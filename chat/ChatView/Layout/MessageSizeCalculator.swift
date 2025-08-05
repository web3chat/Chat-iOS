//
//  MessageSizeCalculator.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

let NameViewMaxWidth = k_ScreenWidth - (10 + 35 + 10)*2

import UIKit

class MessageSizeCalculator: CellSizeCalculator {
    
    var incomingLeadingViewSize = CGSize.zero
    var outgoingLeadingViewSize = CGSize.zero
    
    var incomingLeadingViewPadding = HorizontalEdgeInsets.zero
    var outgoingLeadingViewPadding = HorizontalEdgeInsets.zero
    
    var incomingLeadingViewPosition: LeadingPosition = .messageLabelTop(offset: 0)
    var outgoingLeadingViewPosition: LeadingPosition = .messageLabelTop(offset: 0)
    
    // 头像size
    var incomingAvatarSize = CGSize.init(width: 35, height: 35)
    var outgoingAvatarSize = CGSize.init(width: 35, height: 35)
    
    // 头像位置
    var incomingAvatarPosition = AvatarPosition.init(horizontal: .cellLeading, vertical: .messageLabelTop(offset: 0))
    var outgoingAvatarPosition = AvatarPosition.init(horizontal: .cellTrailing, vertical: .messageLabelTop(offset: 0))
    
    // 头像间距
    var avatarLeadingTrailingPadding: CGFloat = 0
    
    // 昵称size
    var incomingNameViewSize = CGSize.init(width: NameViewMaxWidth, height: 18)// 头像宽+前后间距
    var outgoingNameViewSize = CGSize.init(width: NameViewMaxWidth, height: 18)
    
    // 昵称位置
    var incomingNameViewPosition = NameViewPosition.init(horizontal: .avatarLeading, vertical: .messageLabelTop(offset: 0))
    var outgoingNameViewPosition = NameViewPosition.init(horizontal: .avatarTrailing, vertical: .messageLabelTop(offset: 0))
    
    // 昵称间距
    var nameViewLeadingTrailingPadding: CGFloat = 10
    
    // 消息内容视图间距
    var incomingMessagePadding = UIEdgeInsets.init(top: 0, left: 10, bottom: 15, right: 10)
    var outgoingMessagePadding = UIEdgeInsets.init(top: 0, left: 10, bottom: 15, right: 10)
    var incomingGroupMessagePadding = UIEdgeInsets.init(top: 20, left: 10, bottom: 15, right: 10)
    var outgoingGroupMessagePadding = UIEdgeInsets.init(top: 20, left: 10, bottom: 15, right: 10)
    
    // 消息发送状态size和间距
    var statusSize = CGSize.init(width: 22, height: 22)
    var statusPadding = CGSize.init(width: 10, height: 9)
    
    // 语音消息未读红点size和间距
    var redDotSize = CGSize.init(width: 7, height: 7)
    var redDotPadding: CGFloat = 5
    
    // 消息时间戳内容对齐方式
    var incomingCellTopLabelAlignment = LabelAlignment.init(textAlignment: .center, textInsets: .zero)
    var outgoingCellTopLabelAlignment = LabelAlignment.init(textAlignment: .center, textInsets: .zero)
    
