//
//  StaffInfoDB.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/11.
//

import UIKit

import Foundation
import WCDBSwift

final class StaffInfoDB: TableCodable {
    let depId: String// 员工所属部门 ID
    let depName: String// 员工所属部门名称
    let email: String// 员工邮箱
    let entId: String// 员工所属企业 ID
    let entName: String// 员工所属企业名称
    let id: String// 员工 ID
    let joinTime: Int// 员工入职时间
    let leaderId: String// 员工直属领导 ID
    let name: String// 员工姓名
    let phone: String// 员工手机号
    let position: String// 员工职位
    let role: Int// 员工类型 0：团队负责人；1：超级管理员；2:客户管理员；3：普通人员
    let workplace: String// 员工工作地点
    let isActivated: Bool// 该员工是否被激活 false: 未激活, 无法进行聊天; true: 已激活
    let shortPhone: String// 员工手机短号
    let cardViewable: Int// 团队卡片可视范围(0：仅同团队组织可见；1：所有人不可见；2：所有人可见)
    let phoneViewable: Int// 0：仅同团队组织可见；1：所有人不可见；2：所有人可见
    let imServer: String// 企业 IM 服务器地址
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = StaffInfoDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case depId, depName, email, entId, entName, id, joinTime, leaderId, name, phone, position, role, workplace, isActivated, shortPhone, cardViewable, phoneViewable, imServer
        
        // 自增主键的设置
        static var columnConstraintBindings: [StaffInfoDB.CodingKeys : ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding.init(isPrimary: true)
            ]
        }
        
        // 索引是 TableEncodable 的一个可选函数，可根据需求选择实现或不实现。它用于定于针对单个或多个字段的索引，索引后的数据在能有更高的查询效率
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return [
                "id": IndexBinding.init(indexesBy: id),
                "entId": IndexBinding.init(indexesBy: entId)
            ]
        }
    }
    
    init(with staffInfo: StaffInfo) {
        self.depId = staffInfo.depId // 员工所属部门 ID
        self.depName = staffInfo.depName // 员工所属部门名称
        self.email = staffInfo.email // 员工邮箱
        self.entId = staffInfo.entId // 员工所属企业 ID
        self.entName = staffInfo.entName // 员工所属企业名称
        self.id = staffInfo.id // 员工 ID
        self.joinTime = staffInfo.joinTime // 员工入职时间
        self.leaderId = staffInfo.leaderId // 员工直属领导 ID
        self.name = staffInfo.name // 员工姓名
        self.phone = staffInfo.phone // 员工手机号
        self.position = staffInfo.position // 员工职位
        self.role = staffInfo.role // 员工类型 0：团队负责人；1：超级管理员；2:客户管理员；3：普通人员
        self.workplace = staffInfo.workplace // 员工工作地点
        self.isActivated = staffInfo.isActivated// 该员工是否被激活 false: 未激活, 无法进行聊天; true: 已激活
        self.shortPhone = staffInfo.shortPhone// 员工手机短号
        self.cardViewable = staffInfo.cardViewable
        self.phoneViewable = staffInfo.phoneViewable
        self.imServer = staffInfo.imServer
    }
}

extension StaffInfo {
    init(with staffInfoTable: StaffInfoDB) {
        self.depId = staffInfoTable.depId // 员工所属部门 ID
        self.depName = staffInfoTable.depName // 员工所属部门名称
        self.email = staffInfoTable.email // 员工邮箱
        self.entId = staffInfoTable.entId // 员工所属企业 ID
        self.entName = staffInfoTable.entName // 员工所属企业名称
        self.id = staffInfoTable.id // 员工 ID
        self.joinTime = staffInfoTable.joinTime // 员工入职时间
        self.leaderId = staffInfoTable.leaderId // 员工直属领导 ID
        self.name = staffInfoTable.name // 员工姓名
        self.phone = staffInfoTable.phone // 员工手机号
        self.position = staffInfoTable.position // 员工职位
        self.role = staffInfoTable.role // 员工类型 0：团队负责人；1：超级管理员；2:客户管理员；3：普通人员
        self.workplace = staffInfoTable.workplace // 员工工作地点
        self.isActivated = staffInfoTable.isActivated// 该员工是否被激活 false: 未激活, 无法进行聊天; true: 已激活
        self.shortPhone = staffInfoTable.shortPhone// 员工手机短号
        self.cardViewable = staffInfoTable.cardViewable
        self.phoneViewable = staffInfoTable.phoneViewable
        self.imServer = staffInfoTable.imServer
    }
}
