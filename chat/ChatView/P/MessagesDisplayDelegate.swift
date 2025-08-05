//
//  MessagesDisplayDelegate.swift
//  chat
//
//  Created by 陈健 on 2020/12/28.
//

import Foundation

protocol MessagesDisplayDelegate: NSObjectProtocol {
    
    func collectionView(_ collectionView: MessageCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> MessageCollectionReusableView
    
    // 类型：发送/接收消息
    func messageContainerStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> MessageContainerView.Style
    
    // 头像
    func configureAvatarView(_ avatarView: AvatarView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView)
    
    // 发送状态视图
    func configureStatusView(_ statusView: UIImageView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView)
    
    // 未读红点视图
    func configureRedDotView(_ redDotView: UIView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView)
    
    // 昵称和群成员类型视图
    func configureNameView(_ nameView: NameView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView)
    
    func configureAccessoryView(_ accessoryView: UIView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView)
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> UIColor
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView)
    
    func configureAudioCell(_ cell: AudioMessageCell, message: MessageType)
    
    func audioTintColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> UIColor
    
    func audioProgressTextFormat(_ duration: Float, for audioCell: AudioMessageCell, in messageCollectionView: MessageCollectionView) -> String
}


extension MessagesDisplayDelegate {
    
    func collectionView(_ collectionView: MessageCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> MessageCollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath)
    }
    
    func messageContainerStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> MessageContainerView.Style {
        return message.isOutgoing ? .outgoing : .incoming
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) { }
    
    // 发送状态视图
    func configureStatusView(_ statusView: UIImageView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) { }
    
    // 未读红点视图
    func configureRedDotView(_ redDotView: UIView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) { }
    
    // 昵称和群成员类型视图
    func configureNameView(_ nameView: NameView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) { }
    
    func configureAccessoryView(_ accessoryView: UIView, for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) { }
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> UIColor {
        return UIColor.black
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) { }
    
    func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) { }
    
    func audioTintColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> UIColor {
        return .clear
    }
    
    func audioProgressTextFormat(_ duration: Float, for audioCell: AudioMessageCell, in messageCollectionView: MessageCollectionView) -> String {
        return ""
    }
}
