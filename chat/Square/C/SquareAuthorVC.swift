//
//  SquareAuthorVC.swift
//  chat
//
//  作者信息页：广场里点帖子/评论的头像进来
//  内容：作者（个人 / 公众号）头像 + 昵称 + 身份标签 + 短地址，下面是他/她在广场发布的帖子
//  数据源：GET /square/app/posts?authorAddr=xxx（对接文档 §6.1 的 authorAddr 过滤）
//

import Foundation
import UIKit
import SnapKit
import MJRefresh
import IDMPhotoBrowser
import Kingfisher

final class SquareAuthorVC: UIViewController, ViewControllerProtocol {

    /// 作者地址（接口过滤条件）
    private let address: String
    /// 列表里带过来的展示名（接口回来前先用它，避免白一下）
    private var authorName: String
    /// 作者类型：0 个人 / 1 公众号（用于「公众号」标签）
    private var authorKind: SquareAuthorKind
    /// 作者头像（公众号帖服务端会带 authorAvatar，列表里拿到后给信息卡用）
    private var authorAvatar = ""
    /// 作者是金标公众号（从帖子对象的 authorGold 学到；列表里有一条 true 就是金标）
    private var authorGold = false

    /// 是否展示关注按钮：不是自己（帖子对象不带 followed，状态靠 `SquareFollowStore`，
    /// 名单没拉到时按「未关注」显示，点一下即可关注 —— 服务端幂等）
    private var showsFollowEntry: Bool {
        return !address.isEmpty && address != LoginUser.shared().address
    }

    /// 作者是公众号时给信息卡显示的简介。
    /// 优先级：本人公众号缓存（`SquareMyOfficialStore`）→ 金标目录学到的资料（`SquareOfficialDirectoryStore`）。
    /// ⚠️ 服务端**没有**「按地址查别人公众号资料」的接口（`official/me` 只能查自己），
    /// 别人的简介只能从金标目录 `GET /square/app/officials` 学到 —— 用户进过一次「公众号」筛选后就有了。
    private var currentOfficialIntro: String {
        guard authorKind == .official else { return "" }
        if let mine = SquareMyOfficialStore.profile(for: address)?.intro, !mine.isEmpty {
            return mine
        }
        return SquareOfficialDirectoryStore.item(for: address)?.intro ?? ""
    }

    /// 作者名下的帖子总数（来自 `GET /posts?authorAddr=` 的 `total`，最准且不用额外请求）
    private var authorPostTotal = 0

    /// 作者的粉丝数：只能从官方号目录学（服务端没有「按地址查资料」接口），
    /// 由 `loadOfficialDirectoryIfNeeded()` 拉 `gold=nil`（= `gold=1&gold=0`）的**全部正常号**目录补全。
    /// `nil` = 现在还不知道（目录还在拉 / 这个地址不在目录里）⇒ 信息卡**不显示**粉丝这一项，
    /// 等目录回来（会广播刷新，见 `SquareOfficialDirectoryStore.didUpdateNotification`）再显示。
    /// ⚠️ 以前用「请求是否结束」的静态标志 + `?? 0` 兜底，而请求本身又要求 `authorKind == .official`：
    /// 入口带的身份是猜的（评论只给得出 unknown）⇒ 请求压根没发出去、标志永远不置位
    /// ⇒ 粉丝数一直显示成「…」（用户 2026-09-29 报的「粉丝不显示数量」）。
    private var currentFollowerCount: Int? {
        guard authorKind == .official else { return nil }
        return SquareOfficialDirectoryStore.item(for: address)?.followerCount
    }

    /// 作者的帖子数：**优先**用 `feed` 返回的 `total`。
    /// ⚠️ 以前只从金标目录学（`gold: true` 的名单里没有非金标号）⇒ 用户 2026-09-28 报
    /// 「作者有帖子却显示 0 帖子」；现在拿不到 `total` 时回落已加载条数，最后才回落目录。
    /// `nil` = 首屏接口还没回来 ⇒ UI 显示占位（避免「先 0 再跳真实值」闪一下）
    private var currentPostCount: Int? {
        if authorPostTotal > 0 { return authorPostTotal }
        guard hasLoadedOnce else {
            // 还没回来：本地目录有缓存就先顶上，没有就交给 UI 显示占位
            return SquareOfficialDirectoryStore.item(for: address)?.postCount
        }
        return posts.count
    }

    private var posts = [SquarePost]()
    private var page = 1
    private var hasMore = false
    private var isLoading = false
    /// 第一页数据是否已经回来：回来之前不展示「上拉显示更多」的底部刷新
    private var hasLoadedOnce = false
    /// 已经交给表格展示的帖子数量。
    /// 局部刷新（`reloadRows`）只有落在表格已经知道的行范围内才安全：
    /// 表格内部会拿「更新前的行数」和「数据源给的行数」对比，只要两者不一致就会直接抛
    /// “Invalid update: invalid number of rows in section 1”，所以这里自己记一份。
    private var presentedPostCount = 0
    /// 点赞请求进行中的帖子 id（避免连点）
    private var likingPostIds = Set<Int>()

    /// 信息卡**基础**高度（名字只有一行时）：头像 / 名字行 / 短地址(+身份标签) / 帖子数+粉丝数 / 公众号简介
    /// + 底部「内容」标签栏（`SquareAuthorTabBar.height`，2026-09-30 新增）
    /// （2026-09-28 加了统计行，从 92 改成 126）
    /// ⚠️ 名字太长会**换行**（最多两行）⇒ 实际高度用 `currentInfoRowHeight`
    /// （= 本值 + 多出来的行数 × `nameLineHeight`，由 `syncInfoRowHeight` 同步）
    private static let infoRowHeight: CGFloat = 126 + SquareAuthorTabBar.height
    /// 名字每多一行，卡片要加的高度（16pt medium 的行高 ≈ 22，与「我的信息」页同一套）
    private static let nameLineHeight: CGFloat = 22
    /// 信息卡当前实际高度（名字换行后 > `infoRowHeight`）
    private var currentInfoRowHeight: CGFloat = SquareAuthorVC.infoRowHeight

    // MARK: - 初始化

