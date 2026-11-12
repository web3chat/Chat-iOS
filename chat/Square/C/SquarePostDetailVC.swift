//
//  SquarePostDetailVC.swift
//  chat
//
//  广场帖子详情：帖子内容 + 评论列表 + 底部评论输入
//  - 帖子/评论的所有写操作只由作者本人发起，服务端会校验权限
//  - -20404（不可见/已删）直接提示并返回
//

import Foundation
import UIKit
import SnapKit
import RxSwift
import IDMPhotoBrowser

/// 输入条上沿的白色遮罩（详情页用）：上段渐隐 → 下段纯白。
/// 目的：列表内容被输入条上沿裁掉时，不要留出一条「硬边的深色细条」（键盘弹/收时输入条扫过内容，
/// 图片等深色内容只剩薄薄一条的时候最像一条「细线」）。
/// 最下面一段是**纯白**的，所以哪怕内容只剩 1~2pt，也是被白盖掉而不是露出深色边。
private final class SquareBarTopFadeView: UIView {

    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false          // 不能挡住列表的点击
        backgroundColor = .clear
        gradient.colors = [Color_FFFFFF.withAlphaComponent(0).cgColor, Color_FFFFFF.cgColor]
        // 0~72% 渐隐，最下面 28%（约 4.5pt）是纯白 —— 内容被切成薄条时彻底盖掉
        gradient.locations = [0, 0.72]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

final class SquarePostDetailVC: UIViewController, ViewControllerProtocol {
    /// 详情内数据变化回传给广场流页（避免整页刷新丢失滚动位置）
    var onPostUpdated: ((SquarePost) -> Void)?
    var onPostDeleted: ((Int) -> Void)?

    private let postId: Int
    private let bag = DisposeBag()

    private var post: SquarePost?
    /// 扁平评论（老逻辑 / 本地待审兜底用）
    private var comments = [SquareComment]()
    /// 服务端楼层（`thread=1`）：主评论 + 前 2 条回复 + 总回复数
    private var threads = [SquareCommentThread]()
    /// 已展开楼层加载到的完整回复（key: 主评论 id）
    private var expandedReplies = [Int: [SquareComment]]()
    /// 正在拉取回复的楼层（防连点）
    private var loadingReplyThreadIds = Set<Int>()
    private var page = 1
    private var hasMore = false
    /// 服务端给的「含回复的可见评论数」（评论标题用）
    private var threadCommentCount = 0
    private var isLoadingComments = false
    /// 点击某条评论后需保持可见的评论 id（回复时避免被键盘挡住）
    private var pendingReplyCommentId: Int?

    /// 正在回复的评论 id（一直保留到这条回复提交成功为止）。
    /// `pendingReplyCommentId` 只用于"把目标滚到可见"，键盘一弹起来就被清掉了，
    /// 所以提交时用它记下「我回复的是哪条」。
    private var replyingToCommentId: Int?
    /// 正在回复的那条评论所属的**一级评论 id**（回复成功后要展开这一楼）
    private var replyingToThreadMainId: Int?
    /// 重新加载评论后要展开的楼层（发完回复用）
    private var pendingExpandThreadId: Int?
    /// 重新加载/展开后要滚到的评论 id（发完回复 / 收件箱点进来用）
    private var pendingScrollCommentId: Int?
    /// 收件箱点进来时要定位的评论（可能是回复）
    private var focusCommentId: Int?
    /// 定位目标所属的一级评论 id（服务端没给时为 0）
    private var focusParentId: Int?
    /// 最近一次「点了评论里的链接」的时间：同一手势可能再走一遍 `didSelectRowAt`，用它把「@ 回复」挡掉
    private var commentLinkTappedAt: Date?
    /// 上一条对应的评论 id（只挡这一条，不影响其它评论正常 @ 回复）
    private var commentLinkTappedCommentId: Int?
    /// 已展开全部回复的楼层（key: 主评论 id）
    private var expandedThreadIds = Set<Int>()

    /// 评论区展示行：主评论 + 其下的回复行（超过 2 条先折叠）
    private struct CommentRow {
        var comment: SquareComment
        var isReply: Bool
        var threadMainId: Int
        var replyCount: Int
        var isExpanded: Bool
    }

    private var commentRows = [CommentRow]()
    /// 评论是否已至少加载成功一次（用于空态展示判断）
    private var hasLoadedComments = false
    /// 评论第一页等待是否已经结束（成功 / 失败 / 超时都算）：
    /// 详情页整页显示的判断用它 —— 帖子 + 评论都到位（或等超了）才收起骨架，
    /// 否则会先看到「评论 N」下面空一片。
    private var commentsWaitFinished = false

    // MARK: - 页面加载状态
    //
    // 详情是「一次拉帖子 + 再拉评论」，原来页面一进去表格/输入条就可见，
    // 会先看到半空页面（评论区/输入条）再慢慢填内容。
    // 这里改成：**帖子内容回来之前不显示页面内容**，失败则只显示「重新加载」。
    private enum DetailLoadState {
        case loading   // 首次加载中
        case loaded    // 已就绪
        case failed    // 加载失败（展示重试入口）
    }
    private var detailState: DetailLoadState = .loading

    /// 加载失败时的占位视图：文案 + 「重新加载」按钮（点一下重新拉帖子内容）
    private lazy var retryView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.isHidden = true

