//
//  SquareCommentCell.swift
//  chat
//
//  广场评论 cell（详情页用）
//

import Foundation
import UIKit
import SnapKit
import Kingfisher

final class SquareCommentCell: UITableViewCell {

    static let identifier = "SquareCommentCell"

    /// 楼层内最多直接展示的回复条数，超过则先折叠
    static let maxVisibleReplies = 2

    /// 头像按展示尺寸取 OSS 小图用（头像 32pt）
    static let avatarPixelSide: CGFloat = 32 * UIScreen.main.scale

    /// 点击「展开全部 N 条回复 / 收起」
    var onToggleReplies: (() -> Void)?
    /// 点击右上角删除（仅自己的评论）
    var onDeleteTapped: (() -> Void)?
    /// 点击头像（跳作者信息页）
    var onAvatarTapped: ((SquareComment) -> Void)?
    /// 点击评论内容里的链接（http(s)）：由详情页决定去哪（现在进 App 内 dapp 浏览器）
    var onLinkTapped: ((URL) -> Void)?

    /// 回复相对主评论的缩进
    private static let replyIndent: CGFloat = 36

    /// 评论正文富文本样式：**保持原有的 14pt / 0x24374E**，只把 http(s) 链接标蓝 + 下划线
    private static let contentStyle = SquareRichText.Style(
        font: .regularFont(14), textColor: Color_24374E,
        accentColor: Color_Theme, lineSpacing: 0, linkUnderline: true)

    private var isReply = false
    private var replyCount = 0
    private var isExpanded = false
    /// 当前展示的评论（头像点击回调用）
    private var currentComment: SquareComment?
    /// 当前展示的评论作者地址（异步头像回来时校验，避免复用串头像）
    private var currentAddress = ""
    /// 当前展示的自带头像串（复用校验用，避免异步回来时串头像）
    private var currentAvatarURL = ""
    /// 当前头像的「身份」（服务端头像串 / 作者地址）：刷新时同一个人不重置头像，避免头像闪一下
    private var avatarIdentity: String?
    /// 已经贴上去的头像地址：同一地址不重复 setImage，否则会被置回占位图再换回来（闪）
    private var appliedAvatarURL: String?
    /// 仅用于离屏测量行高（跳过头像解析与下载）
    private var isForMeasurement = false

