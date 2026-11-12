//
//  MessageForwarder.swift
//  chat
//
//  消息转发（单条 / 逐条 / 合并转发）。
//
//  设计说明：
//  1. 转发**不在这里直接发 socket**：把「目标会话 + 待发消息」暂存进 `ChatManager`，
//     再跳到目标会话，由 `ChatVC` 用自己那套发送逻辑发出去
//     —— 服务器地址、加密、上传全部复用，和「大图长按 → 转发图片」是同一条路。
//  2. 目标会话正好是当前会话时（在当前会话里转发），直接交给当前 `ChatVC` 发，不跳页。
//  3. 媒体消息（图片/视频/文件/语音）转发前必须**先拿到本地资源**：
//     · 图片：本地 ImageCache 里就是解密后的原图（见 `SocketManager` 收图时已解密缓存）；
//     · 视频/文件/语音：本地有文件直接用，没有就触发下载，下载完再转发。
//

import Kingfisher
import RxSwift
import SnapKit
import UIKit

enum MessageForwarder {

    /// 转发期间持有正在下载的 VM —— 下载是订阅式的，VM 一旦释放回调就收不到结果了
    private static var downloadingVMs: [(vm: FZMMessageBaseVM, bag: DisposeBag)] = []

    // MARK: - 可转发判断

    /// 系统 / 通知 / 未识别消息不参与转发
    static func canForward(_ msg: Message) -> Bool {
        switch msg.msgType {
        case .text, .image, .video, .file, .audio, .contactCard, .redPacket, .transfer, .forward:
            return true
        case .system, .notify, .RTCCall, .collect, .unknown:
            return false
        }
    }

    // MARK: - 选人

