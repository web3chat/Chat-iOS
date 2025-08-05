//
//  AudioMessageSizeCalculator.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import UIKit

class AudioMessageSizeCalculator: MessageSizeCalculator {
    
    // 语音消息
    var incomingAudioPosition = AudioPosition.init(horizontal: .cellLeading)
    var outgoingAudioPosition = AudioPosition.init(horizontal: .cellTrailing)
    var audioLeadingTrailingPadding: CGFloat = 18
    
    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        let maxWidth = self.messageContainerMaxWidth(for: message, at: indexPath)
        switch message.kind {
        case .audio(let item):
            return self.sizeFor(audio: item, considering: maxWidth)
        default:
            return super.messageContainerSize(for: message, at: indexPath)
        }
    }
    
    func sizeFor(audio: MediaItem, considering maxWidth: CGFloat) -> CGSize {
        let width = maxWidth/60*CGFloat(audio.duration ?? 0) + 80
        return CGSize(width: min(width, maxWidth), height: 43)
    }
    
    override func configure(attributes: MessageCollectionViewLayoutAttributes) {
        
        super.configure(attributes: attributes)
        
        let dataSource = self.layout.messageDataSource
        let indexPath = attributes.indexPath
        let message = dataSource.messageCollectionView(layout.messageCollecitonView, messageForItemAt: indexPath)
        
        attributes.audioPosition = self.audioPosition(for: message)
        attributes.audioLeadingTrailingPadding = self.audioLeadingTrailingPadding
    }
    
    func audioPosition(for message: MessageType) -> AudioPosition {
        return message.isOutgoing ? self.outgoingAudioPosition : self.incomingAudioPosition
    }
}
