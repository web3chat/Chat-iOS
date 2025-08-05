//
//  MessageKind.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import Foundation
import SwiftyJSON

enum MessageKind {
    //系统消息
    case system(String)
    //文字
    case text(String)
    //富文本
    case attributedText(NSAttributedString)
    //音频
    case audio(MediaItem)
    //图片
    case photo(MediaItem)
    //视频
    case video(MediaItem)
    //文件
    case file(FileItem)
    //无用
//    case card(CardItem)
    // 通知 (群聊内灰色文字通知消息)
    case notification(NotifyItem)
    // 转发消息
    case forward(String)
    // 语音视频电话
    case RTCCall(String)
    //转账
    case transfer(TransferItem)
    //收款
    case collect(String)
    //红包
    case redPacket(String)
    //名片
    case contactCard(ContactCardItem)
    //未知类型
    case UNRECOGNIZED(Int)
//    //红包
//    case redBag
//    //通知
//    case notify(String)
//    //转发消息
//    case forward
                    
}


