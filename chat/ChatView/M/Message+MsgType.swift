//
//  Message+MsgType.swift
//  chat
//
//  Created by fzm on 2021/1/18.
//

import Foundation
import Kingfisher
import SwiftyJSON

extension Message {
    enum MsgType {
        typealias RawValue = (value: Int, json: JSON)
        case system(RawValue) //0   系统消息
        case text(RawValue)   //1   文字
        case audio(RawValue)  //2   音频
        case image(RawValue)  //3   图片
        case video(RawValue)  //4   视频
        case file(RawValue)   //5   文件
//        case card(RawValue)   //6
        case notify(RawValue) //7   通知 (群聊内灰色文字通知消息)
        case forward(RawValue)//8   转发消息
        case RTCCall(RawValue)//9   语音视频电话
        case transfer(RawValue)//10 转账
        case collect(RawValue)//11  收款
        case redPacket(RawValue)//12    红包
        case contactCard(RawValue)//13  名片
        case unknown(RawValue)
    }
}

extension Message.MsgType {
    init(rawValue: RawValue) {
        switch rawValue.value {
        case 0:
            self = Message.MsgType.system(rawValue)
        case 1:
            self = Message.MsgType.text(rawValue)
        case 2:
            self = Message.MsgType.audio(rawValue)
        case 3:
            self = Message.MsgType.image(rawValue)
        case 4:
            self = Message.MsgType.video(rawValue)
        case 5:
            self = Message.MsgType.file(rawValue)
//        case 6:
//            self = Message.MsgType.card(rawValue)
        case 7:
            self = Message.MsgType.notify(rawValue)
        case 8:
            self = Message.MsgType.forward(rawValue)
        case 9:
            self = Message.MsgType.RTCCall(rawValue)
        case 10:
            self = Message.MsgType.transfer(rawValue)
        case 11:
            self = Message.MsgType.collect(rawValue)
        case 12:
            self = Message.MsgType.redPacket(rawValue)
        case 13:// 名片
            self = Message.MsgType.contactCard(rawValue)
        default:
            self = Message.MsgType.unknown(rawValue)
        }
    }
    var rawValue: RawValue {
        switch self {
        case .system(let value):
            return value
        case .text(let value):
            return value
        case .audio(let value):
            return value
        case .image(let value):
            return value
        case .video(let value):
            return value
        case .file(let value):
            return value
//        case .card(let value):
//            return value
        case .notify(let value):
            return value
        case .forward(let value):
            return value
        case .unknown(let value):
            return value
        case .RTCCall(let value):
            return value
        case .transfer(let value):
            return value
        case .collect(let value):
            return value
        case .redPacket(let value):
            return value
        case .contactCard(let value):
            return value
        }
    }
}

