//
//  ChatVC.swift
//  chat
//
//  Created by fzm on 2020/12/22.
//  lottie动画

import AVFoundation
import AVKit
import Alamofire
import AliyunOSSiOS
import CryptoKit
import Dispatch
import IQKeyboardManagerSwift
import ImageIO
import Kingfisher
import Lantern
import MJRefresh
import MediaPlayer
import MobileCoreServices
import Photos
import PhotosUI
import RxSwift
import SnapKit
import SwifterSwift
import SwiftyJSON
import TSVoiceConverter
import TZImagePickerController
import UIKit

class ChatVC: MessageVC {

    private var curTapMediaCell: MediaMessageCell?
    //    {
    //        didSet {
    //            self.curTapFileCell = nil
    //        }
    //    }// 当前点击的图片/视频cell
    //    private var curTapFileCell: FileMessageCell? {
    //        didSet {
    //            self.curTapMediaCell = nil
    //        }
    //    }// 文件cell 更新下载进度用

    private var referenceMsg: Message?  // 引用消息数据
    /// 引用条内容缓存：key = 被引用消息的 logId（布局会高频调用，不能每次都查库/遍历列表）。
    /// ⚠️ 只缓存**查到**的，查不到不缓存（原消息可能后续才进列表）。
    private var quotePreviewCache: [Int: QuotePreview] = [:]
    private var curTapMsg: Message?  // 当前点击的message
    private var saveToAlUrl: String = ""  // 保存视频用

    // 正在播放的视频（播放器是系统 AVPlayerViewController，它不持有消息，
    // 长按菜单里的「转发视频 / 保存视频」靠这两个字段拿数据）
    private var playingVideoMsg: Message?
    private var playingVideoPath: String = ""
    private weak var playingPlayerVC: AVPlayerViewController?
    private var videoOrFile: Int = 1  // 区分下载的是视频还是文件  视频==1   文件==2  语音==3
    var documentInteractionController: UIDocumentInteractionController!  // 浏览文件用

    private var audioPlayer: AVAudioPlayer?

