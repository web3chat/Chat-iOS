//
//  Message+MessageType.swift
//  chat
//
//  Created by 陈健 on 2021/1/18.
//

import Foundation

extension Message: MessageType {
    var isOutgoing: Bool {
        return self.fromId == LoginUser.shared().address
    }
    var kind: MessageKind {
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
//        case .forward(_):
//            return .forward(self.msgType)
//        case .RTCCall(_):
//            return .RTCCall(self.msgType)
        case .transfer(_):
            return .transfer(self.msgType)
//        case .collect(_):
//            <#code#>
//        case .redPacket(_):
//            <#code#>
        case .contactCard(_):
            return .contactCard(self.msgType)
        default:
            return .UNRECOGNIZED(0)
//            return .text("[\(UnSupportedMsgType)]")
        }
    }
}
