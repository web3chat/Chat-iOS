//
//  MessagesLayoutDelegate.swift
//  chat
//
//  Created by 陈健 on 2020/12/24.
//

import Foundation

protocol MessageLayoutDataSource: NSObjectProtocol {
    
    func headerViewSize(for section: Int, in messagesCollectionView: MessageCollectionView) -> CGSize
    
    func footerViewSize(for section: Int, in messagesCollectionView: MessageCollectionView) -> CGSize
    
    func collectionView(_ collectionView: MessageCollectionView, insetForSectionAt section: Int) -> UIEdgeInsets
    
    func leadingViewWidth(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat
    
    // 消息时间
    func cellTopLabelHeight(for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat
    
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat
}

extension MessageLayoutDataSource {
    
    func headerViewSize(for section: Int, in messagesCollectionView: MessageCollectionView) -> CGSize {
        return .zero
    }
    
    func footerViewSize(for section: Int, in messagesCollectionView: MessageCollectionView) -> CGSize {
        return .zero
    }
    
    func collectionView(_ collectionView: MessageCollectionView, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
    func leadingViewWidth(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        return 0
    }
    
    // 消息时间
    func cellTopLabelHeight(for message: Message, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        return 0
    }
    
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        return 0
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        return 0
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessageCollectionView) -> CGFloat {
        return 0
    }
}
