//
//  SessionManager.swift
//  chat
//
//  Created by 陈健 on 2021/1/13.
//

import Foundation
import WCDBSwift
import UIKit
import RxSwift

class SessionManager {
    
    /// 固定文本：[有人@我]
    private let atMe = "[有人@我]"
    
    private static let sharedInstance = SessionManager.init()
    
    static func shared() -> SessionManager { return sharedInstance }
    
    private var privateUnreadCount = 0// 私聊未读数
    private var groupUnreadCount = 0// 群聊未读数
    /**
     * 私聊未读数和群聊未读数获取次数统计，都获取过再更新角标
     * 否则先获取的未读数为零时设置角标数为0会清空系统通知栏里的所有通知消息
     */
    private var updateBadgeNumberCount = 0
    
    private let bag = DisposeBag.init()
    private(set) lazy var privateSessionsSubject = BehaviorSubject<[Session]>.init(value: [])
    private(set) lazy var groupSessionsSubject = BehaviorSubject<[Session]>.init(value: [])
    let privateUnReadCountSubject = BehaviorSubject<Int>(value: 0)
    let groupUnReadCountSubject = BehaviorSubject<Int>(value: 0)
    
    private(set) var privateSessions = [Session]() {
        didSet {
            self.allSessions = self.privateSessions + self.groupSessions
//            FZMLog("privateSessions ---- \(self.privateSessions) \n allSessions ---- \(self.allSessions)")
            DispatchQueue.main.async {
                self.privateSessionsSubject.onNext(self.privateSessions)
            }
        }
    }
    
    private(set) var groupSessions = [Session]() {
        didSet {
            self.allSessions = self.privateSessions + self.groupSessions
            DispatchQueue.main.async {
                self.groupSessionsSubject.onNext(self.groupSessions)
            }
        }
    }
    
    private(set) var allSessions = [Session]()
    
    var currentChatSession: Session? = nil
    
    private init() {
        self.addLoginObserver()
        self.loadDBSessions()
        self.setRX()
    }
    
    private func setRX() {
        // 发消息订阅
        ChatManager.shared().sendMsgSubject.subscribe(onNext: {[unowned self] (msg) in
            self.updateLstestInfo(msg: msg)
        }).disposed(by: self.bag)
        // 收消息订阅
        MultipleSocketManager.shared().receiveMsgsSubject.subscribe(onNext: {[unowned self] (msgs) in
            self.handleReceive(msgs: msgs)
        }).disposed(by: self.bag)
    }
    
    // 清除缓存会话数据
    private func clearSessions() {
        self.allSessions.removeAll()
        self.privateSessions.removeAll()
        self.groupSessions.removeAll()
    }
    
    // 重置单个会话的未读数
    func clearUnreadCount(session sessionId: SessionID) {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.unreadCount = 0
        self.update(session: session)
    }
    
    /// 更新会话未读总数
    func refreshAllUnreadCount() {
        // 更新私聊未读总数
        self.refreshPrivateUnreadCount()
        
        // 更新群聊未读总数
        self.refreshGroupUnreadCount()
    }
    
    /// 更新私聊未读总数
    func refreshPrivateUnreadCount() {
        privateUnreadCount = 0
        
        self.privateSessions.forEach { (session) in
            // 免打扰用户未读数不计入总未读数
            var isMuteNoti = false
            if let user = UserManager.shared().user(by: session.id.idValue) {
                isMuteNoti = user.isMuteNotification
            }
            if !isMuteNoti {
                privateUnreadCount += session.unreadCount
            }
        }
        if updateBadgeNumberCount < 2 {
            updateBadgeNumberCount += 1
        }
        updateApplicationIconBadgeNumber()
        
        self.privateUnReadCountSubject.onNext(privateUnreadCount)
    }
    
    private func updateApplicationIconBadgeNumber() {
        // 私聊和群聊未读数两个都至少获取过一次再设置角标，否则先设置为0时会清空系统通知栏的通知消息
        guard updateBadgeNumberCount >= 2 else {
            return
        }
        
        FZMUIMediator.shared().setApplicationIconBadgeNumber(self.privateUnreadCount + self.groupUnreadCount)
    }
    