    // 下载按钮（保存图片、视频用）
    private lazy var downloadBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "icon_download"), for: .normal)
        btn.backgroundColor = .black
        btn.layer.cornerRadius = 4
        btn.layer.masksToBounds = true
        btn.enlargeClickEdge(10, 10, 10, 10)
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: { [weak self] (_) in
            guard let self = self else { return }
            self.saveBtnClick()
        }).disposed(by: self.bag)
        return btn
    }()

    private let bag = DisposeBag.init()

    //是否显示多选
    private var showSelect = false {
        didSet {
            if showSelect {
                self.showRightBarButtonItem(false)
                // 多选：左侧变「取消」、底部显示转发栏、输入区收起
                self.navigationItem.leftBarButtonItem = self.cancelSelectBarItem
                self.view.endEditing(true)
                self.inputBarView.isHidden = true
                self.forwardBar.isHidden = false
            } else {
                self.showRightBarButtonItem(true)
                self.navigationItem.leftBarButtonItem = self.leftBarItemView
                self.inputBarView.isHidden = false
                self.forwardBar.isHidden = true
                self.selectedMsgs.removeAll()
            }
            self.reloadList()
        }
    }
    
    var session: Session
    
    /// 多选模式下已选中的消息
    private var selectedMsgs = [Message]()
    
    /// 多选时的左侧「取消」按钮（代替返回键）
    private lazy var cancelSelectBarItem: UIBarButtonItem = {
        let btn = UIButton.init(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 60, height: 44)
        btn.setTitle(L("取消"), for: .normal)
        btn.setTitleColor(Color_24374E, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        btn.contentHorizontalAlignment = .left
        btn.addTarget(self, action: #selector(cancelSelectAction), for: .touchUpInside)
        return UIBarButtonItem.init(customView: btn)
    }()
    
    /// 多选底栏：逐条转发 / 合并转发 / 删除
    private lazy var forwardBar: FZMForwardBar = {
        let view = FZMForwardBar.init(normal: true)
        view.isHidden = true
        view.backgroundColor = .white
        view.eventBlock = { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .forward:
                self.forwardSelectedMessages(merge: false)
            case .allForward:
                self.forwardSelectedMessages(merge: true)
            case .delete:
                self.deleteSelectedMessages()
            default:
                break
            }
        }
        return view
    }()
    
    @objc private func cancelSelectAction() {
        self.exitSelectMode()
    }

    private lazy var messageArray = [Message]()  // 消息数据

    private lazy var bottomUnReadMessageArray = [Message]()  // 进入页面后新收未读消息数据

    private let operationQueue = OperationQueue()

    private var isHiddenStatusBar: Bool = false

    private var icloudFileBlock: IcloudFileBlock?  //文件block

    private var chatServerUrl: String?  // 当前聊天的服务器地址

    /// 群详情请求失败后的自动重试次数（只在本地已有群信息时重试，避免网络抖动直接锁死输入框）
    private var groupInfoRetryCount = 0

    /// 群聊：本次进入是否已经触发过「补拉离线消息」（见 `triggerGroupOfflineSyncIfNeeded`）
    private var didTriggerGroupOfflineSync = false

    /// 「跟随底部」的截止时间。
    /// 连续收到多条消息时，第一条插入后 collectionView 还没滚到底，
    /// 第二条再判断 `isLastSectionVisible()` 会误判成「用户不在底部」⇒ 消息被塞进底部未读、
    /// 界面不显示（用户 2026-11-02：「对方发了两张图，只显示了一张」）。
    /// 插入/滚动后往后延 2 秒，这段时间内到达的消息一律直接插入。
    private var followBottomUntil: TimeInterval = 0

    private var statusType: SocketConnectStatus = .unConnected
    {
        didSet {
            self.refreshServerStatus()
        }
    }

    private var userInfo: User?  // 私聊用户信息

    private var staffInfo: StaffInfo?  // 私聊用户的员工信息以及企业信息

    private var isGetStaffInfoReuqestSuccess = false  // 获取员工信息请求成功flg

    private var isGettingStaffInfoRequest = false  // 获取员工信息请求进行中flg 防止重复请求

    private var isGetTeamInfoReuqestSuccess = false  // 获取企业信息请求成功flg

    // 群聊的群信息
    private var groupDetailInfo: Group? {
        didSet {
            self.inputBarView.group = groupDetailInfo
        }
    }

    //列表刷新锁
    private let refreshListLock = NSLock()

    private var locationMsg: (String, String)?  // .0 msgId, 搜索关键字 暂时不需要对搜索的文字jx进行高亮, self.locationMsg?.1 不使用
    private var coinName: String?
    private var txHash: String?
    
    /// 阅后即焚发送模式（会话级，离开会话必须关闭）
    private var isBurnMode = false

    /// 群聊进入后是否已跑过一次「自动删除过期消息」
    private var didRunGroupAutoDelete = false

    /// 当前正在处理的红包消息发送者（**会话地址**，不是链上 0x）：
    /// 链上只给得到 `creator` 的 0x 地址、反查不到用户，只用来解析头部的昵称。
    /// ⚠️ 必须放在**类主体**：读写它的 `handleRedPacketTap` / `pushRedPacketInfo` 都在
    /// `extension ChatVC` 里，而**扩展不能有存储属性**。
    private var redPacketSenderAddress = ""

    /// 「开红包」面板对外暴露的两个钩子（面板在 `showOpenRedPacketPanel` 里创建，页面靠它们控制面板）。
    /// ⚠️ 同样**必须放在类主体**：读写它们的是 `extension ChatVC` 里那个 `showOpenRedPacketPanel`
    /// （扩展不能有存储属性，放进去会报 “Extensions must not contain stored properties”）。
    /// - `openRedPacketPanelDismiss`：收起面板；带一个「面板已移除」回调 ⇒ 保证「先消失、再进详情页」的顺序
    /// - `openRedPacketPanelBusy`：领取中态（把「开」按钮换成转圈并禁用，避免重复领）
    /// 面板收起（点叉 / 领取成功）时两个都会被清空。
    private var openRedPacketPanelDismiss: ((@escaping () -> Void) -> Void)?
    private var openRedPacketPanelBusy: ((Bool) -> Void)?

    private lazy var leftBarItemView: UIBarButtonItem = {
        // 使用系统 UIBarButtonItem（customView 会贴左、且 iOS 26 会被套玻璃胶囊）
        let item = UIBarButtonItem(image: UIImage(named: "nav_back")?.withRenderingMode(.alwaysTemplate),
                                   style: .plain,
                                   target: self,
                                   action: #selector(clickBack))
        item.tintColor = Color_24374E
        return item
    }()

    private lazy var rightView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
        return v
    }()

    private lazy var rightBarItemView: UIBarButtonItem = {
        //        let moreBtn = UIBarButtonItem(image: UIImage.init(named: "icon_more")?.withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(rightBarItemClick))
        //        moreBtn.tintColor = Color_24374E
        //        return moreBtn

        let moreButton = UIButton.init(type: .custom)
        moreButton.frame = CGRect.init(x: 0, y: 0, width: 45, height: 44)
        moreButton.setImage(
            #imageLiteral(resourceName: "icon_more").withRenderingMode(.alwaysTemplate),
            for: .normal)
        moreButton.tintColor = Color_24374E
        moreButton.contentHorizontalAlignment = .right
        moreButton.contentVerticalAlignment = .center
        moreButton.addTarget(self, action: #selector(rightBarItemClick), for: .touchUpInside)
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
        v.addSubview(moreButton)
        self.rightView = v
        let barItem = UIBarButtonItem.init(customView: v)
        return barItem
    }()

    private lazy var navTitleView: WJHNavView = {
        let v = WJHNavView.init(
            frame: CGRect.init(x: 0, y: 0, width: 200, height: 44),
            isPrivateChat: self.session.isPrivateChat)
        return v
    }()

    /// 「N 条新消息」按钮**文案**的上限：超过它显示成 `99+`。
    /// ⚠️ 只是文案，**不影响实际加载多少条**（两者必须分开，否则未读 150 时
    ///    只加载 99 条，剩下 51 条被留在「往上滑才加载」的历史里）。
    private static let unreadDisplayCap = 99

    /// 未读数量按钮文案：超过 99 显示 `99+条新消息`
    private static func unreadText(_ count: Int) -> String {
        return (count > unreadDisplayCap ? "\(unreadDisplayCap)+" : "\(count)") + L("条新消息")
    }

    private var topUnreadCount: Int
    private lazy var topUnreadBtn: FZMUnreadCountButton = {
        let btn = FZMUnreadCountButton.init(
            with: #imageLiteral(resourceName: "top_arrow"),
            frame: CGRect(x: k_ScreenWidth, y: 15, width: 125, height: 40))
        btn.setTitle(ChatVC.unreadText(topUnreadCount), for: .normal)
        // 文案长（英文 / 日文 / 韩文）时按内容加宽 —— 否则文字会压到箭头上
        let width = btn.fittedWidth(minWidth: 125)
        btn.frame = CGRect(x: k_ScreenWidth, y: 15, width: width, height: 40)
        // 从屏幕右侧滑出的胶囊：只圆左边两个角（宽度变了 mask 会自己重算）
        btn.roundsLeftCornersOnly = true
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: { [weak self] (_) in
            self?.topUnreadBtnPress()
        }).disposed(by: self.bag)
        return btn

    }()

    private lazy var bottomUnreadBtn: FZMUnreadCountButton = {
        let btn = FZMUnreadCountButton.init(
            with: #imageLiteral(resourceName: "down_arrow"),
            frame: CGRect(x: (k_ScreenWidth - 130) * 0.5, y: k_ScreenHeight, width: 130, height: 40)
        )
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.alpha = 0
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: { [weak self] (_) in
            self?.bottomUnreadBtnPress()
        }).disposed(by: self.bag)
        return btn

    }()

    private var bottomUnreadCount = 0 {
        didSet {
            if bottomUnreadCount == 0 {
                bottomUnreadBtn.alpha = 0
            } else {
                bottomUnreadBtn.setTitle(ChatVC.unreadText(bottomUnreadCount), for: .normal)
                // 同样的道理：按文案加宽并保持水平居中（中文仍是原来的 130）
                let width = bottomUnreadBtn.fittedWidth(minWidth: 130)
                bottomUnreadBtn.frame = CGRect(
                    x: (k_ScreenWidth - width) * 0.5,
                    y: bottomUnreadBtn.frame.origin.y,
                    width: width,
                    height: bottomUnreadBtn.frame.height)
            }
        }
    }

    //MARK: -
    init(session: Session, locationMsg: (String, String)?) {
        self.session = session
        FZMLog("session---\(self.session)")
        self.locationMsg = locationMsg
        topUnreadCount = locationMsg == nil ? session.unreadCount : 0
        super.init(nibName: nil, bundle: nil)
    }

    init(session: Session, coinName: String?, txHash: String?) {
        self.session = session
        FZMLog("session---\(self.session)")
        self.coinName = coinName
        self.txHash = txHash
        topUnreadCount = locationMsg == nil ? session.unreadCount : 0
        super.init(nibName: nil, bundle: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendTransferMsg(coinName: self.coinName!, txHash: self.txHash!)
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        SessionManager.shared().currentChatSession = nil
        FZM_NotificationCenter.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavBackgroundColor()
        IQKeyboardManager.shared.enable = false
        IQKeyboardManager.shared.shouldShowToolbarPlaceholder = false
        IQKeyboardManager.shared.shouldResignOnTouchOutside = false
        // 更新会话名称
        self.refreshSessionName()
    }

    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {
            ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backgroundColor = Color_F6F7F8
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.shouldShowToolbarPlaceholder = true
        IQKeyboardManager.shared.shouldResignOnTouchOutside = true
        VoiceMessagePlayerManager.shared().stopVoice()
        // 阅后即焚为会话级模式：离开会话必须关闭
        if self.isBurnMode {
            self.isBurnMode = false
            self.moreBarView.setBurnSelected(false)
            self.inputBarView.setBurnMode(false)
        }
        // 离开会话时按 DB 重算一次会话预览：会话列表显示的「最后一条」必须与聊天详情里的一致
        // （两边都取 DB 里 datetime 最大的那条），否则会出现「列表页看到的不是详情里最后一条」。
        SessionManager.shared().syncLastMsgInfoWhenLeaveChat(session: self.session)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 群聊：进会话时立即按「自动删除」设置清理一次超期消息（默认 7 天）
        if !self.session.isPrivateChat, !didRunGroupAutoDelete {
            didRunGroupAutoDelete = true
            ChatManager.shared().autoDeleteExpiredMessages(for: self.session)
        }

        // 大图长按「转发图片」：把暂存的图片发到当前会话（复用聊天自己的图片发送逻辑）
        if let shareImage = ChatManager.shared().consumePendingShareImage(for: self.session.id) {
            self.sendImageMsg(image: shareImage)
        }

        // 转发（逐条 / 合并）：把暂存的待转发消息发到当前会话
        // ⚠️ 一条一条发：insertAndSendMessages 只会把 messages.first 交给发送逻辑
        if let forwardMsgs = ChatManager.shared().consumePendingForwardMessages(for: self.session.id) {
            forwardMsgs.forEach { self.insertAndSendMessages([$0], needSendMsg: true) }
        }

        // 「群成员/好友详情 → 红包（专属）」：把暂存的红包消息发到当前会话（同一套红包消息发送逻辑）
        if let packet = ChatManager.shared().consumePendingRedPacket(for: self.session.id) {
            self.sendRedPacketMsg(coinName: packet.coinName, txHash: packet.txHash,
                                  remark: packet.remark, imPacketType: packet.packetType)
        }

        // 「好友详情 → 转账」：把暂存的转账消息发到当前会话（复用聊天里那套转账消息发送逻辑）
        if let transfer = ChatManager.shared().consumePendingTransfer(for: self.session.id) {
            self.sendTransferMsg(coinName: transfer.coinName, txHash: transfer.txHash)
        }

        // 显示右上角「N 条新消息」（加载中时不显示，等离线消息拉完再显示）
        self.updateTopUnreadButtonIfNeeded()

        //        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)), name: Notification.Name("TransferNotification"), object: nil)
    }

    // MARK: - 离线消息加载中 / 顶部未读提示

    /// 有未读、且「第一条未读」不在可见区域时，显示右上角「N 条新消息」
    private func updateTopUnreadButtonIfNeeded() {
        guard self.topUnreadCount > 0 else { return }
        guard self.topUnreadBtn.superview != nil else { return }
        self.topUnreadBtn.isHidden = false

        let firstUnreadSection = max(self.messageArray.count - topUnreadCount, 0)
        let firstUnreadIndexPath = IndexPath.init(item: 0, section: firstUnreadSection)
        if !self.collectionView.indexPathsForVisibleItems.contains(firstUnreadIndexPath) {
            self.showTopUnreadBtn()
        }
    }

    //    @objc func handleNotification(_ notification:Notification){
    //        if let userInfo = notification.userInfo,
    //           let sessionid = userInfo["session"] as? String,
    //           let coinName = userInfo["coinName"] as? String,
    //           let txHash = userInfo["txHash"] as? String{
    //
    //            let sessionID = SessionID.person(sessionid)
    //            let session = SessionManager.shared().getOrCreateSession(id: sessionID)
    //            SessionManager.shared().currentChatSession = session
    //            SessionManager.shared().clearUnreadCount(session: sessionID)
    //
    //            self.coinName = coinName
    //            self.txHash = txHash
    //            topUnreadCount = locationMsg == nil ? session.unreadCount : 0
    //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
    //                self.sendTransferMsg(coinName: self.coinName!, txHash: self.txHash!)
    //            }
    //        }
    //
    //
    //    }

    private func showRightBarButtonItem(_ show: Bool) {
        self.navigationItem.rightBarButtonItem = show ? self.rightBarItemView : nil
    }

    @objc private func clickBack() {
        self.navigationController?.popViewController()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.rightBarButtonItem = nil

        self.navigationItem.leftBarButtonItem = self.leftBarItemView
        self.navigationItem.titleView = self.navTitleView

        self.setBgColor()

        if self.session.isPrivateChat {
            //            moreBarView.hideRed()
            // 专属红包仅支持群聊
            moreBarView.exclusiveRedBagView.isHidden = true
            // 语音房：私聊下第 2 行第 3 格被隐藏的专属红包占着，直接重叠即可
            moreBarView.layoutVoiceRoom(isPrivateChat: true)
            // 阅后即焚仅私聊
            moreBarView.showBurn(true)
            if let user = UserManager.shared().user(by: self.session.id.idValue) {
                self.userInfo = user

                self.showRightBarButtonItem(true)
            }
        } else {
            moreBarView.hideTrans()
            // 语音房：群聊下 hideTrans() 把红包挪到第 2 行第 1 格，语音房接在专属红包右边
            moreBarView.layoutVoiceRoom(isPrivateChat: false)
            // 阅后即焚仅私聊
            moreBarView.showBurn(false)
            if let group = GroupManager.shared().getDBGroup(by: self.session.id.idValue.intEncoded)
            {
                self.groupDetailInfo = group

                //根据是否在群判断显示右侧群详情入口
                self.showRightBarButtonItem(group.isInGroup)
            } else {
                // 本地 DB 没有这个群：先按「拿不到群信息」处理（锁输入框），
                // 但群详情请求会随后从服务器拉一次并恢复 —— 这里留日志，便于区分
                // 「真的不在群里」和「只是本地没缓存」。
                FZMLog("进入群聊：本地 DB 没有群 \(self.session.id.idValue)，等群详情请求回填")
                self.inputBarView.isHidden = true
                self.showRightBarButtonItem(false)
            }
            if let serverUrl = self.groupDetailInfo?.chatServerUrl {
                chatServerUrl = serverUrl

                statusType = MultipleSocketManager.shared().getSingleSocketConnectStatus(serverUrl)
            }
        }

        // 更新会话名称
        self.setNavTitleText()

        self.configureMessageCollectionView()

        self.view.addSubview(topUnreadBtn)
        self.view.addSubview(bottomUnreadBtn)

        // 获取当前发送消息的聊天服务器地址
        self.setChatServerUrl()

        // 群聊：确保该群的聊天服务器已连上，并主动补拉一轮离线消息
        //（群消息没有服务端记录接口，缺的历史/离线消息只能这样补，否则要反复退出重进才慢慢出现）
        self.triggerGroupOfflineSyncIfNeeded()

        // 加载本地消息
        self.loadMsgs()

        // 订阅
        self.setRX()

        if self.session.isPrivateChat {
            // 获取用户详情请求
            self.refreshUserInfoRequestInChatVC()

            // 获取用户员工信息
            self.getStaffInfoRequest()
        } else {
            // 获取群详情请求
            self.refreshGroupInfoRequestInChatVC()

            // 获取群成员列表请求
            self.getGroupMemberListRequest()
        }
    }

    // 获取当前发送消息的聊天服务器地址
    private func setChatServerUrl() {
        chatServerUrl = ""

        if session.isPrivateChat {  // 私聊地址

            if let info = TeamManager.shared().getDBStaffInfo(address: self.session.id.idValue),
                let teamInfo = TeamManager.shared().getDBTeamInfo(entId: info.entId)
            {
                // 有企业信息
                chatServerUrl = teamInfo.imServer
            } else {
                // 不在团队，获取用户的聊天地址
                let chatServerGroups = LoginUser.shared().chatServerGroups

                // 判断自己聊天服务器地址的与该用户的chatServer是否有重合，有则用该地址给此用户发websocket消息，没有走http
                userInfo?.chatServers.forEach { serverUrl in

                    chatServerGroups.forEach { chatServer in
                        // socketManager.url格式为：ws://172.16.101.107:8888/sub/
                        if serverUrl == chatServer.value {
                            chatServerUrl = chatServer.value  // 已获取到聊天地址，退出当前遍历
                            return
                        }
                    }
                    if chatServerUrl != nil {  // 已获取到聊天地址，退出当前遍历
                        return
                    }
                }

                if chatServerUrl.isBlank, let url = userInfo?.chatServers.first {
                    chatServerUrl = url
                }
            }
        } else {  // 群聊地址
            chatServerUrl = session.chatServerUrl
            if chatServerUrl?.isBlank != false {
                let group = GroupManager.shared().getDBGroup(by: session.id.idValue.intEncoded)
                if let serverUrl = group?.chatServerUrl {

                    chatServerUrl = serverUrl
                    session.chatServerUrl = serverUrl
                } else {
                    self.addServerView.isHidden = false
                }
            }
            statusType = MultipleSocketManager.shared().getSingleSocketConnectStatus(
                chatServerUrl ?? "")
        }
        FZMLog("聊天服务器地址： chatServerUrl -- \(chatServerUrl ?? "没获取到")")
    }

    /// 群聊：确保该群的聊天服务器已连上，并主动补拉一轮离线消息。
    private func triggerGroupOfflineSyncIfNeeded() {
        guard !self.session.isPrivateChat, !self.didTriggerGroupOfflineSync else { return }
        guard let serverUrl = self.chatServerUrl, !serverUrl.isBlank else { return }
        self.didTriggerGroupOfflineSync = true
       
        let sessionLogId = ChatManager.shared().getLatestLogId(sessionId: self.session.id.idValue)
        // 会话最近 24 小时内聊过才回退：老会话不值当把整段服务器消息重拉一遍
        let activeRecently = Date.timestamp - self.session.timestamp < 24 * 60 * 60 * 1000
        MultipleSocketManager.shared().ensureSocketConnectedAndSync(serverUrl: serverUrl,
                                                                    sessionId: self.session.id.idValue,
                                                                    sessionLogId: sessionLogId,
                                                                    sessionActiveRecently: activeRecently)
    }

    //刷新群组时的禁言信息
    private func refreshBannedInfo() {
        //先判断全员禁言
        if let type = self.groupDetailInfo?.muteType, type == 1,
            let memberType = self.groupDetailInfo?.person?.memberType, memberType == 0
        {
            //全员禁言 禁言普通群员
            self.inputBarView.bannedAction(with: 0, type: 1)
        } else {

            let time = self.groupDetailInfo?.person?.memberMuteTime
            if time! > Date.timestamp {
                let distance = (time! - Date.timestamp)
                self.inputBarView.bannedAction(with: Double(distance) / 1000, type: 0)
            } else {
                self.inputBarView.bannedAction(with: 0, type: 0)
            }
        }
    }

    // 刷新会话名称
    private func refreshSessionName() {
        self.session = SessionManager.shared().getOrCreateSession(id: self.session.id)

        // 更新会话名称
        self.setNavTitleText()
    }

    // 更新会话名称lab的text
    private func setNavTitleText() {
        var sessionName = self.session.sessionName
        var typeStr = ""
        var isMuteNotifi = false

        if self.session.isPrivateChat {  // 私聊
            if let user = UserManager.shared().user(by: self.session.id.idValue) {
                self.userInfo = user
                isMuteNotifi = user.isMuteNotification
            }
        } else {
            // 群聊
            if let group = GroupManager.shared().getDBGroup(by: self.session.id.idValue.intEncoded)
            {
                self.groupDetailInfo = group

                // 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
                switch group.groupType {
                case 1:
                    typeStr = L("全员")
                case 2:
                    typeStr = L("部门")
                default:
                    typeStr = ""
                }

                isMuteNotifi = group.isMuteNotification

                // 群聊显示群总人数
                if group.memberNum > 0, group.isInGroup {
                    sessionName += "(\(group.memberNum))"
                }
            }
        }

        // 会话昵称
        DispatchQueue.main.async {
            self.navTitleView.setTitleStr(sessionName, typeStr: typeStr, isMuteNotifi: isMuteNotifi)
        }
    }

    /// 订阅聊天服务器连接状态
    private func subscribeServerStatus() {
        guard !self.session.isPrivateChat else {
            return
        }
        MultipleSocketManager.shared().isAvailableSubject.subscribe { [weak self] (event) in
            guard let strongSelf = self, case .next((let url, let isAvailable)) = event,
                let info = strongSelf.groupDetailInfo, let serverUrl = info.chatServerUrl,
                serverUrl == url.absoluteString
            else { return }

            DispatchQueue.main.async {
                strongSelf.statusType = isAvailable ? .connected : .disConnected
            }
        }.disposed(by: self.bag)
    }

    // 刷新顶部服务器名称
    private func refreshServerStatus() {
        guard !self.session.isPrivateChat, let serverUrl = groupDetailInfo?.chatServerUrl else {
            return
        }

        navTitleView.setServerUrl(serverUrl, connectType: statusType)
    }

    // 右上角更多按钮 点击进入详情页
    @objc private func rightBarItemClick() {
        if self.session.isPrivateChat {
            FZMUIMediator.shared().pushVC(
                .goUserDetailInfoVC(address: self.session.id.idValue, source: .normal))
        } else {
            guard chatServerUrl != nil else {
                self.showToast(L("请先添加本群的聊天服务器"))
                return
            }
            //            FZMUIMediator.shared().pushVC(.goGroupDetail(groupId: self.session.id.idValue.intEncoded))

            let vc = FZMGroupDetailInfoVC(with: self.session.id.idValue.intEncoded)
            vc.hidesBottomBarWhenPushed = true
            vc.sendvcBlock = { [] (note) in
                let addr = LoginUser.shared().address

                self.sendContactCard(contactId: addr, name: note, avatar: note, type: -1)

            }
            DispatchQueue.main.async {
                UIViewController.current()?.navigationController?.pushViewController(vc)
            }

        }
    }

    // 页面背景色、导航栏等颜色设置
    private func setBgColor() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8

        self.collectionView.backgroundColor = self.view.backgroundColor
    }

    private func configureMessageCollectionView() {

        self.collectionView.mj_header = MJRefreshNormalHeader.init(refreshingBlock: { [weak self] in
            self?.loadMoreMsg()
        })

        self.collectionView.messageDataSource = self
        self.collectionView.messageCellDelegate = self

        self.inputBarView.delegate = self
        self.moreBarView.delegate = self
        self.addServerView.addBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            guard let server = strongSelf.chatServerUrl else {
                return
            }
            // 跳转到聊天服务器管理页面
            let vc = ChooseServerVC.init()
            vc.groupServer = Server.init(name: "", value: server)
            strongSelf.navigationController?.pushViewController(vc)
        }

        self.collectionView.messageLayoutDataSource = self
        self.collectionView.messagesDisplayDelegate = self

        // 多选底栏（默认隐藏，进入多选模式才显示）
        self.view.addSubview(self.forwardBar)
        self.forwardBar.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.bottom.equalToSuperview()
            m.height.equalTo(70 + k_SafeBottomInset)
        }
    }

    // 从数据库获取消息数据
    private func getHistoryMsgs(locationMsgId: String = "", count: Int = 20) -> [Message] {
        let msgId = locationMsgId.isBlank ? (self.messageArray.first?.msgId ?? "") : locationMsgId
        let msgInDB = ChatManager.shared().getHistoryMsgs(
            session: self.session, from: msgId, count: count,
            includeCurMsgFlg: !locationMsgId.isBlank)
        let newMsgs = self.getMsgsUsers(msgs: msgInDB)
        return newMsgs.reversed()
    }
    
    /// 把从本地库查到的一页历史消息并入数据源（按 msgId 去重）。
    /// ⚠️ 历史分页边界是「时间 + logId」，同一毫秒的多条消息仍可能被相邻两页取到；
    ///    不去重会出现重复 cell / 列表错位。调用方需在 `refreshListLock` 内调用。
    private func dedupedHistoryMsgs(_ newMsgs: [Message]) -> [Message] {
        guard !newMsgs.isEmpty, !self.messageArray.isEmpty else { return newMsgs }
        let existingIds = Set(self.messageArray.map { $0.msgId })
        return newMsgs.filter { !existingIds.contains($0.msgId) }
    }

    // 服务端 records[] → 本地 Message（私聊消息体是密文，需先取对端公钥解密；回调在解密完成后）
    private func parseServerRecords(_ json: JSON, completion: @escaping ([Message]) -> Void) {
        Message.serverRecords(fromData: json, peerAddress: self.session.id.idValue, completion: completion)
    }

    // 加载消息：直接读本地库
    // （服务端记录已在进入 App 时后台异步预取，见 `ChatManager+RecordPull.swift`；
    //  这里不再每次点开会话都请求服务端，避免拖慢打开速度）
    private func loadMsgs() {
        self.loadMsgsFromLocal()
        // 进入会话即补齐本地图片缓存（清理缓存后无需滑动列表即可显示）
        ChatManager.shared().reloadMissingImageCache(sessionId: self.session.id.idValue) { [weak self] (missingCount) in
            guard let self = self, missingCount > 0 else { return }
            self.collectionView.reloadDataAndKeepOffset()
        }
        // 本地没有记录（首次登录 / 启动预取还没跑完）：先让页面显示出来，再异步补拉 —— 打开会话永远不等网络
        self.pullLatestRecordsIfEmpty()
    }

    /// 本地一条记录都没有时，异步向服务端补拉最新一页。
    /// ⚠️ 刻意不在打开会话的路径上同步等接口：页面（含空列表 / 输入框）先上屏，数据到了再补进去。
    /// 启动预取正常跑过之后本地就有数据，这里不会被触发，不会多打接口。
    private func pullLatestRecordsIfEmpty() {
        guard self.session.isPrivateChat, self.locationMsg == nil else { return }
        guard ChatManager.shared().getLatestMsg(sessionId: self.session.id.idValue, exceptMsgId: "") == nil else { return }
        let targetId = self.session.id.idValue
        PriChatRecordAPI.records(targetId: targetId, count: 20, logId: nil, successBlock: { [weak self] (json) in
            guard let self = self else { return }
            self.parseServerRecords(json) { [weak self] (msgs) in
                guard let self = self, !msgs.isEmpty else { return }
                // ⚠️ 落库已在后台队列：必须等写完再读本地，否则刚拉到的消息还没进库
                ChatManager.shared().savePulledRecords(msgs) { [weak self] in
                    self?.loadMsgsFromLocal()
                }
            }
        }, failureBlock: { (error) in
            FZMLog("进入会话补拉私聊记录失败: \(error.localizedDescription)")
        })
    }

    // 加载本地消息
    // 如果是搜索聊天记录跳转，则加载那条数据之后的所有消息数据？？？
    private func loadMsgsFromLocal() {
        DispatchQueue.global().async {
            var msgId = ""
            var count = 20
            if self.locationMsg != nil {
                msgId = self.locationMsg!.0
                count = .max
            } else if self.topUnreadCount >= count {
                // 🔴 首屏固定只取 20 条：离线期间积压的未读一旦超过 20 条，多出来的那段
                //    会留在「往上滑才加载」的历史里 —— 用户看到的就是「发了 26 条只进来 20 条，
                //    另外 6 条跑到历史消息里去了」（2026-11-03 实测确认）。
                //    ⇒ 按未读数放大首屏，把整段未读一次装满（不设上限：
                //    用户要的是「离线期间的全都进来」，宁可多读几条也不能留一半在历史里）。
                count = max(count, self.topUnreadCount + 1)
            }
            if self.locationMsg == nil {
                // 排查「发 N 条只显示 20 条」：打开会话时先看未读数对不对 👇
                // 未读=0 却实际有积压 ⇒ 问题在未读累加（SessionManager.updateLstestInfo），不在首屏取数
                FZMLog("【首屏】session=\(self.session.id.idValue) 未读=\(self.topUnreadCount) 取 \(count) 条")
            }
            let newMsgInDB = self.getHistoryMsgs(locationMsgId: msgId, count: count)
            DispatchQueue.main.async {
                self.refreshListLock.lock()
                let freshMsgs = self.dedupedHistoryMsgs(newMsgInDB)
                if freshMsgs.count > 0 {
                    self.messageArray = freshMsgs + self.messageArray
                }
                // 预取红包链上信息：reloadData 之后 cell 就要上屏了，越早查越好
                self.prefetchRedPacketInfos(newMsgInDB)
                self.collectionView.reloadData()
                if self.locationMsg != nil {
                    self.collectionView.scrollToFirstItem(pos: .top, animated: false)
                } else {
                    self.collectionView.scrollToLastItem(at: .bottom, animated: false)
                }
                self.refreshListLock.unlock()

                // 首屏加载完后更新顶部「N 条新消息」：
                // ⚠️ 不能再无条件 `hideTopUnreadBtn()` —— 那会把 topUnreadCount 清零，
                //    用户就永远看不到这个提示（2026-11-05 反馈「被改没了」）。
                //    改成：加载中先不显示；加载完、且「第一条未读」不在可见区时才显示。
                self.updateTopUnreadButtonIfNeeded()

                // 🔴 未读数 > 已加载数 ⇒ 中间有缺口（服务端认为已投递、不会再推）。
                //    这里把同步断点回退到「当前最早的一条」，让服务端把这一整段**重推一遍**。
                //    只在群聊、且确实缺消息时触发；同一会话本次启动只回退一次（内部有去重）。
                if !self.session.isPrivateChat,
                    self.topUnreadCount > self.messageArray.count,
                    let oldestLogId = self.messageArray.first?.logId, oldestLogId > 0,
                    let serverUrl = self.chatServerUrl, !serverUrl.isBlank
                {
                    FZMLog("【补拉】未读=\(self.topUnreadCount) 已加载=\(self.messageArray.count)，断点回退到 \(oldestLogId) 重拉")
                    MultipleSocketManager.shared().ensureSocketConnectedAndSync(
                        serverUrl: serverUrl, sessionId: self.session.id.idValue,
                        sessionLogId: oldestLogId, sessionActiveRecently: true)
                }
            }
        }
    }

    // 加载更多：私聊优先用服务端游标翻页（本页最小 logId），落库后从本地库补进列表
    private func loadMoreMsg(count: Int = 20) {
        guard self.session.isPrivateChat,
              let cursorLogId = self.messageArray.first?.logId,
              cursorLogId > 0 else {
            self.loadMoreFromLocal(count: count)
            return
        }
        let targetId = self.session.id.idValue
        PriChatRecordAPI.records(targetId: targetId, count: count, logId: String(cursorLogId), successBlock: { [weak self] (json) in
            guard let self = self else { return }
            self.parseServerRecords(json) { [weak self] (msgs) in
                guard let self = self else { return }
                // ⚠️ 同上：等落库完成再读本地
                ChatManager.shared().savePulledRecords(msgs) { [weak self] in
                    self?.loadMoreFromLocal(count: count)
                }
            }
        }, failureBlock: { [weak self] (error) in
            FZMLog("拉取更多私聊记录失败，回退本地库: \(error.localizedDescription)")
            self?.loadMoreFromLocal(count: count)
        })
    }

    // 加载更多本地历史消息
    private func loadMoreFromLocal(count: Int = 20) {
        DispatchQueue.global().async {
            let newMsgInDB = self.getHistoryMsgs(count: count)
            DispatchQueue.main.async {
                self.refreshListLock.lock()
                let freshMsgs = self.dedupedHistoryMsgs(newMsgInDB)
                if freshMsgs.count > 0 {
                    self.messageArray = freshMsgs + self.messageArray
                }
                // 预取红包链上信息（翻到的旧红包若是「进行中」的，也要显示对）
                self.prefetchRedPacketInfos(newMsgInDB)
                self.collectionView.reloadDataAndKeepOffset()
                self.collectionView.mj_header?.endRefreshing()
                self.collectionView.mj_header?.isHidden = newMsgInDB.count == 0
                self.refreshListLock.unlock()
            }
        }
    }

    private func getMsgsUsers(msgs: [Message]) -> [Message] {
        var messages: [Message] = []

        let myGroup = DispatchGroup.init()

        for i in 0..<msgs.count {
            var msg = msgs[i]
            if !msg.isOutgoing {
                // 获取用户信息
                myGroup.enter()
                UserManager.shared().getUser(by: msg.fromId) { (user) in
                    msg.user = user
                    //                    messages.append(msg)
                    myGroup.leave()
                }

                // 如果是群聊则获取群成员信息
                if !self.session.isPrivateChat, let serverUrl = chatServerUrl {
                    myGroup.enter()
                    GroupManager.shared().getMember(
                        by: self.session.id.idValue.intEncoded, memberId: msg.fromId,
                        serverUrl: serverUrl
                    ) { (member) in
                        msg.member = member
                        //                        messages.append(msg)
                        myGroup.leave()
                    }
                }

                messages.append(msg)

            } else {
                messages.append(msg)
            }
        }

        myGroup.notify(queue: .main) {
            FZMLog("遍历结束")
        }

        return messages

        //        msgs.forEach { (msg) in
        //            if !msg.isOutgoing {
        //                UserManager.shared().getUser(by: msg.fromId) { (user) in
        //                    var newMsg = msg
        //                    newMsg.user = user
        //                    messages.append(newMsg)
        //                }
        //            } else {
        //                messages.append(msg)
        //            }
        //        }
        //
        //        return messages
    }

    private func setRX() {
        //        // 自己聊天服务器地址变化订阅
        //        LoginUser.shared().chatServerGroupsSubject.subscribe(onNext: {[unowned self] (_) in
        //            // 获取当前发送消息的聊天服务器地址
        //            self.setChatServerUrl()
        //        }).disposed(by: self.bag)

        // 网络状态变化订阅
        APP.shared().hasNetworkSubject.subscribe(onNext: { [weak self] (hasNetwork) in
            guard let strongSelf = self else { return }
            FZMLog("networkListener 收到网络变化 hasNetwork -- \(hasNetwork)")
            if hasNetwork && strongSelf.session.id.isPersonChat {
                guard let url = strongSelf.chatServerUrl, !url.isBlank else {  // 如果聊天服务器地址为空则重新获取
                    // 获取用户员工信息以及企业信息以获取对方的聊天服务器
                    strongSelf.getStaffInfoRequest()
                    return
                }
            }
        }).disposed(by: bag)

        // 发送消息订阅 消息发送结果
        MultipleSocketManager.shared().sendMsgStatusSubject.subscribe(onNext: {
            [weak self] (sendMsgStatus) in
            guard let self = self else { return }
            // 消息发送回执-修改消息发送状态
            switch sendMsgStatus {
            case .failed(let msgId):
                self.changeMsgStatus(msgId: msgId, status: .failed)
            case .success(let data):
                self.changeMsgStatus(msgId: data.msgId, logId: data.logId, status: .sent)
            case .delivered(let logIds):
                logIds.forEach { (logId) in
                    self.changeMsgStatus(logId: logId, status: .delivered)
                }
            }
        }).disposed(by: self.bag)

        // 收到消息订阅
        MultipleSocketManager.shared().receiveMsgsSubject.subscribe(onNext: { [weak self] (msgs) in
            guard let self = self else { return }

            // 🔴 黑名单用户的消息不显示（产品语义）。
            //    入库那层（`ChatManager.save`）已经按发送者过滤掉了，这里再兵一道：
            //    防止其他路径（如本地回写、多端同步）把黑名单消息流到界面上。
            let myMsgs = msgs.compactMap { (msg) -> Message? in
                if msg.fromId != LoginUser.shared().address {
                    if self.userInfo?.isShield == true { return nil }
                    if let user = UserManager.shared().user(by: msg.fromId), user.isShield == true { return nil }
                }
                return msg
            }.filter { $0.sessionId == self.session.id && !self.messageArray.contains($0) }

            guard myMsgs.count > 0 else { return }

            let newMsgs = self.getMsgsUsers(msgs: myMsgs)

            self.insertAndSendMessages(newMsgs)

        }).disposed(by: self.bag)

        // 接收用户/群免打扰和昵称等详情信息变化通知
        FZM_NotificationCenter.addObserver(
            self, selector: #selector(refreshSessionInfo), name: FZM_Notify_SessionInfoChanged,
            object: nil)

        // 接收聊天文件页面删除文件通知
        FZM_NotificationCenter.addObserver(
            self, selector: #selector(handleDeleteChatMsgs), name: FZM_Notify_DeleteChatMsgs,
            object: nil)

        // 接收撤回消息通知
        FZM_NotificationCenter.addObserver(
            self, selector: #selector(handleRevokeMsg), name: FZM_Notify_RevokeMsg,
            object: nil)

        // 图片解密完成 / 消息体被回写后刷新对应气泡
        // ⚠️ 图片下载超过 8s 兜底时间时，消息先按「加密 URL」落库（气泡是占位），
        //    解密完成后再把 cacheKey 写回库 —— 如果界面不跟着刷新，
        //    用户就会一直看到占位，以为「这张图没了」（用户 2026-11-02 反馈）。
        FZM_NotificationCenter.addObserver(
            self, selector: #selector(handleMsgContentUpdated(_:)),
            name: FZM_Notify_ChatMsgContentUpdated, object: nil)

        if !self.session.isPrivateChat {
            // 群信息更新通知
            FZM_NotificationCenter.addObserver(
                self, selector: #selector(refreshGroupDetailInfo),
                name: FZM_Notify_GroupDetailInfoChanged, object: nil)

            // 退出群聊通知（删群）
            FZM_NotificationCenter.addObserver(
                self, selector: #selector(deleteGroup), name: FZM_Notify_GroupDelete, object: nil)

            // 退出群聊通知（被踢出群）
            FZM_NotificationCenter.addObserver(
                self, selector: #selector(signoutGroup), name: FZM_Notify_GroupSignout, object: nil)

            // 加入群聊通知（被拉进群）
            FZM_NotificationCenter.addObserver(
                self, selector: #selector(signinGroup), name: FZM_Notify_GroupSignin, object: nil)

            // 用户信息更新通知
            FZM_NotificationCenter.addObserver(
                self, selector: #selector(refreshUserInfoNoti), name: FZM_Notify_RefreshUserInfo,
                object: nil)
        }
    }

    // 加入群聊通知更新UI（被拉进群）
    @objc private func signinGroup(notification: NSNotification) {
        // 判断有更新的是否是当前群
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat,
            groupId == self.session.id.idValue.intEncoded
        else {
            return
        }

        DispatchQueue.main.async {
            self.inputBarView.isHidden = false
            self.showRightBarButtonItem(true)
        }
    }

    // 退出群聊通知处理（被踢出群）
    @objc private func signoutGroup(notification: NSNotification) {
        // 判断有更新的是否是当前群
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat,
            groupId == self.session.id.idValue.intEncoded
        else {
            return
        }

        // 退出群聊更新UI
        self.handleQuitGroupAction()
    }

    // 已退出群聊通知处理
    @objc private func deleteGroup(notification: NSNotification) {
        // 判断有更新的是否是当前群
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat,
            groupId == self.session.id.idValue.intEncoded
        else {
            return
        }

        // 退出群聊更新UI
        self.handleQuitGroupAction()
    }

    // 退出群聊更新UI
    private func handleQuitGroupAction() {
        DispatchQueue.main.async {
            self.view.endEditing(true)
            self.inputBarView.isHidden = true
            self.showRightBarButtonItem(false)
        }
    }

    /// 消息体被回写（图片解密完成等）后刷新对应气泡。
    /// ⚠️ 图片下载超过 8s 兜底时间时会先按「加密 URL」落库（气泡显示占位），
    ///    解密完成后再把新 cacheKey 写回库；界面不刷新的话用户会一直看到占位，
    ///    以为「这张图没了」（用户 2026-11-02 反馈）。
    @objc func handleMsgContentUpdated(_ notification: NSNotification) {
        guard let msgId = notification.object as? String, !msgId.isEmpty else { return }
        guard let index = self.messageArray.firstIndex(where: { $0.msgId == msgId }) else { return }
        let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.msgId.is(msgId)
        })
        guard let row = rows.first else { return }
        // 保留展示用的 user / member（DB 里没有这两项）
        let old = self.messageArray[index]
        var newMsg = Message(with: row)
        newMsg.user = old.user
        newMsg.member = old.member
        self.messageArray[index] = newMsg
        self.reloadSectionSafely(index)
        FZMLog("【刷新气泡】msgId=\(msgId) index=\(index)")
    }

    // 聊天文件删除文件处理
    @objc func handleDeleteChatMsgs(notification: NSNotification) {
        guard let (sessionId, msgs) = notification.object as? (SessionID, [Message]),
            sessionId == self.session.id
        else {
            return
        }

        self.deleteMessages(msgs, needDeleteDB: false)
    }

    // 更新会话名称和免打扰状态
    @objc private func refreshSessionInfo(notification: NSNotification) {
        guard let address = notification.object as? String, address == self.session.id.idValue
        else {
            return
        }
        // 更新会话名称
        self.refreshSessionName()
    }

    // 用户信息更新（更新群聊发送者名字）
    @objc private func refreshUserInfoNoti(notification: NSNotification) {
        guard let address = notification.object as? String, !self.session.isPrivateChat else {
            return
        }

        if let user = UserManager.shared().user(by: address) {
            // ⚠️ 数组变更 + reload 收口到主线程加锁，避免和删除消息并发（同 changeMsgStatus）
            DispatchQueue.main.async {
                self.refreshListLock.lock()
                defer { self.refreshListLock.unlock() }

                if self.bottomUnReadMessageArray.count > 0 {
                    for i in 0..<self.bottomUnReadMessageArray.count {
                        if self.bottomUnReadMessageArray[i].fromId == address {
                            self.bottomUnReadMessageArray[i].user = user
                        }
                    }
                }
                if self.messageArray.count > 0 {
                    var indexArr = [Int]()
                    for i in 0..<self.messageArray.count {
                        if self.messageArray[i].fromId == address {
                            self.messageArray[i].user = user
                            indexArr.append(i)
                        }
                    }
                    for item in indexArr {
                        self.reloadSectionSafely(item)
                    }
                }
            }
        }
    }

    /// 群信息更新通知处理
    ///  --- 加群 退群 更新加群权限 更新群加好友权限 更新群禁言 更新群成员（管理权限变化） 更新禁言列表 更新群名 更新群头像
    @objc private func refreshGroupDetailInfo(notification: NSNotification) {
        // 判断有更新的是否是当前群聊
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat,
            groupId == self.session.id.idValue.intEncoded
        else {
            return
        }

        DispatchQueue.main.async {
            if let group = GroupManager.shared().getDBGroup(by: self.session.id.idValue.intEncoded)
            {
                self.groupDetailInfo = group
            }

            // 更新会话名称
            self.refreshSessionName()

            // 获取群详情请求
            self.refreshGroupInfoRequestInChatVC()
        }
    }

    /// 消息发送回执-修改消息发送状态 1. .sent 根据msgId更新status以及返回的logId 2. .failed 根据msgId更新status 3. .delivered 根据logid修改status
    private func changeMsgStatus(msgId: String = "", logId: Int = 0, status: Message.Status) {
        // ⚠️ 该回调可能来自 socket 线程：数组读写 + reload 全部收口到主线程并加锁，
        //    否则会和「多选删除」的模型变更并发，导致 reloadSections 拿到过期下标，
        //    UIKit 抛 Invalid batch updates 直接闪退（2026-10-19）。
        DispatchQueue.main.async {
            self.refreshListLock.lock()
            defer { self.refreshListLock.unlock() }

            guard self.messageArray.count > 0 else { return }

            for i in 0..<self.messageArray.count {
                switch status {
                case .sent:  // 已发送 更新status以及logId
                    if !msgId.isBlank, self.messageArray[i].msgId == msgId {
                        self.messageArray[i].status = status
                        self.messageArray[i].logId = logId
                        self.reloadSectionSafely(i)
                        return
                    }
                case .failed:  // 发送失败 更新status
                    if !msgId.isBlank, self.messageArray[i].msgId == msgId {
                        self.messageArray[i].status = status
                        self.reloadSectionSafely(i)
                        return
                    }
                case .delivered:
                    if logId > 0, self.messageArray[i].logId == logId {
                        self.messageArray[i].status = status
                        self.reloadSectionSafely(i)
                        return
                    }
                default:
                    break
                }
            }
        }
    }

    /// 预取红包消息的链上信息（只做查询/缓存，不改 UI）。
    /// 专属红包在消息体（pb）里没有标记，只能靠链上 `getRedPacket(...)` 的 `whitelistCount` 判断；
    /// 提前查掉能消掉「先显示拼手气红包、再跳成专属红包」的闪变（见 `RedPacketMessageCell.refreshTypeLabel`）。
    /// 只取最近几条：过期的红包 cell 反正不显示类型文字，没必要查。
    private func prefetchRedPacketInfos(_ messages: [Message], limit: Int = 6) {
        var ids = [String]()
        var seen = Set<String>()
        for msg in messages.reversed() {
            guard ids.count < limit else { break }
            // 只认红包消息：`redtxHash` 读的是 json["txHash"]，而**转账消息的 json 里也有 txHash**，
            // 不加这层判断会把转账的哈希当红包 ID 去查
            guard case .redPacket = msg.msgType else { continue }
            guard let txHash = msg.msgType.redtxHash, !txHash.isEmpty, seen.insert(txHash).inserted else { continue }
            ids.append(txHash)
        }
        ids.forEach { RedPacketWeb3Service.shared.prefetchRedPacketInfo(id: $0) }
    }

    // 插入到消息数据源并更新页面
    /// - Parameter didInsert: 消息真正插进列表后的回调。视频要先上屏再转码，
    ///   靠它拿到「补过阅后即焚标记 / 群成员信息」的同一份消息去发送。
    func insertAndSendMessages(
        _ messages: [Message], needSendMsg: Bool = false,
        didInsert: (([Message]) -> Void)? = nil
    ) {
        guard messages.count > 0 else { return }

        // 红包消息一进数据源就预取链上信息（专属红包在消息体里没有标记），
        // 提前查掉 ⇒ cell 上屏时缓存已就绪，首帧直接显示「专属红包」
        prefetchRedPacketInfos(messages)

        var messages = messages
        // 阅后即焚：处于该模式时给自己发出的、允许类型的私聊消息打标
        // （仅 isOutgoing，接收消息不会误标；允许：文本/图片/视频/语音/文件）
        if self.isBurnMode, self.session.isPrivateChat {
            for i in 0..<messages.count where messages[i].isOutgoing {
                switch messages[i].msgType {
                case .text, .image, .video, .audio, .file:
                    messages[i].isBurn = true
                    // 同步写入消息体 JSON，随消息持久化（不单靠新增的 DB 列）
                    messages[i].msgType = messages[i].msgType.markedAsBurn()
                default:
                    break
                }
            }
        }
        // 群聊需显示昵称和群成员
        if !self.session.isPrivateChat {
            //            var member: GroupMember?
            //            if let person = self.groupDetailInfo?.person {
            //                member = person
            //            } else {
            //                member = GroupMember.init(memberId: LoginUser.shared().address, memberMuteTime: 0, memberName: LoginUser.shared().nickName?.value ?? LoginUser.shared().address.shortAddress, memberType: 0, groupId: self.session.id.idValue.intEncoded)
            //            }

            func getMemberInfo(_ msg: Message) -> GroupMember? {
                var member: GroupMember?
                if msg.isOutgoing {
                    if let person = self.groupDetailInfo?.person {
                        member = person
                    } else if let dbMember = GroupManager.shared().getDBGroupMember(
                        with: self.session.id.idValue.intEncoded, memberId: msg.fromId)
                    {
                        member = dbMember
                    } else {
                        member = GroupMember.init(
                            memberId: LoginUser.shared().address, memberMuteTime: 0,
                            memberName: LoginUser.shared().nickName?.value
                                ?? LoginUser.shared().address.shortAddress, memberType: 0,
                            groupId: self.session.id.idValue.intEncoded)
                    }
                } else {
                    if let dbMember = GroupManager.shared().getDBGroupMember(
                        with: self.session.id.idValue.intEncoded, memberId: msg.fromId)
                    {
                        member = dbMember
                    } else {
                        member = GroupMember.init(
                            memberId: msg.fromId, memberMuteTime: 0,
                            memberName: msg.fromId.shortAddress, memberType: 0,
                            groupId: self.session.id.idValue.intEncoded)
                    }
                }

                return member
            }

            for i in 0..<messages.count {
                messages[i].member = getMemberInfo(messages[i])
            }
        }

        DispatchQueue.main.async {
            // 新到的消息可能就是某条引用消息在等的那条原消息 ⇒ 引用条缓存整体失效
            self.quotePreviewCache.removeAll()

            let newMsgs = ChatManager.shared().handleMsgsWithShowTimeFlg(msgs: messages)
            let startSection = self.messageArray.count
            let sections = IndexSet(startSection..<startSection + newMsgs.count)

            self.refreshListLock.lock()

            // 是否应该跟随底部。
            // ⚠️ 不能只靠 `isLastSectionVisible()`：连续到达两条消息时，第一条插入后
            //    collectionView 还没滚动完，第二条再判断会误判成「用户不在底部」
            //    ⇒ 第二条被塞进底部未读、界面不显示。用户看到的就是「两张图只显示一张」
            //    （2026-11-02 日志：两条图片相继 0.13s 落库，只出现一个气泡）。
            // 🔴 `isLastSectionVisible()` 依赖 `indexPathsForVisibleItems`，列表布局变化时
            //    会误判成「最后一条还可见」⇒ 用户明明往上翻了，却永远不显示「N 条新消息」
            //    （用户 2026-11-05 反馈）。这里改用**滚动位置**判断，更可靠。
            let isFollowingBottom = self.isNearBottom()
                || Date().timeIntervalSince1970 < self.followBottomUntil

            // 自己发的消息一律直接插到底部：`needSendMsg == false` 只代表「发送要延后」
            // （视频要先转码），不能因此把它塞进「N 条新消息」——用户刚点发送却没看到气泡
            let isSelfSent = messages.contains { $0.isOutgoing }

            if !isFollowingBottom && self.messageArray.count > 0 && !needSendMsg && !isSelfSent {  // 如果最新一条消息不在可见区域，底部显示 ***条新消息
                FZMLog("【插入】新消息进底部未读 \(newMsgs.count) 条（当前不在底部）")
                newMsgs.forEach { msg in
                    switch msg.msgType {
                    case .system, .text, .audio, .image, .video, .file, .forward, .RTCCall,
                        .transfer, .collect, .redPacket, .contactCard, .unknown:
                        self.bottomUnreadCount += 1
                    default: break
                    }
                }

                self.bottomUnReadMessageArray += newMsgs
                self.showBottomUnreadBtn()
            } else {

                self.messageArray += newMsgs
                // 延续「跟随底部」窗口：接下来 2 秒内到达的消息继续直接插入，
                // 不再因为「布局还没更新完」被塞进底部未读
                self.followBottomUntil = Date().timeIntervalSince1970 + 2

                // ⚠️ 数据源加了 newMsgs，但 collectionView 内部 section 数可能还是旧值
                // （典型场景：底部未读消息刚被并进 messageArray、整表刷新还没排到主线程，见 hideBottomUnreadBtn）。
                // 此时 insertSections 会被 UIKit 判成「Invalid number of sections」直接崩溃
                // （TestFlight 崩溃日志 ChatVC.swift:1110），所以先核对一次，对不上就退回整表刷新。
                if self.collectionView.numberOfSections != startSection {
                    self.collectionView.reloadData()
                    if needSendMsg || isSelfSent || self.isLastSectionVisible() {
                        self.collectionView.scrollToLastItem(animated: newMsgs.count <= 1)
                    }
                } else {
                    self.collectionView.performBatchUpdates(
                        {
                            self.collectionView.insertSections(sections)
                        },
                        completion: { [weak self] _ in
                            guard let self = self else { return }
                            if needSendMsg || isSelfSent || self.isLastSectionVisible() {
                                // 连续收到多条消息时一次插入多条，跳过逐条滚动动画避免卡顿
                                self.collectionView.scrollToLastItem(animated: newMsgs.count <= 1)
                            }
                            // ⚠️ 自己刚发出的消息插入完成后**重新量一次高度**：
                            //    `insertSections` 用的是插入那一刻的尺寸快照，带引用的消息如果那时没算上
                            //    引用条的高度，气泡下方的引用条会被 cell 边界裁掉（看着就是"没显示"），
                            //    直到重进页面重新布局才出现（用户 2026-11-04 反馈）。
                            if isSelfSent {
                                self.reloadSectionSafely(startSection + newMsgs.count - 1)
                                // 高度重新量完再滚一次：第一次滚动用的是插入前的尺寸，
                                // 带引用的消息会少滚 46pt ⇒ 引用条正好落在输入框下面，看着就是"没显示"
                                self.collectionView.layoutIfNeeded()
                                self.collectionView.scrollToLastItem(animated: false)
                                FZMLog("【引用】自己发出的消息插入完成，重载 section=\(startSection + newMsgs.count - 1) 共\(newMsgs.count)条")
                            }
                        })
                }
            }

            self.refreshListLock.unlock()

            // 数据处理完再发消息，否则消息发送回执完成处理数据时发送的消息数据可能还未插入到消息数据源
            if needSendMsg, let msg = messages.first {
                self.sendInsertedMessage(msg)
            }
            // 需要「先上屏、后发送」的场景（视频转码）靠它拿到真正要发的那一份
            // （已补过「阅后即焚」标记 / 群成员信息）
            didInsert?(messages)
        }
    }

    /// 把已经插进列表的消息交给 `ChatManager` 发送（落库 + 上传 + socket）
    private func sendInsertedMessage(_ msg: Message) {
        let serverUrl = self.chatServerUrl ?? ""
        if serverUrl.isBlank && self.session.id.isPersonChat {
            // 获取用户员工信息以及企业信息以获取对方的聊天服务器
            self.getStaffInfoRequest()
        }
        ChatManager.shared().send(msg: msg, chatServerUrl: serverUrl)
    }

    // 最新消息是否可见
    private func isLastSectionVisible() -> Bool {
        guard !self.messageArray.isEmpty else { return false }
        let lastIndexPath = IndexPath(item: 0, section: self.messageArray.count - 1)
        return self.collectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }

    /// 当前是否停在列表底部（按滚动位置判断，比 `indexPathsForVisibleItems` 可靠）。
    /// - Parameter threshold: 距底部多少 pt 以内算「在底部」
    private func isNearBottom(threshold: CGFloat = 60) -> Bool {
        let visibleHeight = self.collectionView.bounds.height
        let contentHeight = self.collectionView.contentSize.height
        guard contentHeight > visibleHeight else { return true }
        let maxOffset = contentHeight - visibleHeight + self.collectionView.contentInset.bottom
        return self.collectionView.contentOffset.y >= maxOffset - threshold
    }

    /// 安全刷新某个 section。
    ///
    /// ⚠️ 删了多条消息后，`messageArray` 已经变小、但 collectionView 可能还没来得及 reload；
    /// 这时任何 `reloadSections(旧下标)` 都会被 UIKit 当成一次 batch update（内部是 delete + insert），
    /// 一旦 section 数对不上就抛「Invalid batch updates detected: Delete section N, Insert section N」闪退
    /// （2026-10-19 多选删除崩溃）。⇒ 执行时重新校验两边下标，越界直接跳过。
    private func reloadSectionSafely(_ index: Int) {
        guard index >= 0,
              index < self.messageArray.count,
              index < self.collectionView.numberOfSections else {
            return
        }
        UIView.performWithoutAnimation {
            self.collectionView.reloadSections(IndexSet([index]))
        }
    }

    // 删除消息数据并更新页面
    func deleteMessages(_ messages: [Message], needDeleteDB: Bool? = true) {
        guard !messages.isEmpty, !self.messageArray.isEmpty else { return }

        DispatchQueue.main.async {
            // 兜底：不管从哪条路进来（多选删除 / 长按删除 / 别处调用），删完都不能留在多选态
            if self.showSelect { self.exitSelectMode() }
            // 诊断：区分「长按删单条（只删本地，服务端还有）」与「删除聊天记录（走 clean-private）」
            FZMLog("【删除消息】入口 session=\(self.session.id.idValue) 条数=\(messages.count) needDeleteDB=\(needDeleteDB ?? true) msgIds=\(messages.map { $0.msgId })")
            // 私聊的「长按删除 / 多选删除」：**改走撤回**（用户 2026-10-19 要求）——
            // 撤回成功后由 ChatManager 把本地这条消息**静默删除**，不生成「撤回了一条消息」提示。
            // 撤回不了的消息（本地未同步 / 通知类 / 发送中或失败）仍走原来的本地删除。
            var localTargets = messages
            if (needDeleteDB ?? true), self.session.isPrivateChat {
                let revokable = messages.filter { self.canRevokeByDelete($0) }
                if !revokable.isEmpty {
                    localTargets = messages.filter { msg in
                        !revokable.contains(where: { $0.msgId == msg.msgId })
                    }
                    self.revokeAsDelete(revokable)
                    if localTargets.isEmpty {
                        FZMLog("【删除消息】私聊删除改走撤回 \(revokable.count) 条，无需本地直删")
                        return
                    }
                }
            }
            // 私聊的「长按删除 / 多选删除」：本地删除之外，**服务端也要删掉这几条** ——
            // 否则之后任何一次从服务端拉取（开 App / 切账号重建缓存、上滑翻页）都会把删掉的消息写回来。
            // 文档只提供按时间范围的 clean-private ⇒ 用自定义时间把范围精确到这一条的毫秒时间戳。
            // ⚠️ 能撤回的消息已经在上面走撤回接口了，这里只剩撤回不了的（大多是服务端还没有的本地消息）
            if needDeleteDB ?? true {
                self.deleteServerRecordsIfNeeded(for: localTargets)
            }
            // ⚠️ 锁用 `defer` 释放：下面任何提前 `return` 都不能把锁留下（否则下次主线程 lock 直接死锁）
            self.refreshListLock.lock()
            defer { self.refreshListLock.unlock() }

            // 删除数据库消息数据并更新会话列表
            if needDeleteDB ?? true {
                ChatManager.shared().delete(messsages: localTargets)
            }

            for i in 0..<localTargets.count {
                let msg = localTargets[i]

                switch msg.msgType {
                case .image:
                    // 清除图片缓存
                    let fileName = "\(msg.msgType.cachekey ?? "")"
                    ChatMediaCache.removeImage(forKey: fileName)
                case .audio, .video, .file:
                    // 删除本地文件
                    let localFilePath = FZMMessageBaseVM.getFilePath(with: msg)
                    if FZMLocalFileClient.shared().isFileExists(atPath: localFilePath) {
                        let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: localFilePath)
                    }
                default:
                    // 暂不处理
                    FZMLog("删除其他类型消息暂不处理")
                }
            }

            // ⚠️⚠️ **必须先按「原下标」收集、再删模型**（不能边删边记下标：删掉前面的元素后，
            //     后面元素的下标会左移，两条消息撞到同一个下标时 `IndexSet` 会**去重**
            //     ⇒「让 collectionView 删的 section 数」≠「模型实际少掉的条数」⇒ 直接闪退。
            //     典型复现：`[A,B,C]` 里选中相邻的 A、B ⇒ indexs 记成 [0,0] → {0}）。
            // ⚠️⚠️ 并且只更新模型 + **整表刷新**，**不要**用 `performBatchUpdates + deleteSections`。
            //   两次闪退的教训（2026-10-13）：
            //    ① 拼 `IndexSet` 时若用「变化后的下标」，重复值会被去重 ⇒「让 collectionView 删的
            //       section 数」≠「模型实际少掉的条数」⇒ UIKit 校验不过，直接抛异常闪退；
            //    ② 即便下标来源正确，`deleteSections` 还要跟 collectionView **缓存的** section 数做校验，
            //       而聊天列表随时会被实时插入（socket 新消息 / 上滑翻页 / 未读合并都会改 messageArray），
            //       缓存值可能落后于 messageArray ⇒ 照样抛 `NSInternalInconsistencyException`；
            //       另外「全选删除」等于删光所有 section，本身也是老雷区。
            //    ⇒ 删消息一律整表刷新：没有计数校验，不可能因计数不一致崩（代价只是没有删除动画）。
            var indexs = IndexSet()
            for msg in localTargets where self.messageArray.contains(msg) {
                guard let index = self.messageArray.firstIndex(where: { $0 == msg }) else { continue }
                indexs.insert(index)
            }
            // 按原下标**从大到小**删：这样删除过程中下标不会左移
            for index in indexs.reversed() {
                guard index < self.messageArray.count else { continue }
                self.messageArray.remove(at: index)
            }
            FZMLog("【删除消息】模型已删 \(indexs.count) 条，剩余 \(self.messageArray.count) 条 ⇒ 整表刷新")

            // ⚠️ 模型变更与 reloadData 必须**同步**完成（不能再用异步的 `reloadList`）：
            //    中间态里若有一条 `reloadSections(旧下标)`（发送回执 / 撤回 / 刷新名片）执行，
            //    UIKit 会按「缓存 section 数 vs 数据源 section 数」校验并抛
            //    「Invalid batch updates detected: Delete section N, Insert section N」闪退（2026-10-19）。
            self.collectionView.reloadData()

            // 滚动放到下一个主队列轮回（此时已按新数据源完成布局）
            DispatchQueue.main.async {
                // `indexPathsForVisibleItems` 此时才是新列表的
                guard self.isLastSectionVisible() else { return }
                self.collectionView.scrollToLastItem(animated: true)
            }
            // 锁由上面的 `defer` 释放
        }
    }

    /// 私聊「删除」能否改走撤回：必须是已同步到服务端的私聊普通消息
    /// （通知类不撤回；发送中/失败的消息服务端可能还没存）
    private func canRevokeByDelete(_ msg: Message) -> Bool {
        guard self.session.isPrivateChat, msg.channelType == .person else { return false }
        if case .notification = msg.kind { return false }
        guard msg.status == .sent || msg.status == .delivered else { return false }
        guard let logId = msg.logId, logId > 0 else { return false }
        return true
    }

    /// 私聊「删除」：逐条调撤回接口。撤回成功后 ChatManager 会**静默删除**本地消息
    /// （不显示「撤回了一条消息」的提示，直接移除气泡）；失败则消息保持原样并提示。
    private func revokeAsDelete(_ messages: [Message]) {
        guard let serverUrl = chatServerUrl, !serverUrl.isBlank else {
            self.showToast(L("撤回失败，聊天服务器地址为空"))
            return
        }
        for msg in messages {
            ChatManager.shared().revokeThenDelete(
                message: msg,
                chatServerUrl: serverUrl,
                successBlock: {
                    FZMLog("【删除消息】撤回成功，静默删除 msgId=\(msg.msgId)")
                },
                failureBlock: { [weak self] error in
                    guard let self = self else { return }
                    FZMLog("【删除消息】撤回失败 msgId=\(msg.msgId)：\(error.localizedDescription)")
                    self.showToast(L("删除失败，请稍后重试"))
                }
            )
        }
    }

    /// 私聊消息的**服务端同步删除**：`clean-private` + 自定义时间（startTime = endTime = 该条消息时间）。
    ///
    /// 为什么不直接"以服务端为准"就完事：单条删除文档没给接口，只能借时间范围接口把范围收到这一条 ——
    /// 服务端 `createTime` 与本地 `datetime` 是同一个毫秒值（历史记录就是用服务端 createTime 落的库），
    /// 所以能精确命中这一条。群聊 / 本地还没同步出去（没有 logId）的消息跳过：服务端没有可删的。
    private func deleteServerRecordsIfNeeded(for messages: [Message]) {
        guard self.session.isPrivateChat else { return }
        let targetId = self.session.id.idValue
        for msg in messages {
            guard msg.channelType == .person else { continue }   // 保守：只处理私聊消息
            guard let logId = msg.logId, logId > 0 else {
                FZMLog("【删除记录】本条服务端还没存（logId 无效），只删本地 msgId=\(msg.msgId)")
                continue
            }
            let time = msg.datetime
            // ⚠️ `startTime == endTime` 会被服务端判为 `custom date range invalid`（2026-10-10 实测）：
            //    必须是一个**有效的区间** ⇒ 给这条消息前后各留 1 秒窗口。
            //    窗口作用：① 满足服务端的区间校验；② 吸收服务端 createTime 与本地 datetime 的毫秒级偏差
            //   （窗口太小时偏差会漏掉 ⇒ 接口成功但那条没删掉，重进 App 又冒出来）。
            //    代价：这 2 秒内的其它消息会一起被删（聊天气泡间隔通常远大于 1 秒，概率很低）。
            let startTime = time - 1000
            let endTime = time + 1000
            FZMLog("【删除记录】单条服务端删除 targetId=\(targetId) logId=\(logId) datetime=\(time) range=[\(startTime), \(endTime)]")
            ChatRecordAPI.cleanPrivate(targetId: targetId, dateOpt: .custom,
                                       startTime: startTime, endTime: endTime,
                                       successBlock: { (_) in
                FZMLog("【删除记录】单条服务端删除成功 logId=\(logId)")
            }, failureBlock: { (error) in
                // 失败后果：服务端还留着这条，之后拉取（重建缓存 / 翻页）会把它写回本地
                FZMLog("【删除记录】单条服务端删除失败 logId=\(logId)：\(error.localizedDescription)")
            })
        }
    }
    
    // 撤回消息（发送撤回请求）
    func revokeMessage(_ msg: Message) {
        guard let serverUrl = chatServerUrl, !serverUrl.isBlank else {
            self.showToast(L("撤回失败，聊天服务器地址为空"))
            return
        }
        ChatManager.shared().revoke(message: msg, chatServerUrl: serverUrl)
    }
    
    // 处理撤回消息通知（UI 层：更新当前页面显示；DB 层由 ChatManager 全局处理）
    @objc func handleRevokeMsg(notification: NSNotification) {
        guard let pbMsg = notification.object as? PbMsg_ActionRevoke else { return }
        
        let logId = Int(pbMsg.logID)
        
        DispatchQueue.main.async {
            self.refreshListLock.lock()
            defer { self.refreshListLock.unlock() }
            
            guard let index = self.messageArray.firstIndex(where: { $0.logId == logId }) else {
                // 【诊断】焚毁信令到了、但当前页面列表里没有这条（不在这个会话 / 还没加载）
                if pbMsg.reason == .burned {
                    FZMLog("【焚毁】UI 未命中 logId=\(logId) 当前会话=\(self.session.id.idValue) 列表=\(self.messageArray.count)条")
                }
                return
            }
            
            self.clearLocalCache(for: self.messageArray[index])
            
            // 从 DB 读取已更新的消息（由 ChatManager.setRevokeObserver 全局更新）
            if let updatedMsg = ChatManager.shared().getMessage(byLogId: logId) {
                self.messageArray[index] = updatedMsg
            }
            
            UIView.performWithoutAnimation {
                self.reloadSectionSafely(index)
            }
        }
    }
    
    // 清理撤回消息的本地缓存
    private func clearLocalCache(for msg: Message) {
        switch msg.msgType {
        case .image:
            if let cacheKey = msg.msgType.cachekey {
                ChatMediaCache.removeImage(forKey: cacheKey)
            }
        case .audio, .video, .file:
            let filePath = FZMMessageBaseVM.getFilePath(with: msg)
            if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
                let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: filePath)
            }
        default:
            break
        }
    }
}