    /// 弹「选择会话」页（好友 + 群聊一张列表），选中后回调目标会话 id
    static func presentPicker(from host: UIViewController?, completion: @escaping (SessionID) -> Void) {
        let picker = ChoiceContactCardVC()
        picker.showsFriendAndGroup = true
        picker.seletedBlock = { contact in
            let address = contact.sessionIDStr
            guard !address.isEmpty else { return }
            // 会话类型看这条联系人自己，不让用户先选一遍「好友/群聊」
            let sessionID: SessionID =
                contact.type == .group ? SessionID.group(address) : SessionID.person(address)
            // ⚠️ 这里**不要**再 dismiss：`ChoiceContactCardVC.deal` 收到选择后会自己 dismiss，
            //    连续两次 dismiss 会把 dismiss 的 completion 吃掉（回调不再执行）。
            //    等它关完再回调，避免「选人页还在关闭动画中就 push 新页面」导致跳转不生效。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                completion(sessionID)
            }
        }
        let nav = FZMNavigationController(rootViewController: picker)
        (host ?? UIViewController.current())?.present(nav, animated: true)
    }

    // MARK: - 多选会话

    /// 弹「选择会话」页（多选版）：勾选多个好友/群聊，点「发送(N)」后回调
    static func presentMultiPicker(
        from host: UIViewController?, completion: @escaping ([SessionID]) -> Void
    ) {
        let picker = ChoiceContactCardVC()
        picker.showsFriendAndGroup = true
        picker.allowsMultipleSelection = true
        picker.selectedBlock = { contacts in
            let ids: [SessionID] = contacts.compactMap { contact in
                let address = contact.sessionIDStr
                guard !address.isEmpty else { return nil }
                return contact.type == .group ? SessionID.group(address) : SessionID.person(address)
            }
            guard !ids.isEmpty else { return }
            // 等选人页关闭动画结束再发，避免在被 dismiss 的页面上做异步操作
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                completion(ids)
            }
        }
        let nav = FZMNavigationController(rootViewController: picker)
        (host ?? UIViewController.current())?.present(nav, animated: true)
    }

    /// 多选转发：把消息分别发到每个目标会话，**不跳页**。
    /// 复用 `ChatManager.send`（落库 + 加密 + socket/HTTP），每个会话各复制一份独立消息。
    static func forward(
        _ msgs: [Message], to sessionIDs: [SessionID], from host: UIViewController?,
        completion: ((Int) -> Void)? = nil
    ) {
        let sources = msgs.filter { canForward($0) }
        guard !sources.isEmpty, !sessionIDs.isEmpty else {
            completion?(0)
            return
        }

        var remaining = sessionIDs
        var total = 0

        func next() {
            guard let target = remaining.first else {
                // 多选转发/分享**不跳页**（用户还在原页面），必须明确告诉他已经发出去了，
                // 否则体感就是「点完发送什么都没发生」。跳转留给用户自己去聊天页看。
                if total > 0 {
                    DispatchQueue.main.async {
                        APP.shared().showToast(L("分享成功，自行跳转到聊天页面查看"))
                    }
                }
                completion?(total)
                return
            }
            remaining.removeFirst()

            copy(sources, to: target) { newMsgs in
                guard !newMsgs.isEmpty else {
                    FZMLog("【多选转发】目标=\(target.idValue) 复制消息失败，跳过（源头 \(sources.count) 条）")
                    next()
                    return
                }
                total += newMsgs.count

                // 目标会话正好是当前打开的这个：直接插进它的列表，用户能立刻看到
                if let chatVC = host as? ChatVC, chatVC.session.id == target {
                    newMsgs.forEach { chatVC.insertAndSendMessages([$0], needSendMsg: true) }
                    next()
                    return
                }

                let serverUrl = dispatchServerUrl(for: target)
                FZMLog("【多选转发】发送目标=\(target.idValue) 条数=\(newMsgs.count) serverUrl=\(serverUrl)")
                DispatchQueue.main.async {
                    for msg in newMsgs {
                        ChatManager.shared().send(msg: msg, chatServerUrl: serverUrl)
                    }
                    next()
                }
            }
        }

        next()
    }

    /// 目标会话的聊天服务器地址（不跳页发送时用；群聊取会话/群信息，私聊取企业 IM 地址）
    ///
    /// 🔴 必须保证**尽量不为空**：`MultipleSocketManager.send` 在 serverUrl 为空时会直接判失败，
    ///    消息连发都不发（日志：`当前聊天服务器地址为空, 发送msg失败`）。
    ///    用户 2026-11-05：多选分享 4 个群只有 1 个发出去 —— 就是因为没打开过的群
    ///    `session.chatServerUrl` / `group.chatServerUrl` 都可能是空，原来直接返回 ""。
    private static func dispatchServerUrl(for sessionID: SessionID) -> String {
        var resolved = ""
        if let session = SessionManager.shared().getSingleLocalSession(by: sessionID) {
            if !session.isPrivateChat {
                if !session.chatServerUrl.isBlank {
                    resolved = session.chatServerUrl
                } else if let group = GroupManager.shared().getDBGroup(by: sessionID.idValue.intEncoded),
                          let url = group.chatServerUrl, !url.isBlank {
                    resolved = url
                }
            } else if let info = TeamManager.shared().getDBStaffInfo(address: sessionID.idValue),
                      let teamInfo = TeamManager.shared().getDBTeamInfo(entId: info.entId),
                      !teamInfo.imServer.isBlank {
                // 私聊：企业 IM 地址优先（与 `ChatVC.setChatServerUrl` 同口径）
                resolved = teamInfo.imServer
            }
        }
        // 兜底：自己已连接的聊天服务器（单服务器部署下就是它）
        if resolved.isBlank {
            resolved = LoginUser.shared().chatServerGroups.first?.value ?? ""
        }
        if resolved.isBlank {
            FZMLog("【多选转发】目标=\(sessionID.idValue) 解析不到聊天服务器地址（会话/群/企业 IM 全空）")
        }
        return resolved
    }

    // MARK: - 对外入口

    /// 逐条转发：每条源消息在目标会话里变成一条独立的新消息
    static func forward(
        _ msgs: [Message], to sessionId: SessionID, from host: UIViewController?,
        completion: ((Int) -> Void)? = nil
    ) {
        let sources = msgs.filter { canForward($0) }
        guard !sources.isEmpty else {
            completion?(0)
            return
        }
        copy(sources, to: sessionId) { newMsgs in
            guard !newMsgs.isEmpty else {
                APP.shared().showToast(L("转发失败，请稍后重试"))
                completion?(0)
                return
            }
            send(newMsgs, to: sessionId, from: host)
            completion?(newMsgs.count)
        }
    }

    /// 合并转发：打包成**一条**「聊天记录」消息
    static func mergeForward(
        _ msgs: [Message], to sessionId: SessionID, from host: UIViewController?,
        completion: ((Bool) -> Void)? = nil
    ) {
        let sources = msgs.filter { canForward($0) }
        guard !sources.isEmpty else {
            completion?(false)
            return
        }
        guard let merged = makeMergedMessage(sources, to: sessionId) else {
            completion?(false)
            return
        }
        send([merged], to: sessionId, from: host)
        completion?(true)
    }

    /// 多选合并转发：每个目标会话各生成一条「聊天记录」卡片，不跳页
    static func mergeForward(
        _ msgs: [Message], to sessionIDs: [SessionID], from host: UIViewController?,
        completion: ((Bool) -> Void)? = nil
    ) {
        let sources = msgs.filter { canForward($0) }
        guard !sources.isEmpty, !sessionIDs.isEmpty else {
            completion?(false)
            return
        }

        var remaining = sessionIDs
        var sentAny = false
        func next() {
            guard let target = remaining.first else {
                completion?(sentAny)
                return
            }
            remaining.removeFirst()
            guard let merged = makeMergedMessage(sources, to: target) else {
                next()
                return
            }
            sentAny = true
            if let chatVC = host as? ChatVC, chatVC.session.id == target {
                chatVC.insertAndSendMessages([merged], needSendMsg: true)
            } else {
                let serverUrl = dispatchServerUrl(for: target)
                DispatchQueue.main.async {
                    ChatManager.shared().send(msg: merged, chatServerUrl: serverUrl)
                }
            }
            next()
        }
        next()
    }

    // MARK: - 发送

    private static func send(_ msgs: [Message], to sessionId: SessionID, from host: UIViewController?) {
        guard !msgs.isEmpty else { return }

        // 目标就是当前这个会话：交给它自己发（跳页反而什么都不发生）
        if let chatVC = host as? ChatVC, chatVC.session.id == sessionId {
            // 一条一条发：insertAndSendMessages 只会把 messages.first 交给发送逻辑
            msgs.forEach { chatVC.insertAndSendMessages([$0], needSendMsg: true) }
            return
        }

        ChatManager.shared().setPendingForwardMessages(msgs, for: sessionId)
        FZMUIMediator.shared().pushVC(.goChatVC(sessionID: sessionId))
    }

    // MARK: - 消息复制（逐条）

    /// 串行复制：媒体消息要等本地资源，串行能保持原顺序
    private static func copy(
        _ msgs: [Message], to sessionId: SessionID, completion: @escaping ([Message]) -> Void
    ) {
        var rest = msgs
        var result = [Message]()
        func next() {
            guard !rest.isEmpty else {
                completion(result)
                return
            }
            let msg = rest.removeFirst()
            makeCopy(of: msg, to: sessionId) { newMsg in
                if let newMsg = newMsg {
                    result.append(newMsg)
                }
                next()
            }
        }
        next()
    }

    private static func makeCopy(
        of msg: Message, to sessionId: SessionID, completion: @escaping (Message?) -> Void
    ) {
        switch msg.msgType {
        case .text:
            completion(makeMessage(sessionId: sessionId, msgType: .init(text: msg.msgType.textValue)))

        case .contactCard:
            // 名片（含安卓端「专属红包」的兼容通道：type == -1），原样带过去
            let msgType = Message.MsgType.init(
                contactCard: msg.msgType.contactId ?? "",
                name: msg.msgType.contactName ?? "",
                avatar: msg.msgType.contactAvatar ?? "",
                type: msg.msgType.contactType ?? 1)
            completion(makeMessage(sessionId: sessionId, msgType: msgType))

        case .transfer:
            let msgType = Message.MsgType.init(
                transfer: msg.msgType.coinName ?? "", txHash: msg.msgType.txHash ?? "")
            completion(makeMessage(sessionId: sessionId, msgType: msgType))

        case .redPacket:
            let msgType = Message.MsgType.init(
                redPacket: msg.msgType.txHash ?? "",
                coinName: msg.msgType.coinName ?? "",
                exec: msg.msgType.exec ?? "",
                packetType: msg.msgType.packetType ?? 0,
                remark: msg.msgType.remark ?? "",
                expire: msg.msgType.expire ?? 0)
            completion(makeMessage(sessionId: sessionId, msgType: msgType))

        case .forward:
            // 转发一条合并转发消息：条目原样带过去
            guard let items = msg.msgType.forwardItems else {
                completion(nil)
                return
            }
            completion(makeMessage(sessionId: sessionId, msgType: .init(forwardItems: items)))

        case .image:
            copyImage(msg, to: sessionId, completion: completion)

        case .video, .file, .audio:
            copyMedia(msg, to: sessionId, completion: completion)

        default:
            completion(nil)
        }
    }

    // MARK: - 图片

    private static func copyImage(
        _ msg: Message, to sessionId: SessionID, completion: @escaping (Message?) -> Void
    ) {
        // 本地缓存里存的就是**解密后的原图**（收图时已解密缓存），直接复制到新 key 再发
        msg.msgType.imageAsync { image in
            guard let image = image else {
                DispatchQueue.main.async {
                    APP.shared().showToast(L("图片还在加载中，请稍后再试"))
                    completion(nil)
                }
                return
            }
            let newKey = String.uuid()
            ChatMediaCache.store(image, forKey: newKey)
            let msgType = Message.MsgType.init(
                image: nil, cacheKey: newKey, width: Double(image.size.width),
                height: Double(image.size.height))
            DispatchQueue.main.async {
                completion(makeMessage(sessionId: sessionId, msgType: msgType))
            }
        }
    }

    // MARK: - 视频 / 文件 / 语音

    private static func copyMedia(
        _ msg: Message, to sessionId: SessionID, completion: @escaping (Message?) -> Void
    ) {
        ensureLocalFile(msg) { filePath in
            guard let filePath = filePath else {
                APP.shared().showToast(L("文件还在下载中，请稍后再试"))
                completion(nil)
                return
            }
            let newKey = String.uuid()
            var newMsg: Message?
            switch msg.msgType {
            case .video:
                let msgType = Message.MsgType.init(
                    video: nil, cacheKey: newKey, duration: msg.msgType.duration ?? 0,
                    width: msg.msgType.size.width, height: msg.msgType.size.height)
                var m = makeMessage(sessionId: sessionId, msgType: msgType)
                m.mediaUrl = URL.init(fileURLWithPath: filePath)
                newMsg = m
                // 封面：优先复用原封面缓存，没有就从视频里抽一帧存到新 key（列表靠它显示缩略图）
                copyVideoCover(msg, newKey: newKey, videoPath: filePath)

            case .file:
                let msgType = Message.MsgType.init(
                    file: nil, cacheKey: newKey, name: msg.msgType.fileName ?? "",
                    md5: msg.msgType.md5 ?? "", size: Double(msg.msgType.fileSize ?? 0))
                var m = makeMessage(sessionId: sessionId, msgType: msgType)
                m.fileUrl = filePath
                newMsg = m

            case .audio:
                let msgType = Message.MsgType.init(
                    audio: nil, duration: msg.msgType.duration ?? 0, cacheKey: newKey,
                    width: 0, height: 0)
                var m = makeMessage(sessionId: sessionId, msgType: msgType)
                m.audioUrl = filePath
                newMsg = m

            default:
                newMsg = nil
            }
            completion(newMsg)
        }
    }

    /// 确保消息的本地文件存在：本地有直接用，没有就触发一次下载，下载完再回调
    private static func ensureLocalFile(_ msg: Message, completion: @escaping (String?) -> Void) {
        // 依次尝试：标准沙盒路径 → 消息里带的本地路径（视频用 mediaUrl、文件用 fileUrl、语音用 audioUrl）
        var candidates: [String] = [FZMMessageBaseVM.getFilePath(with: msg)]
        if let fileUrl = msg.fileUrl, !fileUrl.isBlank { candidates.append(fileUrl) }
        if let mediaUrl = msg.mediaUrl, !mediaUrl.path.isBlank { candidates.append(mediaUrl.path) }
        if let audioUrl = msg.audioUrl, !audioUrl.isBlank { candidates.append(audioUrl) }
        for path in candidates where FZMLocalFileClient.shared().isFileExists(atPath: path) {
            completion(path)
            return
        }

        // 本地没有：下载（下载期间由 downloadingVMs 保活 VM，否则回调拿不到）
        let vm = FZMMessageBaseVM.init(with: msg)
        let bag = DisposeBag()
        var finished = false
        downloadingVMs.append((vm, bag))

        func finish(_ path: String?) {
            guard !finished else { return }
            finished = true
            downloadingVMs.removeAll { $0.vm === vm }
            DispatchQueue.main.async {
                completion(path)
            }
        }

        vm.fileDownloadSucceedSubject.subscribe(onNext: { _ in
            finish(FZMMessageBaseVM.getFilePath(with: msg))
        }).disposed(by: bag)
        vm.fileDownloadFailedSubject.subscribe(onNext: { _ in
            finish(nil)
        }).disposed(by: bag)
        vm.downloadData()
    }

    private static func copyVideoCover(_ msg: Message, newKey: String, videoPath: String) {
        let oldKey = msg.msgType.cachekey ?? ""
        ChatMediaCache.safeRetrieveImage(forKey: oldKey) { image in
            if let image = image {
                ChatMediaCache.store(image, forKey: newKey)
                return
            }
            // 本地没有封面缓存：从视频里抽第一帧
            UIImage.getVideoCropPicture(URL.init(fileURLWithPath: videoPath)) { image in
                guard let image = image else { return }
                ChatMediaCache.store(image, forKey: newKey)
            }
        }
    }

    // MARK: - 合并转发

    /// 把多条消息打包成一条「聊天记录」消息（msgType = 8）
    private static func makeMergedMessage(_ msgs: [Message], to sessionId: SessionID) -> Message? {
        let items: [Message.MsgType.ForwardItem] = msgs.map { msg in
            // 每条都带上**原始消息体**（明文 pb bytes）：接收端据此还原内容，不需要会话密钥
            let pbMsg = PbMsg_msg.init(with: msg)
            return Message.MsgType.ForwardItem(
                avatar: senderAvatar(of: msg),
                name: senderName(of: msg),
                msgType: msg.msgType.intValue,
                msg: pbMsg.msg,
                datetime: msg.datetime)
        }
        guard !items.isEmpty else { return nil }
        return makeMessage(sessionId: sessionId, msgType: .init(forwardItems: items))
    }

    // MARK: - 小工具

    private static func makeMessage(sessionId: SessionID, msgType: Message.MsgType) -> Message {
        return Message.init(
            fromId: LoginUser.shared().address, sessionId: sessionId, msgType: msgType)
    }

    private static func senderName(of msg: Message) -> String {
        if msg.isOutgoing {
            return LoginUser.shared().nickName?.value ?? LoginUser.shared().address
        }
        if let member = msg.member { return member.contactsName }
        if let user = msg.user { return user.contactsName }
        if let user = UserManager.shared().user(by: msg.fromId) { return user.contactsName }
        return msg.fromId.shortAddress
    }

    private static func senderAvatar(of msg: Message) -> String {
        if msg.isOutgoing { return LoginUser.shared().avatarUrl }
        if let member = msg.member { return member.avatarURLStr }
        if let user = msg.user { return user.avatarURLStr }
        if let user = UserManager.shared().user(by: msg.fromId) { return user.avatarURLStr }
        return ""
    }
}

