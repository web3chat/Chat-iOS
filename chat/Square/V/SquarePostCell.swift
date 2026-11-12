//
//  SquarePostCell.swift
//  chat
//
//  广场流帖子 cell：头像 / 展示名（公众号标签）/ 时间 / 正文 / 九宫格 / 点赞·评论·阅读
//

import Foundation
import UIKit
import SnapKit
import Kingfisher

final class SquarePostCell: UITableViewCell {

    static let identifier = "SquarePostCell"

    /// 内容左右边距
    static let contentInset: CGFloat = 15
    /// 头像 + 间隙（列表里正文与图片跟着名称列对齐）
    static let textLeading: CGFloat = 65
    /// 昵称行右侧关注按钮的高度（详情页显示；列表页宽度置 0 不占位，不影响行高）。
    /// ⚠️ 宽度不写常量：按当前语言文案算（`SquareFollowButtonSize`），否则英文 "Following" 会被截断
    private static let followButtonHeight: CGFloat = 26
    /// 昵称单行高度。昵称行里的每个元素（置顶角标 / 金标 / 身份标签 / 分类标签 / 时间 / 关注按钮 / 三个点）
    /// 都对齐到**昵称的第一行中线**，这样详情页昵称换行后这些元素仍然贴着第一行，不会跑到两行中间。
    private static let nameLineHeight: CGFloat = 20

    /// 正文 / 内联图片 / 九宫格 / 操作栏的左边界
    /// - Parameter alignsWithAvatar: true = 与头像左对齐（详情页：整块内容占满内容区）；
    ///   false = 与昵称左对齐（列表：正文跟在头像右侧）
    static func contentLeading(alignsWithAvatar: Bool) -> CGFloat {
        return alignsWithAvatar ? contentInset : textLeading
    }
    /// 头像降采样尺寸（40pt @2x 再放大一档，兼顾清晰与内存）
    private static let avatarPixelSize = CGSize(width: 40 * UIScreen.main.scale * 2,
                                                height: 40 * UIScreen.main.scale * 2)

    var onLikeTapped: ((SquarePost) -> Void)?
    var onCommentTapped: ((SquarePost) -> Void)?
    var onAvatarTapped: ((SquarePost) -> Void)?
    var onTapImage: ((SquarePost, Int, UIImageView) -> Void)?
    /// 右下角三个点（仅本人帖子显示）
    var onMoreTapped: ((SquarePost) -> Void)?
    /// 分享（操作栏最右侧那个）。不设置时 cell 自己弹系统分享面板
    var onShareTapped: ((SquarePost) -> Void)?
    /// 正文里的可点元素（@提及 / #话题 / 链接 / 「查看更多」），仅详情页需要
    var onRichTextTapped: ((SquareRichTap) -> Void)?

    /// 昵称行右侧是否展示「关注 / 已关注」（详情页 true；列表 false）。
    /// ⚠️ 必须在 `configure` **之前**设置：configure 里会按它算按钮宽度与状态（事后设也会自动补刷一次）
    var showsFollow = false {
        didSet { applyFollowState() }
    }

    /// 操作栏里是否展示「举报」（**广场列表** true）。
    /// 我的帖子全是自己的、帖子详情页右上角已有举报入口 ⇒ 那两处不传。
    /// ⚠️ 必须在 `configure` **之前**设置（configure 里按它决定显隐）
    var showsReport = false {
        didSet { applyReportState() }
    }

    private var post: SquarePost?
    /// 是否展示完整正文（详情页 true；列表只显示前 100 字 + 「查看更多」）
    private var showsFullContent = false
    /// 昵称是否允许换行（广场流 / 详情页 true：昵称太长时换行**完整展示**，不再截断成「...」）
    private var wrapsLongName = false
    /// 仅用于离屏测量行高（跳过图片下载）
    private var isForMeasurement = false
    /// 当前头像的「身份」（服务端头像串 / 作者地址）：整表刷新时同一个人不重置头像，避免头像闪一下
    private var avatarIdentity: String?
    /// 已经贴上去的头像地址：同一地址不重复 setImage，否则会被置回占位图再换回来（闪）
    private var appliedAvatarURL: String?
    /// 当前已排期的大图预热 key（cell 复用到别的帖子时取消未触发的预热）
    private var pendingPrefetchKey: String?

    /// 默认占位头像
    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")