//MARK: - 网络请求
extension ChatVC {
    // 获取用户员工信息
    private func getStaffInfoRequest() {
        guard FZM_EnableEnterpriseFeature else { return }// 企业号功能关闭，不发员工信息请求
        // 是否正在请求员工信息判断
        guard !isGettingStaffInfoRequest else {
            return
        }
        isGettingStaffInfoRequest = true
        // 员工信息是否已成功获取过判断
        guard !isGetStaffInfoReuqestSuccess else {
            // 获取用户企业信息
            self.getTeamInfoRequest()
            return
        }
        TeamManager.shared().getStaffInfo(address: self.session.id.idValue) { [weak self] (info) in
            guard let strongSelf = self else { return }
            strongSelf.isGetStaffInfoReuqestSuccess = true
            strongSelf.isGettingStaffInfoRequest = false
            strongSelf.staffInfo = info

            // 获取用户企业信息
            strongSelf.getTeamInfoRequest()

        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.isGettingStaffInfoRequest = false
            //            strongSelf.showToast("获取员工信息失败")
        }
    }

    // 获取用户企业信息
    private func getTeamInfoRequest() {
        guard FZM_EnableEnterpriseFeature else { return }// 企业号功能关闭，不发企业信息请求
        guard let staffInfo = staffInfo else {
            return
        }
        guard !isGetTeamInfoReuqestSuccess else {
            // 获取当前发送消息的聊天服务器地址
            self.setChatServerUrl()
            return
        }
        TeamManager.shared().getEnterPriseInfo(
            entId: staffInfo.entId,
            successBlock: { [weak self] (teamInfo) in
                guard let strongSelf = self else { return }
                strongSelf.isGetTeamInfoReuqestSuccess = true
                strongSelf.staffInfo?.company = teamInfo

                // 获取当前发送消息的聊天服务器地址
                strongSelf.setChatServerUrl()

            },
            failureBlock: { (error) in
                //            guard let strongSelf = self else { return }
                //            strongSelf.showToast("获取企业信息失败")
            })
    }

    // 获取用户详情请求
    private func refreshUserInfoRequestInChatVC() {
        UserManager.shared().getNetUser(targetAddress: self.session.id.idValue) {
            [weak self] (user) in
            guard let strongSelf = self else { return }
            if strongSelf.userInfo?.avatarURLStr != user.avatarURLStr {
                DispatchQueue.main.async {
                    strongSelf.collectionView.reloadData()
                }
            }
            strongSelf.userInfo = user

            // 刷新用户昵称
            strongSelf.refreshSessionName()

            // 获取当前发送消息的聊天服务器地址
            strongSelf.setChatServerUrl()
        } failureBlock: { (error) in
            FZMLog("refreshUserInfoRequestInChatVC error : \(error)")
        }
    }

    // 获取群详情请求
    private func refreshGroupInfoRequestInChatVC() {
        // ⚠️ 原来 `guard let group = self.groupDetailInfo` 在「本地 DB 没这个群」时会直接 return，
        //    页面就停在「空聊天页 + 输入条隐藏」——用户看到的就是「进入群聊失败」。
        //    这里放宽：只要有群 id，就去服务器拉一次详情。
        let groupId: Int
        if let group = self.groupDetailInfo {
            groupId = group.id
        } else {
            groupId = self.session.id.idValue.intEncoded
        }
        guard let serverUrl = chatServerUrl, !serverUrl.isBlank else {
            FZMLog("进入群聊：群 \(groupId) 拿不到聊天服务器地址，无法拉群详情")
            return
        }
        GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: groupId) {
            [weak self] (group) in
            guard let strongSelf = self else { return }
            strongSelf.groupInfoRetryCount = 0
            strongSelf.groupDetailInfo = group
            // 拉到群详情 ⇒ 本地就有这个群了，把输入条 / 右上角入口恢复
            //（本地没群时 viewDidLoad 是隐藏的，不恢复就一直是空聊天页）
            strongSelf.inputBarView.isHidden = false
            strongSelf.showRightBarButtonItem(group.isInGroup)
            //刷新禁言信息
            strongSelf.refreshBannedInfo()

            // 更新会话名称
            strongSelf.refreshSessionName()

            // 本地没有群信息时，服务器地址是这次才拿到的 —— 补一次「连 socket + 补拉离线消息」
            strongSelf.triggerGroupOfflineSyncIfNeeded()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }

            let error = error as NSError
            FZMLog("refreshGroupInfoRequestInChatVC error : code=\(error.code) \(error.localizedDescription)")

            // 本地已经有群信息（能看历史、能发消息）时，网络抖动不要直接锁死输入框：
            // 自动重试一次，真的拉不到才收起输入条并提示。
            if strongSelf.groupDetailInfo != nil, strongSelf.groupInfoRetryCount < 1 {
                strongSelf.groupInfoRetryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    strongSelf.refreshGroupInfoRequestInChatVC()
                }
                return
            }

            if strongSelf.groupDetailInfo == nil {
                // 本地没群信息、又拉不到：保持不可发送，但要给用户一句能看懂的提示
                //（原来是直接弹服务端原文，用户看就是「进入群聊失败」）
                strongSelf.view.endEditing(true)
                strongSelf.inputBarView.isHidden = true
                strongSelf.showRightBarButtonItem(false)
                strongSelf.showToast(L("内容加载失败，请检查网络后重试"))
            } else {
                strongSelf.showToast(error.localizedDescription)
            }
        }
    }

    // 获取群成员列表请求
    private func getGroupMemberListRequest() {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        GroupManager.shared().getGroupMemberList(serverUrl: serverUrl, groupId: info.id) {
            [weak self] (members) in
            guard let strongSelf = self else { return }

            strongSelf.groupDetailInfo?.members = members
        } failureBlock: { (error) in
            FZMLog("getGroupMemberListRequestInChatVC error : \(error.localizedDescription)")
        }
    }
}

//MARK: - 未读消息（顶部/底部） XXX条新消息
extension ChatVC {

    // 获取所有未读消息数据
    func loadAllUnreadMessage(compeletionBlock: @escaping NormalBlock) {
        if self.messageArray.count >= self.topUnreadCount {
            compeletionBlock()
        } else {  // 未读消息超过当前消息数据（进页面一次取20条）则获取所有未读消息
            // 按真实未读数一次补齐，不设上限（和首屏保持一致）
            let count = self.topUnreadCount - self.messageArray.count + 1

            let newMsgInDB = self.getHistoryMsgs(count: count)

            // ⚠️ 和 hideBottomUnreadBtn 同理：数据源变更必须和 reloadData 在同一个主线程块里完成。
            // 原实现是「先更新 messageArray、reloadData 等下一轮」（reloadList 内部是 async），
            // 中间态里若 insertAndSendMessages 的 performBatchUpdates{insertSections} 执行，
            // UIKit 会抛「Invalid number of sections」崩溃（TestFlight 崩溃日志 ChatVC.swift:1110）。
            DispatchQueue.main.async {
                self.refreshListLock.lock()
                let freshMsgs = self.dedupedHistoryMsgs(newMsgInDB)
                if freshMsgs.count > 0 {
                    self.messageArray = freshMsgs + self.messageArray
                }
                self.collectionView.reloadData()
                self.refreshListLock.unlock()
                compeletionBlock()
            }
        }
    }

    // 刷新列表
    func reloadList(completionBlock: NormalBlock? = nil) {
        DispatchQueue.main.async {
            self.refreshListLock.lock()
            self.collectionView.reloadData()
            self.refreshListLock.unlock()
            completionBlock?()
        }
    }

