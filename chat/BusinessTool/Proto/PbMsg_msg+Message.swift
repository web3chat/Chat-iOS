//
//  PbMsg_msg+Message.swift
//  chat
//
//  Created by 陈健 on 2021/1/20.
//  序列化消息结构
//

import Foundation

extension PbMsg_msg {
    /// 序列化消息结构体
    init(with msg: Message) {
        self.channelType = Int32(msg.channelType.rawValue)
        self.msgID = msg.msgId
        self.from = msg.fromId
        self.target = msg.targetId
        self.datetime = UInt64(msg.datetime)
        self.msgType = PbMsg_MsgType.init(rawValue: msg.msgType.intValue) ?? .UNRECOGNIZED(msg.msgType.intValue)
        if let ref = msg.reference {// 引用
            self.reference.topic = Int64(ref.topic)
            self.reference.ref = Int64(ref.ref)
        }
        
        var data = Data.init()
        
        switch msg.msgType {
        case .system:
            var textMsg = PbMsg_TextMsg.init()
            textMsg.content = msg.msgType.textValue
            data = (try? textMsg.serializedData()) ?? Data.init()
        case .text:
            var textMsg = PbMsg_TextMsg.init()
            textMsg.content = msg.msgType.textValue
            // 群聊'@'谁
            //wjhTODO
            if msg.channelType == .group, let mentionIds = msg.mentionIds, mentionIds.count > 0 {
                textMsg.mention = mentionIds
            }
            data = (try? textMsg.serializedData()) ?? Data.init()
        case .audio:
            var audioMsg = PbMsg_AudioMsg.init()
            audioMsg.mediaURL = msg.msgType.url ?? ""
            audioMsg.time = Int32(msg.msgType.duration ?? 0)
            data = (try? audioMsg.serializedData()) ?? Data.init()
        case .image:
            var imageMsg = PbMsg_ImageMsg.init()
            imageMsg.mediaURL = msg.msgType.url ?? ""
            imageMsg.width = Int32(msg.msgType.size.width)
            imageMsg.height = Int32(msg.msgType.size.height)
            data = (try? imageMsg.serializedData()) ?? Data.init()
        case .video:
            var videoMsg = PbMsg_VideoMsg.init()
            videoMsg.mediaURL = msg.msgType.url ?? ""
            videoMsg.width = Int32(msg.msgType.size.width)
            videoMsg.height = Int32(msg.msgType.size.height)
            videoMsg.time = Int32(msg.msgType.duration ?? 0)
            data = (try? videoMsg.serializedData()) ?? Data.init()
        case .file:
            var fileMsg = PbMsg_FileMsg.init()
            fileMsg.mediaURL = msg.msgType.url ?? ""
            fileMsg.name = msg.msgType.fileName ?? ""
            fileMsg.md5 = msg.msgType.md5 ?? ""
            fileMsg.size = Int64(msg.msgType.fileSize ?? 0)
            data = (try? fileMsg.serializedData()) ?? Data.init()
//        case .card:
//            break
        case .notify:
            break
        case .forward:
            break
        case .RTCCall:
            break
        case .transfer:
            var transferMsg = PbMsg_TransferMsg.init()
            transferMsg.coinName = msg.msgType.coinName ?? ""
            transferMsg.txHash = msg.msgType.txHash ?? ""
            data = (try? transferMsg.serializedData()) ?? Data.init()
            break
        case .collect:
            break
        case .redPacket:
            break
        case .contactCard:
            var contactCardMsg = PbMsg_ContactCardMsg.init()
            contactCardMsg.id = msg.msgType.contactId ?? ""
            contactCardMsg.name = msg.msgType.contactName ?? ""
            contactCardMsg.avatar = msg.msgType.contactAvatar ?? ""
            contactCardMsg.type = PbMsg_CardType(rawValue:  msg.msgType.contactType ?? 0)!
            data = (try? contactCardMsg.serializedData()) ?? Data.init()
            break
        case .unknown:
            break
        }
        
        self.msg = data
    }
}