    private var avatarLeftConstraint: SnapKit.Constraint?
    private var contentBottomConstraint: SnapKit.Constraint?
    private var toggleBottomConstraint: SnapKit.Constraint?
    /// 时间靠右的两种位置：有删除按钮时依次左移，避免叠在一起
    private var timeRightConstraint: SnapKit.Constraint?
    private var timeBeforeDeleteConstraint: SnapKit.Constraint?
    /// 身份标签宽度（我 / 公众号；没有身份时置 0 不占位）
    private var tagWidthConstraint: SnapKit.Constraint?

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.image = SquareCommentCell.defaultAvatar
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTap)))
        return view
    }()

    /// 默认占位头像
    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")

    private lazy var nameLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(13), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()

    /// 待审标记（本地发出去但还在审核的评论）
    private lazy var pendingLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_Theme, textAlignment: .center, text: L("审核中"))
        lab.backgroundColor = Color_Theme_Light
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        return lab
    }()

    /// 昵称后的身份小标签（我 / 作者），没有身份时不占宽度
    private lazy var tagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_FFFFFF, textAlignment: .center, text: nil)
        lab.backgroundColor = Color_Identity_Tag
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        lab.isHidden = true
        return lab
    }()

    private lazy var timeLab: UILabel = {
        return UILabel.getLab(font: .regularFont(11), textColor: Color_8A97A5, textAlignment: .right, text: nil)
    }()

    private lazy var contentLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()

    /// 评论内容点击：**只在真的点到链接时才开始识别**（见 `gestureRecognizerShouldBegin`）。
    /// 命中链接时手势按默认 `cancelsTouchesInView = true` 吞掉这次点击，列表行不会再走「点评论 = @ 回复」。
    private lazy var contentTapGesture: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(contentTap(_:)))
    }()

    /// 右上角删除按钮：只在自己的评论上出现
    private lazy var deleteBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        // 注意：UIButton 不会自动缩放 image，只改按钮尺寸图标还是原始大小，必须用 SymbolConfiguration 指定 pointSize
        let config = UIImage.SymbolConfiguration.init(pointSize: 11, weight: .regular)
        btn.setImage(UIImage.init(systemName: "xmark", withConfiguration: config)?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_8A97A5
        btn.isHidden = true
        btn.enlargeClickEdge(14, 14, 14, 14)
        btn.addTarget(self, action: #selector(deleteTap), for: .touchUpInside)
        return btn
    }()

    /// 展开/收起该楼层的回复
    private lazy var toggleBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .regularFont(12)
        btn.contentHorizontalAlignment = .left
        btn.isHidden = true
        btn.addTarget(self, action: #selector(toggleTap), for: .touchUpInside)
        return btn
    }()

    /// 评论之间的分隔细线（左端与文字对齐，最后一条不显示）
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = Color_FFFFFF
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLab)
        contentView.addSubview(tagLab)
        contentView.addSubview(pendingLab)
        contentView.addSubview(timeLab)
        contentView.addSubview(contentLab)
        // 评论内容里的 http 链接可点（自己算命中，不依赖系统链接交互）
        contentLab.isUserInteractionEnabled = true
        contentLab.addGestureRecognizer(contentTapGesture)
        contentView.addSubview(deleteBtn)
        contentView.addSubview(toggleBtn)
        contentView.addSubview(separatorLine)

        avatarView.snp.makeConstraints { (m) in
            avatarLeftConstraint = m.left.equalToSuperview().offset(15).constraint
            m.top.equalToSuperview().offset(12)
            m.size.equalTo(CGSize(width: 32, height: 32))
        }

        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(avatarView.snp.right).offset(10)
            m.centerY.equalTo(avatarView)
            m.height.equalTo(18)
        }
        nameLab.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // 身份标签：紧跟在昵称后面（「我」优先于「公众号」）
        tagLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.right).offset(6)
            m.centerY.equalTo(nameLab)
            m.height.equalTo(16)
            tagWidthConstraint = m.width.equalTo(0).constraint
        }

        pendingLab.snp.makeConstraints { (m) in
            m.left.equalTo(tagLab.snp.right).offset(6)
            m.centerY.equalTo(nameLab)
            m.height.equalTo(16)
            m.width.equalTo(38)
        }

        timeLab.snp.makeConstraints { (m) in
            timeRightConstraint = m.right.equalToSuperview().offset(-15).constraint
            m.centerY.equalTo(nameLab)
            m.left.greaterThanOrEqualTo(pendingLab.snp.right).offset(8)
        }

        deleteBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(nameLab)
            // 按钮本身留出热区，视觉尺寸靠 pointSize 控制（11pt）
            m.size.equalTo(CGSize(width: 22, height: 22))
        }
        // 自己评论时时间要给删除按钮让位（两个约束互斥，默认用上面那个）
        timeBeforeDeleteConstraint = timeLab.snp.prepareConstraints { (m) in
            m.right.equalTo(deleteBtn.snp.left).offset(-6)
        }.first

        contentLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(avatarView.snp.bottom).offset(6)
            contentBottomConstraint = m.bottom.equalToSuperview().offset(-12).constraint
        }

        toggleBtn.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.lessThanOrEqualToSuperview().offset(-15)
            m.top.equalTo(contentLab.snp.bottom).offset(4)
            m.height.equalTo(26)
            toggleBottomConstraint = m.bottom.equalToSuperview().offset(-12).constraint
        }
        // 默认不展示展开按钮（没有回复楼层）
        toggleBottomConstraint?.deactivate()

        // 分隔线：左端对齐文字（回复行会跟着缩进一起右移），右端到屏幕边
        separatorLine.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.equalToSuperview()
            m.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
    }

    /// - Parameters:
    ///   - isReply: 是否楼层内的回复（缩进展示）
    ///   - replyCount: 该楼层回复总数（仅主评论行传，> maxVisibleReplies 时才显示展开/收起）
    ///   - isExpanded: 该楼层是否已展开全部回复
    ///   - showsSeparator: 是否显示底部分隔线（列表最后一条传 false）
    ///   - authorAvatar: 评论作者就是帖子作者时，帖子带过来的公众号头像（非空优先用）
    ///   - postAuthorAddr: 帖子作者地址；别人看 TA 自己的评论时标「作者」，自己看自己的评论仍是「我」
    func configure(_ comment: SquareComment, isReply: Bool = false, replyCount: Int = 0, isExpanded: Bool = false, showsSeparator: Bool = true, authorAvatar: String = "", postAuthorAddr: String = "") {
        self.currentComment = comment
        self.isReply = isReply
        self.replyCount = replyCount
        self.isExpanded = isExpanded
        self.separatorLine.isHidden = !showsSeparator

        // 一级评论已不可见但仍有回复：服务端给 deleted=true，正文/作者为空 ⇒ 显示占位
        nameLab.text = comment.deleted ? L("已删除") : comment.displayName
        let displayContent = comment.deleted ? L("该评论已删除") : comment.content
        contentLab.attributedText = SquareRichText.linkOnlyAttributed(displayContent, style: SquareCommentCell.contentStyle)
        timeLab.text = SquareDateParser.displayText(from: comment.createdDate)
        pendingLab.isHidden = !comment.isPendingReview

        // 昵称后的身份标签：「我」优先，其次「作者」；没有身份时宽度置 0（不占位）
        let tag = identityTag(for: comment, postAuthorAddr: postAuthorAddr)
        tagLab.text = tag.isEmpty ? nil : tag
        tagLab.isHidden = tag.isEmpty
        let tagFont = tagLab.font ?? .regularFont(10)
        let tagWidth = tag.isEmpty ? 0 : (tag as NSString).size(withAttributes: [.font: tagFont]).width + 12
        tagWidthConstraint?.update(offset: ceil(tagWidth))

        configureAvatar(for: comment, authorAvatar: authorAvatar)

        // 自己的评论才显示删除按钮，并把时间往左让位
        deleteBtn.isHidden = !comment.isMine
        if comment.isMine {
            timeRightConstraint?.deactivate()
            timeBeforeDeleteConstraint?.activate()
        } else {
            timeBeforeDeleteConstraint?.deactivate()
            timeRightConstraint?.activate()
        }

        // 回复行缩进
        avatarLeftConstraint?.update(offset: isReply ? 15 + SquareCommentCell.replyIndent : 15)

        let showsToggle = !isReply && replyCount > SquareCommentCell.maxVisibleReplies
        toggleBtn.isHidden = !showsToggle
        if showsToggle {
            toggleBtn.setTitle(isExpanded ? L("收起") : "\(L("展开全部")) \(replyCount) \(L("条回复"))", for: .normal)
            contentBottomConstraint?.deactivate()
            toggleBottomConstraint?.activate()
        } else {
            toggleBottomConstraint?.deactivate()
            contentBottomConstraint?.activate()
        }
    }

    /// 昵称后的身份标签，只区分两种：**「我」最高**（自己看自己的评论，包括在别人帖子里），
    /// 其次「作者」（别人看帖子作者本人的评论）。
    /// 不再显示「公众号」：服务端评论对象不提供 authorKind / authorAvatar，判断不出来就不乱标。
    private func identityTag(for comment: SquareComment, postAuthorAddr: String) -> String {
        if comment.isMine {
            return L("我")
        }
        if !postAuthorAddr.isEmpty, comment.authorAddr == postAuthorAddr {
            return L("作者")
        }
        return ""
    }

    /// 头像：优先用传进来的作者头像（公众号作者自己的评论），否则按地址异步解析（本地登录信息 / 通讯录 / 链上）
    private func configureAvatar(for comment: SquareComment, authorAvatar: String) {
        guard !isForMeasurement else { return }

        let address = comment.authorAddr
        currentAddress = address
        currentAvatarURL = authorAvatar

        // 身份只看**作者地址**：同一个人换头像地址时不能重置，
        // 只有换人（cell 复用）才重置成占位图，否则刷新时会闪一下
        let identity = address.isEmpty ? "srv:\(authorAvatar)" : "addr:\(address)"
        if identity != self.avatarIdentity {
            self.avatarIdentity = identity
            self.appliedAvatarURL = nil
            avatarView.contentMode = .scaleAspectFill
            avatarView.backgroundColor = .clear
            avatarView.image = SquareCommentCell.defaultAvatar
        }

        if !authorAvatar.isEmpty,
           let link = SquareMediaURLParser.displayURL(from: authorAvatar, pixelSide: SquareCommentCell.avatarPixelSide) {
            applyAvatar(url: link, key: authorAvatar)
            return
        }

        SquareAvatarResolver.avatarURL(for: address) { [weak self] url in
            guard let self = self, self.currentAddress == address, self.currentAvatarURL == authorAvatar else { return }
            guard let url = url,
                  let link = SquareMediaURLParser.displayURL(from: url, pixelSide: SquareCommentCell.avatarPixelSide) else { return }
            self.applyAvatar(url: link, key: url)
        }
    }

    /// 贴上头像：同一个地址已经贴过就直接跳过（避免占位图闪一下）
    private func applyAvatar(url: URL, key: String) {
        guard self.appliedAvatarURL != key || self.avatarView.image == nil else { return }
        self.appliedAvatarURL = key
        avatarView.contentMode = .scaleAspectFill
        // 已加载过的头像会**同步**贴上去，不会先闪一帧占位图
        SquareAvatarLoader.apply(to: avatarView,
                                 url: url,
                                 key: key,
                                 placeholder: SquareCommentCell.defaultAvatar) { [weak self] success in
            guard let self = self, !success, self.appliedAvatarURL == key else { return }
            // 加载失败：清掉记录，下次重新配置时重试（否则会一直停在占位图）
            self.appliedAvatarURL = nil
        }
    }

    @objc private func toggleTap() {
        onToggleReplies?()
    }

    /// 点头像：跳该评论作者的信息页（手机会自己把行选中事件取消）
    @objc private func avatarTap() {
        guard let comment = currentComment else { return }
        onAvatarTapped?(comment)
    }

    @objc private func deleteTap() {
        onDeleteTapped?()
    }

    /// 评论内容点击：只处理链接（`linkOnlyAttributed` 只会产链接一种可点元素）
    @objc private func contentTap(_ gesture: UITapGestureRecognizer) {
        guard let tap = SquareRichText.tap(at: gesture.location(in: contentLab), inLabel: contentLab) else { return }
        if case .url(let url) = tap {
            onLinkTapped?(url)
        }
    }

    /// 只有按下位置**真的在链接上**才让手势开始识别：
    /// 命中链接时手势会吞掉这次点击（`cancelsTouchesInView` 默认 true），列表行就不会再走「点评论 = @ 回复」；
    /// 没命中时手势直接不参与，点击照旧传给列表。
    ///
    /// ⚠️ `UITableViewCell`（→ `UIView`）**本身已遵从 `UIGestureRecognizerDelegate`**，
    ///    所以类声明里不能再写一遍（`Redundant conformance`），这里直接 `override` 即可。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === contentTapGesture else { return true }
        return SquareRichText.tap(at: gestureRecognizer.location(in: contentLab), inLabel: contentLab) != nil
    }

    // MARK: - 行高

    private static var sizingCell: SquareCommentCell?
    private static var heightCache = [String: CGFloat]()

    /// 确定性行高（展开状态变化时高度会变，key 里包含相应丢字段）
    static func height(for comment: SquareComment, width: CGFloat, isReply: Bool, replyCount: Int, isExpanded: Bool) -> CGFloat {
        guard width > 0 else { return 0 }

        let key = "\(comment.id)_\(comment.content.count)_\(Int(width))_\(isReply)_\(isExpanded ? 1 : 0)_\(replyCount)_\(comment.isPendingReview ? 1 : 0)"
        if let cached = heightCache[key] {
            return cached
        }

        let cell = sizingCell ?? SquareCommentCell.init(style: .default, reuseIdentifier: SquareCommentCell.identifier)
        sizingCell = cell
        cell.isForMeasurement = true
        cell.bounds = CGRect(x: 0, y: 0, width: width, height: 200)
        cell.configure(comment, isReply: isReply, replyCount: replyCount, isExpanded: isExpanded)
        cell.setNeedsLayout()
        cell.layoutIfNeeded()

        let size = cell.contentView.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                                            withHorizontalFittingPriority: .required,
                                                            verticalFittingPriority: .fittingSizeLevel)
        let height = ceil(size.height)

        if heightCache.count > 400 {
            heightCache.removeAll()
        }
        heightCache[key] = height
        return height
    }}