    // 顶部未读消息视图点击事件
    func topUnreadBtnPress() {
        self.loadAllUnreadMessage { [weak self] in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                strongSelf.refreshListLock.lock()

                if strongSelf.topUnreadCount > 0,
                    strongSelf.topUnreadCount <= strongSelf.messageArray.count
                {
                    strongSelf.collectionView.scrollToSpecifiedItem(at: strongSelf.topUnreadCount)
                } else {
                    strongSelf.collectionView.scrollToFirstItem()
                }

                strongSelf.refreshListLock.unlock()
                strongSelf.hideTopUnreadBtn()
            }
        }
    }

    // 显示顶部未读消息视图
    func showTopUnreadBtn() {
        guard self.topUnreadBtn.frame.origin.x == k_ScreenWidth, self.topUnreadCount != 0 else {
            return
        }
        // ⚠️ 放在**导航栏下方**：聊天页导航栏是不透明的，原来的 y=15 会被整块挡住（用户反馈看不见）
        let y = self.view.safeAreaInsets.top + 8
        UIView.animate(withDuration: 0.3) {
            self.topUnreadBtn.frame = CGRect.init(
                x: k_ScreenWidth - self.topUnreadBtn.bounds.width,
                y: y, width: self.topUnreadBtn.width,
                height: self.topUnreadBtn.height)
        }
    }

    // 隐藏顶部未读消息视图
    func hideTopUnreadBtn() {
        self.topUnreadCount = 0
        guard self.topUnreadBtn.frame.origin.x != k_ScreenWidth else {
            return
        }
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.topUnreadBtn.frame = CGRect.init(
                    x: k_ScreenWidth, y: self.topUnreadBtn.frame.origin.y,
                    width: self.topUnreadBtn.width, height: self.topUnreadBtn.height)
            }
        ) { (_) in
            self.topUnreadBtn.removeFromSuperview()
        }
    }

    // 底部未读消息视图点击事件
    func bottomUnreadBtnPress() {
        self.refreshListLock.lock()
        //        self.messageListView.scrollToRow(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        self.collectionView.scrollToLastItem(animated: true)
        self.refreshListLock.unlock()
        self.hideBottomUnreadBtn()
    }

    // 显示底部未读消息视图
    func showBottomUnreadBtn() {
        guard self.bottomUnreadBtn.frame.origin.y == k_ScreenHeight, self.bottomUnreadCount != 0
        else {
            return
        }
        UIView.animate(withDuration: 0.4) {
            self.bottomUnreadBtn.alpha = 1
            self.bottomUnreadBtn.frame = CGRect.init(
                x: self.bottomUnreadBtn.frame.origin.x,
                y: self.inputBarView.frame.origin.y - self.bottomUnreadBtn.height - 15,
                width: self.bottomUnreadBtn.width, height: self.bottomUnreadBtn.height)
        }
    }

    // 隐藏底部未读消息视图
    func hideBottomUnreadBtn() {
        // ⚠️ 「把未读消息并进数据源」和「reloadData」必须落在同一个主线程块里：
        // 原实现是同步合并 messageArray，而 reloadData 要等下一轮主线程（reloadList 内部是 async），
        // 这一轮的中间态 = messageArray 已经变长、collectionView 内部 section 数还是旧值；
        // 只要这一轮里又来了一条新消息，insertAndSendMessages 的
        // performBatchUpdates{insertSections} 就会拿新的 count 去算插入位置，
        // UIKit 直接抛「Invalid number of sections」崩溃（TestFlight 崩溃日志 ChatVC.swift:1110）。
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            if (strongSelf.bottomUnreadBtn.frame.origin.y == k_ScreenHeight)
                && (strongSelf.bottomUnReadMessageArray.count == 0)
            {
                return
            }

            strongSelf.refreshListLock.lock()
            if strongSelf.bottomUnReadMessageArray.count > 0 {
                strongSelf.messageArray += strongSelf.bottomUnReadMessageArray
                strongSelf.bottomUnReadMessageArray.removeAll()
            }
            strongSelf.collectionView.reloadData()
            strongSelf.collectionView.scrollToLastItem()
            strongSelf.refreshListLock.unlock()

            UIView.animate(
                withDuration: 0.4,
                animations: {
                    strongSelf.bottomUnreadBtn.alpha = 0
                    strongSelf.bottomUnreadBtn.frame = CGRect.init(
                        x: strongSelf.bottomUnreadBtn.frame.origin.x, y: k_ScreenHeight,
                        width: strongSelf.bottomUnreadBtn.width,
                        height: strongSelf.bottomUnreadBtn.height)
                },
                completion: { (_) in
                    strongSelf.bottomUnreadCount = 0
                })
        }
    }
}

//MARK: - InputBarViewDelegate
extension ChatVC: InputBarViewDelegate {

    func inputBarView(_ inputBarView: InputBarView, sendText text: String, mentionIds: [String]) {
        //         self.sendTextNotifityMsg(text: text)
        // 引用的清理在 `sendTextMsg` → `takeReferenceForSending()` 里做
        self.sendTextMsg(text: text, mentionIds: mentionIds)
    }

    func audioBarView(
        _ inputBarView: InputBarView, amrPath: String, wavPath: String, duration: Double
    ) {
        self.sendAudioMsg(amrPath: amrPath, wavPath: wavPath, duration: duration)
    }

    // 删除引用
    func inputBarViewDeleteReference() {
        self.referenceMsg = nil
    }
}

extension ChatVC: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        return self
    }

    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        print("Dismissed!!!")
        documentInteractionController = nil
    }
}

/*
extension ChatVC: URLSessionDelegate, URLSessionDownloadDelegate {
    // 语音、视频、文件下载回调
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        let curMsg = self.curTapMsg

        let fileData : Data = FileManager.default.contents(atPath: location.path)!
        let address = curMsg?.sessionId.isPersonChat ?? true ? curMsg?.fromId : curMsg?.targetId
        ChatManager.getPublickey(by: address! , isGetUserKey: curMsg?.sessionId.isPersonChat ?? true) { (pubkey) in

            var fromFilePath = location.path

            var filePath = ""
            var fileName = "\(curMsg?.msgType.cachekey ?? "")"

            if !pubkey.isBlank {// 有公钥需解密
                let semaphore = DispatchSemaphore.init(value: 0)
                DispatchQueue.global().async {
                    // 解密
                    let decryptData = ChatManager.decryptUploadData(fileData, publickey: pubkey, isEncryptPersionChatData: curMsg?.sessionId.isPersonChat ?? false)

                    // 转存本地临时文件
                    if decryptData.count > 0, let filePath = FZMLocalFileClient.shared().createFile(with: .tmp(fileName: fileName)), FZMLocalFileClient.shared().saveData(decryptData, filePath: filePath) {
                        fromFilePath = filePath
                    }
                    semaphore.signal()
                }
                semaphore.wait()//等待异步任务执行完成才可以继续执行
                FZMLog("文件解密结束，继续下一步操作")
            }

            //视频==1   文件==2  语音==3
            if self.videoOrFile == 1 {
                filePath = DocumentPath.appendingPathComponent("Video/\(fileName).MOV")
            } else if self.videoOrFile == 2 {
                // "Documents/File/166298AE-8DD1-425E-9F34-1C428EDA5076/私聊文件PDF类型.pdf"
                if let name = curMsg?.msgType.fileName {
                    fileName = fileName + "/\(name)"
                }
                filePath = DocumentPath.appendingPathComponent("File/\(fileName)")
            } else if self.videoOrFile == 3 {
                // 浏览器不支持amr，改为上传wav格式，安卓aac格式
                // ?? 本地存储是否需要区分wav格式和aac格式 ??

//                let path = "Voice/AmrFile/\(fileName).amr"
                let path = "Voice/WavFile/\(fileName).wav"
                filePath = DocumentPath.appendingPathComponent(path)
            }

            // 转存成功
            if FZMLocalFileClient.shared().move(fromFilePath: fromFilePath, toFilePath: filePath) {

                if self.videoOrFile == 1 {// 视频
                    // 获取视频封面
                    self.getVideoCoverImage(cell: self.curTapMediaCell, url: URL.init(fileURLWithPath: filePath), fileName: fileName)

                    // 记录视频本地路径，播放视频页面保存时使用
                    self.saveToAlUrl = filePath

                    // 视频下载icon更换为播放icon
                    self.curTapMediaCell?.updateSatus()

                    // 播放视频
                    self.playVideoWithUrl(fileUrl: filePath)

                } else if self.videoOrFile == 2 {// 文件

                    self.showPDF(url: URL.init(fileURLWithPath: filePath))

                } else {// 语音

                    if let msg = self.curTapMsg {
                        VoiceMessagePlayerManager.shared().playVoice(msg: msg)
                    } else {
                        self.showToast(L("语音播放失败"))
                        FZMLog("---语音播放失败，self.curTapMsg 为空---")
                    }
                }

            } else {
                self.showToast(L("下载文件保存到本地沙盒失败"))
                FZMLog("下载文件保存到本地沙盒失败 fileName \(fileName)")
            }
        }
    }

    // 从下载的视频文件中获取视频封面
    func getVideoCoverImage(cell: MediaMessageCell?, url: URL, fileName: String) {
        // 获取视频第一帧作为封面
        UIImage.getVideoCropPicture(url) { (image) in
            guard let image = image else {
                // 封面拿不到就不打扰用户了（只是列表里少个缩略图），仅留日志
                FZMLog("视频封面获取出错")
                return
            }
            // 缓存封面图片
            ChatMediaCache.store(image, forKey: fileName)

            cell?.updateSatusAndImage(image)
        }


//        let asset = AVURLAsset.init(url: url)
//        let gen = AVAssetImageGenerator.init(asset: asset)
//        gen.appliesPreferredTrackTransform = true
//        gen.apertureMode = .encodedPixels
//        let time = CMTimeMakeWithSeconds(0.0, preferredTimescale: 1)
//        var actualTime : CMTime = CMTimeMakeWithSeconds(0, preferredTimescale: 0)
//        do {
//            let imageCG = try gen.copyCGImage(at: time, actualTime: &actualTime)
//            let image = UIImage.init(cgImage: imageCG)
//
//            // 判断图片是否存在
//            if image.imageIsEmpty() {
//                // 缓存封面图片
//                ChatMediaCache.store(image, forKey: fileName)
//
//                cell?.updateSatusAndImage(image)
//            }
//        } catch let error {
//            print(error)
//            self.showToast("视频封面获取失败")
//            FZMLog("视频封面获取出错")
//        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        let progress : CGFloat!
        let num1 : CGFloat = CGFloat(totalBytesWritten)
        let num2 : CGFloat = CGFloat(totalBytesExpectedToWrite)
        progress = CGFloat(num1 / num2)
        if self.videoOrFile == 1 {
            self.curTapMediaCell?.updateDownLoadProcress(proress: progress)
        } else if self.videoOrFile == 2 {
//            self.curTapFileCell?.updateDownLoadProcress(proress: progress)
        } else {

        }
    }
}
*/

//MARK: - MoreItemClickDelegate
extension ChatVC: MoreItemClickDelegate {

    /// 阅后即焚：切换会话级发送模式（离开会话自动关闭）
    func burnCtrl() {
        guard self.session.isPrivateChat else { return }
        self.isBurnMode.toggle()
        self.moreBarView.setBurnSelected(self.isBurnMode)
        self.inputBarView.setBurnMode(self.isBurnMode)
        self.showToast(self.isBurnMode ? L("已开启阅后即焚") : L("已关闭阅后即焚"))
    }

    /// 发起聊天室：先弹「视频聊天 / 语音聊天」模式选择 → 建房 → 把房间链接发到当前会话 → 自己直接进房
    ///
    /// 依据 H5 对接文档：App 先 `POST /api/v1/room/create` 拿服务端生成的房间号 + PIN，
    /// 再拼链接发给对方（**App 端不自造房间参数** —— 校验、撞号重试、PIN 限流都在服务端）。
    /// 建房时只带 `owner`（房主地址），**不绑 `user_addr`**，所以对方凭 room + PIN 即可进房。
    /// 模式在**建房时定死**（`VoiceRoomMode`），所以弹窗选完才建房。
    func sendVoiceRoom() {
        // 进房身份 = 当前钱包 0x 地址（H5 侧靠 `window.H5Wallet.getAddress()` 取，
        // 地址桥由 `VoiceRoomWebSupport` 注入）。未登录 / 未创建钱包时返回空串。
        guard !VoiceRoomWebSupport.currentWalletAddress().isEmpty else {
            self.showToast(L("请先登录"))
            return
        }
        guard VoiceRoomService.siteURL != nil else {
            self.showToast(L("房间服务未配置"))
            FZMLog("语音房：VoiceRoomBaseURL / VoiceRoomSiteURL 均为空，无法建房")
            return
        }
        // 微信风格的底部弹窗：语音聊天 / 取消（「视频聊天」一项已按用户要求去掉）
        VoiceRoomModeSheet.show(from: self) { [weak self] mode in
            guard let self = self, let mode = mode else { return }
            self.createVoiceRoom(mode: mode)
        }
    }

    /// 建房 → 发邀请消息 → 进房（模式已由 `sendVoiceRoom()` 弹窗选定）
    private func createVoiceRoom(mode: VoiceRoomMode) {
        let address = VoiceRoomWebSupport.currentWalletAddress()
        guard !address.isEmpty else {
            self.showToast(L("请先登录"))
            return
        }

        self.showProgress(with: nil)
        Task { @MainActor in
            do {
                let room = try await VoiceRoomService.createRoom(owner: address, mode: mode)
                self.hideProgress()
                guard let link = VoiceRoomService.roomLink(room: room.room, pin: room.pin, mode: mode) else {
                    self.showToast(L("房间创建失败"))
                    return
                }
                // ① 把**邀请文案 + 房间链接**作为一条文本消息发到当前会话。
                //    ⚠️ 链接必须留在正文里：气泡是「整条文本」响应点击、取第一段 http/https 链接
                //       （`ChatVC.firstLink`），只发文案的话就没有可点的链接了。
                //    称呼 = 发起人的**真实昵称**（`VoiceRoomWebSupport.currentDisplayName()`：昵称 → 短地址）。
                //    ⚠️ 2026-10-20 用户要求改：以前固定写「我」，别人收到看到的也是「我 发起了语音」。
                //    现在正文写真实昵称；**自己发的**在展示层把开头昵称换成「我」
                //    （`VoiceRoomInvite.displayText(for:)`），别人看到的就是发起点的人名。
                //    文案分**模式（语音 / 视频）× 会话类型（私聊 / 群聊）**，见 `VoiceRoomService.inviteText`。
                //    照 `sendTransferMsg` 的写法（而不走 `sendTextMsg`）—— 后者会把「引用消息」
                //    一并带上，建房发出去的消息不需要引用；但群聊的 @所有人 要**手动补**（见下）。
                let displayName = VoiceRoomWebSupport.currentDisplayName()
                let inviteText = VoiceRoomService.inviteText(
                    mode: mode, isPrivateChat: self.session.isPrivateChat,
                    name: displayName.isEmpty ? L("我") : displayName)
                    + "\n" + link.absoluteString
                var msg = Message.init(
                    fromId: LoginUser.shared().address, sessionId: self.session.id,
                    msgType: .init(text: inviteText))
                // 群聊：把正文里的「@所有人」落到 `mentionIds` 上（值必须与输入栏 @所有人 一致："ALL"，
                // 见 `FZMAtPeopleVC` / `SessionManager`）。否则它只是普通文字：
                // 收不到「有人@我」红点，服务端也不会按 @ 推送。
                // ⚠️ `Message` 是 struct ⇒ 必须 `var msg` 才能改 `mentionIds`。
                if !self.session.isPrivateChat {
                    msg.mentionIds = ["ALL"]
                }
                self.insertAndSendMessages([msg], needSendMsg: true)
                // ② 发起人自己直接进房（不用再点一次刚发出去的那条链接）
                VoiceRoomLauncher.open(url: link, from: self)
            } catch {
                self.hideProgress()
                self.showToast(error.localizedDescription)
                FZMLog("语音房：建房失败 \(error.localizedDescription)")
            }
        }
    }

