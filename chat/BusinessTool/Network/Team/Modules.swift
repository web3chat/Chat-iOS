//
//  Modules.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/12.
//

import Foundation

struct Modules {
    var name: ModulesName
    var isEnabled: Bool
    var endPoints: Array<String>
}

extension Modules {
    
    enum ModulesName {
        case wallet
        case oa
        case redpacket
        case live
        case shop
        case unknown(String)
        
        var rawValue: String {
            switch self {
            case .wallet:
                return "wallet"
            case .oa:
                return "oa"
            case .redpacket:
                return "redpacket"
            case .live:
                return "live"
            case .shop:
                return "shop"
            case .unknown(let value):
                return value
            }
        }
        
        init(rawValue: String) {
            switch rawValue {
            case "wallet":
                self = .wallet
            case "oa":
                self = .oa
            case "redpacket":
                self = .redpacket
            case "live":
                self = .live
            case "shop":
                self = .shop
            default:
                self = .unknown(rawValue)
            }
        }
    }
}

extension Modules {
    init(json: JSON) {
        self.name = ModulesName.init(rawValue: json["name"].stringValue)
        self.isEnabled = json["isEnabled"].boolValue
        self.endPoints = json["endPoints"].arrayValue.compactMap { $0.string }
    }
}

