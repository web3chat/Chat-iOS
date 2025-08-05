//
//  FriendInfoVC.swift
//  chat
//
//  Created by 陈健 on 2021/3/5.
//  用户详情页
//

import UIKit
import SnapKit
import SwifterSwift

enum FZMApplyEntrance {
    case normal //从好友信息
    case sweep //扫二维码
    case search //搜索
    case invite(inviterId: String)
    case group(groupId: Int) //群
    case share(userId: String) //分享
    case phoneContact
    case team
}

enum FZMUserType {
    case mySelf         // 自己
    case user           // 用户
    case friend         // 好友
    case shieldUser     // 黑名单成员
}

class FriendInfoVC: UIViewController, ViewControllerProtocol {
    
    private var source: FZMApplyEntrance = .normal// 从哪里进入页面标识
    
    private var userType: FZMUserType = .user// 用户类型
    
    private var isMuteNotification = false// 是否开启了免打扰
    
    private var isOnTop = false// 是否置顶
    
    private var isRefreshUserSuccess = false// 获取用户信息中和获取成功标识，以防重复请求
    private var isRefreshingUser = false
    
    private var serverGroup: UserChatServerGroup?// 当前给好友分配的聊天服务器信息
    
    private let disposeBag = DisposeBag.init()
    
    private var serverStatusDisposeBag: DisposeBag?// 聊天服务器bag
    
    private var dataSource = [[Any]]()// 列表数据源（固定5组数据，团队、免打扰、服务器、禁言、黑名单）
    
    var sendredBlock : StringBlock?
    
    let address: String
    
    var groupId : Int?// 群id
    
    private var user: User?// 用户信息
    
    private var groupMember: GroupMember?// 群成员信息
    
    private var groupDetailInfo: Group?
    
    
    
    //禁言显示
    private var bannedTimeLbl : UILabel?
    {
        didSet{
            if let time = groupMember?.memberMuteTime , time > Date.timestamp{
                let distance = (groupMember!.memberMuteTime - Date.timestamp)
                self.showPopAnimatiom(time: Double(distance)/1000)
            }
        }
    }
    
    // 团队成员信息
    private var staffInfo: StaffInfo?
    {
        didSet {
            self.teamInfoModel.userRealName = staffInfo?.name// 员工姓名
            self.teamInfoModel.organizationName = staffInfo?.entName// 员工所属企业名称
            self.teamInfoModel.phone = staffInfo?.phone// 员工手机号
            self.teamInfoModel.shortPhone = staffInfo?.shortPhone// 员工手机短号
            self.teamInfoModel.email = staffInfo?.email// 员工邮箱
            self.teamInfoModel.depName = staffInfo?.depName// 员工所属部门名称
            self.teamInfoModel.position = staffInfo?.position// 员工职位
            
            DispatchQueue.main.async {
                self.baseTableView.reloadData()
            }
        }
    }
    
    private lazy var avatarImageView: UIImageView = {
        let v = UIImageView.init(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        v.isUserInteractionEnabled = true
        
        let headTap = UITapGestureRecognizer()
        headTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            var avatarUrlStr = ""
            if strongSelf.userType == .mySelf {
                avatarUrlStr = LoginUser.shared().avatarUrl
            } else {
                guard let user = strongSelf.user else { return }
                avatarUrlStr = user.avatarURLStr
            }
            // 查看大图
            let vc = FZMEditHeadImageVC(with: .showPersonAvatar, oldAvatar: avatarUrlStr)
            strongSelf.navigationController?.pushViewController(vc)
        }.disposed(by: disposeBag)
        v.addGestureRecognizer(headTap)
        return v
    }()
    
