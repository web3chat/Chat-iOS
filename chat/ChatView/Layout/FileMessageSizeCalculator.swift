//
//  FileMessageSizeCalculator.swift
//  chat
//
//  Created by fzm on 2021/12/23.
//

import Foundation

class FileMessageSizeCalculator: MessageSizeCalculator {

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        switch message.kind {
        case .file(let item):
            return self.sizeFor(mediaItem: item)
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
    func sizeFor(mediaItem: FileItem) -> CGSize {
        let size = CGSize(width: 240, height: 100)
        return size
    }
    
}
