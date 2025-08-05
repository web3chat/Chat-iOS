//
//  MessageType.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import Foundation

protocol MessageType {
    
    var isOutgoing: Bool { get }//是否是自己发出的消息
    
    var kind: MessageKind { get }//消息类型
    
//    var isSend: Bool { get }
//    
//    var isReceive: Bool { get }
}