    // MARK: - 子视图

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 20
        view.backgroundColor = Color_F6F7F8
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTap)))
        return view
    }()

    /// 发帖者昵称：**主题蓝**（`Color_Theme` #32B2F7），与广场列表 / 帖子详情页保持一致
    /// （两个页面共用本 cell，所以只需在这里定一次颜色）
    private lazy var nameLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(15), textColor: Color_Theme, textAlignment: .left, text: nil)
    }()

    /// 关注按钮（详情页昵称行右侧、与昵称平齐）：
    /// 状态与请求全交给 `SquareFollowStore`（和作者信息页同一套逻辑，见 `SquareFollowStore.toggleFollow`）
    private lazy var followBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.titleLabel?.font = .mediumFont(13)
        btn.layer.cornerRadius = SquarePostCell.followButtonHeight / 2
        btn.clipsToBounds = true
        // 默认隐藏 + 宽度 0（列表页完全不占位；详情页由 applyFollowState 打开）
        btn.isHidden = true
        btn.addTarget(self, action: #selector(followTap), for: .touchUpInside)
        return btn
    }()

    private lazy var officialTagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_FFFFFF, textAlignment: .center, text: L("公众号"))
        // 默认蓝色（「我」/「公众号」）；平台官方号的「官方号」在 configure 里换成醒目的金橙
        lab.backgroundColor = Color_Identity_Tag
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        return lab
    }()

    /// 置顶角标（运营置顶，仅广场流第 1 页会带）
    private lazy var pinnedTagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_FFFFFF, textAlignment: .center, text: L("置顶"))
        lab.backgroundColor = Color_Gold
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        lab.isHidden = true
        return lab
    }()

    /// 官方帖分类标签（公告 / 消息 / 活动）：右对齐在昵称行末尾，个人帖恒空
    private lazy var feedTagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_Theme, textAlignment: .center, text: nil)
        lab.backgroundColor = Color_Theme_Light
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        lab.isHidden = true
        return lab
    }()

    /// 金标（作者是运营授予金标的公众号时才显示，宽度 0 / 14 切换）
    /// 样式：橙色实心圆 + 白色实心五角星（`star.circle.fill` 的星是**镂空**的，
    /// 白底上正好是白星；放进 14pt 高度时圆直径约 12pt，与旧 seal 图标等大，布局不用改）
    private lazy var goldView: UIImageView = {
        let config = UIImage.SymbolConfiguration.init(pointSize: 12, weight: .bold)
        let view = UIImageView.init(image: UIImage.init(systemName: "star.circle.fill", withConfiguration: config)?.withRenderingMode(.alwaysTemplate))
        view.tintColor = Color_Gold
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var timeLab: UILabel = {
        return UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()

    /// 正文块容器（文字块与内联图片块**按顺序**竖向排列 —— 就是图文混排）
    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 10
        return stack
    }()

    private lazy var imageGrid: SquareImageGridView = {
        let view = SquareImageGridView()
        view.onTapImage = { [weak self] index, imageView in
            guard let self = self, let post = self.post else { return }
            self.onTapImage?(post, index, imageView)
        }
        return view
    }()

    private lazy var likeItem: SquareActionItem = {
        let item = SquareActionItem()
        item.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
        return item
    }()

    private lazy var commentItem: SquareActionItem = {
        let item = SquareActionItem()
        item.addTarget(self, action: #selector(commentTap), for: .touchUpInside)
        return item
    }()

    private lazy var viewItem: SquareActionItem = {
        return SquareActionItem()
    }()

    /// 举报：操作栏里**阅读按钮的右边**（只对别人的帖子显示，见 `showsReport`）
    private lazy var reportItem: SquareActionItem = {
        let item = SquareActionItem()
        item.addTarget(self, action: #selector(reportTap), for: .touchUpInside)
        return item
    }()

    /// 分享：与点赞同一行、贴在操作栏最右边
    private lazy var shareItem: SquareActionItem = {
        let item = SquareActionItem()
        item.addTarget(self, action: #selector(shareTap), for: .touchUpInside)
        return item
    }()

    private lazy var actionStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [likeItem, commentItem, viewItem, reportItem])
        stack.axis = .horizontal
        // 必须 .fill：.center 时 SquareActionItem 自身无高度约束，高度会算成 0，导致点击穿透（点赞没反应）
        stack.alignment = .fill
        stack.spacing = 20
        return stack
    }()

    private lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()

    /// 右下角三个点：自己的帖子直接在列表里就能删除 / 关评论，不用先进详情
    private lazy var moreBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(UIImage.init(systemName: "ellipsis")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_8A97A5
        btn.isHidden = true
        btn.enlargeClickEdge(10, 10, 10, 10)
        btn.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
        return btn
    }()

    // 注意：本工程内有同名 `Constraint`（数据库层），这里必须显式写 SnapKit.Constraint
    private var imageGridHeightConstraint: SnapKit.Constraint?
    /// 身份标签宽度（我 / 公众号；没有身份时置 0 不占位）
    private var officialTagWidthConstraint: SnapKit.Constraint?
    /// 金标宽度（非金标号置 0 不占位）
    private var goldWidthConstraint: SnapKit.Constraint?
    /// 昵称左边界（置顶角标占位时整体右移，用常量偏移，不与角标视图互相引用）
    private var nameLeadingConstraint: SnapKit.Constraint?
    /// 昵称高度（= 单行高度 × 实际行数；`configure` 里按文本宽度算出来显式更新）
    private var nameHeightConstraint: SnapKit.Constraint?
    /// 置顶角标宽度（非置顶置 0 不占位）
    private var pinnedTagWidthConstraint: SnapKit.Constraint?
    /// 官方帖分类标签（公告 / 消息 / 活动）宽度（无标签置 0 不占位）
    private var feedTagWidthConstraint: SnapKit.Constraint?
    /// 关注按钮宽度（不展示时置 0 不占位）
    private var followWidthConstraint: SnapKit.Constraint?
    /// 三个点按钮宽度（详情页不展示三点，置 0 把右侧位置让出来）
    private var moreWidthConstraint: SnapKit.Constraint?
    /// 正文 / 图片 / 操作栏的左边界约束（详情页要与头像左对齐，列表与昵称对齐）
    private var contentLeadingConstraints = [SnapKit.Constraint]()
    /// 分类标签的两套位置（由 `applyFeedTagLayout(inline:)` 二选一激活）：
    /// 放得下 = 跟在身份标签**同一行**；放不下 = 掉到**下一行**（与身份标签左对齐）
    private var feedTagInlineLeadingConstraint: SnapKit.Constraint?
    private var feedTagInlineCenterYConstraint: SnapKit.Constraint?
    private var feedTagBelowLeadingConstraint: SnapKit.Constraint?
    private var feedTagBelowTopConstraint: SnapKit.Constraint?
    /// 「正文给标签行让位」的约束（标签 bottom + 8）：
    /// **一个标签都没有时必须停用** —— 标签宽度虽然是 0，但只要约束还在，正文就会被顶下一段空白
    private var tagRowConstraints = [SnapKit.Constraint]()
    /// 当前是否处于「有标签行」状态（去抖：只在真变化时才动约束）
    private var tagRowActive = true
    /// 分类标签当前是否与身份标签同一行（去抖用，初始 = 同行）
    private var feedTagInlineActive = true

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = Color_FFFFFF
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // ⚠️🔴 千万不要在这里（或任何地方）用 `nameLab.bounds.width` 回填 `preferredMaxLayoutWidth`！
    // 多行 UILabel 的 intrinsic **宽度** = min(单行宽度, preferredMaxLayoutWidth) ——
    // 只要有一轮布局时 nameLab 的宽度偏小（cell 复用、约束还没稳定、首帧等），就会被**永久锁死在那个窄宽度**上
    // （宽度变窄 → 下一轮再写更窄 → 正反馈），表现就是「昵称被裁成一两个字」。
    // 2026-09-28 就是这么踩的，已回退。昵称的换行高度交给 Auto Layout 自己算：
    // 宽度由约束链决定，UILabel 会用 bounds.width 重算多行高度（`numberOfLines = 0` + `byWordWrapping`）。

    private func setupViews() {
        // 昵称行各元素的对齐基准：昵称**第一行**的中线（= 昵称 top + 单行高度的一半）
        let nameCenterY = SquarePostCell.nameLineHeight / 2
        contentView.addSubview(avatarView)
        contentView.addSubview(pinnedTagLab)
        contentView.addSubview(nameLab)
        contentView.addSubview(followBtn)
        contentView.addSubview(goldView)
        contentView.addSubview(officialTagLab)
        contentView.addSubview(feedTagLab)
        contentView.addSubview(timeLab)
        contentView.addSubview(contentStack)
        contentView.addSubview(imageGrid)
        contentView.addSubview(actionStack)
        contentView.addSubview(moreBtn)
        contentView.addSubview(shareItem)
        contentView.addSubview(lineView)

        avatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(SquarePostCell.contentInset)
            m.top.equalToSuperview().offset(14)
            m.size.equalTo(CGSize(width: 40, height: 40))
        }

        nameLab.snp.makeConstraints { (m) in
            nameLeadingConstraint = m.left.equalToSuperview().offset(SquarePostCell.textLeading).constraint
            m.top.equalToSuperview().offset(16)
            // 昵称高度**由 `configure` 显式给**（= 单行高度 × 实际行数）。
            // ⚠️ 不能只写 `>= 20` 靠 UILabel 自己长高：本 cell 的行高是离屏 `systemLayoutSizeFitting` 量的，
            // 多行 label 在那条路上会按错的宽度算 ⇒ 只算出一行高度 ⇒ 第二行被裁（用户报的「昵称被截断」）
            nameHeightConstraint = m.height.equalTo(SquarePostCell.nameLineHeight).constraint
        }

        // 置顶角标：占昵称左边（宽度置 0 时昵称回到原来的位置）
        pinnedTagLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(SquarePostCell.textLeading)
            m.centerY.equalTo(nameLab.snp.top).offset(nameCenterY)
            m.height.equalTo(16)
            pinnedTagWidthConstraint = m.width.equalTo(0).constraint
        }

        // 金标：**紧贴昵称右侧**（金标号才有；宽度置 0 时不占位）
        goldView.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.right)
            m.centerY.equalTo(nameLab.snp.top).offset(nameCenterY)
            m.height.equalTo(14)
            goldWidthConstraint = m.width.equalTo(0).constraint
        }

        // 身份标签（我 / 官方号 / 公众号）：**另起一行**，与昵称左对齐（用户 2026-09-28：
        // 标签全部下移到第二行，第一行只留「昵称 + 金标 + 时间」，昵称才不会被标签挤没）
        officialTagLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.left)
            m.top.equalTo(nameLab.snp.bottom).offset(6)
            m.height.equalTo(16)
            officialTagWidthConstraint = m.width.equalTo(0).constraint
        }

        // 官方帖分类标签（公告 / 消息 / 活动）：优先跟在身份标签**同一行**，放不下时掉到**下一行**
        feedTagLab.snp.makeConstraints { (m) in
            feedTagInlineLeadingConstraint = m.left.equalTo(officialTagLab.snp.right).offset(6).constraint
            feedTagInlineCenterYConstraint = m.centerY.equalTo(officialTagLab).constraint
            feedTagBelowLeadingConstraint = m.left.equalTo(officialTagLab.snp.left).constraint
            feedTagBelowTopConstraint = m.top.equalTo(officialTagLab.snp.bottom).offset(6).constraint
            m.height.equalTo(16)
            feedTagWidthConstraint = m.width.equalTo(0).constraint
            // 标签行右边不许压到「三个点 / 关注按钮」那一片
            m.right.lessThanOrEqualTo(moreBtn.snp.left).offset(-8)
        }
        // 初始：分类标签与身份标签同一行（放不下时 configure 里切到下一行）
        feedTagBelowLeadingConstraint?.deactivate()
        feedTagBelowTopConstraint?.deactivate()

        timeLab.snp.makeConstraints { (m) in
            // 时间**始终在第一行**：跟在金标后面（金标隐藏时宽度 0 ⇒ 等价于跟在昵称后面）
            m.left.equalTo(goldView.snp.right).offset(6)
            m.centerY.equalTo(nameLab.snp.top).offset(nameCenterY)
            // 给「关注按钮 / 三个点」让位
            m.right.lessThanOrEqualTo(followBtn.snp.left).offset(-8)
        }
        // 关注按钮：右对齐在三个点左侧（宽度置 0 = 不占位，列表页不展示）
        followBtn.snp.makeConstraints { (m) in
            m.right.equalTo(moreBtn.snp.left).offset(-8)
            m.centerY.equalTo(nameLab.snp.top).offset(nameCenterY)
            m.height.equalTo(SquarePostCell.followButtonHeight)
            followWidthConstraint = m.width.equalTo(0).constraint
        }
        // 名称过长时优先保证时间可见
        nameLab.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentStack.snp.makeConstraints { (m) in
            contentLeadingConstraints.append(m.left.equalToSuperview().offset(SquarePostCell.textLeading).constraint)
            m.right.equalToSuperview().offset(-SquarePostCell.contentInset)
            // 默认跟在头像下方；详情页昵称换行 / 时间下移变高时由它们把正文顶下去（否则会压住下面几行）。
            // 999 优先级的等式保证只有一行昵称时位置与原来完全一致，行高也不变。
            m.top.greaterThanOrEqualTo(avatarView.snp.bottom).offset(8)
            m.top.greaterThanOrEqualTo(nameLab.snp.bottom).offset(8)
            m.top.greaterThanOrEqualTo(timeLab.snp.bottom).offset(8)
            // 标签行在昵称下面：有标签时正文必须让开它（没标签时这两条由 `applyTagRowVisibility` 停用）
            tagRowConstraints.append(m.top.greaterThanOrEqualTo(officialTagLab.snp.bottom).offset(8).constraint)
            tagRowConstraints.append(m.top.greaterThanOrEqualTo(feedTagLab.snp.bottom).offset(8).constraint)
            m.top.equalTo(avatarView.snp.bottom).offset(8).priority(999)
        }

        imageGrid.snp.makeConstraints { (m) in
            contentLeadingConstraints.append(m.left.equalToSuperview().offset(SquarePostCell.textLeading).constraint)
            m.right.equalToSuperview().offset(-SquarePostCell.contentInset)
            m.top.equalTo(contentStack.snp.bottom).offset(10)
            imageGridHeightConstraint = m.height.equalTo(0).constraint
        }

        actionStack.snp.makeConstraints { (m) in
            contentLeadingConstraints.append(m.left.equalToSuperview().offset(SquarePostCell.textLeading).constraint)
            m.top.equalTo(imageGrid.snp.bottom).offset(12)
            m.height.equalTo(20)
            m.bottom.equalToSuperview().offset(-14)
        }

        lineView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(SquarePostCell.contentInset)
            m.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
        // 与点赞栏同一行、靠右（高度不参与行高计算，不影响 height(for:)）
        moreBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-SquarePostCell.contentInset)
            m.centerY.equalTo(nameLab.snp.top).offset(nameCenterY)
            m.height.equalTo(22)
            moreWidthConstraint = m.width.equalTo(22).constraint
        }
        // 分享：与点赞同一行、位于最右侧。不放进 actionStack，避免把左侧三个统计推歪
        shareItem.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-SquarePostCell.contentInset)
            m.centerY.equalTo(actionStack)
            m.height.equalTo(20)
        }
        // 统计数字很长时先压缩统计（不换行、截断），别去和分享按钮重叠
        actionStack.snp.makeConstraints { (m) in
            m.right.lessThanOrEqualTo(shareItem.snp.left).offset(-12)
        }
    }

    // MARK: - 数据绑定

    /// 分类标签的位置切换：放得下就与身份标签**同一行**，放不下就掉到**下一行**（与身份标签左对齐）。
    /// 两套约束互斥：先关掉另一套再开自己那套，避免「同一视图两组位置约束同时有效」的冲突。
    private func applyFeedTagLayout(inline: Bool) {
        guard feedTagInlineActive != inline else { return }
        feedTagInlineActive = inline
        if inline {
            feedTagBelowLeadingConstraint?.deactivate()
            feedTagBelowTopConstraint?.deactivate()
            feedTagInlineLeadingConstraint?.activate()
            feedTagInlineCenterYConstraint?.activate()
        } else {
            feedTagInlineLeadingConstraint?.deactivate()
            feedTagInlineCenterYConstraint?.deactivate()
            feedTagBelowLeadingConstraint?.activate()
            feedTagBelowTopConstraint?.activate()
        }
    }

    /// 标签行显隐：**一个标签都没有**时要把「正文给标签让位」的两条约束停掉，
    /// 否则标签宽度虽然是 0，正文仍会被顶出 22pt 以上的空白。
    /// 先全部停用再按需激活 —— `configure` 每次都会调它，写成幂等的最稳。
    private func applyTagRowVisibility(hasTags: Bool) {
        guard tagRowActive != hasTags else { return }
        tagRowActive = hasTags
        tagRowConstraints.forEach { hasTags ? $0.activate() : $0.deactivate() }
    }

    /// 切换内容左边界：详情页与头像左对齐，列表与昵称对齐。
    /// 会改变正文的可用宽度（进而影响换行与行高），所以 `height(for:)` 必须传同一个值
    private func applyContentLeading(alignsWithAvatar: Bool) {
        let leading = SquarePostCell.contentLeading(alignsWithAvatar: alignsWithAvatar)
        contentLeadingConstraints.forEach { $0.update(offset: leading) }
    }

    /// - Parameter showsMore: 是否显示右下角三个点（点赞 / 回复 / 查看 同一行的右侧那个）。
    ///   详情页里的操作入口在别处，传 false 隐藏。
    /// - Parameter showsBottomLine: 是否显示单元格底部细线（详情页传 false：
    ///   键盘弹起时表格高度变化会把这条线一起拖动，看起来像“细线飘了”，而输入条自己已经有一条分割线）
    /// - Parameter showsSelfTag: 自己的普通帖是否也标「我」（详情页传 true）
    /// - Parameter showsFullContent: 是否显示完整正文（详情页传 true：全文展示、不截断；
    ///   列表 false：与详情页**同一套渲染**（Markdown 排版 + 图文混排内联图），只是文字累计满 100 字后
    ///   截断成「… 查看更多」，其后的块（含后面的图片）不再显示）
    /// - Parameter interactiveContent: 正文是否需要交互（详情页 true：@ / #话题 / 链接可点、长按可选中复制；列表 false）
    /// - Parameter alignsContentWithAvatar: 正文 / 图片 / 操作栏是否与头像左对齐（详情页 true；列表 false 与昵称对齐）
    /// - Parameter wrapsLongName: 昵称过长时是否换行完整展示（广场流 / 详情页 true）。
    ///   开启后昵称可占多行，其余元素仍对齐它**第一行**，正文会被昵称顶下去；
    ///   ⚠️ 该开关与昵称内容都会影响行高 ⇒ `height(for:)` 必须传同一个值（缓存 key 已含两者）
    /// - Parameter showsImagesCompletely: 帖子图片是否「完整显示」（详见 `SquareImageGridView.displaysImagesCompletely`）。
    ///   **目前只有帖子详情页传 true**（用户 2026-10-09：进详情页后图片不该还裁着，要整张都看得见）。
    ///   格子尺寸没变 ⇒ 不影响行高，`height(for:)` 不需要传它。
    /// ⚠️ 标签行（身份标签 / 分类标签）的位置由 `applyFeedTagLayout` 按可用宽度自动决定，
    /// 时间固定在第一行、跟在金标后面（2026-09-28 用户定的版式），这两个都没有开关可传。
    func configure(_ post: SquarePost, cellWidth: CGFloat, showsMore: Bool = true, showsBottomLine: Bool = true, showsSelfTag: Bool = false, showsFullContent: Bool = false, interactiveContent: Bool = false, alignsContentWithAvatar: Bool = false, wrapsLongName: Bool = false, showsImagesCompletely: Bool = false) {
        self.post = post
        self.showsFullContent = showsFullContent
        self.wrapsLongName = wrapsLongName
        // 昵称：允许换行时按内容占多行**完整展示**（四个列表页都开），否则单行截断
        nameLab.numberOfLines = wrapsLongName ? 0 : 1
        nameLab.lineBreakMode = wrapsLongName ? .byWordWrapping : .byTruncatingTail
        applyContentLeading(alignsWithAvatar: alignsContentWithAvatar)

        // 作者头像：服务端带 authorAvatar 就直接用（公众号帖），为空才按地址解析，
        // 两者都取不到且是公众号帖时用主题色喇叭图标区分
        configureAvatar(for: post)
        nameLab.text = post.displayName
        // 昵称后的身份标签：「我」优先，其次官方号 / 公众号
        let tag = post.identityTag(showsSelfTag: showsSelfTag)
        officialTagLab.text = tag.isEmpty ? nil : tag
        officialTagLab.isHidden = tag.isEmpty
        // 只有平台官方号（唯一）用醒目的金橙底；「我」/「公众号」保持蓝色
        officialTagLab.backgroundColor = post.isPlatformOfficial ? Color_Official_Tag : Color_Identity_Tag
        let tagFont = officialTagLab.font ?? .regularFont(10)
        let tagWidth = tag.isEmpty ? 0 : (tag as NSString).size(withAttributes: [.font: tagFont]).width + 12
        officialTagWidthConstraint?.update(offset: ceil(tagWidth))
        // 金标（《App增量-公众号金标》§4）：帖子带了 `authorGold` 就用它；
        // 没带时回退到金标目录（`GET /officials` 学到的那份名单），避免后端漏字段就永远不显示金标
        let showsGold = SquarePostCell.showsGold(for: post)
        goldView.isHidden = !showsGold
        goldWidthConstraint?.update(offset: showsGold ? 14 : 0)
        // 置顶（《App增量-置顶与二次编辑》§2）：角标占昵称左侧，昵称整体右移一个常量
        let pinnedFont = pinnedTagLab.font ?? .regularFont(10)
        let pinnedTagWidth = post.pinned ? ceil((L("置顶") as NSString).size(withAttributes: [.font: pinnedFont]).width + 12) : 0
        pinnedTagLab.isHidden = !post.pinned
        pinnedTagWidthConstraint?.update(offset: pinnedTagWidth)
        nameLeadingConstraint?.update(offset: SquarePostCell.textLeading + (pinnedTagWidth > 0 ? pinnedTagWidth + 6 : 0))
        // 官方帖分类标签（《App增量-官方帖标签》§2）：非官方帖 tag 恒为空
        // ⚠️ 服务端下发的 tag 是**中文原文**（公告 / 消息 / 活动），它只用来显示 ⇒ 显示前过一遍本地化
        // （⚠️ 请求参数里的 tag 仍必须是中文原文，别拿本地化后的值去请求；顶部筛选栏是同一条规矩）
        // 先 trim：服务端多带一个空格就会让本地化查不到 key、把中文原样摆出来
        let feedTag = post.tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let feedTagText = feedTag.isEmpty ? "" : L(feedTag)
        feedTagLab.text = feedTagText.isEmpty ? nil : feedTagText
        feedTagLab.isHidden = feedTagText.isEmpty
        let feedTagFont = feedTagLab.font ?? .regularFont(10)
        let feedTagWidth = feedTagText.isEmpty ? 0 : ceil((feedTagText as NSString).size(withAttributes: [.font: feedTagFont]).width + 12)
        feedTagWidthConstraint?.update(offset: feedTagWidth)

        // 标签行排版（用户 2026-09-28）：身份标签与分类标签都放到昵称**下面一行**（与昵称左对齐），
        // 两个标签一行放不下时分类标签掉到**下一行**；两个都空时把「正文让位」的约束停掉。
        let tagMoreBtnWidth: CGFloat = (showsMore && post.isMine && post.id > 0) ? 22 : 0
        let tagsLeft = SquarePostCell.textLeading + (pinnedTagWidth > 0 ? pinnedTagWidth + 6 : 0)
        let tagsAvailable = cellWidth - tagsLeft - SquarePostCell.contentInset - (tagMoreBtnWidth > 0 ? tagMoreBtnWidth + 8 : 0)
        let tagsInlineWidth = tagWidth + feedTagWidth + ((tagWidth > 0 && feedTagWidth > 0) ? 6 : 0)
        applyFeedTagLayout(inline: tagsInlineWidth <= tagsAvailable)
        applyTagRowVisibility(hasTags: tagWidth > 0 || feedTagWidth > 0)
        timeLab.text = SquarePostCell.timeText(of: post)

        // 昵称**必须完整显示**：用 UILabel 自己的 `sizeThatFits` 在「可用宽度」下量出它到底需要多高，
        // 再**显式**写进 `nameLab` 的高度约束。
        // ⚠️ 为什么不再"算行数"（boundingRect / 宽度比较）：中英混排 + 标点的换行点与真实渲染有出入，
        //    临界时（名字宽度 ≈ 可用宽度）会**少算一行** ⇒ 第二行被裁（用户报的「昵称被截断」）。
        //    `sizeThatFits` 与渲染是同一套引擎，量出来多少就是多少。
        // ⚠️ 宽度用**按当前内容算出的确定值**，不是 `nameLab.bounds.width`
        //    （2026-09-28 “用 bounds.width 回填 → 越写越窄” 那个坑已回退，别再走回头路）
        let nameTimeWidth = ceil((SquarePostCell.timeText(of: post) as NSString)
            .size(withAttributes: [.font: timeLab.font ?? UIFont.regularFont(12)]).width)
        let nameFollowWidth: CGFloat = showsFollow ? SquareFollowButtonSize.width(font: .mediumFont(13)) : 0
        let nameMoreWidth: CGFloat = (showsMore && post.isMine && post.id > 0) ? 22 : 0
        var nameRightReserve = SquarePostCell.contentInset + nameTimeWidth + 6 + (showsGold ? 14 : 0)
        if nameMoreWidth > 0 { nameRightReserve += nameMoreWidth + 8 }
        if nameFollowWidth > 0 { nameRightReserve += nameFollowWidth + 8 }
        let nameLeadingInset = SquarePostCell.textLeading + (pinnedTagWidth > 0 ? pinnedTagWidth + 6 : 0)
        // 再留 12pt 余量：宁可多算一行/多留一点白，也不要让文字被裁
        let nameAvailable = max(40, cellWidth - nameLeadingInset - nameRightReserve - 12)
        nameLab.preferredMaxLayoutWidth = nameAvailable
        let nameFitHeight = ceil(nameLab.sizeThatFits(
            CGSize(width: nameAvailable, height: CGFloat.greatestFiniteMagnitude)).height)
        // 单行：保持原来的 20pt（所有页面的行高都不变）；多行：给足再多留 6pt，绝不让第二行被裁
        let nameHeight = nameFitHeight <= SquarePostCell.nameLineHeight + 2
            ? SquarePostCell.nameLineHeight
            : nameFitHeight + 6
        nameHeightConstraint?.update(offset: nameHeight)

        // 正文：图文混排。列表与详情页现在是**同一套**渲染（文字块 / 内联图片块按原位置交替排列），
        // 区别只有「列表按 100 字截断 + 查看更多」（见 `contentBlocks`）；没内联的图片两边都仍走九宫格
        let maxWidth = cellWidth - SquarePostCell.contentLeading(alignsWithAvatar: alignsContentWithAvatar) - SquarePostCell.contentInset
        // ⚠️ 列表也要算内联图：列表与详情页现在是同一套渲染 ⇒「内联图 / 九宫格」的分工必须一致
        // （内联过的图两边都不再进九宫格，否则同一张图会出现两次）
        let inlineURLs = SquareRichText.inlineImageURLs(in: post.content)
        rebuildContent(post: post, maxWidth: maxWidth, showsFullContent: showsFullContent, interactiveContent: interactiveContent)

        let gridItems = post.mediaUrls.enumerated().filter { !inlineURLs.contains($0.element) }
        let gridUrls = gridItems.map { $0.element }
        // 详情页正文里内联展示过的图会从九宫格去掉 ⇒ 下标与 mediaUrls 不再一致，
        // 必须把「真实下标」一起传给九宫格（否则点开的会是另一张图）
        let gridTags = gridItems.map { $0.offset }
        // 显示方式必须在 configure **之前**设置：它决定缩略图地址（m_lfit / m_fill）与 contentMode
        imageGrid.displaysImagesCompletely = showsImagesCompletely
        let gridHeight = imageGrid.configure(urls: gridUrls, maxWidth: maxWidth,
                                            loadImages: !isForMeasurement, tags: gridTags)
        imageGridHeightConstraint?.update(offset: gridHeight)
        imageGrid.snp.updateConstraints { (m) in
            m.top.equalTo(contentStack.snp.bottom).offset(gridUrls.isEmpty ? 0 : 10)
        }

        // 帖子在列表里停留一会儿后，提前把「大图浏览」要用的屏宽版图片预热进 SDWebImage 缓存，
        // 点开大图 / 左右滑动时就不用再等下载（预热地址与 SquarePhotoPresenter.present 完全一致）。
        // 只预热前 3 张：既能覆盖「点第一张」和随后左右滑两页，又不会在滑动浏览时产生太多流量；
        // 更靠后的图片在 SquarePhotoPresenter.present 时会按「离当前这张最近」的顺序补预热。
        if !isForMeasurement {
            let prefetchKey = post.mediaUrls.joined(separator: "|")
            if pendingPrefetchKey != prefetchKey {
                if let previous = pendingPrefetchKey {
                    SquarePhotoPrefetcher.cancelPending(key: previous)
                }
                pendingPrefetchKey = prefetchKey
                SquarePhotoPrefetcher.prefetchWhenVisible(
                    Array(post.mediaUrls.prefix(3)), key: prefetchKey)
            }
        }

        likeItem.configure(symbol: post.liked ? "hand.thumbsup.fill" : "hand.thumbsup",
                           title: "\(post.likeCount)",
                           isActive: post.liked)
        commentItem.configure(symbol: "bubble.right", title: "\(post.commentCount)", isActive: false)
        viewItem.configure(symbol: "eye", title: "\(post.viewCount)", isActive: false)
        // 举报：只给**别人的帖子**（自己发的帖不需要），位置在阅读按钮右边
        reportItem.configure(symbol: "flag", title: L("举报"), isActive: false)
        reportItem.accessibilityLabel = L("举报")
        applyReportState()
        // 分享只放图标（不要文字）：文字标签留给 VoiceOver
        shareItem.configure(symbol: "square.and.arrow.up", title: "", isActive: false)
        shareItem.accessibilityLabel = L("分享")
        // 待审 / 被拒的帖子不给分享（内容还没正式公开）
        shareItem.isHidden = post.isUnderReview
        // 本地待审快照 id = 0，没有服务端对象可操作，不展示三个点
        let showsMoreBtn = showsMore && post.isMine && post.id > 0
        moreBtn.isHidden = !showsMoreBtn
        // 不显示三点时**连宽度也置 0**（隐藏的普通视图仍占位）：昵称行右侧可用区跟着右移，
        // 昵称就多出 22+8pt（用户 2026-09-28 报的「昵称显示不全」也有这部分的份）；
        // 详情页（showsMore = false）同理 —— 关注按钮才能贴近右边缘
        moreWidthConstraint?.update(offset: showsMoreBtn ? 22 : 0)
        lineView.isHidden = !showsBottomLine
        // 昵称行右侧的关注按钮（详情页才显示；自己的帖 / 地址为空不给）
        self.applyFollowState()

        // DEBUG：昵称行排版自检（用户 2026-09-28 要求打印广场帖子内容排查「昵称显示不全」）。
        // 看两点就够：① 单行需要宽度 > 昵称框宽 ⇒ 确实没放下；② 框高只有 20 ⇒ 换行没生效（第二行被裁）
        #if DEBUG
        if !isForMeasurement {
            layoutIfNeeded()
            let nameFont = nameLab.font ?? .mediumFont(15)
            let nameText = nameLab.text ?? ""
            let singleLineWidth = ceil((nameText as NSString).size(withAttributes: [.font: nameFont]).width)
            let brief = post.content.replacingOccurrences(of: "\n", with: " ").prefix(20)
            FZMLog("广场昵称排版 id=\(post.id) 服务端名字=[\(post.authorName)] 显示=[\(nameText)] 单行需宽=\(Int(singleLineWidth)) 昵称框=\(Int(nameLab.bounds.width))x\(Int(nameLab.bounds.height)) 可换行=\(nameLab.numberOfLines == 0) 右侧占位[置顶\(Int(pinnedTagWidth)) 金标\(showsGold ? 14 : 0) 身份\(Int(tagWidth)) 分类\(Int(feedTagWidth)) 时间\(Int(timeLab.bounds.width)) 关注\(Int(followBtn.bounds.width)) 三点\(Int(moreBtn.bounds.width))] 正文前20字=[\(brief)]")
        }
        #endif
    }

    // MARK: - 关注

    /// 是否金标号：帖子里的 `authorGold` 优先，缺字段时查金标目录（`GET /officials` 学到的那份名单）
    /// ⚠️ 目录是异步拉回来的 ⇒ 同一个帖子的结果可能一场会话内由 false 变 true，
    /// 而金标会占掉昵称右侧 14pt（影响昵称是否换行）⇒ `cacheKey` 里必须带上它
    static func showsGold(for post: SquarePost) -> Bool {
        if post.authorGold { return true }
        // 金标只发给公众号；个人帖不查目录
        guard post.authorKind == .official else { return false }
        return SquareOfficialDirectoryStore.item(for: post.authorAddr)?.gold ?? false
    }

    /// 按 `showsFollow` + `SquareFollowStore` 刷关注按钮。
    /// 不显示时把宽度也置 0（不是只 isHidden），否则昵称行右侧会留一块空白、把时间挤掉
    private func applyFollowState() {
        let address = post?.authorAddr ?? ""
        let canFollow = showsFollow && !address.isEmpty && address != LoginUser.shared().address
        // 宽度按当前语言算（中文 = 62pt；英文要容纳 "Following"），不展示时置 0（不是只 isHidden）
        followWidthConstraint?.update(offset: canFollow ? SquareFollowButtonSize.width(font: .mediumFont(13)) : 0)
        followBtn.isHidden = !canFollow
        guard canFollow else { return }
        let isFollowing = SquareFollowStore.isFollowing(address)
        followBtn.setTitle(isFollowing ? L("已关注") : L("关注"), for: .normal)
        followBtn.setTitleColor(isFollowing ? Color_8A97A5 : Color_FFFFFF, for: .normal)
        followBtn.backgroundColor = isFollowing ? Color_F6F7F8 : Color_Theme
    }

    /// 按 `showsReport` + 帖子归属刷举报入口：
    /// 只有「广场列表 + 别人的帖子（有服务端 id）」才显示 —— `isHidden` 的 arrangedSubview 不占宽度
    private func applyReportState() {
        let postId = post?.id ?? 0
        let canReport = showsReport && !(post?.isMine ?? true) && postId > 0
        reportItem.isHidden = !canReport
    }

    /// 点举报：进独立举报页（和详情页右上角走同一个入口）
    @objc private func reportTap() {
        guard let post = post, showsReport, !post.isMine, post.id > 0 else { return }
        guard let host = SquarePostSharePresenter.hostViewController(from: self) else { return }
        SquareReportVC.present(from: host, post: post)
    }

    /// 供外部轻量刷新（详情页从作者页返回时调用，不重建整行、不动图片）
    func refreshFollowState() {
        self.applyFollowState()
        self.applyReportState()
    }

    /// 点关注 / 取关：乐观更新 + 失败回滚 + 404 静默（全在 `SquareFollowStore.toggleFollow` 里）
    @objc private func followTap() {
        guard let post = post, showsFollow, !post.authorAddr.isEmpty else { return }
        SquareFollowStore.toggleFollow(address: post.authorAddr, onUpdate: { [weak self] in
            self?.applyFollowState()
        }, onFailure: { [weak self] failure in
            guard let self = self else { return }
            // 404（接口未上线）/ -20411（不能关注自己）不弹提示
            if SquareFollowStore.isSilentFailure(failure) {
                FZMLog("关注/取关失败(静默) \(failure.rawCode)")
            } else {
                self.showToast(failure.message)
            }
        })
    }

    @objc private func moreTap() {
        guard let post = post else { return }
        onMoreTapped?(post)
    }

    @objc private func shareTap() {
        guard let post = post else { return }
        if let onShareTapped = onShareTapped {
            onShareTapped(post)
            return
        }
        // 没被页面接管时 cell 自己弹系统分享面板（广场流 / 详情页 / 我的帖子共用同一个 cell）
        SquarePostSharePresenter.present(post: post,
                                        from: SquarePostSharePresenter.hostViewController(from: self),
                                        sourceView: shareItem)
    }

    // MARK: - 正文（图文混排）

    /// 重建正文块：文字块（可点 / 可选中）+ 内联图片块
    private func rebuildContent(post: SquarePost, maxWidth: CGFloat, showsFullContent: Bool, interactiveContent: Bool) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard maxWidth > 0 else { return }

        for block in contentBlocks(post: post, maxWidth: maxWidth, showsFullContent: showsFullContent) {
            switch block {
            case .text(let attributed):
                let textView = makeContentTextView(interactive: interactiveContent)
                textView.attributedText = attributed
                contentStack.addArrangedSubview(textView)
                // 高度自己算（与离屏测量同一套），行高才确定
                textView.snp.makeConstraints { (m) in
                    m.height.equalTo(SquareRichText.height(for: attributed, width: maxWidth))
                }
            case .image(let url, let aspect):
                let imageView = makeInlineImageView()
                // 大图浏览要按整条帖子的图片列表翻页，所以记下它在 mediaUrls 里的下标
                imageView.tag = post.mediaUrls.firstIndex(of: url) ?? 0
                contentStack.addArrangedSubview(imageView)
                let height = maxWidth / max(aspect, 0.2)
                imageView.snp.makeConstraints { (m) in
                    m.height.equalTo(height)
                }
                if isForMeasurement {
                    imageView.backgroundColor = Color_F6F7F8
                } else {
                    loadInlineImage(url, into: imageView, maxWidth: maxWidth)
                }
            }
        }
    }

    /// 正文块：列表与详情页**同一套渲染**（Markdown 排版 + 图文混排内联图），
    /// 区别只有「列表按 100 字截断 + 「查看更多」」。
    /// 用户 2026-10-08：广场列表的正文要与帖子详情页一致，纯文本 / Markdown 文档 / 图文混排各种形态都要一致。
    private func contentBlocks(post: SquarePost, maxWidth: CGFloat, showsFullContent: Bool) -> [SquareRichBlock] {
        if showsFullContent {
            return SquareRichText.blocks(of: post.content)
        }
        return SquareRichText.collapsedBlocks(of: post.content, limit: SquareRichText.listCharacterLimit)
    }

    private func makeContentTextView(interactive: Bool) -> UITextView {
        // SquareContentTextView：系统编辑菜单（复制 / 查询 / 翻译…）收起后自动清掉选区与光标，
        // 否则 iOS 会把选中的高亮 + 手柄一直留着，看起来像「光标还在闪」
        let view = SquareContentTextView(frame: .zero, textContainer: nil)
        view.backgroundColor = .clear
        view.isEditable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.dataDetectorTypes = []
        // 高度完全由约束控制，不要用 intrinsicContentSize 干扰测量
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.isUserInteractionEnabled = interactive
        view.isSelectable = interactive
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(contentTap(_:))))
        return view
    }

    private func makeInlineImageView() -> UIImageView {
        let view = UIImageView()
        view.backgroundColor = Color_F6F7F8
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 6
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(inlineImageTap(_:))))
        return view
    }

    /// 加载内联图片：只限宽不裁切（高度已按正文里记的宽高比占好，加载完不会跳）
    private func loadInlineImage(_ raw: String, into imageView: UIImageView, maxWidth: CGFloat) {
        guard let url = SquareMediaURLParser.inlineImageURL(from: raw, pixelWidth: maxWidth * UIScreen.main.scale) else { return }
        let key = url.absoluteString
        if let cached = SquareImageMemoryCache.image(forKey: key) {
            imageView.kf.cancelDownloadTask()
            imageView.image = cached
            return
        }
        imageView.kf.setImage(with: url, placeholder: nil,
                              options: [.transition(.fade(0.08)), .scaleFactor(UIScreen.main.scale), .backgroundDecode]) { result in
            if case .success(let value) = result {
                SquareImageMemoryCache.store(value.image, forKey: key)
            }
        }
    }

    @objc private func contentTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? UITextView else { return }
        guard let tap = SquareRichText.tap(at: gesture.location(in: textView), in: textView) else { return }
        onRichTextTapped?(tap)
    }

    @objc private func inlineImageTap(_ gesture: UITapGestureRecognizer) {
        guard let post = post, let imageView = gesture.view as? UIImageView else { return }
        onTapImage?(post, imageView.tag, imageView)
    }

    // MARK: - 行高计算

    /// 离屏测量用的 cell
    private static var sizingCell: SquarePostCell?
    /// 行高缓存（key 覆盖所有影响高度的字段）
    private static var heightCache = [String: CGFloat]()

    /// 帖子 cell 在指定宽度下的确定高度。
    /// 不依赖 automaticDimension：因为 configure 里会更新九宫格高度约束，
    /// 自测高度存在「测量早于配置」的时序问题，会导致行高偏小、底部点赞栏压到用户名上。
    /// ⚠️ 参数必须与**真实 cell 的 `configure` 完全一致**：`showsFollow` / `showsSelfTag` / `showsMore`
    /// 会改变昵称行右侧占位宽度，进而决定昵称是否换行（换行后行高会变高）。
    static func height(for post: SquarePost, width: CGFloat,
                       showsFullContent: Bool = false,
                       alignsContentWithAvatar: Bool = false,
                       wrapsLongName: Bool = false,
                       showsSelfTag: Bool = false,
                       showsFollow: Bool = false,
                       showsMore: Bool = true) -> CGFloat {
        guard width > 0 else { return 0 }

        let key = cacheKey(for: post, width: width, showsFullContent: showsFullContent,
                           alignsContentWithAvatar: alignsContentWithAvatar, wrapsLongName: wrapsLongName,
                           showsSelfTag: showsSelfTag, showsFollow: showsFollow, showsMore: showsMore)
        if let cached = heightCache[key] {
            return cached
        }

        let cell = sizingCell ?? SquarePostCell.init(style: .default, reuseIdentifier: SquarePostCell.identifier)
        sizingCell = cell
        cell.isForMeasurement = true
        cell.bounds = CGRect(x: 0, y: 0, width: width, height: 300)
        // ⚠️ 必须在 configure **之前**设置（configure 里按它算关注按钮宽度）
        cell.showsFollow = showsFollow
        cell.configure(post, cellWidth: width, showsMore: showsMore, showsSelfTag: showsSelfTag,
                       showsFullContent: showsFullContent, alignsContentWithAvatar: alignsContentWithAvatar,
                       wrapsLongName: wrapsLongName)
        cell.setNeedsLayout()
        cell.layoutIfNeeded()

        let size = cell.contentView.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                                            withHorizontalFittingPriority: .required,
                                                            verticalFittingPriority: .fittingSizeLevel)
        let height = ceil(size.height)

        if heightCache.count > 300 {
            heightCache.removeAll()
        }
        heightCache[key] = height
        return height
    }

    /// ⚠️ key 必须覆盖**所有影响高度的字段**：内容长度、正文是否全文、左边界、图片数、各项计数、状态、
    /// **是否允许多行昵称 + 昵称本身**（详情页昵称换行会使行变高，昵称不同高度就不同），
    /// 以及**决定昵称行右侧占位宽度**的开关（关注按钮 / 身份标签 / 三点 / 金标 / 置顶）——它们会影响昵称要不要换行
    private static func cacheKey(for post: SquarePost, width: CGFloat, showsFullContent: Bool,
                                 alignsContentWithAvatar: Bool, wrapsLongName: Bool,
                                 showsSelfTag: Bool, showsFollow: Bool, showsMore: Bool) -> String {
        // 关注按钮的**实际占位宽度**（不展示时 0）：宽度按当前语言算（`SquareFollowButtonSize`），
        // 换语言后同一个帖子的换行结果会变 ⇒ 只记「有没有关注按钮」不够，会把上一个语言测出的行高复用过来
        let followWidth = showsFollow ? Int(SquareFollowButtonSize.width(font: .mediumFont(13)).rounded()) : 0
        let flags = "\(showsFullContent ? 1 : 0)\(alignsContentWithAvatar ? 1 : 0)\(wrapsLongName ? 1 : 0)\(showsSelfTag ? 1 : 0)[\(followWidth)]\(showsMore ? 1 : 0)\(showsGold(for: post) ? 1 : 0)\(post.pinned ? 1 : 0)"
        // ⚠️ 语言也进 key：身份标签（我 / 官方号 / 公众号）与分类标签（公告 / Notice）的宽度都随语言变，
        // 两者决定标签行会不会换行 ⇒ 影响行高（标签行的 top 也会把正文顶下去）
        // ⚠️ 时间文案（刚刚 / 59分钟前 / 12-31 …）宽度会变，而它是「昵称可用宽度」的右侧预留之一
        // ⇒ 会影响昵称是否换行 ⇒ 影响行高，必须进 key
        let timePart = timeText(of: post)
        return "\(LanguageManager.shared.currentLanguageCode)_\(post.id)_\(Int(width))_\(post.content.count)_\(flags)_\(post.mediaUrls.count)_\(post.likeCount)_\(post.commentCount)_\(post.liked)_\(post.viewCount)_\(post.status.rawValue)_\(post.displayName.utf16.count)|\(post.displayName)_\(timePart)"
    }

    // MARK: - 头像

    private func configureAvatar(for post: SquarePost) {
        // 离屏测量行高时不需要真头像
        guard !isForMeasurement else { return }

        // 身份没变（整表刷新 / 同一条帖子重新配置）就保持当前头像不动，
        // 换人（cell 复用）才重置成占位图 —— 否则每次刷新头像都会「占位图 → 真头像」闪一下。
        // 身份只看**作者地址**：同一作者换头像地址（服务端换 URL）时也不能重置，
        // 那种情况交给 applyAvatar 用 keepCurrentImageWhileLoading 平滑替掉。
        let identity = post.authorAddr.isEmpty ? "srv:\(post.authorAvatar)" : "addr:\(post.authorAddr)"
        if identity != self.avatarIdentity {
            self.avatarIdentity = identity
            self.appliedAvatarURL = nil
            resetAvatarAppearance()
        }

        // 服务端帖子对象自带的作者头像：公众号帖是当前公众号头像，个人帖为空串
        let address = post.authorAddr
        let avatar = post.authorAvatar
        if !avatar.isEmpty, let link = SquareMediaURLParser.displayURL(from: avatar, pixelSide: SquarePostCell.avatarPixelSize.width) {
            applyAvatar(url: link, key: avatar)
            return
        }

        // 没有自带头像（个人帖 / 公众号清空过头像）：按地址解析（本地登录信息 → 通讯录 → 链上）；
        // 回来时校验地址与头像串，避免 cell 复用导致串头像
        SquareAvatarResolver.avatarURL(for: address) { [weak self] url in
            guard let self = self, self.post?.authorAddr == address, self.post?.authorAvatar == avatar else { return }
            guard let url = url,
                  let link = SquareMediaURLParser.displayURL(from: url, pixelSide: SquarePostCell.avatarPixelSize.width) else {
                self.applyPlaceholder(for: post)
                return
            }
            self.applyAvatar(url: link, key: url)
        }
    }

    /// 头像回到默认样子（换作者时调用）
    private func resetAvatarAppearance() {
        avatarView.contentMode = .scaleAspectFill
        avatarView.tintColor = nil
        avatarView.backgroundColor = Color_F6F7F8
        avatarView.image = SquarePostCell.defaultAvatar
    }

    /// 贴上头像：同一个地址已经贴过就直接跳过（避免占位图闪一下）
    private func applyAvatar(url: URL, key: String) {
        guard self.appliedAvatarURL != key || self.avatarView.image == nil else { return }
        self.appliedAvatarURL = key
        avatarView.contentMode = .scaleAspectFill
        avatarView.tintColor = nil
        avatarView.backgroundColor = Color_F6F7F8
        // 已加载过的头像在 SquareAvatarLoader 里会**同步**贴上去，不会先闪一帧占位图
        SquareAvatarLoader.apply(to: avatarView,
                                 url: url,
                                 key: key,
                                 placeholder: SquarePostCell.defaultAvatar,
                                 downsampleSize: SquarePostCell.avatarPixelSize) { [weak self] success in
            guard let self = self, !success, self.appliedAvatarURL == key else { return }
            // 加载失败：清掉记录，下次重新配置时重试（否则会一直停在占位图）
            self.appliedAvatarURL = nil
        }
    }

    /// 列表里九宫格图片会请求的地址（预取用；与 cell 加载时完全一致，命中同一份缓存）
    static func mediaThumbnailURLs(for post: SquarePost, cellWidth: CGFloat) -> [URL] {
        let maxWidth = cellWidth - SquarePostCell.textLeading - SquarePostCell.contentInset
        return SquareImageGridView.thumbnailURLs(for: post.mediaUrls, maxWidth: maxWidth)
    }

    /// 一个头像都取不到时的兜底：公众号帖显示主题色喇叭（保住公众号视觉识别），个人帖回默认占位图
    private func applyPlaceholder(for post: SquarePost) {
        self.appliedAvatarURL = nil
        avatarView.kf.cancelDownloadTask()
        guard post.isOfficialPost else {
            resetAvatarAppearance()
            return
        }
        avatarView.image = UIImage.init(systemName: "megaphone.fill")?.withRenderingMode(.alwaysTemplate)
        avatarView.tintColor = Color_Theme
        avatarView.contentMode = .center
        avatarView.backgroundColor = Color_Theme_Light
    }

    // MARK: - 事件

    @objc private func likeTap() {
        guard let post = self.post else { return }
        onLikeTapped?(post)
    }

    @objc private func commentTap() {
        guard let post = self.post else { return }
        onCommentTapped?(post)
    }

    @objc private func avatarTap() {
        guard let post = self.post else { return }
        onAvatarTapped?(post)
    }

    // MARK: - 时间展示

    static func timeText(of post: SquarePost) -> String {
        let text = SquareDateParser.displayText(from: post.createdDate)
        return text.isEmpty ? post.createdAt : text
    }
}

