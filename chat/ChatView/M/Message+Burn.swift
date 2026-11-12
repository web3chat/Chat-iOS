//
//  Message+Burn.swift
//  chat
//
//  阅后即焚相关判定
//

import Foundation

extension Message {

    /// 收方待查看的阅后即焚消息：显示占位、不展示正文/缩略图/不预下载。
    /// 发方自己（isOutgoing）仍显示真实内容；已焚毁后 msgType 会变成通知消息，也不再是占位。
    var isBurnPlaceholder: Bool {
        guard isBurn, !isOutgoing else { return false }
        if case .notify = msgType { return false }
        return true
    }

    /// 是否已焚毁（已焚后 msgType 被替换为 type=8 的通知消息，文案「已阅后焚毁」）
    var isBurned: Bool {
        guard isBurn, case .notify = msgType else { return false }
        return true
    }

    /// 阅后即焚的确认对端：收方关闭详情时要通知的「消息发送者」
    var burnConfirmTargetId: String {
        return self.fromId
    }
}

extension Message.MsgType {
    /// 打上「阅后即焚」标记：**同时写入消息体 JSON**（随消息持久化，
    /// 不依赖新增的 DB 列，避免列丢失/旧库 NULL 导致标记丢失）
    func markedAsBurn() -> Message.MsgType {
        var json = self.rawValue.json
        json["burn"] = true
        return Message.MsgType(rawValue: (self.rawValue.value, json))
    }

    /// 消息体 JSON 里的阅后即焚标记
    var isBurnFlagInJSON: Bool {
        return self.rawValue.json["burn"].boolValue
    }
}
