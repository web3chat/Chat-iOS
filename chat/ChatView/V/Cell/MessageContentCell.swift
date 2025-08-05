//
//  MessageContentCell.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import UIKit

class MessageContentCell: MessageCollectionViewCell {
    
    var msg: Message?
    var vm: FZMMessageBaseVM?
    
    let leadingView = UIView.init()
    
    // 头像（自己/他人）
    let avatarView : AvatarView = {
        let v = AvatarView.init()
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        
        return v
    }()
    
    // 群成员昵称和类型视图
    let nameView: NameView = {
        let v = NameView.init()
        return v
    }()
    
    // 消息内容视图
    let messageContainerView: MessageContainerView = {
        let v = MessageContainerView.init()
        v.clipsToBounds = true
        v.layer.masksToBounds = true
        return v
    }()
    
    // 消息发送状态视图(仅自己发送消息左侧显示)
    let statusView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "chat_sent"))
        imV.contentMode = .center
        return imV
    }()
    
    // 语音未读小图标
    let redDotView : UIView = {
        let view = UIView()
        view.backgroundColor = Color_DD5F5F
        view.layer.cornerRadius = 3.5
        view.clipsToBounds = true
        return view
    }()
    
    // 消息时间戳
    let cellTopLabel: InsetLabel = {
        let lab = InsetLabel.init()
        lab.numberOfLines = 0
        lab.textAlignment = .center
//        lab.font = .systemFont(ofSize: 12, weight: .regular)
        lab.font = UIFont.preferredFont(forTextStyle: .footnote)
        return lab
    }()
    
    let cellBottomLabel: InsetLabel = {
        let lab = InsetLabel.init()
        lab.numberOfLines = 0
        lab.textAlignment = .center
        lab.font = UIFont.preferredFont(forTextStyle: .footnote)
        return lab
    }()
    
    let messageTopLabel: InsetLabel = {
        let lab = InsetLabel.init()
        lab.numberOfLines = 0
        lab.font = UIFont.preferredFont(forTextStyle: .footnote)
        return lab
    }()
    
    let messageBottomLabel: InsetLabel = {
        let lab = InsetLabel.init()
        lab.numberOfLines = 0
        lab.font = UIFont.preferredFont(forTextStyle: .footnote)
        return lab
    }()
    
    // 每条消息内容左/右侧跟随视图
    let accessoryView: UIView = {
        let v = UIView.init()
//        v.isHidden = true
        return v
    }()
    
    weak var delegate: MessageCellDelegate? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupViews() {
        self.contentView.addSubview(self.leadingView)
        self.contentView.addSubview(self.accessoryView)
        self.contentView.addSubview(self.cellTopLabel)
        self.contentView.addSubview(self.messageTopLabel)
        self.contentView.addSubview(self.messageBottomLabel)
        self.contentView.addSubview(self.cellBottomLabel)
        self.contentView.addSubview(self.messageContainerView)
        self.contentView.addSubview(self.avatarView)
        self.contentView.addSubview(self.nameView)
        self.contentView.addSubview(self.statusView)
        self.contentView.addSubview(self.redDotView)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.avatarView.image = nil
        self.nameView.nameLable.text = nil
        self.nameView.typeLable.text = nil
        self.nameView.typeLable.backgroundColor = .clear
        self.cellTopLabel.text = nil
        self.cellBottomLabel.text = nil
        self.messageTopLabel.text = nil
        self.messageBottomLabel.text = nil
        
        self.cellTopLabel.attributedText = nil
        self.cellBottomLabel.attributedText = nil
        self.messageTopLabel.attributedText = nil
        self.messageBottomLabel.attributedText = nil
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        guard let attributes = layoutAttributes as? MessageCollectionViewLayoutAttributes else { return }
        
        self.layoutMessageContainerView(with: attributes)
        self.layoutMessageBottomLabel(with: attributes)
        self.layoutCellBottomLabel(with: attributes)
        self.layoutCellTopLabel(with: attributes)
        self.layoutMessageTopLabel(with: attributes)
        self.layoutAvatarView(with: attributes)
        self.layoutNameView(with: attributes)
        self.layoutAccessoryView(with: attributes)
        self.layoutLeadingView(with: attributes)
        self.layoutStatusView(with: attributes)
        self.layoutRedDotView(with: attributes)
    }
    
    func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        
        guard let dataSource = messageCollectionView.messageDataSource else {
            fatalError("nilMessagesDataSource")
        }
        
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessagesDisplayDelegate")
        }
        self.delegate = messageCollectionView.messageCellDelegate
        
        self.msg = message
        self.vm = FZMMessageBaseVM.init(with: message)
        
        displayDelegate.configureAvatarView(self.avatarView, for: message, at: indexPath, in: messageCollectionView)
        displayDelegate.configureAccessoryView(self.accessoryView, for: message, at: indexPath, in: messageCollectionView)
        displayDelegate.configureStatusView(self.statusView, for: message, at: indexPath, in: messageCollectionView)
        displayDelegate.configureRedDotView(self.redDotView, for: message, at: indexPath, in: messageCollectionView)
        displayDelegate.configureNameView(self.nameView, for: message, at: indexPath, in: messageCollectionView)
        
        let messageContainerStyle = displayDelegate.messageContainerStyle(for: message, at: indexPath, in: messageCollectionView)
        self.messageContainerView.style = messageContainerStyle
        
        let topCellLabelText = dataSource.cellTopLabelAttributedText(for: message, at: indexPath)
        let bottomCellLabelText = dataSource.cellBottomLabelAttributedText(for: message, at: indexPath)
        let topMessageLabelText = dataSource.messageTopLabelAttributedText(for: message, at: indexPath)
        let bottomMessageLabelText = dataSource.messageBottomLabelAttributedText(for: message, at: indexPath)
        
        
        cellTopLabel.configure {
            cellTopLabel.attributedText = topCellLabelText
            cellTopLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
        cellBottomLabel.configure {
            cellBottomLabel.attributedText = bottomCellLabelText
            cellBottomLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
        messageTopLabel.configure {
            messageTopLabel.attributedText = topMessageLabelText
            messageTopLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
        messageBottomLabel.configure {
            messageBottomLabel.attributedText = bottomMessageLabelText
            messageBottomLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
        
    }
    
    // MARK: - Gesture
    override func handleTapGesture(_ gesture: UIGestureRecognizer) {
        guard let message = self.msg else { return }
        let touchLocation = gesture.location(in: self)
        
        switch true {
        case self.messageContainerView.frame.contains(touchLocation):
            self.delegate?.didTapMessage(in: self, message: message)
        case self.avatarView.frame.contains(touchLocation):
            if touchLocation.x > k_ScreenWidth/2 {
                self.delegate?.didTapSelfAvatar(in: self, message: message)
            } else {
                self.delegate?.didTapAvatar(in: self, message: message)
            }
        case self.cellTopLabel.frame.contains(touchLocation):
            self.delegate?.didTapCellTopLabel(in: self, message: message)
        case self.cellBottomLabel.frame.contains(touchLocation):
            self.delegate?.didTapCellBottomLabel(in: self, message: message)
        case self.messageTopLabel.frame.contains(touchLocation):
            self.delegate?.didTapMessageTopLabel(in: self, message: message)
        case self.messageBottomLabel.frame.contains(touchLocation):
            self.delegate?.didTapMessageBottomLabel(in: self, message: message)
        case self.statusView.frame.contains(touchLocation):
            self.delegate?.didTapStatusView(in: self, message: message)
        case self.accessoryView.frame.contains(touchLocation):
            self.delegate?.didTapAccessoryView(in: self, message: message)
        case self.leadingView.frame.contains(touchLocation):
            self.delegate?.didTapLeadingView(in: self, message: message)
        default:
            self.delegate?.didTapBackground(in: self, message: message)
        }
    }
    
    override func handleLongPressGesture(_ longPressGesture: UILongPressGestureRecognizer) {
        guard let message = self.msg else { return }
        let touchLocation = longPressGesture.location(in: self)
        
        switch true {
        case self.messageContainerView.frame.contains(touchLocation):
            self.delegate?.didLongPressMessage(in: self, message: message)
        case self.avatarView.frame.contains(touchLocation):
            if touchLocation.x > k_ScreenWidth/2 {
                self.delegate?.didLongPressSelfAvatar(in: self, message: message)
            } else {
                self.delegate?.didLongPressAvatar(in: self, message: message)
            }
        case self.cellTopLabel.frame.contains(touchLocation):
            self.delegate?.didLongPressCellTopLabel(in: self, message: message)
        case self.cellBottomLabel.frame.contains(touchLocation):
            self.delegate?.didLongPressCellBottomLabel(in: self, message: message)
        case self.messageTopLabel.frame.contains(touchLocation):
            self.delegate?.didLongPressMessageTopLabel(in: self, message: message)
        case self.messageBottomLabel.frame.contains(touchLocation):
            self.delegate?.didLongPressMessageBottomLabel(in: self, message: message)
        case self.accessoryView.frame.contains(touchLocation):
            self.delegate?.didLongPressAccessoryView(in: self, message: message)
        case self.leadingView.frame.contains(touchLocation):
            self.delegate?.didLongPressLeadingView(in: self, message: message)
        default:
            self.delegate?.didLongPressBackground(in: self, message: message)
        }
    }
    
}
// MARK: - Layout
extension MessageContentCell {
    
    func layoutLeadingView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        switch attributes.leadingViewPosition {
        case .messageLabelTop(let offset):
            origin.y = messageTopLabel.frame.minY + offset
        }
        origin.x = attributes.leadingViewPadding.left
        self.leadingView.frame = CGRect.init(origin: origin, size: attributes.leadingViewSize)
    }
    
    func layoutAvatarView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        let padding = attributes.avatarLeadingTrailingPadding
        
        switch attributes.avatarPosition.horizontal {
        case .cellLeading:
            origin.x = attributes.leadingViewSize.width + attributes.leadingViewPadding.horizontal + padding
        case .cellTrailing:
            origin.x = attributes.frame.width - attributes.avatarSize.width - padding
        }
        
        switch attributes.avatarPosition.vertical {
        case .messageLabelTop(let offset):
            origin.y = messageTopLabel.frame.minY + offset
        }
        
        self.avatarView.frame = CGRect.init(origin: origin, size: attributes.avatarSize)
    }
    
    func layoutNameView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        let avatarPadding = attributes.avatarLeadingTrailingPadding

        switch attributes.namePosition.horizontal {
        case .avatarLeading:
            origin.x = attributes.leadingViewSize.width + attributes.leadingViewPadding.horizontal + attributes.avatarSize.width + attributes.nameViewLeadingTrailingPadding + avatarPadding
        case .avatarTrailing:
            origin.x = attributes.leadingViewSize.width + attributes.leadingViewPadding.horizontal + attributes.avatarSize.width + attributes.nameViewLeadingTrailingPadding + avatarPadding
        }

        switch attributes.namePosition.vertical {
        case .messageLabelTop(let offset):
            origin.y = messageTopLabel.frame.minY + offset
        }
        
        self.nameView.frame = CGRect.init(origin: origin, size: attributes.nameViewSize)
    }
    
    func layoutMessageContainerView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        switch attributes.avatarPosition.vertical {
        case .messageLabelTop:
            if attributes.accessoryViewSize.height > attributes.messageContainerSize.height {
                let messageHeight = attributes.messageContainerSize.height + attributes.messageContainerPadding.vertical
                origin.y = (attributes.size.height / 2) - (messageHeight / 2)
            } else {
                origin.y = attributes.cellTopLabelSize.height + attributes.messageTopLabelSize.height + attributes.messageContainerPadding.top
            }
        }
        
        let avatarPadding = attributes.avatarLeadingTrailingPadding
        switch attributes.avatarPosition.horizontal {
        case .cellLeading:
            origin.x = attributes.leadingViewSize.width + attributes.leadingViewPadding.horizontal + attributes.avatarSize.width + attributes.messageContainerPadding.left + avatarPadding
        case .cellTrailing:
            origin.x = attributes.frame.width - attributes.avatarSize.width - attributes.messageContainerSize.width - attributes.messageContainerPadding.right - avatarPadding
        }
        self.messageContainerView.frame = CGRect.init(origin: origin, size: attributes.messageContainerSize)
    }
    
    open func layoutCellTopLabel(with attributes: MessageCollectionViewLayoutAttributes) {
        self.cellTopLabel.textAlignment = attributes.cellTopLabelAlignment.textAlignment
//        self.cellTopLabel.textInsets = attributes.cellTopLabelAlignment.textInsets
        self.cellTopLabel.textInsets = UIEdgeInsets.init(top: 10, left: 0, bottom: 12, right: 0)// 设置上下间距
        
        self.cellTopLabel.frame = CGRect(origin: .zero, size: attributes.cellTopLabelSize)
    }
    
    func layoutMessageTopLabel(with attributes: MessageCollectionViewLayoutAttributes) {
        self.messageTopLabel.textAlignment = attributes.messageTopLabelAlignment.textAlignment
        self.messageTopLabel.textInsets = attributes.messageTopLabelAlignment.textInsets
        
        let y = self.messageContainerView.frame.minY - attributes.messageContainerPadding.top - attributes.messageTopLabelSize.height
        let origin = CGPoint(x: 0, y: y)
        
        self.messageTopLabel.frame = CGRect(origin: origin, size: attributes.messageTopLabelSize)
    }
    
    func layoutMessageBottomLabel(with attributes: MessageCollectionViewLayoutAttributes) {
        self.messageBottomLabel.textAlignment = attributes.messageBottomLabelAlignment.textAlignment
        self.messageBottomLabel.textInsets = attributes.messageBottomLabelAlignment.textInsets
        
        let y = self.messageContainerView.frame.maxY + attributes.messageContainerPadding.bottom
        let origin = CGPoint.init(x: 0, y: y)
        self.messageBottomLabel.frame = CGRect.init(origin: origin, size: attributes.messageBottomLabelSize)
    }
    
    func layoutCellBottomLabel(with attributes: MessageCollectionViewLayoutAttributes) {
        self.cellBottomLabel.textAlignment = attributes.cellBottomLabelAlignment.textAlignment
//        self.cellBottomLabel.textInsets = attributes.cellBottomLabelAlignment.textInsets
        self.cellBottomLabel.textInsets = UIEdgeInsets.init(top: 0, left: 0, bottom: 12, right: 0)// 设置上下间距
        
        let y = self.messageBottomLabel.frame.maxY
        let origin = CGPoint(x: 0, y: y)
        
        self.cellBottomLabel.frame = CGRect(origin: origin, size: attributes.cellBottomLabelSize)
    }
    
    // 消息发送状态视图
    func layoutStatusView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        
        origin.y = self.messageContainerView.frame.maxY - attributes.statusViewSize.height - attributes.statusViewPadding.height
        
        origin.x = self.messageContainerView.frame.minX - attributes.statusViewPadding.width - attributes.statusViewSize.width
        self.statusView.frame = CGRect.init(origin: origin, size: attributes.statusViewSize)
    }
    
    // 未读红点视图
    func layoutRedDotView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        
        origin.y = self.messageContainerView.frame.minY
        
        origin.x = self.messageContainerView.frame.maxX + attributes.redDotViewPadding
        self.redDotView.frame = CGRect.init(origin: origin, size: attributes.redDotViewSize)
    }
    
    // 每条消息内容左/右侧跟随视图
    func layoutAccessoryView(with attributes: MessageCollectionViewLayoutAttributes) {
        var origin = CGPoint.zero
        
        switch attributes.accessoryViewPosition {
        case .messageTop:
            origin.y = self.messageContainerView.frame.minY
        }
        
        switch attributes.avatarPosition.horizontal {
        case .cellLeading:
            origin.x = self.messageContainerView.frame.maxX + attributes.accessoryViewPadding.left
        case .cellTrailing:
            origin.x = self.messageContainerView.frame.minX - attributes.accessoryViewPadding.right - attributes.accessoryViewSize.width
        }
        self.accessoryView.frame = CGRect.init(origin: origin, size: attributes.accessoryViewSize)
    }
}



















