//
//  Group.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/23.
//

import Foundation
import SwiftyJSON
import sqlcipher

struct Group {
    var adminNum: Int?// 群内管理员数量
    var avatar: String?// 头像url
    var createTime: Int// 群创建时间
    var friendType: Int// 加好友限制， 0=群内可加好友，1=群内禁止加好友
    var groupType: Int// 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
    var id: Int// 群ID
    var idStr: String?// id为必填, 如果同时填了 idStr, 则优先选择 idStr
    var introduce: String?
    var joinType: Int// 加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群 2=需要审批
    var markId: String?
    var maximum: Int// 群人数上限
    var memberNum: Int// 群人数
    var members: Array<GroupMember>?
    var muteNum: Int// 群内当前被禁言的人数
    var muteType: Int// 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    var name: String// 群名称（加密群名）
    var owner: GroupMember// 群主信息
    var person: GroupMember?// 自己在群里的信息
    var status: Int// 群状态，0=正常 1=封禁 2=解散
    var key: String?// 加密私钥
    var publicName: String// 公开群名(不加密)
    
    var address: String {// 会话session用的标识
        return self.id.string
    }
    
    var chatServerUrl: String?// 群服务器地址
    
    var isOnTop = false// 是否置顶
    var isMuteNotification = false// 是否免打扰
    
    var isInGroup = true// 自己是否还在群
    
    var isSelected = false//wjhTODO
}

extension Group {
    init(json: JSON, isIncludeAdminNum: Bool = true, isIncludeMembers: Bool = true, isIncludePersion: Bool = true, isIncludeKey: Bool = true) {
        if isIncludeAdminNum {
            self.adminNum = json["adminNum"].intValue
        }
        self.avatar = json["avatar"].stringValue
        self.createTime = json["createTime"].intValue
        self.friendType = json["friendType"].intValue
        self.groupType = json["groupType"].intValue
        let groupId = json["id"].intValue
        self.id = groupId
        self.idStr = json["idStr"].stringValue
        self.introduce = json["introduce"].stringValue
        self.joinType = json["joinType"].intValue
        self.markId = json["markId"].stringValue
        self.maximum = json["maximum"].intValue
        self.memberNum = json["memberNum"].intValue
        if isIncludeMembers {
            self.members = json["members"].arrayValue.compactMap { GroupMember.init(json: $0, groupId: groupId) }
        }
        self.muteNum = json["muteNum"].intValue
        self.muteType = json["muteType"].intValue
        let privateName = json["name"].stringValue
        self.owner = GroupMember.init(json: json["owner"], groupId: groupId)
        if isIncludePersion {
            self.person = GroupMember.init(json: json["person"], groupId: groupId)
        }
        self.status = json["status"].intValue
        if isIncludeKey {
            let groupKey = json["key"].stringValue
            self.key = groupKey
            self.name = EncryptManager.decryptGroupName(privateName, key: groupKey)
        } else {
            self.name = privateName
        }
        self.publicName = json["publicName"].stringValue
    }
}

extension Group: Equatable {
    static func == (lhs: Group, rhs: Group) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Group: Codable {
    private enum CodingKeys: CodingKey {
        case adminNum, avatar, createTime, friendType, groupType, id, idStr, introduce, joinType, markId, maximum, memberNum, members, muteNum, muteType, name, owner, person, status, key, publicName
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(adminNum, forKey: .adminNum)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(createTime, forKey: .createTime)
        try container.encode(friendType, forKey: .friendType)
        try container.encode(groupType, forKey: .groupType)
        try container.encode(id, forKey: .id)
        try container.encode(idStr, forKey: .idStr)
        try container.encode(introduce, forKey: .introduce)
        try container.encode(joinType, forKey: .joinType)
        try container.encode(markId, forKey: .markId)
        try container.encode(maximum, forKey: .maximum)
        try container.encode(memberNum, forKey: .memberNum)
        try container.encode(members, forKey: .members)
        try container.encode(muteNum, forKey: .muteNum)
        try container.encode(muteType, forKey: .muteType)
        try container.encode(name, forKey: .name)
        try container.encode(owner, forKey: .owner)
        try container.encode(person, forKey: .person)
        try container.encode(status, forKey: .status)
        try container.encode(key, forKey: .key)
        try container.encode(publicName, forKey: .publicName)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.adminNum = try container.decode(Int.self, forKey: .adminNum)
        self.avatar = try container.decode(String.self, forKey: .avatar)
        self.createTime = try container.decode(Int.self, forKey: .createTime)
        self.friendType = try container.decode(Int.self, forKey: .friendType)
        self.groupType = try container.decode(Int.self, forKey: .groupType)
        self.id = try container.decode(Int.self, forKey: .id)
        self.idStr = try container.decode(String.self, forKey: .idStr)
        self.introduce = try container.decode(String.self, forKey: .introduce)
        self.joinType = try container.decode(Int.self, forKey: .joinType)
        self.markId = try container.decode(String.self, forKey: .markId)
        self.maximum = try container.decode(Int.self, forKey: .maximum)
        self.memberNum = try container.decode(Int.self, forKey: .memberNum)
        self.members = try container.decode(Array.self, forKey: .members)
        self.muteNum = try container.decode(Int.self, forKey: .muteNum)
        self.muteType = try container.decode(Int.self, forKey: .muteType)
        self.name = try container.decode(String.self, forKey: .name)
        self.owner = try container.decode(GroupMember.self, forKey: .owner)
        self.person = try container.decode(GroupMember.self, forKey: .person)
        self.status = try container.decode(Int.self, forKey: .status)
        self.key = try container.decode(String.self, forKey: .key)
        self.publicName = try container.decode(String.self, forKey: .publicName)
    }
}

extension Group: Contacts {
    var sessionID: SessionID {
        return SessionID.group(self.id.string)
    }
    
    var contactsName: String {
        guard !name.isBlank else {
            guard !publicName.isBlank else {
                guard let memberName = self.owner.memberName, !memberName.isBlank else {
                    return self.owner.memberId.shortAddress
                }
                return memberName
            }
            return publicName
        }
        return name
    }
    
    var avatarURLStr: String {
        return self.avatar ?? ""
    }
}
