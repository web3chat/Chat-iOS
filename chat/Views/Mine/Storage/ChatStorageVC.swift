//
//  ChatStorageVC.swift
//  chat
//
//  「存储空间 → 聊天记录」：按会话列出本地占用，支持清理媒体 / 清理整个会话。
//
//  ⚠️ 只删本机：
//     `ChatManager.deleteSessionMsgs(targetId:)` 只删本地库，服务端没有「按会话删除」接口，
//     下次同步仍可能把历史补回来。所以文案统一写「清理本机」。
//

import UIKit
import SnapKit
import Kingfisher
import SwifterSwift

class ChatStorageVC: UIViewController, ViewControllerProtocol {

    /// 上级「聊天记录」显示的数（= 各会话之和；详情页不再单列 App 必要文件）
    private var totalChatBytes: Int64

    init(totalChatBytes: Int64 = 0) {
        self.totalChatBytes = totalChatBytes
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UI

    private lazy var tableView: UITableView = {
        let view = UITableView.init(frame: .zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.separatorStyle = .none
        view.dataSource = self
        view.delegate = self
        view.rowHeight = 68
        view.showsVerticalScrollIndicator = false
        view.register(ChatStorageCell.self, forCellReuseIdentifier: "ChatStorageCell")
        return view
    }()

    private lazy var headerLabel: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: L("按占用大小排序，点击可清理"))
        lab.numberOfLines = 0
        return lab
    }()

    /// 清理「未关联媒体」（30 天前、没有被当前账号消息引用的文件）
    private lazy var cleanOrphanButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.contentHorizontalAlignment = .left
        btn.titleLabel?.font = .regularFont(12)
        btn.setTitleColor(Color_8A97A5, for: .normal)
        btn.setTitle(L("未关联媒体"), for: .normal)
        btn.addTarget(self, action: #selector(cleanOrphanTapped), for: .touchUpInside)
        btn.isEnabled = false
        return btn
    }()

