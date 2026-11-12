//
//  MessageDataSource.swift
//  chat
//
//  Created by fzm on 2020/12/21.
//

import Foundation

protocol MessageDataSource: NSObjectProtocol {
    
    func messageCollectionView(_ messageCollectionView: MessageCollectionView, messageForItemAt indexPath: IndexPath) -> Message
    
    func numberOfSections(in messageCollectionView: MessageCollectionView) -> Int
    
    func messageCollectionView(_ messageCollectionView: MessageCollectionView, numberOfItemsInSection section: Int) -> Int
    
    func cellTopLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString?
    
    func cellBottomLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString?
    
    func messageTopLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString?
    
    func messageBottomLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString?
    
    /// 引用消息：这条消息要显示在被引用气泡下方的那条引用条内容。
    /// 返回 nil = 不显示引用条（普通消息 / 引用的原消息查不到 / 系统通知类）。
    func quotePreview(for message: Message, at indexPath: IndexPath) -> QuotePreview?
    
}

extension MessageDataSource {
    func cellTopLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        return nil
    }
    
    func cellBottomLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        return nil
    }
    
    func messageTopLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        return nil
    }
    
    func messageBottomLabelAttributedText(for message: Message, at indexPath: IndexPath) -> NSAttributedString? {
        return nil
    }
    
    func quotePreview(for message: Message, at indexPath: IndexPath) -> QuotePreview? {
        return nil
    }
}
