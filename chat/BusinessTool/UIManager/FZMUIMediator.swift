//
//  FZMUIMediator.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/5.
//

import Foundation
import RxSwift

 enum FZMPushVCType {
    case goFullTextSearch(searchType: FZMFullTextSearchType = .all, limitCount: Int = 3, isHideHistory: Bool = false)//搜索好友/群/聊天记录
    case goChatVC(sessionID: SessionID, locationMsg:(String, String)? = nil, backToRootVC: Bool = true, selectedRootVCIndex: Int = 0)//去聊天
    case goChatVCToTransfer(sessionID:SessionID,coinName:String?,txHash:String,backToRootVC: Bool = true, selectedRootVCIndex: Int = 0)// 去聊天并转账
    case goUserDetailInfoVC(address: String, source: FZMApplyEntrance?)// 跳转到用户/好友详情页
    case goServer// 服务器列表页面
    case goQRCodeShow(type:FZMQRCodeVCShowType)//二维码展示
    case selectFriend(type: FZMSelectFriendGroupShowStyle, chatServerUrl:String?, completeBlock: NormalBlock?)//选择好友页
    case goChooseServerToCreateGroup// 创建群聊-跳转到选择服务器列表页面
    case goGroupDetail(groupId: Int)//群详情
    case goTeamH5WebVC(type: TeamViewType, completeBlock: NormalBlock?)// H5页面 团队相关页面
    case goAddGroup(groupId: Int,inviterId:String) //进入加群页面
    case goRedpacket(detail:String) // 进入红包详情页面
    case goChooseMemberSourceVC(type: FZMGroupChooseMemberType, server: Server? = nil, completeBlock: StringArrayBlock?)// 添加新群成员时选择好友/组织架构成员页面
}

@objc public class FZMUIMediator: NSObject {

    private static var sharedInstance: FZMUIMediator? = FZMUIMediator()
    private let disposeBag = DisposeBag()
    @objc public class func shared() -> FZMUIMediator {
        if let shared = sharedInstance {
            return shared
        } else {
            let shared = FZMUIMediator()
            sharedInstance = shared
            return shared
        }
    }
    
    class func launchManager() {
        // 启用前先重置
        if let _ = sharedInstance {
            sharedInstance = nil
        }
        let _ = FZMUIMediator.shared()
    }
    
    override init() {
        super.init()
//        IMNotifyCenter.shared().addReceiver(receiver: self, type: .user)
//        IMNotifyCenter.shared().addReceiver(receiver: self, type: .appState)
    }
    
    // 首页切换到通讯录页面
    func selectConversationNav(showGroup: Bool = false) {
        guard let tabBar = homeTabbarVC, let nav = contactsNav, let index = tabBar.viewControllers?.firstIndex(of: nav), let vc = nav.visibleViewController as? FriendListVC else { return }
        vc.showListViewAction(showGroup ? 1 : 0)
        tabBar.selectedIndex = index
    }
    
    //设置未读数
    func setTabbarBadge(with index: Int, count: Int) {
        DispatchQueue.main.async {
            guard let tabBar = self.homeTabbarVC as? FZMTabBarController else { return }
            tabBar.setTabbarBadge(with: index, count: count)
        }
    }
    
