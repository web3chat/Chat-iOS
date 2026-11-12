//
//  ChatRecord+Message.swift
//  chat
//
//  服务端私聊记录（pri-chat-record 的 records[]）→ 本地 Message 转换
//  文档：《获取私聊记录_App对接文档》
//

import Foundation
import SwiftyJSON

extension Message {

    /// 解析 pri-chat-record 的 data（{record_count, records}）。
    /// ⚠️ 私聊消息体在发送时被 DH 加密（见 `PbMsg_event+Message.swift`），服务端没有私钥、
    /// 不可能给出明文——必须用对端公钥解密后再按 msgType 反序列化，
    /// 加解密沿用既有 `ChatManager.decryptMsgData`（与 socket 收消息完全同一套）。
    static func serverRecords(fromData json: JSON, peerAddress: String, completion: @escaping ([Message]) -> Void) {
        guard let arr = json["records"].array, !arr.isEmpty else {
            completion([])
            return
        }
        ChatManager.getPublickey(by: peerAddress, isGetUserKey: true) { (publickey) in
            FZMLog("私聊记录：count=\(arr.count) peer=\(peerAddress) publickey=\(publickey.isBlank ? "空(无法解密)" : "有")")
            if let first = arr.first {
                FZMLog("私聊记录原文(首条)：\(String(first.rawString()?.prefix(1200) ?? ""))")
            }
            let msgs = arr.compactMap { Message.record(from: $0, publickey: publickey) }
            completion(msgs)
        }
    }

    /// 单条服务端记录 → Message；字段缺失/非法时返回 nil
    static func record(from json: JSON, publickey: String) -> Message? {
        // logId：服务端为字符串（大整数），也兼容数字
        let logIdValue: Int? = {
            if let i = json["logId"].int { return i }
            if let s = json["logId"].string, let i = Int(s) { return i }
            return nil
        }()
        guard let logId = logIdValue else { return nil }

        let fromId = json["fromId"].stringValue
        let targetId = json["targetId"].stringValue
        guard !fromId.isEmpty, !targetId.isEmpty else { return nil }

        // msgId 为空时用 logId 兜底，保证多次拉取去重稳定（不会每次生成新 uuid 造成重复行）
        let rawMsgId = json["msgId"].stringValue
        let msgId = rawMsgId.isEmpty ? "log_\(logId)" : rawMsgId
        let msgTypeValue = json["msgType"].intValue
        let datetime = Message.normalizedMillisecond(json["createTime"])
        // 阅后即焚：服务端可能不回吐 source；此时**保留本地已存的标记**，
        // 否则重新拉取会把本地 isBurn 覆盖成 false（标记丢失）。
        var isBurn = json["source"]["burn"].bool ?? false
        if !isBurn, !json["source"].exists() {
            isBurn = Message.localBurnFlag(msgId: msgId)
        }

        // 1) 密文路径：解密 → 按 msgType 反序列化（与 socket 收消息完全一致）
        //    ⚠️ 只要检测到密文字段，就**不再回退明文映射**——否则会把密文当正文写进本地库（污染历史）。
        if let encrypted = Message.encryptedBody(from: json) {
            guard !publickey.isBlank else {
                FZMLog("私聊记录：公钥为空，无法解密，忽略该条 logId=\(logId)")
                return nil
            }
            var pb = PbMsg_msg()
            pb.channelType = 0
            pb.logID = Int64(logId)
            pb.msgID = msgId
            pb.from = fromId
            pb.target = targetId
            pb.msgType = PbMsg_MsgType.init(rawValue: msgTypeValue) ?? .UNRECOGNIZED(msgTypeValue)
            pb.datetime = UInt64(datetime)
            // 服务端若回吐引用字段就带上（老服务端不回吐，交给调用方用本地缓存补）
            if let ref = Message.reference(fromRecord: json) {
                pb.reference.topic = Int64(ref.topic)
                pb.reference.ref = Int64(ref.ref)
            }
            let decrypted = ChatManager.decryptMsgData(encrypted, publickey: publickey, isEncryptPersionChatData: true)
            FZMLog("私聊记录解密：logId=\(logId) 密文=\(encrypted.count)B 解密后=\(decrypted.count)B 密文头=\(Message.hexPrefix(encrypted)) 明文头=\(Message.hexPrefix(decrypted))")
            // 解密失败时解密函数会**原样返回密文**，不能继续当明文解析（会把密文当正文写进本地库）
            guard !ChatManager.isMsgDecryptFailed(cipher: encrypted, decrypted: decrypted) else {
                FZMLog("私聊记录解密失败（返回原密文），忽略该条 logId=\(logId) 密文=\(encrypted.count)B")
                return nil
            }
            pb.msg = decrypted
            // 复用既有「pb → Message」解析（含各 msgType 的消息体解析）
            var message = Message(pbMsg: pb, publickey: publickey)
            guard !message.msgType.isUnknown, !message.msgType.isEmptyText else {
                FZMLog("私聊记录解密后仍无法解析，忽略该条（不回退明文映射）logId=\(logId) msgType=\(msgTypeValue)")
                return nil
            }
            message.isRead = true
            message.showTime = false
            message.isBurn = isBurn
            return message
        }

        // 2) 无密文字段：视为服务端已给明文 content（mock/未加密环境），按文档键名映射
        let contentJSON = Message.MsgType.json(fromServerContent: json["content"], msgType: msgTypeValue)
        let fallbackType = Message.MsgType.init(rawValue: (msgTypeValue, contentJSON))
        if case .text = fallbackType, fallbackType.textValue.isBlank {
            FZMLog("私聊记录：明文 content 为空，忽略该条 logId=\(logId)")
            return nil
        }
        var message = Message(serverRecord: logId, msgId: msgId, fromId: fromId, targetId: targetId,
                              datetime: datetime, msgType: fallbackType, isBurn: isBurn)
        message.reference = Message.reference(fromRecord: json)
        return message
    }