// MARK: - 底部小按钮（图标 + 数字）

private final class SquareActionItem: UIControl {

    private lazy var iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var titleLab: UILabel = {
        return UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()

    /// 图标与文字之间的间距（只放图标时置 0，不占文字宽度）
    private var titleLeftConstraint: SnapKit.Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(iconView)
        self.addSubview(titleLab)

        iconView.snp.makeConstraints { (m) in
            m.left.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 17, height: 17))
        }
        titleLab.snp.makeConstraints { (m) in
            titleLeftConstraint = m.left.equalTo(iconView.snp.right).offset(4).constraint
            m.right.centerY.equalToSuperview()
        }
    }

    /// 图标+数字较小，适当扩大点击热区
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -8, dy: -8).contains(point)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameter title: 计数字符串；传空串 = 只放图标（分享等），此时不占文字宽度
    func configure(symbol: String, title: String, isActive: Bool) {
        let color = isActive ? Color_Theme : Color_8A97A5
        iconView.image = UIImage.init(systemName: symbol)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = color
        titleLab.text = title.isEmpty ? nil : title
        titleLab.textColor = color
        titleLeftConstraint?.update(offset: title.isEmpty ? 0 : 4)
    }
}

// MARK: - 可选中的正文文本视图

/// 只读、可长按选中复制的正文文本视图。
/// 系统默认行为：点了「复制 / 查询 / 翻译…」任一项后，系统编辑菜单收起，但**选区高亮与手柄会一直留着**
/// （看起来就像光标还在），体验很脏。这里在菜单收起后把选区/焦点清掉。
///
/// ⚠️ 不能一收到「菜单收起」就清：**拖动选择文字 / 拖手柄的过程中系统会临时把菜单收起来**，
/// 那种情况清掉会让选区在滑到一半时消失。所以清理走「延迟 + 双保险」：
/// 1. 手指还按在屏幕上（自己加的长按手势处于 began/changed）→ 不清；
/// 2. 期间菜单又弹出来（`willPresentEditMenuWith`，说明选择还在继续）→ 取消清理。
private final class SquareContentTextView: UITextView, UITextViewDelegate, UIGestureRecognizerDelegate {