    // 设置app角标未读数
    func setApplicationIconBadgeNumber(_ count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    //跳转页面
    func pushVC(_ type: FZMPushVCType) {
        guard let tabBar = homeTabbarVC else { return }
        guard let nav = tabBar.selectedViewController as? UINavigationController else { return }
//        let selectNav = (nav is UINavigationController) ? nav : UIViewController.current()?.navigationController
        var vc : UIViewController?
        switch type {
        case .goChatVC(let sessionID, let locationMsg, let backToRootVC, let selectedRootVCIndex)://去聊天页面
            self.goToChatVC(with: sessionID, locationMsg: locationMsg, backToRootVC: backToRootVC, selectedRootVCIndex: selectedRootVCIndex)
        case .goChatVCToTransfer(let sessionID, let coinName,let txHash, let backToRootVC, let selectedRootVCIndex):
            self.goToChatVCToTransfer(with: sessionID, coinName: coinName, txHash: txHash,backToRootVC: backToRootVC,selectedRootVCIndex: selectedRootVCIndex)
        case .goFullTextSearch(let searchType, let limitCount, let isHideHistory):
            vc = FZMFullTextSearchVC.init(searchType: searchType, limitCount: limitCount, isHideHistory: isHideHistory)
        case .goUserDetailInfoVC(let address, let source):// 跳转到用户/好友详情页
            self.goUserDetailInfoVC(address: address, source: source)
        case .goServer:
            vc = ChooseServerVC.init()
        case .goQRCodeShow(type: let type):
            vc = QRCodeVC(with: type)
        case .selectFriend(type: let type, let chatServerUrl, completeBlock: let completeBlock):
            self.goSelectFriendVC(with: type, chatServerUrl:chatServerUrl, completeBlock: completeBlock)
        case .goChooseServerToCreateGroup:
            self.createGroup()
        case .goGroupDetail(groupId: let groupId):
            vc = FZMGroupDetailInfoVC(with: groupId)
        case .goTeamH5WebVC(let type, let completeBlock):
            self.goToTeamH5WebVC(with: type, completeBlock: completeBlock)
        case .goAddGroup(groupId: let groupId,let inviterId):
            vc = FZMAddGroupVC.init(with: groupId, inviterId: inviterId)
        case .goRedpacket(detail: let detail):
            vc = RedpackageDetailvc(with: detail)
        case .goChooseMemberSourceVC(let type, let server, let completeBlock):
            self.goToChooseMemberSourceVC(type: type, server: server, completeBlock: completeBlock)
        }
        if let vc = vc {
            DispatchQueue.main.async {
                vc.hidesBottomBarWhenPushed = true
                nav.pushViewController(vc)
            }
        }
    }
    
    // 跳转团队相关H5页面
    private func goToTeamH5WebVC(with type: TeamViewType, completeBlock: NormalBlock? = nil) {
        let vc = TeamH5WebViewVC.init(with: type)
        vc.teamOperationBlock = {
            completeBlock?()
        }
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
    
    // 选择好友/组织架构成员加入/创建群聊
    private func goToChooseMemberSourceVC(type: FZMGroupChooseMemberType, server: Server? = nil, completeBlock: StringArrayBlock? = nil) {
        let vc = FZMGroupChooseMemberSourceVC.init(with: type, server: server)
        vc.selectMembersBlock = { (list) in
            completeBlock?(list)
        }
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
    
    /// 创建群聊-跳转选择聊天服务器页
    @objc private func createGroup() {
        
        // 先选择在哪个服务器创建群聊（群聊选择完所在服务器后不可更改）
        let chatServerGroups = LoginUser.shared().chatServerGroups
        let servers = chatServerGroups.compactMap {
            Server.init(userchatServerGroup: $0)
        }
        let serverDataSource = [("接收聊天消息的服务器", servers)]
        
        let vc = ServerListVC.init()
        vc.listType = .chatServer
        vc.iscreateGroup = true
        vc.listType = .chatServer
        vc.showManageBtnFlg = true
        vc.dataSource = serverDataSource
        vc.isHiddenSelectedImgView = true
        vc.title = "选择服务器"
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
    
    //选择好友页
    private func goSelectFriendVC(with type: FZMSelectFriendGroupShowStyle, chatServerUrl: String? = "", completeBlock: NormalBlock? = nil) {
        guard let _ = homeTabbarVC else { return }
        let vc = FZMSelectFriendToGroupVC(with: type)
        if let serverUrl = chatServerUrl {
            vc.chatServerUrl = serverUrl
        }
        vc.reloadBlock = {
            completeBlock?()
        }
//        let nav = FZMNavigationController.init(rootViewController: vc)
//        DispatchQueue.main.async {
//            tabBar.selectedViewController?.present(nav, animated: true)
//        }
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
    
    // 跳转到用户详情页-普通用户、好友、黑名单用户、群成员用户
    private func goUserDetailInfoVC(address: String, source: FZMApplyEntrance? = nil) {
//        if address == LoginUser.shared().address {
//            let vc = MyQRCodeVC(with: .me)
//            vc.hidesBottomBarWhenPushed = true
//            DispatchQueue.main.async {
//                UIViewController.current()?.navigationController?.pushViewController(vc)
//            }
//        } else {
            let vc = FriendInfoVC.init(with: address, source: source)
            vc.hidesBottomBarWhenPushed = true
            DispatchQueue.main.async {
                UIViewController.current()?.navigationController?.pushViewController(vc)
            }
//        }
    }
    
    // 聊天页
    private func goToChatVC(with sessionID: SessionID, locationMsg:(String, String)? = nil, backToRootVC: Bool = true, selectedRootVCIndex: Int = 0) {
        let session = SessionManager.shared().getOrCreateSession(id: sessionID)
        SessionManager.shared().currentChatSession = session
        SessionManager.shared().clearUnreadCount(session: sessionID)
        
        let vc = ChatVC.init(session: session, locationMsg: locationMsg)
        
        guard let tabBar = homeTabbarVC, let nav = sessionNav, let nowNav = tabBar.selectedViewController as? UINavigationController, let index = tabBar.viewControllers?.firstIndex(of: nav) else { return }
        // 切换到页面的私聊/群聊
        DispatchQueue.main.async {
            // 切换根页面时先返回到根页面
            UIViewController.current()?.navigationController?.popToRootViewController(animated: false)
            
            tabBar.selectedIndex = index
            
            vc.hidesBottomBarWhenPushed = true
            
            if nowNav != nav, backToRootVC {// 判断当前页面是否是根页面，不是则返回到根页面
//                if nowNav is FZMNavigationController {
                    nav.pushViewController(vc, animated: true)
                    nowNav.popToRootViewController(animated: false)
//                } else {
//                    //其它工程引用chat33，联系人页面先消失再push，不然返回箭头不渲染。
//                    nowNav.dismiss(animated: true, completion: nil)
//                    nav.pushViewController(vc, animated: true)
//                }
            }else{
                nav.pushViewController(vc, animated: true)
            }
        }
        
//        UIViewController.current()?.navigationController?.popToRootViewController(animated: false)
//        UIViewController.current()?.tabBarController?.selectedIndex = 0
//        DispatchQueue.main.async {
//            UIViewController.current()?.navigationController?.pushViewController(vc)
//        }
    }
    
    private func goToChatVCToTransfer(with sessionID:SessionID,coinName:String?,txHash:String,backToRootVC: Bool = true, selectedRootVCIndex: Int = 0){
        let session = SessionManager.shared().getOrCreateSession(id: sessionID)
        SessionManager.shared().currentChatSession = session
        SessionManager.shared().clearUnreadCount(session: sessionID)
        
        let vc = ChatVC.init(session: session, coinName: coinName, txHash: txHash)
        
        guard let tabBar = homeTabbarVC, let nav = sessionNav, let nowNav = tabBar.selectedViewController as? UINavigationController, let index = tabBar.viewControllers?.firstIndex(of: nav) else { return }
        // 切换到页面的私聊/群聊
        DispatchQueue.main.async {
            // 切换根页面时先返回到根页面
            UIViewController.current()?.navigationController?.popToRootViewController(animated: false)
            
            tabBar.selectedIndex = index
            
            vc.hidesBottomBarWhenPushed = true
            
            if nowNav != nav, backToRootVC {// 判断当前页面是否是根页面，不是则返回到根页面
//                if nowNav is FZMNavigationController {
                    nav.pushViewController(vc, animated: true)
                    nowNav.popToRootViewController(animated: false)
//                } else {
//                    //其它工程引用chat33，联系人页面先消失再push，不然返回箭头不渲染。
//                    nowNav.dismiss(animated: true, completion: nil)
//                    nav.pushViewController(vc, animated: true)
//                }
            }else{
                nav.pushViewController(vc, animated: true)
            }
        }
        
    }
    // 返回到根页面
    func backToRootVC() {
        guard let tabBar = homeTabbarVC, let nav = sessionNav, let nowNav = tabBar.selectedViewController as? UINavigationController, let index = tabBar.viewControllers?.firstIndex(of: nav) else { return }
        
        DispatchQueue.main.async {
            // 切换根页面时先返回到根页面
            UIViewController.current()?.navigationController?.popToRootViewController(animated: false)
            
            tabBar.selectedIndex = index
                        
            nowNav.popToRootViewController(animated: false)
        }
    }
    
    var homeTabbarVC : UITabBarController?
    
    private var sessionNav: UINavigationController?
    /// 消息页面--root
    func getSessionNavigationController() -> UINavigationController {
        if let nav = sessionNav {
            return nav
        }
        let vc = SessionVC.init()
        let nav = UINavigationController.init(rootViewController: vc)
        sessionNav = nav
        return nav
    }
    
    private var contactsNav: UINavigationController?
    /// 通讯录页面--root
    func getContactsNavigationController() -> UINavigationController {
        if let nav = contactsNav {
            return nav
        }
        let vc = FriendListVC.init()
        let nav = UINavigationController.init(rootViewController: vc)
        contactsNav = nav
        return nav
    }
    
    private var walletNav : UINavigationController?
    ///钱包页面--root
    func getWalletNavigationController() -> UINavigationController {
        if let nav = walletNav {
            return nav
        }
        let vc = WalletVC.init()
        let nav = UINavigationController.init(rootViewController: vc)
        walletNav = nav
        return nav
    }
    
    func getMyDaoNavigationController() -> UINavigationController{
        if let nav = walletNav {
            return nav
        }
        let vc = PWNewsHomeViewController.init()
        let nav = UINavigationController.init(rootViewController: vc)
        walletNav = nav
        vc.homeTransferBlock = {[](coinName,txHash,sessionId) in
            let sessionsID = SessionID.person(sessionId)
            
            FZMUIMediator.shared().pushVC(.goChatVCToTransfer(sessionID: sessionsID, coinName: coinName, txHash: txHash))
        }
        return nav
    }
    
    private var mineNav: UINavigationController?
    /// 通讯录页面--root
    func getMineNavigationController() -> UINavigationController {
        if let nav = mineNav {
            return nav
        }
        let vc = MineVC.init()
        let nav = UINavigationController.init(rootViewController: vc)
        mineNav = nav
        return nav
    }
}
