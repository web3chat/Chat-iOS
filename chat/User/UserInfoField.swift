//
//  UserInfoField.swift
//  chat
//
//  Created by 陈健 on 2021/1/22.
//

import Foundation

struct UserInfoField {
    var name: UserInfoName
    var value: String
    var level: UserInfoLevel
}

extension UserInfoField {
    
    enum UserInfoLevel {
        case `private`
        case protect
        case `public`
        case unknown(String)
        
        var rawValue: String {
            switch self {
            case .private:
                return "private"
            case .protect:
                return "protect"
            case .public:
                return "public"
            case .unknown(let value):
                return value
            }
        }
        
        init(rawValue: String) {
            switch rawValue {
            case "private":
                self = .private
            case "protect":
                self = .protect
            case "public":
                self = .public
            default:
                self = .unknown(rawValue)
            }
        }
    }
    
    enum UserInfoName {
        case pubKey
        case nickname
        case avatar
        case phone
        case email
        case ETH
        case BNB
        case BTY
        case unknown(String)
        
        var rawValue: String {
            switch self {
            case .pubKey:
                return "pubKey"
            case .nickname:
                return "nickname"
            case .avatar:
                return "avatar"
            case .phone:
                return "phone"
            case .email:
                return "email"
            case .ETH:
                return "chain.ETH"
            case .BNB:
                return "chain.BNB"
            case .BTY:
                return "chain.BTY"
            case .unknown(let value):
                return value
            }
        }
        
        init(rawValue: String) {
            switch rawValue {
            case "pubKey":
                self = .pubKey
            case "nickname":
                self = .nickname
            case "avatar":
                self = .avatar
            case "phone":
                self = .phone
            case "email":
                self = .email
            case "chain.ETH":
                self = .ETH
            case "chain.BNB":
                self = .BNB
            case "chain.BTY":
                self = .BTY
            default:
                self = .unknown(rawValue)
            }
        }
    }
}

extension UserInfoField {
    init(json: JSON) {
        self.name = UserInfoName.init(rawValue: json["name"].stringValue)
        self.value = json["value"].stringValue
        self.level = UserInfoLevel.init(rawValue: json["level"].stringValue)
    }
}

extension UserInfoField: Codable {
    private enum CodingKeys: CodingKey {
        case name, value, level
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name.rawValue, forKey: .name)
        try container.encode(value, forKey: .value)
        try container.encode(self.name.rawValue, forKey: .level)
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nameRaw = try container.decode(String.self, forKey: .name)
        self.name = UserInfoName.init(rawValue: nameRaw)
        self.value = try container.decode(String.self, forKey: .value)
        let levelRaw = try container.decode(String.self, forKey: .level)
        self.level = UserInfoLevel.init(rawValue: levelRaw)
    }
}
