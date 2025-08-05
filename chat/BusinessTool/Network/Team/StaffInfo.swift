//
//  StaffInfo.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/11.
//  /v1/staff/get-staff 获取员工信息

import Foundation

struct StaffInfo {
    var depId: String// 员工所属部门 ID
    var depName: String// 员工所属部门名称
    var email: String// 员工邮箱
    var entId: String// 员工所属企业 ID
    var entName: String// 员工所属企业名称
    var id: String// 员工 ID
    var isActivated: Bool// 该员工是否被激活 false: 未激活, 无法进行聊天; true: 已激活
    var joinTime: Int// 员工入职时间
    var leaderId: String// 员工直属领导 ID
    var name: String// 员工姓名
    var phone: String// 员工手机号
    var position: String// 员工职位
    var role: Int// 员工类型 0：团队负责人；1：超级管理员；2:客户管理员；3：普通人员
    var shortPhone: String// 员工手机短号
    var workplace: String// 员工工作地点
    var cardViewable: Int// 团队卡片可视范围(0：仅同团队组织可见；1：所有人不可见；2：所有人可见)
    var phoneViewable: Int// 0：仅同团队组织可见；1：所有人不可见；2：所有人可见
    var imServer: String// 企业 IM 服务器地址
    
    var company: EnterPriseInfo?
}

extension StaffInfo {
    init(json: JSON) {
        self.isActivated = json["isActivated"].boolValue
        self.depId = json["depId"].stringValue
        self.depName = json["depName"].stringValue
        self.email = json["email"].stringValue
        self.entId = json["entId"].stringValue
        self.entName = json["entName"].stringValue
        self.id = json["id"].stringValue
        self.joinTime = json["joinTime"].intValue
        self.leaderId = json["leaderId"].stringValue
        self.name = json["name"].stringValue
        self.phone = json["phone"].stringValue
        self.position = json["position"].stringValue
        self.role = json["role"].intValue
        self.shortPhone = json["shortPhone"].stringValue
        self.workplace = json["workplace"].stringValue
        self.cardViewable = json["cardViewable"].intValue
        self.phoneViewable = json["phoneViewable"].intValue
        self.imServer = json["imServer"].stringValue
    }
}

extension StaffInfo {
    var pDictionary: [String: Any] {
        var companyDic: [String : Any] = [:]
        if let compDic = company?.pDictionary {
            companyDic = compDic
        }
        return [
            "isActivated": isActivated,
            "depId": depId,
            "depName": depName,
            "email" : email,
            "entId" : entId,
            "entName" : entName,
            "id" : id,
            "joinTime" : joinTime,
            "leaderId" : leaderId,
            "name" : name,
            "phone" : phone,
            "position" : position,
            "role" : role,
            "workplace" : workplace,
            "shortPhone" : shortPhone,
            "company" : companyDic,
            "cardViewable" : cardViewable,
            "phoneViewable" : phoneViewable,
            "imServer" : imServer
        ]
    }
}

extension StaffInfo: Codable {
    private enum CodingKeys: CodingKey {
        case isActivated, depId, depName, email, entId, entName, id, joinTime, leaderId, name, phone, position, role, workplace, shortPhone, cardViewable, phoneViewable, imServer
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isActivated, forKey: .isActivated)
        try container.encode(depId, forKey: .depId)
        try container.encode(depName, forKey: .depName)
        try container.encode(email, forKey: .email)
        try container.encode(entId, forKey: .entId)
        try container.encode(entName, forKey: .entName)
        try container.encode(id, forKey: .id)
        try container.encode(joinTime, forKey: .joinTime)
        try container.encode(leaderId, forKey: .leaderId)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(position, forKey: .position)
        try container.encode(role, forKey: .role)
        try container.encode(workplace, forKey: .workplace)
        try container.encode(shortPhone, forKey: .shortPhone)
        try container.encode(cardViewable, forKey: .cardViewable)
        try container.encode(phoneViewable, forKey: .phoneViewable)
        try container.encode(imServer, forKey: .imServer)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isActivated = try container.decode(Bool.self, forKey: .isActivated)
        self.depId = try container.decode(String.self, forKey: .depId)
        self.depName = try container.decode(String.self, forKey: .depName)
        self.email = try container.decode(String.self, forKey: .email)
        self.entId = try container.decode(String.self, forKey: .entId)
        self.entName = try container.decode(String.self, forKey: .entName)
        self.id = try container.decode(String.self, forKey: .id)
        self.joinTime = try container.decode(Int.self, forKey: .joinTime)
        self.leaderId = try container.decode(String.self, forKey: .leaderId)
        self.name = try container.decode(String.self, forKey: .name)
        self.phone = try container.decode(String.self, forKey: .phone)
        self.position = try container.decode(String.self, forKey: .position)
        self.role = try container.decode(Int.self, forKey: .role)
        self.workplace = try container.decode(String.self, forKey: .workplace)
        self.shortPhone = try container.decode(String.self, forKey: .shortPhone)
        self.cardViewable = try container.decode(Int.self, forKey: .cardViewable)
        self.phoneViewable = try container.decode(Int.self, forKey: .phoneViewable)
        self.imServer = try container.decode(String.self, forKey: .imServer)
    }
}

