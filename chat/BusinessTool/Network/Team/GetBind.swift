//
//  GetBind.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/12.
//  /v1/account/get-bind 获取绑定信息

import Foundation

struct GetBind {
    var personalUid: String// 个人账户地址
    var accountInfo: AccountInfo// 公司账户
}

extension GetBind {
    init(json: JSON) {
        self.personalUid = json["personalUid"].stringValue
        self.accountInfo = AccountInfo.init(json: json["accountInfo"])
    }
}

// 公司账户
struct AccountInfo {
    let mnemonic: String// 助记词
    var privateKey: String// 私钥
    var uid: String// 地址
}

extension AccountInfo {
    init(json: JSON) {
        self.mnemonic = json["mnemonic"].stringValue
        self.privateKey = json["privateKey"].stringValue
        self.uid = json["uid"].stringValue
    }
}
