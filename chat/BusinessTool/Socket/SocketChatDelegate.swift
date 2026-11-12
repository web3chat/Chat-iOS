//
//  SocketChatDelegate.swift
//  Chat33
//
//  Created by fzm on 2018/9/20.
//  Copyright © 2018年 fzm. All rights reserved.
//

import Foundation

protocol SocketChatMsgDelegate: AnyObject {
    func receiveMessage(with msg: Message, isLocal: Bool)
    func receiveHistoryMsgList(with msgs: [Message], isUnread: Bool)
    func failSendMessage(with msg: Message)
}

protocol SocketConnectDelegate: AnyObject {
    func socketConnect()
    func socketDisConnect()
}