    private var legacyMenuObserver: NSObjectProtocol?
    private var pasteboardObserver: NSObjectProtocol?
    /// 手指是否正按在本视图层次上（长按选中 / 拖手柄期间系统会临时收起菜单，这时不能清选区）
    private var isTouchingSelection = false
    /// 待执行的清理任务（拖拽继续或菜单重新弹出时取消）
    private var pendingClearWorkItem: DispatchWorkItem?
    /// 当前挂着「触摸感知」手势的父视图（选中手柄不一定在文本视图自己的子视图里）
    private weak var gestureHostView: UIView?

    /// 长按手势：`cancelsTouchesInView = false` + 允许同时识别，只用来感知「用户正在选字」
    private lazy var selectionTouchGesture: UILongPressGestureRecognizer = makeTouchGesture()
    /// 挂在父视图上的同一个用途的手势
    private lazy var hostTouchGesture: UILongPressGestureRecognizer = makeTouchGesture()

    private func makeTouchGesture() -> UILongPressGestureRecognizer {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(selectionTouchChanged(_:)))
        gesture.minimumPressDuration = 0
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delegate = self
        return gesture
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        addGestureRecognizer(selectionTouchGesture)
        observeMenuDismissIfNeeded()
        observePasteboardIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
        addGestureRecognizer(selectionTouchGesture)
        observeMenuDismissIfNeeded()
        observePasteboardIfNeeded()
    }

    deinit {
        cancelPendingClear()
        if let observer = legacyMenuObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = pasteboardObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 选中手柄通常不在文本视图自己的子视图里，父视图上也挂一个同类手势，保证「拖手柄」也能被感知
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview = superview else {
            gestureHostView?.removeGestureRecognizer(hostTouchGesture)
            gestureHostView = nil
            return
        }
        guard gestureHostView !== superview else { return }
        gestureHostView?.removeGestureRecognizer(hostTouchGesture)
        superview.addGestureRecognizer(hostTouchGesture)
        gestureHostView = superview
    }

    // MARK: - 菜单出现 / 收起

    @available(iOS 16.0, *)
    func textView(_ textView: UITextView, willPresentEditMenuWith animator: UIEditMenuInteractionAnimating) {
        // 菜单又弹出来了 ⇒ 选择还在继续（拖拽结束 / 重新选中），取消待执行的清理
        cancelPendingClear()
    }

    @available(iOS 16.0, *)
    func textView(_ textView: UITextView, willDismissEditMenuWith animator: UIEditMenuInteractionAnimating) {
        // 菜单完全收起后再考虑清理，避免和系统自己的做动画抢
        animator.addCompletion { [weak self] in
            self?.scheduleClearAfterMenuDismiss()
        }
    }

    /// iOS 15 及以下兜底（iOS 16 起系统改成 UIEditMenuInteraction，不再保证发这个通知）
    @available(iOS, deprecated: 16.0, message: "iOS 16+ 走 textView(_:willDismissEditMenuWith:)")
    private func observeLegacyMenuControllerIfNeeded() {
        legacyMenuObserver = NotificationCenter.default.addObserver(
            forName: UIMenuController.didHideMenuNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleClearAfterMenuDismiss()
        }
    }

    private func observeMenuDismissIfNeeded() {
        observeLegacyMenuControllerIfNeeded()
    }

    /// 复制 / 剪切 / 粘贴 一定会写系统粘贴板 ⇒ 用粘贴板变化作为「菜单项已被点了」的可靠信号
    /// （不依赖菜单收起时机，各系统版本都准）
    private func observePasteboardIfNeeded() {
        pasteboardObserver = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleClearAfterMenuDismiss()
        }
    }

    // MARK: - 清理

    /// 收到「菜单收起 / 复制完成」后延迟一小会儿再清：期间手指要是还按着（在拖选择）就放弃；
    /// 延迟也顺便保证系统复制动作（写粘贴板）先完成。
    private func scheduleClearAfterMenuDismiss() {
        cancelPendingClear()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingClearWorkItem = nil
            guard !self.isTouchingSelection else { return }
            self.clearSelection()
        }
        pendingClearWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private func cancelPendingClear() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
    }

    /// 清掉选区/光标：只把 selectedTextRange 置 nil 时 iOS 有时仍留一个插入点，所以再 resign 一次。
    /// 只在「有选区」时清（单纯点一下的空插入点不用管）。
    private func clearSelection() {
        guard let range = selectedTextRange, !range.isEmpty else { return }
        selectedTextRange = nil
        if isFirstResponder {
            _ = resignFirstResponder()
        }
    }

    @objc private func selectionTouchChanged(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            isTouchingSelection = true
            cancelPendingClear()
        case .ended, .cancelled, .failed:
            isTouchingSelection = false
        default:
            break
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    /// 不能抢文本视图自己的选中 / 点击手势
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
