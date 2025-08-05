//
//  Message+Reference.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/28.
//

import Foundation

extension Message {
    struct Reference {
        var ref: Int // 直接引用的那条消息
        var topic: Int // 最初引用开始的那条消息
    }
}
