//
//  MediaMessageSizeCalculator.swift
//  chat
//
//  Created by fzm on 2020/12/23.
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
        var width = mediaItem.size.width
        var height = mediaItem.size.height

        // ⚠️ 服务端 / 其它端可能不带 width/height（消息 JSON 里缺失 ⇒ 0），或者给出 1×1 这类脏数据。
        //    原来会直接算出 0×0 / 1×1 的气泡 —— 用户看到的就是「这条消息什么都没有 / 只有一个点」。
        //    这里做兜底：无效尺寸给一个默认正方形，过小的按比例放大到最小可见尺寸。
        if !width.isFinite || !height.isFinite || width <= 0 || height <= 0 {
            return CGSize(width: 150, height: 150)
        }

        var maxValue = max(width, height)
        var minValue = min(width, height)
        if maxValue > 150.0 {
            minValue = minValue / maxValue * 150.0
            maxValue = 150.0
        }
        // 最小可见尺寸：短边至少 20pt（极扁的图也能看见），最长边至少 80pt（1×1 这类不会被画成一个点）
        let minLongSide: CGFloat = 80
        if maxValue < minLongSide {
            let scale = minLongSide / maxValue
            maxValue *= scale
            minValue *= scale
        }
        minValue = max(minValue, 20)

        let size = width > height ? CGSize(width: maxValue, height: minValue) : CGSize(width: minValue, height: maxValue)
        return size
    }
    
}