extension Message.MsgType {
    // 会话列表显示的最新消息
    var preview: NSAttributedString {
        switch self {
        case .system:
            let att = NSAttributedString.init(string: L("[通知]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .text:
            let text = self.textValue
            // 语音聊天邀请消息：正文是「文案 + 房间链接」，会话列表里只显示 [语音聊天] / [视频聊天]
            //（判定与气泡一致，都走 `VoiceRoomInvite.link(in:)`）
            if let link = VoiceRoomInvite.link(in: text) {
                let title = VoiceRoomService.mode(of: link) == .video ? L("[视频聊天]") : L("[语音聊天]")
                return NSAttributedString.init(string: title, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            }
            // 分享链接卡片（AI 客服 / 商城 H5）：会话列表只显示卡片标题（不露链接）
            if let card = ShareLinkCard.parse(text) {
                let att = NSAttributedString.init(string: card.title, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
                return att
            }
            let att = NSAttributedString.init(string: text, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .audio:
            let att = NSAttributedString.init(string: L("[语音]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .image:
            let att = NSAttributedString.init(string: L("[图片]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .video:
            let att = NSAttributedString.init(string: L("[视频]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .file:
            let text = self.fileName!
            let att = NSAttributedString.init(string: L("[文件]")+"\(text)", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
//        case .card:
//            let nameStr = self.name ?? ""
//            let att = NSAttributedString.init(string: "[名片]\(nameStr)", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
//            return att
        case .notify:// [通知]
            var text = self.text
            let keyword = L("重新编辑")
            if text.contains(keyword) {
              text = text.replacingOccurrences(of: keyword, with: "")
            }
            let att = NSAttributedString.init(string: L("[通知]") + text, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .forward:
            let att = NSAttributedString.init(string: L("[转发消息]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .RTCCall:
            let att = NSAttributedString.init(string: L("[语音/视频通话]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .transfer:
            let att = NSAttributedString.init(string: L("[转账]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .collect:
            let att = NSAttributedString.init(string: L("[收款]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .redPacket:
            let att = NSAttributedString.init(string: L("[红包]"), attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .contactCard:
            let pre = self.contactType == -1 ? L("[专属红包]") : L("[名片]")
            let att = NSAttributedString.init(string: pre, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .unknown:
            let att = NSAttributedString.init(string: "[\(UnSupportedMsgType)]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        }
    }
}

extension Message.MsgType: Equatable {
    static func == (lhs: Message.MsgType, rhs: Message.MsgType) -> Bool {
        return lhs.rawValue.value == rhs.rawValue.value
    }
}

extension Message.MsgType {
    var intValue: Int { self.rawValue.value }
    
    var textValue: String {
        guard case let .text(value) = self else { return "" }
        return value.json["content"].stringValue
    }
    
    var systemTextValue:String {
        guard case let .system(value) = self else {
            return ""
        }
        return value.json["content"].stringValue

    }
}

//extension Message.MsgType: ForwardItem {
//    var forwardAvatar: String? {
//        let json = self.rawValue.json
//        guard let contactId = json["contactId"].string  else { return nil }
//        return contactId
//    }
//    
//    var forwardName: String? {
//        let json = self.rawValue.json
//        guard let contactId = json["contactId"].string  else { return nil }
//        return contactId
//    }
//    
//    var forwardMsgType: Int? {
//        let json = self.rawValue.json
//        guard let contactId = json["contactId"].int  else { return nil }
//        return contactId
//    }
//    
//    var forwardMsg: Data? {
//        let json = self.rawValue.json
//        guard let contactId = json["contactId"].data  else { return nil }
//        return contactId
//    }
//    
//    var forwardDatetime: Int? {
//        let json = self.rawValue.json
//        guard let contactId = json["contactId"].int  else { return nil }
//        return contactId
//    }
//}

extension Message.MsgType: ContactCardItem {
    var contactId: String? {
        let json = self.rawValue.json
        guard let contactId = json["contactId"].string  else { return nil }
        return contactId
    }
    
    var contactName: String? {
        let json = self.rawValue.json
        guard let contactName = json["contactName"].string  else { return nil }
        return contactName
    }
    
    var contactAvatar: String? {
        let json = self.rawValue.json
        guard let contactAvatar = json["contactAvatar"].string  else { return nil }
        return contactAvatar
    }
    
    var contactType: Int? {
        let json = self.rawValue.json
        guard let contactType = json["contactType"].int  else { return nil }
        return contactType
    }
}

// MARK: - 合并转发条目的摘要

extension Message.MsgType.ForwardItem {
    /// 列表/详情页里显示的摘要：文本直接用原文，其他类型用类型占位
    var summaryText: String {
        switch msgType {
        case 0, 1:// 系统 / 文本：body 都是 TextMsg
            if let text = (try? PbMsg_TextMsg.init(serializedData: msg))?.content, !text.isBlank {
                // 分享链接卡片（AI 客服 / 商城 H5）：摘要只显示标题
                if let card = ShareLinkCard.parse(text) { return card.title }
                return text
            }
            return "[\(UnSupportedMsgType)]"
        case 2:
            return L("[语音]")
        case 3:
            return L("[图片]")
        case 4:
            return L("[视频]")
        case 5:
            let name = (try? PbMsg_FileMsg.init(serializedData: msg))?.name ?? ""
            return L("[文件]") + name
        case 7:
            return L("[通知]")
        case 8:
            return L("[转发消息]")
        case 10:
            return L("[转账]")
        case 11:
            return L("[收款]")
        case 12:
            return L("[红包]")
        case 13:
            return L("[名片]")
        default:
            return "[\(UnSupportedMsgType)]"
        }
    }
}

extension Message.MsgType: MediaItem {
    
    var url: String? {
        let json = self.rawValue.json
        guard let urlString = json["url"].string  else { return nil }
        return urlString
    }
    
    func imageAsync(block: @escaping (UIImage?)->()) {
        let json = self.rawValue.json
        guard let cacheKey = json["cacheKey"].string else { block(nil); return }

        // ⚠️ 不能直接用 `retrieveImage(forKey:)`：磁盘缓存取回的 JPEG 默认未解码，
        //    直接显示会让 CA 在主线程硬解原图（超大图会在 CMPhoto 里 SIGSEGV，2026-10-13）。
        //    统一走 safeRetrieveImage：降采样 + 立即解码。
        ChatMediaCache.safeRetrieveImage(forKey: cacheKey, maxPixelSize: 2048) { image in
            block(image)
        }
    }
    
    var duration: Double? {
        let json = self.rawValue.json
        return json["duration"].double
    }
    
    var size: CGSize {
        let json = self.rawValue.json
        let width = json["width"].doubleValue
        let height = json["height"].doubleValue
        return CGSize.init(width: width, height: height)
    }
    
    var mediaCachekey: String? {
        let json = self.rawValue.json
        guard let cacheKey = json["cacheKey"].string else { return nil }
        return cacheKey
    }
}

extension Message.MsgType: FileItem {
    var fileSize: Int? {
        let json = self.rawValue.json
        return json["size"].int
    }
    
    var fileUrl: String? {
        let json = self.rawValue.json
        guard let urlString = json["url"].string  else { return nil }
        return urlString
    }
    
    var fileName: String? {
        let json = self.rawValue.json
        guard let fileName = json["name"].string  else { return nil }
        return fileName
    }
    
    var localFilePath: String? {//wjhTODO
//        let json = self.rawValue.json
//        guard let cacheKey = json["cacheKey"].string else { block(nil); return }
//
//        ChatMediaCache.clearMemoryCache()
//        ChatMediaCache.retrieveImage(forKey: cacheKey) { (result) in
//            guard case .success(let cache) = result,
//                  let image = cache.image else {
//                block(nil)
//                return
//            }
//            block(image)
//        }//6AE381CE-BC52-4C6A-B58A-B5EEE3610507
        
        return ""
    }
    
    var md5: String? {
        let json = self.rawValue.json
        guard let fileName = json["md5"].string  else { return nil }
        return fileName
    }
    
    var iconImageName: String? {
        let json = self.rawValue.json
        guard let fileUrl = json["url"].string  else { return nil }
        let imageName = (fileUrl.count > 0 ? (fileUrl as String).pathExtension : ((localFilePath ?? "") as String).pathExtension).matchingFileType()
        return imageName
    }
    
    var cachekey: String? {
        let json = self.rawValue.json
        guard let cacheKey = json["cacheKey"].string else { return nil }
        
        return cacheKey
    }
}

extension Message.MsgType: NotifyItem {
    
    var text: String {
        let json = self.rawValue.json
        guard let text = json["content"].string  else { return "" }
        return text
    }
    
    var type: Int {
        let json = self.rawValue.json
        guard let type = json["type"].int  else { return 0 }
        return type
    }
    
    var groupId: Int {
        let json = self.rawValue.json
        guard let groupId = json["groupId"].int  else { return 0 }
        return groupId
    }
    
    var operatorId: String? {
        let json = self.rawValue.json
        guard let operatorId = json["operatorId"].string  else { return nil }
        return operatorId
    }
    
    var groupname: String? {
        let json = self.rawValue.json
        guard let groupname = json["groupname"].string  else { return nil }
        return groupname
    }
    
    var inviter: String? {
        let json = self.rawValue.json
        guard let inviter = json["inviter"].string  else { return nil }
        return inviter
    }
    
    var members: [String]? {
        let json = self.rawValue.json
        let memberStr = json["members"].string
        guard let str = memberStr else {
            return nil
        }
        let arrSubStrings = str.split(separator: ",")
        let arrStrings = arrSubStrings.compactMap { "\($0)" }
        
        return arrStrings
    }
    
    var mutetype: Int? {
        let json = self.rawValue.json
        guard let mutetype = json["mutetype"].int  else { return nil }
        return mutetype
    }
    
    var newOwner: String? {
        let json = self.rawValue.json
        guard let newOwner = json["newOwner"].string  else { return nil }
        return newOwner
    }
    
    // 撤回消息时保留的原文内容（用于"重新编辑"）
    var revokedContent: String? {
        let json = self.rawValue.json
        guard let revokedContent = json["revokedContent"].string  else { return nil }
        return revokedContent
    }
}

extension Message.MsgType:TransferItem {
    var coinName: String? {
        let json = self.rawValue.json
        guard let coinName = json["coinName"].string  else { return "" }
        return coinName
    }

    var txHash: String? {
        let json = self.rawValue.json
        guard let recordId = json["txHash"].string  else { return "" }
        return recordId
    }

}

extension Message.MsgType: RedpacketItem {
    var redcoinName: String? {
        let json = self.rawValue.json
        return json["coinName"].string
    }

    var redtxHash: String? {
        let json = self.rawValue.json
        return json["txHash"].string
    }
    var exec: String? {
        let json = self.rawValue.json
        return json["exec"].string
    }

    var packetType: Int? {
        let json = self.rawValue.json
        return json["packetType"].int
    }

    var remark: String? {
        let json = self.rawValue.json
        return json["remark"].string
    }

    var expire: UInt64? {
        let json = self.rawValue.json
        return json["expire"].uInt64
    }
}

//MARK: - Convenience Init
extension Message.MsgType {
    //0   系统消息
    init(system: String) {
        let dic = ["content": system]
        let json = JSON.init(dic)
        let rawValue = (0, json)
        self.init(rawValue: rawValue)
    }
    
    //1   文字
    init(text: String) {
        let dic = ["content": text]
        let json = JSON.init(dic)
        let rawValue = (1, json)
        self.init(rawValue: rawValue)
    }
    
    //2   音频
    init(audio audioUrl: String?, duration: Double, cacheKey: String?, width: Double, height: Double) {
        let dic = ["url": audioUrl as Any,
                   "duration": duration,
                   "cacheKey": cacheKey as Any,
                   "width": width,
                   "height": height,]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (2, json)
        self.init(rawValue: rawValue)
    }
    
    //3   图片
    init(image imageUrl: String?, cacheKey: String?, width: Double, height: Double) {
        let dic = ["url": imageUrl as Any,
                   "cacheKey": cacheKey as Any,
                   "width": width,
                   "height": height,]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (3, json)
        self.init(rawValue: rawValue)
    }
    
    //4   视频
    init(video videoUrl: String?, cacheKey: String?, duration: Double, width: Double, height: Double) {
        let dic = ["url": videoUrl as Any,
                   "cacheKey": cacheKey as Any,
                   "duration": duration,
                   "width": width,
                   "height": height,]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (4, json)
        self.init(rawValue: rawValue)
    }
    
    //5   文件
    init(file fileUrl: String?, cacheKey: String?, name: String?, md5: String?, size: Double) {
        let dic = ["url": fileUrl as Any,
                   "cacheKey": cacheKey as Any,
                   "name": name as Any,
                   "md5": md5 as Any,
                   "size": size,]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (5, json)
        self.init(rawValue: rawValue)
    }
    
    //7   通知 (群聊内灰色文字通知消息)
    init(notify text: String, type:Int, groupId: Int, operatorId: String?, groupname: String?, inviter: String?, members: [String]?, mutetype: Int?, newOwner: String?, revokedContent: String? = nil) {
        let memberStr = members?.joined(separator: ",")
        let dic = ["content": text,
                   "type": type,
                   "groupId": groupId,
                   "operatorId": operatorId as Any,
                   "groupname": groupname as Any,
                   "inviter": inviter as Any,
                   "members": memberStr as Any,
                   "mutetype": mutetype as Any,
                   "newOwner": newOwner as Any,
                   "revokedContent": revokedContent as Any]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (7, json)
        self.init(rawValue: rawValue)
    }
    
    //8   转发消息
    init(forward contactId: String, name: String, avatar: String, type: Int) {
        let dic = ["contactId": contactId,
                   "contactName": name,
                   "contactAvatar": avatar,
                   "contactType": type]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (8, json)
        self.init(rawValue: rawValue)
    }
    
    // MARK: - 合并转发（msgType = 8）
    
    /// 合并转发里的单条记录。
    /// `msg` 是该条消息**原始的消息体字节**（即 `PbMsg_msg.msg`，加密前写入、未加密），
    /// 接收端拿到后可直接反序列化成 `PbMsg_TextMsg` / `PbMsg_ImageMsg` 等还原内容。
    struct ForwardItem {
        var avatar: String
        var name: String
        var msgType: Int
        var msg: Data
        var datetime: Int
    }
    
    /// 用一组条目构造合并转发消息（8）
    init(forwardItems items: [ForwardItem]) {
        let arr: [[String: Any]] = items.map { item in
            return ["avatar": item.avatar,
                    "name": item.name,
                    "msgType": item.msgType,
                    "msg": item.msg.base64EncodedString(),
                    "datetime": item.datetime]
        }
        let json = JSON.init(["items": arr] as [String : Any])
        self.init(rawValue: (8, json))
    }
    
    /// 合并转发的条目列表（非合并转发消息返回 nil）
    var forwardItems: [ForwardItem]? {
        guard case .forward(let rawValue) = self else { return nil }
        let arr = rawValue.json["items"].array ?? []
        let items: [ForwardItem] = arr.compactMap { itemJson in
            guard let base64 = itemJson["msg"].string,
                  let data = Data(base64Encoded: base64) else { return nil }
            return ForwardItem(avatar: itemJson["avatar"].string ?? "",
                               name: itemJson["name"].string ?? "",
                               msgType: itemJson["msgType"].int ?? 0,
                               msg: data,
                               datetime: itemJson["datetime"].int ?? 0)
        }
        return items.isEmpty ? nil : items
    }
    
    /// 合并转发里某一条的摘要文案（详情页与卡片预览共用）
    var forwardSummary: String {
        return self.forwardItems?.first?.summaryText ?? L("[转发消息]")
    }
    
    // 转账
    init(transfer coinName:String,txHash:String) {
        let dic = ["coinName":coinName,
                   "txHash":txHash] as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (10,json)
        self.init(rawValue: rawValue)
    }

    // 红包
    init(redPacket txHash: String, coinName: String, exec: String = "", packetType: Int = 0, remark: String = "", expire: UInt64 = 0) {
        let dic: [String: Any] = [
            "txHash": txHash,
            "coinName": coinName,
            "exec": exec,
            "packetType": packetType,
            "remark": remark,
            "expire": expire
        ]
        let json = JSON.init(dic)
        let rawValue = (12, json)
        self.init(rawValue: rawValue)
    }

    // 名片
    init(contactCard contactId: String, name: String, avatar: String, type: Int) {
        let dic = ["contactId": contactId,
                   "contactName": name,
                   "contactAvatar": avatar,
                   "contactType": type]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (13, json)
        self.init(rawValue: rawValue)
    }
}