// MARK: - 合并转发详情页

/// 合并转发卡片点开后：逐条展示被打包的那几条消息
class ForwardDetailVC: UIViewController {

    private let items: [Message.MsgType.ForwardItem]

    private lazy var tableView: UITableView = {
        let view = UITableView.init(frame: .zero, style: .plain)
        view.backgroundColor = .white
        view.separatorStyle = .none
        view.rowHeight = UITableView.automaticDimension
        view.estimatedRowHeight = 60
        view.dataSource = self
        view.delegate = self
        view.register(ForwardDetailCell.self, forCellReuseIdentifier: "ForwardDetailCell")
        return view
    }()

    init(items: [Message.MsgType.ForwardItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L("聊天记录")
        self.view.backgroundColor = .white
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(
            image: #imageLiteral(resourceName: "nav_back").withRenderingMode(.alwaysTemplate),
            style: .plain, target: self, action: #selector(clickBack))
        self.navigationItem.leftBarButtonItem?.tintColor = Color_24374E

        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }

    @objc private func clickBack() {
        self.navigationController?.popViewController(animated: true)
    }
}

extension ForwardDetailVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ForwardDetailCell", for: indexPath)
        guard let detailCell = cell as? ForwardDetailCell, indexPath.row < items.count else {
            return cell
        }
        detailCell.configure(with: items[indexPath.row])
        return cell
    }
}

