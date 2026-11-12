//
//  MessageContentCell.swift
//  chat
//
//  Created by fzm on 2020/12/22.
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

    /// 引用条（气泡**下方**那一小条「昵称 + 内容摘要」）。
    /// 高度由 `attributes.quoteHeight` 给出，气泡本身不受影响 —— 见 `layoutQuoteBlockView`。
    let quoteBlockView: QuoteBlockView = QuoteBlockView.init()

    /// 气泡下方的「译文 / 转写」卡片（在引用条下面；没有引用条就紧贴气泡下沿）。
    /// 高度由 `attributes.extraBlockHeight` 给出，气泡本身同样不受影响 —— 见 `layoutExtraBlockView`。
    let extraBlockView: MessageExtraBlockView = MessageExtraBlockView.init()

    /// 当前 cell 的引用条内容（`configure` 时从数据源取；`apply` 优先用它，而不是布局属性里的那份）
    private var cellQuotePreview: QuotePreview?
    /// 最近一次应用的布局属性：`configure` 之后用它重摆一次引用条，避免依赖 apply / configure 的先后顺序
    private var lastQuoteAttributes: MessageCollectionViewLayoutAttributes?
    
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
    
    // MARK: - 多选（转发）标记
    
    /// 多选模式下显示的圆形勾选标记：画在**头像位置**上（多选时头像与昵称隐藏）。
    /// ⚠️ 它只是叠在已有布局上，**不参与尺寸计算**，因此不会影响气泡布局与缓存 key。
    let selectIndicatorView: UIImageView = {
        let imV = UIImageView.init()
        imV.contentMode = .center
        imV.isHidden = true
        return imV
    }()
    
    /// 阅后即焚角标（纯叠加，**不参与尺寸计算**；只给有真实气泡的消息，通知/系统消息不显示）
    /// 直接用与输入框上方「🔥 阅后即焚」提示条**一模一样的 emoji 火焰**（纯图标、无底色框）
    let burnBadgeView: UILabel = {
        let lab = UILabel()
        lab.text = "🔥"
        lab.font = UIFont.systemFont(ofSize: 11)
        lab.textAlignment = .center
        lab.isHidden = true
        return lab
    }()
    
    /// 本次显示是否处于多选模式
    private var isSelectMode = false
    /// 本条消息是否被选中
    private var isMsgSelected = false
    
    private static let selectOnImage: UIImage? = MessageContentCell.makeSelectImage(selected: true)
    private static let selectOffImage: UIImage? = MessageContentCell.makeSelectImage(selected: false)
    /// 勾选圈直径（画在头像正中间）
    private static let selectIndicatorSide: CGFloat = 22
    
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
        // 引用条（气泡下方；隐藏时不占位，尺寸由布局属性决定）
        self.quoteBlockView.isHidden = true
        self.contentView.addSubview(self.quoteBlockView)
        // 译文 / 转写卡片（引用条下面；隐藏时不占位）
        self.extraBlockView.isHidden = true
        self.contentView.addSubview(self.extraBlockView)
        // 阅后即焚角标（叠加，不影响布局）
        self.contentView.addSubview(self.burnBadgeView)
        // 多选标记放最后：保证盖在头像等视图之上
        self.contentView.addSubview(self.selectIndicatorView)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.selectIndicatorView.isHidden = true
        self.burnBadgeView.isHidden = true
        self.quoteBlockView.isHidden = true
        self.extraBlockView.isHidden = true
        self.cellQuotePreview = nil
        // 头像在多选时会被临时隐藏，这里恢复；
        // ⚠️ 昵称/身份标签（NameView）的显隐**由 configureNameView 决定**，不要在这里碰
        self.avatarView.isHidden = false
        
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

        self.lastQuoteAttributes = attributes
        self.layoutMessageContainerView(with: attributes)
        self.layoutQuoteBlockView(with: attributes)
        self.layoutExtraBlockView(with: attributes)
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
        // 阅后即焚角标（三处刷新：configure / apply / layoutSubviews，防 cell 复用与时机问题）
        self.refreshBurnBadge()
        // 多选标记跟着头像位置走（头像 frame 已在上面布局完成）
        if self.isSelectMode {
            self.selectIndicatorView.frame = self.selectIndicatorFrame()
        }
    }
    
    // MARK: - 多选
    
    /// 由聊天页在 cell 上屏时调用（传入当前是否多选 + 本条是否选中）
    func setSelectMode(_ isSelectMode: Bool, selected: Bool) {
        self.isMsgSelected = selected

        // 通知消息（群聊里的灰色通知）与系统消息不参与多选：不显示勾选圈，也不需要给圈让位
        var showIndicator = isSelectMode
        if let msg = self.msg {
            switch msg.msgType {
            case .notify, .system:
                showIndicator = false
            default:
                break
            }
        }
        self.isSelectMode = showIndicator

        self.selectIndicatorView.isHidden = !showIndicator
        // ⚠️ 只让头像给勾选圈让位。昵称/身份标签的显隐归 `configureNameView` 管：
        //    在这里强行置 false，会让私聊冒出昵称、群聊冒出「群主」标签（转发卡片上就叠了一个）
        self.avatarView.isHidden = showIndicator
        self.selectIndicatorView.image = selected ? MessageContentCell.selectOnImage : MessageContentCell.selectOffImage
        self.selectIndicatorView.frame = self.selectIndicatorFrame()
    }
    
    private func selectIndicatorFrame() -> CGRect {
        let avatarFrame = self.avatarView.frame
        let side = MessageContentCell.selectIndicatorSide
        return CGRect.init(x: avatarFrame.midX - side / 2, y: avatarFrame.midY - side / 2, width: side, height: side)
    }
    
    /// 阅后即焚角标位置：气泡内的右上角（小尺寸，尽量不遮正文）
    private func burnBadgeFrame() -> CGRect {
        let side: CGFloat = 13
        let f = self.messageContainerView.frame
        guard f.width > side + 4, f.height > side + 4 else { return .zero }
        return CGRect.init(x: f.maxX - side - 1, y: f.minY + 1, width: side, height: side)
    }

    /// 刷新阅后即焚角标（configure / apply / layoutSubviews 都调；只给有真实气泡的消息）
    func refreshBurnBadge() {
        var show = false
        if let msg = self.msg, msg.isBurn {
            switch msg.msgType {
            case .notify, .system:
                show = false
            default:
                show = true
            }
        }
        self.burnBadgeView.isHidden = !show
        guard show else { return }
        let frame = self.burnBadgeFrame()
        if frame == .zero {
            self.burnBadgeView.isHidden = true
        } else {
            self.burnBadgeView.frame = frame
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // cell 复用/首次布局的时机不确定，统一在布局完成后刷新一次角标
        self.refreshBurnBadge()
    }
    
    /// 用代码画勾选圈（不依赖图片资源）：未选中 = 空心圆，选中 = 主题色实心圆 + 白勾
    private static func makeSelectImage(selected: Bool) -> UIImage? {
        let side = selectIndicatorSide
        let size = CGSize.init(width: side, height: side)
        let renderer = UIGraphicsImageRenderer.init(size: size)
        return renderer.image { _ in
            let rect = CGRect.init(origin: .zero, size: size)
            if selected {
                Color_Theme.setFill()
                UIBezierPath.init(ovalIn: rect).fill()
                
                let check = UIBezierPath.init()
                check.move(to: CGPoint.init(x: side * 0.28, y: side * 0.52))
                check.addLine(to: CGPoint.init(x: side * 0.44, y: side * 0.68))
                check.addLine(to: CGPoint.init(x: side * 0.74, y: side * 0.32))
                check.lineWidth = 2
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                UIColor.white.setStroke()
                check.stroke()
            } else {
                Color_8A97A5.setStroke()
                let circle = UIBezierPath.init(ovalIn: rect.insetBy(dx: 1, dy: 1))
                circle.lineWidth = 1.5
                circle.stroke()
            }
        }
    }
    
    func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        
        guard let dataSource = messageCollectionView.messageDataSource else {
            FZMLog("MessageContentCell：messageDataSource 为空，跳过配置")
            return
        }
        
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            FZMLog("MessageContentCell：messagesDisplayDelegate 为空，跳过配置")
            return
        }
        self.delegate = messageCollectionView.messageCellDelegate
        
        self.msg = message
        self.vm = FZMMessageBaseVM.init(with: message)

        // 引用条内容以**数据源**为准（在 configure 里取），不依赖布局属性 ——
        // cell 复用时 `apply` 可能先于 `configure` 跑，属性里还是上一条消息的引用（nil），
        // 只按属性画会导致引用条被隐藏后再也回不来（用户 2026-11-04 反馈「滑动后引用条消失」）。
        self.cellQuotePreview = messageCollectionView.messageDataSource?.quotePreview(for: message, at: indexPath)
        self.refreshQuoteBlockIfNeeded()
        
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
        
        // 阅后即焚角标：configure 时 msg 刚设好，先刷一次（apply / layoutSubviews 还会再刷）
        self.refreshBurnBadge()
        
    }
    
    /// 触摸点是否落在引用条上（引用条挂在 `contentView` 上，坐标系与 cell 一致，这里做个兜底转换）
    private func containsQuoteBlock(_ point: CGPoint) -> Bool {
        guard let superview = self.quoteBlockView.superview else { return false }
        let frameInCell = superview.convert(self.quoteBlockView.frame, to: self)
        return frameInCell.contains(point)
    }

    /// 触摸点是否落在「译文 / 转写」卡片上（卡片自己带点按复制手势，cell 不要再处理）
    private func containsExtraBlock(_ point: CGPoint) -> Bool {
        guard !self.extraBlockView.isHidden, let superview = self.extraBlockView.superview else {
            return false
        }
        let frameInCell = superview.convert(self.extraBlockView.frame, to: self)
        return frameInCell.contains(point)
    }

    // MARK: - Gesture
    override func handleTapGesture(_ gesture: UIGestureRecognizer) {
        guard let message = self.msg else { return }
        let touchLocation = gesture.location(in: self)
        
        switch true {
        // 引用条：点击跳到被引用的原消息（必须排在气泡判定之前，它在气泡下方）
        case !self.quoteBlockView.isHidden
            && self.containsQuoteBlock(touchLocation):
            self.delegate?.didTapQuote(in: self, message: message)
        // 译文 / 转写卡片：点按复制由卡片自己的手势处理，这里不再分发
        case self.containsExtraBlock(touchLocation):
            break
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
        // 引用条上长按 = 对这条消息本身长按（和点气泡一个效果）
        case !self.quoteBlockView.isHidden
            && self.containsQuoteBlock(touchLocation):
            self.delegate?.didLongPressMessage(in: self, message: message)
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
        // 气泡尺寸就是 `messageContainerSize`（引用条的高度只加在行高里，不从气泡里扣：
        // 扣减会在"属性认为有引用、数据认为没有"的瞬间把气泡压矮，正文被裁掉 —— 用户 2026-11-04 反馈）
        let containerSize = attributes.messageContainerSize

        var origin = CGPoint.zero
        switch attributes.avatarPosition.vertical {
        case .messageLabelTop:
            if attributes.accessoryViewSize.height > containerSize.height {
                let messageHeight = containerSize.height + attributes.messageContainerPadding.vertical
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
            origin.x = attributes.frame.width - attributes.avatarSize.width - containerSize.width - attributes.messageContainerPadding.right - avatarPadding
        }
        self.messageContainerView.frame = CGRect.init(origin: origin, size: containerSize)
    }

    /// 摆引用条：紧贴气泡下沿、与气泡同宽（自己发的消息同样右对齐）
    func layoutQuoteBlockView(with attributes: MessageCollectionViewLayoutAttributes) {
        // 内容以 `configure` 时从数据源取到的那份为准；没有才回退布局属性里的
        let preview = self.cellQuotePreview ?? attributes.quotePreview

        // 【临时诊断】引用条布局：能看到"属性里有没有引用 / 高度算没算 / cell 多高 / 画没画"
        if attributes.quotePreview != nil || preview != nil || self.msg?.reference != nil {
            FZMLog(
                "【引用】cell section=\(attributes.indexPath.section) attrPreview=\(attributes.quotePreview != nil) cellPreview=\(self.cellQuotePreview != nil) quoteH=\(attributes.quoteHeight) cellH=\(attributes.size.height) containerH=\(attributes.messageContainerSize.height) msgRef=\(self.msg?.reference != nil)"
            )
        }
        guard attributes.quoteHeight > 0,
            let preview = self.cellQuotePreview ?? attributes.quotePreview
        else {
            self.quoteBlockView.isHidden = true
            return
        }
        self.quoteBlockView.isHidden = false
        self.quoteBlockView.configure(with: preview)

        let container = self.messageContainerView.frame
        // 宽度只跟引用文字走（不再拉齐气泡宽度）：自己发的贴右边，对方发的贴左边
        var width = attributes.quoteWidth > 0 ? attributes.quoteWidth : container.width
        width = min(width, max(self.bounds.width - 16, QuoteBlockMetrics.minWidth))
        var x = container.minX
        switch attributes.avatarPosition.horizontal {
        case .cellLeading:
            x = container.minX
        case .cellTrailing:
            x = container.maxX - width
        }
        let y = container.maxY + QuoteBlockMetrics.gap
        self.quoteBlockView.frame = CGRect.init(
            x: x, y: y, width: width, height: QuoteBlockMetrics.blockHeight)
    }

    /// 摆「译文 / 转写」卡片：在引用条下面（没有引用条就紧贴气泡下沿），与气泡同侧对齐
    func layoutExtraBlockView(with attributes: MessageCollectionViewLayoutAttributes) {
        guard attributes.extraBlockHeight > 0, let block = attributes.extraBlock else {
            self.extraBlockView.isHidden = true
            return
        }
        self.extraBlockView.isHidden = false
        self.extraBlockView.configure(with: block)

        let container = self.messageContainerView.frame
        let maxWidth = max(self.bounds.width - 16, 0)
        let preferredWidth = attributes.extraBlockWidth > 0 ? attributes.extraBlockWidth : container.width
        let width = max(min(preferredWidth, maxWidth), 0)
        var x = container.minX
        switch attributes.avatarPosition.horizontal {
        case .cellLeading:
            x = container.minX
        case .cellTrailing:
            x = container.maxX - width
        }
        let y = container.maxY + attributes.quoteHeight + MessageExtraBlockMetrics.gap
        self.extraBlockView.frame = CGRect(x: x, y: y, width: width, height: attributes.extraBlockHeight)
    }

    /// `configure` 之后重摆一次（cell 复用时 apply/configure 先后不确定，这里保证最终状态正确）
    private func refreshQuoteBlockIfNeeded() {
        guard let attributes = self.lastQuoteAttributes else { return }
        self.layoutMessageContainerView(with: attributes)
        self.layoutQuoteBlockView(with: attributes)
        self.layoutExtraBlockView(with: attributes)
    }

    /// 跳转到被引用消息时闪一下，让用户看清落在哪条上
    func flashHighlight() {
        let mask = UIView.init(frame: self.contentView.bounds)
        mask.backgroundColor = Color_Theme.withAlphaComponent(0.15)
        mask.layer.cornerRadius = 6
        mask.isUserInteractionEnabled = false
        self.contentView.addSubview(mask)
        UIView.animate(withDuration: 0.9, delay: 0.1, options: .curveEaseOut) {
            mask.alpha = 0
        } completion: { (_) in
            mask.removeFromSuperview()
        }
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



