    /// 从服务端记录里解析引用关系（服务端可能不回吐 ⇒ 返回 nil，由本地缓存兜底）。
    /// 兼容几种键名：`reference{ref,topic}` / `refId`+`topicId` / `ref`+`topic`（数字或字符串）。
    static func reference(fromRecord json: JSON) -> Message.Reference? {
        func intValue(_ value: JSON) -> Int? {
            if let i = value.int { return i }
            if let s = value.string { return Int(s) }
            return nil
        }
        let ref = intValue(json["reference"]["ref"]) ?? intValue(json["refId"]) ?? intValue(json["ref"])
        let topic = intValue(json["reference"]["topic"]) ?? intValue(json["topicId"]) ?? intValue(json["topic"])
        guard let refId = ref, refId > 0 else { return nil }
        var topicId = refId
        if let topic = topic, topic > 0 { topicId = topic }
        return Message.Reference.init(ref: refId, topic: topicId)
    }

    /// Data 前缀的 hex（诊断用）
    static func hexPrefix(_ data: Data, count: Int = 16) -> String {
        return data.prefix(count).map { String(format: "%02x", $0) }.joined()
    }

    /// 本地已存的阅后即焚标记（DB 列 或 消息体 JSON）——服务端不回吐 source 时用于保留本地值
    private static func localBurnFlag(msgId: String) -> Bool {
        let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.msgId.is(msgId)
            constraint.limit = 1
        }
        guard let row = rows.first else { return false }
        let rawValue = (row.msgType, JSON.init(parseJSON: row.msg))
        let type = Message.MsgType.init(rawValue: rawValue)
        return (row.isBurn ?? false) || type.isBurnFlagInJSON
    }

    /// 从记录里取出加密消息体：兼容 base64 / hex，字段兼容 msg / body / content（含子字段）
    static func encryptedBody(from json: JSON) -> Data? {
        var candidates: [String] = []
        func add(_ value: JSON) {
            if let s = value.string, !s.isEmpty { candidates.append(s) }
        }
        add(json["msg"])
        add(json["body"])
        add(json["content"])
        add(json["msgData"])
        let content = json["content"]
        add(content["data"])
        add(content["msg"])
        add(content["body"])
        add(content["content"])
        add(content["payload"])

        for s in candidates {
            if let data = Message.decodeBodyString(s), !data.isEmpty { return data }
        }
        return nil
    }

    /// 字符串 → 密文二进制：先 base64（标准/URL-safe），再 hex
    static func decodeBodyString(_ s: String) -> Data? {
        if let data = Data(base64Encoded: s), !data.isEmpty { return data }
        let normalized = s.replacingOccurrences(of: "-", with: "+")
                          .replacingOccurrences(of: "_", with: "/")
        if let data = Data(base64Encoded: normalized, options: .ignoreUnknownCharacters), !data.isEmpty {
            return data
        }
        // hex
        let hex = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.count >= 16, hex.count % 2 == 0, hex.allSatisfy({ $0.isHexDigit }) {
            var bytes = [UInt8]()
            bytes.reserveCapacity(hex.count / 2)
            var idx = hex.startIndex
            while idx < hex.endIndex {
                let next = hex.index(idx, offsetBy: 2)
                if let b = UInt8(hex[idx..<next], radix: 16) { bytes.append(b) }
                idx = next
            }
            if !bytes.isEmpty { return Data(bytes) }
        }
        return nil
    }

    /// 兜底构造（服务端明文 content 场景）
    private init(serverRecord logId: Int, msgId: String, fromId: String, targetId: String,
                 datetime: Int, msgType: Message.MsgType, isBurn: Bool) {
        self.msgId = msgId
        self.fromId = fromId
        self.targetId = targetId
        self.channelType = .person
        self.msgType = msgType
        self.logId = logId
        self.datetime = datetime
        self.status = .sent
        self.isRead = true
        self.showTime = false
        self.reference = nil
        self.isBurn = isBurn
    }

    /// 统一成毫秒时间戳：≥ 1e12 视为毫秒，否则视为秒并 ×1000
    static func normalizedMillisecond(_ json: JSON) -> Int {
        var raw: Int64 = 0
        if let n = json.int64 { raw = n }
        else if let s = json.string, let n = Int64(s) { raw = n }
        if raw <= 0 { return Date.timestamp }
        if raw < 1_000_000_000_000 { raw *= 1000 }
        return Int(raw)
    }
}

