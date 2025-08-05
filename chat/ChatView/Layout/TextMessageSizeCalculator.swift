//
//  TextMessageSizeCalculator.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import UIKit

class TextMessageSizeCalculator: MessageSizeCalculator {

    var incomingMessageLabelInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 16)
    var outgoingMessageLabelInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 20)
    
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
    
    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        let attributedText: NSAttributedString
        switch message.kind {
        case .attributedText(let text):
            attributedText = text
        case .text(let text):
            attributedText = NSAttributedString.init(string: text, attributes: [.font: self.messageLabelFont])
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
