//
//  UserDB.swift
//  chat
//
//  Created by 陈健 on 2021/1/14.
//

import UIKit

import Foundation
import WCDBSwift

final class UserDB: TableCodable {
    
    let publicKey: String
    let address: String
    let chatServers: [String]
    let imageURLStr: String
    let nickname: String
    let phone: String
    
    let createTime: Int
    let groups: [String]
    let alias: String
    let isOnTop: Bool
    let isMuteNotification: Bool
    
    let isFriend: Bool
    let isShield: Bool
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = UserDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case publicKey, address, imageURLStr, nickname, phone, chatServers, createTime, groups, alias, isOnTop, isMuteNotification, isFriend, isShield
        
        // 自增主键的设置
        static var columnConstraintBindings: [UserDB.CodingKeys : ColumnConstraintBinding]? {
            return [
                address: ColumnConstraintBinding.init(isPrimary: true)
            ]
        }
        
        // 索引是 TableEncodable 的一个可选函数，可根据需求选择实现或不实现。它用于定于针对单个或多个字段的索引，索引后的数据在能有更高的查询效率
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return [
                "publicKey": IndexBinding.init(indexesBy: publicKey),
                "address": IndexBinding.init(indexesBy: address),
                "isFriend": IndexBinding.init(indexesBy: isFriend),
                "isShield": IndexBinding.init(indexesBy: isShield)
            ]
        }
    }
    
    init(with user: User) {
        self.publicKey = user.publicKey ?? ""
        self.address = user.address
        self.chatServers = user.chatServers
        self.imageURLStr = user.imageURLStr ?? ""
        self.nickname = user.nickname ?? ""
        self.phone = user.phone ?? ""
        self.createTime = user.createTime
        self.groups = user.groups
        self.alias = user.alias ?? ""
        self.isOnTop = user.isOnTop
        self.isMuteNotification = user.isMuteNotification
        self.isFriend = user.isFriend
        self.isShield = user.isShield
    }
}

extension User {
    init(with userTable: UserDB) {
        self.publicKey = userTable.publicKey
        self.address = userTable.address
        self.chatServers = userTable.chatServers
        self.imageURLStr = userTable.imageURLStr
        self.nickname = userTable.nickname
        self.phone = userTable.phone
        self.createTime = userTable.createTime
        self.groups = userTable.groups
        self.alias = userTable.alias
        self.isOnTop = userTable.isOnTop
        self.isMuteNotification = userTable.isMuteNotification
        self.isFriend = userTable.isFriend
        self.isShield = userTable.isShield
    }
}

