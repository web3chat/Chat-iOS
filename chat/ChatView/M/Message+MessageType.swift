//
//  Message+MessageType.swift
//  chat
//
//  Created by fzm on 2021/1/18.
//

import Foundation
import UIKit

extension Message: MessageType {
    var isOutgoing: Bool {
        return self.fromId == LoginUser.shared().address
    }
    var kind: MessageKind {
        // 收方阅后即焚占位：不展示正文/缩略图，渲染成可点击的文本气泡（点击进独立详情）
        if isBurnPlaceholder {
            return .text(L("点击查看阅后即焚消息"))
        }
        switch self.msgType {
        case .system(_):
            return .system(self.msgType.systemTextValue)
        case .text(_):
            return .text(self.msgType.textValue)
        case .audio(_):
            return .audio(self.msgType)
        case .image(_):
            return .photo(self.msgType)
        case .video(_):
            return .video(self.msgType)
        case .file(_):
            return .file(self.msgType)
        case .notify(_):
            return .notification(self.msgType)
        case .forward(_):
            // 合并转发卡片自己从 message.msgType 里读条目，这里的字符串只作占位标题
            return .forward(L("聊天记录"))
        case .transfer(_):
            return .transfer(self.msgType)
//        case .collect(_):
//            <#code#>
        case .redPacket(_):
            return .redPacket(self.msgType)
        case .contactCard(_):
            return .contactCard(self.msgType)
        default:
            return .UNRECOGNIZED(0)
//            return .text("[\(UnSupportedMsgType)]")
        }
    }
}