        let label = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("内容加载失败，请检查网络后重试"))
        label.numberOfLines = 0
        view.addSubview(label)
        label.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview().inset(30)
            m.bottom.equalTo(view.snp.centerY).offset(-16)
        }

        let button = UIButton(type: .custom)
        button.setTitle(L("重新加载"), for: .normal)
        button.setTitleColor(Color_Theme, for: .normal)
        button.titleLabel?.font = .mediumFont(15)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = Color_Theme.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 24, bottom: 9, right: 24)
        button.addTarget(self, action: #selector(retryLoadDetail), for: .touchUpInside)
        view.addSubview(button)
        button.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(view.snp.centerY).offset(10)
        }
        return view
    }()

    @objc private func retryLoadDetail() {
        self.loadDetail()
    }

    /// 首次加载时的骨架屏（一条帖子 + 评论标题 + 三条评论），替代转圈 HUD
    private lazy var skeletonView: SquarePostDetailSkeletonView = {
        let view = SquarePostDetailSkeletonView()
        view.isHidden = true
        return view
    }()

    /// 按加载状态显示/隐藏页面内容与重试视图
    private func applyDetailState() {
        // 帖子拿到 + 评论第一页到位（或等超了）才整页显示，避免先看到半空的评论区
        let showContent = (detailState == .loaded && commentsWaitFinished)
        self.tableView.isHidden = !showContent
        self.commentBar.isHidden = !showContent
        if fadesContentAboveInputBar {
            self.barTopFadeView.isHidden = !showContent
        }
        self.retryView.isHidden = (detailState != .failed)
        // 首次加载：骨架顶住（上面是帖子、下面带评论），内容齐了才整页显示
        let showSkeleton = (detailState == .loading) || (detailState == .loaded && !commentsWaitFinished)
        self.skeletonView.isHidden = !showSkeleton
        if showSkeleton {
            self.skeletonView.startAnimating()
        } else {
            self.skeletonView.stopAnimating()
        }
    }

    // MARK: - 初始化

    init(postId: Int, focusCommentId: Int? = nil, focusParentId: Int? = nil) {
        self.postId = postId
        self.focusCommentId = focusCommentId
        self.focusParentId = focusParentId
        self.pendingScrollCommentId = focusCommentId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 子视图

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = Color_FFFFFF
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        // 不需要横向滚动条（会显示成列表底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        // 拖动列表也能收起键盘（不用非得点空白处）
        view.keyboardDismissMode = .onDrag
        view.estimatedRowHeight = 200
        view.estimatedSectionHeaderHeight = 0
        view.estimatedSectionFooterHeight = 0
        view.rowHeight = UITableView.automaticDimension
        view.dataSource = self
        view.delegate = self
        view.register(SquarePostCell.self, forCellReuseIdentifier: SquarePostCell.identifier)
        view.register(SquareCommentCell.self, forCellReuseIdentifier: SquareCommentCell.identifier)
        return view
    }()

    /// 页面底部常驻的展示条：永远待在页面里，不挂键盘、不参与编辑，点击转发焦点给键盘输入条
    private lazy var commentBar: SquareCommentInputBar = {
        let view = SquareCommentInputBar()
        view.isDisplayOnly = true
        view.onRequestFocus = { [weak self] in
            self?.keyboardCommentBar.becomeInputFirstResponder()
        }
        // 页面展示条上的「发送」：直接用键盘输入条里的内容发（滑动/点空白收起键盘后也能发）
        view.onSendRequested = { [weak self] in
            guard let self = self, !self.keyboardCommentBar.isSending else { return }
            let text = self.keyboardCommentBar.trimmedText
            guard !text.isEmpty else { return }
            self.sendComment(text)
        }
        return view
    }()

    /// 键盘专用输入条：不进页面视图树，只挂在键盘上（accessoryView）；键盘收起时随键盘一起消失。
    /// 页面上的「输入条」其实是 commentBar（展示条），两条互不干扰 —— 不再需要把输入条抢回页面。
    private lazy var keyboardCommentBar: SquareCommentInputBar = {
        let view = SquareCommentInputBar()
        view.prepareForKeyboardUse()
        view.onSend = { [weak self] text in
            self?.sendComment(text)
        }
        view.onKeyboardShown = { [weak self] keyboardHeight in
            guard let self = self else { return }
            self.keyboardHeight = keyboardHeight
            // 键盘落位后把被挡住的评论露出来
            self.scrollToPendingReplyIfNeeded()
        }
        view.onTextChanged = { [weak self] text in
            guard let self = self else { return }
            self.commentBar.display(text: text)
            self.updateBarAnchorHeight()
        }
        return view
    }()

    /// 输入条上方的白色渐隐遮罩：贴到输入条顶边的内容会「渐隐」过渡。
    ///
    /// 为什么需要：帖子里的**深色配图被输入条裁掉**时，会在输入条顶边留下一段**硬边的深色细条**；
    /// 键盘弹/收时输入条会扫过内容，图片只剩薄薄一条时最像「一条细线」，而且只存在于动画的那一两帧里
    /// （截图、正常速度播录屏都抓不到）。关键是：输入条自己的顶线是浅灰 `#E6EAEE`，
    /// 深色细条紧贴在它上方，反差很显眼。
    /// 有了这层渐变，被裁的地方是渐隐到白色的，就不会出现硬边。
    /// ⚠️ 不想要这个效果：把 `fadesContentAboveInputBar` 改成 false 即可。
    private let fadesContentAboveInputBar = true
    private static let barTopFadeHeight: CGFloat = 16

    private lazy var barTopFadeView: SquareBarTopFadeView = {
        return SquareBarTopFadeView()
    }()

    /// 输入条常驻占位条：键盘弹起时输入条被系统挂到键盘上（inputAccessoryView），
    /// 由它替输入条占住页面底部的位置 —— 表格底边和渐隐遮罩都贴在它上面，布局稳定不随键盘动。
    private lazy var barAnchor: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        return view
    }()
    private var barAnchorHeightConstraint: SnapKit.Constraint?
    /// 键盘高度（弹起时由输入条回调同步，用于评论滚动的可见区修正）
    private var keyboardHeight: CGFloat = 0

    // MARK: - 唤起输入

    /// 唤起评论输入（点帖子「评论」/ 点评论回复都走这里）
    private func focusCommentInput(mention name: String? = nil) {
        if let name = name, !name.isEmpty {
            keyboardCommentBar.appendMention(name: name)
        } else {
            // 直接点「评论」按钮发新评论（不是回复）⇒ 不能沿用上一次的回复目标
            self.replyingToCommentId = nil
            self.replyingToThreadMainId = nil
            keyboardCommentBar.becomeInputFirstResponder()
        }
        // 键盘已经弹着的时候再点另一条评论，「键盘高度没变」不会触发 onKeyboardShown，
        // 这里补一次滚动
        guard keyboardCommentBar.isKeyboardVisible else { return }
        DispatchQueue.main.async { [weak self] in
            self?.scrollToPendingReplyIfNeeded()
        }
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_FFFFFF
        self.navigationItem.title = L("帖子详情")

        // 输入条：只放进视图树，不建外部约束（frame 在 `viewDidLayoutSubviews` 里对齐占位条）。
        // 键盘弹起时它会被系统摘走挂到键盘上（inputAccessoryView），键盘完全收起后再放回来。
        self.view.addSubview(commentBar)

        // 底部占位条：输入条挂到键盘上期间，由它占住页面底部。
        // 表格底边/渐隐遮罩贴在它上面，和键盘完全无关，布局不再跟着键盘动。
        self.view.addSubview(barAnchor)
        barAnchor.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            barAnchorHeightConstraint = m.height.equalTo(SquareCommentInputBar.restHeight).constraint
        }

        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            m.bottom.equalTo(barAnchor.snp.top)
        }

        // 首次加载的骨架（和表格同一区域，盖在表格之上）
        self.view.addSubview(skeletonView)
        skeletonView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            m.bottom.equalTo(barAnchor.snp.top)
        }

        // 加载失败的重试视图（盖在表格上，和表格同一区域）
        self.view.addSubview(retryView)
        retryView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            m.bottom.equalTo(barAnchor.snp.top)
        }

        // 页面展示条盖在占位条之上（`bindTo` 里 addSubview 会把 z 序挪到最上层）。
        // 展示条永远待在页面里、不动；键盘上的那条是 `keyboardCommentBar`（另一实例），
        // 所以不再有「把输入条从键盘上抢回来」这回事。
        commentBar.bindTo(view: self.view)
        // 键盘专用输入条（触发创建；透明、屏幕外地挂在页面里，只在键盘上出现）
        _ = keyboardCommentBar
        keyboardCommentBar.restHostView = self.view
        self.view.addSubview(keyboardCommentBar)
        // 详情加载完成后才知道能否评论，这里先按可评论展示（发送按钮由内容是否为空控制）
        commentBar.setCommentsEnabled(true)

        // 输入条上沿的白色渐隐层（加在最后 = 盖在表格和输入条之上）：
        // 内容贴到占位条顶边时渐隐，避免深色配图被裁出硬边细条
        if fadesContentAboveInputBar {
            self.view.addSubview(barTopFadeView)
            barTopFadeView.snp.makeConstraints { (m) in
                m.left.right.equalToSuperview()
                m.bottom.equalTo(barAnchor.snp.top)
                m.height.equalTo(SquarePostDetailVC.barTopFadeHeight)
            }
        }

        // 点空白处收起键盘（cancelsTouchesInView = false，不影响点评论行回复）
        let blankTap = UITapGestureRecognizer.init(target: self, action: #selector(blankTap(_:)))
        blankTap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(blankTap)

        // 昵称行右侧的关注按钮：名单没拉过先拉一次（拉不到就保持「关注」，不弹错），
        // 之后状态变化（自己点 / 别的页面改了同一地址）都走通知刷按钮
        NotificationCenter.default.addObserver(self, selector: #selector(followStateChanged), name: .squareFollowDidChange, object: nil)
        // 语言切换：帖子 + 评论里的文案（「举报 / 分享 / 作者」等）都要重刷
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: LanguageManager.LanguageChangedNotification, object: nil)
        SquareFollowStore.refresh()

        loadDetail()
    }

    /// 页面展示条底边对齐屏幕底（占位条同底）；多行输入时它比占位条高，也要底边对齐。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if commentBar.superview === self.view {
            commentBar.alignToBottom(of: self.view)
        }
    }

    /// 展示条高度变化时同步占位条高度（表格底边贴占位条，列表自动让位）
    private func updateBarAnchorHeight() {
        barAnchorHeightConstraint?.update(offset: commentBar.preferredHeight)
        self.view.setNeedsLayout()
    }

    /// 点空白处（帖子区域 / 列表空白）收起评论键盘；点评论行是「回复这个人」，不打扰
    @objc private func blankTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: point), indexPath.section == 1 {
            return
        }
        // 点在按钮等控件上（点赞 / 评论 / 更多 / 展开）交给控件自己处理，
        // 否则手势的“收键盘”会和控件自己的“弹键盘”互相打架
        if self.isControlTap(at: point) {
            return
        }
        // ⚠️ 不能写 `self.view.endEditing(true)`：键盘弹起时输入框已经被系统挂到键盘上了，
        // 不在本页的视图树里，`endEditing` 找不到它。直接让键盘输入条自己去 resign。
        keyboardCommentBar.resignInputFirstResponder()
    }

    /// 命中测试：沿视图层级向上找，判断点的是不是 UIControl（按钮 / 控件）
    private func isControlTap(at point: CGPoint) -> Bool {
        var hit = tableView.hitTest(point, with: nil)
        while let view = hit, view !== tableView {
            if view is UIControl { return true }
            hit = view.superview
        }
        return false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏白底、去掉滚动时出现的底部细线
        applySquareNavBarStyle()
        // 从作者页等地方回来时补刷一次（cell 可能刚被重建，通知没赶上）
        refreshPostFollowState()
    }

    /// 关注状态变化（自己点了关注按钮 / 别的页面改了同一地址）
    /// 语言切换：整表重刷一次文案（帖子 + 评论里的「举报 / 分享 / 作者」等都是 configure 时取的 L()）
    @objc private func languageChanged() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    @objc private func followStateChanged() {
        self.refreshPostFollowState()
    }

    /// 只刷帖子行（section 0）里那个关注按钮，**不重建整行** —— 重建会让头像/图片重新贴一遍
    private func refreshPostFollowState() {
        guard self.isViewLoaded, self.tableView.numberOfSections > 0,
              self.tableView.numberOfRows(inSection: 0) > 0 else { return }
        let indexPath = IndexPath.init(row: 0, section: 0)
        (self.tableView.cellForRow(at: indexPath) as? SquarePostCell)?.refreshFollowState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开页面（返回上一页 / 继续 push 别的页）时如果还在编辑，先取消编辑、收起键盘
        keyboardCommentBar.resignInputFirstResponder()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // 安全区变化（横竖屏 / 机型切换）时占位条高度对齐；输入条 frame 由 viewDidLayoutSubviews 跟着对齐
        barAnchorHeightConstraint?.update(offset: SquareCommentInputBar.restHeight)
        self.view.setNeedsLayout()
    }

    // MARK: - 键盘
    //
    // 两条输入条分工：
    // - 页面底部是「展示条」（commentBar）：永远待在页面里，不参与编辑，点击把焦点转给键盘输入条；
    // - 键盘上是「输入条」（keyboardCommentBar）：作为 textView 的 inputAccessoryView 挂在键盘顶上，
    //   与键盘同一个动画（像素级同步，细线不会出现），键盘收起时随键盘一起消失，无需回位。
    // 表格底边固定在底部占位条上；评论滚动时用 `keyboardHeight` 修正可见区。

    /// 回复评论时，把目标评论滚到键盘上方可见位置
    private func scrollToPendingReplyIfNeeded() {
        guard let commentId = pendingReplyCommentId,
              let row = commentRows.firstIndex(where: { $0.comment.id == commentId }) else { return }
        pendingReplyCommentId = nil
        self.tableView.layoutIfNeeded()
        self.scrollToCommentRow(row, animated: true)
    }

    /// 滚到某条评论：**只在它被输入条/键盘挡住时滚，且只滚到刚好看得见**。
    /// 之前用的是 `scrollToRow(at: .middle)`：不管这一行本来就看得见，也会强行把它滚到屏幕中间，
    /// 于是「一点评论回复 / 一发评论，键盘一弹起来整个列表就被顶一下」—— 看起来就像
    /// 「评论标题下面那条细线被顶上去」。
    private func scrollToCommentRow(_ row: Int, animated: Bool) {
        guard row >= 0, row < commentRows.count else { return }
        self.tableView.layoutIfNeeded()
        let indexPath = IndexPath.init(row: row, section: 1)
        let target = self.tableView.rectForRow(at: indexPath)
        guard target.height > 0 else { return }
        // 键盘弹起时表格不变矮（底边固定在占位条上），被键盘盖住的部分不算可见区
        let keyboardCover = max(0, keyboardHeight - SquareCommentInputBar.restHeight)
        let visible = CGRect(x: 0, y: self.tableView.contentOffset.y,
                             width: self.tableView.bounds.width,
                             height: self.tableView.bounds.height - keyboardCover)
        // 已经完整可见（上下各留 8pt 余量）就不动，避免无意义地跳一下
        if visible.insetBy(dx: 0, dy: -8).contains(target) { return }
        self.tableView.scrollRectToVisible(target.insetBy(dx: 0, dy: -10), animated: animated)
    }

    // MARK: - 评论楼层

    /// 根据服务端楼层重建展示行（主评论 + 折叠后的回复）。
    /// 服务端没给 `threads`（老数据/异常）时退回原来的扁平列表 + 本地 @ 推断。
    private func rebuildCommentRows() {
        var rows = [CommentRow]()

        if !threads.isEmpty {
            for thread in threads {
                let mainId = thread.comment.id
                let expanded = expandedThreadIds.contains(mainId)
                let loadedReplies = expandedReplies[mainId] ?? thread.replies
                let totalReplies = max(thread.replyCount, loadedReplies.count)
                rows.append(CommentRow(comment: thread.comment,
                                       isReply: false,
                                       threadMainId: mainId,
                                       replyCount: totalReplies,
                                       isExpanded: expanded))

                // 未展开只展示前 2 条（服务端 `replies` 就是“更早的 2 条”）
                let visibleReplies = expanded
                    ? loadedReplies
                    : Array(loadedReplies.prefix(SquareCommentCell.maxVisibleReplies))

                for reply in visibleReplies {
                    rows.append(CommentRow(comment: reply, isReply: true, threadMainId: mainId, replyCount: 0, isExpanded: false))
                }
            }
        } else {
            let legacyThreads = SquareCommentThreadBuilder.build(
                comments,
                localReplyTargets: SquareLocalReplyTargetStore.targets(for: postId))
            for thread in legacyThreads {
                let mainId = thread.comment.id
                let expanded = expandedThreadIds.contains(mainId)
                rows.append(CommentRow(comment: thread.comment,
                                       isReply: false,
                                       threadMainId: mainId,
                                       replyCount: thread.replies.count,
                                       isExpanded: expanded))
                let visibleReplies = (thread.replies.count > SquareCommentCell.maxVisibleReplies && !expanded)
                    ? Array(thread.replies.prefix(SquareCommentCell.maxVisibleReplies))
                    : thread.replies
                for reply in visibleReplies {
                    rows.append(CommentRow(comment: reply, isReply: true, threadMainId: mainId, replyCount: 0, isExpanded: false))
                }
            }
        }

        commentRows = rows
    }

    private func toggleThread(_ mainId: Int) {
        if expandedThreadIds.contains(mainId) {
            expandedThreadIds.remove(mainId)
            rebuildCommentRows()
            self.tableView.reloadSections(IndexSet.init(integer: 1), with: .automatic)
        } else {
            expandThread(mainId)
        }
    }

    /// 展开某一楼：先把完整回复拉全（分页最多 10 页），再刷新这一楼
    private func expandThread(_ mainId: Int, completion: (() -> Void)? = nil) {
        guard mainId > 0 else {
            completion?()
            return
        }
        expandedThreadIds.insert(mainId)
        if let cached = expandedReplies[mainId] {
            rebuildCommentRows()
            if isViewLoaded { tableView.reloadSections(IndexSet.init(integer: 1), with: .automatic) }
            completion?()
            return
        }
        guard !loadingReplyThreadIds.contains(mainId) else { return }
        loadingReplyThreadIds.insert(mainId)
        loadAllReplies(postId: postId, commentId: mainId, page: 1, accumulated: []) { [weak self] replies in
            guard let self = self else { return }
            self.loadingReplyThreadIds.remove(mainId)
            self.expandedReplies[mainId] = replies
            if let index = self.threads.firstIndex(where: { $0.comment.id == mainId }) {
                self.threads[index].replyCount = max(self.threads[index].replyCount, replies.count)
            }
            self.rebuildCommentRows()
            if self.isViewLoaded {
                self.tableView.reloadSections(IndexSet.init(integer: 1), with: .automatic)
            }
            completion?()
        }
    }

    /// 递归拉完某楼的全部回复（`pageSize=100`，最多 10 页）
    private func loadAllReplies(postId: Int,
                                commentId: Int,
                                page: Int,
                                accumulated: [SquareComment],
                                completion: @escaping ([SquareComment]) -> Void) {
        SquareService.shared.commentReplies(postId: postId, commentId: commentId, page: page, pageSize: 100, success: { [weak self] replyPage in
            let merged = accumulated + replyPage.list
            if replyPage.hasMore, page < 10 {
                self?.loadAllReplies(postId: postId, commentId: commentId, page: page + 1,
                                     accumulated: merged, completion: completion)
            } else {
                completion(merged)
            }
        }, failure: { [weak self] failure in
            self?.showToast(with: failure.message)
            completion(accumulated)
        })
    }

    /// 滚到指定评论（找到才滚；找不到返回 false）
    @discardableResult
    private func scrollToCommentIfPossible(_ commentId: Int) -> Bool {
        guard let row = commentRows.firstIndex(where: { $0.comment.id == commentId }) else { return false }
        DispatchQueue.main.async { [weak self] in
            self?.scrollToCommentRow(row, animated: true)
        }
        return true
    }

    /// 收件箱点进来：定位到目标评论；目标回复没加载时先展开它所属的一楼
    private func handleFocusIfNeeded() {
        guard let targetId = pendingScrollCommentId else { return }
        if scrollToCommentIfPossible(targetId) {
            pendingScrollCommentId = nil
            return
        }
        guard let parent = focusParentId, parent > 0, parent != targetId else { return }
        expandThread(parent) { [weak self] in
            guard let self = self else { return }
            if self.scrollToCommentIfPossible(targetId) {
                self.pendingScrollCommentId = nil
            }
        }
    }

    // MARK: - 数据

    /// 本人公众号资料预热：评论头像 / 「公众号」标记要用到它（`SquareMyOfficialStore` 是本地缓存）。
    /// 只有「没缓存」或「缓存里没头像」时才拉一次，拿到后刷新一下评论列表，避免缓存在别的页面没被写过时
    /// 一直显示成个人头像。
    private func warmMyOfficialProfileIfNeeded() {
        let address = LoginUser.shared().address
        guard !address.isEmpty else { return }
        let cached = SquareMyOfficialStore.profile(for: address)
        guard cached == nil || (cached?.avatar.isEmpty ?? true) else { return }
        SquareService.shared.officialMe(success: { [weak self] me in
            guard let self = self, LoginUser.shared().address == address else { return }
            let profile = SquareMyOfficialProfile(state: me.state,
                                                  name: me.official?.name ?? "",
                                                  avatar: me.official?.avatar ?? "",
                                                  intro: me.official?.intro ?? "")
            SquareMyOfficialStore.save(profile, for: address)
            // 资料刚到：评论里的公众号头像 / 标签可能变了，刷一下评论区
            guard self.isViewLoaded, self.tableView.numberOfSections > 1 else { return }
            self.tableView.reloadSections(IndexSet.init(integer: 1), with: .none)
        }, failure: { _ in })
    }

    private func loadDetail() {
        warmMyOfficialProfileIfNeeded()
        // 重新加载（进入 / 重试）：评论要重新等一次，否则会先显示半空的评论区
        commentsWaitFinished = false
        hasLoadedComments = false
        self.detailState = .loading
        self.applyDetailState()// 内容回来之前先显示骨架
        SquareService.shared.postDetail(id: postId, success: { [weak self] post in
            guard let self = self else { return }
            self.hideProgress()
            self.post = post
            self.updateCommentBar()
            self.updateRightBarButton()
            self.tableView.reloadData()
            self.detailState = .loaded
            self.applyDetailState()// 帖子和评论都到位后整页显示（评论紧接着就填进来）
            self.onPostUpdated?(post)
            self.loadComments(reset: true)
            // 网络慢时不能把用户吊在骨架上：3 秒评论还没回来就先显示帖子
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, !self.commentsWaitFinished else { return }
                self.commentsWaitFinished = true
                self.applyDetailState()
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.hideProgress()
            if failure.isNotFound {
                // 帖子被删/不可见：不用给重试入口，提示后退
                self.showToast(with: failure.message)
                self.popBack()
                return
            }
            // 其它失败（网络等）：整页换成「重新加载」
            self.detailState = .failed
            self.applyDetailState()
        })
    }

    /// 加载评论楼层
    /// - Parameter expandThreadId: 加载完成后要展开的楼层（发完回复用）
    private func loadComments(reset: Bool,
                              scrollToCommentId: Int? = nil,
                              expandThreadId: Int? = nil) {
        guard !isLoadingComments else { return }
        isLoadingComments = true
        let targetPage = reset ? 1 : page + 1
        if let expandThreadId = expandThreadId {
            pendingExpandThreadId = expandThreadId
        }
        if let scrollToCommentId = scrollToCommentId {
            pendingScrollCommentId = scrollToCommentId
        }

        SquareService.shared.commentThreads(postId: postId, page: targetPage, success: { [weak self] pageData in
            guard let self = self else { return }
            self.isLoadingComments = false
            self.page = targetPage
            self.hasMore = pageData.hasMore
            self.threadCommentCount = pageData.commentCount
            if reset {
                self.threads = pageData.threads
                self.expandedReplies.removeAll()
                self.expandedThreadIds.removeAll()
                self.comments = pageData.threads.flatMap { [$0.comment] + $0.replies }
            } else {
                self.threads.append(contentsOf: pageData.threads)
                self.comments.append(contentsOf: pageData.threads.flatMap { [$0.comment] + $0.replies })
            }
            self.hasLoadedComments = true
            self.commentsWaitFinished = true
            self.rebuildCommentRows()
            self.tableView.reloadData()
            self.applyDetailState()

            // 发完回复：展开目标楼层（完整回复拉全后再滚到新评论）
            if let expandId = self.pendingExpandThreadId {
                self.pendingExpandThreadId = nil
                self.expandThread(expandId) { [weak self] in
                    guard let self = self, let target = self.pendingScrollCommentId else { return }
                    if self.scrollToCommentIfPossible(target) {
                        self.pendingScrollCommentId = nil
                    }
                }
            } else if let target = self.pendingScrollCommentId {
                if self.scrollToCommentIfPossible(target) {
                    self.pendingScrollCommentId = nil
                } else {
                    self.handleFocusIfNeeded()
                }
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isLoadingComments = false
            // 评论没拉到也算「等完了」：先把帖子放出来（不然骨架会一直挂着）
            self.commentsWaitFinished = true
            self.applyDetailState()
            // 帖子不可见时评论接口同样失败，此处不重复打扰
            if !failure.isNotFound {
                self.showToast(with: failure.message)
            }
        })
    }

    private func updateCommentBar() {
        guard let post = post else { return }
        commentBar.setCommentsEnabled(post.commentsEnabled)
        keyboardCommentBar.setCommentsEnabled(post.commentsEnabled)
    }

    /// 右上角按钮的状态（去重：同一状态不重复设置导航栏 item）
    private enum RightBarButtonState {
        case none
        /// 本人的帖：三个点（删帖 / 关评论）
        case mine
        /// 别人的帖：举报
        case report
    }
    /// 当前右上角按钮所对应的状态（nil = 还没设置过）
    private var rightBarButtonState: RightBarButtonState?

    /// 能否举报：帖子已加载 + 不是自己的帖 + 已登录 + 广场可读
    /// （广场被关闭时举报接口会回 -20413，那时不给入口）
    private var canReport: Bool {
        guard let post = post else { return false }
        return post.id > 0 && !post.isMine && LoginUser.shared().isLogin && SquareStatusStore.canRead
    }

    /// 右上角按钮：**只在状态真正变化时才设置导航栏 item**。
    ///
    /// ⚠️ 不要每次数据回调都重设导航栏 item：侧滑返回被取消时 UIKit 会把导航栏内容视图的
    /// 左边距短暂清成 0，此刻重新设置 item 会让导航栏整体重排，左侧返回按钮被按
    /// 「左边距 0 + 间距常量(-8)」摆到 -8pt、被屏幕左边缘裁掉且不会自愈。
    /// （其它页面不会在页面出现后重设 item，所以只有帖子详情会左移。）
    private func updateRightBarButton() {
        let state: RightBarButtonState
        if post?.isMine ?? false {
            state = .mine
        } else if canReport {
            state = .report
        } else {
            state = .none
        }
        guard rightBarButtonState != state else { return }
        rightBarButtonState = state

        guard state != .none else {
            self.navigationItem.rightBarButtonItem = nil
            return
        }
        let btn = UIButton.init(type: .custom)
        let isMine = (state == .mine)
        if isMine {
            btn.setImage(UIImage.init(systemName: "ellipsis")?.withRenderingMode(.alwaysTemplate), for: .normal)
            btn.tintColor = Color_24374E
            btn.frame = CGRect.init(x: 0, y: 0, width: 30, height: 30)
        } else {
            // 举报：直接用**文字**（原来那个 `exclamationmark.bubble` 图标看不出是举报）
            btn.setTitle(L("举报"), for: .normal)
            btn.setTitleColor(Color_Theme, for: .normal)
            btn.titleLabel?.font = .mediumFont(15)
            btn.frame = CGRect.init(x: 0, y: 0, width: 52, height: 30)
            btn.accessibilityLabel = L("举报")
        }
        btn.addTarget(self, action: isMine ? #selector(moreTap) : #selector(reportTap), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: btn)
    }

    // MARK: - 交互

    private func toggleLike(_ post: SquarePost) {
        guard self.post != nil else { return }

        // 乐观更新，失败再回滚
        let previousLiked = post.liked
        let previousCount = post.likeCount
        self.post?.liked = !previousLiked
        self.post?.likeCount = max(previousCount + (previousLiked ? -1 : 1), 0)
        updatePostRow()

        SquareService.shared.toggleLike(post: post, success: { [weak self] result in
            guard let self = self else { return }
            self.post?.liked = result.liked
            self.post?.likeCount = result.likeCount
            self.updatePostRow()
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.post?.liked = previousLiked
            self.post?.likeCount = previousCount
            self.updatePostRow()
            self.showToast(with: failure.message)
        })
    }

    private func updatePostRow() {
        guard let post = self.post else { return }
        self.tableView.reloadSections(IndexSet.init(integer: 0), with: .none)
        self.onPostUpdated?(post)
    }
    private func sendComment(_ content: String) {
        keyboardCommentBar.isSending = true
        let replyToId = replyingToCommentId
        let replyThreadMainId = replyingToThreadMainId
        SquareService.shared.createComment(postId: postId, content: content, replyToId: replyToId, success: { [weak self] outcome in
            guard let self = self else { return }
            self.keyboardCommentBar.isSending = false
            switch outcome {
            case .published(let comment):
                // 服务端已经落库 parentId / replyToId；本地记录只给「老数据 + 文本推断」兜底
                if let parent = replyToId, comment.id > 0 {
                    SquareLocalReplyTargetStore.save(replyId: comment.id, parentId: parent, postId: self.postId)
                }
                self.replyingToCommentId = nil
                self.replyingToThreadMainId = nil
                self.clearCommentInput()
                // 注意：不能写 self.post?.commentCount += 1，同时对可选属性读写会触发 exclusivity 报错
                if var post = self.post {
                    post.commentCount += 1
                    self.post = post
                }
                // 以服务端返回的第一页为准，避免本地顺序与服务端不一致；
                // 回复时展开被回复的那一楼并滚到新回复
                self.loadComments(reset: true,
                                  scrollToCommentId: comment.id > 0 ? comment.id : nil,
                                  expandThreadId: replyThreadMainId)
                self.tableView.reloadSections(IndexSet.init(integer: 0), with: .none)
            case .pendingReview:
                // 内容已入库，等运营台审核后才可见：本地先插一条「审核中」的评论，避免用户以为没发出去
                self.replyingToCommentId = nil
                self.replyingToThreadMainId = nil
                self.clearCommentInput()
                let pending = SquareComment.pendingComment(postId: self.postId, content: content)
                self.comments.insert(pending, at: 0)
                if let mainId = replyThreadMainId, mainId > 0,
                   let index = self.threads.firstIndex(where: { $0.comment.id == mainId }) {
                    var replies = self.expandedReplies[mainId] ?? self.threads[index].replies
                    replies.append(pending)
                    self.expandedReplies[mainId] = replies
                    self.expandedThreadIds.insert(mainId)
                    self.threads[index].replyCount += 1
                } else {
                    self.threads.insert(SquareCommentThread(comment: pending, replies: [], replyCount: 0), at: 0)
                }
                self.rebuildCommentRows()
                self.tableView.reloadSections(IndexSet.init(integer: 1), with: .none)
                if let row = self.commentRows.firstIndex(where: { $0.comment.isPendingReview }) {
                    self.scrollToCommentRow(row, animated: true)
                }
                self.showToast(with: L("已提交，等待审核"))
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.keyboardCommentBar.isSending = false
            self.showToast(with: failure.message)
            if failure.code == .commentsClosed {
                self.keyboardCommentBar.setCommentsEnabled(false)
                self.commentBar.setCommentsEnabled(false)
            }
        })
    }

    /// 发送成功后清空两条输入条（键盘输入条 + 页面展示条同步），
    /// 并把键盘与键盘上的输入条一起收掉（发完不该还占着半屏）
    private func clearCommentInput() {
        keyboardCommentBar.clear()
        commentBar.display(text: nil)
        updateBarAnchorHeight()
        keyboardCommentBar.resignInputFirstResponder()
    }

    private func deleteComment(_ comment: SquareComment) {
        // 本地待审评论（服务端待审不返回 id）没有服务端对象，只能本地移除
        guard comment.id > 0 else {
            removePendingComment(comment)
            return
        }
        SquareService.shared.deleteComment(id: comment.id, success: { [weak self] deletedId in
            guard let self = self else { return }
            self.comments.removeAll { $0.id == deletedId }
            self.threads.removeAll { $0.comment.id == deletedId }
            for index in self.threads.indices {
                self.threads[index].replies.removeAll { $0.id == deletedId }
                let mainId = self.threads[index].comment.id
                if let expanded = self.expandedReplies[mainId] {
                    self.expandedReplies[mainId] = expanded.filter { $0.id != deletedId }
                }
            }
            self.rebuildCommentRows()
            if var post = self.post {
                post.commentCount = max(post.commentCount - 1, 0)
                self.post = post
                self.onPostUpdated?(post)
            }
            self.tableView.reloadData()
        }, failure: { [weak self] failure in
            self?.showToast(with: failure.message)
        })
    }

    /// 删除前二次确认
    private func confirmDeleteComment(_ comment: SquareComment) {
        let alert = UIAlertController.init(title: L("删除评论"),
                                           message: L("删除后不可恢复，确定删除？"),
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: L("确定"), style: .destructive, handler: { [weak self] _ in
            self?.deleteComment(comment)
        }))
        self.present(alert, animated: true)
    }

    /// 移除本地待审评论（内容相同即认为是同一条）
    private func removePendingComment(_ comment: SquareComment) {
        comments.removeAll { $0.id == 0 && $0.content == comment.content }
        threads.removeAll { $0.comment.id == 0 && $0.comment.content == comment.content }
        for mainId in Array(expandedReplies.keys) {
            expandedReplies[mainId]?.removeAll { $0.id == 0 && $0.content == comment.content }
        }
        rebuildCommentRows()
        tableView.reloadData()
    }

    private func deletePost() {
        SquareService.shared.deletePost(id: postId, success: { [weak self] deletedId in
            guard let self = self else { return }
            self.showToast(with: L("删除成功"))
            self.onPostDeleted?(deletedId)
            self.popBack()
        }, failure: { [weak self] failure in
            self?.showToast(with: failure.message)
        })
    }

    private func setCommentsEnabled(_ enabled: Bool) {
        SquareService.shared.setCommentsEnabled(postId: postId, enabled: enabled, success: { [weak self] result in
            guard let self = self else { return }
            self.post?.commentsEnabled = result.enabled
            self.commentBar.setCommentsEnabled(result.enabled)
            self.keyboardCommentBar.setCommentsEnabled(result.enabled)
            self.updateRightBarButton()
            if let post = self.post {
                self.onPostUpdated?(post)
            }
            self.showToast(with: result.enabled ? L("已开启评论") : L("已关闭评论"))
        }, failure: { [weak self] failure in
            self?.showToast(with: failure.message)
        })
    }

    @objc private func moreTap() {
        guard let post = post else { return }
        let sheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        // 二次编辑（《App增量-置顶与二次编辑》§3）：过期 / 待审 / 已删不给入口
        if post.canEdit() {
            sheet.addAction(UIAlertAction.init(title: L("编辑"), style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                let vc = SquareCreatePostVC.edit(with: post)
                vc.hidesBottomBarWhenPushed = true
                vc.onPosted = { [weak self] in
                    self?.loadDetail()
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }))
        }
        if post.isOfficialPost {
            sheet.addAction(UIAlertAction.init(title: post.commentsEnabled ? L("关闭评论") : L("开启评论"), style: .default, handler: { [weak self] _ in
                self?.setCommentsEnabled(!post.commentsEnabled)
            }))
        }
        sheet.addAction(UIAlertAction.init(title: L("删除帖子"), style: .destructive, handler: { [weak self] _ in
            self?.confirmDeletePost()
        }))
        sheet.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect.init(x: k_ScreenWidth - 30, y: k_StatusNavigationBarHeight, width: 1, height: 1)
        }
        self.present(sheet, animated: true)
    }

    private func confirmDeletePost() {
        let alert = UIAlertController.init(title: L("删除帖子"), message: L("删除后不可恢复，确定删除？"), preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: L("确定"), style: .destructive, handler: { [weak self] _ in
            self?.deletePost()
        }))
        self.present(alert, animated: true)
    }

    /// 右上角举报：进独立的举报页（选类型 + 填理由 + 提交）
    /// （同一帖只能举报一次，重复时服务端回 `-20410`）
    @objc private func reportTap() {
        guard let post = post, canReport else { return }
        SquareReportVC.present(from: self, post: post)
    }

    private func showPhotoBrowser(urls: [String], index: Int, from imageView: UIImageView) {
        SquarePhotoPresenter.present(urls: urls, index: index, from: imageView, in: self)
    }

    /// 点头像（帖子作者 / 评论作者）→ 自己的头像进「我的信息」页（和广场右上角头像按钮一致），别人的进作者信息页
    private func openAuthor(_ address: String, name: String, kind: SquareAuthorKind) {
        guard !address.isEmpty else { return }
        if address == LoginUser.shared().address {
            let mine = SquareMyPostsVC.init()
            mine.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(mine, animated: true)
            return
        }
        let vc = SquareAuthorVC.init(address: address, name: name, authorKind: kind)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    private func popBack() {
        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - 正文富文本

    /// 正文里的点击：链接 / @提及 / #话题 / 「查看更多」
    private func handleRichTextTap(_ tap: SquareRichTap) {
        switch tap {
        case .url(let url):
            // 帖子正文里的链接改在 **App 内置浏览器**打开（不再跳系统 Safari）；
            // 语音房链接仍进通话容器（`VoiceRoomLauncher` 内部判定），非 http(s) 才回退系统打开。
            if url.scheme == "http" || url.scheme == "https" {
                VoiceRoomLauncher.open(url: url, from: self)
            } else {
                APP.shared().openUrl(with: url.absoluteString)
            }
        case .mention(let name):
            guard let address = SquareRichText.address(ofMention: name) else {
                self.showToast(with: L("未找到该用户"))
                return
            }
            openAuthor(address, name: name, kind: .person)
        case .topic(let topic):
            // 服务端没有话题接口（只能按 kind / authorAddr 过滤），先支持复制话题；
            // 接口就绪后把这里换成 push 话题页即可
            UIPasteboard.general.string = "#\(topic)#"
            self.showToast(with: L("已复制话题"))
        case .more:
            // 详情页正文不截断（不再出现「查看更多」），这里保留分支仅为了枚举完整
            break
        }
    }
}

// MARK: - 列表

extension SquarePostDetailVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return post == nil ? 0 : 1
        }
        return commentRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: SquarePostCell.identifier, for: indexPath) as! SquarePostCell
            if let post = post {
                // 昵称行右侧的关注按钮（⚠️ 必须在 configure **之前**设置：configure 里按它算宽度与状态）
                cell.showsFollow = true
                // 详情页不展示点赞/回复/查看同一行的三个点（删除等操作只在列表里做），
                // 也不画帖子底部细线：键盘弹起时表格高度变化会拖动这条线，看起来像“细线飘上去又落回来”，
                // 而输入条自己顶部已经有一条分割线了。
                // wrapsLongName：昵称当前宽度放不下时换行完整展示（与下面的 heightForRowAt 必须同参）
                // showsImagesCompletely：详情页的帖子图片要**整张显示**（格子内等比缩放、比例不同留白），
                // 不再用方形裁切 ⇒ 用户不用点开大图才能看全（格子尺寸没变，行高不受影响）
                cell.configure(post, cellWidth: k_ScreenWidth, showsMore: false, showsBottomLine: false, showsSelfTag: true, showsFullContent: true, interactiveContent: true, alignsContentWithAvatar: true, wrapsLongName: true, showsImagesCompletely: true)
                cell.onRichTextTapped = { [weak self] tap in
                    self?.handleRichTextTap(tap)
                }
                cell.onLikeTapped = { [weak self] post in
                    self?.toggleLike(post)
                }
                cell.onCommentTapped = { [weak self] _ in
                    self?.focusCommentInput()
                }
                cell.onTapImage = { [weak self] post, index, imageView in
                    self?.showPhotoBrowser(urls: post.mediaUrls, index: index, from: imageView)
                }
                cell.onAvatarTapped = { [weak self] post in
                    self?.openAuthor(post.authorAddr, name: post.authorName, kind: post.authorKind)
                }
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: SquareCommentCell.identifier, for: indexPath) as! SquareCommentCell
        guard indexPath.row < commentRows.count else { return cell }
        let row = commentRows[indexPath.row]
        // 最后一条评论不画分隔线，避免列表末尾多出一条悬空的线
        let showsSeparator = indexPath.row < commentRows.count - 1
        let commentAvatar = commentAvatarURLString(for: row.comment)
        cell.configure(row.comment, isReply: row.isReply, replyCount: row.replyCount, isExpanded: row.isExpanded,
                       showsSeparator: showsSeparator, authorAvatar: commentAvatar,
                       postAuthorAddr: post?.authorAddr ?? "")
        cell.onToggleReplies = { [weak self] in
            self?.toggleThread(row.threadMainId)
        }
        cell.onDeleteTapped = { [weak self] in
            self?.confirmDeleteComment(row.comment)
        }
        cell.onAvatarTapped = { [weak self] comment in
            self?.openAuthor(comment.authorAddr, name: comment.authorName, kind: comment.authorKind)
        }
        // 评论内容里的 http 链接：与正文链接同一入口（进 App 内 dapp 浏览器；语音房链接会走通话容器）
        cell.onLinkTapped = { [weak self] url in
            guard let self = self else { return }
            self.commentLinkTappedAt = Date()
            self.commentLinkTappedCommentId = row.comment.id
            VoiceRoomLauncher.open(url: url, from: self)
        }
        return cell
    }

    /// 评论头像地址串：**公众号评论要用公众号头像，不能显示成本人个人头像**。
    /// 优先级：
    /// 1. 服务端给这条评论带的 `authorAvatar`（最准，别的公众号的评论也靠它）；
    /// 2. 本人公众号评论 → 本地缓存的公众号头像（立刻可见，不依赖服务端）；
    /// 3. 评论作者就是帖子作者（公众号在自己的帖子里评论）→ 用帖子带的头像；
    /// 4. 空串：交给 cell 按地址解析（个人评论）。
    private func commentAvatarURLString(for comment: SquareComment) -> String {
        if !comment.authorAvatar.isEmpty { return comment.authorAvatar }

        let myAddress = LoginUser.shared().address
        if comment.isOfficialComment, comment.authorAddr == myAddress,
           let profile = SquareMyOfficialStore.profile(for: myAddress),
           profile.state.isApproved, !profile.avatar.isEmpty {
            return profile.avatar
        }

        if !comment.authorAddr.isEmpty, comment.authorAddr == post?.authorAddr {
            return post?.authorAvatar ?? ""
        }
        return ""
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }
        let header = UIView.init()
        header.backgroundColor = Color_FFFFFF
        let lab = UILabel.getLab(font: .mediumFont(14), textColor: Color_24374E, textAlignment: .left,
                                 text: "\(L("评论")) \(threadCommentCount > 0 ? threadCommentCount : (post?.commentCount ?? comments.count))")
        header.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
        }
        let line = UIView.init()
        line.backgroundColor = Color_E6EAEE
        header.addSubview(line)
        line.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 1 ? 42 : 0.01
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // 评论区空态
        if section == 1 {
            guard post != nil, hasLoadedComments, commentRows.isEmpty else { return nil }
            let footer = UIView.init()
            footer.backgroundColor = Color_FFFFFF
            let lab = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .center, text: L("暂无评论"))
            footer.addSubview(lab)
            lab.snp.makeConstraints { (m) in
                m.centerX.equalToSuperview()
                m.top.equalToSuperview().offset(16)
            }
            return footer
        }

        // 作者自己可见的未过审帖，给一条提示
        guard section == 0, let post = post, post.isUnderReview else { return nil }
        let footer = UIView.init()
        footer.backgroundColor = Color_F6F7F8
        let text = post.status == .pendingReview ? L("审核中，仅你自己可见") : L("未通过审核，仅你自己可见")
        let lab = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: text)
        footer.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        return footer
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 1 {
            return (post != nil && hasLoadedComments && commentRows.isEmpty) ? 60 : 0.01
        }
        guard section == 0, let post = post, post.isUnderReview else { return 0.01 }
        return 34
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 点帖子正文 / 图片区域一律当“空白”：由 blankTap 收起键盘，这里不抢焦点。
        // （之前这里会聚焦评论输入，结果就是：点一下先把键盘收掉、紧接着又被这里抢回来 ——
        //   表现出来就是“键盘消失之后又出现，一直循环”）
        // 打开键盘的入口：帖子上的「评论」按钮、底部输入条、点某条评论回复。
        if indexPath.section == 0 {
            return
        }

        // 点击别人（或自己）的评论：@ 对方回复
        guard indexPath.row < commentRows.count else { return }
        guard post?.commentsEnabled == true else {
            self.showToast(with: L("评论已关闭"))
            return
        }
        let comment = commentRows[indexPath.row].comment

        // 刚点的是**这条评论**里的链接（手势已处理）⇒ 这一下不要再当成「@ 回复」
        if let tappedId = commentLinkTappedCommentId, tappedId == comment.id,
           let tappedAt = commentLinkTappedAt, Date().timeIntervalSince(tappedAt) < 0.5 {
            commentLinkTappedCommentId = nil
            commentLinkTappedAt = nil
            return
        }
        guard !comment.isPendingReview else { return }
        pendingReplyCommentId = comment.id
        replyingToCommentId = comment.id
        replyingToThreadMainId = commentRows[indexPath.row].threadMainId
        focusCommentInput(mention: SquareCommentThreadBuilder.displayName(of: comment))
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : k_ScreenWidth
        if indexPath.section == 0 {
            guard let post = post else { return 0 }
            // 详情页正文是全文，行高要按全文量（列表是截断 100 字）；昵称可换行 ⇒ 带上 wrapsLongName。
            // ⚠️ 开关必须与 `cellForRowAt` 里的 `configure` 完全一致：关注按钮 / 身份标签 / 三点
            //    都会占掉昵称行右侧的宽度，少传一个就会把行高算小、昵称被压到正文上
            return SquarePostCell.height(for: post, width: width, showsFullContent: true, alignsContentWithAvatar: true,
                                         wrapsLongName: true, showsSelfTag: true, showsFollow: true, showsMore: false)
        }
        guard indexPath.row < commentRows.count else { return 0 }
        let row = commentRows[indexPath.row]
        return SquareCommentCell.height(for: row.comment, width: width,
                                        isReply: row.isReply, replyCount: row.replyCount, isExpanded: row.isExpanded)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.section == 1, hasMore, !isLoadingComments, indexPath.row >= commentRows.count - 1 else { return }
        loadComments(reset: false)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, indexPath.row < commentRows.count, commentRows[indexPath.row].comment.isMine else { return nil }
        let action = UIContextualAction.init(style: .destructive, title: L("删除")) { [weak self] (_, _, completion) in
            guard let self = self, indexPath.row < self.commentRows.count else { return }
            self.deleteComment(self.commentRows[indexPath.row].comment)
            completion(true)
        }
        return UISwipeActionsConfiguration.init(actions: [action])
    }
}
