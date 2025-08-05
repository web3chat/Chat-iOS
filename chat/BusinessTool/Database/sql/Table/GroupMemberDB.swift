//
//  GroupMemberDB.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/25.
//

import UIKit

import Foundation
import WCDBSwift

final class GroupMemberDB: TableCodable {
    
    var id: Int?
    let memberId: String
    let memberMuteTime: Int
    let memberName: String?
    let memberType: Int
    let groupId: Int
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = GroupMemberDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case id, memberId, memberMuteTime, memberName, memberType, groupId
        
        static var columnConstraintBindings: [GroupMemberDB.CodingKeys : ColumnConstraintBinding]? {
            // 自增主键的设置
            return [
                id: ColumnConstraintBinding.init(isPrimary: true, isAutoIncrement: true)
            ]
        }
        
        // 索引是 TableEncodable 的一个可选函数，可根据需求选择实现或不实现。它用于定于针对单个或多个字段的索引，索引后的数据在能有更高的查询效率
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return [
                "memberId": IndexBinding.init(indexesBy: memberId),
                "groupId": IndexBinding.init(indexesBy: groupId)
            ]
        }
        
    }
    
    init(with groupMember: GroupMember) {
        self.memberId = groupMember.memberId
        self.memberMuteTime = groupMember.memberMuteTime
        self.memberName = groupMember.memberName
        self.memberType = groupMember.memberType
        self.groupId = groupMember.groupId
    }
    
}

extension GroupMember {
    init(with groupMemberTable: GroupMemberDB) {
        self.memberId = groupMemberTable.memberId
        self.memberMuteTime = groupMemberTable.memberMuteTime
        self.memberName = groupMemberTable.memberName
        self.memberType = groupMemberTable.memberType
        self.groupId = groupMemberTable.groupId
    }
}
