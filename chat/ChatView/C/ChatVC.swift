//
//  ChatVC.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//  lottie动画

import UIKit
import SnapKit
import MJRefresh
import Photos
import PhotosUI
import MobileCoreServices
import Kingfisher
import Dispatch
import Lantern
import Alamofire
import AVKit
import AVFoundation
import CryptoKit
import SwifterSwift
import TSVoiceConverter
import MediaPlayer
import AliyunOSSiOS
import RxSwift

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
    
    private var referenceMsg: Message?// 引用消息数据
    private var curTapMsg: Message?// 当前点击的message
    private var saveToAlUrl: String = ""// 保存视频用
    private var videoOrFile : Int = 1// 区分下载的是视频还是文件  视频==1   文件==2  语音==3
    var documentInteractionController: UIDocumentInteractionController!// 浏览文件用
    
    private var audioPlayer: AVAudioPlayer?
    
    // 下载按钮（保存图片、视频用）
    private lazy var downloadBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "icon_download"), for: .normal)
        btn.backgroundColor = .black
        btn.layer.cornerRadius = 4
        btn.layer.masksToBounds = true
        btn.enlargeClickEdge(10, 10, 10, 10)
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            guard let self = self else { return }
            self.saveBtnClick()
        }).disposed(by: self.bag)
        return btn
    }()
    
    private let bag = DisposeBag.init()
    
    //是否显示多选
    private var showSelect = false {
        didSet{
//            self.forwardBar.isHidden = !showSelect
//            self.navigationItem.leftBarButtonItem = showSelect ? UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelSelect)) : UIBarButtonItem(customView: leftBarItemView)
            if showSelect {
                self.showRightBarButtonItem(false)
//                self.inputBar.showState(.normal)
            }else {
//                self.vmList.values.forEach { (vm) in
//                    vm.selected = false
//                }
//                self.selectMsgVMArr.removeAll()
//                if conversation.type == .group {
//                    IMConversationManager.shared().getGroup(with: conversation.conversationId) { (model) in
//                        if model.memberLevel == .none {
//                            self.navigationItem.rightBarButtonItems = nil
//                        }else {
//                            self.navigationItem.rightBarButtonItems = self.rightBarItemViews
//                        }
//                    }
//                }else {
                self.showRightBarButtonItem(true)
//                }
//                self.inputBar.showState(.detail)
            }
            self.reloadList()
        }
    }
    
    private var session: Session
    
    private lazy var messageArray = [Message]()// 消息数据
    
    private lazy var bottomUnReadMessageArray = [Message]()// 进入页面后新收未读消息数据
    
    private let operationQueue = OperationQueue()
    
    private var isHiddenStatusBar:Bool = false
    
    private var icloudFileBlock : IcloudFileBlock?//文件block
    
    private var chatServerUrl: String?// 当前聊天的服务器地址
    
    private var statusType: SocketConnectStatus = .unConnected
    {
        didSet {
            self.refreshServerStatus()
        }
    }
    
    private var userInfo: User?// 私聊用户信息
    
    private var staffInfo: StaffInfo?// 私聊用户的员工信息以及企业信息
    
    private var isGetStaffInfoReuqestSuccess = false// 获取员工信息请求成功flg
    
    private var isGettingStaffInfoRequest = false// 获取员工信息请求进行中flg 防止重复请求
    
    private var isGetTeamInfoReuqestSuccess = false// 获取企业信息请求成功flg
    
    // 群聊的群信息
    private var groupDetailInfo: Group? {
        didSet {
            self.inputBarView.group = groupDetailInfo
        }
    }
    
    //列表刷新锁
    private let refreshListLock = NSLock()
    
    private var locationMsg: (String, String)?// .0 msgId, 搜索关键字 暂时不需要对搜索的文字jx进行高亮, self.locationMsg?.1 不使用
    private var coinName:String?
    private var txHash:String?
    
    private lazy var leftView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
        return v
    }()
    
    private lazy var leftBarItemView: UIBarButtonItem = {
        let leftButton = UIButton.init(type: .custom)
        leftButton.frame = CGRect.init(x: 0, y: 0, width: 45, height: 44)
        leftButton.setImage(#imageLiteral(resourceName: "nav_back").withRenderingMode(.alwaysTemplate), for: .normal)
        leftButton.contentHorizontalAlignment = .left
        leftButton.contentVerticalAlignment = .center
        leftButton.tintColor = Color_24374E
        leftButton.addTarget(self, action: #selector(clickBack), for: .touchUpInside)
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
        v.addSubview(leftButton)
        self.leftView = v
        let leftBarItem = UIBarButtonItem.init(customView: v)
        return leftBarItem
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
        moreButton.setImage(#imageLiteral(resourceName: "icon_more").withRenderingMode(.alwaysTemplate), for: .normal)
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
        let v = WJHNavView.init(frame: CGRect.init(x: 0, y: 0, width: 200, height: 44), isPrivateChat: self.session.isPrivateChat)
        return v
    }()
    
    private var topUnreadCount:Int
    private lazy var topUnreadBtn: UIButton = {
        let btn = FZMUnreadCountButton.init(with: #imageLiteral(resourceName: "top_arrow"), frame: CGRect(x: k_ScreenWidth, y: 15, width: 125, height: 40))
        btn.setTitle("\(topUnreadCount)条新消息", for: .normal)
        let maskPath = UIBezierPath.init(roundedRect: btn.bounds, byRoundingCorners: [UIRectCorner.topLeft,UIRectCorner.bottomLeft], cornerRadii: CGSize.init(width: btn.bounds.height * 0.5, height: btn.bounds.height * 0.5))
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath.cgPath
        btn.layer.mask = maskLayer
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.topUnreadBtnPress()
        }).disposed(by: self.bag)
        return btn
        
    }()
    
    private lazy var bottomUnreadBtn: UIButton = {
        let btn = FZMUnreadCountButton.init(with: #imageLiteral(resourceName: "down_arrow"), frame:CGRect(x: (k_ScreenWidth - 130) * 0.5 , y: k_ScreenHeight, width: 130, height: 40))
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true;
        btn.alpha = 0;
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.bottomUnreadBtnPress()
        }).disposed(by: self.bag)
        return btn
        
    }()
    
    private var bottomUnreadCount = 0 {
        didSet {
            if bottomUnreadCount == 0 {
                bottomUnreadBtn.alpha = 0
            } else {
                bottomUnreadBtn.setTitle("\(bottomUnreadCount)条新消息", for: .normal)
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
    
    init(session:Session,coinName:String?,txHash:String?){
        self.session = session
        FZMLog("session---\(self.session)")
        self.coinName = coinName
        self.txHash = txHash
        topUnreadCount = locationMsg == nil ? session.unreadCount : 0
        super.init(nibName: nil, bundle: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
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
        
        // 更新会话名称
        self.refreshSessionName()
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor = Color_F6F7F8
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        VoiceMessagePlayerManager.shared().stopVoice()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 显示右上角 ***新未读消息 按钮
        if topUnreadCount > 0 && self.collectionView.visibleCells.count < topUnreadCount {
            self.showTopUnreadBtn()
        }
        
//        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)), name: Notification.Name("TransferNotification"), object: nil)
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
        if show {
            self.navigationItem.rightBarButtonItem = self.rightBarItemView
            
//            let spaceItem = UIBarButtonItem.init(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
//            spaceItem.width = 1
//
//            self.navigationItem.rightBarButtonItems = [spaceItem, self.rightBarItemView]
//            self.navigationController?.navigationBar.insertSubview(self.rightView, aboveSubview: self.navTitleView)
        } else {
            self.navigationItem.rightBarButtonItem = nil
//            self.navigationItem.rightBarButtonItems = nil
        }
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
            moreBarView.hideRed()
            if let user = UserManager.shared().user(by: self.session.id.idValue) {
                self.userInfo = user
                
                self.showRightBarButtonItem(true)
            }
        } else {
            moreBarView.hideTrans()
            if let group = GroupManager.shared().getDBGroup(by: self.session.id.idValue.intEncoded) {
                self.groupDetailInfo = group
                
                //根据是否在群判断显示右侧群详情入口
                self.showRightBarButtonItem(group.isInGroup)
            }else{
                //没有这个群
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
        
        if session.isPrivateChat {// 私聊地址
            
            if let info = TeamManager.shared().getDBStaffInfo(address: self.session.id.idValue), let teamInfo = TeamManager.shared().getDBTeamInfo(entId: info.entId) {
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
                            chatServerUrl = chatServer.value// 已获取到聊天地址，退出当前遍历
                            return
                        }
                    }
                    if let _ = chatServerUrl {// 已获取到聊天地址，退出当前遍历
                        return
                    }
                }
                
                if chatServerUrl.isBlank, let url = userInfo?.chatServers.first {
                    chatServerUrl = url
                }
            }
        } else {// 群聊地址
            chatServerUrl = session.chatServerUrl
            if chatServerUrl?.isBlank != false {
                let group = GroupManager.shared().getDBGroup(by: session.id.idValue.intEncoded)
                if let serverUrl = group?.chatServerUrl {
                    
                    chatServerUrl = serverUrl
                    session.chatServerUrl = serverUrl
                }else{
                    self.addServerView.isHidden = false
                }
            }
            statusType = MultipleSocketManager.shared().getSingleSocketConnectStatus(chatServerUrl ?? "")
        }
        FZMLog("聊天服务器地址： chatServerUrl -- \(chatServerUrl ?? "没获取到")")
    }
    
    //刷新群组时的禁言信息
    private func refreshBannedInfo() {
        //先判断全员禁言
        if let type = self.groupDetailInfo?.muteType,type == 1,let memberType = self.groupDetailInfo?.person?.memberType,memberType == 0 {
            //全员禁言 禁言普通群员
            self.inputBarView.bannedAction(with: 0, type: 1)
        } else {
            
            let time = self.groupDetailInfo?.person?.memberMuteTime
            if time! > Date.timestamp{
                let distance = (time! - Date.timestamp)
                self.inputBarView.bannedAction(with: Double(distance)/1000, type: 0)
            }else{
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
        
        if self.session.isPrivateChat {// 私聊
            if let user = UserManager.shared().user(by: self.session.id.idValue) {
                self.userInfo = user
                isMuteNotifi = user.isMuteNotification
            }
        } else {
            // 群聊
            if let group = GroupManager.shared().getDBGroup(by: self.session.id.idValue.intEncoded) {
                self.groupDetailInfo = group
                
                // 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
                switch group.groupType {
                case 1:
                    typeStr = "全员"
                case 2:
                    typeStr = "部门"
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
        MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
            guard let strongSelf = self, case .next((let url, let isAvailable)) = event, let info = strongSelf.groupDetailInfo, let serverUrl = info.chatServerUrl, serverUrl == url.absoluteString else { return }
            
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
            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: self.session.id.idValue, source: .normal))
        } else {
            guard let _ = chatServerUrl else {
                self.showToast("请先添加本群的聊天服务器")
                return
            }
//            FZMUIMediator.shared().pushVC(.goGroupDetail(groupId: self.session.id.idValue.intEncoded))
            
           let vc = FZMGroupDetailInfoVC(with: self.session.id.idValue.intEncoded)
            vc.hidesBottomBarWhenPushed = true
            vc.sendvcBlock = {[] (note) in
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
        
        self.collectionView.mj_header = MJRefreshNormalHeader.init(refreshingBlock: {[weak self] in
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
    }
    
    // 从数据库获取消息数据
    private func getHistoryMsgs(locationMsgId: String = "", count: Int = 20) -> [Message] {
        let msgId = locationMsgId.isBlank ? (self.messageArray.first?.msgId ?? "") : locationMsgId
        let msgInDB = ChatManager.shared().getHistoryMsgs(session: self.session, from: msgId, count: count, includeCurMsgFlg: !locationMsgId.isBlank)
        let newMsgs = self.getMsgsUsers(msgs: msgInDB)
        return newMsgs.reversed()
    }
    
    // 加载本地消息
    // 如果是搜索聊天记录跳转，则加载那条数据之后的所有消息数据？？？
    private func loadMsgs() {
        DispatchQueue.global().async {
            var msgId = ""
            var count = 20
            if (self.locationMsg != nil) {
                msgId = self.locationMsg!.0
                count = .max
            }
            let newMsgInDB = self.getHistoryMsgs(locationMsgId: msgId, count: count)
            DispatchQueue.main.async {
                self.refreshListLock.lock()
                if newMsgInDB.count > 0 {
                    self.messageArray = newMsgInDB + self.messageArray
                }
                self.collectionView.reloadData()
                if self.locationMsg != nil {
                    self.collectionView.scrollToFirstItem(pos: .top, animated: false)
                } else {
                    self.collectionView.scrollToLastItem(at: .bottom, animated: false)
                }
                self.refreshListLock.unlock()
            }
        }
    }
    
    // 加载更多本地历史消息
    private func loadMoreMsg(count: Int = 20) {
        DispatchQueue.global().async {
            let newMsgInDB = self.getHistoryMsgs(count: count)
            DispatchQueue.main.async {
                self.refreshListLock.lock()
                if newMsgInDB.count > 0 {
                    self.messageArray = newMsgInDB + self.messageArray
                }
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
                    GroupManager.shared().getMember(by: self.session.id.idValue.intEncoded, memberId: msg.fromId, serverUrl: serverUrl) { (member) in
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
        APP.shared().hasNetworkSubject.subscribe(onNext: {[weak self] (hasNetwork) in
            guard let strongSelf = self else { return }
            FZMLog("networkListener 收到网络变化 hasNetwork -- \(hasNetwork)")
            if hasNetwork && strongSelf.session.id.isPersonChat {
                guard let url = strongSelf.chatServerUrl, !url.isBlank else {// 如果聊天服务器地址为空则重新获取
                    // 获取用户员工信息以及企业信息以获取对方的聊天服务器
                    strongSelf.getStaffInfoRequest()
                    return
                }
            }
        }).disposed(by: bag)
        
        // 发送消息订阅 消息发送结果
        MultipleSocketManager.shared().sendMsgStatusSubject.subscribe(onNext: {[unowned self] (sendMsgStatus) in
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
        MultipleSocketManager.shared().receiveMsgsSubject.subscribe(onNext: {[weak self] (msgs) in
            guard let self = self else { return }
            
            // 黑名单用户过滤
            let myMsgs = msgs.compactMap { (msg) -> Message? in
                if msg.fromId != LoginUser.shared().address {
                    if self.userInfo?.isShield == true {
                        return nil
                    }
                }
                return msg
            }.filter { $0.sessionId == self.session.id && !self.messageArray.contains($0) }
            
            guard myMsgs.count > 0 else { return }
            
            let newMsgs = self.getMsgsUsers(msgs: myMsgs)
            
            self.insertAndSendMessages(newMsgs)
            
        }).disposed(by: self.bag)
        
        
        // 接收用户/群免打扰和昵称等详情信息变化通知
        FZM_NotificationCenter.addObserver(self, selector: #selector(refreshSessionInfo), name: FZM_Notify_SessionInfoChanged, object: nil)
        
        // 接收聊天文件页面删除文件通知
        FZM_NotificationCenter.addObserver(self, selector: #selector(handleDeleteChatMsgs), name: FZM_Notify_DeleteChatMsgs, object: nil)
        
        if !self.session.isPrivateChat {
            // 群信息更新通知
            FZM_NotificationCenter.addObserver(self, selector: #selector(refreshGroupDetailInfo), name: FZM_Notify_GroupDetailInfoChanged, object: nil)
            
            // 退出群聊通知（删群）
            FZM_NotificationCenter.addObserver(self, selector: #selector(deleteGroup), name: FZM_Notify_GroupDelete, object: nil)
            
            // 退出群聊通知（被踢出群）
            FZM_NotificationCenter.addObserver(self, selector: #selector(signoutGroup), name: FZM_Notify_GroupSignout, object: nil)
            
            // 加入群聊通知（被拉进群）
            FZM_NotificationCenter.addObserver(self, selector: #selector(signinGroup), name: FZM_Notify_GroupSignin, object: nil)
            
            // 用户信息更新通知
            FZM_NotificationCenter.addObserver(self, selector: #selector(refreshUserInfoNoti), name: FZM_Notify_RefreshUserInfo, object: nil)
        }
    }
    
    // 加入群聊通知更新UI（被拉进群）
    @objc private func signinGroup(notification: NSNotification) {
        // 判断有更新的是否是当前群
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat, groupId == self.session.id.idValue.intEncoded else {
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
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat, groupId == self.session.id.idValue.intEncoded else {
            return
        }
        
        // 退出群聊更新UI
        self.handleQuitGroupAction()
    }
    
    // 已退出群聊通知处理
    @objc private func deleteGroup(notification: NSNotification) {
        // 判断有更新的是否是当前群
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat, groupId == self.session.id.idValue.intEncoded else {
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
    
    // 聊天文件删除文件处理
    @objc func handleDeleteChatMsgs(notification: NSNotification) {
        guard let (sessionId, msgs) = notification.object as? (SessionID, [Message]), sessionId == self.session.id else {
            return
        }
        
        self.deleteMessages(msgs, needDeleteDB: false)
    }
    
    // 更新会话名称和免打扰状态
    @objc private func refreshSessionInfo(notification: NSNotification) {
        guard let address = notification.object as? String, address == self.session.id.idValue else {
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
            if bottomUnReadMessageArray.count > 0 {
                for i in 0..<bottomUnReadMessageArray.count {
                    if bottomUnReadMessageArray[i].fromId == address {
                        bottomUnReadMessageArray[i].user = user
                    }
                }
            }
            if messageArray.count > 0 {
                var indexArr = [Int]()
                for i in 0..<messageArray.count {
                    if messageArray[i].fromId == address {
                        messageArray[i].user = user
                        indexArr.append(i)
                    }
                }
                
                if indexArr.count > 0 {
                    DispatchQueue.main.async {
                        for item in indexArr {
                            UIView.performWithoutAnimation {
                                self.collectionView.reloadSections(IndexSet([item]))
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// 群信息更新通知处理
    ///  --- 加群 退群 更新加群权限 更新群加好友权限 更新群禁言 更新群成员（管理权限变化） 更新禁言列表 更新群名 更新群头像
    @objc private func refreshGroupDetailInfo(notification: NSNotification) {
        // 判断有更新的是否是当前群聊
        guard let groupId = notification.object as? Int, !self.session.isPrivateChat, groupId == self.session.id.idValue.intEncoded else {
            return
        }
        
        DispatchQueue.main.async {
            if let group = GroupManager.shared().getDBGroup(by: self.session.id.idValue.intEncoded) {
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
        guard self.messageArray.count > 0 else { return }
        
        for i in 0..<self.messageArray.count {
            switch status {
            case .sent:// 已发送 更新status以及logId
                if !msgId.isBlank, self.messageArray[i].msgId == msgId {
                    self.messageArray[i].status = status
                    self.messageArray[i].logId = logId
                    
                    DispatchQueue.main.async {
                        self.collectionView.reloadSections(IndexSet([i]))
                    }
                    
                    break
                }
            case .failed:// 发送失败 更新status
                if !msgId.isBlank, self.messageArray[i].msgId == msgId {//msgId不为空
                    self.messageArray[i].status = status
                    
                    DispatchQueue.main.async {
                        self.collectionView.reloadSections(IndexSet([i]))
                    }
                    
                    break
                }
            case .delivered:
                if logId > 0, self.messageArray[i].logId == logId {//logId不为空
                    self.messageArray[i].status = status
                    
                    DispatchQueue.main.async {
                        self.collectionView.reloadSections(IndexSet([i]))
                    }
                    
                    break
                }
            default:
                break
            }
        }
    }
    
    // 插入到消息数据源并更新页面
    func insertAndSendMessages(_ messages: [Message], needSendMsg: Bool = false) {
        guard messages.count > 0 else { return }
        
        var messages = messages
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
                    } else if let dbMember = GroupManager.shared().getDBGroupMember(with: self.session.id.idValue.intEncoded, memberId: msg.fromId) {
                        member = dbMember
                    } else {
                        member = GroupMember.init(memberId: LoginUser.shared().address, memberMuteTime: 0, memberName: LoginUser.shared().nickName?.value ?? LoginUser.shared().address.shortAddress, memberType: 0, groupId: self.session.id.idValue.intEncoded)
                    }
                } else {
                    if let dbMember = GroupManager.shared().getDBGroupMember(with: self.session.id.idValue.intEncoded, memberId: msg.fromId) {
                        member = dbMember
                    } else {
                        member = GroupMember.init(memberId: msg.fromId, memberMuteTime: 0, memberName: msg.fromId.shortAddress, memberType: 0, groupId: self.session.id.idValue.intEncoded)
                    }
                }
                
                return member
            }
            
            for i in 0..<messages.count {
                messages[i].member = getMemberInfo(messages[i])
            }
        }
        
        DispatchQueue.main.async {
            let newMsgs = ChatManager.shared().handleMsgsWithShowTimeFlg(msgs: messages)
            let startSection = self.messageArray.count
            let sections = IndexSet(startSection..<startSection + newMsgs.count)
            
            self.refreshListLock.lock()
            
            if !self.isLastSectionVisible() && self.messageArray.count > 0 && !needSendMsg {// 如果最新一条消息不在可见区域，底部显示 ***条新消息
                newMsgs.forEach { msg in
                    switch msg.msgType {
                    case .system, .text, .audio, .image, .video, .file, .forward, .RTCCall, .transfer, .collect, .redPacket, .contactCard, .unknown:
                        self.bottomUnreadCount += 1
                    default: break
                    }
                }
                
                self.bottomUnReadMessageArray += newMsgs
                self.showBottomUnreadBtn()
            } else {
                
                self.messageArray += newMsgs
                self.collectionView.performBatchUpdates({
                    self.collectionView.insertSections(sections)
                }, completion: { [weak self] _ in
                    guard let self = self else { return }
                    if needSendMsg || self.isLastSectionVisible() {
                        self.collectionView.scrollToLastItem(animated: true)
                    }
                })
            }
            
            self.refreshListLock.unlock()
            
            // 数据处理完再发消息，否则消息发送回执完成处理数据时发送的消息数据可能还未插入到消息数据源
            if needSendMsg, let msg = messages.first {
                let serverUrl = self.chatServerUrl ?? ""
                if serverUrl.isBlank && self.session.id.isPersonChat {
                    // 获取用户员工信息以及企业信息以获取对方的聊天服务器
                    self.getStaffInfoRequest()
                }
                ChatManager.shared().send(msg: msg, chatServerUrl: serverUrl)
            }
        }
    }
    
    // 最新消息是否可见
    private func isLastSectionVisible() -> Bool {
        guard !self.messageArray.isEmpty else { return false }
        let lastIndexPath = IndexPath(item: 0, section: self.messageArray.count - 1)
        return self.collectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }
    
    // 删除消息数据并更新页面
    func deleteMessages(_ messages: [Message], needDeleteDB: Bool? = true) {
        guard !messages.isEmpty, !self.messageArray.isEmpty else { return }
        
        DispatchQueue.main.async {
            var indexs = [Int]()
            self.refreshListLock.lock()
            
            // 删除数据库消息数据并更新会话列表
            if needDeleteDB ?? true {
                ChatManager.shared().delete(messsages: messages)
            }
            
            for i in 0..<messages.count {
                let msg = messages[i]
                
                switch msg.msgType {
                case .image:
                    // 清除图片缓存
                        let fileName = "\(msg.msgType.cachekey ?? "")"
                        ImageCache.default.removeImage(forKey: fileName)
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
                
                // 更新消息数据源
                if self.messageArray.contains(msg) {
                    guard let index = self.messageArray.firstIndex(where: {$0 == msg}) else { return }
                    
                    self.messageArray.remove(at: index)
                    indexs.append(index)
                }
            }
            let sections = IndexSet(indexs)
            
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteSections(sections)
            }, completion: { [weak self] _ in
                guard let self = self, self.isLastSectionVisible() else { return }
                self.collectionView.scrollToLastItem(animated: true)
            })
            self.refreshListLock.unlock()
        }
    }
}

//MARK: - 网络请求
extension ChatVC {
    // 获取用户员工信息
    private func getStaffInfoRequest() {
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
        guard let staffInfo = staffInfo else {
            return
        }
        guard !isGetTeamInfoReuqestSuccess else {
            // 获取当前发送消息的聊天服务器地址
            self.setChatServerUrl()
            return
        }
        TeamManager.shared().getEnterPriseInfo(entId: staffInfo.entId, successBlock: { [weak self] (teamInfo) in
            guard let strongSelf = self else { return }
            strongSelf.isGetTeamInfoReuqestSuccess = true
            strongSelf.staffInfo?.company = teamInfo
            
            // 获取当前发送消息的聊天服务器地址
            strongSelf.setChatServerUrl()
            
        }, failureBlock: { (error) in
//            guard let strongSelf = self else { return }
//            strongSelf.showToast("获取企业信息失败")
        })
    }
    
    // 获取用户详情请求
    private func refreshUserInfoRequestInChatVC() {
        UserManager.shared().getNetUser(targetAddress: self.session.id.idValue) { [weak self] (user) in
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
        guard let group = self.groupDetailInfo, let serverUrl = chatServerUrl else { return }
        GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: group.id) { [weak self] (group) in
            guard let strongSelf = self else { return }
            strongSelf.groupDetailInfo = group
            //刷新禁言信息
            strongSelf.refreshBannedInfo()
            
            // 更新会话名称
            strongSelf.refreshSessionName()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            
            //隐藏inputbar
            strongSelf.view.endEditing(true)
            strongSelf.inputBarView.isHidden = true
            strongSelf.showRightBarButtonItem(false)
            FZMLog("refreshGroupInfoRequestInChatVC error : \(error)")
            
            let error = error as NSError
            strongSelf.showToast(error.localizedDescription)
        }
    }
    
    // 获取群成员列表请求
    private func getGroupMemberListRequest() {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        GroupManager.shared().getGroupMemberList(serverUrl: serverUrl, groupId: info.id) { [weak self] (members) in
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
    func loadAllUnreadMessage(compeletionBlock:@escaping NormalBlock) {
        if self.messageArray.count >= self.topUnreadCount {
            compeletionBlock()
        } else {// 未读消息超过当前消息数据（进页面一次取20条）则获取所有未读消息
            let count = self.topUnreadCount - self.messageArray.count + 1
            
            let newMsgInDB = self.getHistoryMsgs(count: count)
            if newMsgInDB.count > 0 {
                self.messageArray = newMsgInDB + self.messageArray
            }
            
            self.reloadList(completionBlock: {
                compeletionBlock()
            })
        }
    }
    
    // 刷新列表
    func reloadList(completionBlock:NormalBlock? = nil) {
        DispatchQueue.main.async {
            self.refreshListLock.lock()
            self.collectionView.reloadData()
            self.refreshListLock.unlock()
            completionBlock?()
        }
    }
    
    // 顶部未读消息视图点击事件
    func topUnreadBtnPress() {
        self.loadAllUnreadMessage() {[weak self] in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                strongSelf.refreshListLock.lock()
                
                if strongSelf.topUnreadCount > 0, strongSelf.topUnreadCount <= strongSelf.messageArray.count {
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
        UIView.animate(withDuration: 0.3) {
            self.topUnreadBtn.frame = CGRect.init(x: k_ScreenWidth - self.topUnreadBtn.bounds.width, y: self.topUnreadBtn.frame.origin.y, width: self.topUnreadBtn.width, height: self.topUnreadBtn.height)
        }
    }
    
    // 隐藏顶部未读消息视图
    func hideTopUnreadBtn() {
        self.topUnreadCount = 0
        guard self.topUnreadBtn.frame.origin.x != k_ScreenWidth else {
            return
        }
        UIView.animate(withDuration: 0.3, animations: {
            self.topUnreadBtn.frame = CGRect.init(x: k_ScreenWidth, y: self.topUnreadBtn.frame.origin.y, width: self.topUnreadBtn.width, height: self.topUnreadBtn.height)
        }) { (_) in
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
        guard self.bottomUnreadBtn.frame.origin.y == k_ScreenHeight, self.bottomUnreadCount != 0 else {
            return
        }
        UIView.animate(withDuration: 0.4) {
            self.bottomUnreadBtn.alpha = 1
            self.bottomUnreadBtn.frame = CGRect.init(x: self.bottomUnreadBtn.frame.origin.x, y:self.inputBarView.frame.origin.y - self.bottomUnreadBtn.height - 15 , width: self.bottomUnreadBtn.width, height: self.bottomUnreadBtn.height)
        }
    }
    
    // 隐藏底部未读消息视图
    func hideBottomUnreadBtn() {
        if (self.bottomUnreadBtn.frame.origin.y == k_ScreenHeight) && (self.bottomUnReadMessageArray.count == 0) {
            return
        }
        if self.bottomUnReadMessageArray.count > 0 {
            self.refreshListLock.lock()
            self.messageArray += self.bottomUnReadMessageArray
            self.bottomUnReadMessageArray.removeAll()
            self.refreshListLock.unlock()
        }
        self.reloadList {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.refreshListLock.lock()
            strongSelf.collectionView.scrollToLastItem()
            strongSelf.refreshListLock.unlock()
            UIView.animate(withDuration: 0.4, animations: {
                strongSelf.bottomUnreadBtn.alpha = 0
                strongSelf.bottomUnreadBtn.frame = CGRect.init(x: strongSelf.bottomUnreadBtn.frame.origin.x, y: k_ScreenHeight, width: strongSelf.bottomUnreadBtn.width, height: strongSelf.bottomUnreadBtn.height)
            }, completion: { (_) in
                strongSelf.bottomUnreadCount = 0
            })
        }
    }
}

//MARK: - InputBarViewDelegate
extension ChatVC: InputBarViewDelegate  {
    
     func inputBarView(_ inputBarView: InputBarView, sendText text: String, mentionIds: [String]) {
//         self.sendTextNotifityMsg(text: text)
         self.sendTextMsg(text: text, mentionIds: mentionIds)
    }
    
    func audioBarView(_ inputBarView: InputBarView, amrPath: String, wavPath: String, duration: Double) {
        self.sendAudioMsg(amrPath: amrPath, wavPath: wavPath, duration: duration)
    }
    
    // 删除引用
    func inputBarViewDeleteReference() {
        self.referenceMsg = nil
    }
}

extension ChatVC: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
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
                        self.showToast("语音播放失败")
                        FZMLog("---语音播放失败，self.curTapMsg 为空---")
                    }
                }
                
            } else {
                self.showToast("下载文件保存到本地沙盒失败")
                FZMLog("下载文件保存到本地沙盒失败 fileName \(fileName)")
            }
        }
    }
    
    // 从下载的视频文件中获取视频封面
    func getVideoCoverImage(cell: MediaMessageCell?, url: URL, fileName: String) {
        // 获取视频第一帧作为封面
        UIImage.getVideoCropPicture(url) { (image) in
            guard let image = image else {
                self.showToast("视频封面获取失败")
                FZMLog("视频封面获取出错")
                return
            }
            // 缓存封面图片
            ImageCache.default.store(image, forKey: fileName)
            
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
//                ImageCache.default.store(image, forKey: fileName)
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
    func sendRedBag() {
        
//        guard let info = GroupManager.shared().getDBGroup(by: groupId) else { return }
//        self.groupDetailInfo = info
//        FZMUIMediator.shared().pushVC(.goGroupDetail(groupId: self.session.id.idValue.intEncoded))
        
        
        guard let info = self.groupDetailInfo else { return }
        let infovc = FZMGroupMemberListVC(with: info, fromTag: 1)
        infovc.sendBlock = { [] (note) in
            let addr = LoginUser.shared().address
            infovc.navigationController?.popViewController()
            self.sendContactCard(contactId: addr, name: note, avatar: note, type: -1)
        }
        self.navigationController?.pushViewController(infovc, animated: true)
        
        
        return
        
  
//        let vc = ChoiceContactCardVC()
//        vc.contactCardType = 3
//        vc.groupId = self.groupDetailInfo!.id
//        vc.seletedBlock = { [weak self] contact in
////            self?.sendContactCard(contactId: contact.user!.address, name: "", avatar: contact.user!.aliasName, type: 1)
//            
//            let vc =  TransferViewController.init()
//            let avatarUrl = contact.groupMember!.avatarURLStr
//            let address = contact.groupMember!.memberId
//            let memberName = contact.groupMember?.memberName
//            let selfaddr = LoginUser.shared().address
//            if selfaddr == address{
//                self!.showToast("不能给自己发专属红包")
//                return
//            }
//            let coinArray = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID()
//            let coin = coinArray?.first as! LocalCoin
//           
//            var toAddr = ""
//            User.getUser(targetAddress: contact.groupMember!.memberId, count: 100, index: "", successBlock: {[weak self] (json) in
//                guard let strongSelf = self else { return }
//                let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
//                
//                for field in fields {
//                    if case .ETH = field.name {
//                        toAddr = field.value
//                    }
//                }
//                if toAddr.count == 0{
//                    strongSelf.showToast("未获取到对方地址")
//                    return
//                }
//                vc.contactDict = ["avatarUrl":avatarUrl as NSString,"address":memberName! as NSString,"toAddr":toAddr as NSString]
//                
//                vc.coin = coin
//                //获取当前时间
//                let currentDate = Date()
//                
//                // 创建一个DateFormatter实例
//                let dateFormatter = DateFormatter()
//                
//                // 设置日期格式
//                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // 例如：2023-04-01 12:34:56
//                
//                // 将当前时间转换为字符串
//                let dateString = dateFormatter.string(from: currentDate)
//                
//                vc.transferBlock =  { [] (coinName,txHash,amount) in
//                    let addr = LoginUser.shared().address
//                    let toAdddr = contact.name.count == 0 ? contact.groupMember?.memberId:contact.name
//                 // 接收者地址或昵称 币种+数量 时间
//                    
////                    let detail = toAdddr! + "," + amount + " " + coinName + "," + dateString
//                    let detail = "\(toAdddr!),\(amount!) \(coinName!),\(dateString)"
//                    self?.sendContactCard(contactId: addr, name: detail, avatar: detail, type: -1)
//                    
//                }
//                strongSelf.navigationController?.pushViewController(vc, animated: true)
//                // 未设置过IM服务器 连接默认IM服务器 并上传保存到服务端
//               
//            }, failureBlock: nil)
//            
//        }
//        self.navigationController?.present(vc, animated: true)
    }
    
    // 点击发图片/视频
    func sendPhoto() {
        FZMLog("点击发图片/视频")
        operationQueue.maxConcurrentOperationCount = 1
        let picker = ImagePickerController.init(withSelectOne: false, maxSelectCount: 9, allowEditing: false, showVideo: true)
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
        
        picker.didFinishPickingPhotosHandle = {[weak self] (photos, assets, isSelectOriginalPhoto) in
            guard let strongSelf = self, let images = photos, let assets = assets as? [PHAsset] else { return }
            if images.count == assets.count {
                for i in 0..<assets.count {
                    let asset = assets[i]
                    if asset.mediaType == .video {
                        PHCachingImageManager().requestAVAsset(forVideo: asset, options: nil, resultHandler: {(assetAV, audioMix, info) -> Void in
                            if let assetAV = assetAV, let avasset = assetAV as? AVURLAsset {
                                strongSelf.sendVideoMsg(cropPicture: images[i], asset: asset, localPath: avasset.url)
                            }
                        })
                    } else {
//                        self.sendImageMsg(image: images[i])
                        let requestOption = PHImageRequestOptions()
                        requestOption.version = .unadjusted
                        requestOption.isSynchronous = false
                        PHImageManager.default().requestImageData(for:asset, options:requestOption, resultHandler: { (data,uti,orientation,info)in
                            if let UTI = uti,UTTypeConformsTo(UTI as CFString,kUTTypeGIF) {
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
        let documentTypes = [String(kUTTypeItem)]// ["public.item"] Will open and provide access to all items on drive
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
   
        let vc =  TransferViewController.init()
        let avatarUrl = self.userInfo?.avatarURLStr
        let address = self.userInfo?.aliasName
        let toAddr = self.userInfo?.ethAddr
        if toAddr?.count == 0 || toAddr == nil {
            self.showToast("未获取到对方地址");
            return
        }
        vc.contactDict = ["avatarUrl":avatarUrl! as NSString,"address":address! as NSString,"toAddr":toAddr! as NSString]
        
        let coinArray = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID()
        let coin = coinArray?.first as! LocalCoin
        vc.coin = coin
        vc.transferBlock =  { [weak self] (coinName,txHash,amount) in
            
            self?.sendTransferMsg(coinName: coinName!, txHash: txHash!)
        }
        self.navigationController?.pushViewController(vc, animated: true)
            
    }
    
    func sendContact() {
        FZMLog("点击发送名片")
        
        let vc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let person = UIAlertAction(title: "个人名片", style: .default) { _ in
            let vc = ChoiceContactCardVC()
            vc.contactCardType = 1
            vc.seletedBlock = { [weak self] contact in
                self?.sendContactCard(contactId: contact.user!.address, name: "", avatar: contact.user!.aliasName, type: 1)
            }
            self.navigationController?.present(vc, animated: true)
        }
        let group = UIAlertAction(title: "群聊名片", style: .default) { _ in
            let vc = ChoiceContactCardVC()
            vc.contactCardType = 2
            vc.seletedBlock = { [weak self] contact in
                self?.sendContactCard(contactId: contact.group!.address, name: "", avatar:contact.group!.name , type: 2)
            }
            self.navigationController?.present(vc, animated: true)
        }
        
        let cancel = UIAlertAction(title: "取消", style: .destructive) { _ in
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
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        if url.startAccessingSecurityScopedResource() {
            NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: nil) { (newURL) in
                self.icloudFileBlock?([newURL])
            }
            url.stopAccessingSecurityScopedResource()
        }
    }
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.icloudFileBlock?(urls)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}

// MARK: - 图片视频选择Delegate
extension ChatVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        let mediaType = info[UIImagePickerController.InfoKey.mediaType.rawValue] as? String
        if mediaType == kUTTypeMovie as String {// 视频
            DispatchQueue.global().async {
                guard let mediaURL = info[UIImagePickerController.InfoKey.mediaURL.rawValue] as? URL else { return }
                var localIdentifier: String?
                PHPhotoLibrary.shared().performChanges({
                    localIdentifier = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: mediaURL)?.placeholderForCreatedAsset?.localIdentifier
                }) { (success, error) in
                    if success,
                       let localIdentifier = localIdentifier,
                       let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject {
                        UIImage.getVideoCropPicture(mediaURL) { (firstFrame) in
                            DispatchQueue.main.async {
                                picker.dismiss(animated: true, completion: { [self] in
                                    isHiddenStatusBar = false
                                    UIView.animate(withDuration: 0.5) {
                                        self.setNeedsStatusBarAppearanceUpdate()
                                    }
                                })
                                guard let firstFrame = firstFrame else { return }
                                self.sendVideoMsg(cropPicture: firstFrame, asset: asset, localPath: mediaURL)
                            }
                        }
                    }
                }
            }
        } else {// 图片
            DispatchQueue.main.async {
                picker.dismiss(animated: true, completion: { [self] in
                    isHiddenStatusBar = false
                    UIView.animate(withDuration: 0.5) {
                        self.setNeedsStatusBarAppearanceUpdate()
                    }
                })
                guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage else {
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
        var msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: .init(text: text))
        if mentionIds.count > 0 {
            msg.mentionIds = mentionIds
        }
        // 有引用消息
        if let refMsg = self.referenceMsg, let logId = refMsg.logId {
            let refId = logId
            var topicId = logId
            // 引用的消息已引用了其他消息
            if let curRef = refMsg.reference {
                topicId = curRef.topic
            }
            let ref = Message.Reference.init(ref: refId, topic: topicId)
            msg.reference = ref
        }
        
        self.insertAndSendMessages([msg], needSendMsg: true)
//        ChatManager.shared().send(msg: msg)//主线程异步插入数据未完成时发消息回执已返回，无法修改消息状态
    }
    // 发送系统消息
    private func sendTextNotifityMsg(text: String){
        let msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: .init(system: text))
        
        self.insertAndSendMessages([msg], needSendMsg: true)
    }
    
    // 转账
    private func sendTransferMsg(coinName:String,txHash:String){
        guard coinName.count > 0, txHash.count > 0 else { return }
        
        let msgType = Message.MsgType.init(transfer: coinName, txHash: txHash)
        let msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        
        self.insertAndSendMessages([msg],needSendMsg: true)
    }
    
    // 发送名片
    private func sendContactCard(contactId:String,name:String,avatar:String,type:Int){
        
        let msgType = Message.MsgType.init(contactCard: contactId, name: name, avatar: avatar, type: type)
        let msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        
        self.insertAndSendMessages([msg],needSendMsg: true)
    }
    
    
    // 发图片
    private func sendImageMsg(image: UIImage, gifData: Data? = nil) {
        
        let cacheKey = String.uuid()
        ImageCache.default.store(image, forKey: cacheKey)
        
        let msgType = Message.MsgType.init(image: nil, cacheKey: cacheKey, width: Double(image.size.width), height: Double(image.size.height))
//        let msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        var msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
        if let gifData = gifData {
            msg.gifData = gifData
        }
        
        self.insertAndSendMessages([msg], needSendMsg: true)
//        ChatManager.shared().send(msg: msg)
    }
    
    // 发视频
    private func sendVideoMsg(cropPicture: UIImage, asset: PHAsset, localPath: URL) {
        if #available(iOS 9.0, *) {
            guard let size = (PHAssetResource.assetResources(for: asset).first?.value(forKey: "fileSize") as? Int), (size / 1024 / 1024) < 600 else {
                //源视频大于600M(导出的时候会进行压缩),不能发送
                self.showToast("视频过大")
                return
            }
        }
        
        let cacheKey = String.uuid()
        ImageCache.default.store(cropPicture, forKey: cacheKey)
        
        // 视频转存
        guard let filePath = FZMLocalFileClient.shared().createFile(with: .video(fileName: cacheKey)), let outputPath = FZMLocalFileClient.shared().createFile(with: .tmp(fileName: cacheKey)) else {
            self.showToast("视频选取失败，请重试")
            return
        }
        
        DispatchQueue.global().async {
            
            defer {
                // 清除零时文件
                let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: outputPath)
            }
            
            // 视频转MP4格式
            let outputUrl = URL.init(fileURLWithPath: outputPath)
            let avAsset = AVURLAsset.init(url: localPath, options: nil)
            let exportSession = AVAssetExportSession.init(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
            exportSession?.outputFileType = .mp4
            exportSession?.outputURL = outputUrl
            exportSession?.shouldOptimizeForNetworkUse = true
            exportSession?.exportAsynchronously(completionHandler: {
                switch exportSession?.status {
                case .completed:
                    // 转码成功
                    if let data = try? Data.init(contentsOf: outputUrl), FZMLocalFileClient.shared().saveData(data, filePath: filePath) {
                        let msgType = Message.MsgType.init(video: nil, cacheKey: cacheKey, duration: asset.duration, width: Double(cropPicture.size.width), height: Double(cropPicture.size.height))
                        var msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
                        msg.mediaUrl = URL.init(string: filePath)
                        self.insertAndSendMessages([msg], needSendMsg: true)
                    } else {
                        self.showToast("视频转存本地失败，请重试")
                    }
                case .failed:
                    // 转码失败
                    self.showToast("视频转码失败，请重试")
                    FZMLog("视频转码失败:  \(String(describing: exportSession?.error))")
                default:
                    // 其他状态
                    FZMLog("视频转码的其他状态...")
                }
            })
        }
    }
    
    // 转存MP4格式视频到本地并发送
    private func saveAndSendVideo(tmpPath: String, filePath: String, cropPicture: UIImage, cacheKey: String, asset: PHAsset) {
        if let data = try? Data.init(contentsOf: URL.init(string: tmpPath)!), FZMLocalFileClient.shared().saveData(data, filePath: filePath) {
            let msgType = Message.MsgType.init(video: nil, cacheKey: cacheKey, duration: asset.duration, width: Double(cropPicture.size.width), height: Double(cropPicture.size.height))
            var msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
            msg.mediaUrl = URL.init(string: filePath)
            self.insertAndSendMessages([msg], needSendMsg: true)
        } else {
            self.showToast("视频转存本地失败，请重试")
        }
    }
    
    // 发语音
    private func sendAudioMsg(amrPath: String, wavPath: String, duration: Double) {
        let cacheKey = wavPath.fileName()
        let msgType = Message.MsgType.init(audio: nil, duration: duration, cacheKey: cacheKey, width: 0, height: 0)
        var msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
//        msg.audioUrl = amrPath
        msg.audioUrl = wavPath// 浏览器不支持amr格式，改为使用wav格式上传
        self.insertAndSendMessages([msg], needSendMsg: true)
    }
    
    // 发文件
    private func sendFileMsg(fileURL: URL) {
        if fileURL.startAccessingSecurityScopedResource() {
            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [.withoutChanges], error: nil) { (newURL) in
                guard let data = try? Data.init(contentsOf: newURL) else {
                    self.showToast("文件选取失败,请重试")
                    return
                }
                guard (data.count / 1024 / 1024) < 100 else {
                    self.showToast("文件不能大于100M")
                    return
                }
                let cacheKey = String.uuid()
                
                let fileName = newURL.lastPathComponent
//                let filePath = DocumentPath.appendingPathComponent("File/\(cacheKey)/\(fileName)")
                let fileFolder = "\(cacheKey)/\(fileName)"
                
                guard let filePath = FZMLocalFileClient.shared().createFile(with: .file(fileName: fileFolder))  else {
                    self.showToast("文件选取失败,请重试")
                    return
                }
                
                if FZMLocalFileClient.shared().saveData(data, filePath: filePath) {
                    let msgType = Message.MsgType.init(file: nil, cacheKey: cacheKey, name: fileName, md5: OSSUtil.fileMD5String(filePath), size: Double(data.count))
                    var msg = Message.init(fromId: LoginUser.shared().address, sessionId: self.session.id, msgType: msgType)
                    msg.fileUrl = filePath
                    self.insertAndSendMessages([msg], needSendMsg: true)
                    
//                    let msg = SocketMessage.init(filePath: filePath, fileSize: data.count, from: IMLoginUser.shared().userId, to: self.conversation.conversationId, channelType: self.conversation.type,isBurn: false, isEncryptMsg:self.isEncrypt)
//                    self.insertAndSendMessages([msg], needSendMsg: true)
                } else {
                    self.showToast("文件选取失败，请重试")
                }
            }
            fileURL.stopAccessingSecurityScopedResource()
        } else {
            self.showToast("文件选取失败,请重试")
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
                
                guard let index = self.messageArray.firstIndex(of: msg) else { return }
                self.messageArray[index] = message
                self.collectionView.reloadSections(IndexSet([index]))
                
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
    func messageCollectionView(_ messageCollectionView: MessageCollectionView, messageForItemAt indexPath: IndexPath) -> Message {
        guard self.messageArray.count > indexPath.section else {
            return Message.init(fromId: "", sessionId: self.session.id, msgType: .init(text: ""))
        }
        return self.messageArray[indexPath.section]
    }
    
    func numberOfSections(in messageCollectionView: MessageCollectionView) -> Int {
        return self.messageArray.count
    }
    
    func messageCollectionView(_ messageCollectionView: MessageCollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    /// 消息时间戳DataSource
    func cellTopLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        
        if message.showTime {
            let timeStr = String.showTimeString(with: Double(message.datetime))
            let attr = NSAttributedString(string: timeStr, attributes: [.foregroundColor: Color_8A97A5,.font:UIFont.preferredFont(forTextStyle: .footnote)])
            
            return attr
        } else {
            return nil
        }
    }
    
    func cellBottomLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        switch message.kind {
        case .notification(let notifyItem):
            let text = notifyItem.text
            let attr = NSAttributedString(string: text, attributes: [.foregroundColor: Color_8A97A5,.font:UIFont.preferredFont(forTextStyle: .footnote)])
            
            return attr
        default:
            return nil
        }
    }
    
    func messageTopLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
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
    
    func messageBottomLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        return nil
    }
}

extension ChatVC: MessageLayoutDataSource {
    /// 是否显示时间戳
    func cellTopLabelHeight(for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        return message.showTime ? 30 : 0
    }
    
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        switch message.kind {
        case .notification(let notifyItem):
            let text = notifyItem.text
            let height = text.getContentHeight(font: UIFont.preferredFont(forTextStyle: .footnote), width: k_ScreenWidth - 40) + 10
            
            return max(40, height)
        default:
            return 0
        }
    }
}

extension ChatVC: MessagesDisplayDelegate {
    // 列表滚动后是否隐藏顶部/底部未读消息视图处理
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        if self.collectionView.mj_header?.isRefreshing == false, topUnreadCount <= messageArray.count, indexPath.section <= messageArray.count - topUnreadCount {
            hideTopUnreadBtn()
        }
        if indexPath.section >= collectionView.numberOfSections - 1 {
            hideBottomUnreadBtn()
        }
    }
    
    // 头像显示处理
    func configureAvatarView(_ avatarView: AvatarView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) {
        if message.isOutgoing {//自己
            if LoginUser.shared().avatarUrl.isEmpty {
                avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
            } else {
                avatarView.kf.setImage(with: URL.init(string: LoginUser.shared().avatarUrl), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
            }
        } else {//其他用户
            UserManager.shared().getUser(by: message.fromId) { (user) in
                DispatchQueue.main.async {
                    guard let user = user else {
                        avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
                        return
                    }
                    avatarView.kf.setImage(with: URL.init(string: user.avatarURLStr), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
                }
            }
            
            if let user = message.user {
                avatarView.kf.setImage(with: URL.init(string: user.avatarURLStr), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
            } else {
                if let user = UserManager.shared().user(by: message.fromId) {
                    avatarView.kf.setImage(with: URL.init(string: user.avatarURLStr), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
                } else {
                    avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
                    UserManager.shared().getNetUser(targetAddress: message.fromId)
                }
            }
        }
    }
    
    // 群成员昵称、类型视图
    func configureNameView(_ nameView: NameView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) {
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
            if let member = GroupManager.shared().getDBGroupMember(with: self.session.id.idValue.intEncoded, memberId: message.fromId) {
                nameStr = member.contactsName
                type = member.memberType
            } else if let user = UserManager.shared().user(by: message.fromId) {
                nameStr = user.contactsName
            }
        }
        
        nameView.setNameAndType(isOutgoing: message.isOutgoing, name: nameStr, userType: type)
    }
    
    // 消息发送状态处理
    func configureStatusView(_ statusView: UIImageView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) {
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
            
            switch message.status {
            case .failed:
                statusView.image = #imageLiteral(resourceName: "chat_sendfail")
            case .sent:
                statusView.image = self.session.isPrivateChat ? #imageLiteral(resourceName: "chat_sent") : nil
                statusView.isHidden = self.session.isPrivateChat && message.isOutgoing ? false : true
            case .delivered:
                statusView.image = self.session.isPrivateChat ? #imageLiteral(resourceName: "chat_received") : nil
            case .sending:
                statusView.image = #imageLiteral(resourceName: "chat_sending")
                makeSendingAnimation(statusView)
            case .deleted:
                break
            }
        } else {
            statusView.isHidden = true
        }
    }
    
    // 语音未读红点
    func configureRedDotView(_ redDotView: UIView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) {
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
    
    // 点击消息内容区域
    func didTapMessage(in cell: MessageContentCell, message: Message) {
        FZMLog("didTapMessage \(message)")
        
//        self.view.endEditing(true)
        self.inputBarView.inputTextView.textView.resignFirstResponder()
        
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
            let cell = cell as! MediaMessageCell
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
            
        case .transfer:
            let vc = TradeDetailViewController.init()
            vc.isPushedByNotification = true
            vc.coin = FZMMessageBaseVM.getLocalCoin(with: message)
            vc.tradeHash = message.msgType.txHash;
            
            self.navigationController?.pushViewController(vc, animated: true)
        case .contactCard(_):
            let type = message.msgType.contactType
            if type == 1 {
                FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: message.msgType.contactId!, source: .normal))
            }else if type == 2 {
                let inviteId = message.isOutgoing ? LoginUser.shared().address : self.session.id.idValue
                FZMUIMediator.shared().pushVC(.goAddGroup(groupId: Int(message.msgType.contactId!)!, inviterId: inviteId))
            }else {
                let detail = message.msgType.contactAvatar!
                FZMUIMediator.shared().pushVC(.goRedpacket(detail: detail))
            }
           
        default:
            return
        }
    }
    
    //打开消息内的url
    func openUrl(urlStr: NSString) {
        if urlStr .contains("www") {
            if let url = URL(string: urlStr as String) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
    }
    
    // 下载语音、视频、文件类型消息（需把资源文件缓存到本地的消息）
    func downloadData(cell: MessageContentCell, msg: Message) {
        // 开始下载文件
        DispatchQueue.global().async {
            cell.vm?.downloadData()
        }
        
        // 下载成功订阅
        cell.vm?.fileDownloadSucceedSubject.subscribe { [weak self] (event) in
            guard let strongSelf = self, case .next(let msg) = event, msg.msgId == strongSelf.curTapMsg?.msgId else { return }// 判断回调后当前点击的消息
            let filePath = FZMMessageBaseVM.getFilePath(with: msg)
            guard !filePath.isBlank, FZMLocalFileClient.shared().isFileExists(atPath: filePath) else {
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
            guard let strongSelf = self, case .next(let msg) = event, msg.msgId == strongSelf.curTapMsg?.msgId else { return }
            strongSelf.showToast("下载失败")
            FZMLog("下载失败 msg \(msg)")
        }).disposed(by: bag)
        
        // 下载进度
        cell.vm?.fileDownloadProgressSubject.subscribe({ (event) in
            guard case .next(let progress) = event else { return }
            if case .file = msg.msgType {
                let fileCell = cell as! FileMessageCell
                fileCell.updateDownLoadProcress(proress: progress)
            } else if case .video = msg.msgType {
                let mediaCell = cell as! MediaMessageCell
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
                    documentInteractionController.presentOpenInMenu(from: navRect, in: self.view, animated: true)
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
    func playVideoWithUrl(fileUrl : String){
        DispatchQueue.main.async {
            try? AVAudioSession.sharedInstance().setCategory(.playback)// 添加此行代码可在静音模式下播放音频
            
            let item = AVPlayerItem(url: URL(fileURLWithPath: fileUrl))
            let play = AVPlayer(playerItem:item)
            let playController = AVPlayerViewController()
            playController.player = play
            self.present(playController, animated: true, completion: {
                playController.view.addSubview(self.downloadBtn)
                playController.view.bringSubviewToFront(self.downloadBtn)
                self.downloadBtn.tag = 2
                self.downloadBtn.frame = CGRect.init(x: k_ScreenWidth - 80, y: k_ScreenHeight - 80, width: 30, height: 30)
            })
        }
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
            lanternCell?.imageView.kf.setImage(with: URL.init(string: url), placeholder: placeholder)
        }
        lantern.transitionAnimator = LanternZoomAnimator(previousView: { index -> UIView? in
            return cell.imageView
        })
        lantern.pageIndex = 1
        lantern.view.addSubview(downloadBtn)
        downloadBtn.tag = 1
        downloadBtn.frame = CGRect.init(x: k_ScreenWidth - 45, y: k_ScreenHeight - 60, width: 30, height: 30)
        lantern.show()
    }
    
    //保存图片和保存视频公用 tag==1保存图片  tag==2保存视频
    func saveBtnClick() {
        if self.downloadBtn.tag == 1{//保存图片
            let img = curTapMediaCell?.imageView.image
            let imgData = curTapMsg?.gifData
            if (imgData != nil) {//保存gif到相册
                PHPhotoLibrary.shared().performChanges({
                    let options =  PHAssetResourceCreationOptions()
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imgData! as Data, options: options)
                    }) { (isSuccess: Bool, error: Error?) in
                        var showMessage = ""
                        if isSuccess {
                            showMessage = "图片已保存"
                        } else{
                            showMessage = "图片保存失败"
                        }
                        DispatchQueue.main.async {
                            APP.shared().showToast(showMessage)
                        }
                    }
            } else {//保存普通图片到相册
                UIImageWriteToSavedPhotosAlbum(img!, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
            }
        }else{//保存视频
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.saveToAlUrl){
                UISaveVideoAtPathToSavedPhotosAlbum(self.saveToAlUrl, self, #selector(self.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    
    @objc func video(videoPath: String, didFinishSavingWithError error: NSError, contextInfo info: AnyObject) {
        var showMessage = ""
        if error.code != 0{
            showMessage = "视频保存失败"
        }else{
            showMessage = "视频已保存"
        }
        DispatchQueue.main.async {
            APP.shared().showToast(showMessage)
        }
    }
    
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = "图片保存失败"
        }else{
            showMessage = "图片已保存"

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
        
        let vc = FriendInfoVC.init(with: address, source:self.session.isPrivateChat ? nil : .group(groupId: self.session.id.idValue.intEncoded))
        vc.sendredBlock = {[] (note) in
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
            self.inputBarView.mentionGroupMember(with: self.session.id.idValue.intEncoded, msg: message)
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
                UIPasteboard.general.string = msg.msgType.textValue
            default:
                break
            }
        }
        
        func changeVoicePlayMode() {
            VoiceMessagePlayerManager.shared().exchangePlayMode()
            self.showToast("已切换为\(VoiceMessagePlayerManager.shared().playMode ? "听筒" : "扬声器")播放")
        }
        
        let voiceItem: FZMMsgMenuItem
        if VoiceMessagePlayerManager.shared().playMode {
            voiceItem = FZMMsgMenuItem(type: .loudspeaker, block: {
                FZMLog("扬声器")
                changeVoicePlayMode()
            })
        } else {
            voiceItem = FZMMsgMenuItem(type: .handset, block: {
                FZMLog("听筒")
                changeVoicePlayMode()
            })
        }
        
        let translateItem = FZMMsgMenuItem(type: .translate) {
            FZMLog("转文字")
        }
        
        switch msg.kind {
        case .text:
            itemArr.append(copyItem)
        case .audio:
            itemArr.append(voiceItem)
            itemArr.append(translateItem)
        default:
            break
        }
        
        //wjhTEST
//        // 回复仅支持：文字、图片、视频、文件
//        let replyItem = FZMMsgMenuItem(type: .reply) { [weak self] in
//            FZMLog("回复（引用），自己发送的消息也可回复，回复消息默认@被回复的人，回复仅支持：文字、图片、视频、文件")
//            guard let strongSelf = self else { return }
//
//            strongSelf.replyMsgAction(msg)
//        }
//        switch msg.kind {
//        case .text, .photo, .video, .file:
//            itemArr.append(replyItem)
//        default:
//            break
//        }
        
        let deleteItem = FZMMsgMenuItem(type: .delete) {
            FZMLog("删除")
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.leftBtnTitle = "取消"
            alert.rightBtnTitle = "确定"
            
            let str = "确认删除？"
            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
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
        
        let msgStr = getReplyDetail(msg)
        
        // 输入框视图设置引用文字
        self.inputBarView.referenceMsgStr(msgStr)
        
        if !self.session.isPrivateChat, !msg.isOutgoing {
            // 引用消息，自动 @此群成员
            self.inputBarView.mentionGroupMember(with: self.session.id.idValue.intEncoded, msg: msg)
        } else {
            self.inputBarView.inputTextView.textView.becomeFirstResponder()
        }
    }
    
    // 获取引用消息的文本内容
    private func getReplyDetail(_ msg: Message) -> String {
        var detailStr = ""
        //wjhTODO
        //FIXME: 未完成
//        guard msg.isOutgoing else {
//            return "此消息已撤回"
//        }
//
//        guard msg.isRead else {
//            return "此消息已删除"
//        }
        
        // 获取引用对象昵称
        var showName = msg.isOutgoing ? LoginUser.shared().address.shortAddress : msg.fromId.shortAddress
        if self.session.isPrivateChat {// 私聊 昵称/地址
            if msg.isOutgoing {// 自己
                if let nickname = LoginUser.shared().nickName?.value, !nickname.isBlank {
                    showName = nickname
                }
            } else {
                if let user = UserManager.shared().user(by: msg.fromId), let nickname = user.nickname, !nickname.isBlank {
                    showName = nickname
                }
            }
        } else {// 群聊 群昵称/昵称/地址
            if msg.isOutgoing {// 自己
                if let membername = self.groupDetailInfo?.person?.memberName, !membername.isBlank {
                    showName = membername
                } else if let member = GroupManager.shared().getDBGroupMember(with: self.session.id.idValue.intEncoded, memberId: msg.fromId), let membername = member.memberName, !membername.isBlank {
                    showName = membername
                }
            } else {
                if let member = GroupManager.shared().getDBGroupMember(with: self.session.id.idValue.intEncoded, memberId: msg.fromId) {
                    showName = member.atName
                } else if let user = UserManager.shared().user(by: msg.fromId), let nickname = user.nickname, !nickname.isBlank {
                    showName = nickname
                }
            }
        }
        
        if !showName.isBlank {
            detailStr = showName + "："
        }
        
        // 根据消息类型显示具体信息,回复仅支持：文字、图片、视频、文件
        var contStr = ""
        switch msg.kind {
        case .text(let msgStr):
            contStr = msgStr
        case .photo:
            contStr = "[图片]"
        case .video:
            contStr = "[视频]"
        case .file(let fileItem):
            contStr = "[文件]\(fileItem.fileName ?? "")"
        default:
            return ""
        }
        
        detailStr += contStr
        
        return detailStr
    }
}

