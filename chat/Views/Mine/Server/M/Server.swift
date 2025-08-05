//
//  Server.swift
//  chat
//
//  Created by 陈健 on 2021/2/25.
//

import UIKit

struct Server {
    var name: String = ""
    var value: String = ""
    var id: String = String.uuid()
}

extension Server {
    init(userchatServerGroup: UserChatServerGroup) {
        self.id = userchatServerGroup.id
        self.name = userchatServerGroup.name
        self.value = userchatServerGroup.value
    }
}

extension Server: Codable {
    private enum CodingKeys: CodingKey {
        case name, value, id
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        try container.encode(id, forKey: .id)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(String.self, forKey: .value)
        self.id = try container.decode(String.self, forKey: .id)
    }
}
