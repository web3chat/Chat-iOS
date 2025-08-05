//
//  UserChatServerGroup.swift
//  chat
//
//  Created by 陈健 on 2021/1/25.
//

import UIKit
import Starscream

struct UserChatServerGroup {
    let id: String
    var name: String
    var value: String
    var firstConnect = false
}

extension UserChatServerGroup {
    init(json: JSON) {
        self.id = json["id"].stringValue
        self.name = json["name"].stringValue
        self.value = json["value"].stringValue
    }
    
    init(server: Server) {
        self.id = server.id
        self.name = server.name
        self.value = server.value
    }
    
    init(userchatServer: UserChatServer) {
        self.id = userchatServer.id
        self.name = userchatServer.name
        self.value = userchatServer.address
    }
}

extension UserChatServerGroup: Equatable {
    static func == (lhs: UserChatServerGroup, rhs: UserChatServerGroup) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.value == rhs.value
    }
}

extension UserChatServerGroup: Codable {
    private enum CodingKeys: CodingKey {
        case id, name, value
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(String.self, forKey: .value)
    }
}
