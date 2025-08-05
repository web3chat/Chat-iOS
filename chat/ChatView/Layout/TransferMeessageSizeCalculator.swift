//
//  TransferMeessageSizeCalculator.swift
//  chat
//
//  Created by 郑晨 on 2025/3/11.
//

import Foundation

class TransferMeessageSizeCalculator: MessageSizeCalculator {

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        switch message.kind {
        case .transfer(let item):
            return self.sizeFor(mediaItem: item)
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
    func sizeFor(mediaItem: TransferItem) -> CGSize {
        let size = CGSize(width: 208, height: 80)
        return size
    }
    
}
