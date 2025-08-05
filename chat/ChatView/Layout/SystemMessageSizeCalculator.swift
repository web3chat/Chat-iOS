//
//  SystemMessageSizeCalculator.swift
//  chat
//
//  Created by 郑晨 on 2025/3/20.
//

import Foundation

class SystemMessageSizeCalculator: MessageSizeCalculator {

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        switch message.kind {
        case .system(let text):
            return self.sizeFor(mediaItem: text)
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
    func sizeFor(mediaItem: String) -> CGSize {
        let size = CGSize(width: k_ScreenWidth - 20, height: CGFloat(MAXFLOAT))
        return size
    }
    
}