    func sendRedBag() {
        let toId = self.session.id.idValue
        let isGroup = !self.session.isPrivateChat
        let vc = FZMCreateLuckyBagVC(to: toId, isGroup: isGroup)
        vc.sendCompleteBlock = {
            [weak self] (_, coinName, packetType, packetId, packetUrl, remark, _) in
            guard let self = self else { return }
            let txHash = packetId.isEmpty ? packetUrl : packetId
            guard !coinName.isEmpty, !txHash.isEmpty else { return }
            self.sendRedPacketMsg(
                coinName: coinName, txHash: txHash, remark: remark, imPacketType: packetType)
            self.navigationController?.popViewController(animated: true)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // 发专属红包（仅群聊）：先选 1 位或多位群成员 → 解析链上地址 → 进发红包页（白名单 N 人、N 份）
    func sendExclusiveRedBag() {
        guard !self.session.isPrivateChat, let info = self.groupDetailInfo else { return }
        let memberVC = FZMExclusiveRedBagMemberVC(with: info, fromTag: 0)
        memberVC.selectedBlock = { [weak self] members in
            guard let self = self else { return }
            self.resolveExclusiveReceiverAddresses(members: members)
        }
        UIViewController.current()?.present(
            FZMNavigationController(rootViewController: memberVC), animated: true, completion: nil)
    }

    /// 群成员聊天地址 → 链上 ethAddr（逐个解析、保持选择顺序），全部解析成功后进入专属红包发送页
    private func resolveExclusiveReceiverAddresses(members: [(address: String, name: String)]) {
        guard !members.isEmpty else { return }
        self.showProgress(with: nil)

        // 结果按下标回填保证顺序；getUser 回调线程不固定，用锁保护共享状态
        let lock = NSLock()
        var addresses = [String?](repeating: nil, count: members.count)
        var missingNames = [String]()
        let group = DispatchGroup()

        for (index, member) in members.enumerated() {
            group.enter()
            // ⚠️ 必须走网络取 ethAddr：本地 user 表没有 ethAddr 列，`getUser(by:)` 命中缓存会返回 nil
            UserManager.shared().getEthAddressForUser(member.address) { ethAddress in
                let address = ethAddress
                lock.lock()
                if address.isValidEthereumAddressString {
                    addresses[index] = address
                } else {
                    missingNames.append(member.name.isEmpty ? member.address.shortAddress : member.name)
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.hideProgress()

            // 有成员拿不到链上地址就整单不发：否则白名单缺人、份数金额会对不上
            guard missingNames.isEmpty else {
                self.showToast(L("未获取到对方地址") + "：" + missingNames.joined(separator: "、"))
                return
            }
            let resolvedAddresses = addresses.compactMap { $0 }
            guard resolvedAddresses.count == members.count else {
                self.showToast(L("未获取到对方地址"))
                return
            }
            // 白名单去重：同一链上地址只保留一份，避免出现「份数 > 实际可领人数」
            var seenAddresses = Set<String>()
            var finalAddresses = [String]()
            var finalNames = [String]()
            var finalChatAddresses = [String]()
            for (index, address) in resolvedAddresses.enumerated() {
                guard seenAddresses.insert(address.lowercased()).inserted else { continue }
                finalAddresses.append(address)
                finalNames.append(members[index].name)
                // 会话地址（`1…`）：只用于展示，弹层里给用户看它而不是 0x 地址
                finalChatAddresses.append(members[index].address)
            }

            let vc = FZMCreateLuckyBagVC(
                to: self.session.id.idValue, isGroup: true,
                exclusiveAddresses: finalAddresses, exclusiveNames: finalNames,
                exclusiveChatAddresses: finalChatAddresses)
            vc.sendCompleteBlock = {
                [weak self] (_, coinName, packetType, packetId, packetUrl, remark, _) in
                guard let self = self else { return }
                let txHash = packetId.isEmpty ? packetUrl : packetId
                guard !coinName.isEmpty, !txHash.isEmpty else { return }
                self.sendRedPacketMsg(
                    coinName: coinName, txHash: txHash, remark: remark, imPacketType: packetType)
                self.navigationController?.popViewController(animated: true)
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    // 点击发图片/视频
    func sendPhoto() {
        FZMLog("点击发图片/视频")

        SystemMediaPicker.shared.present(from: self, maxCount: 9) { [weak self] results in
            guard let self = self else {
                print("ChatVC 已释放，取消发送")
                return
            }

            if results.isEmpty {
                print("用户取消了选择")
                return
            }
            print("一共选择了 \(results.count) 个媒体")
            // 遍历结果，发送逻辑
            for (index, media) in results.enumerated() {
                print("--- 处理第 \(index+1) 个媒体 ---")
                switch media.mediaType {
                case .image:
                    // 1. 发送静态图片
                    if let img = media.image {
                        print("拿到静态图: \(img.size)")
                        DispatchQueue.main.async {
                            self.sendImageMsg(image: img)
                        }
                    }
                case .gif:
                    // 2. 发送 GIF 动图
                    if let gifData = media.gifData {
                        print("拿到 GIF Data，大小: \(gifData.count)")
                        // 限制 GIF 文件大小，超过 50MB 不允许发送
                        let maxGifSize = 50 * 1024 * 1024
                        guard gifData.count <= maxGifSize else {
                            DispatchQueue.main.async {
                                self.showToast(L("GIF过大，请选择小于50MB的文件"))
                            }
                            continue
                        }
                        // 使用 ImageIO 仅解码第一帧作为预览图，避免 UIImage(data:) 在 iOS 13+
                        // 将 GIF 所有帧一次性解码到内存导致 OOM 崩溃
                        guard let firstFrame = ChatVC.decodeGIFFirstFrame(gifData) else {
                            DispatchQueue.main.async {
                                self.showToast(L("发送失败，请稍后再试"))
                            }
                            continue
                        }
                        DispatchQueue.main.async {
                            self.sendImageMsg(image: firstFrame, gifData: gifData)
                        }
                    }
                case .video:
                    // 3. 发送视频
                    if let videoURL = media.videoURL, let asset = media.asset {
                        print("拿到视频路径: \(videoURL.path)")
                        // 获取视频缩略图（300x300）
                        VideoThumbnailLoader.loadThumbnail(
                            from: asset, size: CGSize(width: 300, height: 300)
                        ) { [weak self] (thumbnailImage) in
                            guard let self = self else { return }
                            DispatchQueue.main.async {
                                if let image = thumbnailImage {
                                    print("成功拿到视频缩略图: \(image.size)")
                                    self.sendVideoMsg(cropPicture: image, asset: asset, localPath: videoURL)
                                } else {
                                    // 缩略图获取失败，用占位图兜底，确保视频消息仍能发出
                                    print("获取视频缩略图失败，使用占位图发送")
                                    let fallbackImage = ChatVC.makeVideoPlaceholder(asset: asset)
                                    self.sendVideoMsg(cropPicture: fallbackImage, asset: asset, localPath: videoURL)
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showToast(L("发送失败，请稍后再试"))
                        }
                    }
                case .unknown:
                    print("未知媒体类型，跳过")
                }
            }
        }

        return
        //        let picker1 = UIImagePickerController()
        //        picker1.sourceType = .photoLibrary
        //        self.present(picker1, animated: true)
        //
        //        return

        let picker = ImagePickerController.init(
            withSelectOne: false, maxSelectCount: 9, allowEditing: false, showVideo: true)
        //        let picker = ImagePickerController.init(withSelectOne: false, maxSelectCount: 9, allowEditing: false, showVideo: false)//wjhTEST
        picker.imagePickerControllerDidCancelHandle = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isHiddenStatusBar = false
            UIView.animate(withDuration: 0.5) {
                strongSelf.setNeedsStatusBarAppearanceUpdate()
            }
        }

        picker.didFinishPickingPhotosHandle = {
            [weak self] (photos, assets, isSelectOriginalPhoto) in
            guard let strongSelf = self, let images = photos, let assets = assets as? [PHAsset]
            else { return }
            if images.count == assets.count {
                for i in 0..<assets.count {
                    let asset = assets[i]
                    if asset.mediaType == .video {
                        // ⚠️ 必须允许网络访问：iCloud 上的视频没下载到本地时，
                        //    原来 `options: nil` 根本拿不到 AVAsset，而且失败分支什么都没有 ——
                        //    用户点完「确定」毫无反应（2026-11-02 修）。
                        let videoOptions = PHVideoRequestOptions()
                        videoOptions.isNetworkAccessAllowed = true
                        videoOptions.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestAVAsset(
                            forVideo: asset, options: videoOptions,
                            resultHandler: { (assetAV, audioMix, info) -> Void in
                                if let avasset = assetAV as? AVURLAsset {
                                    DispatchQueue.main.async {
                                        strongSelf.sendVideoMsg(
                                            cropPicture: images[i], asset: asset, localPath: avasset.url
                                        )
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        if let error = info?[PHImageErrorKey] as? Error {
                                            FZMLog("视频获取失败: \(error)")
                                        }
                                        strongSelf.showToast(L("视频加载失败，请稍后重试"))
                                    }
                                }
                            })
                    } else {
                        //                        self.sendImageMsg(image: images[i])
                        let requestOption = PHImageRequestOptions()
                        requestOption.version = .unadjusted
                        requestOption.isSynchronous = false
                        PHImageManager.default().requestImageData(
                            for: asset, options: requestOption,
                            resultHandler: { (data, uti, orientation, info) in
                                if let UTI = uti, UTTypeConformsTo(UTI as CFString, kUTTypeGIF) {
                                    // It's GIF
                                    FZMLog("---- It's GIF -----")

                                    strongSelf.sendImageMsg(image: images[i], gifData: data)
                                } else {
                                    strongSelf.sendImageMsg(image: images[i])
                                }
                            })
                    }
                }
            }

            strongSelf.isHiddenStatusBar = false
            UIView.animate(withDuration: 0.5) {
                strongSelf.setNeedsStatusBarAppearanceUpdate()
            }
        }
        isHiddenStatusBar = true
        UIView.animate(withDuration: 0.5) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        self.present(picker, animated: true, completion: nil)
    }

    // 点击拍摄
    func goCamera() {
        FZMLog("点击拍摄")
        operationQueue.maxConcurrentOperationCount = 1
        let picker = UIImagePickerController.init()
        picker.delegate = self
        picker.mediaTypes = [kUTTypeImage as String]
        picker.mediaTypes.append(kUTTypeMovie as String)
        picker.videoMaximumDuration = 60 * 10
        picker.videoQuality = .typeHigh
        //        if type == .photoLibrary {
        //            picker.sourceType = .photoLibrary
        //        }else if type == .camera {
        picker.sourceType = .camera
        //        }
        picker.allowsEditing = false

        isHiddenStatusBar = true
        UIView.animate(withDuration: 0.5) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        self.present(picker, animated: true, completion: nil)
    }

    // 点击发文件
    func sendFile() {
        FZMLog("点击发文件")
        //        FZMUIMediator.shared().pushVC(.icloudPicker { (fileUrls) in
        //            for url in fileUrls {
        //                self.sendFileMsg(fileURL: url)
        //            }
        //        })

        self.openDocumentPicker { (fileUrls) in
            fileUrls.forEach { url in
                self.sendFileMsg(fileURL: url)
            }
        }
    }

    func openDocumentPicker(icloudFileBlock: @escaping IcloudFileBlock) {
        self.icloudFileBlock = icloudFileBlock
        //        let documentTypes = [
        //            "public.content",
        //            "public.text",
        //            "public.source-code ",
        //            "public.image",
        //            "public.avi",
        //            "public.audiovisual-content",
        //            "com.adobe.pdf",
        //            "com.apple.keynote.key",
        //            "com.microsoft.word.doc",
        //            "com.microsoft.word.docx",
        //            "com.microsoft.excel.xls",
        //            "com.microsoft.excel.xlsx",
        //            "com.microsoft.powerpoint.ppt",
        //            "com.microsoft.powerpoint.pptx",
        //            "com.pkware.zip-archive"
        //        ]
        let documentTypes = [String(kUTTypeItem)]  // ["public.item"] Will open and provide access to all items on drive
        /**
         文档类型参考苹果官方地址：https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259
         */
        let documentPicker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .open)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        if #available(iOS 11.0, *) {
            documentPicker.allowsMultipleSelection = true
        } else {
        }
        self.present(documentPicker, animated: true, completion: nil)
    }

    //    // 点击发红包
    //    func sendRedBag() {
    //        //wjhTODO sendRedBag
    //        FZMLog("点击发红包")
    //    }

    func transfer() {

        FZMLog("点击转账")
        guard let user = self.userInfo else {
            showToast(L("用户信息未加载，请稍后再试"))
            return
        }
        // 默认选中「0x 地址开头的 BTY」（与好友详情页 / 发红包页一致），没有则回退列表第一个
        guard let coin = PWDataBaseManager.shared().preferredTransferCoin() else {
            showToast(L("暂无可用币种"))
            return
        }
        // 地址获取与「红包」链路一致：走网络取对方的链上 ethAddr（0x…）
        // ⚠️ 不能用本地 user.ethAddr/bnbAddr：本地 user 表没有 ethAddr 列，命中缓存会拿到空 ⇒ 误报「未获取到对方地址」
        self.showProgress(with: nil)
        UserManager.shared().getEthAddressForUser(user.address) { [weak self] ethAddress in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.hideProgress()
                var toAddr = ethAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                if toAddr.isEmpty {
                    // 网络拿不到时退回本地值（能拿到就用，拿不到仍提示）
                    toAddr = user.ethAddr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
                if toAddr.isEmpty {
                    toAddr = user.bnbAddr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
                guard !toAddr.isEmpty else {
                    self.showToast(L("未获取到对方地址"))
                    return
                }
                let vc = TransferViewController.init()
                vc.contactDict = [
                    "avatarUrl": user.avatarURLStr as NSString,
                    "address": user.aliasName as NSString,
                    "toAddr": toAddr as NSString,
                ]
                vc.coin = coin
                vc.transferBlock = { [weak self] coinName, txHash, _ in
                    guard let self = self,
                        let name = coinName, !name.isEmpty,
                        let hash = txHash, !hash.isEmpty
                    else { return }
                    self.sendTransferMsg(coinName: name, txHash: hash)
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func sendContact() {
        FZMLog("点击发送名片")

        let vc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let person = UIAlertAction(title: L("个人名片"), style: .default) { _ in
            let vc = ChoiceContactCardVC()
            vc.contactCardType = 1
            vc.seletedBlock = { [weak self] contact in
                self?.sendContactCard(
                    contactId: contact.user!.address, name: "", avatar: contact.user!.aliasName,
                    type: 1)
            }
            self.navigationController?.present(vc, animated: true)
        }
        let group = UIAlertAction(title: L("群聊名片"), style: .default) { _ in
            let vc = ChoiceContactCardVC()
            vc.contactCardType = 2
            vc.seletedBlock = { [weak self] contact in
                self?.sendContactCard(
                    contactId: contact.group!.address, name: "", avatar: contact.group!.name,
                    type: 2)
            }
            self.navigationController?.present(vc, animated: true)
        }

        let cancel = UIAlertAction(title: L("取消"), style: .destructive) { _ in
            vc.dismiss(animated: true)
        }

        vc.addAction(person)
        vc.addAction(group)
        vc.addAction(cancel)

        self.navigationController?.present(vc, animated: true)

        //        self.sendContactCard()
    }

}

extension ChatVC: UIDocumentPickerDelegate {
    public func documentPicker(
        _ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL
    ) {
        if url.startAccessingSecurityScopedResource() {
            NSFileCoordinator().coordinate(
                readingItemAt: url, options: [.withoutChanges], error: nil
            ) { (newURL) in
                self.icloudFileBlock?([newURL])
            }
            url.stopAccessingSecurityScopedResource()
        }
    }
    public func documentPicker(
        _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
        self.icloudFileBlock?(urls)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromUIImagePickerControllerInfoKeyDictionary(
    _ input: [UIImagePickerController.InfoKey: Any]
) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey)
    -> String
{
    return input.rawValue
}

// MARK: - 图片视频选择Delegate
extension ChatVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        let mediaType = info[UIImagePickerController.InfoKey.mediaType.rawValue] as? String
        if mediaType == kUTTypeMovie as String {  // 视频
            DispatchQueue.global().async {
                guard let mediaURL = info[UIImagePickerController.InfoKey.mediaURL.rawValue] as? URL
                else { return }
                var localIdentifier: String?
                PHPhotoLibrary.shared().performChanges({
                    localIdentifier =
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: mediaURL)?
                        .placeholderForCreatedAsset?.localIdentifier
                }) { (success, error) in
                    if success,
                        let localIdentifier = localIdentifier,
                        let asset = PHAsset.fetchAssets(
                            withLocalIdentifiers: [localIdentifier], options: nil
                        ).firstObject
                    {
                        UIImage.getVideoCropPicture(mediaURL) { (firstFrame) in
                            DispatchQueue.main.async {
                                picker.dismiss(
                                    animated: true,
                                    completion: { [self] in
                                        isHiddenStatusBar = false
                                        UIView.animate(withDuration: 0.5) {
                                            self.setNeedsStatusBarAppearanceUpdate()
                                        }
                                    })
                                guard let firstFrame = firstFrame else { return }
                                self.sendVideoMsg(
                                    cropPicture: firstFrame, asset: asset, localPath: mediaURL)
                            }
                        }
                    }
                }
            }
        } else {  // 图片
            DispatchQueue.main.async {
                picker.dismiss(
                    animated: true,
                    completion: { [self] in
                        isHiddenStatusBar = false
                        UIView.animate(withDuration: 0.5) {
                            self.setNeedsStatusBarAppearanceUpdate()
                        }
                    })
                guard
                    let image = info[
                        convertFromUIImagePickerControllerInfoKey(
                            UIImagePickerController.InfoKey.originalImage)] as? UIImage
                else {
                    return
                }
                let newImage = image.fixedImageToUpOrientation2()
                self.sendImageMsg(image: newImage)
            }
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        DispatchQueue.main.async {
            picker.dismiss(animated: true) { [self] in
                //                UIApplication.shared.setStatusBarHidden(false, with: .fade)
                //                self.setNeedsStatusBarAppearanceUpdate()
                isHiddenStatusBar = false
                UIView.animate(withDuration: 0.5) {
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }

    // 状态栏
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        //        return .fade
        return .slide
    }

    override var prefersStatusBarHidden: Bool {
        return isHiddenStatusBar
    }
}

//MARK: - 发消息
extension ChatVC {
    // 发文字
    private func sendTextMsg(text: String, mentionIds: [String]) {
        var msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id,
            msgType: .init(text: text))
        if mentionIds.count > 0 {
            msg.mentionIds = mentionIds
        }
        // 有引用消息（取完即清，避免引用串到下一条）
        msg.reference = self.takeReferenceForSending()

        self.insertAndSendMessages([msg], needSendMsg: true)
        //        ChatManager.shared().send(msg: msg)//主线程异步插入数据未完成时发消息回执已返回，无法修改消息状态
    }

    /// 取出待发送的引用，并立刻清空引用态（输入框里的引用条一起收起来）。
    /// 引用链：直接引用 `ref`，`topic` 沿用原消息的 `topic`（引用的引用都归到最初那条）。
    private func takeReferenceForSending() -> Message.Reference? {
        defer { self.clearReferenceState() }
        guard let refMsg = self.referenceMsg, let logId = refMsg.logId else { return nil }
        var topicId = logId
        // ⚠️ 只有原消息**确实带有效 topic** 才继承：老版本把每条收到的消息都塞了 `{0,0}` 的假引用，
        //    直接继承会把 `topic = 0` 发出去，web 端按 topic 找不到引用链就不渲染引用条。
        if let curRef = refMsg.reference, curRef.topic > 0 {
            topicId = curRef.topic
        }
        return Message.Reference.init(ref: logId, topic: topicId)
    }
    
    // 发送系统消息
    private func sendTextNotifityMsg(text: String) {
        let msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id,
            msgType: .init(system: text))

        self.insertAndSendMessages([msg], needSendMsg: true)
    }

    // 转账
    private func sendTransferMsg(coinName: String, txHash: String) {
        guard coinName.count > 0, txHash.count > 0 else { return }

        let msgType = Message.MsgType.init(transfer: coinName, txHash: txHash)
        let msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)

        self.insertAndSendMessages([msg], needSendMsg: true)
    }

    // 发送红包消息
    private func sendRedPacketMsg(
        coinName: String, txHash: String, remark: String, imPacketType: IMRedPacketType
    ) {
        guard !coinName.isEmpty, !txHash.isEmpty else { return }
        let packetType: Int
        switch imPacketType {
        case .common:
            packetType = 1  // PbMsg_RPType.identicalAmount
        case .luck, .promote:
            packetType = 0  // PbMsg_RPType.randomAmount
        }
        let msgType = Message.MsgType.init(
            redPacket: txHash,
            coinName: coinName,
            exec: "",
            packetType: packetType,
            remark: remark,
            expire: 0
        )
        let msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        self.insertAndSendMessages([msg], needSendMsg: true)
    }

    /// 取私钥：命中 `WalletPrivateKeyStore` 内存缓存直接回调（**不弹密码**），否则弹一次密码
    /// ——「第一次开红包输一次密码，之后开红包不再输」（与 AI 客服共用同一份内存缓存）。
    /// 用户取消 ⇒ 静默什么都不做；其它失败 ⇒ toast 提示。
    private func requestRedPacketPrivateKey(completion: @escaping (Data) -> Void) {
        WalletPrivateKeyStore.shared.requestPrivateKey(title: L("请输入密聊密码"), success: { privateKey in
            completion(privateKey)
        }, failure: { [weak self] error in
            switch error {
            case .cancelled:
                break
            default:
                FZMLog("打开红包取私钥失败：\(error.message)")
                self?.showToast(error.message)
            }
        })
    }

    /// 在**聊天页**直接领取红包（用户 2026-09-30：「抢红包做成在聊天页面抢，抢成功了再进入红包详情页」）。
    /// - 「开」面板**不关**（用户 2026-09-30）：领取中把「开」按钮换成转圈并禁用，避免重复领；
    /// - 成功：收起「开」面板 → 面板消失后才 push 详情页（详情页只展示，不再自动领取）；
    /// - 失败：只 toast，**面板留着**，用户可以再点一次「开」重试，也不会进详情页。
    /// 链上详情缓存由 `RedPacketWeb3Service.claimRedPacket` 在成功后自动失效，
    /// 所以详情页查到的是「已领取」的新详情，不会拿聊天页刚才那份旧缓存。
    private func claimRedPacketInChat(
        packetId: String, coinName: String, decimals: Int, privateKey: Data
    ) {
        // 不用 showProgress：那 HUD 挂在页面 view 上，会被还开着的「开」面板遮住
        openRedPacketPanelBusy?(true)
        RedPacketWeb3Service.shared.claimRedPacket(id: packetId, privateKey: privateKey) {
            [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let amount):
                let amountText = RedPacketWeb3Service.shared.format(amount, decimals: decimals)
                // 面板还盖在页面上：toast 挂页面 view 会被遮住，直接挂到 window 上
                let toastHost: UIView = UIApplication.shared.keyWindow ?? self.view
                toastHost.showToast(String(format: L("成功领取%@%@"), amountText, coinName))
                // 气泡是按链上详情缓存渲染的（此时缓存已失效）⇒ 重刷一下，免得回来还写着「查看红包」
                self.collectionView.reloadData()
                // 先收面板，面板移除后再进详情页（顺序就是用户要的「先消失再进页」）；
                // 面板已经被用户关掉时（钩子已清空）直接进页。
                // ⚠️ 闭包类型必须显式写 `() -> Void`：`self?.xxx()` 的返回值是 `Void?`，
                // 让编译器推断会得到 `() -> ()?`，传给 `(@escaping () -> Void) -> Void` 会报
                // 「Cannot convert value of type '() -> ()?' to '() -> Void'」
                let push: () -> Void = { [weak self] in
                    guard let self = self else { return }
                    self.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
                }
                if let dismiss = self.openRedPacketPanelDismiss {
                    dismiss(push)
                } else {
                    push()
                }
            case .failure(let error):
                // 面板留着，允许再点「开」重试。
                // 失败原因同样要挂在 window 上 —— 挂在页面 view 上会被还开着的面板遮住，
                // 那样用户只看到「转圈停了」却不知道为什么失败
                let toastHost: UIView = UIApplication.shared.keyWindow ?? self.view
                toastHost.showToast(error.localizedDescription)
                self.openRedPacketPanelBusy?(false)
            }
        }
    }

    private func handleRedPacketTap(packetId: String, coinName: String, senderAddress: String) {
        redPacketSenderAddress = senderAddress
        showProgress(with: nil)
        RedPacketWeb3Service.shared.getRedPacketInfo(id: packetId) { [weak self] result in
            guard let self = self else { return }
            self.hideProgress()
            switch result {
            case .success(let info):
                self.handleRedPacketInfo(info, packetId: packetId, coinName: coinName)
            case .failure(let error):
                self.showToast(error.localizedDescription)
            }
        }
    }

    private func handleRedPacketInfo(_ info: RedPacketChainInfo, packetId: String, coinName: String)
    {
        if info.userClaimed {
            showClaimedRedPacketPanel(coinName: coinName, stateText: L("红包已领取")) { [weak self] in
                self?.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
            }
            return
        }

        // 专属红包：非白名单（包含发起人自己）不允许开箱，避免链上 revert
        if info.hasWhitelist, !info.userInWhitelist {
            let me = RedPacketWeb3Service.shared.currentAddress()?.lowercased() ?? ""
            let stateText =
                me == info.creator.lowercased() ? L("等待好友领取") : L("该红包仅限指定好友领取")
            showClaimedRedPacketPanel(coinName: coinName, stateText: stateText) { [weak self] in
                self?.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
            }
            return
        }

        switch info.status {
        case .active:
            // 币种：消息里没带时用链上查到的符号（与详情页的回退规则一致），否则 toast 会缺币种
            let resolvedCoinName = coinName.isEmpty ? info.tokenSymbol : coinName
            showOpenRedPacketPanel(coinName: resolvedCoinName) { [weak self] in
                // 用户 2026-09-30：「抢红包做成在聊天页面抢，抢成功了再进入红包详情页」
                // ⇒ 先在聊天页拿到私钥（首次弹一次密码，之后命中缓存直接过），
                //   然后在**聊天页**发起领取：领成功才 push 详情页，失败只 toast、**不进详情页**
                self?.requestRedPacketPrivateKey { [weak self] privateKey in
                    self?.claimRedPacketInChat(
                        packetId: packetId, coinName: resolvedCoinName, decimals: info.decimals,
                        privateKey: privateKey)
                }
            }
        case .claimedAll:
            showClaimedRedPacketPanel(coinName: coinName, stateText: L("红包已领完")) { [weak self] in
                self?.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
            }
        case .expired:
            showClaimedRedPacketPanel(coinName: coinName, stateText: L("红包已过期")) { [weak self] in
                self?.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
            }
        case .expiredWithdrawn:
            showClaimedRedPacketPanel(coinName: coinName, stateText: L("过期已取回")) { [weak self] in
                self?.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
            }
        case .withdrawn:
            showClaimedRedPacketPanel(coinName: coinName, stateText: L("红包已取回")) { [weak self] in
                self?.pushRedPacketInfo(packetId: packetId, coinName: coinName, privateKey: nil)
            }
        }
    }

    /// 进红包详情页。
    /// - Parameter privateKey: 非空 ⇒ 详情页进页自动领取（带私钥）。
    ///   ⚠️ 当前**所有调用点都传 nil**：领取已改到聊天页做（见 `claimRedPacketInChat`），
    ///   详情页只负责展示（含「已领完 / 已过期 / 已领过」这类不需领取的情况）。
    ///   参数与 `FZMRedBagInfoVC` 的自动领取能力先保留，别处要复用时可直接传。
    private func pushRedPacketInfo(packetId: String, coinName: String, privateKey: Data?) {
        let vc = FZMRedBagInfoVC(
            with: packetId,
            isShowRecord: true,
            shouldAutoClaim: privateKey != nil,
            autoClaimPrivateKey: privateKey,
            coinName: coinName,
            senderAddress: redPacketSenderAddress
        )
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 红包弹窗的标题：「你发了一个BTY红包」/「张三 发了一个BTY红包」。
    /// - 发送者是自己 ⇒「你」；
    /// - **群聊** ⇒ 与 @群成员同一口径 `GroupMember.atName`：群昵称 → 用户昵称 → 短地址；
    /// - 私聊 ⇒ 会话地址反查昵称，查不到则回落到短地址（不能显示空）。
    /// - `senderAddress` 用属性 `redPacketSenderAddress`（在 `handleRedPacketTap` 开头就赋好了）。
    private func redPacketPanelTitle(coinName: String) -> String {
        let body = String(format: L("发了一个%@红包"), coinName)
        let sender = redPacketSenderAddress
        if sender.isEmpty || sender == LoginUser.shared().address {
            return L("你") + body
        }
        if !self.session.isPrivateChat {
            // 群红包：与「@群成员 / 引用消息 / 群聊消息」同一口径 —— `GroupMember.atName`
            // （群昵称 → 用户昵称 → 短地址）。用户 2026-10-08 反馈：不能直接显示地址。
            let groupId = self.session.id.idValue.intEncoded
            if let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: sender) {
                let name = member.atName
                if !name.isBlank { return name + " " + body }
            }
            // 群成员表里查不到这个人（群成员列表未同步）时，至少回落到用户昵称
            let nickname = UserManager.shared().user(by: sender)?.nickname ?? ""
            return (nickname.isBlank ? sender.shortAddress : nickname) + " " + body
        }
        let name = UserManager.shared().user(by: sender)?.contactsName ?? ""
        return (name.isEmpty ? sender.shortAddress : name) + " " + body
    }

    // 「开红包」面板的两个钩子（`openRedPacketPanelDismiss` / `openRedPacketPanelBusy`）
    // 是**存储属性**，不能写在扩展里 ⇒ 定义在类主体（见 `redPacketSenderAddress` 旁边）
    private func showOpenRedPacketPanel(coinName: String, openBlock: @escaping () -> Void) {
        guard let window = UIApplication.shared.keyWindow else { return }

        let maskView = UIView(frame: window.bounds)
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        maskView.alpha = 0

        let cardView = UIView()
        // 渐变层在「加入 window + layoutIfNeeded」之后才铺（那时才有真实 bounds）；
        // 阴影/发光要留下，所以本视图不能 masksToBounds
        cardView.layer.cornerRadius = 24
        cardView.applyRPGoldBorder(1, alpha: 0.35, cornerRadius: 24)
        cardView.applyRPGlow(RP.redBright, radius: 18, opacity: 0.35, offsetY: 8)
        maskView.addSubview(cardView)

        let titleLab = UILabel.getLab(
            font: UIFont.regularFont(14), textColor: RP.onRedWeak,
            textAlignment: .center, text: redPacketPanelTitle(coinName: coinName))
        cardView.addSubview(titleLab)

        let remarkLab = UILabel.getLab(
            font: UIFont.boldFont(22), textColor: RP.onRedStrong, textAlignment: .center,
            text: L("恭喜发财，大吉大利！"))
        cardView.addSubview(remarkLab)

        let openBtn = UIButton(type: .custom)
        // 金色提亮：与「已领取」弹窗同一套（原来的 `RP.gold` 压在珊瑚红卡上发闷）
        openBtn.backgroundColor = RP.goldBright
        openBtn.setTitle(L("开"), for: .normal)
        openBtn.setTitleColor(RP.goldDeep, for: .normal)
        openBtn.titleLabel?.font = UIFont.boldFont(32)
        openBtn.layer.cornerRadius = 46
        // 不裁剪：backgroundColor 本身会按 cornerRadius 圆角，但裁了就看不到金色外发光
        openBtn.applyRPGlow(RP.goldBright, radius: 16, opacity: 0.45, offsetY: 0)
        cardView.addSubview(openBtn)
        // 领取中的转圈（盖在「开」按钮上，显隐见 `openRedPacketPanelBusy`）
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.color = RP.goldDeep
        loadingView.hidesWhenStopped = true
        cardView.addSubview(loadingView)
        loadingView.snp.makeConstraints { (make) in
            make.center.equalTo(openBtn)
        }

        let closeBtn = UIButton(type: .custom)
        closeBtn.setImage(
            UIImage(named: "chat_cancel")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.85)
        cardView.addSubview(closeBtn)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(300)
            // 去掉头像后卡片上下不必再留那么多白
            make.height.equalTo(340)
        }
        closeBtn.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.width.height.equalTo(24)
        }
        // 名字可能很长（「谈信未来-比特币元 发了一个BTY红包」单行放不下）⇒ 允许两行中缝居中
        titleLab.numberOfLines = 2
        titleLab.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(60)
            make.left.right.equalToSuperview().inset(20)
            // ⚠️ 用「上界」而不是固定 20：固定高会把第二行直接裁掉；
            // 只有一行时标签按 intrinsic 保持 20，下面备注的间距不会变
            make.height.lessThanOrEqualTo(40)
        }
        remarkLab.snp.makeConstraints { make in
            make.top.equalTo(titleLab.snp.bottom).offset(36)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(30)
        }
        openBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-44)
            make.width.height.equalTo(92)
        }

        // 收起面板：淡出遮罩，移除后回调。
        // 同时把对外的两个钩子置空 —— 面板已经不在了，页面不该再往它上面做事
        let dismiss: (@escaping () -> Void) -> Void = { [weak self] completion in
            self?.openRedPacketPanelDismiss = nil
            self?.openRedPacketPanelBusy = nil
            UIView.animate(
                withDuration: 0.2,
                animations: {
                    maskView.alpha = 0
                },
                completion: { _ in
                    maskView.removeFromSuperview()
                    completion()
                })
        }
        openRedPacketPanelDismiss = dismiss
        openRedPacketPanelBusy = { busy in
            openBtn.isUserInteractionEnabled = !busy
            // 转圈期间把「开」字藏掉（两个都在按钮中心，字和转圈会叠在一起）
            openBtn.setTitle(busy ? "" : L("开"), for: .normal)
            if busy {
                loadingView.startAnimating()
            } else {
                loadingView.stopAnimating()
            }
            // 领取中不让关面板：关了面板就接不到「领取成功 → 进详情页」这条链了
            closeBtn.isUserInteractionEnabled = !busy
        }
        closeBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: { _ in dismiss({}) }).disposed(
            by: bag)
        // ⚠️ 点「开」**不关面板**（用户 2026-09-30）：领取成功由页面调 `openRedPacketPanelDismiss` 收起，
        // 失败则面板留着（只 toast），用户可以直接再点一次「开」重试
        openBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: { _ in
            openBlock()
        }).disposed(by: bag)

        window.addSubview(maskView)
        // 先跑一遍布局，卡片/按钮才有真实 bounds，渐变层才能铺满
        maskView.layoutIfNeeded()
        cardView.applyRPGradient(
            RP.primaryGradient, start: CGPoint(x: 0.1, y: 0), end: CGPoint(x: 0.9, y: 1),
            cornerRadius: 24)
        UIView.animate(withDuration: 0.2) {
            maskView.alpha = 1
        }
    }

    private func showClaimedRedPacketPanel(
        coinName: String, stateText: String, detailBlock: @escaping () -> Void
    ) {
        guard let window = UIApplication.shared.keyWindow else { return }

        let maskView = UIView(frame: window.bounds)
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        maskView.alpha = 0

        let cardView = UIView()
        cardView.layer.cornerRadius = 24
        cardView.applyRPGoldBorder(1, alpha: 0.35, cornerRadius: 24)
        cardView.applyRPGlow(RP.redBright, radius: 18, opacity: 0.35, offsetY: 8)
        maskView.addSubview(cardView)

        let titleLab = UILabel.getLab(
            font: UIFont.regularFont(14), textColor: RP.onRedWeak,
            textAlignment: .center, text: redPacketPanelTitle(coinName: coinName))
        cardView.addSubview(titleLab)

        let remarkLab = UILabel.getLab(
            font: UIFont.boldFont(22), textColor: RP.onRedStrong, textAlignment: .center,
            text: stateText)
        cardView.addSubview(remarkLab)

        let detailBtn = UIButton(type: .custom)
        // 金色提亮：`RP.gold`(#C9A961) 压在珊瑚红卡上发闷，换成专供红底大面积填充的亮金
        // （用户 2026-09-28：「领取红包弹窗的金色亮一点」）；字用深金，亮底上对比刚好。
        detailBtn.backgroundColor = RP.goldBright
        detailBtn.setTitle(L("查看详情"), for: .normal)
        detailBtn.setTitleColor(RP.goldDeep, for: .normal)
        detailBtn.titleLabel?.font = UIFont.boldFont(16)
        detailBtn.layer.cornerRadius = 24
        detailBtn.applyRPGlow(RP.goldBright, radius: 14, opacity: 0.40, offsetY: 0)
        cardView.addSubview(detailBtn)

        let closeBtn = UIButton(type: .custom)
        closeBtn.setImage(
            UIImage(named: "chat_cancel")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.85)
        cardView.addSubview(closeBtn)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(300)
            // 去掉头像后卡片上下不必再留那么多白
            make.height.equalTo(340)
        }
        closeBtn.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.width.height.equalTo(24)
        }
        // 同「拆红包」弹窗：名字长时允许两行
        titleLab.numberOfLines = 2
        titleLab.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(60)
            make.left.right.equalToSuperview().inset(20)
            make.height.lessThanOrEqualTo(40)
        }
        remarkLab.snp.makeConstraints { make in
            make.top.equalTo(titleLab.snp.bottom).offset(36)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(30)
        }
        detailBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-44)
            make.width.equalTo(156)
            make.height.equalTo(48)
        }

        let dismiss: () -> Void = {
            UIView.animate(
                withDuration: 0.2,
                animations: {
                    maskView.alpha = 0
                },
                completion: { _ in
                    maskView.removeFromSuperview()
                })
        }
        closeBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: { _ in dismiss() }).disposed(
            by: bag)
        detailBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: { _ in
            dismiss()
            detailBlock()
        }).disposed(by: bag)

        window.addSubview(maskView)
        // 先跑一遍布局，卡片/按钮才有真实 bounds，渐变层才能铺满
        maskView.layoutIfNeeded()
        cardView.applyRPGradient(
            RP.primaryGradient, start: CGPoint(x: 0.1, y: 0), end: CGPoint(x: 0.9, y: 1),
            cornerRadius: 24)
        UIView.animate(withDuration: 0.2) {
            maskView.alpha = 1
        }
    }

    // 发送名片
    private func sendContactCard(contactId: String, name: String, avatar: String, type: Int) {

        let msgType = Message.MsgType.init(
            contactCard: contactId, name: name, avatar: avatar, type: type)
        let msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)

        self.insertAndSendMessages([msg], needSendMsg: true)
    }

    // 使用 ImageIO 仅解码 GIF 的第一帧，避免 UIImage(data:) 在 iOS 13+ 将全部帧解码导致 OOM
    private static func decodeGIFFirstFrame(_ gifData: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(gifData as CFData, nil) else {
            return nil
        }
        guard CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        // 仅创建第一帧的 CGImage，不解码其余帧
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // 当视频缩略图获取失败时，生成一个带有正确宽高比的占位图，确保消息不丢失
    private static func makeVideoPlaceholder(asset: PHAsset) -> UIImage {
        let rawWidth = CGFloat(asset.pixelWidth)
        let rawHeight = CGFloat(asset.pixelHeight)
        let maxSide: CGFloat = 300
        var size: CGSize
        if rawWidth > 0 && rawHeight > 0 {
            let ratio = min(maxSide / rawWidth, maxSide / rawHeight, 1.0)
            size = CGSize(width: rawWidth * ratio, height: rawHeight * ratio)
        } else {
            size = CGSize(width: maxSide, height: maxSide)
        }
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        UIColor.darkGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let placeholder = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return placeholder ?? UIImage()
    }

    // 发图片
    private func sendImageMsg(image: UIImage, gifData: Data? = nil) {

        let cacheKey = String.uuid()
        ChatMediaCache.store(image, forKey: cacheKey)

        let msgType = Message.MsgType.init(
            image: nil, cacheKey: cacheKey, width: Double(image.size.width),
            height: Double(image.size.height))
        //        let msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        var msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        if let gifData = gifData {
            msg.gifData = gifData
        }
        // 图片也可以作为引用的回复内容一起发出去
        msg.reference = self.takeReferenceForSending()

        self.insertAndSendMessages([msg], needSendMsg: true)
        //        ChatManager.shared().send(msg: msg)
    }

    /// 发送视频：最长时长（与相机拍摄的 `videoMaximumDuration` 保持一致）
    private static let maxVideoDuration: TimeInterval = 10 * 60
    /// 源文件超过这个大小**直接拦下**：转码要完整解码 + 重新编码整段视频，
    /// 几百 MB 的 4K 视频手机上要跑很久、很容易让用户以为「点了没反应」。
    private static let videoMaxSourceBytes = 300 * 1024 * 1024
    /// 压缩后仍然超过这个大小才真正拦下（兜底）
    private static let videoMaxOutputBytes = 200 * 1024 * 1024

    /// 发送视频时选的导出预设：只做「压小」，绝不放大。
    /// - 长边 > 1280（超过 720p）⇒ `AVAssetExportPreset1280x720`
    /// - 否则 ⇒ `AVAssetExportPresetMediumQuality`（小视频保持原尺寸，避免被放大反而变大）
    private static func videoExportPresetName(for asset: AVAsset) -> String {
        let tracks = asset.tracks(withMediaType: .video)
        guard let track = tracks.first else { return AVAssetExportPresetMediumQuality }
        let size = track.naturalSize.applying(track.preferredTransform)
        let longSide = max(abs(size.width), abs(size.height))
        return longSide > 1280 ? AVAssetExportPreset1280x720 : AVAssetExportPresetMediumQuality
    }

    // 发视频
    private func sendVideoMsg(cropPicture: UIImage, asset: PHAsset, localPath: URL) {
        // 时长限制：相机拍摄靠 `UIImagePickerController.videoMaximumDuration` 限制，
        // 从相册选的视频没有任何限制 ⇒ 这里统一兜住（不然可以选一个两小时的视频）。
        if asset.duration > ChatVC.maxVideoDuration {
            self.showToast(L("视频不能超过10分钟"))
            return
        }
        // 源文件大小：超过上限直接拦（这种视频本身发不出去），
        // 但用 KVC 取不到 fileSize（私有 API）时**必须放行** ——
        // 原来用 `guard let size` 会把「取不到」误判成「视频过大」而永远发不出去。
        if #available(iOS 9.0, *) {
            if let size = (PHAssetResource.assetResources(for: asset).first?.value(forKey: "fileSize") as? Int) {
                FZMLog("发送视频：源文件 \(size / 1024 / 1024)MB 时长 \(Int(asset.duration))s")
                if size > ChatVC.videoMaxSourceBytes {
                    self.showToast(L("视频过大"))
                    return
                }
            } else {
                FZMLog("发送视频：取不到源文件大小，照常发送（时长 \(Int(asset.duration))s）")
            }
        }

        let cacheKey = String.uuid()
        ChatMediaCache.store(cropPicture, forKey: cacheKey)

        // 视频转存
        guard
            let filePath = FZMLocalFileClient.shared().createFile(with: .video(fileName: cacheKey))
        else {
            self.showToast(L("视频选取失败，请重试"))
            return
        }

        // ① 先把「发送中」的气泡插进列表：转码少则几秒、多则几十秒（4K / 长视频更久），
        //    等转完再插，用户点完「发送」看到的就是「页面毫无变化」（用户 2026-11-03 反馈）。
        //    缩略图上面已经进了缓存 ⇒ 气泡一上屏就能显示封面 + 「发送中」的菊花。
        let msgType = Message.MsgType.init(
            video: nil, cacheKey: cacheKey, duration: asset.duration,
            width: Double(cropPicture.size.width), height: Double(cropPicture.size.height))
        var placeholder = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        placeholder.mediaUrl = URL(fileURLWithPath: filePath)
        // 视频也可以作为引用的回复内容（引用信息跟着占位消息一起进列表，转码完接着发）
        placeholder.reference = self.takeReferenceForSending()

        // ② 气泡上屏后再「转码 → 落盘 → 发送」
        self.insertAndSendMessages([placeholder], needSendMsg: false) { [weak self] inserted in
            guard let msg = inserted.first else { return }
            self?.exportAndSendVideo(msg, localPath: localPath, filePath: filePath)
        }
    }

    /// 视频转码 → 落盘 → 交给 `ChatManager` 上传发送。
    /// 调用前气泡已经插进列表（状态 `.sending`），这里只负责把文件准备好。
    private func exportAndSendVideo(
        _ msg: Message, localPath: URL, filePath: String
    ) {
        let serverUrl = self.chatServerUrl ?? ""
        let start = Date()

        // 失败收尾：清掉半成品文件 + 撤掉刚插进去的气泡（这条消息根本没发出去，留着只会一直转菊花）
        let fail: (String) -> Void = { [weak self] reason in
            FZMLog("发送视频失败：\(reason)")
            let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: filePath)
            ChatVC.deletePickerTmpFile(localPath)
            DispatchQueue.main.async {
                self?.showToast(L("视频发送失败，请重试"))
                self?.deleteMessages([msg], needDeleteDB: false)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // ① 按目标码率压（720p / ~1.2Mbps）：
            //    `AVAssetExportSession` 的预设是按画质调的，压不住体积 ——
            //    实测 127s 的 4K 源用 1280x720 预设导出 **159MB（约 10Mbps）**，服务端直接拒收；
            //    而 MediumQuality 会把 1080p 缩成 320x568。详见 `ChatVideoCompressor`。
            var error = ChatVideoCompressor.compress(
                source: localPath, destination: URL(fileURLWithPath: filePath))
            if let compressError = error {
                FZMLog("按码率压缩失败，退回系统预设：\(compressError.localizedDescription)")
                // ② 兜底：系统导出的预设（体积大一点，但至少能发出去）
                error = ChatVC.exportWithSystemPreset(source: localPath, destination: filePath)
            }
            ChatVC.deletePickerTmpFile(localPath)
            if let error = error {
                fail("转码失败 \(error.localizedDescription)")
                return
            }
            let size = ChatVC.fileSize(atPath: filePath)
            if size > ChatVC.videoMaxOutputBytes {
                fail("压缩后仍然过大（\(size / 1024 / 1024)MB）")
                return
            }
            FZMLog(
                "视频转码完成：\(size / 1024 / 1024)MB，耗时 "
                    + "\(Int(Date().timeIntervalSince(start)))s，开始发送 msgId=\(msg.msgId.prefix(8))")
            DispatchQueue.main.async { [weak self] in
                if let self = self {
                    // 文件已经在本机了：刷一下这条气泡，让播放图标从「下载」变「播放」
                    self.refreshMessageCell(msgId: msg.msgId)
                    // 走和「立即发送」同一条路：重新读一次 chatServerUrl
                    // （转码这段时间里地址可能刚好被拉回来）
                    self.sendInsertedMessage(msg)
                } else {
                    // 聊天页已经被弹掉了：消息照样发出去（会落库，重进会话能看到「发送中/已发送」）
                    ChatManager.shared().send(msg: msg, chatServerUrl: serverUrl)
                }
            }
        }
    }

    /// 兜底导出：系统预设（同步执行，调用方需在后台线程）
    private static func exportWithSystemPreset(source: URL, destination: String) -> Error? {
        let avAsset = AVURLAsset.init(url: source, options: nil)
        guard
            let exportSession = AVAssetExportSession.init(
                asset: avAsset, presetName: ChatVC.videoExportPresetName(for: avAsset))
        else {
            return NSError(
                domain: "chat.video", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法创建转码任务"])
        }
        try? FileManager.default.removeItem(atPath: destination)
        exportSession.outputFileType = .mp4
        exportSession.outputURL = URL.init(fileURLWithPath: destination)
        exportSession.shouldOptimizeForNetworkUse = true

        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously { semaphore.signal() }
        semaphore.wait()
        guard exportSession.status == .completed else {
            return exportSession.error
                ?? NSError(
                    domain: "chat.video", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "系统转码失败"])
        }
        return nil
    }

    /// 文件大小（取不到按 0 处理）
    private static func fileSize(atPath path: String) -> Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.intValue ?? 0
    }

    /// 刷新某条消息所在的 cell（只刷这一条，不动整表）
    private func refreshMessageCell(msgId: String) {
        refreshListLock.lock()
        defer { refreshListLock.unlock() }
        guard let index = messageArray.firstIndex(where: { $0.msgId == msgId }) else { return }
        reloadSectionSafely(index)
    }

    /// 删掉 PHPicker 复制到系统临时目录的那份源视频（只删临时目录里的，别动相册里的文件）
    private static func deletePickerTmpFile(_ url: URL) {
        let tmpRoot = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
        let path = url.resolvingSymlinksInPath().path
        guard path.hasPrefix(tmpRoot) else { return }
        let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: path)
    }

    // 转存MP4格式视频到本地并发送
    private func saveAndSendVideo(
        tmpPath: String, filePath: String, cropPicture: UIImage, cacheKey: String, asset: PHAsset
    ) {
        if let data = try? Data.init(contentsOf: URL.init(string: tmpPath)!),
            FZMLocalFileClient.shared().saveData(data, filePath: filePath)
        {
            let msgType = Message.MsgType.init(
                video: nil, cacheKey: cacheKey, duration: asset.duration,
                width: Double(cropPicture.size.width), height: Double(cropPicture.size.height))
            var msg = Message.init(
                fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
            msg.mediaUrl = URL.init(string: filePath)
            self.insertAndSendMessages([msg], needSendMsg: true)
        } else {
            self.showToast(L("视频转存本地失败，请重试"))
        }
    }

    // 发语音
    private func sendAudioMsg(amrPath: String, wavPath: String, duration: Double) {
        let cacheKey = wavPath.fileName()
        let msgType = Message.MsgType.init(
            audio: nil, duration: duration, cacheKey: cacheKey, width: 0, height: 0)
        var msg = Message.init(
            fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        //        msg.audioUrl = amrPath
        msg.audioUrl = wavPath  // 浏览器不支持amr格式，改为使用wav格式上传
        self.insertAndSendMessages([msg], needSendMsg: true)
    }

    // 发文件
    private func sendFileMsg(fileURL: URL) {
        if fileURL.startAccessingSecurityScopedResource() {
            NSFileCoordinator().coordinate(
                readingItemAt: fileURL, options: [.withoutChanges], error: nil
            ) { (newURL) in
                guard let data = try? Data.init(contentsOf: newURL) else {
                    self.showToast(L("文件选取失败,请重试"))
                    return
                }
                guard (data.count / 1024 / 1024) < 100 else {
                    self.showToast(L("文件不能大于100M"))
                    return
                }
                let cacheKey = String.uuid()

                let fileName = newURL.lastPathComponent
                //                let filePath = DocumentPath.appendingPathComponent("File/\(cacheKey)/\(fileName)")
                let fileFolder = "\(cacheKey)/\(fileName)"

                guard
                    let filePath = FZMLocalFileClient.shared().createFile(
                        with: .file(fileName: fileFolder))
                else {
                    self.showToast(L("文件选取失败,请重试"))
                    return
                }

                if FZMLocalFileClient.shared().saveData(data, filePath: filePath) {
                    let msgType = Message.MsgType.init(
                        file: nil, cacheKey: cacheKey, name: fileName,
                        md5: OSSUtil.fileMD5String(filePath), size: Double(data.count))
                    var msg = Message.init(
                        fromId: LoginUser.shared().address, sessionId: self.session.id,
                        msgType: msgType)
                    msg.fileUrl = filePath
                    // 文件也可以作为引用的回复内容
                    msg.reference = self.takeReferenceForSending()
                    self.insertAndSendMessages([msg], needSendMsg: true)

                    //                    let msg = SocketMessage.init(filePath: filePath, fileSize: data.count, from: IMLoginUser.shared().userId, to: self.conversation.conversationId, channelType: self.conversation.type,isBurn: false, isEncryptMsg:self.isEncrypt)
                    //                    self.insertAndSendMessages([msg], needSendMsg: true)
                } else {
                    self.showToast(L("文件选取失败，请重试"))
                }
            }
            fileURL.stopAccessingSecurityScopedResource()
        } else {
            self.showToast(L("文件选取失败,请重试"))
        }
    }

    // 重发消息
    func reSendMessage(msg: Message) {
        var message = msg
        if message.status == .failed {
            message.status = .sending
            message.datetime = Date.timestamp

            DispatchQueue.main.async {
                self.refreshListLock.lock()

                if let index = self.messageArray.firstIndex(of: msg) {
                    self.messageArray[index] = message
                    self.reloadSectionSafely(index)
                }
                // ⚠️ 必须无条件解锁：原来 guard 失败直接 return 会把锁留着 ⇒ 下次主线程 lock 死锁
                self.refreshListLock.unlock()

                let serverUrl = self.chatServerUrl ?? ""
                if serverUrl.isBlank && self.session.id.isPersonChat {
                    // 获取用户详情请求
                    self.refreshUserInfoRequestInChatVC()

                    // 获取用户员工信息以及企业信息以获取对方的聊天服务器
                    self.getStaffInfoRequest()
                }
                ChatManager.shared().send(msg: message, chatServerUrl: serverUrl)
            }
        }
    }
}

//MARK: - 消息cell数据源
extension ChatVC: MessageDataSource {
    func messageCollectionView(
        _ messageCollectionView: MessageCollectionView, messageForItemAt indexPath: IndexPath
    ) -> Message {
        guard self.messageArray.count > indexPath.section else {
            return Message.init(fromId: "", sessionId: self.session.id, msgType: .init(text: ""))
        }
        return self.messageArray[indexPath.section]
    }

    func numberOfSections(in messageCollectionView: MessageCollectionView) -> Int {
        return self.messageArray.count
    }

    func messageCollectionView(
        _ messageCollectionView: MessageCollectionView, numberOfItemsInSection section: Int
    ) -> Int {
        return 1
    }

    /// 消息时间戳DataSource
    func cellTopLabelAttributedText(for message: Message, at indexPath: IndexPath)
        -> NSAttributedString?
    {

        if message.showTime {
            let timeStr = String.showTimeString(with: Double(message.datetime))
            let attr = NSAttributedString(
                string: timeStr,
                attributes: [
                    .foregroundColor: Color_8A97A5,
                    .font: UIFont.preferredFont(forTextStyle: .footnote),
                ])

            return attr
        } else {
            return nil
        }
    }

    func cellBottomLabelAttributedText(for message: Message, at indexPath: IndexPath)
        -> NSAttributedString?
    {
        switch message.kind {
        case .notification(let notifyItem):
            let text = notifyItem.text
            // 自己撤回的文字消息：高亮"重新编辑"入口
            if notifyItem.revokedContent != nil {
                let attr = NSMutableAttributedString(
                    string: text,
                    attributes: [
                        .foregroundColor: Color_8A97A5,
                        .font: UIFont.preferredFont(forTextStyle: .footnote),
                    ])
                let keyword = L("重新编辑")
                let range = (text as NSString).range(of: keyword)
                if range.location != NSNotFound {
                    attr.addAttributes([.foregroundColor: Color_Theme], range: range)
                }
                return attr
            }
            let attr = NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: Color_8A97A5,
                    .font: UIFont.preferredFont(forTextStyle: .footnote),
                ])

            return attr
        default:
            return nil
        }
    }

    func messageTopLabelAttributedText(for message: Message, at indexPath: IndexPath)
        -> NSAttributedString?
    {
        //        return nil
        //        if message.showTime {
        //            let timeStr = String.showTimeString(with: Double(message.datetime))
        //            let attr = NSAttributedString(string: timeStr, attributes: [.foregroundColor: Color_8A97A5,.font:UIFont.preferredFont(forTextStyle: .footnote)])
        //
        //            return attr
        //        } else {
        return nil
        //        }
    }

    func messageBottomLabelAttributedText(for message: Message, at indexPath: IndexPath)
        -> NSAttributedString?
    {
        return nil
    }

    // MARK: - 引用消息

    /// 气泡下方那条引用条的内容。
    /// 布局阶段会高频调用（每次算行高/上屏都问一遍），所以按被引用消息的 logId 缓存**查到的那份**。
    func quotePreview(for message: Message, at indexPath: IndexPath) -> QuotePreview? {
        // refId > 0 才算真引用（历史数据里有一批 `{0,0}` 的假引用，见 `Message+PbMsg` 的注释）
        guard let refId = message.reference?.ref, refId > 0 else { return nil }
        if let cached = self.quotePreviewCache[refId] { return cached }

        // ⚠️ 先在**当前消息列表**里找：用户长按回复时那条消息就在列表里，按 logId 一定能命中。
        //    原来只查数据库 ⇒ 引用「别人发来的消息」时首帧查空（收消息落库与 logId 的写入时机不一致），
        //    气泡下方的引用条要等重进页面才出现（用户 2026-11-04 反馈）。
        //    列表里没有（比如原消息不在已加载窗口内）再回退数据库。
        let inListMsg = self.messageArray.first(where: { $0.logId == refId })
        let refMsg = inListMsg ?? ChatManager.shared().getMessage(byLogId: refId)

        guard let refMsg = refMsg, let preview = self.quotePreviewInfo(for: refMsg) else {
            // ⚠️ 这里**不再缓存"查不到"**：原消息可能下一帧才进列表 / 才落库，
            //    缓存住会让引用条一直空着，直到重进页面清空缓存。
            FZMLog("【引用】ref=\(refId) 取不到内容 inList=\(inListMsg != nil) db=\(refMsg != nil)")
            return nil
        }
        FZMLog("【引用】ref=\(refId) inList=\(inListMsg != nil) name=\(preview.name) content=\(preview.content.prefix(16))")
        self.quotePreviewCache[refId] = preview
        return preview
    }
}

