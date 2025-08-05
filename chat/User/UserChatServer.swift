//
//  UserChatServer.swift
//  chat
//
//  Created by 陈健 on 2021/1/22.
//

import Foundation

struct UserChatServer {
    let id: String
    var name: String
    var address: String
}

extension UserChatServer {
    init(json: JSON) {
        self.id = json["id"].stringValue
        self.name = json["name"].stringValue
        self.address = json["address"].stringValue
    }
}

extension UserChatServer: Codable {
    private enum CodingKeys: CodingKey {
        case id, name, address
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.address = try container.decode(String.self, forKey: .address)
    }
}
