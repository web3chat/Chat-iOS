//
//  SessionManager.swift
//  chat
//
//  Created by fzm on 2021/1/13.
//

import Foundation
import WCDBSwift
import UIKit
import RxSwift

class SessionManager {
    
    /// 固定文本：[有人@我]
    private let atMe = L("[有人@我]")
    
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
    
    /// 会话数组会被多个线程读写（收消息 / 拉历史都在后台线程改），而直接读一个 `[Session]` 存储
    /// 属性时，数组头（指针 + 数量）可能被另一个线程改写一半 ⇒ 读到的数组是坏的，接着 filter / memcpy 就崩。
    /// 另外做会话列表的人要的是「列表变了」这个信号，不需要每次变更都通知一遍。
    /// 所以：底层存储加锁，通知按 runloop 合并。
    private let cacheLock = NSLock()
    private var privateSessionsStorage = [Session]()
    private var groupSessionsStorage = [Session]()
    private var allSessionsStorage = [Session]()
    private var privateSessionsEmitScheduled = false
    private var groupSessionsEmitScheduled = false
    
    private(set) var privateSessions: [Session] {
        get {
            cacheLock.lock(); defer { cacheLock.unlock() }
            return privateSessionsStorage
        }
        set {
            cacheLock.lock()
            privateSessionsStorage = newValue
            allSessionsStorage = newValue + groupSessionsStorage
            cacheLock.unlock()
            schedulePrivateSessionsEmit()
        }
    }
    
    private(set) var groupSessions: [Session] {
        get {
            cacheLock.lock(); defer { cacheLock.unlock() }
            return groupSessionsStorage
        }
        set {
            cacheLock.lock()
            groupSessionsStorage = newValue
            allSessionsStorage = privateSessionsStorage + newValue
            cacheLock.unlock()
            scheduleGroupSessionsEmit()
        }
    }
    
    private(set) var allSessions: [Session] {
        get {
            cacheLock.lock(); defer { cacheLock.unlock() }
            return allSessionsStorage
        }
        set {
            cacheLock.lock()
            allSessionsStorage = newValue
            cacheLock.unlock()
        }
    }
    
