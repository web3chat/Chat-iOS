//
//  SquareMyPostsVC.swift
//  chat
//
//  我的帖子：本机待审快照 + 从广场流里过滤出的本人已过审帖
//  说明：接口暂无「我的帖子」列表（广场流只返回已过审帖，待审帖连 id 都不返回），
//  因此已过审帖靠扫流按地址过滤、待审帖靠本地快照；服务端补接口后只需替换数据源。
//

import Foundation
import UIKit
import SnapKit
import MJRefresh
import IDMPhotoBrowser
import Kingfisher

final class SquareMyPostsVC: UIViewController, ViewControllerProtocol {

    /// 列表行：待审快照没有 id，单独用 localId 标记
    private struct Row {
        var post: SquarePost
        var pendingLocalId: String?
        var date: Date
    }

    /// 每页条数（`GET /square/app/me/posts`）
    private let pageSize = SquareLimits.defaultPageSize

    private var rows = [Row]()
    private var myPosts = [SquarePost]()
    private var myPostsPage = 1
    private var canScanMore = true
    /// 正在拉「我的帖子」（沿用原变量名，语义 = 列表加载中）
    private var isScanning = false
    /// 流量汇总（每页都返回同一份累计值，只信第一页）；拿不到就是 0
    private var trafficPosts = 0
    private var trafficViews = 0
    private var trafficLikes = 0
    private var trafficComments = 0
    /// 首次扫流是否已经结束：结束前不展示「上拉显示更多」的底部刷新
    private var hasLoadedOnce = false
    /// 已经交给表格展示的帖子行数（用于判断能不能做局部刷新，详见 `reloadPostRow(at:)`）
    private var presentedRowCount = 0
    /// 点赞请求进行中的帖子 id（避免连点）
    private var likingPostIds = Set<Int>()
    /// 我的公众号状态（信息卡只展示状态文字，公众号名称/头像在公众号页里看）
    private var officialState: SquareOfficialState = .none
    /// 本人公众号资料（名称 / 头像）——进页面先用缓存渲染，接口回来再刷新
    private var officialProfile: SquareMyOfficialProfile?
    /// 本进程内是否已经拉过权威金标目录校验本人金标（失败时重置，允许下拉刷新重试）
    private static var goldRosterChecked = false

    /// 我的公众号简介（已通过公众号且拉到了简介才有；展示在信息卡副标题下面一行）
    private var currentOfficialIntro: String {
        guard officialState.isApproved else { return "" }
        return officialProfile?.intro ?? ""
    }

    /// 信息卡高度（名字一行时）
    private static let infoRowHeight: CGFloat = 92
    /// 流量汇总卡高度
    private static let trafficRowHeight: CGFloat = 68
    /// 名字换行时每多一行要加的高度
    private static let nameLineHeight: CGFloat = 22
    /// 信息卡**当前**高度：名字太长换行后会变高（用户 2026-09-28：我的信息页名字太长要换行显示）
    private var currentInfoRowHeight: CGFloat = SquareMyPostsVC.infoRowHeight
    /// 信息区总高（信息卡 + 流量卡）：骨架 / 空态的 top 偏移都基于它
    private var headerHeight: CGFloat { return currentInfoRowHeight + SquareMyPostsVC.trafficRowHeight }

