//
//  ChatRecordAPI.swift
//  chat
//
//  聊天记录删除 / 阅后即焚 相关接口（服务端 /app/record/*）
//  对应文档：《删除私聊记录_App对接文档》《阅后即焚_App对接文档》
//

import Foundation
import Moya

/// 手动删除的时间范围（对应 dateOpt）
enum ChatRecordDateOption: Int {
    case custom = 0        // 自定义：需同时传 startTime / endTime
    case last1Day = 1      // 最近 1 天
    case last3Days = 2     // 最近 3 天
    case last7Days = 3     // 最近 7 天
    case last30Days = 4    // 最近 30 天
    case last90Days = 5    // 最近 90 天
    case last180Days = 6   // 最近 180 天
    case last365Days = 7   // 最近 365 天
    case all = 8           // 全部历史
}

extension ChatRecordDateOption {
    /// 展示文案
    var title: String {
        switch self {
        case .custom: return L("自定义")
        case .last1Day: return L("最近1天")
        case .last3Days: return L("最近3天")
        case .last7Days: return L("最近7天")
        case .last30Days: return L("最近30天")
        case .last90Days: return L("最近90天")
        case .last180Days: return L("最近180天")
        case .last365Days: return L("最近365天")
        case .all: return L("全部历史")
        }
    }

    /// 对应天数（custom / all 为 nil）
    var days: Int? {
        switch self {
        case .custom, .all: return nil
        case .last1Day: return 1
        case .last3Days: return 3
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90
        case .last180Days: return 180
        case .last365Days: return 365
        }
    }
}

/// 自动删除选项（对应 option）
enum ChatAutoDeleteOption: Int {
    case off = 0       // 不自动删除
    case day1 = 1      // 超过 1 天
    case day3 = 2      // 超过 3 天
    case day7 = 3      // 超过 7 天
    case day30 = 4     // 超过 30 天
    case day180 = 5    // 超过 180 天

    /// 对应保留天数（本地兜底清理用）；关闭返回 0
    var days: Int {
        switch self {
        case .off: return 0
        case .day1: return 1
        case .day3: return 3
        case .day7: return 7
        case .day30: return 30
        case .day180: return 180
        }
    }

    /// 展示文案
    var title: String {
        switch self {
        case .off: return L("关闭")
        case .day1: return L("1天")
        case .day3: return L("3天")
        case .day7: return L("7天")
        case .day30: return L("30天")
        case .day180: return L("180天")
        }
    }

    /// 所有选项（用于 action sheet）
    static var allCasesInOrder: [ChatAutoDeleteOption] {
        return [.off, .day1, .day3, .day7, .day30, .day180]
    }
}

enum ChatRecordAPI {
    /// 手动删除私聊记录（按时间范围，双方会话均生效）
    case cleanPrivate(targetId: String, dateOpt: Int, startTime: Int?, endTime: Int?)
    /// 设置自动删除
    case autoDeleteSet(targetId: String, option: Int)
    /// 查询自动删除
    case autoDeleteGet(targetId: String)
    /// 阅后即焚焚毁确认（收方关闭详情后调用）
    case burnConfirm(targetId: String, logId: Int)
}

extension ChatRecordAPI: XLSTargetType {

    var parameters: [String: Any] {
        switch self {
        case .cleanPrivate(let targetId, let dateOpt, let startTime, let endTime):
            var params: [String: Any] = ["targetId": targetId, "dateOpt": dateOpt]
            // 仅自定义（dateOpt = 0）时必填
            if dateOpt == ChatRecordDateOption.custom.rawValue {
                if let startTime = startTime { params["startTime"] = startTime }
                if let endTime = endTime { params["endTime"] = endTime }
            }
            return params
        case .autoDeleteSet(let targetId, let option):
            return ["targetId": targetId, "option": option]
        case .autoDeleteGet(let targetId):
            return ["targetId": targetId]
        case .burnConfirm(let targetId, let logId):
            return ["targetId": targetId, "logId": logId]
        }
    }

    var method: Moya.Method {
        return .post
    }

    var path: String {
        switch self {
        case .cleanPrivate:
            return "app/record/clean-private"
        case .autoDeleteSet:
            return "app/record/auto-delete/set"
        case .autoDeleteGet:
            return "app/record/auto-delete/get"
        case .burnConfirm:
            return "app/record/burn-confirm"
        }
    }
}

extension ChatRecordAPI {

    /// 手动删除私聊记录
    static func cleanPrivate(targetId: String,
                             dateOpt: ChatRecordDateOption,
                             startTime: Int? = nil,
                             endTime: Int? = nil,
                             successBlock: Provider.SuccessBlock?,
                             failureBlock: Provider.FailureBlock?) {
        Provider.request(ChatRecordAPI.cleanPrivate(targetId: targetId,
                                                    dateOpt: dateOpt.rawValue,
                                                    startTime: startTime,
                                                    endTime: endTime),
                         successBlock: successBlock,
                         failureBlock: failureBlock)
    }

    /// 设置自动删除
    static func autoDeleteSet(targetId: String,
                              option: ChatAutoDeleteOption,
                              successBlock: Provider.SuccessBlock?,
                              failureBlock: Provider.FailureBlock?) {
        Provider.request(ChatRecordAPI.autoDeleteSet(targetId: targetId, option: option.rawValue),
                         successBlock: successBlock,
                         failureBlock: failureBlock)
    }

    /// 查询自动删除
    static func autoDeleteGet(targetId: String,
                              successBlock: Provider.SuccessBlock?,
                              failureBlock: Provider.FailureBlock?) {
        Provider.request(ChatRecordAPI.autoDeleteGet(targetId: targetId),
                         successBlock: successBlock,
                         failureBlock: failureBlock)
    }

    /// 阅后即焚焚毁确认
    static func burnConfirm(targetId: String,
                            logId: Int,
                            successBlock: Provider.SuccessBlock?,
                            failureBlock: Provider.FailureBlock?) {
        Provider.request(ChatRecordAPI.burnConfirm(targetId: targetId, logId: logId),
                         successBlock: successBlock,
                         failureBlock: failureBlock)
    }
}
