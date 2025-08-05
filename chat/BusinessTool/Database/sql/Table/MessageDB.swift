//
//  MessageDB.swift
//  chat
//
//  Created by 陈健 on 2021/1/18.
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
    let topicId: Int?// 最初引用开始的那条消息
    let refId: Int?// 直接引用的那条消息
    
    let gifData: Data?
    
    enum CodingKeys: String, CodingTableKey {

        typealias Root = MessageDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case msgId, fromId, targetId, sessionId, channelType, msgType, msg, logId, datetime, status, isRead, showTime, gifData, mentionIds, topicId, refId
        
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
        self.topicId = message.reference?.topic
        self.refId = message.reference?.ref
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
        if let refId = messageDB.refId, let topicId = messageDB.topicId {
            let ref = Message.Reference.init(ref: refId, topic: topicId)
            self.reference = ref
        }
    }
}
