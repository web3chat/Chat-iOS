//
//  CommonTools.swift
//  Chat33
//
//  Created by fzm on 2018/9/19.
//  Copyright © 2018年 fzm. All rights reserved.
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

/// 聊天媒体（消息图片 / 视频封面 / 引用图 / 阅后即焚图）**专用**的图片缓存。
///
/// 为什么要和 `ImageCache.default` 分开：
/// · `ImageCache.default` 里放的是广场图、头像、分享卡片等「可再生、清了也没关系」的图；
/// · 聊天图片是**消息的一部分**，用户不会认为「清理缓存」应该把它清掉
///   （清了只能重新下载，万一本地消息体里的 url 丢了就彻底看不到）。
/// 所以：**「清理缓存」只清 `ImageCache.default`，不动这里**；
/// 聊天媒体的清理统一走「聊天记录 / 单个会话」的清理入口（`FZMStorageManager.clearMedia`）。
let ChatMediaCache = ImageCache(name: "chatMedia")

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
    // 文件系统异常时 `try!` 会直接闪退；失败回退到沙盒下的 Documents
    if let url = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
        return url
    }
    FZMLog("获取 Documents 目录失败，回退到 NSHomeDirectory/Documents")
    return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
}

//时间
let k_OnedaySeconds: Double = 60.0 * 60.0 * 24
let k_ForverBannedTime: Int = 9223372036854775807// 永久禁言时间

let DocumentPath = NSHomeDirectory() + "/Documents/"
let CachesPath = NSHomeDirectory() + "/Caches/"



//MARK: ---- NotificationCenter ----
let FZM_NotificationCenter = NotificationCenter.default

/// 聊天记录删除新功能开关（手动删除 + 自动删除 + 服务端同步删除）
/// 已按对接文档接入：手动删除 /app/record/clean-private、自动删除 /app/record/auto-delete/set·get
let FZM_EnableChatDeleteFeature = true

/// 多语言切换入口开关（设置中心显示"多语言"行）
/// 已开放：设置中心显示"多语言"行，进入后可切换 简体中文 / English
let FZM_EnableMultiLanguage = true

/// **面容/指纹替代密聊密码 总开关（一键隐藏入口）**
/// - `false`：设置中心不显示该入口，且所有需要密聊密码的地方一律退回手输密码（功能代码保留）
/// - 绑定关系 =（本机生物识别 ↔ 登录账号 ↔ 密聊密码），只存本机 Keychain（生物识别 ACL），
///   不写服务器、不进 iCloud、不同步其它设备；切换账号仍必须手输密码
let FZM_EnableBiometricUnlock = true

/// **企业号（团队 / 员工 / 企业信息）相关功能总开关**
/// 当前没有员工信息、也不需要这些接口：
///   - 入口/内容：改成 false 后，团队与员工相关的界面会自动隐藏（数据层不再赋值）
///   - 接口：TeamAPI / 员工、企业信息、团队 H5 等请求全部不再发出
/// 后续要开启：把这里改成 true 即可（相关代码一行未删，开关打开就恢复原行为）
let FZM_EnableEnterpriseFeature = false

/// **分享卡片样式开关（AI 客服 / 商城 H5 分享）**
/// - `true`：聊天气泡渲染成「图标 + 标题 + 摘要 + 来源」卡片（2026-10-30 起的样式）
/// - `false`：气泡显示**之前的文本版式**
///   ```
///   来自X的分享
///   「标题
///   摘要
///   https://…
///   来源：xxx」
///   ```
/// 发送正文也受它控制：关闭时发文本版式（老版本 App / 其它端收到也能正常显示，不会看到原始 JSON）。
/// 被历史 JSON 消息兼容：关闭时仍能解析成上面的文本，不会把 `{"t":…}` 直接露出来。
let FZM_EnableShareLinkCard = false

