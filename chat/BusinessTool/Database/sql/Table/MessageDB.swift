//
//  MessageDB.swift
//  chat
//
//  Created by fzm on 2021/1/18.
//

import UIKit
import WCDBSwift
import SwiftyJSON

//MARK: 消息
final class MessageDB: TableCodable {
    let msgId: String
    let fromId: String
    let targetId: String
    let sessionId: String
    let channelType: Int
    let msgType: Int
    let msg: String
    let logId: Int?
    let datetime: Int
    let status: Int// 发送状态（成功、ing、失败、已接收、已删除）
    let isRead: Bool
    let showTime: Bool
    let mentionIds: String?// 群内@的id数组
    let isBurn: Bool?// 阅后即焚标记（老库该列为 NULL，按 false 处理）
    let topicId: Int?// 最初引用开始的那条消息
    let refId: Int?// 直接引用的那条消息
    
    let gifData: Data?
    
    // 气泡下方的附属文本（本地生成，不上链、不进消息体）
    let translation: String?// 文本消息译文
    let translationLang: String?// 译文目标语言 code
    let transcript: String?// 语音转写文本
    
    enum CodingKeys: String, CodingTableKey {

        typealias Root = MessageDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case msgId, fromId, targetId, sessionId, channelType, msgType, msg, logId, datetime, status, isRead, showTime, gifData, mentionIds, topicId, refId, isBurn
        case translation, translationLang, transcript
        
        static var columnConstraintBindings: [MessageDB.CodingKeys : ColumnConstraintBinding]? {
            return [msgId: ColumnConstraintBinding.init(isPrimary: true)]
        }
        
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return ["sessionId": IndexBinding.init(indexesBy: sessionId),
                    "logId": IndexBinding.init(indexesBy: logId.asIndex(orderBy: .descending)),
                    "datetime": IndexBinding.init(indexesBy: datetime.asIndex(orderBy: .descending))]
        }
    }
    
    init(with message: Message) {
        self.msgId = message.msgId
        self.fromId = message.fromId
        self.targetId = message.targetId
        self.sessionId = message.sessionId.idValue
        self.channelType = message.channelType.rawValue
        let msgTypeValue = message.msgType.rawValue
        self.msgType = msgTypeValue.value
        self.msg = msgTypeValue.json.rawString() ?? ""
        self.logId = message.logId
        self.datetime = message.datetime
        self.status = message.status.rawValue
        self.isRead = message.isRead
        self.showTime = message.showTime
        self.gifData = message.gifData
        self.mentionIds = message.mentionIds?.joined(separator: ",")
        // 阅后即焚：列值 或 消息体 JSON 里的标记（双轨，防丢）
        self.isBurn = message.isBurn || message.msgType.isBurnFlagInJSON
        self.topicId = message.reference?.topic
        self.refId = message.reference?.ref
        // 附属文本：空串按「没有」处理（老库为 NULL）
        self.translation = message.translation?.isBlank == false ? message.translation : nil
        self.translationLang = message.translationLang?.isBlank == false ? message.translationLang : nil
        self.transcript = message.transcript?.isBlank == false ? message.transcript : nil
    }
}

extension Message {
    init(with messageDB: MessageDB) {
        self.msgId = messageDB.msgId
        self.fromId = messageDB.fromId
        self.targetId = messageDB.targetId
        self.channelType = Message.ChannelType.init(rawValue: messageDB.channelType)
        let rawValue = (messageDB.msgType, JSON.init(parseJSON: messageDB.msg))
        self.msgType = Message.MsgType.init(rawValue: rawValue)
        self.logId = messageDB.logId
        self.datetime = messageDB.datetime
        self.status = Message.Status.init(rawValue: messageDB.status) ?? .sent
        self.isRead = messageDB.isRead
        self.showTime = messageDB.showTime
        self.gifData = messageDB.gifData
        self.mentionIds = messageDB.mentionIds?.components(separatedBy: ",")
        self.isBurn = (messageDB.isBurn ?? false) || self.msgType.isBurnFlagInJSON
        // 附属文本：老库该列为 NULL；空串同样按「没有」处理
        self.translation = messageDB.translation?.isBlank == false ? messageDB.translation : nil
        self.translationLang = messageDB.translationLang?.isBlank == false ? messageDB.translationLang : nil
        self.transcript = messageDB.transcript?.isBlank == false ? messageDB.transcript : nil
        // 引用：只有 refId > 0 才算真引用。
        // ⚠️ 历史版本给每条收到的消息都写了 `{0,0}` 的假引用（见 `Message+PbMsg`），
        //    库里那批老数据 refId/topicId 都是 0；这里必须过滤掉，否则老消息会一直当成"有引用"
        //    （转发时会带出非法 reference，列表也会按 refId=0 反查原消息）。
        if let refId = messageDB.refId, let topicId = messageDB.topicId, refId > 0 {
            let ref = Message.Reference.init(ref: refId, topic: topicId)
            self.reference = ref
        }
    }
}
