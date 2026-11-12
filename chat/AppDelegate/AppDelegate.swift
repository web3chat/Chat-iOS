//
//  AppDelegate.swift
//  chat
//
//  Created by fzm on 2020/12/9.
//

import UIKit
import GKNavigationBarSwift
import IQKeyboardManagerSwift

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private static let sharedInstance = AppDelegate.init()
    
    class func shared() -> AppDelegate{
        return sharedInstance
    }
    
    var window: UIWindow?
    
//    var homeTabbarVC : FZMTabBarController?
    
    var isFirstApplicationDidBecomeActive = true
    
    var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    
    /// Info.plist 里声明了 `UIApplicationSceneManifest` 就说明走场景生命周期。
    /// iOS 27 起「声明了场景但没有接场景生命周期」会直接 `__builtin_trap`，
    /// 所以这里用一个判断保证建窗只发生在一个地方。
    static var isSceneLifecycleEnabled: Bool {
        guard #available(iOS 13.0, *) else { return false }
        return Bundle.main.infoDictionary?["UIApplicationSceneManifest"] != nil
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration",
                                                 sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // 顶部导航栏统一成不透明白底（**关闭**系统「液态玻璃」）：
        // iOS 26/27 上不做这层兜底的话，nav bar 会变成玻璃材质，与 App 自己的设计混在一起。
        // 各页面自己的 appearance 仍然优先。
        if #available(iOS 15.0, *) {
            let nav = UINavigationBarAppearance()
            nav.configureWithOpaqueBackground()
            nav.backgroundColor = .white
            nav.shadowColor = .clear
            nav.buttonAppearance.normal.backgroundImage = UIImage()
            nav.buttonAppearance.highlighted.backgroundImage = UIImage()
            nav.doneButtonAppearance.normal.backgroundImage = UIImage()
            nav.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            nav.backButtonAppearance.normal.backgroundImage = UIImage()
            nav.backButtonAppearance.highlighted.backgroundImage = UIImage()
            UINavigationBar.appearance().standardAppearance = nav
            UINavigationBar.appearance().compactAppearance = nav
            UINavigationBar.appearance().scrollEdgeAppearance = nav
            UINavigationBar.appearance().compactScrollEdgeAppearance = nav
            UINavigationBar.appearance().isTranslucent = false
        }
        
        // 导航栏相关设置
        GKConfigure.awake()
        
        GKConfigure.setupCustom { (configure) in
            configure.gk_translationX = 15
            configure.gk_translationY = 20
            configure.gk_scaleX = 0.90
            configure.gk_scaleY = 0.92
            // ⚠️ 这个值就是「leftBarButtonItem 距屏幕左边的距离」。
            //    GKNavigationBar 会把它换算成 `_leadingBarConstraints.constant =
            //    gk_navItemLeftSpace - gk_fixedSpace()`。
            // ⚠️ 但它只对 **iOS 25 及以下** 有效：iOS 26 起导航栏内容视图换成了
            //    `NavigationBarContentView`，GKNavigationBar 挂的 `_UINavigationBarContentView*.`
            //    两个私有类不再被调用（模拟器实测：`_updateMarginConstraints` 一次都没触发）
            //    ⇒ iOS 26/27 上这个值不生效，返回按钮走系统原生位置。
            //    想再调就只改这一个数（0 = 贴齐安全区左边缘）。
            configure.gk_navItemLeftSpace = 6.0
            configure.gk_navItemRightSpace = 12.0
            
            configure.shiledItemSpaceVCs = ["TZ"]
        }
        
        AppDelegateIntercepter.shared().loadIQKeyboard()
        // 加载UI
        self.launch()
        
        // 友盟推送配置
        self.launchOptions = launchOptions
//        self.umPushConfig(launchOptions: self.launchOptions)
        self.umPushConfig()
        
        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = 0
        }
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        FZMLog("\n ===> 程序程序暂行 !")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        FZMLog("\n ===> 程序进入后台 !")
        
        //进入后台模式，主动断开socket，防止出现处理不了的情况
        DispatchQueue.main.async {
            MultipleSocketManager.shared().disconnectSockets()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        FZMLog("\n ===> 程序进入前台 !")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        FZMLog("\n ===> 程序重新激活 !")
        
        //进入前台模式，主动连接socket
        //解决因为网络切换或链接不稳定问题，引起socket断连问题
        //如果app从无网络，到回复网络，需要执行重连
        if !isFirstApplicationDidBecomeActive {
            DispatchQueue.main.async {
                MultipleSocketManager.shared().updateConnectedSockets()
                // socket 一直连着（没重连 / 没重新鉴权）时 syncMsg 不会自己再跑，
                // 上一次同步链提前收尾的话，离线消息就再也补不回来 ⇒ 回前台主动补一轮
                MultipleSocketManager.shared().restartAllOfflineSync()
            }
        }
        isFirstApplicationDidBecomeActive = false
        
        if let isNotFirstLaunchApp = UserDefaultsDB.isNotFirstLaunchApp, isNotFirstLaunchApp {
            // 通知权限是否开启判断
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { (status, error) in
                if !status {
                    FZMLog("用户不同意授权通知权限")
                    if UserDefaultsDB.userDismissedNotificationSettingsPrompt == true {
                        return
                    }
                    guard !APP.shared().hasShowNotifCenterFlg else {
                        return
                    }
                    APP.shared().showAlertController(type: .notifCenter)
                }
            }
        }
        UserDefaultsDB.isNotFirstLaunchApp = true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        FZMLog("\n ===> 程序意外暂行 !")
    }
}