    init(address: String, name: String = "", authorKind: SquareAuthorKind = .person) {
        self.address = address
        self.authorName = name
        self.authorKind = authorKind
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
        view.estimatedRowHeight = 240
        view.rowHeight = UITableView.automaticDimension
        view.estimatedSectionHeaderHeight = 0
        view.estimatedSectionFooterHeight = 0
        view.dataSource = self
        view.delegate = self
        view.register(SquarePostCell.self, forCellReuseIdentifier: SquarePostCell.identifier)
        view.register(SquareAuthorInfoCell.self, forCellReuseIdentifier: SquareAuthorInfoCell.identifier)
        view.mj_header = MJRefreshNormalHeader.init(refreshingBlock: { [weak self] in
            self?.reload(showLoading: false)
        })
        view.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: { [weak self] in
            self?.loadMore()
        })
        return view
    }()

    private lazy var emptyLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("TA 还没有发过帖子"))
    }()

    /// 空态文案容器（挂成 `tableFooterView`）：高度写死 —— `tableFooterView` 只认 frame 高度，
    /// 里面 label 的约束不参与算高。
    private static let emptyFooterHeight: CGFloat = 120
    private lazy var emptyFooter: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: SquareAuthorVC.emptyFooterHeight))
        view.backgroundColor = .clear
        view.addSubview(emptyLab)
        emptyLab.snp.makeConstraints { (m) in
            // 与信息卡保持 80pt 间距：与旧叠层方案的视觉位置一致
            m.top.equalToSuperview().offset(80)
            m.centerX.equalToSuperview()
        }
        return view
    }()

    /// 骨架屏：信息卡下面那块区域（帖子还没回来时先顶住，避免一片白）
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
        self.navigationItem.title = L("作者信息")
        self.xls_navigationBarBackgroundColor = Color_FFFFFF

        self.view.addSubview(tableView)
        // ⚠️ 空态文案**不在 view 上做叠层**，而是挂成 `tableFooterView`（表格内容的一部分）：
        // 叠层要靠 `contentOffset` 手动同步位置，而 MJRefresh 收 header 是**动画改 offset**
        // （offset 模型值瞬间到位、内容用动画滑回去），叠层会立刻跳到终点再等内容跟上，
        // 表现就是下拉刷新时「TA 还没有发过帖子」闪一下（2026-09-24 修，与 SquareMyPostsVC 同一套）。
        // 放进内容里则天然跟着内容滚，不需要自己跟任何动画。
        // 骨架仍旧是叠层（只在首屏加载时出现，那时没有 header 回落动画），最后加 ⇒ 盖在空态之上
        self.view.addSubview(skeletonView)
        tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        // 首屏加载结束前不挂空态 footer
        setEmptyFooterVisible(false)
        // 信息卡下面是帖子区：骨架只盖这一块，上面作者信息（已知数据）直接可见
        skeletonView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            skeletonTopConstraint = m.top.equalToSuperview().offset(currentInfoRowHeight).constraint
        }
        // 刚进来先不出现「上拉显示更多」，等第一页回来再按 hasMore 决定
        tableView.mj_footer?.isHidden = true

        // 关注 / 取关（别处改了同一地址）时刷新信息卡上的按钮
        NotificationCenter.default.addObserver(self, selector: #selector(followStateChanged), name: .squareFollowDidChange, object: nil)
        // 官方号目录更新（学到新的简介 / 粉丝数）时刷新信息卡。
        // ⚠️ 目录每进程只拉一次，请求可能是**别的页面**发起的（或上次进别的作者页时拉的）
        // ⇒ 只有发起方刷新自己的卡片的话，本页会一直停在「…」
        NotificationCenter.default.addObserver(self, selector: #selector(directoryUpdated), name: SquareOfficialDirectoryStore.didUpdateNotification, object: nil)
        // 语言切换：列表里的文案（帖子里的「举报 / 分享 / 身份标签 / 时间」）都要重刷
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: LanguageManager.LanguageChangedNotification, object: nil)

        reload(showLoading: true)
        loadOfficialDirectoryIfNeeded()
    }

    // MARK: - 官方号目录（信息卡「粉丝数」的数据源）

    /// 目录一次最多 100 条（服务端没文档化排序，粉丝少的号可能排在后面）⇒ 按页往下找，最多 5 页（500 个号）
    private static let officialDirectoryMaxPages = 5
    /// 本进程**已经拉完的页数**（0 = 没拉过；失败后重置）：下次进作者页从下一页接着找。
    /// ⚠️ 不能只记「拉过没拉过」：上一页作者是个人号时会早早就停在第一页，
    /// 如果因此把所有作者页都判成「已经拉过」，后面遇到排得靠后的公众号就永远找不到粉丝数了（用户 2026-09-29 报）
    private static var officialDirectoryPagesFetched = 0
    /// 是否正在拉：同一时刻只允许一条请求链（短时间内反复 push 作者页时不重复请求）
    private static var officialDirectoryFetching = false

    /// 拉全量公众号目录（`gold = nil` = 全部正常号），把**别人的**公众号资料（简介 / 粉丝数 / 帖子数）
    /// 存进本地目录 `SquareOfficialDirectoryStore`，信息卡从那里取值。
    ///
    /// ⚠️ 服务端**没有**「按地址查别人公众号资料」的接口（`official/me` 只能查自己）⇒ 这是唯一来源。
    /// ⚠️ 目录默认只出**金标**号（`gold: true`）⇒ 非金标公众号永远拿不到（用户 2026-09-28 报的
    /// 「我关注了该作者，粉丝还是 0」）。这里传 `gold: nil` ⇒ 编成 `gold=1&gold=0` 拉**全部正常号**
    /// （文档 §3：`gold` 可多值；只传 `gold=0` 不是「全部」）。
    /// ⚠️ 以前这里要求 `authorKind == .official` 才拉，但入口带的身份是猜的（评论对象常不带 authorKind）
    /// ⇒ 真公众号也可能一次都不拉（用户 2026-09-29 报的「粉丝不显示数量」）。现在不看身份，
    /// 进来了就拉；本地已经有这个地址的资料就直接用。
    /// 注：服务端目录**只含公众号**，个人作者的粉丝数依旧拿不到（信息卡会隐藏这一项）。
    private func loadOfficialDirectoryIfNeeded() {
        guard !address.isEmpty else { return }
        // 本地已经有这个地址的资料（本页或别的页面学到的）⇒ 不用请求
        guard SquareOfficialDirectoryStore.item(for: address) == nil else { return }
        // 已经有别的页面在拉 ⇒ 等它的广播刷新（见 `directoryUpdated`）
        guard !SquareAuthorVC.officialDirectoryFetching else { return }
        let next = SquareAuthorVC.officialDirectoryPagesFetched + 1
        guard next <= SquareAuthorVC.officialDirectoryMaxPages else { return }
        SquareAuthorVC.officialDirectoryFetching = true
        loadOfficialDirectoryPage(next)
    }

    /// 逐页拉全量目录：**找到本页作者就停**（沿途几页都存进本地目录，别的作者页也能用）。
    /// 每存一页都广播一次，信息卡随到随刷，不用等整个目录拉完。
    private func loadOfficialDirectoryPage(_ page: Int) {
        SquareService.shared.officials(gold: nil, page: page, pageSize: SquareLimits.maxPageSize, success: { [weak self] pageData in
            SquareOfficialDirectoryStore.save(pageData.list)
            // 记进度：下次进别的作者页从下一页接着找
            SquareAuthorVC.officialDirectoryPagesFetched = max(SquareAuthorVC.officialDirectoryPagesFetched, page)
            guard let self = self else {
                SquareAuthorVC.officialDirectoryFetching = false
                return
            }
            // 已经学到这个地址的资料 ⇒ 完成（信息卡已由目录广播刷新）
            guard SquareOfficialDirectoryStore.item(for: self.address) == nil else {
                SquareAuthorVC.officialDirectoryFetching = false
                return
            }
            // 作者身份已经确定是个人号 ⇒ 目录里不可能有它，不再往下翻（省请求）
            let mightBeOfficial = !self.hasLoadedOnce || self.authorKind == .official
            guard pageData.hasMore, page < SquareAuthorVC.officialDirectoryMaxPages, mightBeOfficial else {
                SquareAuthorVC.officialDirectoryFetching = false
                return
            }
            self.loadOfficialDirectoryPage(page + 1)
        }, failure: { failure in
            // 失败解锁 + 清进度（下次进作者页从头再来）；不弹提示（拿不到粉丝数就隐藏这一项）
            SquareAuthorVC.officialDirectoryFetching = false
            SquareAuthorVC.officialDirectoryPagesFetched = 0
            FZMLog("作者页全量官方号目录拉取失败(静默) \(failure.rawCode) \(failure.message)")
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏白底、去掉滚动时出现的底部细线
        applySquareNavBarStyle()
        // 关注名单：第一次进来拉一次（失败只记日志，按钮照常显示，状态按本地已知的）
        SquareFollowStore.refresh { [weak self] in
            self?.reloadInfoRow()
        }
    }

    // MARK: - 数据

    /// 拉第一页（下拉刷新 / 首次进入）
    private func reload(showLoading: Bool) {
        isLoading = true
        // 首次进入 / 列表还没有内容：用骨架屏顶住，不再转圈（已有内容的下拉刷新保持旧内容不动）
        if showLoading && !posts.isEmpty {
            self.showProgress()
        }
        updateEmptyState()
        SquareService.shared.feed(page: 1, kind: .all, authorAddr: address, success: { [weak self] pageData in
            guard let self = self else { return }
            self.isLoading = false
            self.hasLoadedOnce = true
            self.hideProgress()
            self.tableView.mj_header?.endRefreshing()
            self.page = 1
            self.posts = pageData.list
            // 帖子总数：服务端给了 `total` 就用它（列表只有第一页时也能显示真实总数）
            self.authorPostTotal = pageData.total > 0 ? pageData.total : pageData.list.count
            self.hasMore = pageData.hasMore
            self.applyAuthorInfo(from: pageData.list.first)
            self.reloadTable()
            self.updateEmptyState()
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isLoading = false
            self.hasLoadedOnce = true
            self.hideProgress()
            self.tableView.mj_header?.endRefreshing()
            self.updateEmptyState()
            self.showToast(failure.message)
        })
    }

    /// 上拉加载下一页
    private func loadMore() {
        guard !isLoading, hasMore else {
            self.tableView.mj_footer?.endRefreshing()
            return
        }
        isLoading = true
        SquareService.shared.feed(page: page + 1, kind: .all, authorAddr: address, success: { [weak self] pageData in
            guard let self = self else { return }
            self.isLoading = false
            self.tableView.mj_footer?.endRefreshing()
            self.page += 1
            self.hasMore = pageData.hasMore
            self.posts.append(contentsOf: pageData.list)
            self.reloadTable()
            self.updateEmptyState()
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isLoading = false
            self.tableView.mj_footer?.endRefreshing()
            self.showToast(failure.message)
        })
    }

    /// 用接口返回的帖子校正展示名与身份（进页面时带过来的信息可能不全）
    ///
    /// 注意：这里**不能**做局部刷新。首次拉取时是先给 `posts` 赋值、再调用本方法，
    /// 表格内部此刻还记着 section 1 有 0 行，一 `reloadSections` 就会因为「行数对不上」崩溃。
    /// 展示名/身份的变化统一交给调用方后面的 `reloadTable()` 刷新。
    private func applyAuthorInfo(from post: SquarePost?) {
        guard let post = post else { return }
        if !post.authorName.isEmpty {
            authorName = post.authorName
        }
        if post.authorKind != .unknown {
            authorKind = post.authorKind
        }
        // 公众号帖会带当前公众号头像，信息卡优先用它
        if !post.authorAvatar.isEmpty {
            authorAvatar = post.authorAvatar
        }
        // 金标只能从帖子对象学到（服务端没给 authorGold 时恒 false，不会误标）
        if post.authorGold {
            authorGold = true
        }
    }

    /// 只刷新信息卡（section 0 恒为 1 行，局部刷新安全）
    private func reloadInfoRow() {
        guard isViewLoaded, tableView.numberOfSections > 0 else { return }
        tableView.reloadRows(at: [IndexPath.init(row: 0, section: 0)], with: .none)
    }

    /// 关注状态变化（自己的请求或别的页面改了同一地址）
    /// 语言切换：整表重刷一次文案（帖子里的「举报 / 分享 / 标签 / 时间」都是 configure 时取的 L()）。
    /// 走 `reloadTable()` 而不是直接 `reloadData()`：它同时会同步「表格已展示的行数」，
    /// 避免之后局部刷新时报 “Invalid update”
    @objc private func languageChanged() {
        guard isViewLoaded else { return }
        reloadTable()
    }

    @objc private func followStateChanged() {
        reloadInfoRow()
    }

    /// 官方号目录学到新数据（粉丝数 / 简介）⇒ 只刷信息卡
    @objc private func directoryUpdated() {
        reloadInfoRow()
    }

    /// 关注 / 取关：乐观更新，失败回滚（两个接口都幂等）
    private func toggleFollow() {
        guard showsFollowEntry else { return }
        let wasFollowing = SquareFollowStore.isFollowing(address)
        let target = !wasFollowing
        SquareFollowStore.setFollowed(target, address: address)
        reloadInfoRow()
        let success: (SquareFollowResult) -> Void = { [weak self] result in
            guard let self = self else { return }
            SquareFollowStore.setFollowed(result.followed, address: self.address)
            self.reloadInfoRow()
        }
        let failure: (SquareFailure) -> Void = { [weak self] failure in
            guard let self = self else { return }
            SquareFollowStore.setFollowed(wasFollowing, address: self.address)
            self.reloadInfoRow()
            // 404（接口未上线）/ -20411（不能关注自己）：不弹提示（见 isSilentFailure 注释）
            if SquareFollowStore.isSilentFailure(failure) {
                FZMLog("关注/取关失败(静默) \(failure.rawCode)")
            } else {
                self.showToast(failure.message)
            }
        }
        if target {
            SquareService.shared.follow(targetAddr: address, success: success, failure: failure)
        } else {
            SquareService.shared.unfollow(targetAddr: address, success: success, failure: failure)
        }
    }

    /// 整体刷新，同时记录表格当前展示的帖子数量
    private func reloadTable() {
        presentedPostCount = posts.count
        tableView.reloadData()
    }

    /// 只刷新一行（表格状态和数据源对不上时退回整体刷新，避免崩溃）
    private func reloadPostRow(at index: Int) {
        guard index >= 0, index < posts.count, index < presentedPostCount else {
            reloadTable()
            return
        }
        tableView.reloadRows(at: [IndexPath.init(row: index, section: 1)], with: .none)
    }

    private func updateEmptyState() {
        // 空态：**刷新过程中不要来回切**（列表本来就空时，下拉刷新会「闪一下」）
        let isEmpty = posts.isEmpty
        if !isLoading || !isEmpty {
            setEmptyFooterVisible(isEmpty)
        }
        // 「上拉显示更多」：第一页回来过、还有下一页、且列表里有内容才给
        tableView.mj_footer?.isHidden = !hasLoadedOnce || !hasMore || posts.isEmpty
        updateSkeletonState()
        syncOverlayPositions()
    }

    /// 骨架屏显隐：**只在首次加载**、且一条帖子都还没有时顶骨架。
    /// 下拉刷新时不再顶骨架：那是固定叠层，会把被顶下去的信息卡盖住。
    private func updateSkeletonState() {
        let shouldShow = !hasLoadedOnce && isLoading && posts.isEmpty
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

    /// 让骨架跟着列表内容一起移动（信息卡占 `currentInfoRowHeight`，贴在它下面）
    /// 注意：空态文案已改成 `tableFooterView`（内容的一部分，不需要同步）
    private func syncOverlayPositions() {
        let contentTop = currentInfoRowHeight - tableView.contentOffset.y
        skeletonTopConstraint?.update(offset: contentTop)
    }

    /// 名字换行后同步信息卡高度（每多一行 +`nameLineHeight`）。
    /// ⚠️ 与「我的信息」页同一套注意事项：本方法是在 `cellForRowAt` 里调的，
    /// **高度没变就不要 reload**（成环会出事）；确实变高时用 `async` 推迟到本轮布局之后再刷
    private func syncInfoRowHeight(cell: SquareAuthorInfoCell) {
        let width = SquareAuthorInfoCell.nameAvailableWidth(showsFollow: showsFollowEntry)
        let lines = cell.nameLineCount(forWidth: width)
        let height = SquareAuthorVC.infoRowHeight + CGFloat(lines - 1) * SquareAuthorVC.nameLineHeight
        guard abs(height - currentInfoRowHeight) > 0.5 else { return }
        currentInfoRowHeight = height
        skeletonTopConstraint?.update(offset: height - tableView.contentOffset.y)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // ⚠️ 只更新行高（`beginUpdates/endUpdates`），**不要** `reloadRows`：
            //    重建 cell 会把整张信息卡重画一遍（头像重贴、文字重排），看起来就是「闪 / 抖」
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            self.updateEmptyState()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncOverlayPositions()
    }

    // MARK: - 交互

    private func openDetail(_ post: SquarePost) {
        guard post.id > 0 else { return }
        let vc = SquarePostDetailVC.init(postId: post.id)
        vc.hidesBottomBarWhenPushed = true
        vc.onPostUpdated = { [weak self] updated in
            self?.applyUpdatedPost(updated)
        }
        vc.onPostDeleted = { [weak self] deletedId in
            self?.posts.removeAll { $0.id == deletedId }
            self?.reloadTable()
            self?.updateEmptyState()
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }

    private func applyUpdatedPost(_ post: SquarePost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
        reloadPostRow(at: index)
    }

    private func toggleLike(_ post: SquarePost) {
        guard !likingPostIds.contains(post.id) else { return }
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        likingPostIds.insert(post.id)
        // 乐观更新，失败回滚
        let previousLiked = posts[index].liked
        let previousCount = posts[index].likeCount
        posts[index].liked = !previousLiked
        posts[index].likeCount = max(previousCount + (previousLiked ? -1 : 1), 0)
        reloadPostRow(at: index)

        SquareService.shared.toggleLike(post: post, success: { [weak self] result in
            guard let self = self else { return }
            self.likingPostIds.remove(post.id)
            guard let index = self.posts.firstIndex(where: { $0.id == post.id }) else { return }
            self.posts[index].liked = result.liked
            self.posts[index].likeCount = result.likeCount
            self.reloadPostRow(at: index)
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.likingPostIds.remove(post.id)
            if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                self.posts[index].liked = previousLiked
                self.posts[index].likeCount = previousCount
                self.reloadPostRow(at: index)
            }
            self.showToast(failure.message)
        })
    }

    /// 自己的帖子才给「三个点」入口（编辑 / 删除 / 关评论）
    private func showPostActions(_ post: SquarePost) {
        SquarePostActionSheet.present(from: self, post: post, onUpdated: { [weak self] updated in
            self?.applyUpdatedPost(updated)
        }, onDeleted: { [weak self] deletedId in
            guard let self = self else { return }
            self.posts.removeAll { $0.id == deletedId }
            self.reloadTable()
            self.updateEmptyState()
        }, onEdited: { [weak self] in
            self?.reload(showLoading: false)
        })
    }

    /// 图片浏览（列表里点图）
    private func showPhotoBrowser(urls: [String], index: Int, from imageView: UIImageView) {
        SquarePhotoPresenter.present(urls: urls, index: index, from: imageView, in: self)
    }
}

// MARK: - 列表

extension SquareAuthorVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: SquareAuthorInfoCell.identifier, for: indexPath) as! SquareAuthorInfoCell
            cell.selectionStyle = .none
            let isGold = authorGold || (SquareOfficialDirectoryStore.item(for: address)?.gold ?? false)
            cell.configure(address: address,
                           name: authorName,
                           authorKind: authorKind,
                           authorAvatar: authorAvatar,
                           officialIntro: currentOfficialIntro,
                           followerCount: currentFollowerCount,
                           postCount: currentPostCount,
                           isGold: isGold,
                           showsFollow: showsFollowEntry,
                           isFollowing: SquareFollowStore.isFollowing(address),
                           // 「未认证公众号」只在**作者身份确定**后才显示：入口带的类型是猜的
                           // （评论不带 authorKind），先顶这句话会让真公众号闪一下错误文案（用户 2026-09-29）
                           showsUnverifiedOfficial: hasLoadedOnce && authorKind == .person)
            // 名字太长会换行（不限行数、不截断）⇒ 卡片高度跟着长高
            // ⚠️ 必须放在 configure **之后**：名字文本已设好，`sizeThatFits` 才能量准
            syncInfoRowHeight(cell: cell)
            cell.onFollowTapped = { [weak self] in
                self?.toggleFollow()
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: SquarePostCell.identifier, for: indexPath) as! SquarePostCell
        guard indexPath.row < posts.count else { return cell }
        let post = posts[indexPath.row]
        // 与广场流保持一致：昵称过长时换行完整显示，标签在昵称下面另起一行
        cell.configure(post, cellWidth: k_ScreenWidth, wrapsLongName: true)
        cell.onLikeTapped = { [weak self] post in
            self?.toggleLike(post)
        }
        cell.onCommentTapped = { [weak self] post in
            self?.openDetail(post)
        }
        cell.onTapImage = { [weak self] post, index, imageView in
            self?.showPhotoBrowser(urls: post.mediaUrls, index: index, from: imageView)
        }
        cell.onMoreTapped = { [weak self] post in
            self?.showPostActions(post)
        }
        // 已经在作者页了，头像不再跳转，避免自己套自己
        cell.onAvatarTapped = nil
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1, indexPath.row < posts.count else { return }
        openDetail(posts[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            // 名字换行时卡片要长高（`currentInfoRowHeight` 由 `syncInfoRowHeight` 维护）
            return currentInfoRowHeight
        }
        guard indexPath.row < posts.count else { return 0 }
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : k_ScreenWidth
        // ⚠️ 必须与 cellForRowAt 的 configure 同参，否则行高会算小
        return SquarePostCell.height(for: posts[indexPath.row], width: width, wrapsLongName: true)
    }
}