    /// 同一轮内最多通知一次（收消息 / 拉历史会连续改会话数组，每次变更都通知 = 列表反复重排 + reload）
    private func schedulePrivateSessionsEmit() {
        cacheLock.lock()
        let needSchedule = !privateSessionsEmitScheduled
        privateSessionsEmitScheduled = true
        cacheLock.unlock()
        guard needSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cacheLock.lock()
            let snapshot = self.privateSessionsStorage
            self.privateSessionsEmitScheduled = false
            self.cacheLock.unlock()
            self.privateSessionsSubject.onNext(snapshot)
        }
    }
    
    private func scheduleGroupSessionsEmit() {
        cacheLock.lock()
        let needSchedule = !groupSessionsEmitScheduled
        groupSessionsEmitScheduled = true
        cacheLock.unlock()
        guard needSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cacheLock.lock()
            let snapshot = self.groupSessionsStorage
            self.groupSessionsEmitScheduled = false
            self.cacheLock.unlock()
            self.groupSessionsSubject.onNext(snapshot)
        }
    }
    
    var currentChatSession: Session? = nil
    
    private init() {
        self.addLoginObserver()
        self.loadDBSessions()
        self.setRX()
    }
    
    private func setRX() {
        // 发消息订阅
        ChatManager.shared().sendMsgSubject.subscribe(onNext: {[weak self] (msg) in
            guard let self = self else { return }
            self.updateLstestInfo(msg: msg)
        }).disposed(by: self.bag)
        // 收消息订阅
        MultipleSocketManager.shared().receiveMsgsSubject.subscribe(onNext: {[weak self] (msgs) in
            guard let self = self else { return }
            self.handleReceive(msgs: msgs)
        }).disposed(by: self.bag)
    }
    
    // 清除缓存会话数据
    private func clearSessions() {
        self.allSessions = []
        self.privateSessions = []
        self.groupSessions = []
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
            // 还有消息则更新会话消息内容（这是从 DB 查出来的「最新一条」，必须照它更新）
            self.updateLstestInfo(msg: latestMsg, force: true)
        } else {
            // 没有消息记录则删除会话
            self.deleteSession(id: session.id)
        }
    }
    
    // 撤回消息后刷新会话预览（不排除任何消息，取 DB 中最新的）
    func refreshLastMsgInfo(session: Session) {
        if let latestMsg = ChatManager.shared().getLatestMsg(sessionId: session.id.idValue, exceptMsgId: "") {
            self.updateLstestInfo(msg: latestMsg, force: true)
        } else {
            self.deleteSession(id: session.id)
        }
    }
    
    /// 离开聊天页时用：按 DB 重算一次会话预览。
    /// 会话列表与聊天详情（`orderBy datetime desc, logId desc`）都取 DB 里最新的一条，
    /// 这样就不会出现「列表页看到的不是详情里最后一条」。
    /// ⚠️ 取不到消息时**保持原样**（不删会话），避免一次查询异常 / 消息还没落库就把会话从列表里抹掉。
    func syncLastMsgInfoWhenLeaveChat(session: Session) {
        guard self.getSingleLocalSession(by: session.id) != nil else { return }
        if let latestMsg = ChatManager.shared().getLatestMsg(sessionId: session.id.idValue, exceptMsgId: "") {
            self.updateLstestInfo(msg: latestMsg, force: true)
        }
    }
    
    // 更新会话记录显示的消息发送状态
    func updateMsgSendStatus(with msgId: String, sendSuccess: Bool) {
        // 更新数据库
        var sessionInDB = self.getDBSession(with: msgId)
        
        if sessionInDB != nil {
            sessionInDB!.isSendFailed = !sendSuccess
            self.update(session: sessionInDB!)
            
            // 发送回执会把 DB 里这条消息的 datetime 改写成**服务端时间**（发送时用的是本机时间），
            // 这里按 DB 重算一次会话预览：否则会话列表的「最后一条」（本机时间 / 旧内容）
            // 会与聊天详情（按 datetime 排序查库）里的最后一条错位（用户报的「聊天信息会乱」）。
            self.refreshLastMsgInfo(session: sessionInDB!)
            
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
                    // ⚠️ 必须是 continue 而不是 return：一批里只要有一个会话命中拉黑，
                    //    用 return 会把**后面同批所有会话**的消息全部跳过（漏未读、漏更新预览）。
                    continue
                }
            }
            self.updateLstestInfo(msg: lastMsg, plusUnreadCount: msgArr.count)
            // 未读数排查日志：同一批 msgId 如果出现两次，就是重复投递没被挡住
            FZMLog("【未读累加】session=\(lastMsg.sessionId.idValue) 本批=\(msgArr.count) 条 lastMsgId=\(lastMsg.msgId)")
        }
    }
    
    // 更新消息列表
    /// - Parameter force: 调用方已经把「DB 里最新的一条」查出来了（删除 / 撤回 / 回执刷新），
    ///   传 true 表示必须照着更新，不做新旧比较。
    private func updateLstestInfo(msg: Message, plusUnreadCount count: Int? = nil, isSendFailed: Bool? = false, force: Bool = false) {
        var session = self.getOrCreateSession(id: msg.sessionId)
        
        // 有新会话记录，获取已存本地会话记录，不存在则保存临时会话记录到本地
        let existingSession = self.getSingleLocalSession(by: msg.sessionId)
        if existingSession == nil {
            self.insert(session: session)
            self.save(session: session)
        }
        
        // ⚠️ 乱序 / 延迟到达的**旧消息不能把会话预览改旧**。
        // 以前这里无条件 `session.timestamp = msg.datetime`：只要来一条旧消息（重推、乱序、
        // 或自己刚发完还没收到回执），列表页显示的最后一条就不再是聊天详情里的最后一条 —— 即用户报的「聊天信息会乱」。
        // 判据：只在「已经有预览」且「这条消息更旧」时跳过预览更新；未读数 / 发送失败标记照常更新。
        let hasPreview = existingSession != nil && (!session.msgId.isEmpty || session.latestInfo.length > 0)
        // 自己刚发出的消息一定是最新的：本机时钟可能比服务端慢（消息时间戳会被 ack 改成服务端时间），
        // 不能拿时间戳把自己的消息挡掉
        let isMyOwnMessage = msg.fromId == LoginUser.shared().address
        if !force, hasPreview, !isMyOwnMessage, msg.datetime < session.timestamp {
            if let count = count, self.currentChatSession?.id != msg.sessionId {
                session.unreadCount = session.unreadCount + count
            }
            if let isSendFailed = isSendFailed {
                session.isSendFailed = isSendFailed
            }
            self.update(session: session)
            return
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
    
    // 更新会话自动删除选项（0=关闭 1=1天 2=3天 3=7天 4=30天 5=180天）
    func updateAutoDeleteOption(session sessionId: SessionID, option: Int) {
        guard var session = self.getSingleLocalSession(by: sessionId) else { return }
        session.autoDeleteOption = option
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
        // ★ 「小Y」（AI 客服）是会话列表渲染层的**虚拟行**：不写库、不进会话数据源，因此**不允许删除**。
        //   目前它本来就不在 `privateSessions` 里（下面的 guard 也会拦住），这里再显式拦一道，
        //   避免以后新增删除入口时不小心误删。
        guard id.idValue != AICustomerStore.entrySessionID else { return }
        
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
        
        // ★ 「群聊消息」列表里只放**真的有消息、而且自己还在群里**的群会话：
        //   - 没有任何消息的空会话（历史版本自动补出来的那种）不显示；
        //   - 已退群 / 被踢 / 群已解散（本地 grouplist 的 isInGroup == false）不显示。
        //   ⚠️ 只从内存数据源里过滤，**不删 DB 行**：该群来新消息时会走
        //      `updateLstestInfo` → `insert + save` 正常复活，不影响后续功能。
        let groupDBs: [GroupDB] = DBManager.shared().getObjects(fromTable: .grouplist, constraintBlock: nil)
        let leftGroupIds = Set(groupDBs.filter { !$0.isInGroup }.map { $0.id })
        let displayable = sessions.filter { (session) -> Bool in
            let hasMessage = !session.msgId.isEmpty || session.latestInfo.length > 0
            guard hasMessage else { return false }
            return !leftGroupIds.contains(session.id.idValue.intEncoded)
        }
        if displayable.count != sessions.count {
            FZMLog("群聊列表过滤：本地群会话 \(sessions.count) 条，隐藏 \(sessions.count - displayable.count) 条（无消息 / 已不在群）")
        }
        self.groupSessions = displayable
        
        // 清理「本地没有任何群信息」的残留群会话（跨账号串号），确认不在群里才删
        self.verifySessionsWithoutGroupInfo()
        
        self.refreshGroupUnreadCount()
    }
    
    // ⚠️ 曾经在这里有个 `restoreMissingGroupSessions()`：把「本地 grouplist 里还在、但没有会话行」
    //    的群无条件补回一条会话。它有两个副作用，用户 2026-10-27 明确报过：
    //    1. 用户长按「删除聊天」删掉的群会话，重启 App 就被它补回来；
    //    2. 补出来的会话没有任何消息预览（`Session(id:)` 的 latestInfo 为空）⇒ 列表里一条空白群聊。
    //    ⇒ 已移除。会话行真的丢了也不需要它：从通讯录进群会建会话，群里来新消息也会
    //      `updateLstestInfo` → `insert + save` 重建。**不要再加回来。**
    
    /// 校验「本地根本没有群信息」的群会话：向服务器确认一次，**服务器明确说不在群里（10015）**
    /// 才删掉会话。用于清理跨账号残留（切账号后另一个账号的群会话还留在列表里）。
    /// ⚠️ 网络失败 / 其它错误一律不动，避免像 2026-10-26 那次误删用户的群。
    private func verifySessionsWithoutGroupInfo() {
        guard LoginUser.shared().isLogin else { return }
        let groupDBs: [GroupDB] = DBManager.shared().getObjects(fromTable: .grouplist, constraintBlock: nil)
        let knownIds = Set(groupDBs.map { $0.id })
        let orphans = self.groupSessions.filter { !knownIds.contains($0.id.idValue.intEncoded) }
        guard !orphans.isEmpty else { return }
        for session in orphans {
            let groupId = session.id.idValue.intEncoded
            var serverUrl = session.chatServerUrl
            if serverUrl.isEmpty {
                serverUrl = LoginUser.shared().chatServerGroups.first?.value ?? ""
            }
            guard !serverUrl.isEmpty else { continue }
            GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: groupId, successBlock: { _ in
                // 确认在群里：群信息已落库，会话保留
                FZMLog("群会话校验通过（在群里）：groupId=\(groupId)")
            }, failureBlock: { error in
                if abs((error as NSError).code) == 10015 {
                    FZMLog("清理跨账号残留群会话：groupId=\(groupId)")
                    SessionManager.shared().deleteSession(id: session.id)
                }
            })
        }
    }
    
    /// 加载本地所有会话数据
    private func loadDBSessions() {
        // 清理历史版本遗留的 AI 客服数据（该功能已下线）
        self.cleanupLegacyAISessionData()
        
        // 加载本地所有私聊会话
        self.loadDBPrivateSessions()
        
        // 加载本地所有群聊会话
        self.loadDBGroupSessions()
        
        // 登录后异步预取私聊聊天记录（不阻塞主线程；详见 ChatManager+RecordPull.swift）
        // ⚠️ 必须延后到下一个 runloop：loadDBSessions() 会在 SessionManager.init() 里被调用，
        //    此处若同步访问 SessionManager.shared()（prefetchPrivateRecords 内部会读 allSessions）
        //    会重入正在初始化的 static ⇒ EXC_BREAKPOINT 崩溃。
        // ⚠️ 再延后 5s：等首屏（会话列表）渲染完、用户这波点击过去，再开始预取，
        //    避免预取的网络/落库和用户刚进 App 的操作抢资源。
        //    实测 1.5s 太早：用户在这几秒里点顶部「私聊 / 群聊」分段会卡住几秒
        //    （预取串行拉会话 + 回主线程写库，把主线程 / DB 一起占住）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // 重装 / 换机后本地会话表是空的 ⇒ 预取没有 targetId 可用，先按好友列表从服务端恢复
            // （内部会判断「本机是否真的没有私聊会话」，只会跑一次；详见 ChatManager+RecordPull.swift）
            ChatManager.shared().autoRecoverPrivateRecordsIfFreshInstall()
            ChatManager.shared().prefetchPrivateRecords()
        }
    }
    
    /// 清理老版本遗留的 AI 客服数据：会话记录、聊天记录与本地 AI 配置
    private func cleanupLegacyAISessionData() {
        let legacyAIAddress = "ai_assistant"
        
        // 该会话的聊天记录
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.is(legacyAIAddress)
        }
        
        // 会话本身
        DBManager.shared().delete(fromTable: .session) { (constraint) in
            constraint.condition = SessionDB.Properties.id.is(legacyAIAddress)
        }
        
        // 老版本 AI 配置（API Key / 模型 / 地址 / 思考模式等）
        ["kAIAPIKey", "kAIAPIURL", "kAIModelName", "kAIVisionModelName",
         "kAIReasoningModelName", "kAIUseReasoningMode"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
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
        if oldSession.autoDeleteOption != session.autoDeleteOption {
            updatePropertys.append(SessionDB.Properties.autoDeleteOption)
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
