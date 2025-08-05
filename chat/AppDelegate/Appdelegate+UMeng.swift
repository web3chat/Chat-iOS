//
//  Appdelegate+UMeng.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/16.
//

import Foundation
import UIKit

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    /// 开启消息推送
    func umRegisterForRemoteNotifi() {
        // push组件基本功能配置
        let entity = UMessageRegisterEntity.init()
        //type是对推送的几个参数的选择，可以选择一个或者多个。默认是三个全部打开，即：声音，弹窗，角标
        entity.types = Int(UMessageAuthorizationOptions.badge.rawValue|UMessageAuthorizationOptions.sound.rawValue|UMessageAuthorizationOptions.alert.rawValue)
        UNUserNotificationCenter.current().delegate = self
        UMessage.registerForRemoteNotifications(launchOptions: self.launchOptions, entity: entity) { (granted, error) in
            if granted {
                FZMLog("友盟推送注册成功")
            } else {
                FZMLog("友盟推送注册失败")
            }
        }
    }
    
    /// 关闭消息推送
    func umUnregisterForRemoteNotifi() {
        DispatchQueue.main.async {
            UMessage.unregisterForRemoteNotifications()
        }
    }
    
    // 友盟推送配置
//    func umPushConfig(launchOptions: [UIApplication.LaunchOptionsKey: Any]?)  {
    func umPushConfig() {
        // 是否清除角标 默认自动角标清零
        UMessage.setBadgeClear(false)
        
        //开发者需要显式的调用此函数，日志系统才能工作
        UMCommonLogManager.setUp()
        UMConfigure.setLogEnabled(true)//设置打开日志
        UMConfigure.initWithAppkey(UMAPPKEY, channel: "App Store")
        
        // 读取本地存储的友盟推送关闭flg
        let flg = FZM_UserDefaults.bool(forKey: CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY)
        if flg != true {
            // 离线通知开启
            self.umRegisterForRemoteNotifi()
        }
        
//        //如果要在iOS10显示交互式的通知，必须注意实现以下代码
//        if #available(iOS 10.0, *) {
//            let action1 = UNNotificationAction.init(identifier: "action1_identifier", title: "打开应用", options: .foreground)
//            let action2 = UNNotificationAction.init(identifier: "action2_identifier", title: "忽略", options: .foreground)
//            //UNNotificationCategoryOptionNone
//            //UNNotificationCategoryOptionCustomDismissAction  清除通知被触发会走通知的代理方法
//            //UNNotificationCategoryOptionAllowInCarPlay       适用于行车模式
//            let category1 = UNNotificationCategory.init(identifier: "category1", actions: [action1, action2], intentIdentifiers: [], options: .customDismissAction)
//            let categories = NSSet.init(objects: category1)
//            entity.categories = (categories as! Set<AnyHashable>)
//            UNUserNotificationCenter.current().delegate = self
//            UMessage.registerForRemoteNotifications(launchOptions: launchOptions, entity: entity) { (granted, error) in
//                if granted {
//
//                } else {
//
//                }
//            }
//
//        } else {
//            // Fallback on earlier versions
//            let action1 = UIMutableUserNotificationAction.init()
//            action1.identifier = "action1_identifier"
//            action1.title = "打开应用"
//            action1.activationMode = .foreground
//            let action2 = UIMutableUserNotificationAction.init()
//            action2.identifier = "action2_identifier"
//            action2.title = "忽略"
//            action2.activationMode = .background //当点击的时候不启动程序，在后台处理
//            action2.isAuthenticationRequired = true //需要解锁才能处理，如果action.activationMode = UIUserNotificationActivationModeForeground;则这个属性被忽略；
//            action2.isDestructive = true
//            let actionCategory1 = UIMutableUserNotificationCategory.init()
//            actionCategory1.identifier = "category1" // 这组动作的唯一标示
//            actionCategory1.setActions([action1, action2], for: .default)
//            let categories = NSSet.init(objects: actionCategory1)
//            entity.categories = (categories as! Set<AnyHashable>)
//        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        FZMLog("deviceToken : \(deviceToken)")
//        let device = NSData.init(data: deviceToken)
//        let device_Token = device.description.replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "").replacingOccurrences(of: " ", with: "")
//        FZMLog("deviceToken string: \(device_Token)")
        
        let deviceTokenStr = deviceToken.map{String(format:"%02.2hhx", arguments: [$0]) }.joined()
        FZMLog("设备token--- \(deviceTokenStr)")
        
        APPDeviceToken = deviceTokenStr
        
//        var deviceTokenString = String()
//        let bytes = [UInt8](deviceToken)
//        for item in bytes {
//            deviceTokenString += String(format:"%02x", item&0x000000FF)
//        }
//        FZMLog("设备token1--- \(deviceTokenString)")
    }
    
    //iOS10以下使用这两个方法接收通知
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // 标签
//        application.applicationIconBadgeNumber = 0
        
        UMessage.setAutoAlert(false)
        
        if #available(iOS 10.0, *) {
        } else {
            FZMLog("noti-didReceiveRemoteNotification  \(userInfo)")
            UMessage.didReceiveRemoteNotification(userInfo)
            completionHandler(UIBackgroundFetchResult.newData)
        }
    }
    
    //iOS10新增：处理前台收到通知的代理方法
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        if notification.request.isKind(of: UNPushNotificationTrigger.self) {
            //应用处于前台时的远程推送接受
            //关闭U-Push自带的弹出框
            UMessage.setAutoAlert(false)
            //必须加这句代码
            UMessage.didReceiveRemoteNotification(userInfo)
        } else {
            //应用处于前台时的本地推送接受
        }
        //当应用处于前台时提示设置，需要哪个可以设置哪一个
        completionHandler([.alert, .badge, .sound])
        
        // 收到通知消息处理
        self.handleNotificationCenterUserInfo(userInfo)
    }
    
    //iOS10新增：处理后台点击通知的代理方法
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if response.notification.request.isKind(of: UNPushNotificationTrigger.self) {
            //应用处于后台时的远程推送接受
            //必须加这句代码
            UMessage.didReceiveRemoteNotification(userInfo)
        } else {
            //应用处于后台时的本地推送接受
        }
        
        // 收到通知消息处理
        self.handleNotificationCenterUserInfo(userInfo)
    }
    
    // 收到通知消息处理
    private func handleNotificationCenterUserInfo(_ userInfo:[AnyHashable : Any]) {
        FZMLog("收到通知userinfo : \(userInfo)")
        /**
         // 普通通知消息
         收到通知userinfo : [AnyHashable("aps"): {
             alert =     {
                 body = "test-content";
                 subtitle = "test-title/";
                 title = "test-title";
             };
         }, AnyHashable("d"): ualexqx162389878067910, AnyHashable("p"): 0]
         
         // 跳转聊天通知消息
         收到通知userinfo : [AnyHashable("address"): 17m7ZAj8mQTsdDHAkvgePYcUGJ7fWrx899, AnyHashable("d"): ua061mw162390338776310, AnyHashable("channelType"): 0, AnyHashable("aps"): {
             alert =     {
                 body = "\U63a8\U9001\U5185\U5bb9";
                 subtitle = "test-title3";
                 title = "test-title2";
             };
             badge = 1;
             sound = default;
         }, AnyHashable("p"): 0]
         */
        
        if userInfo.keys.contains("aps"), let aps = userInfo["aps"] as? [String: Any], let badge = aps["badge"] as? Int {
            // let alert = aps["alert"] as? [String: String]
            FZMUIMediator.shared().setApplicationIconBadgeNumber(badge)
        }
        
        var address = ""
        var channelType = ""
        if userInfo.keys.contains("address") {
            address = userInfo["address"] as! String
        }
        if userInfo.keys.contains("channelType") {
            channelType = userInfo["channelType"] as! String
        }
        FZMLog("收到通知address : \(address)  channelType : \(channelType)")
        
        if LoginUser.shared().isLogin, !address.isBlank {
            if let session = SessionManager.shared().currentChatSession, session.id.idValue == address {
                // 当前已在该聊天页面内
                return
            }
            if channelType == "0" {// 私聊
                FZMLog("收到推送通知 私聊")
//                SessionManager.shared().goChatVC(with: SessionID.person(address))
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.person(address)))
                
            } else if channelType == "1" {// 群聊
                FZMLog("收到推送通知 群聊")
//                SessionManager.shared().goChatVC(with: SessionID.group(address))
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(address)))
                
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        FZMLog("error \(error.localizedDescription)")
    }
}
