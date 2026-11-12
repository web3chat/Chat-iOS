//
//  PriChatRecordAPI.swift
//  chat
//
//  获取私聊聊天记录（服务端 /store/app/pri-chat-record）
//  对应文档：《获取私聊记录_App对接文档》
//

import Foundation
import Moya

enum PriChatRecordAPI {
    /// 拉取当前用户与 targetId 的私聊历史（logId 为分页游标，取上一页最小 logId；不传则从最新开始）
    case records(targetId: String, count: Int, logId: String?)
}

extension PriChatRecordAPI: XLSTargetType {

    var parameters: [String: Any] {
        switch self {
        case .records(let targetId, let count, let logId):
            var params: [String: Any] = ["targetId": targetId, "count": count]
            if let logId = logId, !logId.isEmpty {
                params["logId"] = logId
            }
            return params
        }
    }

    var method: Moya.Method {
        return .post
    }

    var path: String {
        return "store/app/pri-chat-record"
    }
}

extension PriChatRecordAPI {

    /// 拉取私聊历史记录
    static func records(targetId: String,
                        count: Int,
                        logId: String? = nil,
                        successBlock: Provider.SuccessBlock?,
                        failureBlock: Provider.FailureBlock?) {
        Provider.request(PriChatRecordAPI.records(targetId: targetId, count: count, logId: logId),
                         successBlock: successBlock,
                         failureBlock: failureBlock)
    }
}
