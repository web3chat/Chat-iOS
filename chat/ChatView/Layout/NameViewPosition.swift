//
//  NameViewPosition.swift
//  chat
//
//  Created by 王俊豪 on 2021/12/24.
//

import Foundation

struct NameViewPosition {
    enum Horizontal {
        case avatarLeading
        case avatarTrailing
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

extension NameViewPosition.Vertical: Equatable {
    
    static func == (lhs: NameViewPosition.Vertical, rhs: NameViewPosition.Vertical) -> Bool {
        if case .messageLabelTop(let lhsOffset) = lhs,  case .messageLabelTop(let rhsOffset) = rhs {
            return lhsOffset == rhsOffset
        }
        return false
    }
}

extension NameViewPosition: Equatable {
    
    static func == (lhs: NameViewPosition, rhs: NameViewPosition) -> Bool {
        return lhs.vertical == rhs.vertical && lhs.horizontal == rhs.horizontal
    }
    
}
