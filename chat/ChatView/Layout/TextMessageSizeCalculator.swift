//
//  TextMessageSizeCalculator.swift
//  chat
//
//  Created by fzm on 2020/12/23.
//

import UIKit

class TextMessageSizeCalculator: MessageSizeCalculator {

    var incomingMessageLabelInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    var outgoingMessageLabelInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    
    var messageLabelFont = UIFont.preferredFont(forTextStyle: .body)
    
    override init(layout: MessageCollectionViewLayout) {
        super.init(layout: layout)
        self.incomingAccessoryViewPadding = HorizontalEdgeInsets.zero
        self.outgoingAccessoryViewPadding = HorizontalEdgeInsets.zero
    }
    
    func messageLabelInsets(for message: MessageType) -> UIEdgeInsets {
        return message.isOutgoing ? self.outgoingMessageLabelInsets : self.incomingMessageLabelInsets
    }
    
    override func messageContainerMaxWidth(for message: Message, at indexPath: IndexPath) -> CGFloat {
        let maxWidth = super.messageContainerMaxWidth(for: message, at: indexPath)
        let textInsets = self.messageLabelInsets(for: message)
        return maxWidth - textInsets.horizontal
    }

    /// 「译文 / 转写」卡片不扣正文左右 inset，直接用气泡整体最大宽度（能多显示一点、少折一行）
    override func extraBlockMaxWidth(for message: Message, at indexPath: IndexPath) -> CGFloat {
        return super.extraBlockMaxWidth(for: message, at: indexPath)
            + self.messageLabelInsets(for: message).horizontal
    }
    
    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        // 语音 / 视频邀请：整条消息渲染成「图标 + 语音聊天 + 点击加入聊天 · 房间 …」卡片，
        // 不再按正文量高度（尺寸常量都在 `VoiceRoomInvite`）
        if case .text(let inviteText) = message.kind,
           let inviteLink = VoiceRoomInvite.link(in: inviteText) {
            let maxBubbleWidth = self.messageContainerMaxWidth(for: message, at: indexPath)
                + self.messageLabelInsets(for: message).horizontal
            return CGSize(width: VoiceRoomInvite.cardWidth(for: inviteLink, maxWidth: maxBubbleWidth),
                          height: VoiceRoomInvite.cardHeight)
        }

        // 分享链接（AI 客服 / 商城 H5）：整条消息渲染成「图标 + 标题 + 摘要 + 来源」卡片，
        // 不再按正文量高度（尺寸常量都在 `ShareLinkCard`）。
        // ⚠️ 卡片开关关闭时不走这里（气泡显示的是文本版式，高度得按文本量）
        if case .text(let shareText) = message.kind,
           FZM_EnableShareLinkCard,
           let card = ShareLinkCard.parse(shareText) {
            let maxBubbleWidth = self.messageContainerMaxWidth(for: message, at: indexPath)
                + self.messageLabelInsets(for: message).horizontal
            let cardWidth = ShareLinkCard.cardWidth(maxWidth: maxBubbleWidth)
            return CGSize(width: cardWidth, height: card.height(width: cardWidth))
        }

        let attributedText: NSAttributedString
        switch message.kind {
        case .attributedText(let text):
            attributedText = text
        case .text(let text):
            // 正文为空（解密失败 / 空消息）：气泡按占位文案量，别算成一个空气泡
            let baseText = text.isBlank ? EmptyTextPlaceholder : text
            // 卡片样式关闭时，气泡里显示的是还原后的文本版式 ⇒ 高度也要按它量
            let displayText = FZM_EnableShareLinkCard ? baseText : (ShareLinkCard.parse(baseText)?.plainText ?? baseText)
            attributedText = NSAttributedString.init(string: displayText, attributes: [.font: self.messageLabelFont])
        case .notification:
            return .zero
        default:
            attributedText = NSAttributedString.init(string: "[\(UnSupportedMsgType)]", attributes: [.font: self.messageLabelFont])
        }
        
        let maxWidth = self.messageContainerMaxWidth(for: message, at: indexPath)
        var messageContainerSize = self.labelSize(for: attributedText, considering: maxWidth)
        
        let messageInsets = self.messageLabelInsets(for: message)
        messageContainerSize.width += messageInsets.horizontal
        messageContainerSize.height += messageInsets.vertical

        // 占位文案（「该消息内容无法显示」）量出来容易刚好贴边 ⇒ 给 8pt 余量，避免显示不全
        if case .text(let text) = message.kind, text.isBlank {
            messageContainerSize.width += 8
        }

        return messageContainerSize
    }
    
    
    override func configure(attributes: MessageCollectionViewLayoutAttributes) {
        super.configure(attributes: attributes)
        
        let dataSource = self.layout.messageDataSource
        let indexPath = attributes.indexPath
        let message = dataSource.messageCollectionView(layout.messageCollecitonView, messageForItemAt: indexPath)
        
        attributes.messageLabelInsets = self.messageLabelInsets(for: message)
        attributes.messageLabelFont = self.messageLabelFont
        
        switch message.kind {
        case .attributedText(let text):
            guard !text.string.isEmpty else { return }
            guard let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else { return }
            attributes.messageLabelFont = font
        default:
            break
        }
    }
    
}
