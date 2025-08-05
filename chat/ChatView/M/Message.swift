//
//  Message.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import Foundation
import SwiftyJSON
import Kingfisher

let UnSupportedMsgType = "不支持的消息类型"

enum SocketLuckyPacketStatus : Int {
    case normal = 1 //正常状态
    case receiveAll//领取完
    case past//过期
    case opened//已领取
}

struct Message {
    
    let msgId: String//本地生成的消息id
    let fromId: String
    let targetId: String
    let channelType: ChannelType// 私聊、群聊
    var msgType: MsgType// 消息类型 系统 文字 音频 图片 视频 文件 (卡片 忽略) 通知 转发
    var logId: Int?// 服务端返回的消息id
    var datetime: Int
    var status: Status// 发送状态（成功、ing、失败、已接收、已删除）
    
    var isRead = false//是否已读，暂用于语音和系统消息
    var showTime = false//是否显示消息时间
    
    var mentionIds: [String]?// 群内@的id数组
    
    var reference: Reference?// 引用的消息
    
    var gifData: Data?
    
    var user: User?
    
    var member: GroupMember?
    
    var mediaUrl: URL!//存储拍摄视频路径
    var fileUrl: String!//存储文件路径
    var audioUrl: String!//存储语音文件路径
    
    var packetType:IMRedPacketType?
    var coinname:String?
    private init(fromId: String, targetId: String, channelType: ChannelType, msgType: MsgType) {
        self.msgId = String.uuid()
        self.fromId = fromId
        self.targetId = targetId
        self.channelType = channelType
        self.msgType = msgType
        self.datetime = Date.timestamp
        self.status = .sending
    }
}

extension Message: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.msgId == rhs.msgId
    }
}

extension Message {
    
    var sessionId: SessionID {
        if case .group = channelType {
            return SessionID.group(targetId)
        }
        return self.isOutgoing ? SessionID.person(targetId) : SessionID.person(fromId)
    }
    
    // 会话列表显示的最新消息
    var mesPreview: NSAttributedString {
        return self.msgType.preview
    }
}



extension Message {
//    init(fromId: String, sessionId: SessionID, text: String) {
//        self.init(fromId: fromId, targetId: sessionId.idValue, channelType: sessionId.isPrivateChat ? .friend : .group, msgType: MsgType.init(text: text))
//    }
//
//    init(fromId: String, sessionId: SessionID, image: UIImage) {
//
//        let cacheKey = String.uuid()
//        ImageCache.default.store(image, forKey: cacheKey)
//
//        let msgType = MsgType.init(image: nil, cacheKey: cacheKey, width: Double(image.size.width), height: Double(image.size.height))
//        self.init(fromId: fromId, targetId: sessionId.idValue, channelType: sessionId.isPrivateChat ? .friend : .group, msgType: msgType)
//    }
    
    init(fromId: String, sessionId: SessionID, msgType: MsgType) {
        self.init(fromId: fromId, targetId: sessionId.idValue, channelType: sessionId.isPersonChat ? .person : .group, msgType: msgType)
    }
}
