//
//  Message+MsgType.swift
//  chat
//
//  Created by 陈健 on 2021/1/18.
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
            let att = NSAttributedString.init(string: "[通知]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .text:
            let text = self.textValue
            let att = NSAttributedString.init(string: text, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .audio:
            let att = NSAttributedString.init(string: "[语音]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .image:
            let att = NSAttributedString.init(string: "[图片]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .video:
            let att = NSAttributedString.init(string: "[视频]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .file:
            let text = self.fileName!
            let att = NSAttributedString.init(string: "[文件]\(text)", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
//        case .card:
//            let nameStr = self.name ?? ""
//            let att = NSAttributedString.init(string: "[名片]\(nameStr)", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
//            return att
        case .notify:// [通知]
            let text = self.text
            let att = NSAttributedString.init(string: text, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .forward:
            let att = NSAttributedString.init(string: "[转发消息]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .RTCCall:
            let att = NSAttributedString.init(string: "[语音/视频通话]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .transfer:
            let att = NSAttributedString.init(string: "[转账]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .collect:
            let att = NSAttributedString.init(string: "[收款]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .redPacket:
            let att = NSAttributedString.init(string: "[红包]", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor : Color_8A97A5])
            return att
        case .contactCard:
            let pre = self.contactType == -1 ? "[专属红包]" : "[名片]"
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

extension Message.MsgType: MediaItem {
    
    var url: String? {
        let json = self.rawValue.json
        guard let urlString = json["url"].string  else { return nil }
        return urlString
    }
    
    func imageAsync(block: @escaping (UIImage?)->()) {
        let json = self.rawValue.json
        guard let cacheKey = json["cacheKey"].string else { block(nil); return }
        
        ImageCache.default.clearMemoryCache()
        ImageCache.default.retrieveImage(forKey: cacheKey) { (result) in
            guard case .success(let cache) = result,
                  let image = cache.image else {
                block(nil)
                return
            }
            block(image)
        }//6AE381CE-BC52-4C6A-B58A-B5EEE3610507
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
//        ImageCache.default.clearMemoryCache()
//        ImageCache.default.retrieveImage(forKey: cacheKey) { (result) in
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
    init(notify text: String, type:Int, groupId: Int, operatorId: String?, groupname: String?, inviter: String?, members: [String]?, mutetype: Int?, newOwner: String?) {
        let memberStr = members?.joined(separator: ",")
        let dic = ["content": text,
                   "type": type,
                   "groupId": groupId,
                   "operatorId": operatorId as Any,
                   "groupname": groupname as Any,
                   "inviter": inviter as Any,
                   "members": memberStr as Any,
                   "mutetype": mutetype as Any,
                   "newOwner": newOwner as Any]
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
    
    // 转账
    init(transfer coinName:String,txHash:String) {
        let dic = ["coinName":coinName,
                   "txHash":txHash] as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (10,json)
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
