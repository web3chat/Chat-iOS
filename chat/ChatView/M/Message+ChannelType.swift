//
//  Message+ChannelType.swift
//  chat
//
//  Created by 陈健 on 2021/1/18.
//

import Foundation

extension Message {
    enum ChannelType {
        case person //0 私聊
        case group  //1 群聊
        case unknown(Int)// 未知
    }
}
extension Message.ChannelType: Equatable {
    static func == (lhs:Message.ChannelType, rhs: Message.ChannelType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension Message.ChannelType {
    init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = Message.ChannelType.person
        case 1:
            self = Message.ChannelType.group
        default:
            self = Message.ChannelType.unknown(rawValue)
        }
    }
    var rawValue: Int {
        switch self {
        case .person:
            return 0
        case .group:
            return 1
        case .unknown(let value):
            return value
        }
    }
}