    private lazy var aliasNameLab: UILabel = {
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        lab.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            self?.editFriendAlias()
        }).disposed(by: self.disposeBag)
        return lab
    }()
    
    private lazy var uidLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        lab.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let self = self, ges.state == .ended else { return }
            guard !self.address.isEmpty else { return }
            UIPasteboard.general.string = self.address
            self.showToast("地址已复制")
        }).disposed(by: self.disposeBag)
        return lab
    }()
    
    private lazy var nickLab: UILabel = {
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return nickLab
    }()
    
    // 用户信息视图
    private lazy var headerView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: Int(k_ScreenWidth) - 30, height: 90))
        v.backgroundColor = Color_F6F7F8
        v.addSubview(self.avatarImageView)
        self.avatarImageView.frame = CGRect.init(x: 0, y: 10, width: 50, height: 50)
        
        v.addSubview(self.aliasNameLab)
        self.aliasNameLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(10)
            m.left.equalTo(65)
            m.width.lessThanOrEqualTo(k_ScreenWidth - 95)
            m.height.greaterThanOrEqualTo(20)
        }
        
        v.addSubview(self.uidLab)
        self.uidLab.snp.makeConstraints { (m) in
            m.left.equalTo(self.aliasNameLab)
            m.right.equalToSuperview()
            m.top.equalTo(self.aliasNameLab.snp.bottom).offset(5)
        }
        
        return v
    }()
    
    private let bottomViewHeight: CGFloat = 110
    
    private lazy var footView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: bottomViewHeight))
        view.backgroundColor = .clear
        
        return view
    }()
    
    // 列表
    private lazy var baseTableView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = self.headerView
        view.tableFooterView = self.footView
        view.register(FriendInfoTeamCell.self, forCellReuseIdentifier: "FriendInfoTeamCell")
        view.register(FriendInfoSettingCell.self, forCellReuseIdentifier: "FriendInfoSettingCell")
        view.register(FriendInfoServerCell.self, forCellReuseIdentifier: "FriendInfoServerCell")
        view.register(FriendInfoBlackListCell.self, forCellReuseIdentifier: "FriendInfoBlackListCell")
        view.separatorColor = Color_F6F7F8
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        return view
    }()
    
    // 底部悬浮视图
    private lazy var bottomView: FriendInfoBottomView = {
        let view = FriendInfoBottomView.init()
        view.clickActionBlock = { [weak self] (index) in
            guard let strongSelf = self else { return }
            // type 0. 专属红包 1. 转账 2. 视频通话 3. 发消息 4. 添加好友 5. 删除好友
            switch index {
            case 0:
                strongSelf.sendRed()
            case 1:
                strongSelf.transfer()
            case 2:
                strongSelf.showToast("视频通话")
            case 3:
                // 发消息
                strongSelf.sendMsg()
            case 4:
                // 加好友
                strongSelf.addOrDeleteFriend()
            case 5:
                // 删好友
                strongSelf.addOrDeleteFriend()
            default:
                strongSelf.showToast("---")
            }
        }
        return view
    }()
    

    
    // 员工信息数据源
    private lazy var teamInfoModel: FriendInfoTeamCellModel = {
        let organization = FriendInfoTeamCellModel.init()
        organization.userRealName = ""
        organization.organizationName = ""
        organization.phone = ""
        organization.shortPhone = ""
        organization.email = ""
        organization.depName = ""
        organization.position = ""
        return organization
    }()
    
    // 免打扰/置顶数据源
    private lazy var muteAndOnTopModel: FriendInfoSwitchCellModel = {
        let model = FriendInfoSwitchCellModel.init()
        model.isMuteNofification = isMuteNotification
        model.isOnTop = isOnTop
        model.isMuteSwitchChangeBlock = { [weak self] (isSwitchOn) in
            // 消息免打扰
            self?.isMuteNotificationTapHandle(isSwitchOn: isSwitchOn)
        }
        model.isOnTopSwitchChangeBlock = { [weak self] (isOnTop) in
            // 置顶聊天
            self?.isOnTopTapHandle(isOn: isOnTop)
        }
        model.clickChatRecordBlock = { [weak self] in
            // 查找聊天记录
            self?.searchChatRecord()
        }
        model.clickChatFileBlock = { [weak self] in
            // 聊天文件
            self?.goToChatFileVC()
        }
        return model
    }()
    
    // 服务器数据源
    private lazy var serverModel: FriendInfoServerCellModel = {
        let server = FriendInfoServerCellModel.init()
        server.selectedBlock = { [weak self] in
            self?.toChatServerListVC()
        }
        return server
    }()
    
    // 黑名单数据源
    private lazy var blackListModel: FriendInfoTextCellModel = {
        let model = FriendInfoTextCellModel.init()
        var title = "加入黑名单"
        var conStr = ""
        if userType == .shieldUser {
            title = "移出黑名单"
            conStr = "已不再接受对方消息"
        }
        model.leftString = title
        model.rightString = conStr
        model.selectedBlock = {[weak self] in
            self?.blacklistTapHandle()
        }
        return model
    }()
    
    
    //禁言数据源
    private lazy var bannedListModel: FriendInfoTextCellModel = {
        let model = FriendInfoTextCellModel.init()
        var title = "禁言"
        var conStr = self.groupDetailInfo?.muteType == 1 ? "全员禁言" : "可发言"
        model.leftString = title
        model.rightString = conStr
        model.selectedBlock = {[weak self] in
            self?.bannedListTapHandel()
        }
        return model
    }()
    
    // MARK: -
    //    init(with address: String, groupId: Int? = nil, source: FZMApplyEntrance? = nil, usertype: FZMUserType? = nil) {
    init(with address: String, source: FZMApplyEntrance? = nil) {
        self.address = address
        //        self.groupId = groupId
        if let source = source {
            self.source = source
            switch source {
            case .group(let groupId):
                self.groupId = groupId
            case _: ()
            }
        }
        //        if let type = usertype {
        //            self.userType = type
        //        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.address != LoginUser.shared().address {
            self.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNavBackgroundColor()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "详细资料"
        
        self.setBgColor()
        
        // 页面布局
        self.setupViews()
        
        // 获取用户类型
        if self.address == LoginUser.shared().address {
            userType = .mySelf
        } else {
            if let user = UserManager.shared().user(by: address) {
                self.user = user
                if user.isShield {
                    userType = .shieldUser
                } else {
                    if user.isFriend {
                        userType = .friend
                    } else {
                        userType = .user
                    }
                }
            }
        }
        
        // 获取本地数据库用户员工信息和企业信息
        self.staffInfo = TeamManager.shared().getDBStaffInfo(address: self.address)
        if let entId = self.staffInfo?.entId {
            self.staffInfo?.company = TeamManager.shared().getDBTeamInfo(entId: entId)
        }
        
        // 获取本地群信息和群成员信息
        if let groupId = groupId {
            self.groupDetailInfo = GroupManager.shared().getDBGroup(by: groupId)
            self.groupMember = GroupManager.shared().getDBGroupMember(with: groupId, memberId: self.address)
        }
        
        // 刷新页面数据
        self.reloadData()
        
        
        //激活的用户进行以下请求
        if let staffInfo = staffInfo {
            if staffInfo.isActivated == true {
                // 获取用户详情请求
                self.refreshUserInfoRequest()
            }
        } else {
            // 获取用户详情请求
            self.refreshUserInfoRequest()
        }
        
        // 获取用户员工信息请求
        self.getStaffInfoRequest()
    }
    
    private func setBgColor() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8
    }
    
    private func setupViews() {
        self.view.backgroundColor = Color_F6F7F8
        
        self.view.addSubview(self.baseTableView)
        self.baseTableView.snp.makeConstraints { (m) in
            m.bottom.top.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        self.view.addSubview(self.bottomView)
        self.bottomView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview()
            m.height.equalTo(bottomViewHeight)
        }
    }
    
    // 显示头像
    private func showAvatarImageView(url: String) {
        if !url.isBlank {
            self.avatarImageView.kf.setImage(with: URL.init(string: url), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
        } else {
            self.avatarImageView.image = #imageLiteral(resourceName: "friend_chat_avatar")
        }
    }
    
    // 显示昵称 备注>群昵称>团队姓名>昵称>地址(显示前后各四位)
    private func showNickname() {
        // 展示的是自己的信息
        if userType == .mySelf {
            self.aliasNameLab.isUserInteractionEnabled = false
            
            let nickname = LoginUser.shared().nickName?.value// 昵称
            let address = LoginUser.shared().address.shortAddress// 地址
            var contactname = ""
            
            if let nickname = nickname, !nickname.isBlank {
                contactname = nickname
            } else {
                contactname = address
            }
            self.aliasNameLab.text = contactname
            
//            let staffname = LoginUser.shared().myStaffInfo?.name// 团队昵称
//            let membername = groupDetailInfo?.person?.memberName// 群昵称
            
            // 账号Lab文字显示
            let auAttText : NSMutableAttributedString =  NSMutableAttributedString.init()
            var nickStr = "账号：" + self.address
            
            let nStr = "\n"
            if let membername = groupDetailInfo?.person?.memberName, !membername.isBlank {
                nickStr = nickStr + nStr + "群昵称：" + membername
            }
            
//            if let staffname = staffname, contactname != staffname {
//                nickStr = nickStr + nStr + "团队昵称：" + staffname
//            }
            
            auAttText.append(NSAttributedString.init(string: nickStr))
            
            self.uidLab.attributedText = auAttText
            return
        }
        
        
        // 显示用户昵称
        let aliasName = self.user?.aliasName ?? self.address.shortAddress// 地址
        
        self.aliasNameLab.isUserInteractionEnabled = true
        self.aliasNameLab.attributedText = aliasName.jointImage(image: #imageLiteral(resourceName: "me_edit"))
            
        // 从群进入，群内禁止加好友，不是好友，普通群员 --> 只显示用户头像，昵称（不显示账号）和禁言一栏
        if case .group = self.source ,let friendType = self.groupDetailInfo?.friendType, friendType == 1, self.userType != .friend ,let memberType = self.groupDetailInfo?.person?.memberType, memberType == 0 {
            self.uidLab.text = nil
            self.uidLab.attributedText = nil
            return
        }
        
        // 账号Lab文字显示
        let auAttText : NSMutableAttributedString =  NSMutableAttributedString.init()
        
        var nickStr = "账号：" + self.address
        
        let nStr = "\n"
        if let _ = self.user?.alias {
            if let nickname = self.user?.nickname, !nickname.isBlank, aliasName != nickname {
                nickStr = nickStr + nStr + "昵称：" + nickname
            }
        }
        
//        if let staffname = self.staffInfo?.name {
//            nickStr = nickStr + nStr + "团队昵称：" + staffname
//        }
        
        if let membername = self.groupMember?.memberName, !membername.isBlank {// 从群进入，有群昵称则显示
            nickStr = nickStr + nStr + "群昵称：" + membername
        }
        
        auAttText.append(NSAttributedString.init(string: nickStr))
        
        self.uidLab.attributedText = auAttText
    }
    
    // 加载数据 自己/好友/用户
    private func reloadData() {
        self.dataSource = [
            [],
            [],
            [],
            [],
            []
        ]
        
        if userType == .mySelf {
            // 昵称
            self.showNickname()
            
            // 头像
            self.showAvatarImageView(url: LoginUser.shared().avatarUrl)
            
//            // 列表数据
//            if let _ = self.staffInfo {
//                self.dataSource = [
//                    [],
//                    [],
//                    [],
//                    [],
//                    []
//                ]
//            }
            
            self.footView.isHidden = true
            self.bottomView.isHidden = true
            
            self.baseTableView.reloadData()
            
            return
        }
        
        var isForbiddenAddFriend = false// 是否禁止加好友
        
        // 从群进入，群内禁止加好友，不是好友，普通群员 --> 只显示用户头像，昵称（不显示账号）和禁言一栏
        if case .group = self.source ,let friendType = self.groupDetailInfo?.friendType, friendType == 1, self.userType != .friend ,let memberType = self.groupDetailInfo?.person?.memberType, memberType == 0 {
            isForbiddenAddFriend = true
        }
        //群内禁止加好友
//        self.bottomView.isHidden = isForbiddenAddFriend
        if isForbiddenAddFriend {
            self.bottomView.hideother()
        }
        
        self.serverStatusDisposeBag = nil
        self.serverStatusDisposeBag = DisposeBag.init()
        
        // 头像
        self.showAvatarImageView(url: self.user?.avatarURLStr ?? "")
        
        // 昵称
        self.showNickname()
        
        let height = Int(self.uidLab.frame.maxY) + 15 > 90 ? Int(self.uidLab.frame.maxY) + 15 : 90
        self.headerView.frame = CGRect.init(x: 0, y: 0, width: Int(k_ScreenWidth) - 30, height: height)
        
        if userType == .shieldUser {// 在黑名单 只显示移出黑名单cell
            
            self.footView.isHidden = true
            self.bottomView.isHidden = true
            
            self.blackListModel.leftString = "移出黑名单"
            self.blackListModel.rightString = "已不再接受对方消息"
            
            // 列表数据
            if let _ = self.staffInfo {
                self.dataSource = [
                    [],
                    [],
                    [],
                    [],
                    [blackListModel]
                ]
            } else {
                self.dataSource = [
                    [],
                    [],
                    [],
                    [],
                    [blackListModel]
                ]
            }
        } else if userType == .friend || userType == .user && !isForbiddenAddFriend {// 正常好友状态或普通用户
            
            if userType == .friend {// 好友 显示删除好友按钮
                self.bottomView.itemDeleteFriendView.isHidden = false
                self.bottomView.itemAddFriendView.isHidden = true
            } else if userType == .user {// 普通用户 显示添加好友按钮
                self.bottomView.itemDeleteFriendView.isHidden = true
                self.bottomView.itemAddFriendView.isHidden = false
            }
            
            self.blackListModel.leftString = "加入黑名单"
            self.blackListModel.rightString = ""
            
            // 接收聊天服务器 如果没有设置默认服务器则配置一个
            let chatServerGroups = LoginUser.shared().chatServerGroups// 当前连接的所有IMServer
            
            if let user = self.user {
                // 如果给好友分配过chatServer
                let groups = user.groups
                if groups.count > 0 {
                    groups.forEach { (groupId) in
                        // 如果给好友设置的groupid所对应的server当前有连接
                        if let chatServerGroup = chatServerGroups.filter({ $0.id == groupId }).first {
                            self.serverGroup = chatServerGroup
                            return
                        }
                    }
                }else {
                    // 判断自己连接的与好友连接的chatServer是否有重合，有则给好友分配该地址
                    chatServerGroups.forEach { server in
                        if user.chatServers.contains(server.value) {
                            self.serverGroup = server
                            return
                        }
                    }
                }
            }
            
            // 未分配chatServer且与自己的chatServer没有重合的
            if self.serverGroup == nil {
                if let teamIMServer = TeamIMChatServer {// 在团队则默认分配团队的聊天服务器
                    let chatServerGroup = UserChatServerGroup.init(server: teamIMServer)
                    
                    self.serverGroup = chatServerGroup
                } else if !chatServerGroups.isEmpty {// 自己已连接有chatServer则分配第一条
                    let chatServerGroup = chatServerGroups.first
                    
                    self.serverGroup = chatServerGroup
                } else {
                    // 如果自己没有已连接的chatServer则分配默认的
                    if let server = OfficialChatServers?.first {
                        let chatServerGroup = UserChatServerGroup.init(server: server)
                        
                        self.serverGroup = chatServerGroup
                    }
                }
            }
            
            // 未给好友设置接收TA消息的IMServer时，自动分配一个IMServer
            if var user = self.user, user.groups.count == 0, let server = self.serverGroup {
                // 更新本地用户数据
                user.groups = [server.id]
                self.user = user
                UserManager.shared().updateDBUser(user)
                
//                // 切换好友服务器
//                self.updateFriendChatServerGroups(with: server)
            }
            
            // 订阅聊天服务器连接状态
            self.subscribeServerStatus()
            
            // 当前自己设置的接收对方的的聊天服务器信息
            self.serverModel.serverName = self.serverGroup?.name
            let serverUrl = self.serverGroup?.value ?? ""
            self.serverModel.serverUrlStr = serverUrl.shortUrlStr
            self.serverModel.isAvailable = MultipleSocketManager.shared().getSingleSocketConnectStatus(self.serverGroup?.value ?? "") == .connected ? true : false
            
            if let _ = self.staffInfo ,let name = self.staffInfo?.name, !name.isBlank {
                self.dataSource = [
                    [teamInfoModel],
                    [muteAndOnTopModel],
                    [serverModel],
                    [],
                    [blackListModel]
                ]
            } else {
                self.dataSource = [
                    [],
                    [muteAndOnTopModel],
                    [serverModel],
                    [],
                    [blackListModel]
                ]
            }
            
            // 免打扰
            if let user = self.user {
                isMuteNotification = user.isMuteNotification
                isOnTop = user.isOnTop
            }
            muteAndOnTopModel.isMuteNofification = isMuteNotification
            
            // 置顶
            muteAndOnTopModel.isOnTop = isOnTop
        }
        
        if case .group = self.source {
            //如果是从群过来的 显示禁言按钮
                
            self.dataSource[3] = [bannedListModel]
        }else {
            self.bottomView.hideRed()
        }
        
        self.baseTableView.reloadData()
    }
    
    /// 订阅聊天服务器连接状态
    private func subscribeServerStatus() {
        MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
            guard let strongSelf = self else { return }
            guard case .next((let url, let isAvailable)) = event else { return }
            guard ((strongSelf.serverGroup) != nil) else { return }
            
            if url == MultipleSocketManager.shared().transformUrl(strongSelf.serverGroup?.value ?? "") {
                strongSelf.serverModel.isAvailable = isAvailable
                
                DispatchQueue.main.async {
                    strongSelf.baseTableView.reloadData()
                }
            }
        }.disposed(by: self.serverStatusDisposeBag!)
    }
    
    //MARK: - 接口请求与
    // 获取用户员工信息
    private func getStaffInfoRequest() {
        self.showProgress()
        TeamManager.shared().getStaffInfo(address: self.address) { [weak self] (info) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            
            strongSelf.staffInfo = info
            
            // 该员工是否被激活 false: 未激活, 无法进行聊天; true: 已激活
            if !info.isActivated {
//                //wjhTODO 先只显示员工信息视图
//                strongSelf.dataSource = [
//                    [strongSelf.teamInfoModel],
//                    [],
//                    [],
//                    []
//                ]
//                strongSelf.baseTableView.reloadData()
            } else {
                if let oldStaffInfo = strongSelf.staffInfo {
                    if oldStaffInfo.isActivated == false {
                        strongSelf.refreshUserInfoRequest()
                    }
                }
                
                // 获取用户企业信息
                strongSelf.getTeamInfoRequest()
            }
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.staffInfo = nil
            strongSelf.hideProgress()
        }
    }
    
    // 获取用户企业信息
    private func getTeamInfoRequest() {
        guard let staffInfo = staffInfo else {
            return
        }
        TeamManager.shared().getEnterPriseInfo(entId: staffInfo.entId, successBlock: { [weak self] (teamInfo) in
            guard let strongSelf = self else { return }
            strongSelf.staffInfo?.company = teamInfo
        }, failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.showToast("获取企业信息失败")
        })
    }
    
    // 获取用户详情请求-更新本地用户信息
    private func refreshUserInfoRequest() {
        guard !isRefreshUserSuccess && !isRefreshingUser else { return }
        isRefreshingUser = true
        UserManager.shared().getNetUser(targetAddress: self.address) { [weak self] (user) in
            guard let strongSelf = self else { return }
            strongSelf.user = user
            
            strongSelf.reloadData()// 刷新页面
            strongSelf.isRefreshUserSuccess = true
            strongSelf.isRefreshingUser = false
            
            // 用户信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_RefreshUserInfo, object: strongSelf.address)
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.showToast("获取用户详情失败")
            strongSelf.isRefreshUserSuccess = false
            strongSelf.isRefreshingUser = false
        }
    }
    
    // 切换好友服务器
    private func updateFriendChatServerGroups(with chatServerGroup: UserChatServerGroup) {
        self.view.showActivity()
        let addressAndGroups = (address: self.address, groups: [chatServerGroup.id])
        BlockchainHelper.addOrUpdateFriends(addressAndGroups: [addressAndGroups]) { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            if var user = strongSelf.user {
                user.groups = [chatServerGroup.id]
                strongSelf.user = user
                UserManager.shared().updateDBUser(user)
            }
            
            // 更新会话聊天服务器地址
            SessionManager.shared().updateSessionChatServerUrl(session: SessionID.person(strongSelf.address), chatServerUrl: chatServerGroup.value)
            
            strongSelf.reloadData()// 刷新页面
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.view.show(error)
        }
    }
    
    // 加入黑名单请求
    private func requestAddToBlackList() {
        self.view.showActivity()
        // 写入合约 自动添加到本地数据库黑名单表，移出好友列表，并删除首页消息列表（保留消息记录）
        UserManager.shared().addShieldUser(by: self.address) { [weak self] (shieldUser) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            APP.shared().showToast("将对方加入黑名单成功，请耐心等待，稍后查看结果...")
            
            strongSelf.userType = .shieldUser
            
            strongSelf.reloadData()// 刷新页面
            
            // 删除首页消息列表（保留消息记录）
            SessionManager.shared().deleteSession(id: SessionID.person(strongSelf.address))
            
            strongSelf.navigationController?.popToRootViewController(animated: true)
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    // 添加好友请求
    @objc private func addFriend() {
        self.view.showActivity()
        UserManager.shared().addFriend(by: self.address) { [weak self] (friend) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.showToast("添加好友成功，请耐心等待，稍后查看结果...")
            strongSelf.user = friend
            strongSelf.userType = .friend
            strongSelf.reloadData()
            
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.view.show(error)
        }
    }
    
    // 删除好友请求
    @objc private func addOrDeleteFriend() {
        if userType != .friend {
            // 添加好友
            self.addFriend()
        } else {
            let alertController = UIAlertController.init(title: "提示", message: "确定删除该好友", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            let okAction = UIAlertAction.init(title: "确定", style: .destructive, handler: { (_) in
                self.view.showActivity()
                UserManager.shared().deleteFriend(by: self.address) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.view.hideActivity()
                    strongSelf.showToast("删除好友成功，请耐心等待，稍后查看结果...")
                    // 删除会话
                    SessionManager.shared().deleteSession(id: SessionID.person(strongSelf.address))
                    // 删除聊天记录
                    ChatManager.shared().deleteSessionMsgs(targetId: strongSelf.address)
                    
                    strongSelf.navigationController?.popToRootViewController(animated: true)
                } failureBlock: { [weak self] (error) in
                    guard let strongSelf = self else { return }
                    strongSelf.view.hideActivity()
                    strongSelf.view.show(error)
                }
            })
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // 查找聊天记录
    private func searchChatRecord() {
        FZMUIMediator.shared().pushVC(.goFullTextSearch(searchType: .chatRecord(specificId: self.address), limitCount: NSInteger.max, isHideHistory: true))
    }
    
    private func goToChatFileVC() {
        let vc = FZMFileViewController.init(session: Session.init(id: SessionID.person(self.address)))
        self.navigationController?.pushViewController(vc)
    }
    
    // 是否免打扰
    private func isMuteNotificationTapHandle(isSwitchOn: Bool) {
        isMuteNotification = isSwitchOn
        
        muteAndOnTopModel.isMuteNofification = isMuteNotification
        
        self.baseTableView.reloadData()
        
        // 更新本地好友信息
        UserManager.shared().updateUserMuteNotifacation(address: self.address, isMuteNoti: isMuteNotification)
        
        // 发送详情信息更新通知（聊天页面顶部）
        FZM_NotificationCenter.post(name: FZM_Notify_SessionInfoChanged, object: self.address)
    }
    
    // 是否置顶
    private func isOnTopTapHandle(isOn: Bool) {
        isOnTop = isOn
        muteAndOnTopModel.isOnTop = isOnTop
        
        self.baseTableView.reloadData()
        
        // 更新本地好友信息
        UserManager.shared().updateUserIsOnTop(address: self.address, isOnTop: isOnTop)
    }
    
    // 编辑备注名称
    @objc private func editFriendAlias() {
        guard let user = self.user else {
            return
        }
        let vc = EditNicknameVC.init()
        vc.editType = .alias
        vc.placeholder = user.alias
        vc.hidesBottomBarWhenPushed = true
        vc.compeletionBlcok = {[weak self] (alias) in
            guard let strongSelf = self, var user = strongSelf.user, alias != user.alias else { return }
            user.alias = alias
            strongSelf.user = user
            strongSelf.reloadData()
            UserManager.shared().updateDBUser(strongSelf.user!)
            
            // 更新会话名称
            SessionManager.shared().updateSessionName(session: strongSelf.user!.sessionID, name: user.contactsName)
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_SessionInfoChanged, object: strongSelf.address)
            
            // 用户信息更新通知(群聊需更新消息发送者名称)
            FZM_NotificationCenter.post(name: FZM_Notify_RefreshUserInfo, object: strongSelf.address)
        }
        self.navigationController?.pushViewController(vc)
    }
    
    // 跳转到服务器选择页面
    private func toChatServerListVC() {
        let chatServerGroups = LoginUser.shared().chatServerGroups
        let servers = chatServerGroups.compactMap {
            Server.init(name: $0.name, value: $0.value, id: $0.id)
        }
        let serverDataSource = [("接收聊天消息的服务器", servers)]
        let vc = ServerListVC.init()
        vc.listType = .chatServer
        vc.showManageBtnFlg = true
        vc.title = "选择服务器"
        vc.isHiddenSelectedImgView = true
        vc.dataSource = serverDataSource
        
        vc.selectedBlock = {[weak self, weak vc] (indexPath) in
            FZMLog("选择\(indexPath)")
            vc?.navigationController?.popViewController(animated: true)
            guard let self = self else { return }
            guard indexPath.section < serverDataSource.count,
                  indexPath.row < serverDataSource[indexPath.section].1.count else { return }
            let chatServerGroup = chatServerGroups[indexPath.row]
            self.updateFriendChatServerGroups(with: chatServerGroup)
        }
        self.navigationController?.pushViewController(vc)
    }
    
    // 黑名单项点击处理
    private func blacklistTapHandle() {
        if userType == .friend || userType == .user {
            let alias = self.user?.contactsName
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.leftBtnTitle = "取消"
            alert.rightBtnTitle = "确定"
            let str = "加入黑名单后，你将不再接收到对方的消息，确定将 \(alias!) 移至黑名单吗?"
            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
            attStr.addAttributes([NSAttributedString.Key.foregroundColor: Color_Theme], range:(str as NSString).range(of: alias! as String))
            alert.attributedInfo = attStr
            alert.leftBtnTouchBlock = {}
            alert.rightBtnTouchBlock = {
                self.requestAddToBlackList()
            }
            alert.show()
        } else {
            self.view.showActivity()
            // 移出黑名单请求，写入合约 移出本地数据库黑名单表，如果是好友则好友列表
            UserManager.shared().deleteShieldUser(by: self.address) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.view.hideActivity()
                strongSelf.showToast("移出黑名单成功，请耐心等待，稍后查看结果...")
                strongSelf.userType = .shieldUser
                
                strongSelf.reloadData()// 刷新页面
                strongSelf.navigationController?.popToRootViewController(animated: true)
            } failureBlock: { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.view.hideActivity()
                strongSelf.view.show(error)
            }
        }
    }
    
    //禁言项点击处理
    private func bannedListTapHandel() {
        if let type = self.groupDetailInfo?.person?.memberType, type == 1 || type == 2 {
            let view = BannedAlertView.init(with: self.groupMember!.memberId, groupId: self.groupId!)
            view.completeBlock = {
                self.groupMember = GroupManager.shared().getDBGroupMember(with: self.groupId!, memberId: self.address)
                let distance = (self.groupMember!.memberMuteTime - Date.timestamp)
                self.showPopAnimatiom(time: Double(distance)/1000)
            }
            view.cancelBlock = {
                FZMAnimationTool.removeCountdown(with: self.bannedTimeLbl!)
                self.bannedTimeLbl!.text = self.groupDetailInfo?.muteType == 1 ? "全员禁言" : "可发言"
            }
            view.show()
        } else {
            FZMLog("普通群成员不能修改其他群成员禁言类型...")
        }
    }
    
    // 点击发消息按钮
    @objc private func sendMsg() {
        
        // 判断当前地址是否有聊天，如果是则点击发消息按钮时返回聊天页
        guard SessionManager.shared().currentChatSession?.id.idValue == self.address else {
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.person(self.address)))
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func transfer(){
        let vc =  TransferViewController.init()
        let avatarUrl = user?.avatarURLStr
        let address = user?.aliasName
        let sessionId = user?.sessionID.idValue
        var toAddre = ""
        let coinArray = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID()
        let coin = coinArray?.first as! LocalCoin
        User.getUser(targetAddress: user!.address, count: 100, index: "", successBlock: {[weak self] (json) in
            guard let strongSelf = self else { return }
            let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
            
            for field in fields {
                if case .ETH = field.name {
                    toAddre = field.value
                }
            }
            if toAddre.count == 0{
                strongSelf.showToast("未获取到对方地址")
                return
            }
            
            vc.contactDict = ["avatarUrl":avatarUrl! as NSString,"address":address! as NSString,"toAddr":toAddre as NSString,"sessionId":sessionId! as NSString]
            vc.coin = coin
            vc.transferBlock =  { [] (coinName,txHash,amount) in
                let sessionID = SessionID.person(sessionId!)
                FZMUIMediator.shared().pushVC(.goChatVCToTransfer(sessionID: sessionID, coinName: coinName, txHash: txHash!))
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
            // 未设置过IM服务器 连接默认IM服务器 并上传保存到服务端
           
        }, failureBlock: nil)
    }
    
    @objc private func sendRed(){
        let vc =  TransferViewController.init()
        vc.fromTag = FromTagChat
        let avatarUrl = self.groupMember!.avatarURLStr
        let address = self.groupMember!.memberId
        let memberName = self.groupMember?.memberName
        let selfaddr = LoginUser.shared().address
        if selfaddr == address{
            self.showToast("不能给自己发专属红包")
            return
        }
        let coinArray = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID()
        let coin = coinArray?.first as! LocalCoin
       
        var toAddr = ""
        User.getUser(targetAddress: self.groupMember!.memberId, count: 100, index: "", successBlock: {[weak self] (json) in
            guard let strongSelf = self else { return }
            let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
            
            for field in fields {
                if case .ETH = field.name {
                    toAddr = field.value
                }
            }
            if toAddr.count == 0{
                strongSelf.showToast("未获取到对方地址")
                return
            }
            vc.contactDict = ["avatarUrl":avatarUrl as NSString,"address":memberName! as NSString,"toAddr":toAddr as NSString]
            
            vc.coin = coin
            //获取当前时间
            let currentDate = Date()
            
            // 创建一个DateFormatter实例
            let dateFormatter = DateFormatter()
            
            // 设置日期格式
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // 例如：2023-04-01 12:34:56
            
            // 将当前时间转换为字符串
            let dateString = dateFormatter.string(from: currentDate)
            
            vc.transferBlock =  { [] (coinName,txHash,amount) in
                
                let toAdddr = self!.user?.aliasName ?? self!.address
             // 接收者地址或昵称 币种+数量 时间
//                    let detail = toAdddr! + "," + amount + " " + coinName + "," + dateString
                let detail = "\(toAdddr),\(amount!) \(coinName!),\(dateString)"
                
                if ((self?.sendredBlock) != nil) {
                    self?.sendredBlock!(detail)
                }
                
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
            // 未设置过IM服务器 连接默认IM服务器 并上传保存到服务端
           
        }, failureBlock: nil)
    }
    
    private func showPopAnimatiom(time: Double) {
        
        if time < k_OnedaySeconds {
            FZMAnimationTool.removeCountdown(with: self.bannedTimeLbl!)
            let formatter = DateFormatter.getDataformatter()
            formatter.dateFormat = "HH:mm:ss"
            FZMAnimationTool.countdown(with: self.bannedTimeLbl!, fromValue: time, toValue: 0, block: { [weak self] (useTime) in
                guard let strongSelf = self else { return }
                let time = useTime - 8 * 3600
                let date = Date.init(timeIntervalSince1970: TimeInterval(time))
                strongSelf.bannedTimeLbl!.text = "禁言 " + formatter.string(from: date)
            },finishBlock: {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.bannedTimeLbl!.text = ""
            })
        }else{
            self.bannedTimeLbl!.text = "永久禁言"
        }
    }
}

extension FriendInfoVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView.init()
        v.backgroundColor = self.baseTableView.backgroundColor
        return v
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return dataSource[section].count == 0 ? 0 : 15
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            var height = 390
            let phone = self.staffInfo?.phone ?? ""
            let shortphone = self.staffInfo?.shortPhone ?? ""
            if phone.isBlank {
                height -= 50
            }
            if shortphone.isBlank {
                height -= 50
            }
            return CGFloat(height)
        } else if indexPath.section == 1 {
            return 200
        } else if indexPath.section == 2 {
            return 70
        } else {
            return 50
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = UITableViewCell.init()
        
        guard dataSource.count > indexPath.section else {
            return cell
        }
        let sectionData = self.dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else {
            return cell
        }
        let model = sectionData[indexPath.row]
        
        if let model = model as? FriendInfoTeamCellModel {
            let teamCell = tableView.dequeueReusableCell(withClass: FriendInfoTeamCell.self, for: indexPath)
            teamCell.configure(with: model)
            cell = teamCell
            
        } else if let model = model as? FriendInfoSwitchCellModel {
            let switchCell = tableView.dequeueReusableCell(withClass: FriendInfoSettingCell.self, for: indexPath)
            switchCell.configure(with: model)
            cell = switchCell
        } else if let model = model as? FriendInfoServerCellModel {
            let serverCell = tableView.dequeueReusableCell(withClass: FriendInfoServerCell.self, for: indexPath)
            serverCell.configure(with: model)
            cell = serverCell
        } else if let model = model as? FriendInfoTextCellModel {
            let blackListCell = tableView.dequeueReusableCell(withClass: FriendInfoBlackListCell.self, for: indexPath)
            blackListCell.configure(with: model)
            cell = blackListCell
            if indexPath.section == 3{
                self.bannedTimeLbl = blackListCell.rightLab
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 固定5组数据，团队、免打扰、服务器、禁言、黑名单
        guard dataSource.count > indexPath.section else {
            return
        }
        let sectionData = self.dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else {
            return
        }
        let model = sectionData[indexPath.row]
        if indexPath.section == 2 {
            guard let model = model as? FriendInfoServerCellModel else { return }
            model.selectedBlock?()
        } else if indexPath.section == 3 {
            guard let model = model as? FriendInfoTextCellModel else { return }
            model.selectedBlock?()
        }
    }
}
