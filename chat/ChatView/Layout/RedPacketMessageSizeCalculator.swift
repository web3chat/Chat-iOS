//
//  RedPacketMessageSizeCalculator.swift
//  chat
//
//  红包消息大小计算器
//

import UIKit

class RedPacketMessageSizeCalculator: MessageSizeCalculator {

    /// 红包气泡的内容尺寸。
    /// ⚠️ 必须与 `RedPacketMessageCell.redPacketContainerView` 的固定高度保持一致。
    /// 2026-09-28 放大构图：224×76 → **250×92** —— 原来单行 16pt 标题可用宽度只有 138pt，
    /// 而「恭喜发财，大吉大利！」就要 160pt，直接被截断。
    static let bubbleSize = CGSize(width: 250, height: 92)

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        switch message.kind {
        case .redPacket(let item):
            return self.sizeFor(mediaItem: item)
        case .contactCard(let card) where card.contactType == -1:
            // 安卓端的「专属红包」在 iOS 侧是一条**名片消息**（contactType == -1），
            // 由 `MessageVC` 交给 `RedPacketMessageCell` 渲染 ⇒ 这里也必须给它红包气泡的尺寸。
            // ⚠️ 漏掉这一支会落到 `super`，而 `MessageSizeCalculator.messageContainerSize` 返回 `.zero`
            // ⇒ `messageContainerView` 被算成 0×0，整条消息只剩头像，看起来就是「消息不见了」。
            return RedPacketMessageSizeCalculator.bubbleSize
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
    func sizeFor(mediaItem: RedpacketItem) -> CGSize {
        return RedPacketMessageSizeCalculator.bubbleSize
    }
}
