//
//  BurnPendingDB.swift
//  chat
//
//  阅后即焚待确认队列
//  收方打开详情看过正文后需调 burn-confirm；为防止只写内存丢失，
//  打开即落库，confirm 成功或收到 burned 信令后删除，启动时扫描补发（接口幂等）。
//

import Foundation
import WCDBSwift

final class BurnPendingDB: TableCodable {
    /// 消息 mid（服务端 logId），主键
    var logId: Int
    /// 对端 uid（这条 burn 消息的发送者）
    var targetId: String
    /// 打开时间（毫秒时间戳）
    var openedAt: Int

    enum CodingKeys: String, CodingTableKey {
        typealias Root = BurnPendingDB
        static let objectRelationalMapping = TableBinding(CodingKeys.self)

        case logId, targetId, openedAt

        static var columnConstraintBindings: [BurnPendingDB.CodingKeys : ColumnConstraintBinding]? {
            return [logId: ColumnConstraintBinding.init(isPrimary: true)]
        }
    }

    init(logId: Int, targetId: String, openedAt: Int) {
        self.logId = logId
        self.targetId = targetId
        self.openedAt = openedAt
    }
}
