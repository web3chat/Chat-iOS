//
//  ChatManager+AutoDelete.swift
//  chat
//
//  自动删除聊天记录引擎（本地兜底）
//  服务端为权威（/app/record/auto-delete/set·get），本地按 option 对应天数清理超期消息；
//  双方同步清理由服务端通过 ActionDeleteMessages 信令下发（见 handleDeleteMessagesInDB）。
//

import Foundation
import WCDBSwift

/// 群聊自动删除的「默认值是否已经应用过」标记。
///
/// 需求：群聊默认 7 天自动删除，但用户仍可在群详情里改成关闭/其它天数。
/// 单靠 `autoDeleteOption = 0` 区分不了「从没设置过」和「用户明确关闭」，
/// 所以按群 id 记一个标记：应用过默认值（或用户手动改过）之后就不再覆盖。
enum ChatAutoDeleteDefaults {

    private static let keyPrefix = "chat_group_autodelete_default_v1_"

    private static func key(groupId: String) -> String {
        return keyPrefix + groupId
    }

    static func isConfigured(groupId: String) -> Bool {
        guard !groupId.isEmpty else { return true }
        return UserDefaults.standard.bool(forKey: key(groupId: groupId))
    }

    static func markConfigured(groupId: String) {
        guard !groupId.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: key(groupId: groupId))
    }
}

extension ChatManager {

    /// 群聊自动删除默认 7 天：只对「还没有任何设置」的群生效一次。
    /// - 已经设过（1/3/7/30/180 天）的群不动；
    /// - 用户之后在群详情里选「关闭」会写标记，下次不会再被默认值覆盖。
    func applyGroupAutoDeleteDefaultIfNeeded() {
        guard FZM_EnableChatDeleteFeature else { return }
        guard LoginUser.shared().isLogin else { return }

        for session in SessionManager.shared().allSessions where !session.isPrivateChat {
            let groupId = session.id.idValue
            guard !groupId.isEmpty else { continue }
            guard !ChatAutoDeleteDefaults.isConfigured(groupId: groupId) else { continue }
            if session.autoDeleteOption == ChatAutoDeleteOption.off.rawValue {
                SessionManager.shared().updateAutoDeleteOption(session: session.id,
                                                               option: ChatAutoDeleteOption.day7.rawValue)
                FZMLog("群聊自动删除：默认开启 7 天 group=\(groupId)")
            }
            ChatAutoDeleteDefaults.markConfigured(groupId: groupId)
        }
    }

    /// 自动删除过期消息
    /// 遍历所有会话，对开启了自动删除（autoDeleteOption != off）的会话删除超期消息。
    /// 触发时机：App 启动、进入前台、Socket 重连成功后调用。
    func autoDeleteExpiredMessages() {
        guard FZM_EnableChatDeleteFeature else { return }
        guard LoginUser.shared().isLogin else { return }

        applyGroupAutoDeleteDefaultIfNeeded()

        let sessions = SessionManager.shared().allSessions
        let now = Date.timestamp// 毫秒时间戳

        for session in sessions {
            guard let option = ChatAutoDeleteOption(rawValue: session.autoDeleteOption),
                  option != .off else { continue }

            let cutoff = now - option.days * 86400000// 一天的毫秒数
            self.deleteExpiredMsgs(session: session, before: cutoff)
        }
    }

    /// 只清理某一个会话（进入群聊时用，不用等下次启动/回前台）
    func autoDeleteExpiredMessages(for session: Session) {
        guard FZM_EnableChatDeleteFeature, LoginUser.shared().isLogin else { return }

        applyGroupAutoDeleteDefaultIfNeeded()

        // 默认值可能刚写回，重新取一次会话，避免用旧的 option
        guard let fresh = SessionManager.shared().getSingleLocalSession(by: session.id) else { return }
        guard let option = ChatAutoDeleteOption(rawValue: fresh.autoDeleteOption),
              option != .off else { return }
        let cutoff = Date.timestamp - option.days * 86400000
        self.deleteExpiredMsgs(session: fresh, before: cutoff)
    }
    
    /// 删除指定会话中 before 时间点之前的消息
    /// - Parameters:
    ///   - session: 会话
    ///   - before: 毫秒时间戳，早于该时间的消息会被删除
    func deleteExpiredMsgs(session: Session, before: Int) {
        guard FZM_EnableChatDeleteFeature else { return }
        let sessionId = session.id.idValue
        let condition = MessageDB.Properties.sessionId.is(sessionId) && MessageDB.Properties.datetime < before
        
        // 查询超期消息数量（用于日志与判断）
        let expiredMsgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = condition
        }
        let expiredCount = expiredMsgs.count
        guard expiredCount > 0 else { return }
        
        // 删除数据库消息（DBManager 内部会自动联动删除 FTS 虚表记录）
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = condition
        }
        FZMLog("自动删除完成 sessionId: \(sessionId) 删除消息数: \(expiredCount)")
        
        // 刷新会话预览（若无剩余消息会自动删除会话记录）
        SessionManager.shared().refreshLastMsgInfo(session: session)
    }
    
    /// 手动删除本地消息（配合服务端 clean-private）
    /// 按时间范围删除本地消息并刷新会话/聊天页；clearAll 时清空整个会话
    /// - Parameters:
    ///   - session: 会话
    ///   - startTime: 起始毫秒时间戳（含）；nil 表示不限下界
    ///   - endTime: 结束毫秒时间戳（含）；nil 表示不限上界
    ///   - clearAll: 是否清空整个会话
    func deleteLocalMsgs(session: Session, startTime: Int?, endTime: Int?, clearAll: Bool) {
        let sessionId = session.id.idValue
        var condition = MessageDB.Properties.sessionId.is(sessionId)
        if !clearAll {
            if let startTime = startTime {
                condition = condition && MessageDB.Properties.datetime >= startTime
            }
            if let endTime = endTime {
                condition = condition && MessageDB.Properties.datetime <= endTime
            }
        }
        
        // 先取出将被删除的消息（用于通知聊天页同步 UI）
        let dbMsgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = condition
        }
        FZMLog("【删除记录】本地删除：session=\(sessionId) clearAll=\(clearAll) start=\(startTime.map { String($0) } ?? "-") end=\(endTime.map { String($0) } ?? "-") 命中=\(dbMsgs.count) 条")
        guard !dbMsgs.isEmpty else { return }
        let msgs = dbMsgs.compactMap { Message(with: $0) }
        
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = condition
        }
        // ⚠️ 删完回查一次：删不掉 / 条件写错时，日志能直接看出来
        let leftRows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = condition
        }
        FZMLog("【删除记录】本地删除后回查：同条件剩余=\(leftRows.count) 条（应为 0）")
        
        // 通知聊天页移除（若正在查看该会话）
        FZM_NotificationCenter.post(name: FZM_Notify_DeleteChatMsgs, object: (session.id, msgs))
        // 刷新会话预览（若无剩余消息会自动删除会话记录）
        SessionManager.shared().refreshLastMsgInfo(session: session)
    }
}
