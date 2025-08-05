//
//  Message+Status.swift
//  chat
//
//  Created by 陈健 on 2021/1/19.
//

import Foundation

extension Message {
    enum Status: Int {
        case sent = 0// 发送成功
        case sending = 1// 发送中
        case failed = 2// 发送失败
        case delivered = 3// 对方已接收
        case deleted = 4// 消息已删除
    }
}
