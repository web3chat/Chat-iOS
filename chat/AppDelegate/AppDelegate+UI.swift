//
//  AppDelegate+UI.swift
//  chat
//
//  Created by fzm on 2021/1/4.
//

import Foundation

extension AppDelegate {
    /// 建窗 + 装根控制器（登录成功 / 退出登录 / 切换账号都走这里，**每次重建一个新窗口**）
    ///
    /// 写法与适配 iOS27 之前保持一致（`self.window = UIWindow(...)` + 换根 + makeKeyAndVisible），
    /// 唯一的区别是：iOS 13+ 走了场景生命周期后，窗口必须绑定 `windowScene`，
    /// 否则 `makeKeyAndVisible()` 不会把它挂到屏幕上（新建的首页在屏幕外，
    /// 看起来就是「切换账号只 pop 回『我的』页，没重进 App」）。
    func launchView() {
        let previousWindow = self.window
        self.window = AppDelegate.makeWindow()
        bindWindow()
        // 旧窗口原来靠 `self.window` 被替换后释放而消失；接入场景后 UIKit 可能仍持有它，
        // 显式隐藏，避免旧首页（含挂在窗口上的弹窗/HUD）残留。
        previousWindow?.isHidden = true
    }

    /// 场景生命周期下由 `SceneDelegate` 传入当前场景（首启时 connectedScenes 可能还没就绪）
    @available(iOS 13.0, *)
    func launchView(in scene: UIWindowScene) {
        let previousWindow = self.window
        self.window = UIWindow(windowScene: scene)
        bindWindow()
        previousWindow?.isHidden = true
    }

    /// 场景环境返回绑定 `windowScene` 的窗口，非场景环境返回老写法 `UIWindow(frame:)`
    private static func makeWindow() -> UIWindow {
        if #available(iOS 13.0, *), let scene = activeWindowScene() {
            return UIWindow(windowScene: scene)
        }
        return UIWindow(frame: UIScreen.main.bounds)
    }

    @available(iOS 13.0, *)
    private static func activeWindowScene() -> UIWindowScene? {
        guard AppDelegate.isSceneLifecycleEnabled else { return nil }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private func bindWindow() {
        self.window?.rootViewController = self.getRootVC()
        self.window?.makeKeyAndVisible()
        // SceneDelegate 也持有窗口引用，不同步过去它指向的还是被替换掉的旧窗口
        if #available(iOS 13.0, *),
           let scene = self.window?.windowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.window = self.window
        }
    }

    
    private func getRootVC() -> UIViewController {
        // 退出登录时先返回到根页面
        UIViewController.current()?.navigationController?.popToRootViewController(animated: false)
        
        FZMUIMediator.launchManager()
        
        guard LoginUser.shared().isLogin else {
            
            // 清空推送消息，app角标置为0
            FZMUIMediator.shared().setApplicationIconBadgeNumber(0)
            
            // 判断是否有登录过的账户数据，有则显示UserLoginVC，否则显示ChooseAccountVC
            if hasLoginData() {
                return UINavigationController.init(rootViewController: UserLoginVC.init())
            } else {
                return UINavigationController.init(rootViewController: ChooseAccountVC.init())
            }
            
        }
        
       
        
        // 获取我的用户信息以及发出登录成功通知
        LoginUser.shared().login()
        
        let sessionNav = FZMUIMediator.shared().getSessionNavigationController()
        self.createTabBarItem(nav: sessionNav, title: L("消息"), normalImg: UIImage(named: "tabBar_message"), selectImg: UIImage(named: "tabBar_message_sel"))
        
        let contactsNav = FZMUIMediator.shared().getContactsNavigationController()
        self.createTabBarItem(nav: contactsNav, title: L("通讯录"), normalImg: UIImage(named: "tabBar_contacts"), selectImg: UIImage(named: "tabBar_contacts_sel"))
        
        let searchNav = FZMUIMediator.shared().getSearchNavigationController()
        self.createTabBarItem(nav: searchNav, title: L("发现"), normalImg: UIImage(named: "tabBar_search"), selectImg: UIImage(named: "tabBar_search_sel"))
        
        
        ///钱包tab
        let walletNav = FZMUIMediator.shared().getMyDaoNavigationController()
        self.createTabBarItem(nav: walletNav, title: L("资产"), normalImg: UIImage(named: "tabBar_wallet"), selectImg: UIImage(named: "tabBar_wallet_sel"))
        
        let mineNav = FZMUIMediator.shared().getMineNavigationController()
        self.createTabBarItem(nav: mineNav, title: L("我的"), normalImg: UIImage(named: "tabBar_mine"), selectImg: UIImage(named: "tabBar_mine_sel"))
        
        let tabBar = FZMTabBarController()
//        tabBar.viewControllers = [walletNav, searchNav,sessionNav,contactsNav, mineNav]
        tabBar.viewControllers = [sessionNav, contactsNav,searchNav,walletNav, mineNav]
//        tabBar.viewControllers = [sessionNav, contactsNav, mineNav]
        FZMUIMediator.shared().homeTabbarVC = tabBar
        
        return tabBar
    }
    
    /// 判断数据库中是否有登录过的账户数据
    private func hasLoginData() -> Bool {
        guard let dbList = PWDataBaseManager.shared().queryAllUserInfoData() as? [[String: Any]], !dbList.isEmpty else {
            return false
        }
        return true
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
