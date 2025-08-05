//
//  PbMsg_event+Message.swift
//  chat
//
//  Created by 陈健 on 2021/3/10.
//

import Foundation

extension PbMsg_event {
    /// msg转为protobuf结构体
    init?(with msg: Message, publickey: String) {
        // 序列化
        var pbMsg = PbMsg_msg.init(with: msg)
        
        // 加密消息体
        if !publickey.isBlank {// 公钥不为空时加密消息体
            let encryptMsg = ChatManager.encryptMsgData(pbMsg.msg, publickey: publickey, isEncryptPersionChatData: msg.sessionId.isPersonChat)
            pbMsg.msg = encryptMsg
        }
        
        self.eventType = .message
        if let data = try? pbMsg.serializedData() {
            self.body = data
            FZMLog("pbMsg.serializedData success --- \(data)")
        } else {
            FZMLog("pbMsg.serializedData error ---")
        }
        
//        guard let data = try? pbMsg.serializedData() else { return }
//        self.eventType = .message
//        self.body = data
    }
}
