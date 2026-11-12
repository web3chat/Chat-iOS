//
//  MessageManager.swift
//  chat
//
//  Created by fzm on 2021/1/18.
//

import UIKit
import WCDBSwift
import TZImagePickerController
import SwiftUI

class ChatManager {
    private static let sharedInstance = ChatManager.init()
    static func shared() -> ChatManager { return sharedInstance }
    private let bag = DisposeBag.init()
    
    private let sendMsgQueue = DispatchQueue(label: "com.sendMsgQueue")

    /// 私聊「删除」改走撤回的 logId 集合：撤回成功后本地**直接删掉**这条消息，
    /// 不生成「撤回了一条消息」的提示（用户 2026-10-19 要求）。
    /// ⚠️ 只在主队列读写：Provider 回调队列是 .main，撤回通知 observer 也注册在 .main。
    private var silentRevokeDeleteLogIds = Set<Int>()
    
    private(set) lazy var sendMsgSubject  = PublishSubject<Message>.init()
    private(set) lazy var sendMsgAndUploadFailedSubject = PublishSubject<String>.init()// 上传文件导致消息发送失败结果订阅

    /// 大图长按「转发图片」的待发送图片（选好会话后暂存，进入该会话时由 ChatVC 取走发送）
    private var pendingShareImage: (sessionId: String, image: UIImage)?

    /// 记下待发送的图片（复用聊天里那套压缩/上传/加密，不另写一份发送逻辑）
    func setPendingShareImage(_ image: UIImage, for sessionId: SessionID) {
        pendingShareImage = (sessionId.idValue, image)
    }

    /// 取走并清空（只有目标会话能取到）
    func consumePendingShareImage(for sessionId: SessionID) -> UIImage? {
        guard let pending = pendingShareImage, pending.sessionId == sessionId.idValue else { return nil }
        pendingShareImage = nil
        return pending.image
    }

    /// 待转发的消息（选好会话后暂存，进入该会话时由 ChatVC 取走发送）
    private var pendingForwardMessages: (sessionId: String, msgs: [Message])?

    /// 记下待转发的消息（逐条转发 / 合并转发都走这里）
    func setPendingForwardMessages(_ msgs: [Message], for sessionId: SessionID) {
        pendingForwardMessages = (sessionId.idValue, msgs)
    }

    /// 取走并清空（只有目标会话能取到）
    func consumePendingForwardMessages(for sessionId: SessionID) -> [Message]? {
        guard let pending = pendingForwardMessages, pending.sessionId == sessionId.idValue else {
            return nil
        }
        pendingForwardMessages = nil
        return pending.msgs
    }

    /// 待发送的红包消息（从「群成员/好友详情 → 红包」发的专属红包：链上已经发完了，
    /// 进群会话时由 ChatVC 取走发消息，复用聊天里那套红包消息逻辑）
    private var pendingRedPacket: (sessionId: String, coinName: String, txHash: String, remark: String, packetType: IMRedPacketType)?

    func setPendingRedPacket(coinName: String, txHash: String, remark: String, packetType: IMRedPacketType, for sessionId: SessionID) {
        pendingRedPacket = (sessionId.idValue, coinName, txHash, remark, packetType)
    }

    /// 取走并清空（只有目标会话能取到）
    func consumePendingRedPacket(for sessionId: SessionID) -> (coinName: String, txHash: String, remark: String, packetType: IMRedPacketType)? {
        guard let pending = pendingRedPacket, pending.sessionId == sessionId.idValue else { return nil }
        pendingRedPacket = nil
        return (pending.coinName, pending.txHash, pending.remark, pending.packetType)
    }

    /// 待发送的转账消息（从「好友详情 → 转账」发的转账：链上已经转完了，
    /// 进会话时由 ChatVC 取走发消息，复用聊天里那套转账消息逻辑）
    private var pendingTransfer: (sessionId: String, coinName: String, txHash: String)?

    func setPendingTransfer(coinName: String, txHash: String, for sessionId: SessionID) {
        pendingTransfer = (sessionId.idValue, coinName, txHash)
    }

    /// 取走并清空（只有目标会话能取到）
    func consumePendingTransfer(for sessionId: SessionID) -> (coinName: String, txHash: String)? {
        guard let pending = pendingTransfer, pending.sessionId == sessionId.idValue else { return nil }
        pendingTransfer = nil
        return (pending.coinName, pending.txHash)
    }
    
    private init() {
        self.setRX()
        self.setRevokeObserver()
        self.setDeleteObserver()
    }
    
    /// 注册全局删除聊天记录通知监听（多端同步，不依赖 ChatVC 状态，确保 DB 总能更新）
    private func setDeleteObserver() {
        guard FZM_EnableChatDeleteFeature else { return }// 功能未接入，关闭
        // queue 必须为主队列：该通知在 socket 常驻线程 post，observer 会在 post 线程同步执行；
        // 回调内部会一路调进 SessionManager 数据源（privateSessions/groupSessions 数组读写），
        // 与主线程并发读写会触发 Swift 运行时断言（崩溃栈：__assertionFailure ← 通知 observer）。
        // 改为主队列后与其它会话操作串行，且 ChatManager 先于 ChatVC 注册，DB 更新仍先于 UI 刷新执行。
        FZM_NotificationCenter.addObserver(
            forName: FZM_Notify_DeleteMessages,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let pbMsg = notification.object as? PbMsg_ActionDeleteMessages else { return }
            
            self.handleDeleteMessagesInDB(pbMsg: pbMsg)
        }
    }
    