    // MARK: - 子视图

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = Color_FFFFFF
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        // 不需要横向滚动条（会显示成列表底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.estimatedRowHeight = 240
        view.rowHeight = UITableView.automaticDimension
        view.dataSource = self
        view.delegate = self
        view.register(SquarePostCell.self, forCellReuseIdentifier: SquarePostCell.identifier)
        view.register(SquareMineInfoCell.self, forCellReuseIdentifier: SquareMineInfoCell.identifier)
        view.register(SquareMineTrafficCell.self, forCellReuseIdentifier: SquareMineTrafficCell.identifier)
        view.estimatedSectionHeaderHeight = 0
        view.mj_header = MJRefreshNormalHeader.init(refreshingBlock: { [weak self] in
            self?.reload()
        })
        view.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: { [weak self] in
            self?.scanMore()
        })
        return view
    }()

    private lazy var emptyLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("还没有发过帖子"))
    }()

    /// 空态文案容器（挂成 `tableFooterView`）：高度写死 —— `tableFooterView` 只认 frame 高度，
    /// 里面 label 的约束不参与算高。
    private static let emptyFooterHeight: CGFloat = 120
    private lazy var emptyFooter: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: SquareMyPostsVC.emptyFooterHeight))
        view.backgroundColor = .clear
        view.addSubview(emptyLab)
        emptyLab.snp.makeConstraints { (m) in
            // 与信息区（信息卡 + 流量卡 = headerHeight）保持 80pt 间距：与旧叠层方案的视觉位置一致
            m.top.equalToSuperview().offset(80)
            m.centerX.equalToSuperview()
        }
        return view
    }()

    /// 骨架屏：信息卡下面那块区域（帖子还没扫出来时先顶住，避免一片白）
    private lazy var skeletonView: SquareFeedSkeletonView = {
        let view = SquareFeedSkeletonView()
        view.isHidden = true
        return view
    }()

    /// 骨架的 top 约束：它是叠层，必须跟着 contentOffset 走，
    /// 否则下拉刷新时会被往下滑动的内容盖住、滑动页面时也不跟着动（看起来像浮在页面上）
    private var skeletonTopConstraint: SnapKit.Constraint?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_FFFFFF
        self.navigationItem.title = L("我的信息")
        self.xls_navigationBarBackgroundColor = Color_FFFFFF
        // 右上角进「我的关注 / 我的粉丝」
        let followItem = UIBarButtonItem.init(title: L("我的关注"), style: .plain, target: self, action: #selector(openFollowList))
        followItem.tintColor = Color_24374E
        // 字体比导航栏默认按钮（17）小 2 号
        followItem.setTitleTextAttributes([.font: UIFont.regularFont(15)], for: .normal)
        self.navigationItem.rightBarButtonItem = followItem

        self.view.addSubview(tableView)
        // ⚠️ 空态文案**不在 view 上做叠层**，而是挂成 `tableFooterView`（表格内容的一部分）——
        // 叠层要靠 `contentOffset` 手动同步位置，而 MJRefresh 收 header 是**动画改 offset**
        // （offset 的模型值瞬间到位、内容用动画滑回去），叠层会立刻跳到终点再等内容跟上，
        // 表现就是下拉刷新时「还没有发过帖子」闪一下（2026-09-24 修）。
        // 放进内容里则天然跟着内容滚，不需要自己跟任何动画。
        // 骨架仍旧是叠层（只在首屏加载时出现，那时没有 header 回落动画），最后加 ⇒ 盖在空态之上
        self.view.addSubview(skeletonView)
        tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        // 信息卡下面是帖子区：骨架只盖这一块，上面自己的信息卡直接可见
        skeletonView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            skeletonTopConstraint = m.top.equalToSuperview().offset(self.headerHeight).constraint
        }
        // 首屏加载结束前不挂空态 footer（避免刚进页面闪一下「还没有发过帖子」）
        setEmptyFooterVisible(false)
        // 刚进来先不出现「上拉显示更多」，等首次扫流结束再按 canScanMore 决定
        tableView.mj_footer?.isHidden = true
        // 语言切换：列表里的文案（帖子里的「举报 / 分享 / 标签 / 时间）都要重刷
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: LanguageManager.LanguageChangedNotification, object: nil)

        reload()
    }

    /// 语言切换：整表重刷一次文案（帖子里的「举报 / 分享 / 标签 / 时间」都是 configure 时取的 L()）
    @objc private func languageChanged() {
        guard isViewLoaded else { return }
        mergeRows()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏白底、去掉滚动时出现的底部细线
        applySquareNavBarStyle()
    }

    // MARK: - 数据

    /// 重新拉取：公众号状态 + 我的帖子（含流量汇总）+ 合并本地待审快照
    private func reload() {
        loadOfficialInfo()
        guard LoginUser.shared().isLogin else {
            myPosts = []
            myPostsPage = 1
            canScanMore = false
            mergeRows()
            return
        }
        // 不要在这里清空 myPosts：万一刷新失败，旧列表还能继续显示（成功路径会用第一页整体替换）
        myPostsPage = 1
        canScanMore = true
        loadMyPosts(page: 1, showLoading: true)
    }

    /// 我的公众号状态 + 名称/头像（缓存优先，信息卡展示用）
    private func loadOfficialInfo() {
        let address = LoginUser.shared().address
        guard !address.isEmpty else {
            officialProfile = nil
            reloadMineCell()
            return
        }
        // 先用缓存渲染：已通过的公众号进来就能看到公众号名称与头像，不会闪一下个人资料
        officialProfile = SquareMyOfficialStore.profile(for: address)
        if let cached = officialProfile {
            officialState = cached.state
            reloadMineCell()
        }
        SquareService.shared.officialMe(success: { [weak self] me in
            guard let self = self else { return }
            self.officialState = me.state
            let profile = SquareMyOfficialProfile(state: me.state,
                                                  name: me.official?.name ?? "",
                                                  avatar: me.official?.avatar ?? "",
                                                  intro: me.official?.intro ?? "")
            self.officialProfile = profile
            SquareMyOfficialStore.save(profile, for: address)
            self.reloadMineCell()
        }, failure: { [weak self] _ in
            // 拉取失败不把已有的缓存（可能是公众号）抹掉，避免信息卡来回跳
            guard let self = self, self.officialProfile == nil else { return }
            self.officialState = .none
            self.reloadMineCell()
        })
        verifyGoldRoster()
    }

    // MARK: - 金标校验

    /// 本机缓存的金标名单是「学到就留着」的，可能过期：运营摘掉某号的金标后，
    /// 它不再出现在金标目录 `GET /officials?gold=1` 里，但本机那条 `gold = true` 还在 ⇒
    /// 信息卡会一直显示金标（用户 2026-09-28 报的现象）。
    ///
    /// 这里只在「本机缓存说我是金标」时静默拉一次权威目录做校正（不是金标号就一次请求都不发）。
    /// 拉回来名单**完整**（没有下一页）时才能推断「不在名单里 = 不是金标」。
    private func verifyGoldRoster() {
        let address = LoginUser.shared().address
        guard !address.isEmpty else { return }
        // 只有本机缓存认为「我是金标」才需要校验：否则信息卡本来就不显示金标
        guard SquareOfficialDirectoryStore.item(for: address)?.gold == true else { return }
        guard !SquareMyPostsVC.goldRosterChecked else { return }
        SquareMyPostsVC.goldRosterChecked = true
        SquareService.shared.officials(gold: true, page: 1, pageSize: SquareLimits.maxPageSize, success: { [weak self] pageData in
            guard let self = self else { return }
            SquareOfficialDirectoryStore.save(pageData.list)
            if !pageData.hasMore {
                SquareOfficialDirectoryStore.applyGoldRoster(Set(pageData.list.map { $0.address }))
                // 校正后可能从金标变成非金标：重刷信息卡
                self.reloadMineCell()
            }
        }, failure: { _ in
            // 校验失败保持现状（不抹掉已有金标）——解锁标记，下次进页面 / 下拉刷新再校
            SquareMyPostsVC.goldRosterChecked = false
        })
    }

    /// 进「我的关注 / 我的粉丝」
    @objc private func openFollowList() {
        guard LoginUser.shared().isLogin else {
            self.showToast(with: L("请先登录"))
            return
        }
        let vc = SquareFollowListVC.init()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    /// 刷新信息卡（名称 = 公众号名/昵称/短地址；副标题 = 短地址 · 状态）
    /// 注意：不能去 `tableView.cellForRow(at:)` 找 cell —— 在 `cellForRowAt` 内部还没返回给 table，查不到会直接跳过，
    /// 导致重用时（例如从帖子详情返回触发 reload）信息卡是空白的。这里用数据驱动 + reloadRows。
    private func reloadMineCell() {
        guard isViewLoaded, tableView.numberOfSections > 0 else { return }
        tableView.reloadRows(at: [IndexPath.init(row: 0, section: 0)], with: .none)
    }

    /// 名字换行后同步信息卡高度（名字最多两行，每多一行 +22pt）。
    /// ⚠️ 高度没变**不要** reload —— 它是在 `cellForRowAt` 里被调的，成环会出事；
    /// 变高时用 `async` 推迟到本轮布局之后再去刷新行高 / 骨架偏移。
    private func syncInfoRowHeight(name: String, showsOfficialTag: Bool) {
        let isPlatformOfficial = LoginUser.shared().address == SquareOfficialAccount.platform
        let showsTag = showsOfficialTag || isPlatformOfficial
        let tagText = showsTag ? (isPlatformOfficial ? L("官方号") : L("公众号")) : ""
        let showsGold = SquareOfficialDirectoryStore.item(for: LoginUser.shared().address)?.gold ?? false
        let lines = SquareMineInfoCell.nameLineCount(for: name, tagText: tagText, showsGold: showsGold)
        let height = SquareMyPostsVC.infoRowHeight + CGFloat(lines - 1) * SquareMyPostsVC.nameLineHeight
        guard abs(height - currentInfoRowHeight) > 0.5 else { return }
        currentInfoRowHeight = height
        skeletonTopConstraint?.update(offset: headerHeight)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadRows(at: [IndexPath.init(row: 0, section: 0)], with: .none)
            self.updateEmptyState()
        }
    }

    /// 信息卡展示内容：**是公众号就优先展示公众号信息**（名称 + 公众号头像），否则展示用户自己的昵称 + 头像
    /// 副标题统一是「短地址 · 公众号状态」
    private func mineInfo() -> (name: String, desc: String, statusText: String, statusColor: UIColor, avatarURL: String) {
        let address = LoginUser.shared().address
        let status = officialState.displayText
        // 平台官方号（square-official）不是钱包地址：不要截成「squar…cial」那种怪样子（与作者页一致）
        let addressText = address == SquareOfficialAccount.platform ? L("官方账号") : address.shortAddress
        let desc = [addressText, status].filter { !$0.isEmpty }.joined(separator: " · ")
        if officialState.isApproved, let profile = officialProfile, !profile.name.isEmpty || !profile.avatar.isEmpty {
            let name = SquareDisplayName.of(name: profile.name, address: address)
            return (name, desc, status, statusColor(for: officialState), profile.avatar)
        }
        let name = SquareDisplayName.of(name: LoginUser.shared().nickName?.value ?? "", address: address)
        return (name, desc, status, statusColor(for: officialState), "")
    }

    /// 状态文字颜色：已通过=主题蓝；申请未通过=红；其它（未申请 / 审核中…）保持默认次要不色
    private func statusColor(for state: SquareOfficialState) -> UIColor {
        switch state {
        case .approved: return Color_Theme
        case .rejected: return Color_DD5F5F
        default: return Color_8A97A5
        }
    }

    private func scanMore() {
        guard canScanMore else {
            tableView.mj_footer?.endRefreshing()
            return
        }
        loadMyPosts(page: myPostsPage + 1, showLoading: false)
    }

    /// 拉「我的帖子」（`GET /square/app/me/posts`）：
    /// 只返回本地址的帖（含可见 / 隐藏 / 待审 / AI 拒绝，不含已删与草稿），并带回流量汇总。
    /// 比原来的「扫广场流按地址过滤」准确得多（待审帖也能看到，且不用拉好几页）。
    private func loadMyPosts(page: Int, showLoading: Bool) {
        guard !isScanning else {
            tableView.mj_header?.endRefreshing()
            tableView.mj_footer?.endRefreshing()
            return
        }
        isScanning = true
        // 还没有内容时用骨架屏顶住（不再转圈）；已有内容的下拉刷新保持旧内容不动
        if showLoading && !rows.isEmpty {
            self.showProgress()
        }
        updateEmptyState()
        SquareService.shared.myPosts(page: page, pageSize: pageSize, success: { [weak self] pageData in
            guard let self = self else { return }
            self.isScanning = false
            self.hasLoadedOnce = true
            self.hideProgress()
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            self.myPostsPage = page
            self.canScanMore = pageData.hasMore(page: page, pageSize: self.pageSize)
            self.myPosts = page == 1 ? pageData.list : self.myPosts + pageData.list
            if page == 1 {
                self.trafficPosts = pageData.totalPosts
                self.trafficViews = pageData.totalViews
                self.trafficLikes = pageData.totalLikes
                self.trafficComments = pageData.totalComments
            }
            // 帖子里出现过审版了，本地待审快照就没必要再占一行
            pageData.list.forEach { SquareMyPostStore.removePendingIfMatched(post: $0) }
            self.mergeRows()
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isScanning = false
            self.hasLoadedOnce = true
            self.hideProgress()
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            self.mergeRows()
            // 404（后端还没上线）不弹提示
            if failure.shouldStaySilent {
                FZMLog("我的帖子拉取失败(静默) \(failure.rawCode) \(failure.message)")
            } else {
                self.showToast(failure.message)
            }
        })
    }

    /// 合并：服务端已过审帖 + 本机待审快照，按时间倒序
    private func mergeRows() {
        var list = [Row]()
        for post in myPosts {
            list.append(Row(post: post, pendingLocalId: nil, date: post.createdDate ?? Date.distantPast))
        }
        for record in SquareMyPostStore.pendingPosts() {
            list.append(Row(post: record.post(), pendingLocalId: record.localId, date: record.createdDate ?? Date.distantPast))
        }
        list.sort { $0.date > $1.date }
        rows = list
        presentedRowCount = rows.count
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        // 空态：**刷新过程中不要来回切** —— 列表本来就空时，下拉刷新会把它先藏起来再露出来（用户看到「闪一下」）
        // 规则：只有「不在加载中」或「确实有内容」时才允许改它的显隐
        let isEmpty = rows.isEmpty
        if !isScanning || !isEmpty {
            setEmptyFooterVisible(isEmpty)
        }
        // 「上拉显示更多」：首次加载结束、还能继续加载、且列表里有内容才给
        tableView.mj_footer?.isHidden = !hasLoadedOnce || !canScanMore || rows.isEmpty
        updateSkeletonState()
        syncOverlayPositions()
    }

    /// 骨架屏显隐：**只在首次扫流**、且一条帖子都还没有时顶骨架。
    /// 下拉刷新时不再顶骨架：那是固定叠层，会把被顶下去的信息卡盖住。
    private func updateSkeletonState() {
        let shouldShow = !hasLoadedOnce && isScanning && rows.isEmpty
        skeletonView.isHidden = !shouldShow
        if shouldShow {
            skeletonView.startAnimating()
        } else {
            skeletonView.stopAnimating()
        }
    }

    /// 挂 / 摘空态 footer（`tableFooterView`）：只认 frame 高度，所以高度写在 `emptyFooterHeight`
    private func setEmptyFooterVisible(_ visible: Bool) {
        let target: UIView? = visible ? emptyFooter : nil
        guard tableView.tableFooterView !== target else { return }
        tableView.tableFooterView = target
    }

    /// 让骨架跟着列表内容一起移动（信息区占 `headerHeight`，贴在它下面）
    /// 注意：空态文案已改成 `tableFooterView`（内容的一部分，不需要同步）
    private func syncOverlayPositions() {
        let contentTop = headerHeight - tableView.contentOffset.y
        skeletonTopConstraint?.update(offset: contentTop)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncOverlayPositions()
    }
    /// 只刷新某一行帖子。
    /// 帖子在 **section 1**（section 0 是信息卡）；而且表格内部保存着「更新前的行数」，
    /// 和数据源对不上时 `reloadRows` 会直接抛 “Invalid update: invalid number of rows...” 崩溃，
    /// 所以行号越界或超出已展示范围时退回整体刷新。
    private func reloadPostRow(at index: Int) {
        guard index >= 0, index < rows.count, index < presentedRowCount else {
            presentedRowCount = rows.count
            tableView.reloadData()
            return
        }
        tableView.reloadRows(at: [IndexPath.init(row: index, section: 1)], with: .none)
    }
    // MARK: - 交互

    /// 点头像 → 作者信息页（自己的帖子同样进这个页，页内会带「我」标签）
    private func openAuthor(_ address: String, name: String, kind: SquareAuthorKind) {
        guard !address.isEmpty else { return }
        let vc = SquareAuthorVC.init(address: address, name: name, authorKind: kind)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    private func openDetail(_ post: SquarePost) {
        guard post.id > 0 else { return }
        let vc = SquarePostDetailVC.init(postId: post.id)
        vc.hidesBottomBarWhenPushed = true
        vc.onPostUpdated = { [weak self] updated in
            self?.applyUpdatedPost(updated)
        }
        vc.onPostDeleted = { [weak self] deletedId in
            guard let self = self else { return }
            self.myPosts.removeAll { $0.id == deletedId }
            self.mergeRows()
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }

    /// 详情页回传的单条更新
    private func applyUpdatedPost(_ post: SquarePost) {
        guard let index = rows.firstIndex(where: { $0.post.id == post.id }) else { return }
        rows[index].post = post
        reloadPostRow(at: index)
    }

    /// 删除本地待审快照（待审帖服务端没有 id，无法走删除接口）
    private func deletePendingSnapshot(localId: String) {
        SquareMyPostStore.removePending(localId: localId)
        mergeRows()
    }

    /// 点赞 / 取消点赞（乐观更新，失败回滚）
    private func toggleLike(_ post: SquarePost) {
        guard post.id > 0, !likingPostIds.contains(post.id) else { return }
        guard let index = rows.firstIndex(where: { $0.post.id == post.id }) else { return }

        likingPostIds.insert(post.id)
        let previousLiked = rows[index].post.liked
        let previousCount = rows[index].post.likeCount
        rows[index].post.liked = !previousLiked
        rows[index].post.likeCount = max(previousCount + (previousLiked ? -1 : 1), 0)
        reloadPostRow(at: index)

        SquareService.shared.toggleLike(post: post, success: { [weak self] result in
            guard let self = self else { return }
            self.likingPostIds.remove(post.id)
            self.applyLikeResult(postId: post.id, liked: result.liked, count: result.likeCount)
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.likingPostIds.remove(post.id)
            self.applyLikeResult(postId: post.id, liked: previousLiked, count: previousCount)
            self.showToast(with: failure.message)
        })
    }

    private func applyLikeResult(postId: Int, liked: Bool, count: Int) {
        if let index = rows.firstIndex(where: { $0.post.id == postId }) {
            rows[index].post.liked = liked
            rows[index].post.likeCount = count
            reloadPostRow(at: index)
        }
        if let index = myPosts.firstIndex(where: { $0.id == postId }) {
            myPosts[index].liked = liked
            myPosts[index].likeCount = count
        }
    }

    private func showPhotoBrowser(urls: [String], index: Int, from imageView: UIImageView) {
        SquarePhotoPresenter.present(urls: urls, index: index, from: imageView, in: self)
    }
}

// MARK: - 列表

extension SquareMyPostsVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // section 0：信息卡 + 流量汇总卡（行数**恒定**，避免局部刷新时行数对不上崩溃）
        return section == 0 ? 2 : rows.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1, !rows.isEmpty else { return nil }
        let view = UIView.init()
        view.backgroundColor = Color_FFFFFF
        let lab = UILabel.getLab(font: .mediumFont(15), textColor: Color_24374E, textAlignment: .left, text: L("我的帖子"))
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
        }
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section == 1, !rows.isEmpty else { return 0.01 }
        return 44
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section == 1 else {
            guard indexPath.row == 0 else {
                let cell = tableView.dequeueReusableCell(withIdentifier: SquareMineTrafficCell.identifier, for: indexPath) as! SquareMineTrafficCell
                cell.selectionStyle = .none
                cell.configure(posts: trafficPosts, views: trafficViews, likes: trafficLikes, comments: trafficComments)
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: SquareMineInfoCell.identifier, for: indexPath) as! SquareMineInfoCell
            cell.selectionStyle = .none
            let info = mineInfo()
            cell.configure(name: info.name, desc: info.desc, statusText: info.statusText,
                           statusColor: info.statusColor, avatarURL: info.avatarURL,
                           showsOfficialTag: officialState.isApproved,
                           intro: currentOfficialIntro)
            // 名字太长会换行（最多两行）⇒ 信息卡要跟着变高（骨架 / 空态偏移用同一个值）
            syncInfoRowHeight(name: info.name, showsOfficialTag: officialState.isApproved)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: SquarePostCell.identifier, for: indexPath) as! SquarePostCell
        guard indexPath.row < rows.count else { return cell }

        let row = rows[indexPath.row]
        // 与广场流 / 作者页统一：昵称过长时换行完整显示，标签在昵称下面另起一行
        cell.configure(row.post, cellWidth: k_ScreenWidth, wrapsLongName: true)
        cell.onAvatarTapped = { [weak self] post in
            self?.openAuthor(post.authorAddr, name: post.authorName, kind: post.authorKind)
        }

        if row.pendingLocalId != nil {
            // 待审快照没有服务端 id，点赞/评论/详情都不可用
            cell.onLikeTapped = { [weak self] _ in
                self?.showToast(with: L("审核中，仅你自己可见"))
            }
            cell.onCommentTapped = { [weak self] _ in
                self?.showToast(with: L("审核中，仅你自己可见"))
            }
        } else {
            cell.onLikeTapped = { [weak self] post in
                self?.toggleLike(post)
            }
            cell.onCommentTapped = { [weak self] post in
                self?.openDetail(post)
            }
        }
        cell.onTapImage = { [weak self] post, index, imageView in
            self?.showPhotoBrowser(urls: post.mediaUrls, index: index, from: imageView)
        }
        cell.onMoreTapped = { [weak self] post in
            self?.showPostActions(post)
        }
        return cell
    }

    /// 自己帖子的三个点：编辑 / 删除 / （公众号帖）关评论
    private func showPostActions(_ post: SquarePost) {
        SquarePostActionSheet.present(from: self, post: post, onUpdated: { [weak self] updated in
            self?.applyUpdatedPost(updated)
        }, onDeleted: { [weak self] deletedId in
            guard let self = self else { return }
            self.myPosts.removeAll { $0.id == deletedId }
            self.mergeRows()
        }, onEdited: { [weak self] in
            // 编辑后要重新审核 ⇒ 整体重拉
            self?.reload()
        })
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else {
            // 信息卡：进公众号申请 / 详情
            guard indexPath.row == 0 else { return }
            let vc = SquareOfficialVC.init()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
            return
        }
        guard indexPath.row < rows.count else { return }
        let row = rows[indexPath.row]
        guard row.pendingLocalId == nil else {
            self.showToast(with: L("审核中，仅你自己可见"))
            return
        }
        openDetail(row.post)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section == 1 else {
            return indexPath.row == 0 ? currentInfoRowHeight : SquareMyPostsVC.trafficRowHeight
        }
        guard indexPath.row < rows.count else { return 0 }
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : k_ScreenWidth
        // ⚠️ 必须与 cellForRowAt 的 configure 同参，否则行高会算小
        return SquarePostCell.height(for: rows[indexPath.row].post, width: width, wrapsLongName: true)
    }

    /// 待审快照只支持本地清理
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, indexPath.row < rows.count,
              let localId = rows[indexPath.row].pendingLocalId else { return nil }
        let action = UIContextualAction.init(style: .destructive, title: L("删除帖子")) { [weak self] _, _, completion in
            self?.deletePendingSnapshot(localId: localId)
            completion(true)
        }
        return UISwipeActionsConfiguration.init(actions: [action])
    }
}

