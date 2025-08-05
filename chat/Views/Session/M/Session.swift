//
//  Session.swift
//  chat
//
//  Created by 陈健 on 2021/1/11.
//

import Foundation

struct Session {
    let id: SessionID
    var imageURLStr = ""
    var sessionName = ""
    var latestInfo = NSAttributedString.init()
    var timestamp = Date.timestamp
    var unreadCount = 0
    var isSendFailed = false
    var msgId = ""
    var isPrivateChat: Bool {// 是否是私聊/群聊
        return self.id.isPersonChat
    }
    var groupType = 0// 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
    
    var chatServerUrl = ""// 当前选择的聊天服务器地址（群聊）
    
    var hasAtMe = false// 群聊用，是否有未读的'@'（被'@'后未读，收到新消息仍显示‘[有人@我]’）
    
    init(id: SessionID) {
        self.id = id
        var contactsName = ""/*id.idValue*/// 会话名称
        var imageUrl = ""
        
        if self.id.isPersonChat {// 私聊
//            if let friend = UserManager.shared().friend(by: id.idValue) {
//                contactsName = friend.contactsName// 会话名称
//                imageUrl = friend.avatarURLStr
//            } else
            if let user = UserManager.shared().user(by: id.idValue) {
                contactsName = user.contactsName
                imageUrl = user.avatarURLStr
            }
            
        } else {// 群聊
            if let group = GroupManager.shared().getDBGroup(by: id.idValue.intEncoded) {
                imageUrl = group.avatarURLStr
                contactsName = group.contactsName
                self.chatServerUrl = group.chatServerUrl ?? ""
                self.groupType = group.groupType
            }
        }
        
        self.sessionName = contactsName
        self.imageURLStr = imageUrl
    }
}

extension Session: Equatable {
    static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.id == rhs.id
    }
    
}
