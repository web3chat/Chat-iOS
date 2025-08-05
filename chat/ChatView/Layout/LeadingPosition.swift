//
//  LeadingPosition.swift
//  chat
//
//  Created by 陈健 on 2020/12/24.
//

import Foundation

enum LeadingPosition {
    case messageLabelTop(offset: CGFloat)
}

extension LeadingPosition: Equatable {
    static func == (lhs: LeadingPosition, rhs: LeadingPosition) -> Bool {
        if case .messageLabelTop(let lhsOffset) = lhs,  case .messageLabelTop(let rhsOffset) = rhs {
            return lhsOffset == rhsOffset
        }
        return false
    }
    
}
