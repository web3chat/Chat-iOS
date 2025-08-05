//
//  EnterPriseInfo.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/11.
//  /v1/enterprise/info 查询企业信息

import Foundation

struct EnterPriseInfo {
    var avatar: String// 企业头像
    var description: String// 企业描述
    var id: String// 企业 ID
    var imServer: String// 企业 IM 服务器地址
    var name: String// 企业名称
    var nodeServer: String// 企业区块链服务器地址
    var oaServer: String// 企业 OA 服务器地址
    var rootDepId: String// 企业根部门 ID
}

extension EnterPriseInfo {
    init(json: JSON) {
        self.avatar = json["avatar"].stringValue
        self.description = json["description"].stringValue
        self.id = json["id"].stringValue
        self.imServer = json["imServer"].stringValue
        self.name = json["name"].stringValue
        self.nodeServer = json["nodeServer"].stringValue
        self.oaServer = json["oaServer"].stringValue
        self.rootDepId = json["rootDepId"].stringValue
    }
}

extension EnterPriseInfo {
    var pDictionary: [String: Any] {
        return [
            "avatar" : avatar,
            "description" : description,
            "id" : id,
            "imServer" : imServer,
            "name" : name,
            "nodeServer" : nodeServer,
            "oaServer" : oaServer,
            "rootDepId" : rootDepId,
        ]
    }
}

extension EnterPriseInfo: Codable {
    private enum CodingKeys: CodingKey {
        case avatar, description, id, imServer, name, nodeServer, oaServer, rootDepId
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(description, forKey: .description)
        try container.encode(id, forKey: .id)
        try container.encode(imServer, forKey: .imServer)
        try container.encode(name, forKey: .name)
        try container.encode(nodeServer, forKey: .nodeServer)
        try container.encode(oaServer, forKey: .oaServer)
        try container.encode(rootDepId, forKey: .rootDepId)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.avatar = try container.decode(String.self, forKey: .avatar)
        self.description = try container.decode(String.self, forKey: .description)
        self.id = try container.decode(String.self, forKey: .id)
        self.imServer = try container.decode(String.self, forKey: .imServer)
        self.name = try container.decode(String.self, forKey: .name)
        self.nodeServer = try container.decode(String.self, forKey: .nodeServer)
        self.oaServer = try container.decode(String.self, forKey: .oaServer)
        self.rootDepId = try container.decode(String.self, forKey: .rootDepId)
    }
}

