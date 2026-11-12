//
//  ChatManager+Unparsed.swift
//  chat
//
//  解密失败消息的「密文暂存 + 点击重试」。
//
//  背景（用户 2026-11-04 反馈）：群消息偶尔会因为密钥过期/未同步而解出**空 Data**，
//  而 `PbMsg_TextMsg.init(serializedData: Data())` 是合法的 ⇒ 落库成 `{"content":""}`，
//  界面上是一个永远空的气泡，且原始密文丢了就再也救不回来。
//
//  这里在解密失败时把**原始密文**存下来，用户点那条「该消息内容无法显示」时：
//    ① 重新拉会话密钥（群密钥 / 对方公钥）解一次
//    ② 还不行就用**发送者的个人公钥**再解一次（群聊常见）
//    ③ 解出来了就回填消息体并刷新界面，然后把密文记录删掉
//

import Foundation
import WCDBSwift

/// 解密失败、暂存原始密文，等待重试的消息
final class UnparsedMsgDB: TableCodable {
    /// 消息 mid，主键
    var msgId: String
    /// 服务端 logId
    var logId: Int
    /// 0 私聊 1 群聊
    var channelType: Int
    /// pb 里的 msgType 原始值（重试解析要用）
    var msgType: Int
    /// 发送者
    var fromId: String
    /// 会话目标（群聊是群 id）
    var targetId: String
    /// 原始密文
    var cipher: Data
    /// 落库时间（毫秒）
    var createdAt: Int

    enum CodingKeys: String, CodingTableKey {
        typealias Root = UnparsedMsgDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)

        case msgId, logId, channelType, msgType, fromId, targetId, cipher, createdAt

        static var columnConstraintBindings: [UnparsedMsgDB.CodingKeys: ColumnConstraintBinding]? {
            return [msgId: ColumnConstraintBinding.init(isPrimary: true)]
        }
    }

    init(msgId: String, logId: Int, channelType: Int, msgType: Int,
         fromId: String, targetId: String, cipher: Data, createdAt: Int) {
        self.msgId = msgId
        self.logId = logId
        self.channelType = channelType
        self.msgType = msgType
        self.fromId = fromId
        self.targetId = targetId
        self.cipher = cipher
        self.createdAt = createdAt
    }
}

extension ChatManager {

    /// 解密失败时把原始密文存下来（同一条消息重复失败只保留一条）
    func saveUnparsedMsg(_ pbMsg: PbMsg_msg, cipher: Data) {
        guard !cipher.isEmpty, !pbMsg.msgID.isEmpty else { return }
        let row = UnparsedMsgDB(
            msgId: pbMsg.msgID,
            logId: Int(pbMsg.logID),
            channelType: Int(pbMsg.channelType),
            msgType: Int(pbMsg.msgType.rawValue),
            fromId: pbMsg.from,
            targetId: pbMsg.target,
            cipher: cipher,
            createdAt: Date.timestamp)
        DBManager.shared().insertOrReplace(intoTable: .unparsedMsg, list: [row])
        FZMLog("【解密失败】已暂存密文，可点击气泡重试 msgId=\(row.msgId) 密文=\(cipher.count)B")
    }

    func unparsedMsg(msgId: String) -> UnparsedMsgDB? {
        let rows: [UnparsedMsgDB] = DBManager.shared().getObjects(fromTable: .unparsedMsg) { constraint in
            constraint.condition = UnparsedMsgDB.Properties.msgId.is(msgId)
            constraint.limit = 1
        }
        return rows.first
    }

    /// 一轮离线消息**全部收到之后**统一重试所有解密失败的消息。
    /// ⚠️ 不要在收到消息的当下就重试：重拉密钥要等网络，会把 socket 线程/同步节奏拖乱。
    func retryAllUnparsedMsgs() {
        let rows: [UnparsedMsgDB] = DBManager.shared().getObjects(
            fromTable: .unparsedMsg, constraintBlock: nil)
        guard !rows.isEmpty else { return }
        FZMLog("【解密失败】同步结束，开始重试 \(rows.count) 条")

        var remaining = rows.map { $0.msgId }
        func next() {
            guard let msgId = remaining.first else { return }
            remaining.removeFirst()
            self.retryDecryptUnparsed(msgId: msgId) { _ in
                next()
            }
        }
        next()
    }