/// 详情页里的一条：昵称 + 时间 + 内容摘要（文本直接显示原文）
private class ForwardDetailCell: UITableViewCell {

    private let nameLabel: UILabel = {
        let lab = UILabel.init()
        lab.font = UIFont.systemFont(ofSize: 13)
        lab.textColor = Color_8A97A5
        lab.numberOfLines = 1
        return lab
    }()

    private let contentLabel: UILabel = {
        let lab = UILabel.init()
        lab.font = UIFont.systemFont(ofSize: 15)
        lab.textColor = Color_24374E
        lab.numberOfLines = 0
        return lab
    }()

    private let separator: UIView = {
        let view = UIView.init()
        view.backgroundColor = Color_F6F7F8
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = .white

        self.contentView.addSubview(nameLabel)
        self.contentView.addSubview(contentLabel)
        self.contentView.addSubview(separator)

        nameLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(12)
        }
        contentLabel.snp.makeConstraints { (m) in
            m.left.right.equalTo(nameLabel)
            m.top.equalTo(nameLabel.snp.bottom).offset(6)
            m.bottom.equalToSuperview().offset(-12)
        }
        separator.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: Message.MsgType.ForwardItem) {
        let time = String.showTimeString(with: Double(item.datetime))
        nameLabel.text = item.name + "  " + time
        contentLabel.text = item.summaryText
    }
}
