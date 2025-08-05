//
//  MessageDataSource.swift
//  chat
//
//  Created by 陈健 on 2020/12/21.
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
}
