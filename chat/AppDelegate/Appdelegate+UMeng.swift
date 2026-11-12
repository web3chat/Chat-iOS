//
//  Appdelegate+UMeng.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/16.
//

import Foundation
import UIKit

/// 推送 payload 里字段可能是 String / Int / NSNumber（例如 channelType: 0），强制 `as! String` 会在 Swift 里触发 SIGTRAP。
private func pushPayloadString(_ value: Any?) -> String {
    guard let value = value else { return "" }
    switch value {
    case let s as String:
        return s
    case let n as Int:
        return String(n)
    case let n as NSNumber:
        return n.stringValue
    case let n as Bool:
        return n ? "1" : "0"
    default:
        return String(describing: value)
    }
}

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
    
    /// 按「设置中心 → 离线通知」的开关（本地 flg）同步一次推送注册状态。
    ///
    /// 为什么需要它：`LoginUser.logout()` 会注销推送，如果不在「重新登录」时补回来，
    /// 用户「退出 → 重新登录」（不重启 App）之后就永远收不到推送，
    /// 而设置页开关读的 flg 没变，看起来还是「已开启」。
    /// 统一入口同时避免了「登录时注册早于 UMConfigure 初始化」的顺序问题。
    func syncPushRegistration() {
        let disabled = FZM_UserDefaults.bool(forKey: CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY)
        if disabled {
            self.umUnregisterForRemoteNotifi()
        } else {
            self.umRegisterForRemoteNotifi()
        }
    }
    
    // 友盟推送配置
//    func umPushConfig(launchOptions: [UIApplication.LaunchOptionsKey: Any]?)  {
    func umPushConfig() {
        // 是否清除角标 默认自动角标清零
        UMessage.setBadgeClear(false)
        
        //开发者需要显式的调用此函数，日志系统才能工作
        UMCommonLogManager.setUp()
        #if DEBUG
        UMConfigure.setLogEnabled(true)//设置打开日志（仅 Debug）
        #else
        UMConfigure.setLogEnabled(false)
        #endif
        UMConfigure.initWithAppkey(UMAPPKEY, channel: "App Store")
        
        // 按「设置中心 → 离线通知」的开关同步一次注册状态
        // （UMConfigure 初始化之后才注册，登录态变化时由 syncPushRegistration 再同步）
        self.syncPushRegistration()
        
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
        
        // token 是异步到的：首次安装时用户要先点「允许通知」，这个时间点往往晚于
        // 登录 + socket 鉴权（那次上送给服务器的 token 是空串）⇒ 服务器只认最近一次
        // 鉴权里的 token，不补一次的话这台设备要等到下次重连才有推送。
        MultipleSocketManager.shared().refreshDeviceTokenForAllSockets()
        
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
        // 前台只弹横幅：
        //  · 这里**不要**再调 handleNotificationCenterUserInfo，否则用户在别的页面用着 App，
        //    来一条推送就被强行推进聊天页（横幅其实已经弹过了）；
        //  · 也不要带 .badge：前台角标由本地未读数统一维护
        //    （SessionManager.updateApplicationIconBadgeNumber），双写会互相冲掉。
        completionHandler([.alert, .sound])
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
        
        // 用户点掉的那条通知从通知栏移除（否则进了会话通知栏里还留着）
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        
        // 收到通知消息处理（只有「点击」才跳转）
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
        
        // 角标不再用 payload 里的 badge 覆盖：
        //  · App 在后台 / 未启动时，系统会直接应用 aps.badge；
        //  · App 在前台 / 点开时，角标由本地未读数统一维护（SessionManager.updateApplicationIconBadgeNumber）。
        // 两边都写会互相对冲（服务器算的未读和本地 DB 算的未读本来就不一定一致）。
        
        var address = ""
        var channelType = ""
        if userInfo.keys.contains("address") {
            address = pushPayloadString(userInfo["address"])
        }
        if userInfo.keys.contains("channelType") {
            channelType = pushPayloadString(userInfo["channelType"])
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
                
            } else {
                // 未知类型（系统通知 / 后续新增的业务通知）：不猜，只留日志，别乱跳页面
                FZMLog("收到推送通知 未知 channelType: \(channelType) address: \(address)")
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        FZMLog("error \(error.localizedDescription)")
    }
}
