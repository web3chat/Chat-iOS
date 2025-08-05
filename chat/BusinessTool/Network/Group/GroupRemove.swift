//
//  GroupRemove.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/20.
//  /app/group-remove 踢人

import UIKit

struct GroupRemove {
    let memberIds: Array<String>// 成功被踢的成员列表
    var memberNum: Int// 群人数
}

extension GroupRemove {
    init(json: JSON) {
        self.memberIds = json["memberId"].arrayValue.compactMap{ $0.stringValue }
        self.memberNum = json["memberNum"].intValue
    }
}

extension GroupRemove: Codable {
    private enum CodingKeys: CodingKey {
        case memberIds, memberNum
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberIds, forKey: .memberIds)
        try container.encode(memberNum, forKey: .memberNum)
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.memberIds = try container.decode(Array.self, forKey: .memberIds)
        self.memberNum = try container.decode(Int.self, forKey: .memberNum)
    }
}
