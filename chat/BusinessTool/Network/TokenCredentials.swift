//
//  TokenCredentials.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/16.
//

import Foundation

struct TokenCredentials {
    var AccessKeyId: String
    var AccessKeySecret: String
    var Expiration: String
    var SecurityToken: String
}

extension TokenCredentials {
    init(json: JSON) {
        self.AccessKeyId = json["AccessKeyId"].stringValue
        self.AccessKeySecret = json["AccessKeySecret"].stringValue
        self.Expiration = json["Expiration"].stringValue
        self.SecurityToken = json["SecurityToken"].stringValue
    }
}

extension TokenCredentials: Codable {
    private enum CodingKeys: CodingKey {
        case AccessKeyId, AccessKeySecret, Expiration, SecurityToken
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AccessKeyId, forKey: .AccessKeyId)
        try container.encode(AccessKeySecret, forKey: .AccessKeySecret)
        try container.encode(Expiration, forKey: .Expiration)
        try container.encode(SecurityToken, forKey: .SecurityToken)
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.AccessKeyId = try container.decode(String.self, forKey: .AccessKeyId)
        self.AccessKeySecret = try container.decode(String.self, forKey: .AccessKeySecret)
        self.Expiration = try container.decode(String.self, forKey: .Expiration)
        self.SecurityToken = try container.decode(String.self, forKey: .SecurityToken)
    }
}