extension ChatVC: MessageLayoutDataSource {
    /// 是否显示时间戳
    func cellTopLabelHeight(
        for message: Message, at indexPath: IndexPath,
        in messagesCollectionView: MessageCollectionView
    ) -> CGFloat {
        return message.showTime ? 30 : 0
    }

    func cellBottomLabelHeight(
        for message: MessageType, at indexPath: IndexPath,
        in messagesCollectionView: MessageCollectionView
    ) -> CGFloat {
        switch message.kind {
        case .notification(let notifyItem):
            let text = notifyItem.text
            let height =
                text.getContentHeight(
                    font: UIFont.preferredFont(forTextStyle: .footnote), width: k_ScreenWidth - 40)
                + 10

            return max(40, height)
        default:
            return 0
        }
    }
}

extension ChatVC: MessagesDisplayDelegate {
    // 列表滚动后是否隐藏顶部/底部未读消息视图处理
    override func collectionView(
        _ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {

        if self.collectionView.mj_header?.isRefreshing == false,
            topUnreadCount <= messageArray.count,
            indexPath.section <= messageArray.count - topUnreadCount
        {
            hideTopUnreadBtn()
        }
        if indexPath.section >= collectionView.numberOfSections - 1 {
            hideBottomUnreadBtn()
        }
        
        // 视频消息：cell 一出现就先把文件拉到本地（点开即播）。
        // 内部有全局去重 + 最多 2 条并行的上限，滚屏时不会把带宽/内存打满。
        if indexPath.section < messageArray.count, let contentCell = cell as? MessageContentCell {
            let message = messageArray[indexPath.section]
            if case .video = message.kind {
                contentCell.vm?.prefetchVideoIfNeeded()
            }
            // 多选勾选状态（cell 复用后必须重新设置）
            let isSelected = self.selectedMsgs.contains(where: { $0.msgId == message.msgId })
            contentCell.setSelectMode(self.showSelect, selected: isSelected)
        }
    }

    // 头像显示处理
    func configureAvatarView(
        _ avatarView: AvatarView, for message: Message, at indexPath: IndexPath,
        in messagesCollectionView: MessageCollectionView
    ) {
        if message.isOutgoing {  //自己
            if LoginUser.shared().avatarUrl.isEmpty {
                avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
            } else {
                avatarView.kf.setImage(
                    with: URL.init(string: LoginUser.shared().avatarUrl),
                    placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
            }
        } else {  //其他用户
            UserManager.shared().getUser(by: message.fromId) { (user) in
                DispatchQueue.main.async {
                    guard let user = user else {
                        avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
                        return
                    }
                    avatarView.kf.setImage(
                        with: URL.init(string: user.avatarURLStr),
                        placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
                }
            }

            if let user = message.user {
                avatarView.kf.setImage(
                    with: URL.init(string: user.avatarURLStr),
                    placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
            } else {
                if let user = UserManager.shared().user(by: message.fromId) {
                    avatarView.kf.setImage(
                        with: URL.init(string: user.avatarURLStr),
                        placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
                } else {
                    avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
                    UserManager.shared().getNetUser(targetAddress: message.fromId)
                }
            }
        }
    }

    // 群成员昵称、类型视图
    func configureNameView(
        _ nameView: NameView, for message: Message, at indexPath: IndexPath,
        in messagesCollectionView: MessageCollectionView
    ) {
        guard !self.session.isPrivateChat else {
            nameView.isHidden = true
            return
        }

        nameView.isHidden = false

        var nameStr = message.fromId.shortAddress
        var type = 0

        if let member = message.member {
            nameStr = member.contactsName
            type = member.memberType
        } else {
            if let member = GroupManager.shared().getDBGroupMember(
                with: self.session.id.idValue.intEncoded, memberId: message.fromId)
            {
                nameStr = member.contactsName
                type = member.memberType
            } else if let user = UserManager.shared().user(by: message.fromId) {
                nameStr = user.contactsName
            }
        }

        nameView.setNameAndType(isOutgoing: message.isOutgoing, name: nameStr, userType: type)
    }

    // 消息发送状态处理
    func configureStatusView(
        _ statusView: UIImageView, for message: Message, at indexPath: IndexPath,
        in messagesCollectionView: MessageCollectionView
    ) {
        //
        guard message.isOutgoing else {
            statusView.isHidden = true
            return
        }

        var isNotifyMsg = false
        switch message.msgType {
        case .notify:
            isNotifyMsg = true
        default:
            isNotifyMsg = false
        }
        if !isNotifyMsg {
            statusView.isHidden = !message.isOutgoing
            // cell 复用：先清掉上一次「发送中」的旋转动画，避免状态切换后残留旋转
            statusView.layer.removeAnimation(forKey: "rotation")

            switch message.status {
            case .failed:
                statusView.image = #imageLiteral(resourceName: "chat_sendfail")
            case .sent, .delivered:
                // 私聊里隐藏「发送成功」和「已读（对方已接收）」图标，只保留发送失败的红色按钮；
                // 群聊原本就不显示这两个状态，这里统一用 isHidden 表达，语义更明确。
                statusView.isHidden = true
            case .sending:
                statusView.image = #imageLiteral(resourceName: "chat_sending")
                makeSendingAnimation(statusView)
            case .deleted:
                statusView.isHidden = true
            }
        } else {
            statusView.isHidden = true
        }
    }

    // 语音未读红点
    func configureRedDotView(
        _ redDotView: UIView, for message: Message, at indexPath: IndexPath,
        in messagesCollectionView: MessageCollectionView
    ) {
        guard case .audio = message.msgType, !message.isOutgoing else {
            redDotView.isHidden = true
            return
        }

        if !message.isRead {
            redDotView.isHidden = false
        } else {
            redDotView.isHidden = true
        }
    }

    // 消息发送中图片旋转动画
    func makeSendingAnimation(_ sendingView: UIImageView) {
        if !sendingView.isHidden {
            if sendingView.layer.animation(forKey: "rotation") != nil {
                sendingView.layer.removeAnimation(forKey: "rotation")
            }
            // 1.创建动画
            let rotationAnim = CABasicAnimation(keyPath: "transform.rotation.z")
            // 2.设置动画的属性
            rotationAnim.fromValue = 0
            rotationAnim.toValue = Double.pi * 2
            rotationAnim.repeatCount = MAXFLOAT
            rotationAnim.duration = 1.0
            // 这个属性很重要 如果不设置当页面运行到后台再次进入该页面的时候 动画会停止
            rotationAnim.isRemovedOnCompletion = false
            // 3.将动画添加到layer中
            sendingView.layer.add(rotationAnim, forKey: "rotation")
        }
    }
}

// MARK: - 点击/长按事件回调
extension ChatVC: MessageCellDelegate {

    /// 点击事件

    // 点击背景区域
    func didTapBackground(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapBackground")
    }

    /// 打开阅后即焚独立详情页（只能看这一条）
    private func openBurnDetail(_ message: Message) {
        guard self.session.isPrivateChat else { return }
        let vc = FZMBurnDetailVC(message: message, targetId: message.burnConfirmTargetId)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // 点击消息气泡下方的引用条：滚到被引用的原消息
    func didTapQuote(in cell: MessageContentCell, message: Message) {
        guard let refId = message.reference?.ref else { return }
        FZMLog("didTapQuote ref=\(refId)")
        // 多选模式下不跳转：这时点引用条应该也是"选中这条消息"
        if self.showSelect {
            self.toggleSelect(message: message)
            return
        }
        self.scrollToMessage(logId: refId)
    }

    /// 点「该消息内容无法显示」：重新拉密钥解密，成功后会回填消息体并刷新这条气泡
    private func retryUnparsedMessage(_ message: Message) {
        guard ChatManager.shared().unparsedMsg(msgId: message.msgId) != nil else {
            self.showToast(L("没有可重试的消息内容"))
            return
        }
        self.showToast(L("正在重新获取消息…"))
        // 用户主动重试：强制从网络刷新群密钥 / 发送者公钥。
        // 自动批量重试仍用本地缓存，避免放大请求。
        ChatManager.shared().retryDecryptUnparsed(msgId: message.msgId, refreshKeys: true) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.showToast(ok ? L("消息已恢复") : L("消息内容仍无法获取"))
            }
        }
    }

    /// 图片「加载失败」时点击：重新走一遍「Kingfisher 直连 → 下载 + 解密」兜底。
    /// （`loadEncryptedImage` 每次都会重新取公钥，所以这是真重试，不是读缓存）
    private func retryLoadPhoto(in cell: MediaMessageCell, message: Message) {
        self.showToast(L("正在重新获取图片…"))
        guard let indexPath = self.collectionView.indexPath(for: cell) else { return }
        cell.configure(with: message, at: indexPath, and: self.collectionView)
    }

    // 点击消息内容区域
    func didTapMessage(in cell: MessageContentCell, message: Message) {
        FZMLog("didTapMessage \(message)")

        // 多选模式：点消息 = 切换选中（不再走原来的打开/播放）
        if self.showSelect {
            // 通知消息 / 系统消息不参与多选
            switch message.msgType {
            case .notify, .system:
                return
            default:
                break
            }
            self.toggleSelect(message: message)
            return
        }

        // 「该消息内容无法显示」：点一下重新拉密钥解密（会话密钥 → 发送者个人公钥）
        if case .text(let text) = message.kind, text.isBlank {
            self.retryUnparsedMessage(message)
            return
        }

        //        self.view.endEditing(true)
        self.inputBarView.inputTextView.textView.resignFirstResponder()

        // 阅后即焚占位：点开独立详情页
        if message.isBurnPlaceholder {
            self.openBurnDetail(message)
            return
        }

        curTapMsg = message

        var isFileExist = false

        // 文件本地路径
        let filePath = FZMMessageBaseVM.getFilePath(with: message)
        if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
            // 本地有缓存文件
            isFileExist = true
        }

        switch message.kind {
        case .photo:
            guard let cell = cell as? MediaMessageCell else { return }
            // 图片「加载失败」（直连 + 下载解密都失败）：再点一次 = 重新拉公钥 + 解密，
            // 而不是打开大图 —— 大图拿的还是同一份密文，打开也是空白。
            if cell.isPhotoLoadFailed {
                self.retryLoadPhoto(in: cell, message: message)
                return
            }
            curTapMediaCell = cell
            self.showBigImageViewFromView(cell: cell, msg: message)

        case .audio:
            //            self.playVoice(msg: message)
            if isFileExist {
                VoiceMessagePlayerManager.shared().playVoice(msg: message)
            } else {
                self.downloadData(cell: cell, msg: message)
            }

        case .video:
            //            let cell = cell as! MediaMessageCell
            //            curTapMediaCell = cell
            //            self.playViedo(cell: cell, msg: message)

            if isFileExist {
                self.saveToAlUrl = filePath
                self.playVideoWithUrl(fileUrl: filePath)
            } else {
                self.downloadData(cell: cell, msg: message)
            }

        case .text:
            // 分享链接卡片（AI 客服 / 商城 H5）：气泡里是一张卡片，点卡片就打开卡片里的链接
            // （正文里的链接不直接展示，所以不能走「取正文第一段链接」那条路）
            // ⚠️ 卡片样式关闭时气泡是文本版式，走下面的文本链接逻辑（点非链接区域不响应）
            if FZM_EnableShareLinkCard, let card = ShareLinkCard.parse(message.msgType.textValue) {
                self.openUrl(urlStr: card.url as NSString)
                return
            }
            self.openUrl(urlStr: message.msgType.text as NSString)

        case .file:
            //            let cell = cell as! FileMessageCell
            //            curTapFileCell = cell
            //            self.openFile(cell: cell, msg: message)

            if isFileExist {
                self.showPDF(url: URL.init(fileURLWithPath: filePath))
            } else {
                self.downloadData(cell: cell, msg: message)
            }

        case .forward:
            // 合并转发卡片：点开看被打包的那几条消息
            guard let items = message.msgType.forwardItems else { return }
            let vc = ForwardDetailVC.init(items: items)
            self.navigationController?.pushViewController(vc, animated: true)

        case .transfer:
            let vc = TradeDetailViewController.init()
            vc.isPushedByNotification = true
            vc.coin = FZMMessageBaseVM.getLocalCoin(with: message)
            vc.tradeHash = message.msgType.txHash

            self.navigationController?.pushViewController(vc, animated: true)

        case .redPacket(let redPacketItem):
            // 点击红包消息，跳转到红包详情页
            guard let packetId = redPacketItem.redtxHash, !packetId.isEmpty else {
                showToast(L("红包ID无效"))
                return
            }
            handleRedPacketTap(packetId: packetId, coinName: redPacketItem.redcoinName ?? "", senderAddress: message.fromId)

        case .contactCard(_):
            let type = message.msgType.contactType
            // 名片字段来自服务端/对方客户端，可能为空或不是数字：不能强解包，否则点一下直接崩
            let contactId = (message.msgType.contactId ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if type == 1 {
                guard !contactId.isEmpty else {
                    showToast(L("参数错误"))
                    return
                }
                FZMUIMediator.shared().pushVC(
                    .goUserDetailInfoVC(address: contactId, source: .normal))
            } else if type == 2 {
                guard let groupId = Int(contactId) else {
                    showToast(L("参数错误"))
                    return
                }
                let inviteId =
                    message.isOutgoing ? LoginUser.shared().address : self.session.id.idValue
                FZMUIMediator.shared().pushVC(
                    .goAddGroup(groupId: groupId, inviterId: inviteId))
            } else if type == -1 {
                // 安卓端的「专属红包」：走名片消息兼容通道，csv（`领取人,金额,时间`）放在 contactAvatar 里。
                // 那条消息里**没有链上红包 ID**，所以进我们的详情页时走「本地只读模式」，全程不查链。
                let csv = message.msgType.contactAvatar ?? ""
                let vc = FZMRedBagInfoVC(
                    with: "",
                    isShowRecord: false,
                    coinName: "",
                    senderAddress: message.fromId,
                    localExclusiveCSV: csv
                )
                navigationController?.pushViewController(vc, animated: true)
            } else {
                // 旧通道的兼容兑底：保留原页面，但**去掉强制解包**（avatar 为空时会崩）
                FZMUIMediator.shared().pushVC(
                    .goRedpacket(detail: message.msgType.contactAvatar ?? ""))
            }

        default:
            return
        }
    }

    //打开消息内的url
    func openUrl(urlStr: NSString) {
        // ★ 消息文本里常常夹着别的话（「来玩 https://x.com/?room=ab&pin=1234 啊」），
        //   所以先用系统检测器把**第一段链接**挑出来，而不是把整条文本当成 URL 丢出去。
        if let url = ChatVC.firstLink(in: urlStr as String) {
            // 语音房 / 群视频链接（带 `room` 参数）→ 通话容器（全屏 ↔ 悬浮框，
            // **全 App 只有它带「缩放」按钮**）；其它链接 → **App 内 DApp 浏览器**
            // （不再跳系统 Safari）。两条路都收敛到 `VoiceRoomLauncher.open`，
            // 它内部按 `isVoiceRoomLink` 分流：语音房进容器，其余 push `DAppBrowserViewController`。
            VoiceRoomLauncher.open(url: url, from: self)
            return
        }

        // 挑不出链接时，退回原有行为（原文含 "www" 才交给系统浏览器）
        if urlStr.contains("www") {
            if let url = URL(string: urlStr as String) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
    }

    /// 从任意文本里挑出**第一段** http/https 链接（挑不出返回 nil）
    private static func firstLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, options: [], range: range) {
            guard let url = match.url else { continue }
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" {
                return url
            }
        }
        return nil
    }

    // 下载语音、视频、文件类型消息（需把资源文件缓存到本地的消息）
    func downloadData(cell: MessageContentCell, msg: Message) {
        // 开始下载文件
        DispatchQueue.global().async {
            cell.vm?.downloadData()
        }

        // 下载成功订阅
        cell.vm?.fileDownloadSucceedSubject.subscribe { [weak self] (event) in
            guard let strongSelf = self, case .next(let msg) = event,
                msg.msgId == strongSelf.curTapMsg?.msgId
            else { return }  // 判断回调后当前点击的消息
            let filePath = FZMMessageBaseVM.getFilePath(with: msg)
            guard !filePath.isBlank, FZMLocalFileClient.shared().isFileExists(atPath: filePath)
            else {
                return
            }
            if case .file = msg.msgType {
                strongSelf.showPDF(url: URL.init(fileURLWithPath: filePath))
            } else if case .video = msg.msgType {
                strongSelf.saveToAlUrl = filePath
                strongSelf.playVideoWithUrl(fileUrl: filePath)
            } else if case .audio = msg.msgType {
                VoiceMessagePlayerManager.shared().playVoice(msg: msg)
            }
        }.disposed(by: bag)

        // 下载失败
        cell.vm?.fileDownloadFailedSubject.subscribe({ [weak self] (event) in
            guard let strongSelf = self, case .next(let msg) = event,
                msg.msgId == strongSelf.curTapMsg?.msgId
            else { return }
            strongSelf.showToast(L("下载失败"))
            FZMLog("下载失败 msg \(msg)")
        }).disposed(by: bag)

        // 下载进度
        cell.vm?.fileDownloadProgressSubject.subscribe({ (event) in
            guard case .next(let progress) = event else { return }
            if case .file = msg.msgType, let fileCell = cell as? FileMessageCell {
                fileCell.updateDownLoadProcress(proress: progress)
            } else if case .video = msg.msgType, let mediaCell = cell as? MediaMessageCell {
                mediaCell.updateDownLoadProcress(proress: progress)
            }
        }).disposed(by: bag)
    }

    //    //播放语音
    //    func playVoice(msg: Message) {
    //        FZMLog("播放语音消息。。。。。巴拉巴拉小魔仙")
    //        guard msg.status == 0 || msg.status == 3 else {return}
    //
    //        // 修改播放标识为已读
    //
    //        let filePath = DocumentPath.appendingPathComponent("Voice/WavFile/\(msg.msgType.cachekey ?? "").wav")// 待播放语音的本地路径（传输用amr格式，播放用wav格式）
    //
    //        if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
    //            // 本地有缓存文件
    //            VoiceMessagePlayerManager.shared().playVoice(msg: msg)
    //        } else {
    //            let fileUrl = msg.msgType.fileUrl ?? ""// 文件url地址
    //
    //            self.videoOrFile = 3// 视频==1   文件==2  语音==3
    //            self.downloadData(fileUrl: fileUrl)
    //        }
    //    }

    // 浏览文件
    func showPDF(url: URL) {
        documentInteractionController = UIDocumentInteractionController(url: url)
        documentInteractionController.delegate = self

        DispatchQueue.main.async { [self] in

            let canOpen = documentInteractionController.presentPreview(animated: true)
            if !canOpen {
                if var navRect = self.navigationController?.navigationBar.frame {
                    navRect.size = CGSize.init(width: 1500, height: 40)
                    documentInteractionController.presentOpenInMenu(
                        from: navRect, in: self.view, animated: true)
                }
            }
        }
    }

    //    //打开文件 url地址保存在UserDefaults(下载使用)，文件沙盒路径：在Document/File/文件名.文件类型
    //    func openFile(cell: FileMessageCell, msg: Message){
    //        guard msg.status == 0 || msg.status == 3 else {return}
    //
    //        let filePath = FZMMessageBaseVM.getFilePath(with: msg)
    //
    //        if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
    //            // 本地有缓存文件
    //            self.showPDF(url: URL.init(fileURLWithPath: filePath))
    //
    //        } else {
    //
    //            // 开始下载文件
    //            cell.vm?.downloadData()
    //
    //            // 下载成功订阅
    //            cell.vm?.fileDownloadSucceedSubject.subscribe { [weak self] (event) in
    //                guard let strongSelf = self, case .next(let msg) = event, msg.msgId == self?.curTapMsg?.msgId else { return }// 判断回调后当前点击的消息
    //                let filePath = FZMMessageBaseVM.getFilePath(with: msg)
    //                guard !filePath.isBlank else {
    //                    return
    //                }
    //                strongSelf.showPDF(url: URL.init(fileURLWithPath: filePath))
    //            }.disposed(by: bag)
    //
    ////            let fileUrl = msg.msgType.fileUrl ?? ""// 文件url地址
    ////
    ////            self.videoOrFile = 2// 视频==1   文件==2  语音==3
    ////            self.downloadData(fileUrl: fileUrl)
    //        }
    //    }
    //
    //    //播放视频
    //    func playViedo(cell: MediaMessageCell, msg: Message){
    //        guard msg.status == 0 || msg.status == 3 else {return}
    //
    //        let filePath = FZMMessageBaseVM.getFilePath(with: msg)
    //        if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
    //            // 本地有缓存文件
    //            self.saveToAlUrl = filePath
    //            self.playVideoWithUrl(fileUrl: filePath)
    //
    //        } else {
    //            // 开始下载文件
    //            cell.vm?.downloadData()
    //
    //            // 下载成功订阅
    //            cell.vm?.fileDownloadSucceedSubject.subscribe { [weak self] (event) in
    //                guard let strongSelf = self, case .next(let msg) = event, msg.msgId == self?.curTapMsg?.msgId else { return }// 判断回调后当前点击的消息
    //                let filePath = FZMMessageBaseVM.getFilePath(with: msg)
    //                guard !filePath.isBlank else {
    //                    return
    //                }
    //                strongSelf.saveToAlUrl = cell.vm?.saveVideoToAlUrl ?? ""
    //                strongSelf.playVideoWithUrl(fileUrl: filePath)
    //            }.disposed(by: bag)
    //
    //            let fileUrl = msg.msgType.url ?? ""// 文件url地址
    //
    //            self.videoOrFile = 1// 视频==1   文件==2  语音==3
    //            self.downloadData(fileUrl: fileUrl)
    //        }
    //    }
    //播放视频
    func playVideoWithUrl(fileUrl: String) {
        DispatchQueue.main.async {
            try? AVAudioSession.sharedInstance().setCategory(.playback)  // 添加此行代码可在静音模式下播放音频

            let item = AVPlayerItem(url: URL(fileURLWithPath: fileUrl))
            let play = AVPlayer(playerItem: item)
            let playController = AVPlayerViewController()
            playController.player = play

            // 记下正在播的这条：播放器本身不持有消息，长按菜单要用
            self.playingVideoMsg = self.curTapMsg
            self.playingVideoPath = fileUrl
            self.playingPlayerVC = playController

            self.present(
                playController, animated: true,
                completion: {
                    playController.view.addSubview(self.downloadBtn)
                    playController.view.bringSubviewToFront(self.downloadBtn)
                    self.downloadBtn.tag = 2
                    self.downloadBtn.frame = CGRect.init(
                        x: k_ScreenWidth - 80, y: k_ScreenHeight - 80, width: 30, height: 30)

                    // 长按视频：底部菜单（转发视频 / 保存视频），与大图长按的菜单保持一致
                    let longPress = UILongPressGestureRecognizer(
                        target: self, action: #selector(self.handlePlayVideoLongPress(_:)))
                    playController.view.addGestureRecognizer(longPress)
                })
        }
    }

    // MARK: - 视频长按菜单（转发 / 保存）

    @objc private func handlePlayVideoLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        VoiceMessagePlayerManager.shared().vibrateAction()
        self.showVideoLongPressMenu()
    }

    /// 视频长按菜单：转发视频 / 保存视频（表现与图片大图的长按菜单一致）
    private func showVideoLongPressMenu() {
        var options = [FZMBottomOption]()
        let msg = self.playingVideoMsg

        // 阅后即焚：不给转发 / 保存（和聊天里长按菜单的规则一致）
        if let msg = msg, !msg.isBurn, MessageForwarder.canForward(msg) {
            options.append(FZMBottomOption(title: L("转发视频"), block: { [weak self] in
                guard let self = self else { return }
                // 先关播放器再弹选人页（选人页要盖在播放器上，直接弹会被转场吃掉）
                self.closeVideoPlayer {
                    MessageForwarder.presentMultiPicker(from: self) { [weak self] sessionIDs in
                        guard let self = self else { return }
                        MessageForwarder.forward([msg], to: sessionIDs, from: self)
                    }
                }
            }))
        }

        if msg?.isBurn != true {
            options.append(FZMBottomOption(title: L("保存视频"), block: { [weak self] in
                self?.savePlayingVideoToAlbum()
            }))
        }

        guard !options.isEmpty else { return }
        FZMBottomSelectView.show(with: "", arr: options)
    }

    /// 关闭播放器，等关闭动画走完再做事
    private func closeVideoPlayer(then action: @escaping () -> Void) {
        if let player = self.playingPlayerVC {
            player.dismiss(animated: true)
        } else {
            self.dismiss(animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
    }

    /// 保存正在播放的视频到相册（能播就说明文件已经在本地了）
    private func savePlayingVideoToAlbum() {
        let path = self.playingVideoPath.isEmpty ? self.saveToAlUrl : self.playingVideoPath
        guard !path.isEmpty, FZMLocalFileClient.shared().isFileExists(atPath: path),
              UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path) else {
            self.showToast(L("视频保存失败"))
            return
        }
        UISaveVideoAtPathToSavedPhotosAlbum(
            path, self, #selector(self.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
    }

    //    //下载视频
    //    func downloadData(fileUrl : String){
    //        guard !fileUrl.isBlank else {
    //            self.showToast("数据加载失败")
    //            return
    //        }
    //        let downloadTask : URLSessionDownloadTask
    //        let urlString: String = fileUrl
    //        let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
    //        downloadTask = session.downloadTask(with: urlString.url!)
    //        downloadTask.resume()
    //    }

    // 查看大图
    // MARK: - 大图长按菜单（转发 / 识别二维码 / 保存）
    //
    // ⚠️ 这些方法在 extension 里，**不能声明存储属性**（Extensions must not contain stored properties），
    // 所以不缓存 Lantern：长按手势直接加在 Lantern 自己的 view 上，`gesture.view` 就是容器，
    // 关闭时再顺着响应链取回它所属的控制器（见 `viewController(hosting:)`）。

    func showBigImageViewFromView(cell: MediaMessageCell, msg: Message) {

        let lantern = Lantern()
        lantern.numberOfItems = {
            1
        }
        lantern.reloadCellAtIndex = { context in
            let url = msg.msgType.url ?? ""
            let lanternCell = context.cell as? LanternImageCell
            let placeholder = cell.imageView.image
            // Kingfisher
            lanternCell?.imageView.kf.setImage(
                with: URL.init(string: url), placeholder: placeholder,
                options: [.targetCache(ChatMediaCache)])
        }
        lantern.transitionAnimator = LanternZoomAnimator(previousView: { index -> UIView? in
            return cell.imageView
        })
        lantern.pageIndex = 1
        lantern.view.addSubview(downloadBtn)
        downloadBtn.tag = 1
        downloadBtn.frame = CGRect.init(
            x: k_ScreenWidth - 45, y: k_ScreenHeight - 60, width: 30, height: 30)
        // 长按大图：底部菜单（转发 / 识别二维码 / 保存），与广场大图保持一致
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleBigImageLongPress(_:)))
        lantern.view.addGestureRecognizer(longPress)
        lantern.show()
    }

    @objc private func handleBigImageLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let container = gesture.view else { return }
        VoiceMessagePlayerManager.shared().vibrateAction()

        // 识别放后台（多档兜底：私聊里的大图常是截图 / 低清缩略图，小二维码也要认出来；
        // 一张图里的**所有**二维码都收，用户才能「点哪个扫哪个」），回来再弹菜单
        PhotoLongPressHelper.qrCodes(in: PhotoLongPressHelper.visibleImage(in: container)) { [weak self] hits in
            // 识别期间大图可能已经被关掉
            guard let self = self, container.window != nil else { return }
            self.showBigImageLongPressMenu(in: container, qrCodes: hits)
        }
    }

    /// 大图长按菜单：转发图片 / （图里有二维码时）识别图中二维码 / 保存图片
    private func showBigImageLongPressMenu(in container: UIView, qrCodes: [QRCodeHit]) {
        var options = [FZMBottomOption]()
        options.append(FZMBottomOption(title: L("转发图片"), block: { [weak self] in
            guard let self = self,
                  let image = PhotoLongPressHelper.visibleImage(in: container) else {
                self?.showToast(L("图片还在加载中，请稍后再试"))
                return
            }
            self.closeBigImage(container) { PhotoLongPressHelper.forward(image, from: self) }
        }))
        // 图里没有二维码就不给「识别图中二维码」这一项（和广场一致）
        if !qrCodes.isEmpty {
            options.append(FZMBottomOption(title: L("识别图中二维码"), block: { [weak self] in
                guard let self = self else { return }
                // 只有一个码：直接识别（不多点一次）；多个码：先在图上点选，点哪个扫哪个
                guard qrCodes.count > 1 else {
                    if let hit = qrCodes.first { self.handlePickedQRCode(hit.value, in: container) }
                    return
                }
                PhotoLongPressHelper.pickQRCode(in: container, hits: qrCodes) { [weak self] hit in
                    guard let self = self, let hit = hit else { return }   // 点空白处 = 取消
                    self.handlePickedQRCode(hit.value, in: container)
                }
            }))
        }
        options.append(FZMBottomOption(title: L("保存图片"), block: { [weak self] in
            self?.saveBigImage(in: container)
        }))
        FZMBottomSelectView.show(with: "", arr: options)
    }

    /// 选中某个二维码：关掉大图再按「扫一扫」那套逻辑处理（加好友 / 加群 / 开链接…）
    private func handlePickedQRCode(_ qrString: String, in container: UIView) {
        self.closeBigImage(container) {
            if !QRCodeResultHandler.handle(qrString, from: UIViewController.current()) {
                APP.shared().showToast(qrString)
            }
        }
    }

    /// 关闭大图，等关闭动画走完再做事（选择页 / 加群页要盖在大图上，直接弹会被转场吃掉）
    private func closeBigImage(_ container: UIView, then action: @escaping () -> Void) {
        if let lantern = self.viewController(hosting: container) as? Lantern {
            // 用 Lantern 自己的 dismiss()：它会走「缩回缩略图」的转场
            // （注意：UIViewController 没有无参 dismiss，所以必须转成 Lantern 再调）
            lantern.dismiss()
        } else {
            self.viewController(hosting: container)?.dismiss(animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
    }

    /// 从视图顺着响应链找它所属的控制器（大图容器 → Lantern）
    private func viewController(hosting view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }

    /// 保存当前大图：GIF 走原有逻辑（只有它能保真存动图），普通图片优先存屏幕上这张大图
    /// （比原来那个「存缩略图」的按钮清楚，且不改变已有按钮的行为）
    private func saveBigImage(in container: UIView) {
        if curTapMsg?.gifData != nil {
            self.saveBtnClick()
            return
        }
        if let image = PhotoLongPressHelper.visibleImage(in: container) {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
            return
        }
        self.saveBtnClick()
    }

    //保存图片和保存视频公用 tag==1保存图片  tag==2保存视频
    func saveBtnClick() {
        if self.downloadBtn.tag == 1 {  //保存图片
            let imgData = curTapMsg?.gifData
            if imgData != nil {  //保存gif到相册
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    PHAssetCreationRequest.forAsset().addResource(
                        with: .photo, data: imgData! as Data, options: options)
                }) { (isSuccess: Bool, error: Error?) in
                    var showMessage = ""
                    if isSuccess {
                        showMessage = L("图片已保存")
                    } else {
                        showMessage = L("图片保存失败")
                    }
                    DispatchQueue.main.async {
                        APP.shared().showToast(showMessage)
                    }
                }
            } else {  //保存普通图片到相册
                guard let img = curTapMediaCell?.imageView.image else {
                    self.showToast(L("图片保存失败"))
                    return
                }
                UIImageWriteToSavedPhotosAlbum(
                    img, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
            }
        } else {  //保存视频
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.saveToAlUrl) {
                UISaveVideoAtPathToSavedPhotosAlbum(
                    self.saveToAlUrl, self,
                    #selector(self.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }

    @objc func video(
        videoPath: String, didFinishSavingWithError error: NSError, contextInfo info: AnyObject
    ) {
        var showMessage = ""
        if error.code != 0 {
            showMessage = L("视频保存失败")
        } else {
            showMessage = L("视频已保存")
        }
        DispatchQueue.main.async {
            APP.shared().showToast(showMessage)
        }
    }

    @objc func image(
        image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject
    ) {
        var showMessage = ""
        if error != nil {
            showMessage = L("图片保存失败")
        } else {
            showMessage = L("图片已保存")

        }
        DispatchQueue.main.async {
            APP.shared().showToast(showMessage)
        }
    }

    // 点击其他人头像区域
    func didTapAvatar(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapAvatar")
        self.clickUserHeadImage(address: message.fromId)
    }

    // 跳转用户详情页
    private func clickUserHeadImage(address: String) {
        guard !showSelect else { return }
        //        FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: address, source: self.session.isPrivateChat ? nil : .group(groupId: self.session.id.idValue.intEncoded)))

        let vc = FriendInfoVC.init(
            with: address,
            source: self.session.isPrivateChat
                ? nil : .group(groupId: self.session.id.idValue.intEncoded))
        vc.sendredBlock = { [] (note) in
            print("note is \(note)")
            let addr = LoginUser.shared().address
            vc.navigationController?.popViewController()
            self.sendContactCard(contactId: addr, name: note, avatar: note, type: -1)
        }
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }

    // 点击自己头像区域
    func didTapSelfAvatar(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapSelfAvatar")
        self.clickUserHeadImage(address: message.fromId)
    }

    // 点击重发消息按钮
    func didTapStatusView(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapStatusView")
        guard message.status == .failed else { return }

        // 发送失败的消息重发
        self.reSendMessage(msg: message)
    }

    // 点击消息时间戳
    func didTapCellTopLabel(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapCellTopLabel")
    }

    func didTapCellBottomLabel(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapCellBottomLabel")
        self.reEditRevokedMsg(message)
    }
    
    // 撤回消息重新编辑：自己撤回的文字消息，点击撤回提示中的"重新编辑"即可回填原文
    private func reEditRevokedMsg(_ message: Message) {
        guard case .notify = message.msgType,
              message.msgType.type == 8,
              let revokedContent = message.msgType.revokedContent, !revokedContent.isBlank else { return }
        self.showReEditInput(with: revokedContent)
    }

    func didTapMessageTopLabel(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapMessageTopLabel")
    }

    func didTapMessageBottomLabel(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapMessageBottomLabel")
    }

    func didTapAccessoryView(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapAccessoryView")
    }

    func didTapLeadingView(in cell: MessageCollectionViewCell, message: Message) {
        FZMLog("didTapLeadingView")
    }

    // 长按事件
    // 长按背景区域
    func didLongPressBackground(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressBackground")
    }

    // 长按消息区域
    func didLongPressMessage(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressMessage")
        // 长按显示弹窗
        self.showMenu(in: cell.messageContainerView, msg: message)
    }

    // 长按其他人头像区域
    func didLongPressAvatar(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressAvatar")
        if !self.session.isPrivateChat, !message.isOutgoing {
            // 群聊长按头像 @此群成员，排除自己
            self.inputBarView.mentionGroupMember(
                with: self.session.id.idValue.intEncoded, msg: message)
        }
    }

    // 长按自己头像区域
    func didLongPressSelfAvatar(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressSelfAvatar")
    }

    func didLongPressCellTopLabel(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressCellTopLabel")
    }

    func didLongPressCellBottomLabel(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressCellBottomLabel")
        self.reEditRevokedMsg(message)
    }

    func didLongPressMessageTopLabel(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressMessageTopLabel")
    }

    func didLongPressMessageBottomLabel(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressMessageBottomLabel")
    }

    func didLongPressAccessoryView(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressAccessoryView")
    }

    func didLongPressLeadingView(in cell: MessageContentCell, message: Message) {
        FZMLog("didLongPressLeadingView")
    }
}

// MARK: - 多选 / 转发

extension ChatVC {

    /// 进入多选模式，并默认选中这条消息
    private func enterSelectMode(with msg: Message) {
        self.selectedMsgs = [msg]
        self.showSelect = true
    }

    /// 退出多选：**同步**恢复 UI（导航栏 / 输入区 / 底栏 / 可见单元格的勾选圈）。
    ///
    /// ⚠️ 为什么单独抽一个方法（2026-09-30 转发、2026-10-13 删除都踩过同一个坑）：
    ///    把「退出多选」写在**异步**流程里（等选会话回调 / 等删除后的列表刷新），
    ///    一旦那条路没走到（回调没执行、列表已经被 reload、页面已跳走），
    ///    聊天页就**一直停在多选状态**（圈圈不消、底部转发栏不收回）。
    /// ⚠️ 除了置 `showSelect = false`（走它的 `didSet` → 恢复各栏 + `reloadList()`），这里还
    ///    **同步**把可见单元格擦一遗：即使 `showSelect` 已经是 false（状态被别处改过），
    ///    也能把残留的勾选圈收回来。
    private func exitSelectMode() {
        self.showSelect = false
        self.selectedMsgs.removeAll()
        for indexPath in self.collectionView.indexPathsForVisibleItems {
            (self.collectionView.cellForItem(at: indexPath) as? MessageContentCell)?
                .setSelectMode(false, selected: false)
        }
    }

    /// 多选模式下点消息：切换选中
    private func toggleSelect(message: Message) {
        if let index = self.selectedMsgs.firstIndex(where: { $0.msgId == message.msgId }) {
            self.selectedMsgs.remove(at: index)
        } else {
            self.selectedMsgs.append(message)
        }
        guard let index = self.messageArray.firstIndex(where: { $0.msgId == message.msgId }) else {
            return
        }
        self.refreshListLock.lock()
        self.reloadSectionSafely(index)
        self.refreshListLock.unlock()
    }

    /// 逐条 / 合并转发选中的消息
    private func forwardSelectedMessages(merge: Bool) {
        guard !self.selectedMsgs.isEmpty else {
            self.showToast(L("请先选择要转发的消息"))
            return
        }
        // 按列表顺序（时间顺序）转发
        let ordered = self.messageArray.filter { msg in
            self.selectedMsgs.contains(where: { $0.msgId == msg.msgId })
        }
        // ⚠️ **立即退出多选**（并把要转的消息先拷出来）：
        //    选会话 / 发消息都是异步的，等到回调里再退多选，一旦回调没执行（或已经跳页），
        //    聊天页就会一直停在多选状态（圈圈留着、底栏不收回）。
        self.exitSelectMode()
        MessageForwarder.presentMultiPicker(from: self) { [weak self] sessionIDs in
            guard let self = self else { return }
            if merge {
                MessageForwarder.mergeForward(ordered, to: sessionIDs, from: self)
            } else {
                MessageForwarder.forward(ordered, to: sessionIDs, from: self)
            }
        }
    }

    /// 删除选中的消息（二次确认）
    private func deleteSelectedMessages() {
        let msgs = self.selectedMsgs
        guard !msgs.isEmpty else {
            self.showToast(L("请先选择要删除的消息"))
            return
        }
        let alert = TwoBtnInfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(
            string: L("提示"),
            attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Color_8A97A5])
        alert.leftBtnTitle = L("取消")
        alert.rightBtnTitle = L("确定")
        alert.attributedInfo = NSAttributedString.init(
            string: L("确认删除？"),
            attributes: [.foregroundColor: Color_24374E, .font: UIFont.systemFont(ofSize: 16)])
        alert.leftBtnTouchBlock = {}
        alert.rightBtnTouchBlock = { [weak self] in
            guard let self = self else { return }
            // ⚠️⚠️ **先退出多选、再删**（顺序和「转发」一致；2026-10-13 用户反馈删完仍停在全选状态）：
            //    删除是**异步**的（内部 `DispatchQueue.main.async` + 批量更新 + reload），
            //    多选状态的退出挂在它后面就可能回不来。`msgs` 已经先拷出来了，
            //    退出多选会清空 `selectedMsgs` 也不影响这次删除。
            self.exitSelectMode()
            self.deleteMessages(msgs)
        }
        alert.show()
    }
}

// MARK: - 长按弹窗
extension ChatVC {
    // 长按显示弹窗
    func showMenu(in targetView: MessageContainerView, msg: Message) {

        //        guard let window = UIApplication.shared.keyWindow, msg.status == .sent || msg.status == .delivered else { return }
        guard let window = UIApplication.shared.keyWindow else { return }

        self.view.endEditing(true)

        var itemArr = [FZMMsgMenuItem]()
        let copyItem = FZMMsgMenuItem(type: .copy) {
            FZMLog("复制")
            switch msg.kind {
            case .text:
                // 语音 / 视频聊天邀请消息：只复制**房间号**（用户 2026-10-29 要求），
                // 其它文本消息照原样复制整条正文。
                let text = msg.msgType.textValue
                if let card = ShareLinkCard.parse(text) {
                    // 卡片样式：只复制链接（正文里的抬头/「」/来源不是给人复制的东西）；
                    // 文本版式：复制还原后的整段文本（历史 JSON 消息也不会把 JSON 复制出去）
                    UIPasteboard.general.string = FZM_EnableShareLinkCard ? card.url : card.plainText
                } else {
                    UIPasteboard.general.string = VoiceRoomInvite.copyText(for: text)
                }
            default:
                break
            }
        }

        func changeVoicePlayMode() {
            VoiceMessagePlayerManager.shared().exchangePlayMode()
            let str = VoiceMessagePlayerManager.shared().playMode ? L("听筒") : L("扬声器")
            self.showToast(L("已切换为") + str + L("播放"))
        }

        let voiceItem: FZMMsgMenuItem
        if VoiceMessagePlayerManager.shared().playMode {
            voiceItem = FZMMsgMenuItem(
                type: .loudspeaker,
                block: {
                    FZMLog("扬声器")
                    changeVoicePlayMode()
                })
        } else {
            voiceItem = FZMMsgMenuItem(
                type: .handset,
                block: {
                    FZMLog("听筒")
                    changeVoicePlayMode()
                })
        }

        // 文本消息：系统翻译（iOS 17.4+，只走系统离线翻译）
        let translateItem = FZMMsgMenuItem(type: .translate) { [weak self] in
            FZMLog("翻译")
            guard let strongSelf = self else { return }
            strongSelf.translateTextMessage(msg)
        }

        // 已经翻译过的消息：同一个位置变成「取消翻译」，点了把译文从气泡下方撤掉
        let cancelTranslateItem = FZMMsgMenuItem(type: .cancelTranslate) { [weak self] in
            FZMLog("取消翻译")
            guard let strongSelf = self else { return }
            strongSelf.cancelTranslation(forMessageId: msg.msgId)
        }

        // 语音消息：离线转文字（SFSpeechRecognizer，音频不出设备）
        let toTextItem = FZMMsgMenuItem(type: .totext) { [weak self] in
            FZMLog("转文字")
            guard let strongSelf = self else { return }
            strongSelf.transcribeVoiceMessage(msg)
        }

        // 阅后即焚：不提供复制 / 转文字（只保留撤回与删除）
        if !msg.isBurn {
            switch msg.kind {
            case .text:
                itemArr.append(copyItem)
                if msg.translation?.isBlank == false {
                    // 有译文：优先给「取消翻译」（低版本系统也能取消）
                    itemArr.append(cancelTranslateItem)
                } else if self.canTranslateTextMessage(msg) {
                    itemArr.append(translateItem)
                }
            case .audio:
                itemArr.append(voiceItem)
                itemArr.append(toTextItem)
            default:
                break
            }
        }

        // 回复（引用）：仅支持文字、图片、视频、文件
        let replyItem = FZMMsgMenuItem(type: .reply) { [weak self] in
            FZMLog("回复（引用），自己发送的消息也可回复，回复消息默认@被回复的人，回复仅支持：文字、图片、视频、文件")
            guard let strongSelf = self else { return }
            strongSelf.replyMsgAction(msg)
        }
        switch msg.kind {
        case .text, .photo, .video, .file:
            itemArr.append(replyItem)
        default:
            break
        }

        // 撤回消息重新编辑（仅限自己撤回的文字消息）
        if case .notify = msg.msgType,
           msg.msgType.type == 8,
           let revokedContent = msg.msgType.revokedContent, !revokedContent.isBlank {
            let reeditItem = FZMMsgMenuItem(type: .reedit) { [weak self] in
                FZMLog("重新编辑")
                guard let strongSelf = self else { return }
                strongSelf.showReEditInput(with: revokedContent)
            }
            itemArr.append(reeditItem)
        }

        // 撤回（自己发送的消息；群主/管理员可撤回群成员消息；
        //      **私聊里也可以撤回对方发来的消息** —— 用户 2026-10-16 要求；
        //      **不限时间**，随时可撤回 —— 用户 2026-10-08 要求）
        let canRevoke: Bool = {
            switch msg.kind {
            case .notification:
                return false
            default:
                break
            }
            guard msg.status == .sent || msg.status == .delivered else { return false }
            if msg.isOutgoing { return true }
            // 私聊：对方发来的消息同样允许撤回（请求按 `type = 0` + logId 提交，是否放行由服务端判定）
            if self.session.isPrivateChat { return true }
            if let memberType = self.groupDetailInfo?.person?.memberType,
               memberType == 1 || memberType == 2 {
                return true
            }
            return false
        }()
        
        if canRevoke {
            let revokeItem = FZMMsgMenuItem(type: .revoked) {
                FZMLog("撤回")
                let alert = TwoBtnInfoAlertView.init()
                alert.attributedTitle = NSAttributedString.init(
                    string: L("提示"),
                    attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Color_8A97A5])
                alert.leftBtnTitle = L("取消")
                alert.rightBtnTitle = L("确定")
                
                let str = L("确认撤回该消息？")
                let attStr = NSMutableAttributedString.init(
                    string: str,
                    attributes: [
                        NSAttributedString.Key.foregroundColor: Color_24374E,
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                    ])
                alert.attributedInfo = attStr
                alert.leftBtnTouchBlock = {}
                alert.rightBtnTouchBlock = { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.revokeMessage(msg)
                }
                alert.show()
            }
            itemArr.append(revokeItem)
        }

        // 转发（单条）/ 多选：系统、通知类消息不支持转发；阅后即焚禁止转发 / 多选
        if !msg.isBurn, MessageForwarder.canForward(msg) {
            let forwardItem = FZMMsgMenuItem(type: .forward) { [weak self] in
                FZMLog("转发")
                guard let self = self else { return }
                MessageForwarder.presentMultiPicker(from: self) { [weak self] sessionIDs in
                    guard let self = self else { return }
                    MessageForwarder.forward([msg], to: sessionIDs, from: self)
                }
            }
            itemArr.append(forwardItem)

            let multSelectItem = FZMMsgMenuItem(type: .multselect) { [weak self] in
                FZMLog("多选")
                guard let self = self else { return }
                self.enterSelectMode(with: msg)
            }
            itemArr.append(multSelectItem)
        }

        let deleteItem = FZMMsgMenuItem(type: .delete) {
            FZMLog("删除")
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(
                string: L("提示"),
                attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Color_8A97A5])
            alert.leftBtnTitle = L("取消")
            alert.rightBtnTitle = L("确定")

            let str = L("确认删除？")
            let attStr = NSMutableAttributedString.init(
                string: str,
                attributes: [
                    NSAttributedString.Key.foregroundColor: Color_24374E,
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                ])
            alert.attributedInfo = attStr
            alert.leftBtnTouchBlock = {}
            alert.rightBtnTouchBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                // 删除消息数据
                strongSelf.deleteMessages([msg])
            }
            alert.show()
        }
        itemArr.append(deleteItem)

        //        let multselectItem = FZMMsgMenuItem(type: .multselect) {
        //            FZMLog("多选")
        //        }
        //        itemArr.append(multselectItem)
        //
        //        let mutedItem = FZMMsgMenuItem(type: .muted) {
        //            FZMLog("禁言")
        //        }
        //        itemArr.append(mutedItem)

        guard itemArr.count > 0, let tagSuperView = targetView.superview else { return }

        let fixedRect = tagSuperView.convert(targetView.frame, to: window)
        let view = FZMMsgMenuView(with: itemArr)

        var changeBgImgFlg = false

        switch msg.kind {
        case .text, .audio:
            changeBgImgFlg = true
        default:
            break
        }

        if changeBgImgFlg {
            if msg.isOutgoing {
                targetView.style = .outgoingDark
            } else {
                targetView.style = .incomingDark
            }
            view.hideBlock = {
                if msg.isOutgoing {
                    targetView.style = .outgoing
                } else {
                    targetView.style = .incoming
                }
            }
        }
        var bottomHeight = self.inputBarView.frame.height + k_SafeBottomInset
        if let inputBarSuperView = self.inputBarView.superview {
            let bottomFixRect = inputBarSuperView.convert(self.inputBarView.frame, to: window)
            bottomHeight = k_ScreenHeight - bottomFixRect.minY
        }
        view.show(in: fixedRect, bottomHeight: bottomHeight, isOutGoing: msg.isOutgoing)

        //        var itemArr = [FZMMenuItem]()
        //
        //        let pasteItem = FZMMenuItem(title: "复制") {
        //            switch msg.kind {
        //            case .text:
        //                UIPasteboard.general.string = msg.msgType.textValue
        //            case _:
        //                FZMLog("")
        //            }
        //        }
        //        let voiceItem = FZMMenuItem(title: VoiceMessagePlayerManager.shared().playMode ? "扬声器" : "听筒") {
        //            VoiceMessagePlayerManager.shared().exchangePlayMode()
        //            self.showToast("已切换为\(VoiceMessagePlayerManager.shared().playMode ? "听筒" : "扬声器")播放")
        //        }
        //        switch msg.kind {
        //        case .text:
        //            itemArr.append(pasteItem)
        //        case .audio:
        //            itemArr.append(voiceItem)
        //        case _:
        //            FZMLog("")
        //        }
        //
        //        let deleteItem = FZMMenuItem(title: "删除") {
        //            let alert = TwoBtnInfoAlertView.init()
        //            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
        //            alert.leftBtnTitle = "取消"
        //            alert.rightBtnTitle = "确定"
        //
        //            let str = "确认删除？"
        //            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
        //            alert.attributedInfo = attStr
        //            alert.leftBtnTouchBlock = {}
        //            alert.rightBtnTouchBlock = { [weak self] in
        //                guard let strongSelf = self else {
        //                    return
        //                }
        //                // 删除消息数据
        //                strongSelf.deleteMessages([msg])
        //
        //
        ////                self.deleteMsg(with: msg)
        //            }
        //            alert.show()
        //        }
        //        itemArr.append(deleteItem)
        //
        //        if itemArr.count > 0 {
        //            let fixedRect = targetView.superview!.convert(targetView.frame, to: window)
        //            let view = FZMMenuView(with: itemArr)
        //
        //            var changeBgImgFlg = false
        //
        //            switch msg.kind {
        //            case .text:
        //                changeBgImgFlg = true
        //            case .attributedText:
        //                FZMLog("")
        //            case .video:
        //                FZMLog("")
        //            case .photo:
        //                FZMLog("")
        //            case .audio:
        //                changeBgImgFlg = true
        //            case .system:
        //                FZMLog("")
        //            case .file:
        //                FZMLog("")
        //            case .transfer:
        //                FZMLog("")
        //            case .notification:
        //                FZMLog("")
        //            case .forward:
        //                FZMLog("")
        //            case _:
        //                FZMLog("")
        //            }
        //
        //            if changeBgImgFlg {
        //                if msg.isOutgoing {
        //                    targetView.style = .outgoingDark
        //                } else {
        //                    targetView.style = .incomingDark
        //                }
        //                view.hideBlock = {
        //                    if msg.isOutgoing {
        //                        targetView.style = .outgoing
        //                    } else {
        //                        targetView.style = .incoming
        //                    }
        //                }
        //            }
        //            view.show(in: CGPoint(x: fixedRect.minX, y: fixedRect.midY))
        //        }
    }

    // 菜单视图点击引用消息处理
    private func replyMsgAction(_ msg: Message) {
        self.referenceMsg = msg

        // 输入框引用条：图片/视频/文件带缩略图，纯文字走文本
        if let preview = self.quotePreviewInfo(for: msg) {
            self.inputBarView.setReference(preview)
        } else {
            self.inputBarView.referenceMsgStr(getReplyDetail(msg))
        }

        if !self.session.isPrivateChat, !msg.isOutgoing {
            // 引用消息，自动 @此群成员
            self.inputBarView.mentionGroupMember(with: self.session.id.idValue.intEncoded, msg: msg)
        } else {
            self.inputBarView.inputTextView.textView.becomeFirstResponder()
        }
    }

    // 清空引用态（发送成功后 / 单独取消引用）：输入框里的引用条和待发送的引用数据一起清
    private func clearReferenceState() {
        guard self.referenceMsg != nil else { return }
        self.referenceMsg = nil
        self.inputBarView.clearReference()
    }

    // 获取引用消息的文本内容（输入框上方那条引用条用）
    private func getReplyDetail(_ msg: Message) -> String {
        return self.quotePreviewInfo(for: msg)?.displayText ?? ""
    }

    // MARK: - 引用条内容

    /// 被引用的原消息 → 引用条内容。
    /// 返回 nil = 这条原消息没有可展示的正文（系统通知等），气泡下方就不显示引用条。
    private func quotePreviewInfo(for msg: Message) -> QuotePreview? {
        switch msg.kind {
        case .notification, .system:
            return nil
        default:
            break
        }

        let refLogId = msg.logId ?? 0

        // 已撤回的消息：原来 `getReplyDetail` 里这段是 FIXME 注释掉的，这里补上
        if case .notify = msg.msgType {
            return QuotePreview(name: "", content: L("该消息已撤回"), refLogId: refLogId)
        }

        // 图片/视频：正文留空，靠缩略图表达；文件：显示文件名 + 类型图标
        let content = self.quoteSummary(for: msg) ?? ""
        let media = self.quoteMedia(for: msg)
        guard !content.isBlank || media.exists else { return nil }
        return QuotePreview(
            name: self.quoteDisplayName(for: msg), content: content, refLogId: refLogId, media: media)
    }

    /// 引用条上的图片/视频缩略图、文件图标
    private func quoteMedia(for msg: Message) -> QuoteMedia {
        switch msg.kind {
        case .photo(let item):
            return .photo(cacheKey: item.mediaCachekey, url: item.url)
        case .video(let item):
            return .video(cacheKey: item.mediaCachekey)
        case .file(let item):
            let fileName = item.fileName ?? ""
            return .file(iconName: fileName.pathExtension.matchingFileType())
        default:
            return .none
        }
    }

    /// 引用条上的内容摘要（回复仅支持：文字、图片、视频、文件；其余类型顺带支持）
    private func quoteSummary(for msg: Message) -> String? {
        switch msg.kind {
        case .text(let text):
            return text
        case .attributedText(let text):
            return text.string
        case .photo, .video:
            // 图片 / 视频用缩略图表示，不再显示「[图片]」「[视频]」文字
            return ""
        case .audio(let item):
            return L("[语音]") + String(format: "%.0fs", item.duration ?? 0)
        case .file(let fileItem):
            // 文件直接显示文件名（图标另画），不再加「[文件]」前缀
            return fileItem.fileName ?? L("[文件]")

        case .transfer:
            return L("[转账]")
        case .redPacket:
            return L("[红包]")
        case .contactCard:
            return L("[名片]")
        case .forward:
            return L("[聊天记录]")
        default:
            return nil
        }
    }

    /// 引用条上显示的发送人。
    /// 顺序：群昵称 → 备注/昵称；**都没有就留空，不显示短地址**（用户 2026-11-04 要求）。
    private func quoteDisplayName(for msg: Message) -> String {
        // 1) 群聊：群昵称优先，自己和别人一视同仁
        if !self.session.isPrivateChat {
            if let member = GroupManager.shared().getDBGroupMember(
                with: self.session.id.idValue.intEncoded, memberId: msg.fromId)
            {
                if let memberName = member.memberName, !memberName.isBlank {
                    return memberName
                }
                if let nickname = member.user?.nickname, !nickname.isBlank {
                    return nickname
                }
            }
            // 自己的群昵称（群里自己发消息时，群里成员表可能还没带出自己那条）
            if msg.isOutgoing, let memberName = self.groupDetailInfo?.person?.memberName,
                !memberName.isBlank
            {
                return memberName
            }
        }

        // 2) 自己：昵称 > 备注（都是空就不显示）
        if msg.isOutgoing {
            if let nickname = LoginUser.shared().nickName?.value, !nickname.isBlank {
                return nickname
            }
            return ""
        }

        // 3) 对方：消息上带的用户 > 用户缓存里的备注/昵称
        if let nickname = msg.user?.nickname, !nickname.isBlank {
            return nickname
        }
        if let user = UserManager.shared().user(by: msg.fromId) {
            if let alias = user.alias, !alias.isBlank {
                return alias
            }
            if let nickname = user.nickname, !nickname.isBlank {
                return nickname
            }
        }

        // 4) 什么昵称都没有：留空（产品要求不显示短地址）
        return ""
    }

    // MARK: - 点引用条跳转

    /// 滚到被引用的原消息并闪一下；原消息不在当前列表里（还没加载到）时给个提示
    private func scrollToMessage(logId: Int) {
        guard let index = self.messageArray.firstIndex(where: { $0.logId == logId }) else {
            self.showToast(L("引用的消息不在当前列表"))
            return
        }

        let indexPath = IndexPath.init(item: 0, section: index)
        self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        // 滚完再闪：cell 可能刚上屏，cellForItem 拿不到就退化成不闪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            (self.collectionView.cellForItem(at: indexPath) as? MessageContentCell)?.flashHighlight()
        }
    }