// MARK: - 作者信息卡

/// 作者信息卡：头像 / 昵称（+「我」「公众号」标签）/ 短地址
final class SquareAuthorInfoCell: UITableViewCell {

    static let identifier = "SquareAuthorInfoCell"

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 28
        view.backgroundColor = Color_F6F7F8
        view.image = #imageLiteral(resourceName: "friend_chat_avatar")
        return view
    }()

    private lazy var nameLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()

    /// 身份标签（我 / 官方号 / 公众号），没有身份时不占宽度
    private lazy var tagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_FFFFFF, textAlignment: .center, text: nil)
        // 默认蓝色（「我」/「公众号」）；平台官方号在 configure 里换成金橙
        lab.backgroundColor = Color_Identity_Tag
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        lab.isHidden = true
        return lab
    }()

    private var tagWidthConstraint: SnapKit.Constraint?
    /// 名字宽度（= 可用宽度，**等式**）：
    /// ⚠️ 不能再靠 `right <= 让位值` 这种不等式 + label 自己的 intrinsic 宽度：
    /// 多行 label 的 intrinsic 宽度会随布局时刻变化（首帧/滑动重配时被写窄）⇒ 名字一会儿两行、一会儿一行
    /// （用户 2026-09-30 录屏：滑动一下再取消，昵称从两行变一行）。钉死宽度就彻底稳定了
    private var nameWidthConstraint: SnapKit.Constraint?

    /// 金标（金标公众号才显示）：**叠在头像右下角**（用户 2026-09-30：「把金标图标放到头像右下角，
    /// 不要放到昵称后面」⇒ 这样它完全不占名字 / 标签行的宽度）。
    /// 样式与金标墙那张一致：橙底圆 + 白色实心五角星（`star.circle.fill`）。
    /// ⚠️ 白色圆底**不能删**：该符号的星是**镂空**的，没有白底时会透出头像、星就不是白的了
    private lazy var goldView: UIImageView = {
        let config = UIImage.SymbolConfiguration.init(pointSize: 13, weight: .bold)
        let view = UIImageView.init(image: UIImage.init(systemName: "star.circle.fill", withConfiguration: config)?.withRenderingMode(.alwaysTemplate))
        view.tintColor = Color_Gold
        view.contentMode = .scaleAspectFit
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 7.5
        view.clipsToBounds = true
        return view
    }()

    /// 卡片右侧「给关注按钮让位」的约束（昵称 / 金标后的身份标签 / 复制地址按钮 / 粉丝数）：
    /// 值随 `showsFollow` 在「按钮宽 + 8」与 0 之间切。
    /// ⚠️ **身份标签也必须在里面**：它跟在名字（金标）右边，不给它右边界的话，
    /// 名字一长标签就会被顶到关注按钮下面 —— 看起来就是「名字和关注按钮重叠」（用户 2026-09-28 报的现象）
    private var rightInsetConstraints = [SnapKit.Constraint]()

    /// 关注 / 已关注（`showsFollow` 由页面按 `SquareFollowStore` 决定）
    /// ⚠️ 宽度按当前语言文案算（`SquareFollowButtonSize`），否则英文 "Following" 会被截断
    private lazy var followBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.titleLabel?.font = .mediumFont(14)
        btn.layer.cornerRadius = 14
        btn.clipsToBounds = true
        btn.isHidden = true
        btn.addTarget(self, action: #selector(followTap), for: .touchUpInside)
        return btn
    }()

    /// 点关注 / 取关（状态与请求由页面负责，cell 只回调）
    var onFollowTapped: (() -> Void)?

    @objc private func followTap() {
        onFollowTapped?()
    }

    private lazy var descLab: UILabel = {
        return UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()

    /// 公众号简介（仅公众号且缓存里有才显示；单行省略，不动信息卡固定高度）
    private lazy var introLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.lineBreakMode = .byTruncatingTail
        lab.isHidden = true
        return lab
    }()

    /// 帖子数（金标目录学到的；**0 也显示 0**，与「我的信息」页一致）
    private lazy var postsLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(18), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()

    /// 粉丝数（同上一行：数字大 + 说明小；**数据没到就整项隐藏**，不用「未认证公众号」占位）
    private lazy var fansLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(18), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()

    /// 卡片底部标签栏（当前只有「内容」，带下划线），贴在信息卡**最底部**、横跨整卡。
    /// 以后要加新标签只改 `tabTitles()`，布局 / 下划线 / 选中态都跟着走
    private lazy var tabBar: SquareAuthorTabBar = {
        let view = SquareAuthorTabBar()
        view.onSelect = { [weak self] index in
            self?.onTabSelected?(index)
        }
        return view
    }()

    /// 点了某个标签（当前只有「内容」一项，先留入口：以后按索引切列表内容）
    var onTabSelected: ((Int) -> Void)?

    /// 标签栏的标签（**以后加新标签只改这里**，例如 [L("内容"), L("回复")]）
    private static func tabTitles() -> [String] {
        return [L("内容")]
    }

    /// 地址右侧的复制按钮。
    /// 卡上展示的是**短地址**，直接用不了（加好友要完整地址），所以这里复制的是完整 `address`。
    private lazy var copyAddressBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        let config = UIImage.SymbolConfiguration.init(pointSize: 12, weight: .regular)
        btn.setImage(UIImage.init(systemName: "doc.on.doc", withConfiguration: config)?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_8A97A5
        btn.enlargeClickEdge(10, 10, 10, 10)
        btn.addTarget(self, action: #selector(copyAddressTap), for: .touchUpInside)
        return btn
    }()

    /// 要复制的完整地址（卡上显示的是 `address.shortAddress`）
    private var copyAddressText = ""

    @objc private func copyAddressTap() {
        guard !copyAddressText.isEmpty else { return }
        UIPasteboard.general.string = copyAddressText
        APP.shared().showToast(L("地址已复制"))
    }

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
        self.contentView.addSubview(copyAddressBtn)
        self.contentView.addSubview(postsLab)
        self.contentView.addSubview(fansLab)
        self.contentView.addSubview(followBtn)
        // 底部标签栏：最后加（只是位置在最下面，不与别的视图互相引用）
        self.contentView.addSubview(tabBar)

        // 名字：**不限行数、不截断**（用户 2026-09-30：「右边那么空为什么还换行」/「不要截取文字」）。
        // 宽度上限由约束给定（= 关注按钮左侧 - 8），放得下就一行，放不下才换行，绝不会出现「…」
        nameLab.numberOfLines = 0
        nameLab.lineBreakMode = .byWordWrapping

        avatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            // 头像在「标签栏以上」的那块内容区里居中（`-height/2` 抵消掉底部标签栏的高度），
            // 这样加了标签栏之后头像与名字/统计行的相对位置不变
            m.centerY.equalToSuperview().offset(-SquareAuthorTabBar.height / 2)
            m.size.equalTo(CGSize(width: 56, height: 56))
        }
        // 底部标签栏：横跨整卡、贴底（高度固定为 `SquareAuthorTabBar.height`，卡片高度里已算进它）
        tabBar.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(SquareAuthorTabBar.height)
        }
        // 关注按钮 / 右侧「让位」宽度：按当前语言文案算（中文 = 62pt；英文要容纳 "Following" ≈ 79pt）
        let followWidth = SquareFollowButtonSize.width(font: .mediumFont(14))
        // 卡片内容改成**从上往下排**（用户 2026-09-28：短地址下面要再加一行「帖子数 + 粉丝数」，
        // 卡片变高见 `SquareAuthorVC.infoRowHeight`，不能再按中线锚定）
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(avatarView.snp.right).offset(12)
            m.top.equalToSuperview().offset(16)
            // 名字宽度**钉死**（先按“不显示关注按钮”给个较大值，`applyFollowState` 里会按实际状态校正）：
            // 这样 label 不会被压窄，也不会因布局时机不同而换行结果变化
            nameWidthConstraint = m.width.equalTo(SquareAuthorInfoCell.nameAvailableWidth(showsFollow: false)).constraint
        }
        nameLab.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLab.preferredMaxLayoutWidth = SquareAuthorInfoCell.nameAvailableWidth(showsFollow: false)
        // 金标：紧贴昵称右侧（金标号才有）。
        // ⚠️ 它自己也要给关注按钮让位：名字把可用宽度用满时，金标不能跑到按钮下面
        // （身份标签已挪到第二行，它现在是名字行最右的元素）
        // 金标：**叠在头像右下角**（用户 2026-09-30 指定）——完全不占名字行 / 标签行的宽度。
        // 位置与金标墙 `SquareGoldWallCell` 同一套：头像 right +2 / bottom +2，15×15
        goldView.snp.makeConstraints { (m) in
            m.right.equalTo(avatarView).offset(2)
            m.bottom.equalTo(avatarView).offset(2)
            m.size.equalTo(CGSize(width: 15, height: 15))
        }
        // 身份标签（我 / 官方号 / 公众号）：跟在金标之后。
        // ⚠️ 必须给它一条右边界（与昵称用同一条让位）：名字太长时昵称会被压缩，标签不能被顶到
        // 关注按钮下面（漏了这条就是「名字长和按钮重叠」）
        // 身份标签（我 / 官方号 / 公众号）：放在**第二行**，跟在「短地址 + 复制按钮」后面。
        // ⚠️ 以前它跟在名字右边：名字行得同时塞下「名字 + 金标 + 标签」，英文下名字只剩 ~145pt，
        // 「四季发财SJFC红包」会被截成「四季发财SJFC…」（用户 2026-09-28 报的「昵称显示不全」）。
        // 挪到第二行后名字行只剩「名字 + 金标」，可用宽度回到 ~220pt。
        tagLab.snp.makeConstraints { (m) in
            m.left.equalTo(copyAddressBtn.snp.right).offset(8)
            m.centerY.equalTo(descLab)
            m.height.equalTo(16)
            tagWidthConstraint = m.width.equalTo(0).constraint
            rightInsetConstraints.append(m.right.lessThanOrEqualToSuperview().offset(-(15 + followWidth + 8)).constraint)
        }
        // 第二行的元素（短地址 / 复制 / 身份标签 / 金标）过长时允许被压，别去顶名字的可用宽度
        tagLab.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        followBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            // 顶部与昵称（名字）对齐（用户 2026-09-28）：卡片里名字上方本就空着，而下方还有
            // 副标题 / 粉丝数，按钮垂直居中会整块往下压，看着像把粉丝数挤掉了
            m.top.equalTo(nameLab.snp.top)
            m.size.equalTo(CGSize(width: followWidth, height: 28))
        }
        // 复制按钮：紧跟在短地址右边（注意两个视图都已 addSubview 后再建约束）
        copyAddressBtn.snp.makeConstraints { (m) in
            m.left.equalTo(descLab.snp.right).offset(6)
            // 兜底：地址异常长时不许把按钮推出卡片外（此时由 label 自己截断），也不要跑到关注按钮下面
            rightInsetConstraints.append(m.right.lessThanOrEqualToSuperview().offset(-(15 + followWidth + 8)).constraint)
            m.centerY.equalTo(descLab)
            m.size.equalTo(CGSize(width: 18, height: 18))
        }
        descLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            // 右边给复制按钮让位，地址过长时自己在按钮前截断
            m.right.lessThanOrEqualTo(copyAddressBtn.snp.left).offset(-6)
            m.top.equalTo(nameLab.snp.bottom).offset(6)
        }
        // 公众号简介：紧跟在统计行下面（简介为空时隐藏，不影响原有布局）
        introLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.lessThanOrEqualToSuperview().offset(-15)
            m.top.equalTo(postsLab.snp.bottom).offset(4)
        }
        // 统计行（用户 2026-09-28）：**帖子数 + 粉丝数**，放在**短地址下面一行**，为 0 也显示 0。
        // 样式与「我的信息」页的流量卡一致：数字（18 medium 深色）+ 说明（12 regular 次要色）
        postsLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.top.equalTo(descLab.snp.bottom).offset(8)
            rightInsetConstraints.append(m.right.lessThanOrEqualToSuperview().offset(-(15 + followWidth + 8)).constraint)
        }
        fansLab.snp.makeConstraints { (m) in
            // 两种位置二选一（`applyStatsLayout`）：
            // ① 跟在帖子数右边（默认）  ② 帖子数没拿到时左对齐到名字
            fansLeadingAfterPostsConstraint = m.left.equalTo(postsLab.snp.right).offset(16).constraint
            fansLeadingAlignedWithNameConstraint = m.left.equalTo(nameLab).constraint
            m.centerY.equalTo(postsLab)
            rightInsetConstraints.append(m.right.lessThanOrEqualToSuperview().offset(-(15 + followWidth + 8)).constraint)
        }
        fansLeadingAlignedWithNameConstraint?.deactivate()
    }

    /// 统计行的两种排法（去抖）
    private var statsFansAlone = false
    private var fansLeadingAfterPostsConstraint: SnapKit.Constraint?
    private var fansLeadingAlignedWithNameConstraint: SnapKit.Constraint?

    /// 粉丝数是否「单独显示」（帖子数还没拿到）：单独时左对齐到名字，否则跟在帖子数右边
    private func applyStatsLayout(fansAlone: Bool) {
        guard statsFansAlone != fansAlone else { return }
        statsFansAlone = fansAlone
        if fansAlone {
            fansLeadingAfterPostsConstraint?.deactivate()
            fansLeadingAlignedWithNameConstraint?.activate()
        } else {
            fansLeadingAlignedWithNameConstraint?.deactivate()
            fansLeadingAfterPostsConstraint?.activate()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 名字可用宽度（与约束一致：头像右侧 → 「关注按钮左侧 - 8」）：
    /// `15(边距) + 56(头像) + 12(间隙)` 之后，到 `superview.right - (15 + 关注按钮宽 + 8)`
    static func nameAvailableWidth(showsFollow: Bool) -> CGFloat {
        let followWidth = showsFollow ? SquareFollowButtonSize.width(font: .mediumFont(14)) : 0
        return k_ScreenWidth - 15 - 56 - 12 - (15 + followWidth + 8)
    }

    /// 当前名字在这个宽度下占几行（用 label 自己的引擎量，与渲染同一套；至少 1 行）。
    /// 卡片高度按它加高（见 `SquareAuthorVC.syncInfoRowHeight`）
    func nameLineCount(forWidth width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let fit = nameLab.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
        return max(1, Int(ceil(fit / max(1, nameLab.font.lineHeight))))
    }

    /// 名称规则与列表一致：名字为空或名字本身就是地址时显示短地址；标签「我」优先于「公众号」
    /// - Parameter authorAvatar: 服务端带过来的作者头像（公众号帖才有），非空时优先使用
    /// - Parameter isGold: 作者是否是金标公众号
    /// - Parameter followerCount: 粉丝数（`nil` = 还没拿到 / 拿不到 ⇒ 这一项**不显示**）
    /// - Parameter postCount: 帖子数（`nil` = 还没拿到 ⇒ **整项不显示**；0 也显示 0）
    /// - Parameter showsFollow: 是否展示关注按钮（页面按「不是自己」判定，名单未拉到时也展示）
    /// - Parameter showsUnverifiedOfficial: 是否显示「未认证公众号」（**作者身份已确定**且不是公众号时才给 true）
    func configure(address: String, name: String, authorKind: SquareAuthorKind, authorAvatar: String = "", officialIntro: String = "", followerCount: Int? = nil, postCount: Int? = nil, isGold: Bool = false, showsFollow: Bool = false, isFollowing: Bool = false, showsUnverifiedOfficial: Bool = false) {
        nameLab.text = SquareDisplayName.of(name: name, address: address)

        let isMine = !address.isEmpty && address == LoginUser.shared().address
        // 「官方号」只给平台官方号（唯一）；其它认证号是「公众号」
        let isPlatformOfficial = address == SquareOfficialAccount.platform
        let tag = isMine ? L("我") : (authorKind == .official ? (isPlatformOfficial ? L("官方号") : L("公众号")) : "")
        tagLab.text = tag.isEmpty ? nil : tag
        tagLab.isHidden = tag.isEmpty
        tagLab.backgroundColor = isPlatformOfficial ? Color_Official_Tag : Color_Identity_Tag
        let tagFont = tagLab.font ?? .regularFont(10)
        let tagWidth = tag.isEmpty ? 0 : (tag as NSString).size(withAttributes: [.font: tagFont]).width + 12
        tagWidthConstraint?.update(offset: ceil(tagWidth))

        // 金标（《App增量-公众号金标》§4）：叠在头像右下角，只控显隐（不再有宽度 0/14 切换）
        goldView.isHidden = !isGold

        applyFollowState(showsFollow: showsFollow, isFollowing: isFollowing)

        // 平台官方号（square-official）不是钱包地址：不要截成「squar…cial」那种怪样子，也不给复制地址
        // （`isPlatformOfficial` 上面已经判过，这里直接复用，不要再声明一次）
        descLab.text = isPlatformOfficial ? L("官方账号") : address.shortAddress
        copyAddressText = isPlatformOfficial ? "" : address
        copyAddressBtn.isHidden = isPlatformOfficial

        // 公众号简介：本地缓存里有就显示（后端提供查别人资料的接口后，写进同一个 store 即可）
        let intro = officialIntro.trimmingCharacters(in: .whitespacesAndNewlines)
        introLab.text = intro.isEmpty ? nil : intro
        introLab.isHidden = intro.isEmpty
        // 统计行：帖子数 + 粉丝数。
        // - 帖子数：用 `feed` 的 `total`（个人号也准），`nil` = 还没拿到
        // - 粉丝数：**只有公众号拿得到**（官方号目录只含「已入驻公众号」，个人号不在里面）
        // ⚠️ 两项都是「**拿到数据才显示**」（用户 2026-09-30）：拿不到就整项不显示，
        //    不再拿「…」当占位（否则会先显示「… 帖子」再跳成真实数字）
        let showsPosts = postCount != nil
        postsLab.isHidden = !showsPosts
        postsLab.attributedText = postCount.map { SquareAuthorInfoCell.statText(value: $0, title: "帖子") }
        // ⚠️ 用户 2026-09-29：「未认证公众号」不能当**占位**用 —— 入口列表对作者身份的认知是猜的
        // （评论对象常不带 authorKind），先顶这句话会让真公众号先闪一下错误文案，再变成粉丝数。
        // 现在三种情况分开：拿到粉丝数就显示；身份确实确定不是公众号才显示「未认证公众号」；
        // 其余（数据还没到）整项**隐藏**，等数据到了再显示。
        if let followerCount = followerCount {
            fansLab.isHidden = false
            fansLab.attributedText = SquareAuthorInfoCell.statText(value: followerCount, title: "粉丝")
        } else if showsUnverifiedOfficial {
            fansLab.isHidden = false
            fansLab.attributedText = NSAttributedString(
                string: L("未认证公众号"),
                attributes: [.font: UIFont.regularFont(12), .foregroundColor: Color_8A97A5])
        } else {
            fansLab.isHidden = true
            fansLab.attributedText = nil
        }
        // 帖子数还没到、但粉丝数要显示时，粉丝数左对齐到名字 ——
        // 否则它会停在「帖子数」那个（隐藏但仍占位的）label 右边，看着像凭空右移
        applyStatsLayout(fansAlone: !showsPosts && !fansLab.isHidden)
        configureAvatar(address: address, authorAvatar: authorAvatar)
        // 标签文案跟着语言走（内容没变时 `setTitles` 直接返回，不会重建按钮）
        tabBar.setTitles(SquareAuthorInfoCell.tabTitles())

        #if DEBUG
        // 名字排版自检（用户 2026-09-30 报「右边那么空还要换行」）。
        // ⚠️ 这里**不要**调 `layoutIfNeeded()`：它会在 `cellForRowAt` 期间强制布局，引起抖动
        let debugFont = nameLab.font ?? .mediumFont(16)
        let debugText = nameLab.text ?? ""
        let debugSingleLine = ceil((debugText as NSString).size(withAttributes: [.font: debugFont]).width)
        let debugAvailable = SquareAuthorInfoCell.nameAvailableWidth(showsFollow: !followBtn.isHidden)
        FZMLog("作者信息名字排版 服务端名字=[\(name)] 显示=[\(debugText)] 单行需宽=\(Int(debugSingleLine)) 可用宽=\(Int(debugAvailable)) 行数=\(nameLineCount(forWidth: debugAvailable)) 关注按钮显示=\(!followBtn.isHidden) 金标=\(goldView.isHidden ? 0 : 15)")
        #endif
    }

    /// 统计项文案：数字（18 medium 深色）+ 说明（12 regular 次要色），与「我的信息」页的流量卡同一套。
    /// ⚠️ 只在**真的拿到数值**时调用（用户 2026-09-30：拿不到就整项不显示，不要再拿「…」当占位）
    private static func statText(value: Int, title: String) -> NSAttributedString {
        let text = NSMutableAttributedString(string: "\(value)",
                                             attributes: [.font: UIFont.mediumFont(18), .foregroundColor: Color_24374E])
        text.append(NSAttributedString(string: " " + L(title),
                                      attributes: [.font: UIFont.regularFont(12), .foregroundColor: Color_8A97A5]))
        return text
    }

    /// 关注按钮态：未关注 = 主题色实底；已关注 = 浅底 + 次要文字（点一下取消关注）
    private func applyFollowState(showsFollow: Bool, isFollowing: Bool) {
        followBtn.isHidden = !showsFollow
        // 右侧让位：按钮宽度按当前语言算（英文 "Following" 更宽）；不显示时不留位
        let inset = showsFollow ? -(15 + SquareFollowButtonSize.width(font: .mediumFont(14)) + 8) : -15
        rightInsetConstraints.forEach { $0.update(offset: inset) }
        // 名字宽度也按同一份让位值钉死（等式，不靠不等式 + intrinsic）
        let nameWidth = SquareAuthorInfoCell.nameAvailableWidth(showsFollow: showsFollow)
        nameWidthConstraint?.update(offset: nameWidth)
        nameLab.preferredMaxLayoutWidth = nameWidth
        guard showsFollow else { return }
        followBtn.setTitle(isFollowing ? L("已关注") : L("关注"), for: .normal)
        followBtn.setTitleColor(isFollowing ? Color_8A97A5 : Color_FFFFFF, for: .normal)
        followBtn.backgroundColor = isFollowing ? Color_F6F7F8 : Color_Theme
    }

    /// 当前头像的「身份」（只按作者地址）：同一个人保留当前头像，换人才重置占位图
    private var avatarIdentity: String?
    /// 当前展示的头像地址（用来判断要不要重新加载，避免重复赋值把已经显示的头像换成占位图）
    private var currentAvatarURL = ""

    /// 头像：优先用服务端带的作者头像（公众号帖），为空再按地址解析（本地登录信息 / 通讯录 / 链上）
    /// 地址没变就直接跳过，避免刷新时「占位图 → 真头像」闪一下
    private func configureAvatar(address: String, authorAvatar: String) {
        // 身份只看作者地址：同一个人换头像地址时不重置（交给 showAvatar 平滑替掉）
        let identity = address.isEmpty ? "srv:\(authorAvatar)" : "addr:\(address)"
        if identity != self.avatarIdentity {
            self.avatarIdentity = identity
            self.currentAvatarURL = ""
            avatarView.image = #imageLiteral(resourceName: "friend_chat_avatar")
        }

        if !authorAvatar.isEmpty, let link = URL.init(string: authorAvatar) {
            showAvatar(urlString: authorAvatar, link: link)
            return
        }
        guard !address.isEmpty else { return }

        let own = LoginUser.shared().avatarUrl
        if address == LoginUser.shared().address, !own.isEmpty, let link = URL.init(string: own) {
            showAvatar(urlString: own, link: link)
            return
        }

        SquareAvatarResolver.avatarURL(for: address) { [weak self] url in
            guard let self = self, let url = url, let link = URL.init(string: url) else { return }
            self.showAvatar(urlString: url, link: link)
        }
    }

    /// 加载头像：地址没变就跳过（已经显示的就是这张）；变了也拿当前图当占位，不闪
    private func showAvatar(urlString: String, link: URL) {
        guard !urlString.isEmpty, urlString != currentAvatarURL else { return }
        currentAvatarURL = urlString
        let placeholder = avatarView.image ?? #imageLiteral(resourceName: "friend_chat_avatar")
        SquareAvatarLoader.apply(to: avatarView, url: link, key: urlString, placeholder: placeholder) { [weak self] success in
            guard let self = self, !success, self.currentAvatarURL == urlString else { return }
            // 加载失败：清掉记录，下次重新配置时重试
            self.currentAvatarURL = ""
        }
    }
}

// MARK: - 内容标签栏

/// 作者信息卡底部的标签栏（当前只有「内容」一项，带下划线指示条，效果对齐币安广场）。
/// **为以后加新标签留好位置**：往 `SquareAuthorInfoCell.tabTitles()` 里加一项即可 ——
/// 按钮横向排布、间距、下划线、选中态都会自动跟着走，不需要动这里的布局代码。
final class SquareAuthorTabBar: UIView {

    /// 标签栏高度（`SquareAuthorVC.infoRowHeight` 把它算进信息卡高度）
    static let height: CGFloat = 44
    /// 下划线指示条高度（细条，贴在文字下方）
    private static let indicatorHeight: CGFloat = 3
    /// 第一个标签距左边距（与信息卡其它内容一致）
    private static let leadingInset: CGFloat = 15
    /// 标签之间的间距（加第二个标签时才会用到）
    private static let itemSpacing: CGFloat = 28
    /// 标签文字：**选中 / 未选中只换颜色、不换字号** ⇒ 下划线宽度不会因选中而跳动
    private static let titleFont = UIFont.mediumFont(15)

    /// 选中项变化（页面按索引切内容；当前只有一项，先留入口）
    var onSelect: ((Int) -> Void)?

    private(set) var selectedIndex = 0

    private var titles = [String]()
    private var buttons = [UIButton]()

    /// 下划线指示条：宽度 / 位置都吊在选中项的文字上（文字宽度变了也会自动跟）
    private lazy var indicator: UIView = {
        let view = UIView()
        view.backgroundColor = Color_Theme
        view.layer.cornerRadius = SquareAuthorTabBar.indicatorHeight / 2
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()

    /// 底部分割线（用户 2026-09-30：加在「内容」这一行的最底部、下划线下面）。
    /// 颜色用工程统一的分割线色 `Color_E6EAEE`；**不要这条线就把下面 addSubview 的两行删掉即可**
    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()

    private var indicatorCenterConstraint: SnapKit.Constraint?
    private var indicatorWidthConstraint: SnapKit.Constraint?

    init(titles: [String] = [L("内容")]) {
        super.init(frame: .zero)
        backgroundColor = Color_FFFFFF
        addSubview(indicator)
        addSubview(bottomLine)
        // 底部分割线：横跨整条、贴最底（0.5pt 细线）
        bottomLine.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
        // 指示条只有「高度 + 贴底」是常量约束，横向位置在 `moveIndicator(to:)` 里挂到选中项文字上
        indicator.snp.makeConstraints { (m) in
            m.height.equalTo(SquareAuthorTabBar.indicatorHeight)
            // 抬高一点，别压到分割线上
            m.bottom.equalToSuperview().offset(-6)
        }
        setTitles(titles)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 更新标签列表（内容没变直接返回：`configure` 每次都会调，避免反复重建按钮）
    func setTitles(_ titles: [String]) {
        guard titles != self.titles else { return }
        self.titles = titles
        rebuildItems()
    }

    /// 选中某一项（`notify = true` 时回调 `onSelect`）
    func select(index: Int, notify: Bool = false) {
        guard index >= 0, index < buttons.count else { return }
        selectedIndex = index
        for (i, button) in buttons.enumerated() {
            button.setTitleColor(i == index ? Color_24374E : Color_8A97A5, for: .normal)
        }
        moveIndicator(to: buttons[index])
        if notify { onSelect?(index) }
    }

    @objc private func itemTap(_ sender: UIButton) {
        select(index: sender.tag, notify: true)
    }

    /// 按 `titles` 重建按钮：第一个贴左边距，其余跟在前一个右边 `itemSpacing`
    private func rebuildItems() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        indicatorCenterConstraint?.deactivate()
        indicatorWidthConstraint?.deactivate()
        indicatorCenterConstraint = nil
        indicatorWidthConstraint = nil
        indicator.isHidden = true

        guard !titles.isEmpty else { return }
        selectedIndex = min(selectedIndex, titles.count - 1)
        var previous: UIButton?
        for (index, title) in titles.enumerated() {
            let button = UIButton.init(type: .custom)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = SquareAuthorTabBar.titleFont
            button.setTitleColor(Color_8A97A5, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(itemTap(_:)), for: .touchUpInside)
            addSubview(button)
            buttons.append(button)
            button.snp.makeConstraints { (m) in
                // 文字略高于栏中心：下面要给下划线留位置
                m.centerY.equalToSuperview().offset(-SquareAuthorTabBar.indicatorHeight)
                if let previous = previous {
                    m.left.equalTo(previous.snp.right).offset(SquareAuthorTabBar.itemSpacing)
                } else {
                    m.left.equalToSuperview().offset(SquareAuthorTabBar.leadingInset)
                }
            }
            previous = button
        }
        select(index: selectedIndex)
    }

    /// 把下划线挪到某个标签的文字正下方（宽度跟着文字走）
    private func moveIndicator(to button: UIButton) {
        indicatorCenterConstraint?.deactivate()
        indicatorWidthConstraint?.deactivate()
        indicatorCenterConstraint = nil
        indicatorWidthConstraint = nil
        guard let label = button.titleLabel else { return }
        indicator.isHidden = false
        indicator.snp.makeConstraints { (m) in
            indicatorCenterConstraint = m.centerX.equalTo(label).constraint
            indicatorWidthConstraint = m.width.equalTo(label).constraint
        }
    }
}
