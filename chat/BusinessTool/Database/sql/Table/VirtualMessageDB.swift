//
//  VirtualMessageDB.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/25.
//

import UIKit
import WCDBSwift
import SwiftyJSON

//MARK: 消息
final class VirtualMessageDB: TableCodable {
    let msgId: String
    let content: String
    let sessionId: String
    enum CodingKeys: String, CodingTableKey {
        typealias Root = VirtualMessageDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case msgId
        case content
        case sessionId
        
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .msgId : ColumnConstraintBinding(isPrimary: true, isAutoIncrement: false),
            ]
        }
        static var virtualTableBinding: VirtualTableBinding? {
            return VirtualTableBinding(with: .fts3, and: ModuleArgument(with: .WCDB))
        }
    }
    
    init?(with messageDb: MessageDB) {
        let type = Message.init(with: messageDb).kind
        
        var msgConten = ""
        
        switch type {
        case .text, .file:
            msgConten = messageDb.msg
            //wjhTODO
//        case .forward://转发消息
//            msgConten = messageDb.msg
        default: break
            
        }
        
//        if type == .text {
//            msgConten = dbMessage.contentForSearch
//        } else if type == .forward {
//            msgConten = SocketMessageBody(with: dbMessage.jsonData, type: type).forwardMsgs.compactMap { $0.msgType == .text ? $0.body.content : nil }.joined()
//        }
        guard !msgConten.isEmpty else { return nil }
        /**
         msgConten.substring(with: msgConten.index(msgConten.startIndex, offsetBy: 17) ..< msgConten.index(msgConten.endIndex, offsetBy: -3))
         */
        content = msgConten
        let logId = messageDb.logId?.string ?? ""// 服务端返回的消息id
        msgId = !messageDb.msgId.isEmpty ? messageDb.msgId : logId
        sessionId = messageDb.sessionId
    }
}
