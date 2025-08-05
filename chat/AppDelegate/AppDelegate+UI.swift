//
//  AppDelegate+UI.swift
//  chat
//
//  Created by 陈健 on 2021/1/4.
//

import Foundation

extension AppDelegate {
    func launchView() {
        self.window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window?.rootViewController = self.getRootVC()
        self.window?.makeKeyAndVisible()
    }

    private func getRootVC() -> UIViewController {
        // 退出登录时先返回到根页面
        UIViewController.current()?.navigationController?.popToRootViewController(animated: false)
        
        FZMUIMediator.launchManager()
        
        guard LoginUser.shared().isLogin else {
            
            // 清空推送消息，app角标置为0
            FZMUIMediator.shared().setApplicationIconBadgeNumber(0)
            
            return UINavigationController.init(rootViewController: ChooseAccountVC.init())
        }
        
        // 获取我的用户信息以及发出登录成功通知
        LoginUser.shared().login()
        
        let sessionNav = FZMUIMediator.shared().getSessionNavigationController()
        self.createTabBarItem(nav: sessionNav, title: "消息", normalImg: UIImage(named: "tabBar_message"), selectImg: UIImage(named: "tabBar_message_sel"))
        
        let contactsNav = FZMUIMediator.shared().getContactsNavigationController()
        self.createTabBarItem(nav: contactsNav, title: "通讯录", normalImg: UIImage(named: "tabBar_contacts"), selectImg: UIImage(named: "tabBar_contacts_sel"))
        
        ///钱包tab
//        let walletNav = FZMUIMediator.shared().getWalletNavigationController()
        let walletNav = FZMUIMediator.shared().getMyDaoNavigationController()
        self.createTabBarItem(nav: walletNav, title: "资产", normalImg: UIImage(named: "tabBar_wallet"), selectImg: UIImage(named: "tabBar_wallet_sel"))
        
        let mineNav = FZMUIMediator.shared().getMineNavigationController()
        self.createTabBarItem(nav: mineNav, title: "我的", normalImg: UIImage(named: "tabBar_mine"), selectImg: UIImage(named: "tabBar_mine_sel"))
        
        let tabBar = FZMTabBarController()
        tabBar.viewControllers = [sessionNav, contactsNav,walletNav, mineNav]
//        tabBar.viewControllers = [sessionNav, contactsNav, mineNav]
        FZMUIMediator.shared().homeTabbarVC = tabBar
        
        return tabBar
    }
    
    func createTabBarItem(nav: UINavigationController, title: String, normalImg: UIImage?, selectImg: UIImage?) {
        let item = UITabBarItem(title: title, image: normalImg?.withRenderingMode(.alwaysOriginal), selectedImage: selectImg?.withRenderingMode(.alwaysOriginal))
        item.setTitleTextAttributes([.foregroundColor:Color_8A97A5,
                                     .font:UIFont.regularFont(12)],
                                    for: .normal)
        item.setTitleTextAttributes([.foregroundColor:Color_Theme,
                                     .font:UIFont.regularFont(12)],
                                    for: .selected)
        nav.tabBarItem = item
    }
}
