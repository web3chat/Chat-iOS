//
//  MessageManager.swift
//  chat
//
//  Created by 陈健 on 2021/1/18.
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
    
    private(set) lazy var sendMsgSubject  = PublishSubject<Message>.init()
    private(set) lazy var sendMsgAndUploadFailedSubject = PublishSubject<String>.init()// 上传文件导致消息发送失败结果订阅
    
    private init() {
        self.setRX()
    }
    
    private func setRX() {
        self.sendMsgAndUploadFailedSubject.subscribe(onNext: {[unowned self] (msgId) in
            self.update(mes: msgId, with: .failed)
            
            // 更新会话列表消息状态
            SessionManager.shared().updateMsgSendStatus(with: msgId, sendSuccess: false)
        }).disposed(by: self.bag)
        
        // 消息发送结果订阅
        MultipleSocketManager.shared().sendMsgStatusSubject.subscribe(onNext: {[unowned self] (sendMsgStatus) in
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
        MultipleSocketManager.shared().receiveMsgsSubject.subscribe(onNext: {[unowned self] (msgs) in
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
                self.sendSocketMsg(msg: msg, chatServerUrl: chatServerUrl, publickey: pubkey.finalKey)
            }
        }
    }
    
    private func sendSocketMsg(msg: Message, chatServerUrl: String, publickey: String) {
        switch msg.msgType {
        case .text, .transfer ,.contactCard,.system:
            MultipleSocketManager.shared().send(msg: msg, chatServerUrl: chatServerUrl, publickey:publickey)
        case .image:
            FZMLog("图片消息")
            msg.msgType.imageAsync { image in
                if let image = image {
                    var imgData = image.jpegData(compressionQuality: 0.6)!
                    if let gifData = msg.gifData {
                        imgData = gifData
                    }
                    
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
            if msg.mediaUrl != nil{
                if let data = try? Data.init(contentsOf: URL.init(fileURLWithPath: msg.mediaUrl.path)) {
                    msg.msgType.imageAsync { image in
                        if let image = image {
                            self.uploadFileRequest(fileData: data, msg: msg, publickey: publickey) { (url) in
                                var message = msg
                                let msgType = Message.MsgType.init(video: url, cacheKey: msg.msgType.cachekey, duration: msg.msgType.duration!, width: Double(image.size.width), height: Double(image.size.height))
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
                } else {
                    self.sendMsgAndUploadFailedSubject.onNext(msg.msgId)
                }
            }
        case .file:
            FZMLog("文件消息")
            
            if msg.fileUrl != nil {
                let data = try? Data.init(contentsOf: URL.init(fileURLWithPath: msg.fileUrl))
                self.uploadFileRequest(fileData: data!, msg: msg, publickey: publickey) { (url) in
                    var message = msg
                    let msgType = Message.MsgType.init(file: url, cacheKey: msg.msgType.cachekey, name: (msg.fileUrl as NSString).lastPathComponent, md5: OSSUtil.fileMD5String(msg.fileUrl), size: Double(data?.count ?? 0))
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
                let data = try? Data.init(contentsOf: URL.init(fileURLWithPath: msg.audioUrl))
                self.uploadFileRequest(fileData: data!, msg: msg, publickey: publickey) { (url) in
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
        
        let msgs: [Message] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.sessionId.is(sessionId) && (includeCurMsgFlg ? MessageDB.CodingKeys.datetime >= datetime : MessageDB.CodingKeys.datetime <= datetime)
            constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending), MessageDB.CodingKeys.logId.asOrder(by: .descending)]
            constraint.limit = count
        }).compactMap { $0.msgId != msgId ? Message.init(with: $0) : (includeCurMsgFlg ? Message.init(with: $0) : nil) }
        return msgs
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
            messages = msgs.compactMap { (msg) -> Message? in
                if msg.fromId != LoginUser.shared().address {
                    if let user = UserManager.shared().user(by: msg.fromId), user.isShield == true {
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
            newMsgInDB = newMsgInDB + [newMsg]
        }
        
        return newMsgInDB
    }
    
    /// 保存聊天消息到数据库
    func save(_ msgs: [Message]) {
        let newMsgInDB = self.handleMsgsWithShowTimeFlg(msgs: msgs, needFilterShield: true)
        
        let msgDBArr = newMsgInDB.compactMap { MessageDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .message, list: msgDBArr)
    }
    
    func update(mes msgId: String, with msgType: Message.MsgType)  {
        let row: [ColumnEncodable] = [msgType.rawValue.value]
        self.update(msg: msgId, on: [MessageDB.Properties.msgType], with: row)
    }
    
    func update(mes msgId: String, with status: Message.Status)  {
        let row: [ColumnEncodable] = [status.rawValue]
        self.update(msg: msgId, on: [MessageDB.Properties.status], with: row)
    }
    
    func update(mes msgId: String, isRead: Bool)  {
        let row: [ColumnEncodable] = [isRead]
        self.update(msg: msgId, on: [MessageDB.Properties.isRead], with: row)
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
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.in(msgs.compactMap { $0.msgId })
        }
        
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
    func deleteSessionMsgs(targetId: String) {
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.is(targetId)
        }
    }
}
