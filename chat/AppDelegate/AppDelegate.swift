//
//  AppDelegate.swift
//  chat
//
//  Created by 陈健 on 2020/12/9.
//

import UIKit
import GKNavigationBarSwift

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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // 导航栏相关设置
        GKConfigure.awake()
        
        GKConfigure.setupCustom { (configure) in
            configure.gk_translationX = 15
            configure.gk_translationY = 20
            configure.gk_scaleX = 0.90
            configure.gk_scaleY = 0.92
            configure.gk_navItemLeftSpace = 12.0
            configure.gk_navItemRightSpace = 12.0
            
            configure.shiledItemSpaceVCs = ["TZ"]
        }
        
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
            }
        }
        isFirstApplicationDidBecomeActive = false
        
        if let isNotFirstLaunchApp = UserDefaultsDB.isNotFirstLaunchApp, isNotFirstLaunchApp {
            // 通知权限是否开启判断
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { (status, error) in
                if !status {
                    FZMLog("用户不同意授权通知权限")
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