    // MARK: - 翻译 / 语音转文字

    /// 文本消息是否显示「翻译」入口：系统支持、正文非空、且不是邀请 / 分享卡片这类 JSON 文本
    private func canTranslateTextMessage(_ msg: Message) -> Bool {
        guard MessageTranslationService.isAvailable else { return false }
        guard case .text(let text) = msg.kind, !text.isBlank else { return false }
        if VoiceRoomInvite.link(in: text) != nil { return false }
        if FZM_EnableShareLinkCard, ShareLinkCard.parse(text) != nil { return false }
        return true
    }

    /// 长按「翻译」：调起系统翻译面板；用户点「替换」后把译文存本地并刷新这一条
    private func translateTextMessage(_ msg: Message) {
        guard case .text(let text) = msg.kind, !text.isBlank else { return }
        let presented = MessageTranslationService.present(from: self, text: text) { [weak self] translated in
            guard let self = self else { return }
            self.applyTranslation(translated, toMessageId: msg.msgId)
        }
        if !presented {
            self.showToast(L("当前系统版本不支持消息翻译"))
        }
    }

    private func applyTranslation(_ translated: String, toMessageId msgId: String) {
        let value = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard let index = self.messageArray.firstIndex(where: { $0.msgId == msgId }) else { return }
        guard self.messageArray[index].translation != value else { return }

        self.messageArray[index].translation = value
        self.messageArray[index].translationLang = LanguageManager.shared.currentLanguageCode
        ChatManager.shared().updateTranslation(
            mes: msgId, text: value, lang: LanguageManager.shared.currentLanguageCode)
        self.reloadSectionSafely(index)
    }

