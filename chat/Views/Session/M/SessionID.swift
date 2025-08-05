//
//  SessionID.swift
//  chat
//
//  Created by 陈健 on 2021/1/19.
//

import Foundation

enum SessionID {
    case person(String)// 私聊
    case group(String)// 群聊
    
    var idValue: String {
        switch self {
        case .person(let id):
            return id
        case .group(let id):
            return id
        }
    }
    
    var isPersonChat: Bool {
        if case .person(_) = self {
            return true
        }
        return false
    }
}

extension SessionID: Equatable {
    static func == (lhs: SessionID, rhs: SessionID) -> Bool {
        if case .person(let id1) = lhs, case .person(let id2) = rhs {
            return id1 == id2
        }
        if case .group(let id1) = lhs, case .group(let id2) = rhs {
            return id1 == id2
        }
        return false
    }
}