extension Message.MsgType {

    /// 解析失败（未识别类型）
    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    /// 文本内容为空（解密后得到空正文，视为无效）
    var isEmptyText: Bool {
        if case .text = self { return textValue.isBlank }
        return false
    }

    /// 把服务端 content（mediaUrl/time/...）转换成 App 内部 MsgType JSON（url/duration/...）
    static func json(fromServerContent content: JSON, msgType: Int) -> JSON {
        switch msgType {
        case 0, 1:// 系统 / 文本
            return JSON(["content": content["content"].stringValue])
        case 2:// 语音：{mediaUrl, time}
            return JSON (["url": content["mediaUrl"].stringValue,
                          "duration": content["time"].doubleValue,
                          "cacheKey": String.uuid(),
                          "width": 0,
                          "height": 0] as [String: Any])
        case 3:// 图片：{mediaUrl, height, width}
            return JSON (["url": content["mediaUrl"].stringValue,
                          "cacheKey": String.uuid(),
                          "width": content["width"].doubleValue,
                          "height": content["height"].doubleValue] as [String: Any])
        case 4:// 视频：{mediaUrl, time, height, width}
            return JSON (["url": content["mediaUrl"].stringValue,
                          "cacheKey": String.uuid(),
                          "duration": content["time"].doubleValue,
                          "width": content["width"].doubleValue,
                          "height": content["height"].doubleValue] as [String: Any])
        case 5:// 文件：{mediaUrl, name, md5, size}
            return JSON (["url": content["mediaUrl"].stringValue,
                          "cacheKey": String.uuid(),
                          "name": content["name"].stringValue,
                          "md5": content["md5"].stringValue,
                          "size": content["size"].doubleValue] as [String: Any])
        default:
            // 其它类型（转账/红包/名片等）暂按原样透传 content
            return content
        }
    }
}
