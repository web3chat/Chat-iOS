//
//  MessageColletionViewLayoutAttributes.swift
//  chat
//
//  Created by 陈健 on 2020/12/21.
//

import UIKit

class MessageCollectionViewLayoutAttributes: UICollectionViewLayoutAttributes {
    
    var leadingViewSize: CGSize = .zero
    var leadingViewPadding: HorizontalEdgeInsets = .zero
    var leadingViewPosition: LeadingPosition = .messageLabelTop(offset: 0)
    
    // 头像
    var avatarSize: CGSize = .zero
    var avatarPosition = AvatarPosition.init(horizontal: .cellLeading, vertical: .messageLabelTop(offset: 0))
    var avatarLeadingTrailingPadding: CGFloat = 0
    
    // 昵称和群成员类型
    var nameViewSize: CGSize = .zero
    var namePosition = NameViewPosition.init(horizontal: .avatarLeading, vertical: .messageLabelTop(offset: 0))
    var nameViewLeadingTrailingPadding: CGFloat = 0
    
    // 消息内容
    var messageContainerSize: CGSize = .zero
    var messageContainerPadding: UIEdgeInsets = .zero
    var messageLabelFont = UIFont.preferredFont(forTextStyle: .body)
    var messageLabelInsets: UIEdgeInsets = .zero
    
    // 语音消息
    var audioPosition = AudioPosition.init(horizontal: .cellLeading)
    var audioLeadingTrailingPadding: CGFloat = 0
    
    // 发送状态
    var statusViewSize: CGSize = .zero
    var statusViewPadding: CGSize = .zero
    
    // 未读红点
    var redDotViewSize: CGSize = .zero
    var redDotViewPadding: CGFloat = 0
    
    // 消息时间
    var cellTopLabelAlignment = LabelAlignment.init(textAlignment: .center, textInsets: .zero)
    var cellTopLabelSize: CGSize = .zero
    
    // 群通知消息
    var cellBottomLabelAlignment = LabelAlignment.init(textAlignment: .center, textInsets: .zero)
    var cellBottomLabelSize: CGSize = .zero
    
    var messageTopLabelAlignment = LabelAlignment(textAlignment: .center, textInsets: .zero)
    var messageTopLabelSize: CGSize = .zero
    
    var messageBottomLabelAlignment = LabelAlignment(textAlignment: .center, textInsets: .zero)
    var messageBottomLabelSize: CGSize = .zero
    
    var accessoryViewSize: CGSize = .zero
    var accessoryViewPadding: HorizontalEdgeInsets = .zero
    var accessoryViewPosition: AccessoryPosition = .messageTop
    
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! MessageCollectionViewLayoutAttributes
        copy.leadingViewSize = leadingViewSize
        copy.leadingViewPadding = leadingViewPadding
        copy.leadingViewPosition = leadingViewPosition
        copy.avatarSize = avatarSize
        copy.avatarPosition = avatarPosition
        copy.avatarLeadingTrailingPadding = avatarLeadingTrailingPadding
        copy.audioPosition = audioPosition
        copy.audioLeadingTrailingPadding = audioLeadingTrailingPadding
        copy.nameViewSize = nameViewSize
        copy.namePosition = namePosition
        copy.nameViewLeadingTrailingPadding = nameViewLeadingTrailingPadding
        copy.messageContainerSize = messageContainerSize
        copy.messageContainerPadding = messageContainerPadding
        copy.statusViewSize = statusViewSize
        copy.statusViewPadding = statusViewPadding
        copy.redDotViewSize = redDotViewSize
        copy.redDotViewPadding = redDotViewPadding
        copy.messageLabelFont = messageLabelFont
        copy.messageLabelInsets = messageLabelInsets
        copy.cellTopLabelAlignment = cellTopLabelAlignment
        copy.cellTopLabelSize = cellTopLabelSize
        copy.cellBottomLabelAlignment = cellBottomLabelAlignment
        copy.cellBottomLabelSize = cellBottomLabelSize
        copy.messageTopLabelAlignment = messageTopLabelAlignment
        copy.messageTopLabelSize = messageTopLabelSize
        copy.messageBottomLabelAlignment = messageBottomLabelAlignment
        copy.messageBottomLabelSize = messageBottomLabelSize
        copy.accessoryViewSize = accessoryViewSize
        copy.accessoryViewPadding = accessoryViewPadding
        copy.accessoryViewPosition = accessoryViewPosition
        return copy
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let attributes = object as? MessageCollectionViewLayoutAttributes  else {
            return false
        }
        return super.isEqual(object)
        && attributes.leadingViewSize == leadingViewSize
        && attributes.leadingViewPadding == leadingViewPadding
        && attributes.leadingViewPosition == leadingViewPosition
        && attributes.avatarSize == avatarSize
        && attributes.avatarPosition == avatarPosition
        && attributes.avatarLeadingTrailingPadding == avatarLeadingTrailingPadding
        && attributes.audioPosition == audioPosition
        && attributes.audioLeadingTrailingPadding == audioLeadingTrailingPadding
        && attributes.nameViewSize == nameViewSize
        && attributes.namePosition == namePosition
        && attributes.nameViewLeadingTrailingPadding == nameViewLeadingTrailingPadding
        && attributes.messageContainerSize == messageContainerSize
        && attributes.messageContainerPadding == messageContainerPadding
        && attributes.statusViewSize == statusViewSize
        && attributes.statusViewPadding == statusViewPadding
        && attributes.redDotViewSize == redDotViewSize
        && attributes.redDotViewPadding == redDotViewPadding
        && attributes.messageLabelFont == messageLabelFont
        && attributes.messageLabelInsets == messageLabelInsets
        && attributes.cellTopLabelAlignment == cellTopLabelAlignment
        && attributes.cellTopLabelSize == cellTopLabelSize
        && attributes.cellBottomLabelAlignment == cellBottomLabelAlignment
        && attributes.cellBottomLabelSize == cellBottomLabelSize
        && attributes.messageTopLabelAlignment == messageTopLabelAlignment
        && attributes.messageTopLabelSize == messageTopLabelSize
        && attributes.messageBottomLabelAlignment == messageBottomLabelAlignment
        && attributes.messageBottomLabelSize == messageBottomLabelSize
        && attributes.accessoryViewSize == accessoryViewSize
        && attributes.accessoryViewPadding == accessoryViewPadding
        && attributes.accessoryViewPosition == accessoryViewPosition
    }
}
