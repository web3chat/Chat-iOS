//
//  AudioPosition.swift
//  chat
//
//  Created by 王俊豪 on 2022/1/10.
//

import Foundation

struct AudioPosition {
    enum Horizontal {
        case cellLeading
        case cellTrailing
    }
    
    let horizontal: Horizontal
    
    init(horizontal: Horizontal) {
        self.horizontal = horizontal
    }
}

extension AudioPosition: Equatable {
    
    static func == (lhs: AudioPosition, rhs: AudioPosition) -> Bool {
        return lhs.horizontal == rhs.horizontal
    }
    
}
