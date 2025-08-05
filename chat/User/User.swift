//
//  User.swift
//  chat
//
//  Created by 陈健 on 2021/1/14.
//

import Foundation
import SwiftyJSON

struct User {
    let address: String
    var publicKey: String?
    var chatServers = [String]()
    var chatServerGroups = [UserChatServerGroup]()
    var imageURLStr: String?
    var nickname: String?
    var phone: String?
    var realname: String?
    var bnbAddr:String?
    var ethAddr:String?
    var btyAddr:String?
    var createTime = Date.timestamp
    var groups = [String]()
    var stafInfo: StaffInfo? {
        return TeamManager.shared().getDBStaffInfo(address: address)
    }
    
    var alias: String?// 备注名（本地）
    
    var isOnTop = false//是否置顶（本地）
    var isMuteNotification = false// 是否免打扰（本地）
    
    var isFriend = false// 是否为好友标识（本地）
    var isShield = false// 是否为黑名单用户标识（本地）
    
    
    
    init(address: String) {
        self.address = address
    }
    
    // 解析获取用户信息接口返回json
    init(user address: String, json: JSON) {
        self.address = address
        
        let groups = json["groups"].arrayValue.compactMap { $0.stringValue }
        let chatServers = json["chatServers"].arrayValue.compactMap { UserChatServer.init(json: $0) }
        let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
        
        for field in fields {
            if case .nickname = field.name {
                self.nickname =  field.value
            }
            if case .phone = field.name {
                self.phone =  field.value
            }
            if case .avatar = field.name {
                self.imageURLStr = field.value
            }
            if case .pubKey = field.name {
                self.publicKey = field.value
            }
            if case .ETH = field.name{
                self.ethAddr = field.value
            }
            if case .BNB = field.name{
                self.bnbAddr = field.value
            }
            if case .BTY = field.name{
                self.btyAddr = field.value
            }
        }
        
        self.chatServerGroups = chatServers.compactMap { UserChatServerGroup.init(userchatServer: $0) }
        let servers = chatServers.compactMap { $0.address }
        self.chatServers = servers
        
        self.groups = groups
    }
    
    // 解析获取好友信息接口返回json
    init(friend json: JSON) {
        self.address = json["friendAddress"].stringValue
        self.createTime = json["createTime"].intValue
        self.groups = json["groups"].arrayValue.compactMap({ $0.string })
       
        self.isFriend = true
    }
    
    // 解析获取黑名单用户信息接口返回json
    init(shieldUser json: JSON) {
        self.address = json["targetAddress"].stringValue
        self.createTime = json["createTime"].intValue
        self.isShield = true
    }
}

extension User: Contacts {
    var sessionID: SessionID {
        return SessionID.person(self.address)
    }
    
    /// 普通用户详情页： 备注>昵称>地址(显示前后各四位)
    /// 从群进入用户详情页： 备注>群昵称>昵称>地址(显示前后各四位)
    /// 列表显示： 备注>团队姓名>昵称>地址(显示前后各四位)
    var contactsName: String {
        guard let alias = self.alias, !alias.isBlank else {
            let staffName = TeamManager.shared().getDBStaffName(address: self.address)
            guard !staffName.isBlank else {
                guard let nickname = self.nickname, !nickname.isBlank else {
                    return self.address.shortAddress
                }
                return nickname
            }
            return staffName
        }
        return alias
    }
    
    // 用户详情页显示名称 备注>昵称>地址
    var aliasName: String {
        guard let alias = self.alias, !alias.isBlank else {
            guard let nickname = self.nickname, !nickname.isBlank else {
                return self.address.shortAddress
            }
            return nickname
        }
        return alias
    }
    
    var avatarURLStr: String {
        return self.imageURLStr ?? ""
    }
}