/// **省图模式（图片缓存瘦身）开关**
/// - `false`（当前）：保持原策略 —— 图片缓存**永不过期、不限量**，聊天图额外存一份原图
///   （点开大图不用重新下载，但缓存会一直长；实测 App 本体 135M、总占用 1.35G）
/// - `true`：开启省图模式
///   ① Kingfisher 磁盘缓存 30 天过期 + 400MB 上限（超了按 LRU 淘汰）
///   ② SDWebImage 磁盘缓存 7 天过期 + 200MB 上限
///   ③ 存图时直接保存原始压缩字节，不让 Kingfisher 把 2048px 解码图重新编码写盘
///   ④ 聊天气泡只存 150pt 缩略图（去掉 `.cacheOriginalImage`）
///   ⇒ 同样数量的图体积约为原来的 1/5～1/10；代价是点开大图需要重新下载一次
let FZM_EnableImageSaveMode = false
let FZM_Notify_UserLogin = NSNotification.Name(rawValue: "FZM_Notify_UserLogin")// 登录
let FZM_Notify_UserLogout = NSNotification.Name(rawValue: "FZM_Notify_UserLogout")// 登出
let FZM_Notify_SessionInfoChanged = Notification.Name.init("FZM_Notify_SessionInfoChanged")// 会话免打扰、置顶状态变化通知
let FZM_Notify_InTeamStatusChanged = NSNotification.Name(rawValue: "FZM_Notify_InTeamStatusChanged")// 在/解散/退出团队通知
let FZM_Notify_GroupDetailInfoChanged = Notification.Name.init("FZM_Notify_GroupDetailInfoChanged")// 群详情信息变化通知（备注名、免打扰状态、群名、群头像等）
let FZM_Notify_GroupDelete = Notification.Name.init("FZM_Notify_GroupDelete")// 退出群聊通知（删群）
let FZM_Notify_GroupSignout = Notification.Name.init("FZM_Notify_GroupSignout")// 退出群聊通知（被踢出群）
let FZM_Notify_GroupSignin = Notification.Name.init("FZM_Notify_GroupSignin")// 加入群聊通知（被拉进群）
let FZM_Notify_RefreshUserInfo = Notification.Name.init("FZM_Notify_RefreshUserInfo")// 刷新了用户信息
let FZM_Notify_RevokeMsg = Notification.Name.init("FZM_Notify_RevokeMsg")// 撤回了一条消息
/// 消息体被回写（图片解密完成 / msgType 变了）后通知聊天页刷新对应气泡。
/// `object` = 更新后的消息 msgId（String）。
let FZM_Notify_ChatMsgContentUpdated = Notification.Name.init("FZM_Notify_ChatMsgContentUpdated")
let FZM_Notify_DeleteMessages = Notification.Name.init("FZM_Notify_DeleteMessages")// 其他设备删除聊天记录同步通知
let FZM_Notify_DeleteChatMsgs = Notification.Name.init("FZM_Notify_DeleteChatMsgs")// 删除聊天页面数据通知（文件管理页面删除文件发出此通知）

/// 离线消息同步状态变化。`object` = 聊天服务器地址（String），`userInfo["inProgress"]` = Bool。
/// 聊天页用它显示/收起「加载中」转圈；**加载完成后**才显示「N 条新消息」。
let FZM_Notify_OfflineSyncStateChanged = Notification.Name.init("FZM_Notify_OfflineSyncStateChanged")

let FZM_Notify_File_UploadFile = NSNotification.Name(rawValue: "FZM_Notify_File_UploadFile")
let FZM_Notify_BannedGroup = NSNotification.Name(rawValue: "FZM_Notify_BannedGroup")

let FZM_Notify_ShowQRCodeView = NSNotification.Name(rawValue: "FZM_Notify_ShowQRCodeView")// 首页展示/隐藏顶部二维码视图通知

/// 页面进出（push 进二级页面 / pop 回 Tab 根页面）⇒ TabBar 上的 AI 客服悬浮球要重新判断显隐。
/// 发送方：`ViewControllerIntercepter`（消息/通讯录/我的这三个 Tab 的导航代理）与
/// `CommonViewController`（资产/发现这两个 Tab 的 OC 基类）。
/// ⚠️ OC 侧取不到这个 Swift 常量，那边写的是**同名字符串字面量**，改名要两边一起改。
let FZM_Notify_FloatingAIVisibilityShouldUpdate = NSNotification.Name(rawValue: "FZM_Notify_FloatingAIVisibilityShouldUpdate")



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

// MARK: - 转账默认币种
extension PWDataBaseManager {
    /// 转账页默认选中的币种：**优先选 0x 地址开头的 BTY**（与发红包页 `FZMCreateLuckyBagVC.loadData`
    /// 的默认规则一致），没有则回退列表第一个。
    /// 只影响「默认选中哪个」，不改变币种列表本身。
    func preferredTransferCoin() -> LocalCoin? {
        let coins = (queryCoinArrayBasedOnSelectedWalletID() as? [LocalCoin]) ?? []
        let preferred = coins.first { coin in
            let type = (coin.coin_type ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let address = (coin.coin_address ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return type == "BTY" && address.hasPrefix("0x")
        }
        return preferred ?? coins.first
    }
}