// MARK: - 我的信息卡

/// 「我的」头部：头像 / 名称 / 短地址 · 公众号状态，点击可进申请或详情
final class SquareMineInfoCell: UITableViewCell {

    static let identifier = "SquareMineInfoCell"

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 28
        view.backgroundColor = Color_F6F7F8
        return view
    }()

    /// 名称：**最多两行**（名字太长时换行完整展示，不再截断成「…」。用户 2026-09-28 要求）
    private lazy var nameLab: UILabel = {
        let lab = UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 2
        return lab
    }()

    /// 昵称后的身份标签（自己的号已通过认证时显示「公众号」），没有身份时不占宽度
    private lazy var tagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_FFFFFF, textAlignment: .center, text: L("公众号"))
        lab.backgroundColor = Color_Identity_Tag
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        lab.isHidden = true
        return lab
    }()

    /// 金标：**我是金标号**时紧贴昵称右侧显示（名单来自金标目录 `GET /officials`），宽度 0 / 14 切换
    /// 样式与广场页（帖子 cell / 作者页 / 金标墙）一致：橙底圆 + 白色实心五角星（`star.circle.fill`）
    private lazy var goldView: UIImageView = {
        let config = UIImage.SymbolConfiguration.init(pointSize: 12, weight: .bold)
        let view = UIImageView.init(image: UIImage.init(systemName: "star.circle.fill", withConfiguration: config)?.withRenderingMode(.alwaysTemplate))
        view.tintColor = Color_Gold
        view.contentMode = .scaleAspectFit
        view.isHidden = true
        return view
    }()

    private var goldWidthConstraint: SnapKit.Constraint?
    private var tagWidthConstraint: SnapKit.Constraint?

    private lazy var descLab: UILabel = {
        return UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()

    /// 公众号简介（已通过公众号且拿到简介时显示）。
    /// 单行省略：副标题下面正好还能放下一行。
    /// ⚠️ 信息卡高度不再固定 92：名字太长会换行（最多两行）⇒ 高度由 `SquareMyPostsVC.syncInfoRowHeight`
    /// 动态调整，骨架 / 空态的 top 偏移用的是同一份 `headerHeight`，所以不用另外改。
    private lazy var introLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.lineBreakMode = .byTruncatingTail
        lab.isHidden = true
        return lab
    }()

    private lazy var arrowView: UIImageView = {
        let view = UIImageView.init(image: UIImage.init(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate))
        view.tintColor = Color_C8D3DE
        view.contentMode = .scaleAspectFit
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = Color_FFFFFF
        self.contentView.backgroundColor = Color_FFFFFF
        self.contentView.addSubview(avatarView)
        self.contentView.addSubview(nameLab)
        self.contentView.addSubview(goldView)
        self.contentView.addSubview(tagLab)
        self.contentView.addSubview(descLab)
        self.contentView.addSubview(introLab)
        self.contentView.addSubview(arrowView)

        avatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 56, height: 56))
        }
        arrowView.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 14, height: 14))
        }
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(avatarView.snp.right).offset(12)
            // 名字后面可能跟「金标 + 公众号标签」：宽度按内容来，超长时由后面的边界顶住后自动截断
            m.right.equalTo(goldView.snp.left)
            m.bottom.equalTo(self.contentView.snp.centerY).offset(-2)
        }
        nameLab.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // 金标：紧贴昵称右侧（与帖子 cell / 作者页同一套样式）。
        // ⚠️ 对齐名字**第一行**（名字可能两行）；自己也要有右边界，不能跑到箭头下面
        goldView.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.right)
            m.centerY.equalTo(nameLab.snp.top).offset(11)
            m.height.equalTo(14)
            goldWidthConstraint = m.width.equalTo(0).constraint
            m.right.lessThanOrEqualTo(arrowView.snp.left).offset(-10)
        }
        // 身份标签（我 / 公众号）：**回到名字行**、跟在金标后面（用户 2026-09-28：「标签挪到第二行太丑，改回去」）。
        // 名字太长时靠名字自己换行（最多两行）解决，而不是把标签挪走。
        // ⚠️ 它必须有右边界（顶在箭头左侧），否则名字一长标签会被推到箭头下面
        tagLab.snp.makeConstraints { (m) in
            m.left.equalTo(goldView.snp.right).offset(6)
            m.right.lessThanOrEqualTo(arrowView.snp.left).offset(-10)
            m.centerY.equalTo(nameLab.snp.top).offset(11)
            m.height.equalTo(16)
            tagWidthConstraint = m.width.equalTo(0).constraint
        }
        descLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.equalTo(arrowView.snp.left).offset(-10)
            m.top.equalTo(self.contentView.snp.centerY).offset(4)
        }
        // 简介：跟在副标题下面（introLab 已在上面先 addSubview，再建这条引用 descLab 的约束）
        introLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.equalTo(arrowView.snp.left).offset(-10)
            m.top.equalTo(descLab.snp.bottom).offset(2)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 名字在这个卡片宽度下会占几行（1 或 2）—— 信息卡高度要按它加高（见 `SquareMyPostsVC.syncInfoRowHeight`）
    static func nameLineCount(for displayName: String, tagText: String, showsGold: Bool) -> Int {
        let nameFont = UIFont.mediumFont(16)
        let nameWidth = ceil((displayName as NSString).size(withAttributes: [.font: nameFont]).width)
        guard nameWidth > 0 else { return 1 }
        let tagWidth = tagText.isEmpty ? 0 : ceil((tagText as NSString).size(withAttributes: [.font: UIFont.regularFont(10)]).width + 12)
        // 名字行右侧：右边距 15 + 箭头 14 + 与箭头间距 10 + 金标（宽 + 6）+ 身份标签（宽 + 6）
        let rightUsed: CGFloat = 15 + 14 + 10 + (showsGold ? 14 + 6 : 0) + (tagWidth > 0 ? tagWidth + 6 : 0)
        // 左侧：15（边距）+ 56（头像）+ 12（间隙）
        let available = k_ScreenWidth - 15 - 56 - 12 - rightUsed
        guard available > 24 else { return 2 }
        return nameWidth > available ? 2 : 1
    }

    /// 信息卡：名称（+ 可选「公众号」标签）/ 副标题（短地址 · 公众号状态，状态文字用对应颜色） / 头像
    /// - Parameters:
    ///   - avatarURL: 公众号头像（已通过公众号时传）；为空则回退本人登录头像 / 按地址解析
    ///   - showsOfficialTag: 是已通过的公众号时，在昵称后面加「公众号」标签
    ///     （本人就是平台官方号时不看它，直接显示「官方号」）
    func configure(name: String, desc: String, statusText: String, statusColor: UIColor, avatarURL: String = "", showsOfficialTag: Bool = false, intro: String = "") {
        nameLab.text = name

        // 昵称后的身份标签：「官方号」= 平台官方号（全平台唯一）；其余已认证的号是「公众号」；都不是就不占位
        let isPlatformOfficial = LoginUser.shared().address == SquareOfficialAccount.platform
        let showsTag = showsOfficialTag || isPlatformOfficial
        let tag = showsTag ? (isPlatformOfficial ? L("官方号") : L("公众号")) : ""
        tagLab.text = tag.isEmpty ? nil : tag
        tagLab.isHidden = tag.isEmpty
        tagLab.backgroundColor = isPlatformOfficial ? Color_Official_Tag : Color_Identity_Tag
        // 金标：我本身是金标号时贴在昵称后面（名单来自金标目录）
        let isGold = SquareOfficialDirectoryStore.item(for: LoginUser.shared().address)?.gold ?? false
        goldView.isHidden = !isGold
        goldWidthConstraint?.update(offset: isGold ? 14 : 0)
        let tagFont = tagLab.font ?? .regularFont(10)
        let tagWidth = tag.isEmpty ? 0 : (tag as NSString).size(withAttributes: [.font: tagFont]).width + 12
        tagWidthConstraint?.update(offset: ceil(tagWidth))

        // 副标题里只给「状态」那几个字上色，短地址仍用次要文字色
        let font = descLab.font ?? .regularFont(13)
        let attr = NSMutableAttributedString(string: desc, attributes: [.font: font, .foregroundColor: Color_8A97A5])
        if !statusText.isEmpty, let range = desc.range(of: statusText) {
            attr.addAttribute(.foregroundColor, value: statusColor, range: NSRange(range, in: desc))
        }
        descLab.attributedText = attr

        // 公众号简介：有才显示（单行省略，不动信息卡高度）
        let introText = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        introLab.text = introText.isEmpty ? nil : introText
        introLab.isHidden = introText.isEmpty

        // 公众号优先：服务端给了公众号头像就用它
        if !avatarURL.isEmpty {
            showAvatar(urlString: avatarURL)
            return
        }
        // 不是公众号（公众号头像为空）→ 本地登录头像（改了立即生效）→ 按地址解析 → 都没有就默认头像
        let own = LoginUser.shared().avatarUrl
        if !own.isEmpty {
            showAvatar(urlString: own)
            return
        }
        let address = LoginUser.shared().address
        guard !address.isEmpty else {
            resetToDefaultAvatar()
            return
        }
        SquareAvatarResolver.avatarURL(for: address) { [weak self] resolved in
            guard let self = self, LoginUser.shared().address == address else { return }
            guard let resolved = resolved, !resolved.isEmpty else {
                // 本人也没头像：显式回默认头像，不能把上一个账号的头像留着
                self.resetToDefaultAvatar()
                return
            }
            self.showAvatar(urlString: resolved)
        }
    }

    /// 当前展示的头像地址（用来判断要不要重新加载，避免重复赋值把已经显示的头像换成占位图）
    private var currentAvatarURL = ""

    /// 默认头像（不是公众号、也拿不到本人头像时用）
    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")

    /// 回到默认头像：cell 复用 / 账号切换 / 地址非法时都得显式重置，
    /// 否则会残留上一个账号（或上一篇公众号）的头像
    private func resetToDefaultAvatar() {
        currentAvatarURL = ""
        avatarView.kf.cancelDownloadTask()
        avatarView.backgroundColor = Color_F6F7F8
        avatarView.image = SquareMineInfoCell.defaultAvatar
    }

    /// 加载头像：地址没变就直接跳过（已经显示的就是这张）；变了也拿当前图当占位，
    /// 这样「个人 ↔ 公众号」切换时不会先闪一下占位图
    private func showAvatar(urlString: String) {
        guard !urlString.isEmpty else {
            resetToDefaultAvatar()
            return
        }
        guard urlString != currentAvatarURL else { return }
        guard let link = URL.init(string: urlString) else {
            resetToDefaultAvatar()
            return
        }
        currentAvatarURL = urlString
        let placeholder = avatarView.image ?? SquareMineInfoCell.defaultAvatar
        SquareAvatarLoader.apply(to: avatarView, url: link, key: urlString, placeholder: placeholder) { [weak self] success in
            guard let self = self, !success, self.currentAvatarURL == urlString else { return }
            // 加载失败：清掉记录并回默认头像，下次重新配置时重试
            self.resetToDefaultAvatar()
        }
    }
}

