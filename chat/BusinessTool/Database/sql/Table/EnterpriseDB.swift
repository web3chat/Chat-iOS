//
//  EnterpriseDB.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/23.
//

import UIKit

import Foundation
import WCDBSwift

final class EnterpriseDB: TableCodable {
    let avatar: String //企业头像
    let description: String //企业描述
    let id: String //企业 ID
    let imServer: String //企业 IM 服务器地址
    let name: String //企业名称
    let nodeServer: String //企业区块链服务器地址
    let oaServer: String //企业 OA 服务器地址
    let rootDepId: String //企业根部门 ID
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = EnterpriseDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case avatar //企业头像
        case description //企业描述
        case id //企业 ID
        case imServer //企业 IM 服务器地址
        case name //企业名称
        case nodeServer //企业区块链服务器地址
        case oaServer //企业 OA 服务器地址
        case rootDepId //企业根部门 ID
        
        // 自增主键的设置
        static var columnConstraintBindings: [EnterpriseDB.CodingKeys : ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding.init(isPrimary: true)
            ]
        }
        
        // 索引是 TableEncodable 的一个可选函数，可根据需求选择实现或不实现。它用于定于针对单个或多个字段的索引，索引后的数据在能有更高的查询效率
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return [
                "id": IndexBinding.init(indexesBy: id)
            ]
        }
    }
    
    init(with teamInfo: EnterPriseInfo) {
        self.avatar = teamInfo.avatar //企业头像
        self.description = teamInfo.description //企业描述
        self.id = teamInfo.id //企业 ID
        self.imServer = teamInfo.imServer //企业 IM 服务器地址
        self.name = teamInfo.name //企业名称
        self.nodeServer = teamInfo.nodeServer //企业区块链服务器地址
        self.oaServer = teamInfo.oaServer //企业 OA 服务器地址
        self.rootDepId = teamInfo.rootDepId //企业根部门 ID
    }
}

extension EnterPriseInfo {
    init(with teamInfoTable: EnterpriseDB) {
        self.avatar = teamInfoTable.avatar //企业头像
        self.description = teamInfoTable.description //企业描述
        self.id = teamInfoTable.id //企业 ID
        self.imServer = teamInfoTable.imServer //企业 IM 服务器地址
        self.name = teamInfoTable.name //企业名称
        self.nodeServer = teamInfoTable.nodeServer //企业区块链服务器地址
        self.oaServer = teamInfoTable.oaServer //企业 OA 服务器地址
        self.rootDepId = teamInfoTable.rootDepId //企业根部门 ID
    }
}
