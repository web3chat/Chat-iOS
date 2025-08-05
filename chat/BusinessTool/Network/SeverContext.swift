//
//  SeverContext.swift
//  xls
//
//  Created by 陈健 on 2020/8/19.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation

///民众版
// App Store下载地址
let APPSTORE_DOWNLOAD_URL = "itms-apps://itunes.apple.com/app/id1563350901"

// 友盟推送appkey
let UMAPPKEY = "606ed2222dfb8509d347b399"

// Bugly appId
let BUGLYID = "2fcfb66dba"

/** 公安版
 // App Store下载地址
 let APPSTORE_DOWNLOAD_URL = "itms-apps://itunes.apple.com/app/id1585954452"

 // 友盟推送appkey
 let UMAPPKEY = "6141cf4a1c91e0671baf6abb"
 */


/**
 民众版：
 chat.3syxin.com   - 中心化服务器地址
 3syxin.com        - 前端
 oa.3syxin.com     - 后端
 
 公安版：
 policechat.3syxin.com - 中心化服务器地址
 police.3syxin.com     - 前端
 policeoa.3syxin.com   - 后端
 */

//#if DEBUG
//
//let BackupURL = ""
//
//// 组织架构
//let TeamH5Url = ""
//
//// OKR地址
//let OKRH5Url = ""
//
//#else


let BackupURL = ""
// 组织架构
let TeamH5Url = ""
// OKR地址
let OKRH5Url = ""



//#endif

let APPNAME = "谈信"
//// 分享地址
let APP_URL = ""
let APP_DOWNLOAD_URL = APP_URL + "/?"

let ShareURL = APP_DOWNLOAD_URL + "uid="
// 用户服务协议
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

//代扣地址
let BlockchainPriKey = ""

var APPDeviceToken = UserDefaultsDB.deviceToken ?? "" {
    didSet {
        UserDefaultsDB.deviceToken = APPDeviceToken
    }
}

// 阿里云
let OSS_End_Point = "https://oss-cn-shanghai.aliyuncs.com"
//let OSS_Access_Key = "LTAIsYXxyH9lztHD"
//let OSS_Access_Secret = "bOI1aHqSwvMxnSwtbFCo8pSq8VkOuy"
let OSS_Buket = "dld-test"
let OSS_AUTH_SERVER = BackupURL + "/oss/get-token"


// 华为云
let OBS_EDN_POINT = "https://obs.cn-east-3.myhuaweicloud.com"
let OBS_BUCKET_NAME = "ccccchy-test"
let OBS_Access_Key = "LTAIsYXxyH9lztHD"
let OBS_Access_Secret = "bOI1aHqSwvMxnSwtbFCo8pSq8VkOuy"
//let OBS_AUTH_TYPE = AuthTypeEnum.OBS
let OBS_AUTH_SERVER: String = BackupURL + "/oss/get-huaweiyun-token"
