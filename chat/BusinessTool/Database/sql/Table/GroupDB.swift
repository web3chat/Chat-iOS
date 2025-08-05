//
//  GroupDB.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/25.
//

import UIKit

import Foundation
import WCDBSwift

final class GroupDB: TableCodable {
    
    let adminNum: Int?// 群内管理员数量
    var avatar: String?// 头像url
    let createTime: Int// 群创建时间
    let friendType: Int// 加好友限制， 0=群内可加好友，1=群内禁止加好友
    let groupType: Int// 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
    let id: Int// 群ID
    let idStr: String?// id为必填, 如果同时填了 idStr, 则优先选择 idStr
    var introduce: String?
    let joinType: Int// 加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群
    let markId: String?
    let maximum: Int// 群人数上限
    let memberNum: Int// 群人数
    let muteNum: Int// 群内当前被禁言的人数
    let muteType: Int// 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    let name: String// 群名称（加密）
    let owner: String// 群主信息 转为json字符串
    var person: String?// 自己在群里的信息 转为json字符串
    let status: Int// 群状态，0=正常 1=封禁 2=解散
    var key: String?// 加密秘钥
    let publicName: String// 公开群名（不加密）
    
    let chatServerUrl: String?// 群服务器地址
    
    var isOnTop = false// 是否置顶
    var isMuteNotification = false// 是否免打扰
    
    var isInGroup = true// 自己是否还在群
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = GroupDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case adminNum, avatar, createTime, friendType, groupType, id, idStr, introduce, joinType, markId, maximum, memberNum, muteNum, muteType, name, owner, person, status, isOnTop, isMuteNotification, chatServerUrl, isInGroup, key, publicName
        
        static var columnConstraintBindings: [GroupDB.CodingKeys : ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding.init(isPrimary: true)
            ]
        }
        
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return [
                "id": IndexBinding.init(indexesBy: id),
                "chatServerUrl": IndexBinding.init(indexesBy: chatServerUrl)
            ]
        }
    }
    
    init(with group: Group) {
        self.adminNum = group.adminNum
        self.avatar = group.avatar
        self.createTime = group.createTime
        self.friendType = group.friendType
        self.groupType = group.groupType
        self.id = group.id
        self.idStr = group.idStr
        self.introduce = group.introduce
        self.joinType = group.joinType
        self.markId = group.markId
        self.maximum = group.maximum
        self.memberNum = group.memberNum
        self.muteNum = group.muteNum
        self.muteType = group.muteType
        self.name = group.name
        self.owner = ["groupId":String(group.owner.groupId), "memberMuteTime":String(group.owner.memberMuteTime), "memberType":String(group.owner.memberType), "memberId":group.owner.memberId, "memberName":group.owner.memberName ?? ""].jsonString() ?? ""
        
        if let personItem = group.person {
            self.person = ["groupId":String(personItem.groupId), "memberMuteTime":String(personItem.memberMuteTime), "memberType":String(personItem.memberType), "memberId":personItem.memberId, "memberName":personItem.memberName ?? ""].jsonString()
        }
        self.status = group.status
        self.isOnTop = group.isOnTop
        self.isMuteNotification = group.isMuteNotification
        self.chatServerUrl = group.chatServerUrl ?? ""
        self.isInGroup = group.isInGroup
        self.key = group.key
        self.publicName = group.publicName
    }
}

extension Group {
    init(with groupTable: GroupDB) {
        self.adminNum = groupTable.adminNum
        self.avatar = groupTable.avatar
        self.createTime = groupTable.createTime
        self.friendType = groupTable.friendType
        self.groupType = groupTable.groupType
        self.id = groupTable.id
        self.idStr = groupTable.idStr
        self.introduce = groupTable.introduce
        self.joinType = groupTable.joinType
        self.markId = groupTable.markId
        self.maximum = groupTable.maximum
        self.memberNum = groupTable.memberNum
        self.muteNum = groupTable.muteNum
        self.muteType = groupTable.muteType
        self.name = groupTable.name
        let ownerDic = groupTable.owner.toDictionary()
        self.owner = GroupMember.init(memberId: ownerDic["memberId"] as! String, memberMuteTime: (ownerDic["memberMuteTime"] as! String).intEncoded, memberName: (ownerDic["memberName"] as! String), memberType: (ownerDic["memberType"]! as! String).intEncoded, groupId: (ownerDic["groupId"] as! String).intEncoded)
        if let personDic = groupTable.person?.toDictionary() {
            self.person = GroupMember.init(memberId: personDic["memberId"] as! String, memberMuteTime: (personDic["memberMuteTime"] as! String).intEncoded, memberName: (personDic["memberName"] as! String), memberType: (personDic["memberType"]! as! String).intEncoded, groupId: (personDic["groupId"] as! String).intEncoded)
        }
        self.status = groupTable.status
        self.isOnTop = groupTable.isOnTop
        self.isMuteNotification = groupTable.isMuteNotification
        self.chatServerUrl = groupTable.chatServerUrl
        self.isInGroup = groupTable.isInGroup
        self.key = groupTable.key
        self.publicName = groupTable.publicName
    }
}
