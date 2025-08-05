//
//  TextMessageCell.swift
//  chat
//
//  Created by 陈健 on 2020/12/25.
//

import UIKit

class TextMessageCell: MessageContentCell {
    
    override weak var delegate: MessageCellDelegate? {
        didSet {
            messageLabel.delegate = delegate
        }
    }
    
    var messageLabel = MessageLabel.init()
    
    
    override func setupViews() {
        super.setupViews()
        self.messageContainerView.addSubview(messageLabel)
        self.messageLabel.numberOfLines = 0
    }
    
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.messageLabel.attributedText = nil
        self.messageLabel.text = nil
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        guard let attributes = layoutAttributes as? MessageCollectionViewLayoutAttributes else { return }
        self.messageLabel.textInsets = attributes.messageLabelInsets
        self.messageLabel.messageLabelFont = attributes.messageLabelFont
        self.messageLabel.frame = self.messageContainerView.bounds
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        
        super.configure(with: message, at: indexPath, and: messageCollectionView)
        
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessagesDisplayDelegate")
        }
        
        messageLabel.configure {
            switch message.kind {
            case .text(let text):
                let textColor = displayDelegate.textColor(for: message, at: indexPath, in: messageCollectionView)
                messageLabel.text = text
                messageLabel.textColor = textColor
                if let font = messageLabel.messageLabelFont {
                    messageLabel.font = font
                }
            case .attributedText(let text):
                messageLabel.attributedText = text
            case .notification:
                messageLabel.text = "【通知消息】"
                messageLabel.textColor = Color_8A97A5
                if let font = messageLabel.messageLabelFont {
                    messageLabel.font = font
                }
            default:
                messageLabel.text = "[\(UnSupportedMsgType)]"
                messageLabel.textColor = Color_8A97A5
                if let font = messageLabel.messageLabelFont {
                    messageLabel.font = font
                }
                break
            }
        }
    }
    
    override func handleTapGesture(_ gesture: UIGestureRecognizer) {
        let touchLocation = gesture.location(in: self)
        let translateTouchLocation = convert(touchLocation, to: self.messageContainerView)
        guard self.messageLabel.frame.contains(translateTouchLocation),
              self.messageLabel.handleGesture(translateTouchLocation) else {
                  super.handleTapGesture(gesture)
                  return
              }
    }
}

