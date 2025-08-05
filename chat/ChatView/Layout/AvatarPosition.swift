//
//  AvatarPosition.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import Foundation

struct AvatarPosition {
    enum Horizontal {
        case cellLeading
        case cellTrailing
    }
    
    enum Vertical {
        case messageLabelTop(offset: CGFloat)
    }
    
    let horizontal: Horizontal
    let vertical: Vertical
    
    init(horizontal: Horizontal, vertical: Vertical) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

extension AvatarPosition.Vertical: Equatable {
    
    static func == (lhs: AvatarPosition.Vertical, rhs: AvatarPosition.Vertical) -> Bool {
        if case .messageLabelTop(let lhsOffset) = lhs,  case .messageLabelTop(let rhsOffset) = rhs {
            return lhsOffset == rhsOffset
        }
        return false
    }
}

extension AvatarPosition: Equatable {
    
    static func == (lhs: AvatarPosition, rhs: AvatarPosition) -> Bool {
        return lhs.vertical == rhs.vertical && lhs.horizontal == rhs.horizontal
    }
    
}
