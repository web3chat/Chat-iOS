//
//  IMFullTextSearchVM.swift
//  IMSDK
//
//  Created by 陈健 on 2019/9/20.
//

import UIKit
import RxSwift
import CryptoKit
import sqlcipher

class IMFullTextSearchVM: NSObject {
    let type: FZMFullTextSearchType
    let typeId: String// address/groupid/sessionId
    var avatar: String
    var name: String
    let alias: String
    let msgs: [Message]
    var showName: String {
        switch type {
        case .friend:
            return alias.isEmpty ? name : alias
        case .group:
            return name
        case .chatRecord:
            return name
        case .all:
            return ""
        }
    }
    
    let nameSubject = BehaviorSubject<String?>.init(value: nil)
    let avatarSubject = BehaviorSubject<String?>.init(value: nil)
    
    init(type: FZMFullTextSearchType, typeId: String , avatar: String, name: String, alias: String, msgs:[Message] = [Message]() ) {
        self.type = type
        self.typeId = typeId
        self.avatar = avatar
        self.name = name
        self.alias = alias
        self.msgs = msgs
        if !self.name.isEmpty {
            self.nameSubject.onNext(self.name)
        }
        if !self.avatar.isEmpty {
            self.avatarSubject.onNext(self.avatar)
        }
    }
    
    convenience init(friend: User) {
        self.init(type: .friend, typeId: friend.address ,avatar: friend.avatarURLStr, name: friend.contactsName , alias: friend.alias ?? "")
    }
    
    convenience init(group: Group) {
        self.init(type: .group, typeId: group.address, avatar: group.avatarURLStr, name: group.name, alias: group.contactsName)
    }
    
    convenience init?(msgs: [Message], isDetailList: Bool = false) {
        guard let msg = msgs.first else { return nil }
        let alias = msgs.count == 1 ? msg.mesPreview.string : "\(msgs.count)条相关聊天记录"
        self.init(type: .chatRecord(specificId: nil), typeId: msg.sessionId.idValue, avatar: "", name: "" , alias: alias, msgs: msgs)
        if !isDetailList {
            if msg.channelType == .person {
                let session = SessionManager.shared().getOrCreateSession(id: SessionID.person(msg.isOutgoing ? msg.targetId : msg.fromId))
                self.name = session.sessionName
                self.avatar = session.imageURLStr
                self.nameSubject.onNext(self.name)
                self.avatarSubject.onNext(self.avatar)
            } else if msg.channelType == .group {
                let session = SessionManager.shared().getOrCreateSession(id: SessionID.group(msg.targetId))
                self.name = session.sessionName
                self.avatar = session.imageURLStr
                self.nameSubject.onNext(self.name)
                self.avatarSubject.onNext(self.avatar)
            }
        } else {
            
            
            if msg.channelType == .person || (msg.channelType == .group && msgs.count == 1) {
                let address = msg.fromId
                
                if address == LoginUser.shared().address {
                    self.avatar = LoginUser.shared().avatarUrl
                    self.name = LoginUser.shared().contactsName
                    self.nameSubject.onNext(self.name)
                    self.avatarSubject.onNext(self.avatar)
                } else {
                    UserManager.shared().getUser(by: address) { (user) in
                        if let user = user {
                            self.avatar = user.avatarURLStr
                            self.name = user.contactsName
                            self.nameSubject.onNext(self.name)
                            self.avatarSubject.onNext(self.avatar)
                        } else {
                            self.avatar = ""
                            self.name = address.shortAddress
                        }
                    }
                }
                
                //群内搜聊天记录
                if msg.channelType == .group {
                    let groupId = msg.targetId.intEncoded
                    if let memeber =   GroupManager.shared().getDBGroupMember(with: groupId, memberId: address){
                        self.name = memeber.contactsName
                        self.nameSubject.onNext(self.name)
                    }
                }
                
//            guard let user = UserManager.shared().user(by: address) else {
//                return
//            }
//            self.avatar = user.avatarURLStr
//            self.name = user.contactsName
//            self.nameSubject.onNext(self.name)
//            self.avatarSubject.onNext(self.avatar)
//
//            UserManager.shared().getNetUser(targetAddress: address) { (user) in
//                self.avatar = user.avatarURLStr
//                self.name = user.contactsName
//                self.nameSubject.onNext(self.name)
//                self.avatarSubject.onNext(self.avatar)
//
//            } failureBlock: { (error) in
//                FZMLog("\(error)")
//            }
            } else if msg.channelType == .group {
                let groupId = msg.targetId.intEncoded
                
                if let group = GroupManager.shared().getDBGroup(by: groupId) {
                    self.avatar = group.avatarURLStr
                    self.name = group.contactsName
                    self.nameSubject.onNext(self.name)
                    self.avatarSubject.onNext(self.avatar)
                } else {
                    self.avatar = ""
                    self.name = msg.targetId.shortAddress
                }
            }
        }
    }
    
    static func > (lhs: IMFullTextSearchVM, rhs: IMFullTextSearchVM) -> Bool {
        
        if case FZMFullTextSearchType.chatRecord(_) = lhs.type, case FZMFullTextSearchType.chatRecord(_) = rhs.type {
            return lhs.msgs.first?.datetime ?? 0 > rhs.msgs.first?.datetime ?? 0
        }
        return true
    }
}