// MARK: - 流量汇总卡

/// 「我的」页第二张卡：我的帖子累计流量（《App增量-关注热门举报流量》§5）
/// 只展示数字，点击无跳转；拿不到数据时就是 0（用户要求：不显示「—」）
final class SquareMineTrafficCell: UITableViewCell {

    static let identifier = "SquareMineTrafficCell"

    private lazy var stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.alignment = .center
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = Color_F6F7F8
        self.contentView.backgroundColor = Color_F6F7F8

        let card = UIView()
        card.backgroundColor = Color_FFFFFF
        card.layer.cornerRadius = 8
        card.clipsToBounds = true
        contentView.addSubview(card)
        card.addSubview(stackView)

        card.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(4)
            m.bottom.equalToSuperview().offset(-4)
        }
        stackView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        // 四列：总帖数 / 总阅读 / 总点赞 / 总评论（先在栈里建好 4 列，再统一填数据）
        ["我的帖子", "总阅读", "总点赞", "总评论"].forEach { title in
            stackView.addArrangedSubview(SquareMineTrafficCell.makeColumn(title: L(title)))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 一列：数字（大）在上、说明（小）在下
    private static func makeColumn(title: String) -> UIView {
        let container = UIView()
        let valueLab = UILabel.getLab(font: .mediumFont(18), textColor: Color_24374E, textAlignment: .center, text: nil)
        valueLab.tag = SquareMineTrafficCell.valueLabelTag
        let titleLab = UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: title)
        container.addSubview(valueLab)
        container.addSubview(titleLab)
        valueLab.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.centerY.equalToSuperview().offset(-11)
        }
        titleLab.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(valueLab.snp.bottom).offset(4)
        }
        return container
    }

    /// 数字 label 的 tag（同一文件内跨类型访问，不能用 private 常量）
    fileprivate static let valueLabelTag = 9091

    func configure(posts: Int, views: Int, likes: Int, comments: Int) {
        let values: [Int] = [posts, views, likes, comments]
        for (index, column) in stackView.arrangedSubviews.enumerated() {
            guard let valueLab = column.viewWithTag(SquareMineTrafficCell.valueLabelTag) as? UILabel else { continue }
            valueLab.text = index < values.count ? SquareMineTrafficCell.displayText(values[index]) : "0"
        }
    }

    /// 大数字压缩一下（中文「1.2万」/ 英文「12.8K」），避免四位数字撑破一列
    private static func displayText(_ value: Int) -> String {
        guard value >= 10000 else { return "\(value)" }
        // ⚠️ 进位单位不同：中/繁/日/韩按「万」(÷10000)，其它语言按「K」(÷1000)，
        // 否则英文及新语言界面会显示成「1.3万」（单位没本地化，数值口径也不对）
        let divisor: Double = LanguageManager.shared.usesMyriadUnit ? 10000.0 : 1000.0
        return String(format: "%.1f" + L("万"), Double(value) / divisor)
    }
}