    /// 更新群聊未读总数
    func refreshGroupUnreadCount() {
        groupUnreadCount = 0
        
        self.groupSessions.forEach { (session) in
            // 免打扰群聊未读数不计入总未读数
            var isMuteNoti = false
            if let group = GroupManager.shared().getDBGroup(by: session.id.idValue.intEncoded) {
                isMuteNoti = group.isMuteNotification
            }
            if !isMuteNoti {
                groupUnreadCount += session.unreadCount
            }
        }
        
        if updateBadgeNumberCount < 2 {
            updateBadgeNumberCount += 1
        }
        updateApplicationIconBadgeNumber()
        
        self.groupUnReadCountSubject.onNext(groupUnreadCount)
    }
    
    
    /// 点击消息列表相关处理 - 如果有‘[有人@我]’信息则需更新
    /// - Parameter session: 会话model
    func updateLatestInfo(_ session: Session) {
        // 如果有‘[有人@我]’，则更新消息列表
        if !session.isPrivateChat {
            if session.latestInfo.string.contains(atMe) {
                let tempAttri = NSMutableAttributedString.init(attributedString: session.latestInfo)
                tempAttri.deleteCharacters(in: NSRange(location: 0, length: 6))
                var tmpSession = session
                tmpSession.latestInfo = tempAttri
                self.update(session: tmpSession)
            }
        }
    }
    
    // 更新会话记录显示的消息内容（聊天页面删除消息时需更新会话记录）
    func updateLastMsgInfo(session: Session, msgId: String) {
        if let latestMsg = ChatManager.shared().getLatestMsg(sessionId: session.id.idValue, exceptMsgId: msgId) {
            // 还有消息则更新会话消息内容
            self.updateLstestInfo(msg: latestMsg)
        } else {
            // 没有消息记录则删除会话
            self.deleteSession(id: session.id)
        }
    }
    
    // 更新会话记录显示的消息发送状态
    func updateMsgSendStatus(with msgId: String, sendSuccess: Bool) {
        // 更新数据库
        var sessionInDB = self.getDBSession(with: msgId)
        
        if sessionInDB != nil {
            sessionInDB!.isSendFailed = !sendSuccess
            self.update(session: sessionInDB!)
            
            // 更新数据源
            if sessionInDB!.isPrivateChat {// 私聊
                guard privateSessions.count > 0 else { return }
                for i in 0..<privateSessions.count {
                    if privateSessions[i].msgId == msgId {
                        privateSessions[i].isSendFailed = !sendSuccess
                        return
                    }
                }
            } else {// 群聊
                guard groupSessions.count > 0 else { return }
                for i in 0..<groupSessions.count {
                    if groupSessions[i].msgId == msgId {
                        groupSessions[i].isSendFailed = !sendSuccess
                        return
                    }
                }
            }
        }
    }
    
    // 收到消息处理
    private func handleReceive(msgs: [Message]) {
        let divideMsgs = Array(msgs.reduce(into: Dictionary<String,[Message]>.init()) { (dic, message) in
            let key = message.sessionId.idValue + String(message.channelType.rawValue)
            if dic[key] == nil {
                var arr = Array<Message>.init()
                arr.append(message)
                dic[key] = arr
            } else {
                dic[key]?.append(message)
            }
        }.values)
        for msgArr in divideMsgs where !msgArr.isEmpty {
            guard let lastMsg = msgArr.last else { continue }
            // 拉黑过滤
            if lastMsg.fromId != LoginUser.shared().address {
                let dbUser = UserManager.shared().user(by: lastMsg.fromId)
                // 本地没有此用户则获取该用户信息
                if let _ = dbUser {
                    UserManager.shared().getNetUser(targetAddress: lastMsg.fromId)
                }
                if dbUser?.isShield == true {
                    return
                }
            }
            self.updateLstestInfo(msg: lastMsg, plusUnreadCount: msgArr.count)
        }
    }
    
