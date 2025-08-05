//
//  ContactCardMessageSizeCalculator.swift
//  chat
//
//  Created by 郑晨 on 2025/3/20.
//

import Foundation

class ContactCardMessageSizeCalculator: MessageSizeCalculator {

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        switch message.kind {
        case .contactCard(let item):
            return self.sizeFor(mediaItem: item)
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
    func sizeFor(mediaItem: ContactCardItem) -> CGSize {
        let size = CGSize(width: 240, height: 100)
        return size
    }
    
}