    /// 点「该消息内容无法显示」时调用：依次尝试【会话密钥】→【发送者个人公钥】。
    /// - Parameters:
    ///   - refreshKeys: 是否强制从网络刷新密钥。
    ///     自动批量重试（`retryAllUnparsedMsgs`）传 `false`，用本地缓存、省请求；
    ///     用户主动点击传 `true` —— 否则本地缓存里就是当初解不开的那把旧密钥，重试没有意义。
    ///   - completion: 成功 = true（已回填消息体并发通知刷新界面）
    func retryDecryptUnparsed(msgId: String, refreshKeys: Bool = false, completion: @escaping (Bool) -> Void) {
        guard let row = self.unparsedMsg(msgId: msgId) else {
            completion(false)
            return
        }

        let isPerson = row.channelType == 0
        let me = LoginUser.shared().address
        // 私聊：别人发来的消息用**发送者(from)**公钥解；自己从其它端发出的消息要用**对方(target)**公钥解。
        // （收消息链路 `SocketManager.getInvolvedUsersInfo` 也是这么选 key 的，重试必须保持一致）
        let personKeyOwner = (row.fromId == me && !row.targetId.isEmpty) ? row.targetId : row.fromId
        let sessionKeyOwner = isPerson ? personKeyOwner : row.targetId
        let senderKeyOwner = isPerson ? personKeyOwner : row.fromId

        /// 用暂存记录还原一个 pb 消息（原始 msgType 存在 `unparsed_msg_cipher` 里）
        func makePb(_ data: Data) -> PbMsg_msg {
            var pb = PbMsg_msg()
            pb.channelType = Int32(row.channelType)
            pb.logID = Int64(row.logId)
            pb.msgID = row.msgId
            pb.from = row.fromId
            pb.target = row.targetId
            pb.msgType = PbMsg_MsgType.init(rawValue: row.msgType) ?? .UNRECOGNIZED(row.msgType)
            pb.msg = data
            return pb
        }

        /// 解密成功（或确认是明文）才回填；返回是否真正写回成功
        @discardableResult
        func apply(_ data: Data, key: String) -> Bool {
            guard !data.isEmpty else { return false }
            let msg = Message(pbMsg: makePb(data), publickey: key)
            guard !msg.msgType.isEmptyText, !msg.msgType.isUnknown else {
                FZMLog("【解密失败】重试解出的正文为空/无法识别 msgId=\(msgId)")
                return false
            }
            // 回填消息体（正文/图片地址等），并让聊天页刷新这一条
            self.update(mes: msgId, with: msg.msgType)
            DBManager.shared().delete(fromTable: .unparsedMsg) { constraint in
                constraint.condition = UnparsedMsgDB.Properties.msgId.is(msgId)
            }
            FZMLog("【解密失败】重试成功 msgId=\(msgId) 解出=\(data.count)B")
            FZM_NotificationCenter.post(name: FZM_Notify_ChatMsgContentUpdated, object: msgId)
            completion(true)
            return true
        }

        /// 用某把密钥解一次；密钥为空 / 解密失败时再尝试**明文兜底**
        /// （服务端生成的群通知 / 系统消息没有群密钥，下发的是明文）。
        func attempt(_ key: String) -> Bool {
            if !key.isBlank {
                let decrypted = ChatManager.decryptMsgData(
                    row.cipher, publickey: key, isEncryptPersionChatData: isPerson)
                if !ChatManager.isMsgDecryptFailed(cipher: row.cipher, decrypted: decrypted),
                   apply(decrypted, key: key) {
                    return true
                }
            }
            guard Message.isUsablePlaintextPayload(makePb(row.cipher), publickey: key) else {
                return false
            }
            return apply(row.cipher, key: key)
        }

        func fallbackSenderKeyFromCache() {
            ChatManager.getPublickey(by: senderKeyOwner, isGetUserKey: true) { senderKey in
                if attempt(senderKey) { return }
                FZMLog("【解密失败】发送者公钥重试仍失败 msgId=\(msgId)")
                completion(false)
            }
        }

        /// ② 兜底：发送者的个人公钥。
        /// 私聊的「会话密钥」本来就是发送者公钥，`loadSessionKey` 已经刷新过并写回本地；
        /// 群聊的发送者公钥只是兜底，没必要再强制走网络。
        func trySenderKey() {
            fallbackSenderKeyFromCache()
        }

        func attemptSessionKey(_ key: String) {
            if attempt(key) { return }
            FZMLog("【解密失败】会话密钥重试仍失败 msgId=\(msgId)，改用发送者公钥")
            trySenderKey()
        }

        /// ① 会话密钥（群密钥 / 对方公钥）。
        /// 自动重试用缓存；用户主动重试时强制走网络刷新 —— `getGroupKey` / `getUserPublickey`
        /// 命中本地数据时会直接返回旧密钥，重试就永远解不开。
        func loadSessionKey() {
            guard refreshKeys else {
                ChatManager.getPublickey(by: sessionKeyOwner, isGetUserKey: isPerson) { key in
                    attemptSessionKey(key)
                }
                return
            }
            if isPerson {
                UserManager.shared().getNetUser(targetAddress: senderKeyOwner, successBlock: { user in
                    attemptSessionKey(user.publicKey ?? "")
                }, failureBlock: { _ in
                    ChatManager.getPublickey(by: sessionKeyOwner, isGetUserKey: true) { key in
                        attemptSessionKey(key)
                    }
                })
                return
            }
            let session = SessionManager.shared().getSingleLocalSession(by: .group(row.targetId))
            let serverUrl = (session?.chatServerUrl.isEmpty == false)
                ? (session?.chatServerUrl ?? "")
                : (LoginUser.shared().chatServerGroups.first?.value ?? "")
            guard let groupId = Int(row.targetId), !serverUrl.isEmpty else {
                ChatManager.getPublickey(by: sessionKeyOwner, isGetUserKey: false) { key in
                    attemptSessionKey(key)
                }
                return
            }
            GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: groupId, successBlock: { group in
                attemptSessionKey(group.key ?? "")
            }, failureBlock: { _ in
                ChatManager.getPublickey(by: sessionKeyOwner, isGetUserKey: false) { key in
                    attemptSessionKey(key)
                }
            })
        }

        loadSessionKey()
    }
}
