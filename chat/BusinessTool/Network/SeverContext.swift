//
//  SeverContext.swift
//  xls
//
//  Created by fzm on 2020/8/19.
//  Copyright © 2020 fzm. All rights reserved.
//

import Foundation

///民众版
// App Store下载地址（Apple 分发链接，非业务服务器）
let APPSTORE_DOWNLOAD_URL = "itms-apps://itunes.apple.com/app/id1563350901"

// 友盟推送 AppKey（第三方配置，见 README「第三方配置需求」）
let UMAPPKEY = ""

// Bugly 崩溃上报 AppId（第三方配置，见 README「第三方配置需求」）
let BUGLYID = ""

// MARK: - 业务服务器（空字符串 = 未配置，见 README「服务器地址配置」）

/// 中心化服务主域名：登录/验证码、好友、群组、系统配置、备份/账号绑定、OSS Token 等。
/// 使用方：TokenAPI / SystemAPI / CodeAPI / DiscoveryAPI / BackupAPI / GroupAPI / XLSTargetType。
let BackupURL = ""

/// 组织架构 H5：创建/加入团队、团队入口、团队管理、成员选择。
let TeamH5Url = ""

/// OKR H5。
let OKRH5Url = ""

/// 语音房 H5：`POST {此地址}/api/v1/room/create` 建房并拼接进房链接。
/// 可被 UserDefaults / Info.plist 的 `VoiceRoomSiteURL` 覆盖。
let VoiceRoomBaseURL = ""

/// 未配置服务器地址时的占位 URL，避免 `URL(string: "")` 为 nil 导致崩溃。
let UNCONFIGURED_SERVER_URL = URL(fileURLWithPath: "")


let APPNAME = "谈信开源"

/// 分享 / 邀请下载页，派生 `APP_DOWNLOAD_URL` / `ShareURL`，需与 Android 端一致。
let APP_URL = ""


let APP_DOWNLOAD_URL = APP_URL + "/?"

let ShareURL = APP_DOWNLOAD_URL + "uid="

/// TestFlight 参与链接：
/// 「分享邀请」页面展示的链接 + 二维码都用它，点击 / 扫码走系统默认浏览器下载。
let TESTFLIGHT_DOWNLOAD_URL = "https://testflight.apple.com/join/eTPe37rR"

// 用户服务协议地址
let USER_SERVER_AGREEMENT_URL: String = ""

let APPID = "dtalk"


/* * * * * * * * * * * * * * * * * * * * */

// 官方的IM服务器地址
var OfficialChatServers = UserDefaultsDB.OfficialIMChatServers {
    didSet {
        UserDefaultsDB.OfficialIMChatServers = OfficialChatServers
    }
}

// 官方的区块链节点服务器地址
var OfficialBlockchainServers = UserDefaultsDB.OfficialBlockchainServers {
    didSet {
        UserDefaultsDB.OfficialBlockchainServers = OfficialBlockchainServers
    }
}

// 当前选择的聊天服务器地址
var IMChatServerInUse = UserDefaultsDB.IMChatServer {
    didSet {
        UserDefaultsDB.IMChatServer = IMChatServerInUse
    }
}


// 当前使用的区块链节点
var BlockchainServerInUse = UserDefaultsDB.blockchainServer {
    didSet {
        UserDefaultsDB.blockchainServer = BlockchainServerInUse
    }
}

// -------------

// 组织架构团队IM聊天服务器
var TeamIMChatServer = UserDefaultsDB.TeamIMChatServer {
    didSet {
        UserDefaultsDB.TeamIMChatServer = TeamIMChatServer
    }
}
// 组织架构团队区块链节点地址
var TeamBlockchainServer = UserDefaultsDB.TeamBlockchainServerUrl {
    didSet {
        UserDefaultsDB.TeamBlockchainServerUrl = TeamBlockchainServer
    }
}

// 企业OA服务器
var TeamOAServerUrl = UserDefaultsDB.TeamServer ?? "" {
    didSet {
        UserDefaultsDB.TeamServer = TeamOAServerUrl
    }
}

// 钱包服务器
var WalletServerUrl = UserDefaultsDB.WalletServer ?? "" {
    didSet {
        UserDefaultsDB.WalletServer = WalletServerUrl
    }
}

/// 是否配置了服务器地址。
/// 备份/聊天/链节点任一地址非空即视为已配置；全部为空时，钱包创建/导入不依赖服务器，可直接进入。
var hasConfiguredServerAddress: Bool {
    let values = [
        BackupURL,
        IMChatServerInUse?.value ?? "",
        BlockchainServerInUse?.value ?? "",
    ]
    return values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/* * * * * * * * * * * * * */

// 创建团队地址
let TeamCreateURL = TeamH5Url + "/team/create-team"

// 加入团队地址
let TeamJoinURL = TeamH5Url + "/team/join-team"

// 组织架构入口
let TeamListURL = TeamH5Url + "/team/team-frame"

// 管理团队
let TeamManagerURL = TeamH5Url + "/team/team-management"

// 团队成员列表
let TeamSelectorURL = TeamH5Url + "/team/selector"


/* * * * * * * * * * * * * */

let BackUpOSSURL = BackupURL + "/oss/upload"


// 广场（Square）后端接口域名
let SquareBaseURL = ""

// 扫码登录（PC 网页版）服务地址：confirm / cancel 均走 /app/qr-login/* 前缀。
let ScanLoginBaseURL = ""

// 代扣地址私钥（敏感配置，生产环境应由服务端保管，见 README「第三方配置需求」）
let BlockchainPriKey = ""
var APPDeviceToken = UserDefaultsDB.deviceToken ?? "" {
    didSet {
        UserDefaultsDB.deviceToken = APPDeviceToken
    }
}

// 阿里云 OSS（endpoint / bucket 非密钥，保持默认；AccessKey 改用服务端 STS 下发）
let OSS_End_Point = "https://oss-cn-shanghai.aliyuncs.com"
let OSS_Buket = "dld-test"
/// OSS 临时凭证由 BackupURL 提供（派生地址）
let OSS_AUTH_SERVER = BackupURL + "/oss/get-token"


// 华为云 OBS（endpoint / bucket 非密钥，保持默认；AK/SK 为第三方密钥，见 README）
let OBS_EDN_POINT = "https://obs.cn-east-3.myhuaweicloud.com"
let OBS_BUCKET_NAME = "ccccchy-test"
/// 华为云 OBS AccessKey（第三方配置）
let OBS_Access_Key = ""
/// 华为云 OBS SecretKey（第三方配置）
let OBS_Access_Secret = ""
let OBS_AUTH_SERVER: String = BackupURL + "/oss/get-huaweiyun-token"