    /// 取消翻译：把译文从内存和本地库里清掉，气泡下方的译文卡片随之收起
    private func cancelTranslation(forMessageId msgId: String) {
        guard let index = self.messageArray.firstIndex(where: { $0.msgId == msgId }) else { return }
        guard self.messageArray[index].translation?.isBlank == false else { return }

        self.messageArray[index].translation = nil
        self.messageArray[index].translationLang = nil
        ChatManager.shared().clearTranslation(mes: msgId)
        self.reloadSectionSafely(index)
    }

    /// 长按「转文字」：离线识别本地 wav，成功后把文本存本地并刷新这一条
    private func transcribeVoiceMessage(_ msg: Message) {
        guard case .audio = msg.kind else { return }
        let path = FZMMessageBaseVM.getFilePath(with: msg)
        guard FZMLocalFileClient.shared().isFileExists(atPath: path) else {
            self.showToast(L("语音还没下载，请先播放一次"))
            return
        }
        VoiceTranscriptionService.shared.transcribe(
            audioURL: URL(fileURLWithPath: path),
            languageCode: LanguageManager.shared.currentLanguageCode
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let text):
                self.applyTranscript(text, toMessageId: msg.msgId)
            case .failure(let error):
                self.showToast(error.localizedDescription)
            }
        }
    }

    private func applyTranscript(_ text: String, toMessageId msgId: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard let index = self.messageArray.firstIndex(where: { $0.msgId == msgId }) else { return }
        guard self.messageArray[index].transcript != value else { return }

        self.messageArray[index].transcript = value
        ChatManager.shared().updateTranscript(mes: msgId, text: value)
        self.reloadSectionSafely(index)
    }
}