    /// 注册全局撤回通知监听（不依赖 ChatVC 状态，确保 DB 总能更新）
    private func setRevokeObserver() {
        // queue 必须为主队列：该通知在 socket 常驻线程 post，observer 会在 post 线程同步执行；
        // 回调内部 handleRevokeInDB 会写 DB 并刷新 SessionManager 会话数据源，
        // 与主线程并发读写会触发 Swift 运行时断言（崩溃栈：__assertionFailure ← 通知 observer）。
        // 改为主队列后与其它会话操作串行，且 ChatManager 先于 ChatVC 注册，DB 更新仍先于 UI 刷新执行。
        FZM_NotificationCenter.addObserver(
            forName: FZM_Notify_RevokeMsg,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let pbMsg = notification.object as? PbMsg_ActionRevoke else { return }
            
            let logId = Int(pbMsg.logID)
            let operatorId = pbMsg.operator

            // 私聊「删除」走的是撤回接口：撤回成功后本地要**静默删除原消息**，
            // 不能把气泡改写成「你撤回了一条消息」（用户 2026-10-19 要求）
            if self.consumeSilentRevokeDelete(logId: logId) {
                self.deleteRevokedMessageSilently(logId: logId)
                return
            }

            // 阅后即焚焚毁（reason == burned）：气泡换「已阅后焚毁」，与普通撤回区分
            if pbMsg.reason == .burned {
                if let updatedMsg = self.handleBurnInDB(logId: logId) {
                    let session = SessionManager.shared().getOrCreateSession(id: updatedMsg.sessionId)
                    SessionManager.shared().refreshLastMsgInfo(session: session)
                }
                return
            }

            // 客户端自行判断是否自己撤回（不依赖服务端 self_p 字段）
            let isSelfRevoke = (operatorId == LoginUser.shared().address)
            
            // 更新数据库中的消息
            if let updatedMsg = self.handleRevokeInDB(logId: logId, operatorId: operatorId, isSelfRevoke: isSelfRevoke) {
                // 更新会话列表预览
                let session = SessionManager.shared().getOrCreateSession(id: updatedMsg.sessionId)
                SessionManager.shared().refreshLastMsgInfo(session: session)
            }
        }
    }
    
    private func setRX() {
        self.sendMsgAndUploadFailedSubject.subscribe(onNext: {[weak self] (msgId) in
            guard let self = self else { return }
            self.update(mes: msgId, with: .failed)

            // 更新会话列表消息状态
            SessionManager.shared().updateMsgSendStatus(with: msgId, sendSuccess: false)
        }).disposed(by: self.bag)

        // 消息发送结果订阅
        MultipleSocketManager.shared().sendMsgStatusSubject.subscribe(onNext: {[weak self] (sendMsgStatus) in
            guard let self = self else { return }
            switch sendMsgStatus {
            case .failed(let msgId):
                self.update(mes: msgId, with: .failed)

                // 更新会话列表消息状态
                SessionManager.shared().updateMsgSendStatus(with: msgId, sendSuccess: false)
            case .success(let data):
                self.update(mes: data.msgId, with: .sent, logId: data.logId, datatime: data.datetime)

                // 更新会话列表消息状态
                SessionManager.shared().updateMsgSendStatus(with: data.msgId, sendSuccess: true)
            case .delivered(let logIds):
                logIds.forEach { logId in
                    self.update(msgWithLogId: String(logId), with: .delivered)
                }
            }
        }).disposed(by: self.bag)

        // 收到消息订阅
        MultipleSocketManager.shared().receiveMsgsSubject.subscribe(onNext: {[weak self] (msgs) in
            guard let self = self else { return }
            self.save(msgs)
        }).disposed(by: self.bag)
    }
}

extension ChatManager {
    
    func send(msg: Message, chatServerUrl: String) {
        self.save([msg])
        
        self.sendMsgSubject.onNext(msg)// 更新会话列表显示消息数据
        
        // 先获取对方的公钥/群聊密钥
        sendMsgQueue.async {
            ChatManager.getPublickey(by: msg.targetId, isGetUserKey: msg.sessionId.isPersonChat) { (pubkey) in
                // 公钥/群密钥拿不到时消息会加密失败/被服务端拒收，必须留痕
                // （多选分享时最典型：4 个群只有 1 个发出去，就是有的群密钥没查到）
                if pubkey.finalKey.isBlank {
                    FZMLog("【发送】公钥/群密钥为空 target=\(msg.targetId) msgType=\(msg.msgType.intValue) msgId=\(msg.msgId) serverUrl=\(chatServerUrl)")
                }
                self.sendSocketMsg(msg: msg, chatServerUrl: chatServerUrl, publickey: pubkey.finalKey)
            }
        }
    }
    