    // 通知消息内容对齐方式
    var incomingCellBottomLabelAlignment = LabelAlignment.init(textAlignment: .center, textInsets: UIEdgeInsets.init(top: 0, left: 42, bottom: 0, right: 0))
    var outgoingCellBottomLabelAlignment = LabelAlignment.init(textAlignment: .center, textInsets: UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 42))
    
    var incomingMessageTopLabelAlignment = LabelAlignment.init(textAlignment: .left, textInsets: UIEdgeInsets.init(top: 0, left: 42, bottom: 0, right: 0))
    var outgoingMessageTopLabelAlignment = LabelAlignment.init(textAlignment: .right, textInsets: UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 42))
    
    var incomingMessageBottomLabelAlignment = LabelAlignment.init(textAlignment: .left, textInsets: UIEdgeInsets.init(top: 0, left: 42, bottom: 0, right: 0))
    var outgoingMessageBottomLabelAlignment = LabelAlignment.init(textAlignment: .right, textInsets: UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 42))
    
    var incomingAccessoryViewSize = CGSize.zero
    var outgoingAccessoryViewSize = CGSize.zero
    
    var incomingAccessoryViewPadding = HorizontalEdgeInsets.init(left: 10, right: 0)
    var outgoingAccessoryViewPadding = HorizontalEdgeInsets.init(left: 0, right: 10)
    
    var incomingAccessoryViewPosition: AccessoryPosition = .messageTop
    var outgoingAccessoryViewPosition: AccessoryPosition = .messageTop
    
    override func configure(attributes: MessageCollectionViewLayoutAttributes) {
        super.configure(attributes: attributes)
        let dataSource = self.layout.messageDataSource
        let indexPath = attributes.indexPath
        let message = dataSource.messageCollectionView(layout.messageCollecitonView, messageForItemAt: indexPath)
        
        attributes.avatarSize = self.avatarSize(for: message)
        attributes.avatarPosition = self.avatarPosition(for: message)
        attributes.avatarLeadingTrailingPadding = self.avatarLeadingTrailingPadding
        
        attributes.nameViewSize = self.nameViewSize(for: message)
        attributes.namePosition = self.nameViewPosition(for: message)
        attributes.nameViewLeadingTrailingPadding = self.nameViewLeadingTrailingPadding
        
        let messageContainerSize = self.messageContainerSize(for: message, at: indexPath)
        attributes.messageContainerPadding = self.messageContainerPadding(for: message)
        attributes.messageContainerSize = messageContainerSize
        
        attributes.cellTopLabelSize = self.cellTopLabelSize(for: message, at: indexPath)
        attributes.cellTopLabelAlignment = self.cellTopLabelAlignment(for: message)
        attributes.cellBottomLabelSize = self.cellBottomLabelSize(for: message, at: indexPath)
        attributes.cellBottomLabelAlignment = self.cellBottomLabelAlignment(for: message)
        attributes.messageTopLabelSize = self.messageTopLabelSize(for: message, at: indexPath)
        attributes.messageTopLabelAlignment = self.messageTopLabelAlignment(for: message)
        
        attributes.messageBottomLabelAlignment = self.messageBottomLabelAlignment(for: message)
        attributes.messageBottomLabelSize = self.messageBottomLabelSize(for: message, at: indexPath)
        
        let messageContainerHeight = messageContainerSize.height
        
        let leadingViewWidth = self.leadingViewWidth(for: message, at: indexPath)
        attributes.leadingViewSize = CGSize.init(width: leadingViewWidth, height: messageContainerHeight)
        attributes.leadingViewPadding = self.leadingViewPadding(for: message)
        attributes.leadingViewPosition = self.leadingViewPosition(for: message)
        
        attributes.statusViewSize = self.statusSize
        attributes.statusViewPadding = self.statusPadding
        
        attributes.redDotViewSize = self.redDotSize
        attributes.redDotViewPadding = self.redDotPadding
        
        attributes.accessoryViewSize = self.accessoryViewSize(for: message)
        attributes.accessoryViewPadding = self.accessoryViewPadding(for: message)
        attributes.accessoryViewPosition = self.accessoryViewPosition(for: message)
    }
    
    override func sizeForItem(at indexPath: IndexPath) -> CGSize {
        let dataSource = self.layout.messageDataSource
        let message = dataSource.messageCollectionView(layout.messageCollecitonView, messageForItemAt: indexPath)
        let itemHeight = self.cellContentHeight(for: message, at: indexPath)
        return CGSize(width: layout.itemWidth, height: itemHeight)
    }
    
    func cellContentHeight(for message: Message, at indexPath: IndexPath) -> CGFloat {
        let messageContainerHeight = self.messageContainerSize(for: message, at: indexPath).height
        let cellBottomLabelHeight = self.cellBottomLabelSize(for: message, at: indexPath).height
        let messageBottomLabelHeight = self.messageBottomLabelSize(for: message, at: indexPath).height
        let cellTopLabelHeight = self.cellTopLabelSize(for: message, at: indexPath).height
        let messageTopLabelHeight = self.messageTopLabelSize(for: message, at: indexPath).height
        let messageVerticalPadding = self.messageContainerPadding(for: message).vertical
        let avatarHeight = self.avatarSize(for: message).height
        let avatarVerticalPosition = self.avatarPosition(for: message).vertical
        
        switch avatarVerticalPosition {
        case .messageLabelTop:
            var cellHeight: CGFloat = 0
            cellHeight += cellTopLabelHeight
            cellHeight += messageTopLabelHeight
            let labelsHeight = messageContainerHeight + messageVerticalPadding + messageBottomLabelHeight + cellBottomLabelHeight
            cellHeight += max(labelsHeight, avatarHeight)
            return cellHeight
        }
    }
    
    // MARK: - Leading View
    
    func leadingViewWidth(for message: MessageType, at indexPath: IndexPath) -> CGFloat {
        let layoutDataSource = self.layout.messageLayoutDataSource
        let collectionView = self.layout.messageCollecitonView
        let width = layoutDataSource.leadingViewWidth(for: message, at: indexPath, in: collectionView)
        return width
    }
    
    func leadingViewPadding(for message: MessageType) -> HorizontalEdgeInsets {
        return message.isOutgoing ? self.outgoingLeadingViewPadding : self.incomingLeadingViewPadding
    }
    
    func leadingViewPosition(for message: MessageType) -> LeadingPosition {
        return message.isOutgoing ? self.outgoingLeadingViewPosition : self.incomingLeadingViewPosition
    }
    
    
    // MARK: - Avatar
    
    func avatarPosition(for message: MessageType) -> AvatarPosition {
        return message.isOutgoing ? self.outgoingAvatarPosition : self.incomingAvatarPosition
    }
    
    func avatarSize(for message: MessageType) -> CGSize {
        switch message.kind {
        case .notification, .system:
            return .zero
        default:
            return message.isOutgoing ? self.outgoingAvatarSize : self.incomingAvatarSize
        }
    }
    
    // MARK: - NameView
    func nameViewPosition(for message: Message) -> NameViewPosition {
        return message.isOutgoing ? self.outgoingNameViewPosition : self.incomingNameViewPosition
    }
    
    func nameViewSize(for message: Message) -> CGSize {
        switch message.kind {
        case .notification,.system:
            return .zero
        default:
            return message.isOutgoing ? self.outgoingNameViewSize : self.incomingNameViewSize
        }
    }
    
    // MARK: - Top cell Label
    
    func cellTopLabelSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        let layoutDataSource = layout.messageLayoutDataSource
        let collecitonView = layout.messageCollecitonView
        let height = layoutDataSource.cellTopLabelHeight(for: message, at: indexPath, in: collecitonView)
        return CGSize.init(width: layout.itemWidth, height: height)
    }
    
    func cellTopLabelAlignment(for message: MessageType) -> LabelAlignment {
        return message.isOutgoing ? self.outgoingCellTopLabelAlignment : self.incomingCellTopLabelAlignment
    }
    
    // MARK: - Top message Label
    func messageTopLabelSize(for message: MessageType, at indexPath: IndexPath) -> CGSize {
        let layoutDataSource = layout.messageLayoutDataSource
        let collecitonView = layout.messageCollecitonView
        let height = layoutDataSource.messageTopLabelHeight(for: message, at: indexPath, in: collecitonView)
        return CGSize.init(width: layout.itemWidth, height: height)
    }
    
    func messageTopLabelAlignment(for message: MessageType) -> LabelAlignment {
        return message.isOutgoing ? self.outgoingMessageTopLabelAlignment : self.incomingMessageTopLabelAlignment
    }
    
    // MARK: - Bottom cell Label
    
    func cellBottomLabelSize(for message: MessageType, at indexPath: IndexPath) -> CGSize {
        let layoutDataSource = layout.messageLayoutDataSource
        let collecitonView = layout.messageCollecitonView
        let height = layoutDataSource.cellBottomLabelHeight(for: message, at: indexPath, in: collecitonView)
        return CGSize.init(width: layout.itemWidth, height: height)
    }
    
    func cellBottomLabelAlignment(for message: MessageType) -> LabelAlignment {
        return message.isOutgoing ? self.outgoingCellBottomLabelAlignment : self.incomingCellBottomLabelAlignment
    }
    
    // MARK: - Bottom message Label
    func messageBottomLabelSize(for message: MessageType, at indexPath: IndexPath) -> CGSize {
        let layoutDataSource = layout.messageLayoutDataSource
        let collecitonView = layout.messageCollecitonView
        let height = layoutDataSource.messageBottomLabelHeight(for: message, at: indexPath, in: collecitonView)
        return CGSize.init(width: layout.itemWidth, height: height)
    }
    
    func messageBottomLabelAlignment(for message: MessageType) -> LabelAlignment {
        return message.isOutgoing ? self.outgoingMessageBottomLabelAlignment : self.incomingMessageBottomLabelAlignment
    }
    
    // MARK: - Accessory View
    
    func accessoryViewSize(for message: MessageType) -> CGSize {
        return message.isOutgoing ? self.outgoingAccessoryViewSize : self.incomingAccessoryViewSize
    }
    
    func accessoryViewPadding(for message: MessageType) -> HorizontalEdgeInsets {
        return message.isOutgoing ? self.outgoingAccessoryViewPadding : self.incomingAccessoryViewPadding
    }
    
    func accessoryViewPosition(for message: MessageType) -> AccessoryPosition {
        return message.isOutgoing ? self.outgoingAccessoryViewPosition : self.incomingAccessoryViewPosition
    }
    
    // MARK: - MessageContainer
    
    open func messageContainerPadding(for message: Message) -> UIEdgeInsets {
        if message.channelType == .group {// 群聊需显示群成员昵称
            return message.isOutgoing ? self.outgoingGroupMessagePadding : self.incomingGroupMessagePadding
        } else {
            return message.isOutgoing ? self.outgoingMessagePadding : self.incomingMessagePadding
        }
    }
    
    open func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        return .zero
    }
    
    open func messageContainerMaxWidth(for message: Message, at indexPath: IndexPath) -> CGFloat {
        let leadingViewWidth = self.leadingViewWidth(for: message, at: indexPath)
        let leadingViewPadding = self.leadingViewPadding(for: message)
        let avatarWidth = self.avatarSize(for: message).width
        let messagePadding = self.messageContainerPadding(for: message)
        let accessorySize = self.accessoryViewSize(for: message)
        let accessoryPadding = self.accessoryViewPadding(for: message)
        return layout.itemWidth - leadingViewWidth - leadingViewPadding.horizontal - avatarWidth - messagePadding.horizontal - accessorySize.width - accessoryPadding.horizontal - avatarLeadingTrailingPadding - statusSize.width
    }
    
    func labelSize(for attributedText: NSAttributedString, considering maxWidth: CGFloat) -> CGSize {
        let constraintBox = CGSize.init(width: maxWidth, height: .greatestFiniteMagnitude)
        let rect = attributedText.boundingRect(with: constraintBox, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).integral
        return rect.size
    }
}

