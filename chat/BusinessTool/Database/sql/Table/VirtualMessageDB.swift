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
        // 只收「文字(1) / 文件(5)」两类消息（等价于原来 `Message.init(with:).kind == .text/.file` 的判断），
        // 但**不再构造整个 Message**：构造它要解析 msg 里的 JSON，还会走 `kind`（内部会创建
        // NSAttributedString 这类 UI 对象）—— 在数据库队列上批量跑既慢，又把一堆无关代码
        //（含强解包、attributedString 拼接）拉进了「写虚表」这条路径，属崩溃高危区。
        guard messageDb.msgType == 1 || messageDb.msgType == 5 else { return nil }

        let msgConten = messageDb.msg
        guard !msgConten.isEmpty else { return nil }

        content = msgConten
        let logId = messageDb.logId?.string ?? ""// 服务端返回的消息id
        msgId = !messageDb.msgId.isEmpty ? messageDb.msgId : logId
        sessionId = messageDb.sessionId
    }
}