    // 更新消息列表
    private func updateLstestInfo(msg: Message, plusUnreadCount count: Int? = nil, isSendFailed: Bool? = false) {
        var session = self.getOrCreateSession(id: msg.sessionId)
        
        // 有新会话记录，获取已存本地会话记录，不存在则保存临时会话记录到本地
        if self.getSingleLocalSession(by: msg.sessionId) == nil {
            self.insert(session: session)
            self.save(session: session)
        }
                
        session.timestamp = msg.datetime
        var latestInfo = NSMutableAttributedString.init(attributedString: msg.mesPreview)
        
        // 群聊且不是自己发送的消息
        if !session.isPrivateChat, msg.fromId != LoginUser.shared().address {
            
            var nameStr = msg.fromId.shortAddress
            if let member = GroupManager.shared().getDBGroupMember(with: msg.targetId.intEncoded, memberId: msg.fromId) {
                nameStr = member.contactsName
            } else if let user = UserManager.shared().user(by: msg.fromId) {
                nameStr = user.contactsName
            }
            let tempAttri = NSMutableAttributedString.init(string: nameStr + "：")
            tempAttri.append(latestInfo)
            
            switch msg.msgType {
            case .system, .unknown:
                FZMLog("显示原来的内容")
                //wjhTEST
            case .text:
                latestInfo = tempAttri
                // 群聊，是否有 @谁
                if msg.channelType == .group, let mentionIds = msg.mentionIds, mentionIds.count > 0 {
                    if mentionIds.contains(LoginUser.shared().address) || mentionIds.contains("ALL") {
                        session.hasAtMe = true
                    }
                }
                
                //wjhTEST
//                session.hasAtMe = true
            default:
                latestInfo = tempAttri
                
                //wjhTEST
//                session.hasAtMe = true
            }
            
            // 如果已存在‘[有人@我]’信息，则一直保留，直到被点击查看后重置
            //wjhTODO
            if session.hasAtMe {
                let tempAttriB = NSMutableAttributedString.init(string: atMe)
                tempAttriB.addAttributes([NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_DD5F5F], range: NSRange(location: 0, length: 6))
                tempAttriB.append(latestInfo)
                latestInfo = tempAttriB
            }
            
            session.latestInfo = latestInfo
            session.hasAtMe = false
            if let count = count, self.currentChatSession?.id != msg.sessionId {
                session.unreadCount = session.unreadCount + count
            }
            if let isSendFailed = isSendFailed {
                session.isSendFailed = isSendFailed
            }
            session.msgId = msg.msgId
            self.update(session: session)
        } else {
            session.latestInfo = latestInfo
            if let count = count, self.currentChatSession?.id != msg.sessionId {
                session.unreadCount = session.unreadCount + count
            }
            if let isSendFailed = isSendFailed {
                session.isSendFailed = isSendFailed
            }
            session.msgId = msg.msgId
            self.update(session: session)
        }
    }
}

//MARK: - DB

extension SessionManager {
    
    // 新会话插入会话数据源
    private func insert(session: Session) {
        if session.isPrivateChat {
            guard !privateSessions.contains(where: { $0 == session }) else { return }
            let newSessions = self.privateSessions + [session]
            self.privateSessions = newSessions
            
            self.refreshPrivateUnreadCount()
        } else {
            guard !groupSessions.contains(where: { $0 == session }) else { return }
            let newSessions = self.groupSessions + [session]
            self.groupSessions = newSessions
            
            self.refreshGroupUnreadCount()
        }
    }
    
    // 更新会话名称和头像
    func updateSessionNameAndImageURLStr(session sessionId: SessionID, name: String, imageURLStr: String)  {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.sessionName = name
        session.imageURLStr = imageURLStr
        self.update(session: session)
    }
    
    // 更新会话名称、头像和聊天服务器地址(群聊)
    func updateSessionNameAndImageURLStrAndChatServerUrl(session sessionId: SessionID, name: String, imageURLStr: String, chatServerUrl: String)  {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.sessionName = name
        session.imageURLStr = imageURLStr
        session.chatServerUrl = chatServerUrl
        self.update(session: session)
    }
    // 更新会话头像(群聊)
    func updateSessionAvatar(session sessionId:SessionID, avatarUrlStr: String) {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.imageURLStr = avatarUrlStr
        self.update(session: session)
    }
    
    // 更新会话名称
    func updateSessionName(session sessionId: SessionID, name: String)  {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.sessionName = name
        self.update(session: session)
    }
    
    // 更新会话聊天服务器地址
    func updateSessionChatServerUrl(session sessionId: SessionID, chatServerUrl: String)  {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.chatServerUrl = chatServerUrl
        self.update(session: session)
    }
    
    // 获取单个会话
    func getSingleLocalSession(by id: SessionID) -> Session? {
        guard let session = self.allSessions.filter({ $0.id == id }).first else { return nil }
        return session
    }
    
    // 获取单个会话，如不存在则创建临时会话记录
    func getOrCreateSession(id: SessionID) -> Session {
        if let session = self.getSingleLocalSession(by: id) {
            return session
        }
        
        let session = Session.init(id: id)
        return session
    }
    
    // 删除会话记录
    func deleteSession(id: SessionID) {
        if !id.isPersonChat {
            // 如不存在会话
            guard self.groupSessions.filter({ $0.id == id }).first != nil else { return }
            
            // 存在会话 删除记录
            let newSessions = self.groupSessions.filter({ $0.id != id })
            self.groupSessions = newSessions
        } else {
            // 如不存在会话
            guard self.privateSessions.filter({ $0.id == id }).first != nil else { return }
            
            // 存在会话 删除记录
            let newSessions = self.privateSessions.filter({ $0.id != id })
            self.privateSessions = newSessions
        }
        
        self.deleteInDB(session: id)
        
        //删除完聊天更新会话未读数
        self.refreshAllUnreadCount()
    }
    
    
    /// 加载本地所有私聊会话
    private func loadDBPrivateSessions() {
        guard LoginUser.shared().isLogin else { return }
        let sessions: [Session] = DBManager.shared().getObjects(fromTable: .session, constraintBlock: { (constraint) in
            constraint.condition = SessionDB.CodingKeys.isPrivateChat.is(true)
        }).compactMap { Session.init(with: $0) }
        
        // 黑名单用户过滤
        let filterSessions = sessions.compactMap { (session) -> Session? in
            if session.id.idValue != LoginUser.shared().address {
                if let dbUser = UserManager.shared().user(by: session.id.idValue), dbUser.isShield == true {
                    return nil
                }
            }
            return session
        }
        self.privateSessions = filterSessions
        
        self.refreshPrivateUnreadCount()
    }
    
