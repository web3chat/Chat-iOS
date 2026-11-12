//
//  SessionDB.swift
//  chat
//
//  Created by fzm on 2021/1/12.
//

import Foundation
import WCDBSwift

final class SessionDB: TableCodable {
    let id: String
    var imageURLStr = ""
    var sessionName = ""
    var latestInfo = Data.init()
    var timestamp = 0
    var unreadCount = 0
    var isSendFailed: Bool
    var msgId = ""
    let isPrivateChat: Bool
    var groupType = 0// 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
    var chatServerUrl = ""
    var hasAtMe = false// 是否有未读的'@'（被'@'后未读，收到新消息仍显示‘[有人@我]’）
    var autoDeleteOption = 0// 自动删除选项（0=关闭 1=1天 2=3天 3=7天 4=30天 5=180天）
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = SessionDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case id, isPrivateChat, imageURLStr, sessionName, latestInfo, timestamp, unreadCount, isSendFailed, msgId, chatServerUrl, groupType, hasAtMe, autoDeleteOption
        
        static var columnConstraintBindings: [SessionDB.CodingKeys : ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding.init(isPrimary: true)
            ]
        }
        
        static var indexBindings: [IndexBinding.Subfix : IndexBinding]? {
            return [
                "isPrivateChat": IndexBinding.init(indexesBy: isPrivateChat)
            ]
        }
    }
    
    init(with session: Session) {
        self.id = session.id.idValue
        self.isPrivateChat = session.isPrivateChat
        
        self.imageURLStr = session.imageURLStr
        self.sessionName = session.sessionName
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: session.latestInfo, requiringSecureCoding: false) {
            self.latestInfo = data
        }
        self.timestamp = session.timestamp
        self.unreadCount = session.unreadCount
        self.isSendFailed = session.isSendFailed
        self.msgId = session.msgId
        self.chatServerUrl = session.chatServerUrl
        self.groupType = session.groupType
        self.hasAtMe = session.hasAtMe
        self.autoDeleteOption = session.autoDeleteOption
    }
}

extension Session {
    init(with sessionTable: SessionDB) {
        self.id = sessionTable.isPrivateChat ? .person(sessionTable.id) : .group(sessionTable.id)
        self.imageURLStr = sessionTable.imageURLStr
        self.sessionName = sessionTable.sessionName
        if let latestInfoAtt = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: sessionTable.latestInfo) {
            self.latestInfo = latestInfoAtt
        }
        self.timestamp = sessionTable.timestamp
        self.unreadCount = sessionTable.unreadCount
        self.isSendFailed = sessionTable.isSendFailed
        self.msgId = sessionTable.msgId
        self.chatServerUrl = sessionTable.chatServerUrl
        self.groupType = sessionTable.groupType
        self.hasAtMe = sessionTable.hasAtMe
        self.autoDeleteOption = sessionTable.autoDeleteOption
    }
}