    private lazy var headerContainer: UIView = {
        let container = UIView.init(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth - 30, height: 80))
        container.backgroundColor = .clear
        container.addSubview(self.headerLabel)
        container.addSubview(self.cleanOrphanButton)
        self.headerLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(4)
            m.right.equalToSuperview().offset(-4)
            m.top.equalToSuperview().offset(0)
        }
        self.cleanOrphanButton.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(4)
            m.top.equalTo(self.headerLabel.snp.bottom).offset(6)
            m.height.equalTo(24)
            m.bottom.equalToSuperview().offset(-10)
        }
        return container
    }()

    private lazy var emptyLabel: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("暂无聊天记录"))
        lab.numberOfLines = 0
        return lab
    }()

    // MARK: 数据

    private var items: [FZMChatStorageItem] = []
    private var sessionMap: [String: Session] = [:]
    private var orphanMedia = FZMOrphanMedia()

    private var languageChangeObserver: NSObjectProtocol?

    deinit {
        if let observer = languageChangeObserver {
            FZM_NotificationCenter.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.title = L("聊天记录")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        self.tableView.tableHeaderView = self.headerContainer

        languageChangeObserver = FZM_NotificationCenter.addObserver(
            forName: LanguageManager.LanguageChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] (_) in
            guard let self = self else { return }
            self.title = L("聊天记录")
            self.headerLabel.text = L("按占用大小排序，点击可清理")
            self.emptyLabel.text = L("暂无聊天记录")
            self.tableView.reloadData()
        }

        // 延后一拍：viewDidLoad 时视图还没上屏，HUD 加不上
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutHeader()
    }

    /// 表头高度跟着文案行数走（对账文案有两三行）
    private func layoutHeader() {
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : (k_ScreenWidth - 30)
        let textWidth = max(width - 8, 100)
        let size = headerLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let newHeight = max(44, size.height + 6 + 24 + 10)
        var frame = headerContainer.frame
        guard abs(frame.width - width) > 0.5 || abs(frame.height - newHeight) > 0.5 else { return }
        frame.size = CGSize(width: width, height: newHeight)
        headerContainer.frame = frame
        tableView.tableHeaderView = headerContainer
    }

    /// 详情页对账：上级显示的是真实磁盘数，各会话是"按消息归属"的数，差额单独列出来。
    private func updateHeaderSummary() {
        guard totalChatBytes > 0 else {
            headerLabel.text = L("按占用大小排序，点击可清理")
            layoutHeader()
            return
        }

        var lines: [String] = []
        lines.append("\(L("共")) \(FZMStorageManager.sizeText(totalChatBytes))")
        // 未关联媒体不算进「聊天记录」（它归 App 必要文件），单独提示可清理
        if orphanMedia.totalBytes > 0 {
            lines.append("\(L("未关联媒体")) \(FZMStorageManager.sizeText(orphanMedia.totalBytes))（\(L("不计入上方，可清理"))）")
        }
        lines.append(L("按占用大小排序，点击可清理"))
        headerLabel.text = lines.joined(separator: "\n")
        layoutHeader()
    }

    // MARK: - 未关联媒体

    private func refreshOrphanMedia() {
        cleanOrphanButton.isEnabled = false
        cleanOrphanButton.setTitle(L("正在扫描未关联媒体…"), for: .normal)
        cleanOrphanButton.setTitleColor(Color_8A97A5, for: .normal)
        FZMStorageManager.shared.loadOrphanMedia { [weak self] info in
            guard let self = self else { return }
            self.orphanMedia = info
            self.updateHeaderSummary()
            self.updateOrphanButton()
        }
    }

    private func updateOrphanButton() {
        if orphanMedia.isEmpty {
            cleanOrphanButton.setTitle("\(L("未关联媒体")) 0 KB（\(L("无需清理"))）", for: .normal)
            cleanOrphanButton.setTitleColor(Color_8A97A5, for: .normal)
            cleanOrphanButton.isEnabled = false
        } else {
            cleanOrphanButton.setTitle("\(L("清理未关联媒体")) \(FZMStorageManager.sizeText(orphanMedia.totalBytes))", for: .normal)
            cleanOrphanButton.setTitleColor(Color_Theme, for: .normal)
            cleanOrphanButton.isEnabled = true
        }
        layoutHeader()
    }

    @objc private func cleanOrphanTapped() {
        guard !orphanMedia.isEmpty else { return }
        let size = FZMStorageManager.sizeText(orphanMedia.totalBytes)
        let alert = UIAlertController(
            title: L("清理未关联媒体"),
            message: "\(L("将删除 30 天前、没有被当前账号聊天记录引用的图片/视频/文件/语音，不影响现有消息；其它账号的本地缓存也可能被清掉，切回后会重新下载"))\n\(size)",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: L("清理"), style: .destructive, handler: { [weak self] (_) in
            guard let self = self else { return }
            self.showProgress(with: L("正在清理…"))
            FZMStorageManager.shared.clearOrphanMedia { [weak self] freed in
                guard let self = self else { return }
                self.hideProgress()
                self.showToast("\(L("已清理")) \(FZMStorageManager.sizeText(freed.totalBytes))")
                // 清理后重新拿一次真实磁盘数，避免表头还是旧值
                FZMStorageManager.shared.loadSummary { [weak self] breakdown in
                    guard let self = self else { return }
                    self.totalChatBytes = breakdown.chatBytes
                    self.loadData()
                }
            }
        }))
        present(alert, animated: true)
    }

    // MARK: 数据

    private func loadData() {
        self.showProgress(with: L("正在计算…"))
        FZMStorageManager.shared.loadChatStorage { [weak self] items in
            guard let self = self else { return }
            self.hideProgress()

            // Session 构造会查 UserManager / GroupManager（可能有 DB 查询），只建一次并缓存
            var map: [String: Session] = [:]
            for item in items {
                map[item.sessionId] = Session(id: item.sessionID)
            }
            self.sessionMap = map
            self.items = items
            self.updateHeaderSummary()
            self.refreshOrphanMedia()
            self.tableView.reloadData()
            self.updateEmptyState()
        }
    }

    private func updateEmptyState() {
        self.tableView.backgroundView = self.items.isEmpty ? self.emptyLabel : nil
    }

    private func replaceItem(_ item: FZMChatStorageItem) {
        guard let index = self.items.firstIndex(where: { $0.sessionId == item.sessionId }) else { return }
        self.items[index] = item
        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    private func removeItem(_ item: FZMChatStorageItem) {
        self.items.removeAll { $0.sessionId == item.sessionId }
        self.sessionMap.removeValue(forKey: item.sessionId)
        self.tableView.reloadData()
        self.updateEmptyState()
    }

    // MARK: 操作

    private func showActions(for item: FZMChatStorageItem) {
        let session = self.sessionMap[item.sessionId]
        // ⚠️ 这里用 .alert 而不是 .actionSheet：
        //    actionSheet 在部分系统版本上会被当成 popover 锚定到 tableView 顶部，出现「弹窗在顶部且选项看不见」。
        //    alert 是居中弹窗，三行按钮一定能看到。
        let alert = UIAlertController.init(
            title: session?.sessionName ?? item.sessionId,
            message: FZMStorageManager.sizeText(item.totalBytes),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction.init(title: L("清理媒体文件"), style: .default, handler: { [weak self] (_) in
            self?.confirmClearMedia(item)
        }))
        alert.addAction(UIAlertAction.init(title: L("清理聊天记录"), style: .destructive, handler: { [weak self] (_) in
            self?.confirmDeleteSession(item)
        }))
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }

    /// 只删媒体，保留聊天文字
    private func confirmClearMedia(_ item: FZMChatStorageItem) {
        let alert = UIAlertController.init(
            title: L("清理媒体文件"),
            message: L("只清理图片、视频、文件和语音，聊天文字会保留；再次查看时需要重新下载"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: L("确定"), style: .default, handler: { [weak self] (_) in
            guard let self = self else { return }
            self.showProgress(with: L("正在清理…"))
            FZMStorageManager.shared.clearMedia(for: item) {
                self.hideProgress()
                self.showToast(L("已清理"))

                var updated = item
                updated.imageBytes = 0
                updated.videoBytes = 0
                updated.fileBytes = 0
                updated.voiceBytes = 0
                self.replaceItem(updated)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    /// 删除整个会话（消息 + 媒体）
    private func confirmDeleteSession(_ item: FZMChatStorageItem) {
        let alert = UIAlertController.init(
            title: L("清理聊天记录"),
            message: L("将删除该会话的全部聊天记录和媒体文件（仅本机），不可恢复"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: L("确定"), style: .destructive, handler: { [weak self] (_) in
            guard let self = self else { return }
            self.showProgress(with: L("正在清理…"))
            FZMStorageManager.shared.deleteSession(item) {
                self.hideProgress()
                self.showToast(L("已清理"))
                self.removeItem(item)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - UITableView

extension ChatStorageVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: ChatStorageCell.self, for: indexPath)
        let item = self.items[indexPath.row]
        cell.configure(item: item, session: self.sessionMap[item.sessionId])

        let isFirstRow = indexPath.row == 0
        let isLastRow = indexPath.row == self.items.count - 1
        if isFirstRow && isLastRow {
            DispatchQueue.main.async {
                cell.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 5)
            }
        } else if isFirstRow {
            DispatchQueue.main.async {
                cell.roundCorners([.topLeft, .topRight], radius: 5)
            }
        } else if isLastRow {
            DispatchQueue.main.async {
                cell.roundCorners([.bottomLeft, .bottomRight], radius: 5)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.items.count > indexPath.row else { return }
        self.showActions(for: self.items[indexPath.row])
    }
}

// MARK: - 会话行

private final class ChatStorageCell: UITableViewCell {

    private let avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()

    private let nameLabel: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 15), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 1
        return lab
    }()

    private let detailLabel: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.numberOfLines = 1
        return lab
    }()

    private let sizeLabel: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 1
        return lab
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.contentView.backgroundColor = Color_FFFFFF
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        self.contentView.addSubview(self.avatarView)
        self.avatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 40, height: 40))
        }

        self.contentView.addSubview(self.sizeLabel)
        self.sizeLabel.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.width.lessThanOrEqualTo(100)
        }
        self.sizeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        self.contentView.addSubview(self.nameLabel)
        self.nameLabel.snp.makeConstraints { (m) in
            m.left.equalTo(self.avatarView.snp.right).offset(12)
            m.right.lessThanOrEqualTo(self.sizeLabel.snp.left).offset(-10)
            m.top.equalToSuperview().offset(15)
        }

        self.contentView.addSubview(self.detailLabel)
        self.detailLabel.snp.makeConstraints { (m) in
            m.left.equalTo(self.nameLabel)
            m.right.lessThanOrEqualTo(self.sizeLabel.snp.left).offset(-10)
            m.top.equalTo(self.nameLabel.snp.bottom).offset(4)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.avatarView.kf.cancelDownloadTask()
        self.avatarView.image = nil
        self.nameLabel.text = nil
        self.detailLabel.text = nil
        self.sizeLabel.text = nil
    }

    func configure(item: FZMChatStorageItem, session: Session?) {
        let placeholder = (session?.isPrivateChat ?? !item.isGroup)
            ? #imageLiteral(resourceName: "friend_chat_avatar")
            : #imageLiteral(resourceName: "group_chat_avatar")
        let avatarSize = CGSize(width: 40 * UIScreen.main.scale, height: 40 * UIScreen.main.scale)
        self.avatarView.kf.setImage(
            with: URL.init(string: session?.imageURLStr ?? ""),
            placeholder: placeholder,
            options: [.processor(DownsamplingImageProcessor(size: avatarSize))]
        )

        let name = session?.sessionName ?? ""
        self.nameLabel.text = name.isEmpty ? item.sessionId : name
        self.detailLabel.text = "\(item.msgCount) " + L("条消息")
        self.sizeLabel.text = FZMStorageManager.sizeText(item.totalBytes)
    }
}
