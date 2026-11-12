//
//  FriendInfoVC.swift
//  chat
//
//  Created by fzm on 2021/3/5.
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
        let v = UIImageView.init(image: #imageLiteral(resourceName: "avatar_persion"))
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
            self.showToast(L("地址已复制"))
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
                strongSelf.showToast(L("视频通话"))
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
    
    // 自动删除聊天记录数据源
    private lazy var autoDeleteModel: FriendInfoTextCellModel = {
        let model = FriendInfoTextCellModel.init()
        model.leftString = L("自动删除聊天记录")
        model.rightString = self.autoDeleteOptionString()
        model.selectedBlock = { [weak self] in
            self?.showAutoDeleteActionSheet()
        }
        return model
    }()
    
    // 手动删除聊天记录数据源
    private lazy var deleteChatRecordModel: FriendInfoTextCellModel = {
        let model = FriendInfoTextCellModel.init()
        model.leftString = L("删除聊天记录")
        model.rightString = ""
        model.selectedBlock = { [weak self] in
            self?.showDeleteChatRecordActionSheet()
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
        var title = L("加入黑名单")
        var conStr = ""
        if userType == .shieldUser {
            title = L("移出黑名单")
            conStr = L("已不再接受对方消息")
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
        var title = L("禁言")
        var conStr = self.groupDetailInfo?.muteType == 1 ? L("全员禁言") : L("可发言")
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = L("详细资料")
        
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
            var nickStr = L("账号：") + self.address
            
            let nStr = "\n"
            if let membername = groupDetailInfo?.person?.memberName, !membername.isBlank {
                nickStr = nickStr + nStr + L("群昵称：") + membername
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
        
        var nickStr = L("账号：") + self.address
        
        let nStr = "\n"
        if let _ = self.user?.alias {
            if let nickname = self.user?.nickname, !nickname.isBlank, aliasName != nickname {
                nickStr = nickStr + nStr + L("昵称：") + nickname
            }
        }
        
//        if let staffname = self.staffInfo?.name {
//            nickStr = nickStr + nStr + "团队昵称：" + staffname
//        }
        
        if let membername = self.groupMember?.memberName, !membername.isBlank {// 从群进入，有群昵称则显示
            nickStr = nickStr + nStr + L("群昵称：") + membername
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
            
            self.blackListModel.leftString = L("移出黑名单")
            self.blackListModel.rightString = L("已不再接受对方消息")
            
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
            
            self.blackListModel.leftString = L("加入黑名单")
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
                    FZM_EnableChatDeleteFeature ? [muteAndOnTopModel, autoDeleteModel, deleteChatRecordModel] : [muteAndOnTopModel],
                    [serverModel],
                    [],
                    [blackListModel]
                ]
            } else {
                self.dataSource = [
                    [],
                    FZM_EnableChatDeleteFeature ? [muteAndOnTopModel, autoDeleteModel, deleteChatRecordModel] : [muteAndOnTopModel],
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
            
            // 自动删除当前值回显
            autoDeleteModel.rightString = self.autoDeleteOptionString()
            // 以服务端为准刷新自动删除设置
            self.refreshAutoDeleteFromServer()
        }
        
        if case .group = self.source {
            //如果是从群过来的 显示禁言按钮
                
            self.dataSource[3] = [bannedListModel]
            // 从群进入的成员/好友详情：保留红包按钮（点击进「发专属红包」页面，见 sendRed()）
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
        guard FZM_EnableEnterpriseFeature else { return }// 企业号功能关闭，不发员工信息请求
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
        guard FZM_EnableEnterpriseFeature else { return }// 企业号功能关闭，不发企业信息请求
        guard let staffInfo = staffInfo else {
            return
        }
        TeamManager.shared().getEnterPriseInfo(entId: staffInfo.entId, successBlock: { [weak self] (teamInfo) in
            guard let strongSelf = self else { return }
            strongSelf.staffInfo?.company = teamInfo
        }, failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.showToast(L("获取企业信息失败"))
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
            strongSelf.showToast(L("获取用户详情失败"))
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
            APP.shared().showToast(L("将对方加入黑名单成功，请耐心等待，稍后查看结果..."))
            
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
            strongSelf.showToast(L("添加好友成功，请耐心等待，稍后查看结果..."))
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
            let alertController = UIAlertController.init(title: L("提示"), message: L("确定删除该好友"), preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: L("取消"), style: .cancel, handler: nil)
            let okAction = UIAlertAction.init(title: L("确定"), style: .destructive, handler: { (_) in
                self.view.showActivity()
                UserManager.shared().deleteFriend(by: self.address) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.view.hideActivity()
                    strongSelf.showToast(L("删除好友成功，请耐心等待，稍后查看结果..."))
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
    
    // 自动删除：当前值的显示文案
    private func autoDeleteOptionString() -> String {
        let option = SessionManager.shared().getSingleLocalSession(by: SessionID.person(self.address))?.autoDeleteOption ?? 0
        return (ChatAutoDeleteOption(rawValue: option) ?? .off).title
    }
    
    // 自动删除：弹出选项（选项与对接文档 option 枚举一致）
    private func showAutoDeleteActionSheet() {
        let alert = UIAlertController(title: L("自动删除聊天记录"), message: L("开启后，超过所选时间的聊天记录将被自动删除"), preferredStyle: .actionSheet)
        let currentOption = SessionManager.shared().getSingleLocalSession(by: SessionID.person(self.address))?.autoDeleteOption ?? 0
        for option in ChatAutoDeleteOption.allCasesInOrder {
            let title = option.rawValue == currentOption ? option.title + " ✓" : option.title
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] (_) in
                guard let self = self else { return }
                // 本地缓存 + 服务端同步（失败也保留本地，下次进入以服务端为准）
                SessionManager.shared().updateAutoDeleteOption(session: SessionID.person(self.address), option: option.rawValue)
                self.autoDeleteModel.rightString = self.autoDeleteOptionString()
                self.baseTableView.reloadData()
                ChatRecordAPI.autoDeleteSet(targetId: self.address, option: option, successBlock: { (_) in
                    FZMLog("设置自动删除成功 option: \(option.rawValue)")
                }, failureBlock: { (error) in
                    FZMLog("设置自动删除失败: \(error.localizedDescription)")
                })
            }))
        }
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    // 从服务端拉取自动删除设置并回写本地
    private func refreshAutoDeleteFromServer() {
        ChatRecordAPI.autoDeleteGet(targetId: self.address, successBlock: { [weak self] (json) in
            guard let self = self else { return }
            let option = json["option"].intValue
            SessionManager.shared().updateAutoDeleteOption(session: SessionID.person(self.address), option: option)
            self.autoDeleteModel.rightString = self.autoDeleteOptionString()
            self.baseTableView.reloadData()
        }, failureBlock: { (error) in
            FZMLog("获取自动删除设置失败: \(error.localizedDescription)")
        })
    }
    
    // 手动删除聊天记录：弹出时间范围选项
    private func showDeleteChatRecordActionSheet() {
        let alert = UIAlertController(title: L("删除聊天记录"), message: L("删除后，双方该时间段内的聊天记录都将被删除"), preferredStyle: .actionSheet)
        let options: [ChatRecordDateOption] = [.last1Day, .last3Days, .last7Days, .last30Days, .last90Days, .last180Days, .last365Days, .all, .custom]
        for option in options {
            alert.addAction(UIAlertAction(title: option.title, style: .destructive, handler: { [weak self] (_) in
                guard let self = self else { return }
                if option == .custom {
                    self.showCustomDateRangePicker()
                } else {
                    self.performCleanPrivate(option: option, startTime: nil, endTime: nil)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    // 自定义时间范围：依次选开始 / 结束时间
    private func showCustomDateRangePicker() {
        self.presentDatePicker(title: L("选择开始时间")) { [weak self] startDate in
            guard let self = self else { return }
            self.presentDatePicker(title: L("选择结束时间")) { [weak self] endDate in
                guard let self = self else { return }
                let start = Int(startDate.timeIntervalSince1970 * 1000)
                let end = Int(endDate.timeIntervalSince1970 * 1000)
                self.performCleanPrivate(option: .custom, startTime: min(start, end), endTime: max(start, end))
            }
        }
    }
    
    // 通用日期时间选择弹框
    private func presentDatePicker(title: String, completion: @escaping (Date) -> Void) {
        let alert = UIAlertController(title: title, message: "\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.frame = CGRect(x: 0, y: 40, width: 270, height: 200)
        if #available(iOS 13.4, *) { picker.preferredDatePickerStyle = .wheels }
        alert.view.addSubview(picker)
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: L("确定"), style: .default, handler: { (_) in completion(picker.date) }))
        self.present(alert, animated: true, completion: nil)
    }
    
    // 调服务端删除 + 本地同步删除
    private func performCleanPrivate(option: ChatRecordDateOption, startTime: Int?, endTime: Int?) {
        // ⚠️ 服务端要求「有效区间」：`startTime == endTime`（或跨度过小）会被判
        //    `请求参数错误:custom date range invalid`（2026-10-10 实测）。
        //    自定义选择器的 DatePicker 精确到**分钟**，两次选到同一分钟就会撞上 ⇒ 此处兜底补齐到 1 分钟。
        var startTime = startTime
        var endTime = endTime
        if option == .custom, let start = startTime, let end = endTime, end - start < 60_000 {
            endTime = start + 60_000
            FZMLog("【删除记录】自定义时间范围过小，已兜底为 1 分钟：start=\(start) end=\(start + 60_000)")
        }
        FZMLog("【删除记录】调接口 clean-private targetId=\(self.address) dateOpt=\(option.rawValue) start=\(startTime.map { String($0) } ?? "-") end=\(endTime.map { String($0) } ?? "-")")
        ChatRecordAPI.cleanPrivate(targetId: self.address, dateOpt: option, startTime: startTime, endTime: endTime, successBlock: { [weak self] (_) in
            guard let self = self else { return }
            FZMLog("【删除记录】接口成功，开始删本地 targetId=\(self.address)")
            self.deleteLocalMsgs(option: option, startTime: startTime, endTime: endTime)
            self.showToast(L("删除成功"))
        }, failureBlock: { [weak self] (error) in
            FZMLog("【删除记录】接口失败（本地不删）：\(error.localizedDescription)")
            self?.showToast(error.localizedDescription)
        })
    }
    
    // 本地同步删除对应时间范围的消息
    private func deleteLocalMsgs(option: ChatRecordDateOption, startTime: Int?, endTime: Int?) {
        guard let session = SessionManager.shared().getSingleLocalSession(by: SessionID.person(self.address)) else { return }
        if option == .all {
            ChatManager.shared().deleteLocalMsgs(session: session, startTime: nil, endTime: nil, clearAll: true)
        } else if option == .custom {
            ChatManager.shared().deleteLocalMsgs(session: session, startTime: startTime, endTime: endTime, clearAll: false)
        } else {
            let now = Date.timestamp
            let start = now - (option.days ?? 0) * 86400000
            ChatManager.shared().deleteLocalMsgs(session: session, startTime: start, endTime: now, clearAll: false)
        }
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
        let serverDataSource = [(L("接收聊天消息的服务器"), servers)]
        let vc = ServerListVC.init()
        vc.listType = .chatServer
        vc.showManageBtnFlg = true
        vc.title = L("选择服务器")
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
            // `user` 未加载时 contactsName 为 nil；强解包会闪退，空串时只是提示语里不带昵称
            let alias = self.user?.contactsName ?? ""
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: L("提示"), attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.leftBtnTitle = L("取消")
            alert.rightBtnTitle = L("确定")
            let str = L("加入黑名单后，你将不再接收到对方的消息，确定将") + "\(alias)" + L("移至黑名单吗?")
            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
            if !alias.isEmpty {
                attStr.addAttributes([NSAttributedString.Key.foregroundColor: Color_Theme], range:(str as NSString).range(of: alias))
            }
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
                strongSelf.showToast(L("移出黑名单成功，请耐心等待，稍后查看结果..."))
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
                self.bannedTimeLbl!.text = self.groupDetailInfo?.muteType == 1 ? L("全员禁言") : L("可发言")
            }
            view.show()
        } else {
            FZMLog(L("普通群成员不能修改其他群成员禁言类型..."))
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
        // 会话 id 兜底用当前用户地址，避免下面强解包
        let sessionId = user?.sessionID.idValue ?? self.address
        var toAddre = ""
        // 默认优先选 0x 开头的 BTY（与发红包页一致）；取不到币种就不进转账页
        guard let coin = PWDataBaseManager.shared().preferredTransferCoin() else {
            self.showToast(L("暂无可用币种"))
            return
        }
        User.getUser(targetAddress: user!.address, count: 100, index: "", successBlock: {[weak self] (json) in
            guard let strongSelf = self else { return }
            let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
            
            for field in fields {
                if case .ETH = field.name {
                    toAddre = field.value
                }
            }
            if toAddre.count == 0{
                strongSelf.showToast(L("未获取到对方地址"))
                return
            }
            
            vc.contactDict = ["avatarUrl":avatarUrl! as NSString,"address":address! as NSString,"toAddr":toAddre as NSString,"sessionId":sessionId as NSString]
            vc.coin = coin
            // 成功后不要先 pop 回本详情页：走 FromTagChat（成功后直接 pop 回聊天页；
            // 栈里没有聊天页时本页不 pop，由下面 transferBlock 的 .goChatVC 切页，本页随之销毁）
            vc.fromTag = FromTagChat
            vc.transferBlock = { (coinName, txHash, _) in
                // 转账成功后：暂存转账消息，切到该好友的会话，由 ChatVC 把转账消息发出去
                // （与「专属红包」同一条链路，不再依赖 goChatVCToTransfer 的延迟发送+强解包）
                guard let coinName = coinName, !coinName.isEmpty,
                    let txHash = txHash, !txHash.isEmpty
                else { return }
                let sessionID = SessionID.person(sessionId)
                ChatManager.shared().setPendingTransfer(
                    coinName: coinName, txHash: txHash, for: sessionID)
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: sessionID))
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
            // 未设置过IM服务器 连接默认IM服务器 并上传保存到服务端
           
        }, failureBlock: nil)
    }
    
    /// 从群进入的成员/好友详情：红包 = 给这个人发「专属红包」
    /// （进「发专属红包」页面：白名单 1 人、1 份；链上发完后回到群里把红包消息发出去）
    @objc private func sendRed(){
        let memberId = self.groupMember?.memberId ?? self.address
        guard !memberId.isEmpty, let group = self.groupDetailInfo else { return }
        guard memberId != LoginUser.shared().address else {
            self.showToast(L("不能给自己发专属红包"))
            return
        }
        // 群里展示的名字：群昵称 > 备注/昵称 > 短地址
        var name = self.groupMember?.memberName ?? ""
        if name.isBlank { name = self.user?.aliasName ?? "" }
        if name.isBlank { name = memberId.shortAddress }
        let groupSessionID = group.sessionID

        self.showProgress(with: nil)
        // ⚠️ 必须走网络取 ethAddr：本地 user 表没有 ethAddr 列，`getUser(by:)` 命中本地缓存会返回 nil
        // （「好友详情 → 转账」就是直连网络读 `.ETH` 字段的，这里与它保持一致）
        UserManager.shared().getEthAddressForUser(memberId) { [weak self] ethAddress in
            // 网络回调线程不保证在主线程，统一回到主线程更新 UI
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hideProgress()
                let address = ethAddress
                guard address.isValidEthereumAddressString else {
                    self.showToast(L("未获取到对方地址"))
                    return
                }
                let vc = FZMCreateLuckyBagVC(to: groupSessionID.idValue, isGroup: true,
                                             exclusiveAddresses: [address], exclusiveNames: [name])
                vc.sendCompleteBlock = { [weak self] (_, coinName, packetType, packetId, packetUrl, remark, _) in
                    guard let self = self else { return }
                    let txHash = packetId.isEmpty ? packetUrl : packetId
                    guard !coinName.isEmpty, !txHash.isEmpty else { return }
                    // 红包消息交给 ChatVC 发（和群聊里发红包同一条链路）：先暂存，进群会话后自动发出
                    ChatManager.shared().setPendingRedPacket(coinName: coinName, txHash: txHash,
                                                             remark: remark, packetType: packetType,
                                                             for: groupSessionID)
                    FZMUIMediator.shared().pushVC(.goChatVC(sessionID: groupSessionID))
                }
                vc.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
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
                strongSelf.bannedTimeLbl!.text = L("禁言 ") + formatter.string(from: date)
            },finishBlock: {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.bannedTimeLbl!.text = ""
            })
        }else{
            self.bannedTimeLbl!.text = L("永久禁言")
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
            // ⚠️ section 1 是**多行**：合集 cell（查找聊天记录/聊天文件/消息免打扰/置顶聊天，自然高 200）
            // + 自动删除聊天记录 + 删除聊天记录（文字行，各 50，与 section 3 一致）。
            // 以前这里给整段返回 250（且按行生效）⇒ 每行都被撑到 250，出现大片空白。
            let model = self.dataSource[indexPath.section][indexPath.row]
            return (model is FriendInfoSwitchCellModel) ? 200 : 50
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
