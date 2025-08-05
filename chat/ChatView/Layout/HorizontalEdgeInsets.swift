//
//  HorizontalEdgeInsets.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import Foundation

struct HorizontalEdgeInsets {
    let left: CGFloat
    let right: CGFloat
    
    init(left: CGFloat, right: CGFloat) {
        self.left = left
        self.right = right
    }
    
    static var zero: HorizontalEdgeInsets {
        return HorizontalEdgeInsets.init(left: 0, right: 0)
    }
}
extension HorizontalEdgeInsets {
    
    var horizontal: CGFloat {
        return left + right
    }
}

extension HorizontalEdgeInsets: Equatable {
    
    static func == (lhs: HorizontalEdgeInsets, rhs: HorizontalEdgeInsets) -> Bool {
        return lhs.left == rhs.left && lhs.right == rhs.right
    }
}