    private func sendSocketMsg(msg: Message, chatServerUrl: String, publickey: String) {
        switch msg.msgType {
        case .text, .transfer, .redPacket, .contactCard, .system, .forward:
            MultipleSocketManager.shared().send(msg: msg, chatServerUrl: chatServerUrl, publickey:publickey)
        case .image:
            FZMLog("图片消息")
            msg.msgType.imageAsync { image in
                if let image = image {
                    guard let jpegData = image.jpegData(compressionQuality: 0.6) else {
                        self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                        return
                    }
                    let imgData = msg.gifData ?? jpegData
                    
                    self.uploadFileRequest(fileData: imgData, msg: msg, publickey: publickey) { (url) in
                        var message = msg
                        let msgType = Message.MsgType.init(image: url, cacheKey: msg.msgType.cachekey, width: Double(image.size.width), height: Double(image.size.height))
                        message.msgType = msgType
                        self.update(mes: message.msgId, with: msgType)
                        
                        MultipleSocketManager.shared().send(msg: message, chatServerUrl: chatServerUrl, publickey:publickey)
                    } failure: { _ in
                        FZMLog("发送图片消息 上传图片失败")
                        self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                    }
                } else {
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                }
            }
        case .video:
            FZMLog("视频消息")
            guard let mediaUrl = msg.mediaUrl else {
                FZMLog("发送视频消息 缺少视频文件路径")
                self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                return
            }
            guard let data = try? Data.init(contentsOf: mediaUrl) else {
                FZMLog("发送视频消息 读取视频文件失败")
                self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                return
            }
            msg.msgType.imageAsync { image in
                if let image = image {
                    self.uploadFileRequest(fileData: data, msg: msg, publickey: publickey) { (url) in
                        var message = msg
                        let msgType = Message.MsgType.init(video: url, cacheKey: msg.msgType.cachekey, duration: msg.msgType.duration ?? 0, width: Double(image.size.width), height: Double(image.size.height))
                        message.msgType = msgType
                        self.update(mes: message.msgId, with: msgType)
                        
                        MultipleSocketManager.shared().send(msg: message, chatServerUrl: chatServerUrl, publickey:publickey)
                    } failure: { _ in
                        FZMLog("发送视频消息 上传视频失败")
                        self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                    }
                } else {
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                }
            }
        case .file:
            FZMLog("文件消息")
            
            if msg.fileUrl != nil {
                guard let fileData = try? Data.init(contentsOf: URL.init(fileURLWithPath: msg.fileUrl)) else {
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                    return
                }
                self.uploadFileRequest(fileData: fileData, msg: msg, publickey: publickey) { (url) in
                    var message = msg
                    let msgType = Message.MsgType.init(file: url, cacheKey: msg.msgType.cachekey, name: (msg.fileUrl as NSString).lastPathComponent, md5: OSSUtil.fileMD5String(msg.fileUrl), size: Double(fileData.count))
                    message.msgType = msgType
                    self.update(mes: message.msgId, with: msgType)
                    
                    MultipleSocketManager.shared().send(msg: message, chatServerUrl: chatServerUrl, publickey:publickey)
                } failure: { _ in
                    FZMLog("发送文件消息 上传文件失败")
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                }
            }
            
            
            
//            if ((msg.msgType.fileUrl?.isBlank) != nil) {
//                MultipleSocketManager.shared().send(msg: msg, chatServerUrl: chatServerUrl, publickey:publickey)
//                return
//            }
//
//            OSS.shared().uploadFile(filePath: FZMLocalFileClient.shared().getFilePath(with: .file(fileName: (msg.msgType.localFilePath! as NSString).lastPathComponent))) { (progress) in
//                IMNotifyCenter.shared().postMessage(event: .uploadProgress(msgSendID: msg.msgId, progress: progress))
//            } success: { (url) in
//                let message = msg
////                let msgType = Message.MsgType.init(file: url, cacheKey: cacheKey, name: (filePath as NSString).lastPathComponent, md5: OSSUtil.fileMD5String(filePath), size: Double(data.count))
////                message.msgType = msgType
////                self.update(mes: message.msgId, with: msgType)
//
//                MultipleSocketManager.shared().send(msg: message, chatServerUrl: chatServerUrl, publickey:publickey)
//            } failure: { (error) in
//                FZMLog("send photoMsg OSS uploadImage error---\(error)")
//                self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
//            }
        case .audio:
            FZMLog("语音消息")
//            guard let data = FZMLocalFileClient.shared().readData(fileName: .amr(fileName: msg.msgType.fileUrl!)) else { return }
            if msg.audioUrl != nil {
                guard let audioData = try? Data.init(contentsOf: URL.init(fileURLWithPath: msg.audioUrl)) else {
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                    return
                }
                self.uploadFileRequest(fileData: audioData, msg: msg, publickey: publickey) { (url) in
                    var message = msg
                    var duration: Double = 0
                    switch msg.kind {
                    case .audio(let audioItem):
                        duration = audioItem.duration ?? 0
                    default:
                        duration = 0
                    }
                    let msgType = Message.MsgType.init(audio: url, duration: duration, cacheKey: msg.msgType.cachekey, width: 0, height: 0)
                    message.msgType = msgType
                    self.update(mes: message.msgId, with: msgType)
                    
                    MultipleSocketManager.shared().send(msg: message, chatServerUrl: chatServerUrl, publickey:publickey)
                } failure: { _ in
                    FZMLog("发送语音消息 上传语音失败")
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                }
            }
            
            
    
//            OSS.shared().uploadVoice(file: data) { (url) in
//                var message = msg
//                let msgType = Message.MsgType.init(image: url, cacheKey: msg.msgType.cachekey, width: 0, height: 0)
//                message.msgType = msgType
//                self.update(mes: message.msgId, with: msgType)
//
//                MultipleSocketManager.shared().send(msg: message, chatServerUrl: chatServerUrl, publickey:publickey)
//            } failure: { (error) in
//                self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
//            }

        default:
            FZMLog("暂不支持")
        }
    }
}

//MARK: - DB

extension ChatManager {
    
