//
//  CreateGroup.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/20.
//  /app/create-group 创建群

import Foundation

struct CreateGroup {
    var avatar: String// 头像url
    var createTime: Int// 群创建时间
    var friendType: Int// 加好友限制， 0=群内可加好友，1=群内禁止加好友
    var id: Int// 群ID
    var idStr: String// id为必填, 如果同时填了 idStr, 则优先选择 idStr
    var introduce: String
    var joinType: Int// 加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群
    var markId: String
    var maximum: Int// 群人数上限
    var memberNum: Int// 群人数
    var members: Array<GroupMember>
    var muteNum: Int// 群内当前被禁言的人数
    var muteType: Int// 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    var name: String// 群名称
    var owner: GroupMember// 群主信息
    var status: Int// 群状态，0=正常 1=封禁 2=解散
}

extension CreateGroup {
    init(json: JSON) {
        self.avatar = json["avatar"].stringValue
        self.createTime = json["createTime"].intValue
        self.friendType = json["friendType"].intValue
        let groupId = json["id"].intValue
        self.id = groupId
        self.idStr = json["idStr"].stringValue
        self.introduce = json["introduce"].stringValue
        self.joinType = json["joinType"].intValue
        self.markId = json["markId"].stringValue
        self.maximum = json["maximum"].intValue
        self.memberNum = json["memberNum"].intValue
        self.members = json["members"].arrayValue.compactMap { GroupMember.init(json: $0, groupId: groupId) }
        self.muteNum = json["muteNum"].intValue
        self.muteType = json["muteType"].intValue
        self.name = json["name"].stringValue
        self.owner = GroupMember.init(json: json["owner"], groupId: groupId)
        self.status = json["status"].intValue
    }
}

extension CreateGroup: Codable {
    private enum CodingKeys: CodingKey {
        case avatar, createTime, friendType, id, idStr, introduce, joinType, markId, maximum, memberNum, members, muteNum, muteType, name, owner, status
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(createTime, forKey: .createTime)
        try container.encode(friendType, forKey: .friendType)
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
        try container.encode(status, forKey: .status)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.avatar = try container.decode(String.self, forKey: .avatar)
        self.createTime = try container.decode(Int.self, forKey: .createTime)
        self.friendType = try container.decode(Int.self, forKey: .friendType)
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
        self.status = try container.decode(Int.self, forKey: .status)
    }
}

