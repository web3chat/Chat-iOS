//
//  GroupMember.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/20.
//  /app/group-member-info 查询群成员信息

import UIKit

struct GroupMember {
    let memberId: String
    var memberMuteTime: Int// 该用户被禁言结束的时间 9223372036854775807=永久禁言
    var memberName: String? = ""// 用户群昵称
    var memberType: Int// 用户角色，2=群主，1=管理员，0=群员，10=退群
    var groupId: Int
    
    var user: User? {
        return UserManager.shared().user(by: memberId)
    }
}

extension GroupMember {
    init(json: JSON, groupId: Int) {
        self.memberId = json["memberId"].stringValue
        self.memberMuteTime = json["memberMuteTime"].intValue
        self.memberName = json["memberName"].stringValue
        self.memberType = json["memberType"].intValue
        self.groupId = groupId
    }
}

extension GroupMember: Contacts {
    /// 普通用户详情页： 备注>昵称>地址(显示前后各四位)
    /// 从群进入用户详情页： 备注>群昵称>昵称>地址(显示前后各四位)
    /// 群列表显示： 备注>群昵称>团队姓名>昵称>地址(显示前后各四位)
    var contactsName: String {
        guard let alias = self.user?.alias, !alias.isBlank else {
            guard let name = memberName, !name.isBlank else {
                let staffName = TeamManager.shared().getDBStaffName(address: self.memberId)
                guard !staffName.isBlank else {
                    guard let nickname = self.user?.nickname, !nickname.isBlank else {
                        return self.memberId.shortAddress
                    }
                    return nickname
                }
                return staffName
            }
            return name
        }
        return alias
    }
    
    /// 群 @谁 显示： 群昵称>昵称>地址(显示前后各四位)
    var atName: String {
        guard let name = memberName, !name.isBlank else {
            guard let nickname = self.user?.nickname, !nickname.isBlank else {
                return self.memberId.shortAddress
            }
            return nickname
        }
        return name
    }
    
    var avatarURLStr: String {
        return user?.avatarURLStr ?? ""
    }
    
    var sessionID: SessionID {
        return SessionID.person(self.memberId)
    }
}

extension GroupMember: Equatable {
    static func == (lhs: GroupMember, rhs: GroupMember) -> Bool {
        return lhs.memberId == rhs.memberId && lhs.memberName == rhs.memberName && lhs.memberType == rhs.memberType && lhs.memberMuteTime == rhs.memberMuteTime && lhs.groupId == rhs.groupId
    }
}

extension GroupMember: Codable {
    private enum CodingKeys: CodingKey {
        case memberId, memberMuteTime, memberName, memberType, groupId
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(memberMuteTime, forKey: .memberMuteTime)
        try container.encode(memberName, forKey: .memberName)
        try container.encode(memberType, forKey: .memberType)
        try container.encode(groupId, forKey: .groupId)
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.memberId = try container.decode(String.self, forKey: .memberId)
        self.memberMuteTime = try container.decode(Int.self, forKey: .memberMuteTime)
        self.memberName = try container.decode(String.self, forKey: .memberName)
        self.memberType = try container.decode(Int.self, forKey: .memberType)
        self.groupId = try container.decode(Int.self, forKey: .groupId)
    }
}