    /// 加载本地所有群聊会话
    private func loadDBGroupSessions() {
        guard LoginUser.shared().isLogin else { return }
        let sessions: [Session] = DBManager.shared().getObjects(fromTable: .session, constraintBlock: { (constraint) in
            constraint.condition = SessionDB.CodingKeys.isPrivateChat.is(false)
        }).compactMap { Session.init(with: $0) }
        
        self.groupSessions = sessions
        
        self.refreshGroupUnreadCount()
    }
    
    /// 加载本地所有会话数据
    private func loadDBSessions() {
        // 加载本地所有私聊会话
        self.loadDBPrivateSessions()
        
        // 加载本地所有群聊会话
        self.loadDBGroupSessions()
    }
    
    /// 从数据库获取单条会话记录
    private func getDBSession(with msgId: String) -> Session? {
        let sessionDB: SessionDB? = DBManager.shared().getObjects(fromTable: .session, constraintBlock: { (constraint) in
            constraint.condition = SessionDB.CodingKeys.msgId.is(msgId)
            constraint.limit = 1
        }).first
        
        guard let sessionDB = sessionDB else { return nil }
        
        let session = Session.init(with: sessionDB)
        
        return session
    }
    
    /// 保存会话到数据库
    private func save(session: Session) {
        let sessionDB = SessionDB.init(with: session)
        DBManager.shared().insertOrReplace(intoTable: .session, list: [sessionDB])
    }
    
    private func deleteInDB(session: SessionID) {
        DBManager.shared().delete(fromTable: .session) { (constraint) in
            constraint.condition = SessionDB.Properties.id.is(session.idValue) && SessionDB.Properties.isPrivateChat.is(session.isPersonChat)
            constraint.limit = 1
        }
    }
    
    private func update(session: Session) {
        guard let oldSession = self.getSingleLocalSession(by: session.id) else { return }
        
        var updatePropertys = [PropertyConvertible]()
        
        if oldSession.hasAtMe != session.hasAtMe {
            updatePropertys.append(SessionDB.Properties.hasAtMe)
        }
        if oldSession.imageURLStr != session.imageURLStr {
            updatePropertys.append(SessionDB.Properties.imageURLStr)
        }
        if oldSession.sessionName != session.sessionName {
            updatePropertys.append(SessionDB.Properties.sessionName)
        }
        if !oldSession.latestInfo.isEqual(to: session.latestInfo) {
            updatePropertys.append(SessionDB.Properties.latestInfo)
        }
        if oldSession.timestamp != session.timestamp {
            updatePropertys.append(SessionDB.Properties.timestamp)
        }
        if oldSession.unreadCount != session.unreadCount {
            updatePropertys.append(SessionDB.Properties.unreadCount)
        }
        if oldSession.isSendFailed != session.isSendFailed {
            updatePropertys.append(SessionDB.Properties.isSendFailed)
        }
        if oldSession.msgId != session.msgId {
            updatePropertys.append(SessionDB.Properties.msgId)
        }
        if oldSession.chatServerUrl != session.chatServerUrl {
            updatePropertys.append(SessionDB.Properties.chatServerUrl)
        }
        guard !updatePropertys.isEmpty else { return }
        
        if session.isPrivateChat {// 私聊
            let newSessions = self.privateSessions.filter({ $0 != oldSession }) + [session]
            self.privateSessions = newSessions
            
            self.refreshPrivateUnreadCount()
        } else {// 群聊
            let newSessions = self.groupSessions.filter({ $0 != oldSession }) + [session]
            self.groupSessions = newSessions
            
            self.refreshGroupUnreadCount()
        }
        
        let sessionDB = SessionDB.init(with: session)
        DBManager.shared().update(table: .session, on: updatePropertys, with: sessionDB) { (constraint) in
            constraint.condition = SessionDB.Properties.id.is(sessionDB.id)
        }
    }
}

//MARK: - User Login

extension SessionManager {
    private func addLoginObserver() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogin), name: FZM_Notify_UserLogin, object: LoginUser.shared())
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogout), name: FZM_Notify_UserLogout, object: LoginUser.shared())
    }
    
    @objc private func userLogin() {
        self.loadDBSessions()
    }
    
    @objc private func userLogout() {
        self.clearSessions()
    }
}