    func searchMsg(searchString: String, sessionId: String? = nil) -> [Message] {
        let objects: [VirtualMessageDB] = DBManager.shared().getObjects(fromTable: .virtualMessage, constraintBlock: { (constraint) in
            if let targetId = sessionId {
                constraint.condition = VirtualMessageDB.Properties.sessionId == targetId && VirtualMessageDB.Properties.content.match(searchString + "*")
            } else {
                constraint.condition = VirtualMessageDB.Properties.content.match(searchString + "*")
            }
        })
        
        guard !objects.isEmpty else { return [Message]() }
        
        let msgs: [Message] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.in(objects.compactMap { $0.msgId }) || MessageDB.Properties.logId.in(objects.compactMap {$0.msgId})
            constraint.orderBy = [MessageDB.Properties.datetime.asOrder(by: .descending), MessageDB.Properties.logId.asOrder(by: .descending)]
        }).compactMap { $0.msgId != sessionId ? Message.init(with: $0) : nil }
        
        return msgs
    }
    
    // 获取所有消息中最近的一条（websocket用）
    func getLatestMsg() -> Message? {
        let latestMsg: Message? = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.logId.isNotNull()
            constraint.orderBy = [MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = 1
        }).compactMap { Message.init(with: $0)}.first
        return latestMsg
    }
    
    /// 某台聊天服务器「本地已有」的最大 logId —— 作为该服务器 `syncMsg` 的断点。
    /// ⚠️ 不能用全库最大 logId（`getLatestMsg()`）：多服务器 / 官方群服务器场景下，
    ///    另一台服务器更大的 logId 会被当成这台服务器的断点 ⇒ 服务端认为「没有新消息」，
    ///    这台服务器上的群聊离线消息就永远补不回来（群聊没有服务端记录接口可回补）。
    func getLatestLogId(serverUrl: String) -> Int {
        let globalMax = getLatestMsg()?.logId ?? 0
        let target = MultipleSocketManager.serverKey(serverUrl)
        guard !target.isEmpty else { return globalMax }
        
        let sessions: [SessionDB] = DBManager.shared().getObjects(fromTable: .session, constraintBlock: { (constraint) in
            constraint.condition = SessionDB.CodingKeys.chatServerUrl.isNotNull()
        })
        let sessionIds = sessions.filter {
            MultipleSocketManager.serverKey($0.chatServerUrl) == target
        }.map { $0.id }
        guard !sessionIds.isEmpty else {
            // 本地没有「这台服务器上的会话」（老数据 / 私聊为主）时无从推断，
            // 退回全库最大值 = 原有行为，避免从 0 开始把服务端历史整体重拉。
            FZMLog("syncMsg 断点：服务器 \(target) 没有可用的本地会话，回退为全库最大 logId=\(globalMax)")
            return globalMax
        }
        
        let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.in(sessionIds) && MessageDB.CodingKeys.logId.isNotNull()
            constraint.orderBy = [MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = 1
        })
        let serverMax = rows.first?.logId ?? 0
        // 🔴 兜底：按服务器查到的断点可能比全库最大还小 —— 某群会话的 chatServerUrl 没匹配上时，
        //    这个群的消息不被计入断点，syncMsg 会从偏小的断点拉、把中间的消息跳过
        //    （用户 2026-11-03「发了四五十条只有 20 条」：断点 850346780808712192 比
        //    实际 850347292840955904 小 2 分钟，中间这段永远补不上）。
        //    ⇒ 取 max，保证断点不低于全库最大，绝不跳过任何已落库消息。
        let finalMax = max(serverMax, globalMax)
        if finalMax != serverMax {
            FZMLog("syncMsg 断点：服务器 \(target) 按会话查到 \(serverMax) < 全库最大 \(globalMax)，兜底用 \(finalMax)")
        }
        return finalMax
    }

    /// 某个会话「本地已有」的最大 logId。
    /// 进入会话时用它把**服务器级**同步断点回退回去，补拉「断点已越过、但本地没落库」的消息
    /// （断点按服务器推进，别的会话的新消息会把断点推过这条消息的 logId）。
    func getLatestLogId(sessionId: String) -> Int {
        let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.is(sessionId) && MessageDB.CodingKeys.logId.isNotNull()
            constraint.orderBy = [MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = 1
        })
        return rows.first?.logId ?? 0
    }
    
    func getHistoryMsgs(session: Session, from msgId: String, count: Int = 20, includeCurMsgFlg: Bool = false) -> [Message] {
        
        let sessionId = session.id.idValue
        var fromMsgDB: MessageDB?
        if msgId.isEmpty {
            fromMsgDB = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
                constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId)
                constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending)]
                constraint.limit = 1
            }).first
        } else {
            fromMsgDB = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
                constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId) && MessageDB.CodingKeys.msgId.is(msgId)
                constraint.limit = 1
            }).first
        }
        
        guard let datetime = fromMsgDB?.datetime else { return [] }
        
        // 向前翻页用「时间 + logId」复合游标：
        // 原来只用 `datetime <=`，同一毫秒的多条消息会被相邻两页重复取回 ⇒
        // 合并后出现重复 cell，且「整页都是已加载消息」时会被误判成「没有更多」，
        // 更早的记录永远加载不出来。
        let isOlderPage = !msgId.isEmpty && !includeCurMsgFlg
        let fromLogId = fromMsgDB?.logId
        
        let msgs: [Message] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            let sessionCondition = MessageDB.CodingKeys.sessionId.is(sessionId)
            if includeCurMsgFlg {
                constraint.condition = sessionCondition && MessageDB.CodingKeys.datetime >= datetime
            } else if isOlderPage, let fromLogId = fromLogId {
                constraint.condition = sessionCondition && (MessageDB.CodingKeys.datetime < datetime || (MessageDB.CodingKeys.datetime == datetime && MessageDB.CodingKeys.logId < fromLogId))
            } else {
                constraint.condition = sessionCondition && MessageDB.CodingKeys.datetime <= datetime
            }
            constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending), MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = count
        }).compactMap { Message.init(with: $0) }
        // 库里已有的「幽灵气泡」也不显示（见 `isPhantomBlankTextMsg`；不删数据，只是不上屏）
        return msgs.filter { !self.isPhantomBlankTextMsg($0) }
    }
    
    // 获取此会话最近的一条消息作为会话列表数据
    func getLatestMsg(sessionId: String, exceptMsgId: String) -> Message? {
        
        let lastMsgDB: MessageDB? = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId)
            constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending), MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = 1
        }).filter({ $0.msgId != exceptMsgId }).first
        
        if let dbMsg = lastMsgDB {
            return Message.init(with: dbMsg)
        }
        return nil
    }
    
    // 获取指定类型消息记录 0-系统消息 1-文字 2-音频 3-图片 4-视频 5-文件 6 7-通知 (群聊内灰色文字通知消息) 8-转发消息 9-语音视频电话 10-转账 11-收款 12-红包 13-名片
    func getSpecifiedDBMsgs(typeArr: [Int], session: Session, msgId: String, count: Int = 20) -> [Message] {
        
        let sessionId = session.id.idValue
        var fromMsgDB: MessageDB?
        if msgId.isEmpty {
            fromMsgDB = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
                constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId) && MessageDB.CodingKeys.msgType.in(typeArr)
                constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending)]
                constraint.limit = 1
            }).first
        } else {
            fromMsgDB = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
                constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId) && MessageDB.CodingKeys.msgId.is(msgId) && MessageDB.CodingKeys.msgType.in(typeArr)
                constraint.limit = 1
            }).first
        }
        
        guard let datetime = fromMsgDB?.datetime else { return [] }
        
        let msgs: [Message] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId) && MessageDB.CodingKeys.msgType.in(typeArr) && MessageDB.CodingKeys.datetime <= datetime
            constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending), MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = count
        }).compactMap { $0.msgId != msgId ? Message.init(with: $0) : nil }
        return msgs
    }
    
    // 搜索指定类型的消息（文件）
    func searchSpecifiedMsg(searchString: String, sessionId: String, typeArr: [Int] = [5]) -> [Message] {
        let objects: [VirtualMessageDB] = DBManager.shared().getObjects(fromTable: .virtualMessage, constraintBlock: { (constraint) in
            constraint.condition = VirtualMessageDB.Properties.sessionId == sessionId && VirtualMessageDB.Properties.content.match(searchString + "*")
        })
        
        guard !objects.isEmpty else { return [Message]() }
        
        let msgs: [Message] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.msgType.in(typeArr) && (MessageDB.Properties.msgId.in(objects.compactMap { $0.msgId }) || MessageDB.Properties.logId.in(objects.compactMap {$0.msgId}))
            constraint.orderBy = [MessageDB.Properties.datetime.asOrder(by: .descending), MessageDB.Properties.logId.asOrder(by: .descending)]
        }).compactMap { Message.init(with: $0) }
        
        return msgs
    }
    
    class func getNextUnreadVoiceMsg(timestamp: Int, type: Message.ChannelType, msgType: Message.MsgType, sessionId: String) -> Message? {
        let msgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            
            let channelTypeEqual = MessageDB.Properties.channelType == type.rawValue
            let partCondition = MessageDB.Properties.fromId != LoginUser.shared().address && (MessageDB.Properties.datetime > timestamp && MessageDB.Properties.isRead == false && MessageDB.Properties.msgType == msgType.rawValue.value) && MessageDB.Properties.status != 4
            
            if type == .person {
//                Message.MsgType.audio(Message.MsgType.RawValue).rawValue
//                constraint.condition = (MessageDB.Properties.targetId.like(sessionId) || MessageDB.Properties.fromId.like(sessionId)) && MessageDB.Properties.channelType == type.rawValue && MessageDB.Properties.fromId != LoginUser.shared().address && (MessageDB.Properties.datetime > timestamp && MessageDB.Properties.isRead == false) && MessageDB.Properties.status != 4
                
                constraint.condition = (MessageDB.Properties.targetId.like(sessionId) || MessageDB.Properties.fromId.like(sessionId)) && channelTypeEqual && partCondition
            }else {
                constraint.condition = MessageDB.Properties.targetId.like(sessionId) && channelTypeEqual && partCondition
            }
            constraint.orderBy = [MessageDB.Properties.datetime.asOrder(by: .ascending)]
            constraint.limit = 1
        }
        if let dbMsg = msgs.first {
            return Message(with: dbMsg)
        }
        return nil
    }
    
    // 获取当前消息的前一条消息
    func getLastMsg(from msg: Message) -> Message? {
        let msgs: [Message] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.sessionId.is(msg.sessionId.idValue) && MessageDB.CodingKeys.datetime < msg.datetime && MessageDB.CodingKeys.showTime.is(true)
            constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending), MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = 1
        }).compactMap { Message.init(with: $0) }
        
        if let lastMsg = msgs.first {
            return lastMsg
        }
        return nil
    }
    
    /// 消息数据处理 - 根据前一条显示time的消息时间和当前消息时间差判断是否显示time
    func handleMsgsWithShowTimeFlg(msgs: [Message], needFilterShield: Bool? = false) -> [Message] {
        guard msgs.count > 0, let firstmsg = msgs.first else { return msgs }
        
        var messages = msgs
        
        if needFilterShield == true {
            // 消息过滤掉黑名单用户
            // ⚠️ 这是**故意的**「不显示」：拉黑用户发的消息不入库、不显示。
            //    断点会照常前进（这条消息再也不会重拉），属于产品语义，不是「丢消息」。
            messages = msgs.compactMap { (msg) -> Message? in
                if msg.fromId != LoginUser.shared().address {
                    if let user = UserManager.shared().user(by: msg.fromId), user.isShield == true {
                        FZMLog("【黑名单】不显示黑名单用户消息 msgId=\(msg.msgId) from=\(msg.fromId)")
                        return nil
                    }
                }
                return msg
            }
        }
        
        var lastMsg = self.getLastMsg(from: firstmsg)
        var newMsgInDB : [Message] = []
        
        messages.forEach { model in
            var newMsg = model
            
            if let _ = lastMsg {
                if fabs(Double(model.datetime - lastMsg!.datetime)) > 600000 {
                    lastMsg = model
                    newMsg.showTime = true
                } else {
                    newMsg.showTime = false
                }
            } else {
                newMsg.showTime = true
            }
            newMsgInDB.append(newMsg)
        }
        
        return newMsgInDB
    }
    
    /// 保存聊天消息到数据库
    func save(_ msgs: [Message]) {
        // 「幽灵气泡」不入库：正文为空、又没有密文可重试的文本消息（见 `isPhantomBlankTextMsg`）
        let msgs = msgs.filter { !self.isPhantomBlankTextMsg($0) }
        guard msgs.isEmpty == false else { return }
        // `needFilterShield: true`：黑名单用户发的消息**不入库也不显示**（产品语义）。
        // 除此之外不丢任何消息（图片/视频下载失败也照样落库，显示层给占位图）。
        let newMsgInDB = self.handleMsgsWithShowTimeFlg(msgs: msgs, needFilterShield: true)

        // ⚠️ 服务端历史记录（pri-chat-record）**不带引用字段**：拉历史 / 翻页时用服务端版本覆盖本地那条，
        //    会把已经存好的 refId/topicId 抹成 nil —— 用户看到的就是「引用条时隐时现、重进又没了」。
        //    落库前把本地已知的引用关系补回来（只补 reference 为空的）。
        let merged = ChatManager.mergeLocalReferences(into: newMsgInDB)
        let msgDBArr = merged.compactMap { MessageDB.init(with: $0) }
        DBManager.shared().insertOrReplaceMessages(msgDBArr)

        // 排查「对方发了两张图只收到一张」：这里能看出到底是「没进来」还是「进来了没写库」
        let imageCount = msgDBArr.filter { $0.msgType == 3 }.count
        if msgDBArr.count != msgs.count || imageCount > 0 {
            let typeList = msgDBArr.prefix(8).map { "\($0.msgId.prefix(8)):\($0.msgType)" }
            FZMLog("【落库】写入 \(msgDBArr.count)/\(msgs.count) 条 图片=\(imageCount) 列表=\(typeList)")
        }
        
       
    }

    /// 「幽灵气泡」判定：正文为空的文本消息，且**没有任何可展示 / 可重试的内容**。
    ///
    /// 背景（用户 2026-11-10 反馈）：群里出现一条「该消息内容无法显示，点击重试」，
    /// 点它却提示「没有可重试的消息内容」，而 web 端根本没有这条。
    /// 实际是**对端客户端发出的空正文文本消息**（`PbMsg_TextMsg.content == ""`，解密是成功的），
    /// web 端不渲染空消息，App 却把它画成了「解密失败、可点击重试」的占位气泡。
    /// ⇒ 这类消息不再入库（`save`）、已入库的也不再上屏（`getHistoryMsgs`）。
    ///
    /// ⚠️ 下面三种**不能丢**：
    ///   · 解密失败：`unparsed_msg` 里存着原始密文，展示层要靠它「点击重试」；
    ///   · 带引用：气泡里还有引用条要显示；
    ///   · 阅后即焚：占位文案由阅后即焚自己的样式负责。
    private func isPhantomBlankTextMsg(_ msg: Message) -> Bool {
        guard msg.msgType.isEmptyText else { return false }
        guard !msg.isBurn, msg.reference == nil else { return false }
        return self.unparsedMsg(msgId: msg.msgId) == nil
    }

    /// 落库前补回「本地已经存过、这次没带引用」的消息的引用关系。
    ///
    /// 背景：私聊历史接口不返回 `reference`，整批重建 / 翻页落库会把本地的 refId/topicId 冲掉。
    /// 这里按 msgId 一次性查出本地已有的引用关系补回去（只处理 `reference == nil` 的，不覆盖新数据）。
    static func mergeLocalReferences(into msgs: [Message]) -> [Message] {
        let needIds = msgs.filter { $0.reference == nil }.map { $0.msgId }
        guard !needIds.isEmpty else { return msgs }

        let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.in(needIds)
        }
        guard !rows.isEmpty else { return msgs }

        var refMap: [String: Message.Reference] = [:]
        for row in rows {
            // refId > 0 才算真引用（历史脏数据里有 {0,0}）
            guard let refId = row.refId, let topicId = row.topicId, refId > 0 else { continue }
            refMap[row.msgId] = Message.Reference.init(ref: refId, topic: topicId)
        }
        guard !refMap.isEmpty else { return msgs }

        var result = msgs
        var filled = 0
        for i in 0..<result.count where result[i].reference == nil {
            if let ref = refMap[result[i].msgId] {
                result[i].reference = ref
                filled += 1
            }
        }
        if filled > 0 {
            FZMLog("【引用】落库前补回本地引用关系 \(filled) 条")
        }
        return result
    }
    
    /// 更新消息体（类型 + JSON 正文一起写）
    ///
    /// ⚠️ 只写 `msgType`（数字）是不够的：**消息体 JSON 存在 `msg` 列**
    ///    （见 `MessageDB.init(with:)`：`self.msg = msgTypeValue.json.rawString()`）。
    ///    原来这里只更新了类型列，导致「上传成功后回填的 url / 解密重试成功的新正文」全都没落库：
    ///    · 自己发的图片/视频/音频/文件在本地库里永远是 `url: null` ⇒ 一清缓存就再也加载不出来；
    ///    · 解密重试成功后重进会话又变回占位。
    func update(mes msgId: String, with msgType: Message.MsgType)  {
        let row: [ColumnEncodable] = [msgType.rawValue.value, msgType.rawValue.json.rawString() ?? ""]
        self.update(msg: msgId, on: [MessageDB.Properties.msgType, MessageDB.Properties.msg], with: row)
    }
    
    func update(mes msgId: String, with status: Message.Status)  {
        let row: [ColumnEncodable] = [status.rawValue]
        self.update(msg: msgId, on: [MessageDB.Properties.status], with: row)
    }
    
    func update(mes msgId: String, isRead: Bool)  {
        let row: [ColumnEncodable] = [isRead]
        self.update(msg: msgId, on: [MessageDB.Properties.isRead], with: row)
    }
    
    /// 保存文本消息译文（只写本地库；老库没有这两列时由 WCDB 自动加列）
    func updateTranslation(mes msgId: String, text: String, lang: String)  {
        let row: [ColumnEncodable] = [text, lang]
        self.update(msg: msgId, on: [MessageDB.Properties.translation, MessageDB.Properties.translationLang], with: row)
    }
    
    /// 保存语音转写文本（只写本地库）
    func updateTranscript(mes msgId: String, text: String)  {
        let row: [ColumnEncodable] = [text]
        self.update(msg: msgId, on: [MessageDB.Properties.transcript], with: row)
    }
    
    /// 取消翻译：把译文两列清空（空串在读库时按「没有译文」处理）
    func clearTranslation(mes msgId: String)  {
        let row: [ColumnEncodable] = ["", ""]
        self.update(msg: msgId, on: [MessageDB.Properties.translation, MessageDB.Properties.translationLang], with: row)
    }
    
    func update(msgWithLogId logId: String, with status: Message.Status)  {
        let row: [ColumnEncodable] = [status.rawValue]
        self.update(msgWithLogId: logId, on: [MessageDB.Properties.status], with: row)
    }
    
    func update(mes msgId: String, with status: Message.Status, logId: Int, datatime: Int)  {
        let row: [ColumnEncodable] = [status.rawValue, logId, datatime]
        self.update(msg: msgId, on: [MessageDB.Properties.status, MessageDB.Properties.logId, MessageDB.Properties.datetime], with: row)
    }
    
    func update(msg: Message, on updatePropertys: [PropertyConvertible] = MessageDB.Properties.all) {
        let msgDB = MessageDB.init(with: msg)
        DBManager.shared().update(table: .message, on: updatePropertys, with: msgDB) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.is(msgDB.msgId)
        }
    }
    
    private func update(msg msgId: String, on updatePropertys: [PropertyConvertible], with row: [ColumnEncodable]) {
        DBManager.shared().update(table: .message, on: updatePropertys, with: row) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.is(msgId)
        }
    }
    
    private func update(msgWithLogId logId: String, on updatePropertys: [PropertyConvertible], with row: [ColumnEncodable]) {
        DBManager.shared().update(table: .message, on: updatePropertys, with: row) { (constraint) in
            constraint.condition = MessageDB.Properties.logId.is(logId)
        }
       
    }
    
    
    // 删除多条消息记录
    func delete(messsages msgs: [Message]) {
        guard msgs.count > 0, let lastMsg = msgs.last else {
            return
        }
        
        // 数据库删除消息记录
        // ⚠️ 这个入口**只删本地**：服务端没有「删单条」的接口（文档只提供按时间范围的 clean-private）
        //    ⇒ 日志里要能看到它是「谁」删的，以及之后会不会被服务端记录写回来。
        let msgIds = msgs.compactMap { $0.msgId }
        FZMLog("【删除消息】DB 删除（仅本地）channel=\(lastMsg.channelType) from=\(lastMsg.fromId) target=\(lastMsg.targetId) msgIds=\(msgIds.prefix(8))")
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.in(msgIds)
        }
        let leftRows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.in(msgIds)
        }
        FZMLog("【删除消息】DB 删除后回查：同 msgId 剩余=\(leftRows.count) 条（应为 0）")
        
        // 更新会话列表
        var sessionId: SessionID?
        if lastMsg.channelType == .group {
            sessionId = SessionID.group(lastMsg.targetId)
        } else if lastMsg.channelType == .person {
            sessionId = SessionID.person(lastMsg.isOutgoing ? lastMsg.targetId : lastMsg.fromId)
        }
        
        guard let sessionId = sessionId, let session = SessionManager.shared().getSingleLocalSession(by: sessionId) else {
            return
        }
        
        // 更新会话列表
        SessionManager.shared().updateLastMsgInfo(session: session, msgId: lastMsg.msgId)
    }
    
    // 删除单个会话的所有消息记录
    /// 说明：长按/删除会话仅清本地（对接文档未提供单条 / 整会话的服务端删除接口）；
    /// 双方同步清理由服务端「手动删除 / 自动删除」通过 ActionDeleteMessages 信令下发。
    func deleteSessionMsgs(targetId: String) {
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.is(targetId)
        }
    }
    
    /// 收到其他设备/对方用户删除聊天记录通知后，删除本地数据库消息并刷新会话预览
    /// 私聊场景：对方视角的 sessionId 是"我"的地址，需通过 fromId/targetId 反推本地会话
    func handleDeleteMessagesInDB(pbMsg: PbMsg_ActionDeleteMessages) {
        guard FZM_EnableChatDeleteFeature else { return }// 功能未接入，关闭
        let sessionId = pbMsg.sessionId
        guard !sessionId.isEmpty else { return }
        
        FZMLog("收到删除同步通知 sessionId: \(sessionId) clearAll: \(pbMsg.clearAll) msgIds: \(pbMsg.msgIds.count) before: \(pbMsg.before) channelType: \(pbMsg.channelType)")
        
        // 记录受影响消息的本地会话与 Message 列表（用于删后刷新预览 + 通知聊天页 UI 同步）
        var affectedLocalSessionId: String?
        var affectedMsgs = [Message]()
        
        if pbMsg.clearAll {
            let localSessionId = self.resolveLocalSessionId(pbMsg: pbMsg) ?? sessionId
            affectedLocalSessionId = localSessionId
            let dbMsgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.sessionId.is(localSessionId)
            }
            affectedMsgs = dbMsgs.compactMap { Message(with: $0) }
        } else if !pbMsg.msgIds.isEmpty {
            // msgId 两端一致，先查出这些消息在本地属于哪个会话
            let dbMsgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.msgId.in(pbMsg.msgIds)
            }
            affectedLocalSessionId = dbMsgs.first?.sessionId
            affectedMsgs = dbMsgs.compactMap { Message(with: $0) }
        } else if pbMsg.before > 0 {
            let localSessionId = self.resolveLocalSessionId(pbMsg: pbMsg) ?? sessionId
            affectedLocalSessionId = localSessionId
            let dbMsgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.sessionId.is(localSessionId) && MessageDB.Properties.datetime < Int(pbMsg.before)
            }
            affectedMsgs = dbMsgs.compactMap { Message(with: $0) }
        }
        
        // 执行本地删除
        if pbMsg.clearAll {
            let localSessionId = self.resolveLocalSessionId(pbMsg: pbMsg) ?? sessionId
            DBManager.shared().delete(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.sessionId.is(localSessionId)
            }
        } else if !pbMsg.msgIds.isEmpty {
            DBManager.shared().delete(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.msgId.in(pbMsg.msgIds)
            }
        } else if pbMsg.before > 0 {
            let localSessionId = self.resolveLocalSessionId(pbMsg: pbMsg) ?? sessionId
            DBManager.shared().delete(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.sessionId.is(localSessionId) && MessageDB.Properties.datetime < Int(pbMsg.before)
            }
        }
        
        // 通知聊天页 UI 同步移除（若正在查看该会话）
        if let localSessionId = affectedLocalSessionId, !affectedMsgs.isEmpty {
            let sessionID: SessionID
            if let s = self.findLocalSession(sessionId: localSessionId) {
                sessionID = s.id
            } else {
                sessionID = pbMsg.channelType == 1 ? SessionID.group(localSessionId) : SessionID.person(localSessionId)
            }
            FZM_NotificationCenter.post(name: FZM_Notify_DeleteChatMsgs, object: (sessionID, affectedMsgs))
        }
        
        // 刷新会话预览（优先用被删消息反推出的本地会话）
        guard let localSessionId = affectedLocalSessionId ?? self.resolveLocalSessionId(pbMsg: pbMsg),
              let targetSession = self.findLocalSession(sessionId: localSessionId) else {
            return
        }
        SessionManager.shared().refreshLastMsgInfo(session: targetSession)
    }
    
    /// 私聊场景下，对方设备的 sessionId 是"我"的地址，通过 fromId/targetId 反推本地会话 ID
    private func resolveLocalSessionId(pbMsg: PbMsg_ActionDeleteMessages) -> String? {
        let sessionId = pbMsg.sessionId
        // 本地已存在该会话，直接使用
        if self.findLocalSession(sessionId: sessionId) != nil {
            return sessionId
        }
        // 私聊且本地不存在该 sessionId：反推对方地址作为本地会话 ID
        if pbMsg.channelType == 0 {
            let myAddress = LoginUser.shared().address
            let peer = pbMsg.fromId == myAddress ? pbMsg.targetId : pbMsg.fromId
            if !peer.isEmpty, peer != myAddress, self.findLocalSession(sessionId: peer) != nil {
                return peer
            }
        }
        return nil
    }
    
    /// 查找本地会话（私聊/群聊）
    private func findLocalSession(sessionId: String) -> Session? {
        if let session = SessionManager.shared().getSingleLocalSession(by: SessionID.person(sessionId)) {
            return session
        }
        return SessionManager.shared().getSingleLocalSession(by: SessionID.group(sessionId))
    }
    
    // 撤回消息
    func revoke(message: Message, chatServerUrl: String) {
        guard let logId = message.logId else {
            FZMLog("撤回失败：logId 为空")
            return
        }
        let type = message.channelType == .person ? 0 : 1
        
        GroupManager.shared().revokeMsg(
            serverUrl: chatServerUrl,
            type: type,
            lodId: logId,
            successBlock: { _ in
                FZMLog("撤回消息请求成功 logId: \(logId)")
            },
            failureBlock: { error in
                FZMLog("撤回消息请求失败: \(error)")
            }
        )
    }
    
    /// 私聊「删除」：先调**撤回接口**，撤回成功后把本地这条消息**静默删除**
    /// （不生成「撤回了一条消息」提示，也不保留原文）—— 用户 2026-10-19 要求。
    /// - 撤回失败：消息保持原样，由调用方提示用户
    /// ⚠️ 本文件 import WCDBSwift，顶层 `Error` 是 WCDBSwift 的类（会屏蔽 Swift.Error），
    ///    这里必须显式写 `Swift.Error`，否则 `NSError` 会报 "Cannot convert NSError to Error"。
    func revokeThenDelete(message: Message, chatServerUrl: String,
                          successBlock: (() -> Void)? = nil,
                          failureBlock: ((Swift.Error) -> Void)? = nil) {
        guard let logId = message.logId, logId > 0 else {
            FZMLog("【删除转撤回】logId 无效（服务端还没有这条），跳过 msgId=\(message.msgId)")
            failureBlock?(NSError(domain: "ChatManager", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: L("删除失败，请稍后重试")]))
            return
        }
        let type = message.channelType == .person ? 0 : 1

        // 先打标记：撤回通知可能比 HTTP 回调更早到达，两种顺序都要能静默删除
        self.markSilentRevokeDelete(logId: logId)
        FZMLog("【删除转撤回】调撤回接口 logId=\(logId) msgId=\(message.msgId)")

        GroupManager.shared().revokeMsg(
            serverUrl: chatServerUrl,
            type: type,
            lodId: logId,
            successBlock: { [weak self] _ in
                guard let self = self else { return }
                FZMLog("【删除转撤回】撤回接口成功 logId=\(logId) ⇒ 静默删除本地消息")
                self.deleteRevokedMessageSilently(logId: logId)
                self.unmarkSilentRevokeDelete(logId: logId)
                successBlock?()
            },
            failureBlock: { [weak self] error in
                self?.unmarkSilentRevokeDelete(logId: logId)
                FZMLog("【删除转撤回】撤回接口失败 logId=\(logId)：\(error.localizedDescription)")
                failureBlock?(error)
            }
        )
    }

    private func markSilentRevokeDelete(logId: Int) {
        self.silentRevokeDeleteLogIds.insert(logId)
    }

    private func unmarkSilentRevokeDelete(logId: Int) {
        self.silentRevokeDeleteLogIds.remove(logId)
    }

    /// 取出并移除标记：返回 true 表示这次撤回事件来自「删除」入口
    private func consumeSilentRevokeDelete(logId: Int) -> Bool {
        return self.silentRevokeDeleteLogIds.remove(logId) != nil
    }

    /// 撤回成功后（或收到撤回事件时）**静默删除**本地消息：删 DB + 通知聊天页移除 + 刷新会话预览。
    /// 与普通撤回的区别：**不**把 msgType 改写成「撤回了一条消息」通知。
    /// - Returns: 是否找到并删除了这条消息
    @discardableResult
    func deleteRevokedMessageSilently(logId: Int) -> Bool {
        let dbMessages: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
            constraint.condition = MessageDB.Properties.logId.is(logId)
            constraint.limit = 1
        }
        guard let dbMsg = dbMessages.first else {
            // 已经删过（撤回事件与接口回调先后到达）⇒ 直接忽略
            FZMLog("【删除转撤回】本地已无该消息（可能已删），logId=\(logId)")
            return false
        }
        let msg = Message(with: dbMsg)

        DBManager.shared().delete(fromTable: .message) { constraint in
            constraint.condition = MessageDB.Properties.logId.is(logId)
        }

        // 通知聊天页 UI 移除（needDeleteDB=false：DB 已删完，只同步 UI + 清本地缓存）
        FZM_NotificationCenter.post(name: FZM_Notify_DeleteChatMsgs, object: (msg.sessionId, [msg]))

        // 更新会话列表预览
        if let session = SessionManager.shared().getSingleLocalSession(by: msg.sessionId) {
            SessionManager.shared().refreshLastMsgInfo(session: session)
        }
        FZMLog("【删除转撤回】已静默删除本地消息 logId=\(logId) msgId=\(msg.msgId)")
        return true
    }

    /// 收到撤回通知后，更新数据库中对应消息为通知类型（不依赖 UI 状态）
    /// - Returns: 更新后的 Message，若未找到则返回 nil
    func handleRevokeInDB(logId: Int, operatorId: String, isSelfRevoke: Bool) -> Message? {
        let dbMessages: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
            constraint.condition = MessageDB.Properties.logId.is(logId)
            constraint.limit = 1
        }
        
        guard let dbMsg = dbMessages.first else {
            FZMLog("handleRevokeInDB: 未找到 logId=\(logId) 的消息")
            return nil
        }
        
        var msg = Message(with: dbMsg)
        
        var notifyText: String
        if isSelfRevoke {
            notifyText = L("你撤回了一条消息")
        } else {
            // 获取操作者昵称：优先群昵称 → 用户昵称 → 地址
            var operatorName = operatorId.shortAddress
            // 群聊优先查群成员昵称
            if msg.channelType == .group {
                let groupId = msg.targetId.intEncoded
                if let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: operatorId) {
                    operatorName = member.contactsName
                }
            }
            // 再查用户昵称（私聊或群成员未找到时）
            if operatorName == operatorId.shortAddress, let user = UserManager.shared().user(by: operatorId) {
                operatorName = user.contactsName
            }
            notifyText = "\(operatorName) " + L("撤回了一条消息")
        }
        
        // 保留原文内容（仅限自己撤回的文字消息，用于"重新编辑"）
        var revokedContent: String?
        if isSelfRevoke, case .text = msg.msgType {
            revokedContent = msg.msgType.textValue
        }
        // 撤回提示后追加"重新编辑"入口（会话列表预览中会剥离该关键字）
        if revokedContent != nil {
            notifyText += "\n" + L("重新编辑")
        }
        
        let newMsgType = Message.MsgType.init(notify: notifyText, type: 8, groupId: Int(), operatorId: operatorId, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: nil, revokedContent: revokedContent)
        msg.msgType = newMsgType
        
        // 更新数据库
        self.update(msg: msg)
        
        return msg
    }
    
    /// 通过服务端 logId 从数据库获取消息（供 UI 层读取已更新的消息）
    func getMessage(byLogId logId: Int) -> Message? {
        let dbMessages: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
            constraint.condition = MessageDB.Properties.logId.is(logId)
            constraint.limit = 1
        }
        return dbMessages.first.map { Message(with: $0) }
    }
}
