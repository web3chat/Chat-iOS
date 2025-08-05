//
//  CommonTools.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/19.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Moya
import KeychainAccess

@_exported import RxCocoa
@_exported import RxSwift
@_exported import SwifterSwift
@_exported import SwiftyJSON
@_exported import Kingfisher


let k_ScreenBounds = UIScreen.main.bounds
let k_ScreenWidth = k_ScreenBounds.width
let k_ScreenHeight = k_ScreenBounds.height
//let k_StatusBarSize = UIApplication.shared.statusBarFrame.size
var k_StatusBarSize = getStatusBarSize()
let k_StatusBarWidth = max(k_StatusBarSize.width, k_StatusBarSize.height)
/**状态栏高度*/
let k_StatusBarHeight = min(k_StatusBarSize.width, k_StatusBarSize.height)
/**导航栏高度*/
let k_NavigationBarHeight : CGFloat = 44.0
/**状态栏和导航栏总高度*/
let k_StatusNavigationBarHeight = k_StatusBarHeight + k_NavigationBarHeight
/**是否为刘海屏**/
let k_IsIphoneXseries = k_StatusBarHeight > 20 ? true : false
/**TabBar高度*/
let k_TabBarHeight: CGFloat = k_IsIphoneXseries ? 83.0 : 49.0
/**顶部安全区域远离高度*/
let k_SafeTopInset: CGFloat = k_IsIphoneXseries ? k_StatusBarHeight : 20.0
/**底部安全区域远离高度*/
let k_SafeBottomInset: CGFloat = k_IsIphoneXseries ? 34 : 0

///动态取状态栏的高度
private func getStatusBarSize() -> CGSize {
    var statusBarSize: CGSize = .zero
    if #available(iOS 13.0, *) {
        let statusBarManager = UIApplication.shared.windows.first?.windowScene?.statusBarManager
        statusBarSize = statusBarManager?.statusBarFrame.size ?? .zero
    } else  {
        statusBarSize = UIApplication.shared.statusBarFrame.size
    }
    return statusBarSize
}

/// 获取当前构建版本号
let k_APPVersion = getAppVersion()

/// 获取设备名称
let k_DeviceName = UIDevice.current.name

private func getAppVersion() -> String {
//    #if DEBUG
//    if let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
//        return version
//    }
//    #else
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        return version
    }
//    #endif
    return ""
}

/// 设备唯一UUID
let k_DeviceUUID = getDeviceUUID()

private func getDeviceUUID() -> String {
    let uuid = try? Keychain.init().getString("LocalStaticDeviceUUID")
    let deviceUUID: String = uuid ?? UUID.init().uuidString
    if let _ = uuid {
        
    } else {
        try? Keychain.init().set(deviceUUID, key: "LocalStaticDeviceUUID")
    }
    return deviceUUID
}

var DocumentDirectory: URL {
     try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
}

//时间
let k_OnedaySeconds: Double = 60.0 * 60.0 * 24
let k_ForverBannedTime: Int = 9223372036854775807// 永久禁言时间

let DocumentPath = NSHomeDirectory() + "/Documents/"
let CachesPath = NSHomeDirectory() + "/Caches/"



//MARK: ---- NotificationCenter ----
let FZM_NotificationCenter = NotificationCenter.default
let FZM_Notify_UserLogin = NSNotification.Name(rawValue: "FZM_Notify_UserLogin")// 登录
let FZM_Notify_UserLogout = NSNotification.Name(rawValue: "FZM_Notify_UserLogout")// 登出
let FZM_Notify_SessionInfoChanged = Notification.Name.init("FZM_Notify_SessionInfoChanged")// 会话免打扰、置顶状态变化通知
let FZM_Notify_InTeamStatusChanged = NSNotification.Name(rawValue: "FZM_Notify_InTeamStatusChanged")// 在/解散/退出团队通知
let FZM_Notify_GroupDetailInfoChanged = Notification.Name.init("FZM_Notify_GroupDetailInfoChanged")// 群详情信息变化通知（备注名、免打扰状态、群名、群头像等）
let FZM_Notify_GroupDelete = Notification.Name.init("FZM_Notify_GroupDelete")// 退出群聊通知（删群）
let FZM_Notify_GroupSignout = Notification.Name.init("FZM_Notify_GroupSignout")// 退出群聊通知（被踢出群）
let FZM_Notify_GroupSignin = Notification.Name.init("FZM_Notify_GroupSignin")// 加入群聊通知（被拉进群）
let FZM_Notify_RefreshUserInfo = Notification.Name.init("FZM_Notify_RefreshUserInfo")// 刷新了用户信息

let FZM_Notify_DeleteChatMsgs = Notification.Name.init("FZM_Notify_DeleteChatMsgs")// 删除聊天页面数据通知（文件管理页面删除文件发出此通知）

let FZM_Notify_File_UploadFile = NSNotification.Name(rawValue: "FZM_Notify_File_UploadFile")
let FZM_Notify_BannedGroup = NSNotification.Name(rawValue: "FZM_Notify_BannedGroup")

let FZM_Notify_ShowQRCodeView = NSNotification.Name(rawValue: "FZM_Notify_ShowQRCodeView")// 首页展示/隐藏顶部二维码视图通知



//MARK: ---- UserDefaults ----
let FZM_UserDefaults = UserDefaults.standard
let CHAT33PRO_USER_SHOW_WALLET_KEY = "CHAT33PRO_USER_SHOW_WALLET_KEY"
let CHAT33PRO_SHOW_UPDATE_KEY = "CHAT33PRO_SHOW_UPDATE_KEY"//审核状态flg
let CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY = "CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY"//友盟推送关闭flg




//MARK: ---- Block ----
typealias NormalBlock = ()->()
typealias StringBlock = (String)->()
typealias StringArrayBlock = ([String])->()
typealias BoolBlock = (Bool)->()
typealias IntBlock = (Int)->()
typealias FloatBlock = (Float)->()
typealias DoubleBlock = (Double)->()
typealias ImageBlock = (UIImage)->()
typealias OptionImageBlock = (UIImage?)->()
typealias ImageListBlock = ([UIImage])->()
typealias ImageAndVideoListBlock = ([UIImage],[PHAsset]?)->()
typealias StringBoolBlock = (String,Bool)->()
typealias IcloudFileBlock = ([URL])->()
typealias FailureBlock = (Error) -> ()

typealias JSCallbackBlock = (String, Bool)->Void
typealias JSArrayCallbackBlock = ([String], Bool)->Void



// MARK: - Top level function
/**
 格式化LOG
 
 - parameter items:  输出内容
 - parameter file:   所在文件
 - parameter method: 所在方法
 - parameter line:   所在行
 */
func FZMLog(_ items: Any... ,
    file: String = #file,
    method: String = #function,
    line: Int = #line) {
    #if DEBUG
    let formatter = DateFormatter.getDataformatter()
    formatter.dateFormat = "yyyy-MM-dd hh:mm:ss.SSS"
    var itemStr = ""
    for item in items {
        if let str = item as? String {
            itemStr += str
        } else {
            itemStr += "\(item)"
        }
    }
    var string = "-------------------------- IMLog --------------------------\n"
    string += "[" + formatter.string(from: Date()) + "]"
    string += " <" + (file as NSString).lastPathComponent + ":" + method + "  inLine:\(line)>\n"
    string += itemStr
    print(string)
    #endif
}

