//
//  MediaMessageSizeCalculator.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import UIKit

class MediaMessageSizeCalculator: MessageSizeCalculator {

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
//        let maxWidth = self.messageContainerMaxWidth(for: message, at: indexPath)
        switch message.kind {
        case .photo(let item):
            return self.sizeFor(mediaItem: item)
        case .video(let item):
            return self.sizeFor(mediaItem: item)
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
//    func sizeFor(mediaItem: MediaItem, considering maxWidth: CGFloat) -> CGSize {
    func sizeFor(mediaItem: MediaItem) -> CGSize {
        var maxValue = max(mediaItem.size.width, mediaItem.size.height)
        var minValue = min(mediaItem.size.width, mediaItem.size.height)
        if maxValue > 150.0 {
            minValue = minValue / maxValue * 150.0
            maxValue = 150.0
        }
        let size = mediaItem.size.width > mediaItem.size.height ? CGSize(width: maxValue, height: minValue) : CGSize(width: minValue, height: maxValue)
        return size
    }
    
}
