//
//  SquareFeedPageView.swift
//  chat
//
//  消息页「广场」段整页：
//  顶部两级筛选条（一级胶囊：全部 / 个人 / 公众号 / 公告 / 消息 / 活动；
//  二级下划线：最新 / 热门 / 关注，用户 2026-09-24 定的顺序）+ 帖子流（下拉刷新、上拉加载）
//  + 右下角悬浮发帖按钮 + 空态 / 未登录态 + 红点状态回传
//
//  手势约定（2026-09-23 用户确认，方案 A）：列表上左右滑**切二级筛选**（最新 → 热门 → 关注），
//  只有已经停在最右的「关注」上继续向左滑，才把这一滑交给外层翻到「私聊」；
//  向右滑（左边没有上一段）一律留给筛选。切筛选也可以点顶部那排文字（整条筛选栏都可点，命中区域更宽）。
//

import Foundation
import UIKit
import SnapKit
import MJRefresh
import IDMPhotoBrowser
import Kingfisher

final class SquareFeedPageView: FZMScrollPageItemBaseView {

    /// 是否有未读新帖（供消息页顶部「广场」文字显示红点）
    var onUnreadChanged: ((Bool) -> Void)?

    private var posts = [SquarePost]()
    private var page = 1
    private var hasMore = false
    private var isLoading = false
    private var hasLoadedOnce = false
    private var needsRefresh = false
    private var isPageVisible = false
    /// 本地红点状态（有新帖）
    private var hasUnreadFlag = false
    /// 「带着红点进来、正在等新数据」的状态。
    ///
    /// 翻页动画的每一帧都会走 `FZMScrollPageView.dealWithScroll` → `didAppear()` → `markAllReadIfNeeded()`，
    /// 而进场时的刷新要等 `SquareStatusStore.refreshIfNeeded` 的网络回调才发出 ⇒ 若不管，
    /// 红点会在列表还没刷新前就被清掉（表现：点进广场红点没了、内容还是旧的）。
    /// 拉数据期间它为 true（挡住提前清红点），刷新结果回来后再由 `loadFeed` 复位。
    private var pendingUnreadRefresh = false
    /// 点赞请求进行中的帖子 id（避免连点）
    private var likingPostIds = Set<Int>()
    /// 空态里的「发帖」按钮（未登录时隐藏）
    private var emptyActionBtn: UIButton?
    /// 空态图标与主文案（未登录时切换成登录提示）
    private weak var emptyIconView: UIImageView?
    private weak var emptyTitleLab: UILabel?

    /// 当前二级筛选（最新 / 热门 / 关注）。
    /// 默认停在「最新」（= 二级最左一项）：关注流在没关注任何人时是空列表，不适合做首屏。
    private var tab: SquareFeedTab = .latest
    /// **一级**筛选：全部 / 个人 / 公众号 / 公告 / 消息 / 活动（决定 `kind` / `tag`）
    private var category: SquareFeedCategory = .all
    /// 请求令牌：切换筛选后旧响应直接丢弃
    private var feedToken = 0
    /// 选中下划线的左偏移（切换筛选时只动这一个约束，不重建视图）
    private var filterUnderlineLeftConstraint: SnapKit.Constraint?
    /// 已经同步过的筛选项下标（同一项重复设置时不再刷文字样式 / 下划线）
    private var appliedFilterIndex: Int?

    /// 广场页里的左右滑动用来切筛选，不让外层的私聊 / 群聊 / 广场跟着翻页
    override var locksHorizontalPaging: Bool {
        return true
    }

    /// 广场现在是**第一段**（广场 / 私聊 / 群聊），左右滑仍然用来切**二级**筛选（最新 → 热门 → 关注）：
    /// - 向右滑：左边已经没有上一段可翻了，这一滑留给自己的筛选，一律不给外层翻页；
    /// - 向左滑：切到最右边的「关注」后再向左滑，就交给外层翻到「私聊」。
    /// （「最右」按 `rawValue` 判，与显示顺序一致；换顺序不用改这里的判据）
    /// - Parameter direction: 1 = 手指向右（翻到上一段），-1 = 手指向左（翻到下一段）
    override func blocksHorizontalPaging(direction: CGFloat) -> Bool {
        // 手指此刻就落在一级胶囊栏上：这一下只用来滚胶囊，任何方向都不给外层翻页
        if isTouchOnCategoryBar {
            return true
        }
        // 刚在一级栏上横滑完（手指已抬起）：同样不给外层翻页
        if Date().timeIntervalSince1970 - categoryBarPanTime < 0.35 {
            return true
        }
        if direction > 0 {
            return true
        }
        // 二级最右一项：再向左滑就交给外层翻页（一级项是用横滑胶囊切的，不参与这里的左右滑）
        return tab.rawValue < SquareFeedTab.allCases.count - 1
    }

    /// 单个筛选的列表快照：切回来时直接铺上，不用等网络、不闪骨架。
    /// 当前筛选的状态就在 `posts` / `page` / `hasMore` / `tableView.contentOffset` 里，切走时才写回这里。
    private struct FeedSnapshot {
        var posts: [SquarePost]
        var page: Int
        var hasMore: Bool
        var contentOffset: CGPoint
    }
    /// 快照 key：**一级 + 二级组合**（只按二级存会在换一级时串内容）
    private struct FeedKey: Hashable {
        let category: SquareFeedCategory
        let tab: SquareFeedTab
    }
    private var feedSnapshots = [FeedKey: FeedSnapshot]()
    /// 正在播放的左右推入过渡（被下一次切换打断时用来收尾）
    private weak var slideSnapshotView: UIView?
    /// 过渡令牌：动画回调里校验，避免被打断后旧回调把新过渡的快照移除
    private var slideToken = 0

    // MARK: - 子视图

    // MARK: - 一级筛选（全部 / 个人 / 公众号 / 公告 / 消息 / 活动）

    private static let categoryBarHeight: CGFloat = 40
    private static let categoryButtonHeight: CGFloat = 28
    private static let categorySideInset: CGFloat = 15
    /// 胶囊之间的间距。
    /// 用户 2026-09-24：「一级列表各个按钮的距离加 5」⇒ 5 → **10**。
    /// ⚠️ 一级栏尺寸账本（2026-09-24 用系统字体 12pt **实测**重算；改字号 / 内边距 / 加类型前先按这笔账核）：
    /// 可视宽 = 屏宽 - 右侧预留 49（`mineBtn` right 10 + 32 + 间隙 4 + 竖线 1 + 间隙 2）- 左边距 15；
    /// 胶囊内容 = 文字合计 155（13 个全角字）+ 6 颗 ×2× 内边距 9（108）+ 间距 5×10（50）= **≈313pt**
    /// ⇒ 屏宽 ≥390 时 6 颗完整可见（390 → 可视 326）；375（SE）差约 2pt，第 6 颗「活动」被裁掉一丝
    /// （可横滑拉出来）。想所有机型都完整可见：间距回到 5（省 25pt）或内边距再收到 8（省 12pt）
    private static let categorySpacing: CGFloat = 10
    /// 胶囊左右内边距（文字两侧留白）。
    /// 用户 2026-09-23 反馈「外圈看起来有点窄」⇒ 从 8 加到 10；
    /// 2026-09-24 用户要求胶囊间距 +5（共需多 25pt）⇒ 这里从 10 收到 **9**（腾回 12pt），
    /// 视觉上仍是「宽胶囊」（只比之前窄 1pt/侧）；其余空间靠右侧预留再收紧 6pt（见 `mineBtn` 的 right = -10）
    private static let categoryButtonPadding: CGFloat = 9
    /// 一级胶囊栏右边界与竖分割线之间的间距
    private static let categoryDividerSpacing: CGFloat = 2
    /// 竖分割线宽度 / 高度（高度矮一点，做「列表 | 我的」的分层）
    private static let categoryDividerWidth: CGFloat = 1
    private static let categoryDividerHeight: CGFloat = 18

    /// 一级栏最近一次横滑的时间戳。
    /// 手指落在一级胶囊上横滑时，这一下**只能用来滚胶囊**，不能把页面翻到「私聊」——
    /// 外层是在手势开始时问 `blocksHorizontalPaging(direction:)`，两边手势的 began 前后顺序不确定，
    /// 所以用「刚刚在一级栏上滑过」这个时间窗口来判定，比读手势状态可靠。
    private var categoryBarPanTime: TimeInterval = 0

    /// 横向拖动切二级筛选的位移阈值（pt）：超过它才换筛选
    private static let swipeSwitchThreshold: CGFloat = 40

    /// 左右滑动列表切**二级**筛选用的 pan（见 `handleHorizontalPan`）。
    /// 只接管「横向为主」的滑动（见 `gestureRecognizerShouldBegin`），纵向滑动留给列表滚动。
    private lazy var horizontalPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
        pan.maximumNumberOfTouches = 1
        return pan
    }()

    /// 一级胶囊栏的横滑 pan（`categoryScrollView.isScrollEnabled == false`，滚动完全由它驱动）。
    /// 🔴 为什么要自己实现（2026-09-28 修「英文下一级菜单不能滑动」）：
    /// 英文下胶囊总宽（All / Personal / Official / Notice / News / Event ≈ 380pt）超出可视区（≈320pt），
    /// 必须能横滑才能看到后面几颗。但这一行的拖动同时被「外层翻页（广场/私聊/群聊）」和
    /// 「左右滑切二级筛选」盯着，scrollView 自带的 pan 在这种多重竞争下会划不动
    /// ⇒ 直接 `isScrollEnabled = false` 拿掉系统 pan，自己改 `contentOffset`：
    /// 触摸命中范围、方向判定、边界夹取、惯性全由我们决定，不再依赖任何竞争结果。
    private lazy var categoryPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCategoryPan(_:)))
        pan.maximumNumberOfTouches = 1
        return pan
    }()
    /// 一级栏拖动开始时的 contentOffset.x
    private var categoryPanStartOffset: CGFloat = 0

    /// 一级筛选：横向滚动的胶囊按钮（样式与二级的下划线刻意区分：这里是「胶囊」）
    private lazy var categoryScrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = Color_FFFFFF
        // 不显示滚动条：iOS 15 起横向滚动条会显示成胶囊下方的一条黑细线
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        // 🔴 关掉系统 pan：一级栏的横滑改成自己实现（见 `categoryPan` / `handleCategoryPan`）。
        // 英文下胶囊总宽超过可视区时，系统 pan 会被外层翻页 / 切二级筛选的手势抢走，
        // 表现就是用户报的「一级菜单不能滑动」。
        view.isScrollEnabled = false
        // 内容右侧留一点余量：滚到底时最后一颗胶囊不会紧贴分割线
        view.contentInset = UIEdgeInsets.init(top: 0, left: 0,
                                              bottom: 0, right: SquareFeedPageView.categorySideInset)
        return view
    }()

    /// 一级胶囊栏 与 「我的」入口 之间的竖分割线（分层用）。
    /// 它同时是一级栏的右边界：胶囊不会滚到头像底下（否则新加类型的最后几颗会被头像盖住、点不到）
    private lazy var categoryDivider: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()
    
    /// 一级胶囊栏**底部**的横细线：把「一级（全部/个人/公众号/公告/消息/活动）」
    /// 与「二级（最新/热门/关注）」两排分开（二级自己那条在 `filterBar` 底部；用户 2026-09-24 要求一级也加一条）。
    /// 画在一级栏**内部**的下边沿：filterBar 在上面一层，画到它头顶会被盖住
    private lazy var categoryBottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()

    private lazy var categoryStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = SquareFeedPageView.categorySpacing
        view.alignment = .center
        return view
    }()

    private var categoryButtons = [UIButton]()

    /// **二级**筛选栏（最新 / 热门 / 关注）：横向均分整行，
    /// 选中态是**蓝色下划线**（文字加粗变色 + 下划线，无胶囊底），
    /// 刻意与消息页顶部「广场 / 私聊 / 群聊」的浅灰胶囊区分开（一级那排才是胶囊）；字号也比那边小 2 号。
    private static let filterTabs: [SquareFeedTab] = SquareFeedTab.allCases
    private static let filterLeftInset: CGFloat = 15
    private static let filterBarHeight: CGFloat = 44
    /// 每项宽度自适应：屏宽减去**左右边距**后均分（二级只有 3 项）。
    /// ⚠️ 不要再给「我的」头像按钮预留右边空间：那个按钮已经移到**一级**胶囊栏那一行，
    /// 二级这排右边不再有任何东西。之前多预留了 32+8+15 = 55pt，
    /// 表现就是「最新/热门/关注」挤在左边、右边空一大块（用户 2026-09-23 报的「显示怪怪的」）。
    private static let filterItemWidth: CGFloat = {
        let reserved = filterLeftInset * 2
        let width = (k_ScreenWidth - reserved) / CGFloat(SquareFeedTab.allCases.count)
        return max(floor(width), 44)
    }()
    /// 选中下划线的宽度（固定短横线，居中于当前项）
    private static let filterUnderlineWidth: CGFloat = 20
    /// 选中下划线距离二级筛选栏**底边**的距离（往上抬，不再贴着栏底那条细线）。
    /// 让它落在「文字底部 ↔ 栏底」这段空白的中线上（用户 2026-09-24 要求）：
    /// 二级栏高 44、文字块 35 居中 ⇒ 文字下沿 = 4.5 + 35 = 39.5，减去字形自身的底部留白后
    /// 可见字形下沿 ≈29；与栏底 44 之间的空白 ≈29…44，2.5pt 的下划线居中 ⇒ 底边距栏底 ≈6pt。
    /// 改字号 / 栏高 / 文字块高度时按这笔账重算
    private static let filterUnderlineBottomInset: CGFloat = 6

    /// 第 index 个筛选项的下划线居中时的左偏移
    private static func filterUnderlineCenteredLeft(_ index: Int) -> CGFloat {
        let itemLeft = filterLeftInset + filterItemWidth * CGFloat(index)
        return itemLeft + (filterItemWidth - filterUnderlineWidth) / 2
    }

    private lazy var filterBar: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        return view
    }()

    /// 选中下划线（蓝色主题色，固定短横线；**往上抬 6pt**，落在文字与栏底之间的空白中线，不贴栏底）
    private lazy var filterUnderline: UIView = {
        let view = UIView()
        view.backgroundColor = Color_Theme
        view.layer.cornerRadius = 1.25
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var filterSegments: [ChatHeadSegment] = {
        // 字号比消息页顶部那排小 2 号（选中态与未选中态同步缩小）
        let decrement: CGFloat = 2
        return SquareFeedPageView.filterTabs.map { ChatHeadSegment(with: $0.title, fontDecrement: decrement) }
    }()

    /// 筛选栏最右侧：收件箱（评论我的帖子 / 回复我的评论），未读时显示红点
    private lazy var inboxBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.layer.cornerRadius = 16
        // 不要 clipsToBounds：未读红点要露在右上角外侧
        btn.clipsToBounds = false
        btn.backgroundColor = Color_F6F7F8
        let config = UIImage.SymbolConfiguration.init(pointSize: 17, weight: .regular)
        btn.setImage(UIImage.init(systemName: "bell", withConfiguration: config)?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_8A97A5
        btn.addTarget(self, action: #selector(inboxTap), for: .touchUpInside)
        return btn
    }()

    /// 收件箱未读红点（挂在铃铛右上角）
    private lazy var inboxDot: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.init(hexString: "#FF3B30")
        view.layer.cornerRadius = 4
        view.isHidden = true
        return view
    }()

    /// 筛选栏最右侧：固定图标的「我的」入口（不显示本人头像，点击查看我的信息与帖子）
    private lazy var mineBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.backgroundColor = Color_F6F7F8
        // UIButton 不缩放 image，视觉尺寸靠 SymbolConfiguration 的 pointSize 控制
        let config = UIImage.SymbolConfiguration.init(pointSize: 17, weight: .regular)
        btn.setImage(UIImage.init(systemName: "person.crop.circle", withConfiguration: config)?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_8A97A5
        btn.addTarget(self, action: #selector(mineTap), for: .touchUpInside)
        return btn
    }()

    /// 悬浮发帖按钮（右下角）
    private lazy var createBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(UIImage.init(systemName: "square.and.pencil")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_FFFFFF
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 28
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.18
        btn.layer.shadowRadius = 8
        btn.layer.shadowOffset = CGSize(width: 0, height: 3)
        btn.addTarget(self, action: #selector(createTap), for: .touchUpInside)
        return btn
    }()

    /// 当前页面所在的 ViewController（沿响应链查找，兜底取顶层 VC）
    private var hostViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return UIViewController.current()
    }

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = Color_FFFFFF
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        // 不需要横向滚动条（会显示成列表底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.rowHeight = UITableView.automaticDimension
        view.estimatedRowHeight = 240
        view.dataSource = self
        view.delegate = self
        // 提前把后面几屏的九宫格小图下下来（见文件末尾的 UITableViewDataSourcePrefetching）
        view.prefetchDataSource = self
        view.register(SquarePostCell.self, forCellReuseIdentifier: SquarePostCell.identifier)
        view.mj_header = MJRefreshNormalHeader.init(refreshingBlock: { [weak self] in
            self?.refresh(showLoading: false)
        })
        view.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: { [weak self] in
            self?.loadMore()
        })
        return view
    }()

    private lazy var emptyView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.isHidden = true
        let iconView = UIImageView.init(image: UIImage.init(systemName: "text.bubble")?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = Color_C8D3DE
        iconView.contentMode = .scaleAspectFit
        emptyIconView = iconView

        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("暂无内容，来发第一帖"))
        emptyTitleLab = lab

        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("发帖"), for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .mediumFont(15)
        btn.layer.cornerRadius = 17.5
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(createTap), for: .touchUpInside)
        emptyActionBtn = btn

        view.addSubview(iconView)
        view.addSubview(lab)
        view.addSubview(btn)

        iconView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.centerY.equalToSuperview().offset(-70)
            m.size.equalTo(CGSize(width: 60, height: 60))
        }
        lab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(iconView.snp.bottom).offset(14)
        }
        btn.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(lab.snp.bottom).offset(18)
            m.size.equalTo(CGSize(width: 120, height: 35))
        }
        return view
    }()

    /// 未登录占位文案
    private lazy var loginLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("登录后即可使用广场"))
    }()

    /// 空态 / 骨架的 top 约束：它们是叠层，金标墙（表头）占位时要跟着下移
    private var emptyTopConstraint: SnapKit.Constraint?
    private var skeletonTopConstraint: SnapKit.Constraint?

    /// 金标公众号目录墙：作为 `tableView.tableHeaderView` ⇒ **随列表一起划走**（只挂在「公众号」筛选上）
    private lazy var goldWallView: SquareGoldWallView = {
        let view = SquareGoldWallView.init(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: SquareGoldWallView.preferredHeight))
        view.onSelect = { [weak self] card in
            self?.openAuthor(card.address, name: card.name, kind: .official)
        }
        return view
    }()
    private var goldCards = [SquareOfficialCard]()
    /// 已经拉过一次金标列表（失败也算，不反复重试；下拉刷新会 force）
    private var goldCardsLoaded = false
    private var isLoadingGoldCards = false

    // MARK: - 金标墙（暂不上线）
    //
    // ⚠️ 用户 2026-09-23：「把金标墙隐藏掉，先不做」⇒ `showsGoldWall = false` 时**完全不挂 tableHeaderView**，
    // 列表顶部不再有那排公众号卡片（代码 / 假数据都留着，想放出来把下面两个开关一起打开）。
    private static let showsGoldWall = false

    /// 临时假数据（只看排版用）——正式放开金标墙时应同时改回 false，改走后端 `GET /officials`
    private static let debugUseFakeGoldCards = false

    /// 假的金标公众号（只为看排版：没给 avatar ⇒ 走「按地址解析头像」失败 ⇒ 默认头像）
    private static let debugFakeGoldCards: [SquareOfficialCard] = {
        let items: [[String: Any]] = [
            ["address": "0xFake000000000000000000000000000000000001", "name": "谈信官方", "gold": true, "postCount": 26, "followerCount": 12800],
            ["address": "0xFake000000000000000000000000000000000002", "name": "谈信公告", "gold": true, "postCount": 12, "followerCount": 8600],
            ["address": "0xFake000000000000000000000000000000000003", "name": "活动中心", "gold": true, "postCount": 8, "followerCount": 4300],
            ["address": "0xFake000000000000000000000000000000000004", "name": "帮助与反馈", "gold": true, "postCount": 5, "followerCount": 2100],
            ["address": "0xFake000000000000000000000000000000000005", "name": "一个很长的公众号名称用来看是不是会被截断", "gold": true, "postCount": 3, "followerCount": 900],
            ["address": "0xFake000000000000000000000000000000000006", "name": "最后一个", "gold": true, "postCount": 2, "followerCount": 100],
        ]
        return items.map { SquareOfficialCard(json: JSON($0)) }
    }()

    /// 关闭说明文案（canRead == false 时展示，服务端文案原样用）
    private weak var closedMessageLab: UILabel?
    /// 关闭页的「刷新」按钮（刷新中禁用 + 改文案，见 `closedRefreshTap`）
    private weak var closedRefreshBtn: UIButton?

    /// 广场关闭时的整页说明（《App增量-广场开关与审核强度》§4）
    /// canRead=false 时不请求帖子列表，直接把服务端 message 摆出来。
    /// 版式（2026-09-23 优化）：浅主题色圆底图标 + 服务端文案 + 实心主题色刷新按钮，**整块随文案长度垂直居中**
    /// （以前是「图标固定 centerY-70 + 文案往下挂」，服务端文案一长整块就往下坠、看着不像居中）
    private lazy var closedView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.isHidden = true

        // 图标：浅主题色圆底 + 主题色喇叭（比原来的灰色裸图标更像一个「状态」）
        let iconBg = UIView()
        iconBg.backgroundColor = Color_Theme_Light
        iconBg.layer.cornerRadius = 44

        let iconView = UIImageView.init(image: UIImage.init(systemName: "megaphone")?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = Color_Theme
        iconView.contentMode = .scaleAspectFit

        // 正文：服务端文案，用主色深字做视觉主体
        let lab = UILabel.getLab(font: .regularFont(15), textColor: Color_24374E, textAlignment: .center, text: nil)
        lab.numberOfLines = 0
        closedMessageLab = lab

        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("刷新"), for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.setTitleColor(Color_FFFFFF.withAlphaComponent(0.75), for: .disabled)
        btn.titleLabel?.font = .mediumFont(15)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(closedRefreshTap), for: .touchUpInside)
        closedRefreshBtn = btn

        view.addSubview(iconBg)
        view.addSubview(iconView)
        view.addSubview(lab)
        view.addSubview(btn)

        // 以**文案**为锚：图标挂在文案上方、按钮挂在文案下方 ⇒ 文案多长整块都保持居中。
        // 再给图标/按钮各加一条「不得超出屏幕边距」的下限保护：服务端文案极端长时先压文案，
        // 而不是把图标顶到导航栏、把刷新按钮推到屏幕外
        iconBg.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalTo(lab.snp.top).offset(-20)
            m.top.greaterThanOrEqualToSuperview().offset(24)
            m.size.equalTo(CGSize(width: 88, height: 88))
        }
        iconView.snp.makeConstraints { (m) in
            m.center.equalTo(iconBg)
            m.size.equalTo(CGSize(width: 38, height: 38))
        }
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(40)
            m.right.equalToSuperview().offset(-40)
            // 以文案为锚居中：文案中心比「图标+文案+按钮」这一整块的中心高 21pt（与文案行数无关，可直接推），
            // 再往上偏 8pt 做视觉居中 ⇒ 整块看起来是居中且不偏下的
            m.centerY.equalToSuperview().offset(13)
        }
        btn.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(lab.snp.bottom).offset(26)
            m.bottom.lessThanOrEqualToSuperview().offset(-24)
            m.size.equalTo(CGSize(width: 140, height: 40))
        }
        return view
    }()

    /// 骨架屏：没有任何内容可显示时的加载态（首次进入 / 切筛选 / 空列表下拉刷新）
    private lazy var skeletonView: SquareFeedSkeletonView = {
        let view = SquareFeedSkeletonView()
        view.isHidden = true
        return view
    }()

    // MARK: - 初始化

    override init(with pageTitle: String) {
        super.init(with: L("广场"))
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        self.backgroundColor = Color_FFFFFF
        self.addSubview(categoryScrollView)
        // ⚠️ 分割线必须先 add 进层级：下面的 categoryScrollView 约束会引用它，
        // 没有共同父视图时 SnapKit 激活约束会直接抛异常闪退
        self.addSubview(categoryDivider)
        self.addSubview(categoryBottomLine)
        self.addSubview(filterBar)
        filterBar.addSubview(filterUnderline)
        self.addSubview(tableView)
        self.addSubview(emptyView)
        self.addSubview(skeletonView)
        self.addSubview(createBtn)

        let line = UIView.init()
        line.backgroundColor = Color_E6EAEE
        filterBar.addSubview(line)

        // 一级（胶囊，可横滑）在顶部，二级（下划线）紧跟其下。
        // 右边收到分割线左侧（而不是屏宽）：胶囊只在分割线左边滑动，不会滑到「我的」头像底下
        categoryScrollView.snp.makeConstraints { (m) in
            m.left.top.equalToSuperview()
            m.right.equalTo(categoryDivider.snp.left).offset(-SquareFeedPageView.categoryDividerSpacing)
            m.height.equalTo(SquareFeedPageView.categoryBarHeight)
        }
        // 一级栏底部横细线：与一级栏下边沿齐平（filterBar 从它下面开始，不会盖住）
        categoryBottomLine.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.bottom.equalTo(categoryScrollView.snp.bottom)
            m.height.equalTo(0.5)
        }
        filterBar.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(categoryScrollView.snp.bottom)
            m.height.equalTo(SquareFeedPageView.filterBarHeight)
        }
        // 放在 filterBar 之外（同级、且在上层）：否则点它会被筛选栏的整体手势当成「切筛选」
        self.addSubview(mineBtn)
        self.addSubview(inboxBtn)
        // 收件箱在最右，未读红点挂在右上角
        inboxBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-10)
            m.centerY.equalTo(categoryScrollView)
            m.size.equalTo(CGSize(width: 32, height: 32))
        }
        inboxBtn.addSubview(inboxDot)
        inboxDot.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(1)
            m.top.equalToSuperview().offset(1)
            m.size.equalTo(CGSize(width: 8, height: 8))
        }
        mineBtn.snp.makeConstraints { (m) in
            // 收件箱铃铛占掉最右 32 + 间隙；「我的」在它左边，保持原来的 16pt 圆形按钮
            m.right.equalTo(inboxBtn.snp.left).offset(-6)
            // 与**一级**筛选栏同一行（它才是页面最上面那一行）
            m.centerY.equalTo(categoryScrollView)
            m.size.equalTo(CGSize(width: 32, height: 32))
        }
        // 竖分割线：压在「一级栏」与「我的」之间（引用 mineBtn ⇒ 必须写在 mineBtn 的 addSubview 之后）
        categoryDivider.snp.makeConstraints { (m) in
            m.right.equalTo(mineBtn.snp.left).offset(-4)
            m.centerY.equalTo(categoryScrollView)
            m.width.equalTo(SquareFeedPageView.categoryDividerWidth)
            m.height.equalTo(SquareFeedPageView.categoryDividerHeight)
        }
        filterUnderline.snp.makeConstraints { (m) in
            filterUnderlineLeftConstraint = m.left.equalToSuperview().offset(SquareFeedPageView.filterUnderlineCenteredLeft(0)).constraint
            m.width.equalTo(SquareFeedPageView.filterUnderlineWidth)
            // 距栏底留 6pt：下划线居中于「文字底部 ↔ 栏底」之间的空白（不再和栏底细线贴在一起）
            m.bottom.equalToSuperview().offset(-SquareFeedPageView.filterUnderlineBottomInset)
            m.height.equalTo(2.5)
        }
        // 五个筛选项：绝对偏移定位，保持与消息页顶部分段一致的间距
        for (index, segment) in filterSegments.enumerated() {
            filterBar.addSubview(segment)
            segment.snp.makeConstraints { (m) in
                m.left.equalToSuperview().offset(SquareFeedPageView.filterLeftInset + SquareFeedPageView.filterItemWidth * CGFloat(index))
                m.centerY.equalToSuperview()
                m.height.equalTo(35)
                m.width.equalTo(SquareFeedPageView.filterItemWidth)
            }
        }
        line.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
        // 下划线已上移（不再压在栏底细线上），但仍提到最上层：保证它不会被后来加入的视图遮住
        filterBar.bringSubviewToFront(filterUnderline)
        tableView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(filterBar.snp.bottom)
        }
        emptyView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            emptyTopConstraint = m.top.equalTo(filterBar.snp.bottom).constraint
        }
        // 骨架屏与列表同位置：加载时顶在列表上层
        skeletonView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            skeletonTopConstraint = m.top.equalTo(filterBar.snp.bottom).constraint
        }
        // 悬浮按钮压在列表之上，不会被列表拦截
        createBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-18)
            m.bottom.equalToSuperview().offset(-18)
            m.size.equalTo(CGSize(width: 56, height: 56))
        }

        // 广场关闭时的整页说明：**最后 add** ⇒ 盖在列表 / 悬浮发帖按钮 / 「我的」之上
        // （写在中间的 addSubview 之前会被后面加的遮罩盖住，这是本仓库踩过的坑）
        self.addSubview(closedView)
        closedView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        // 显式定层序（必须写在**所有** addSubview 之后）：
        // 筛选栏在叠层之上（叠层上移时不许盖住它），发帖按钮 / 「我的」 / 关闭页又在筛选栏之上
        self.bringSubviewToFront(categoryScrollView)
        self.bringSubviewToFront(categoryDivider)
        self.bringSubviewToFront(categoryBottomLine)
        self.bringSubviewToFront(filterBar)
        self.bringSubviewToFront(createBtn)
        self.bringSubviewToFront(mineBtn)
        self.bringSubviewToFront(inboxBtn)
        self.bringSubviewToFront(closedView)
        // 开关变化（进页拉到 / 拉列表收到 -20413 / 别的页拉 officialMe 写回）时同步整页
        NotificationCenter.default.addObserver(self, selector: #selector(squareStatusChanged), name: .squareStatusDidChange, object: nil)
        // 关注名单变了（拉取回来 / 关注取关）：关注流要重新过滤一遍
        NotificationCenter.default.addObserver(self, selector: #selector(followStateChanged), name: .squareFollowDidChange, object: nil)
        // 语言切换：列表里的文案（帖子里的「举报 / 分享 / 身份标签 / 时间」）都要重刷
        // （用户 2026-09-28：英文切中文时帖子里的「举报」没实时翻译过来）
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: LanguageManager.LanguageChangedNotification, object: nil)
        // 整条筛选栏响应点击（不依赖单个 label 的命中区域）
        let filterTap = UITapGestureRecognizer.init(target: self, action: #selector(filterBarTap(_:)))
        filterBar.addGestureRecognizer(filterTap)
        // 默认停在「最新」（= 二级最左一项，见 tab 属性的注释）
        applyFilterUI(SquareFeedPageView.filterTabs.firstIndex(of: tab) ?? 0)
        setupCategoryBar()
        // 左右滑动列表切筛选（走到边界后交给外层翻页，见 blocksHorizontalPaging(direction:)）。
        // ⚠️ 这里用「只接管横向为主」的 pan，不用 UISwipeGestureRecognizer：用户 2026-09-24 反馈
        // 「左滑右滑时很容易就点进帖子详情」—— UISwipe 只在快速 flick 时才认，
        // 慢划 / 短划识别不出来 ⇒ 那一下没有任何手势认领，list 里 cell 的触摸不会被取消，
        // 松手时 UITableView 就把它当成点击（didSelectRowAt）直接进了详情。
        // pan 一进入识别就会给 cell 发 touchesCancelled，慢划也不会误进详情；
        // 顺带改成按横向位移阈值判切换，「慢慢划」也能切，更接近系统手势。
        horizontalPan.delegate = self
        self.addGestureRecognizer(horizontalPan)
        // 未登录 / 广场不允许发帖时不展示悬浮发帖按钮（避免点了只弹提示）
        createBtn.isHidden = !canCreatePost
        emptyView.addSubview(loginLab)
        loginLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.centerY.equalToSuperview().offset(-40)
        }
        updateEmptyState()
    }

    // MARK: - 对外

    /// 进入该段（首次拉取 / 需要时刷新 / 标记已读）
    func enterPage() {
        isPageVisible = true
        // ★ 先同步记住「这红点进来的」：下面 `refreshIfNeeded` 的回调可能要等一次网络往返，
        //   而翻页动画期间的 `didAppear()` → `markAllReadIfNeeded()` 会先把 hasUnreadFlag 清掉，
        //   到那时再判 `hasUnreadFlag` 就永远为 false ⇒ 「有红点进广场自动刷新」会失效。
        let enterWithUnread = hasUnreadFlag
        // 进广场先问一次开关（60 秒节流；后端未上线 / 网络失败时静默跳过），拿到后再决定要不要拉列表
        SquareStatusStore.refreshIfNeeded { [weak self] in
            guard let self = self else { return }
            self.applyReadableState()
            // 关注名单（帖子对象不带 followed，只能自己拉；60 秒内不重复）
            SquareFollowStore.refresh()
            if enterWithUnread {
                // 有红点：这次进场必须拉最新，且拉到之前不要把红点清掉
                self.pendingUnreadRefresh = true
            }
            if !self.hasLoadedOnce {
                self.hasLoadedOnce = true
                self.refresh(showLoading: true)
            } else if self.needsRefresh || enterWithUnread {
                // 有新帖时进入即拉最新一页，避免红点被旧数据直接清掉
                self.needsRefresh = false
                self.refresh(showLoading: false)
            }
            self.markAllReadIfNeeded()
        }
    }

    /// 离开该段
    func leavePage() {
        isPageVisible = false
    }

    /// 帖子列表回到顶部（再次点击「消息」Tab 时调用）。
    ///
    /// ⚠️ 顶部偏移不是 `.zero`：安全区 / 金标墙表头会体现在 `adjustedContentInset`，
    /// 直接用 `.zero` 会把表头顶出去（金标墙目前是关的，但偏移算法得对）。
    /// 已经在顶部就直接返回，避免点一下还播一段空动画。
    func scrollToTop() {
        let top = CGPoint(x: 0, y: -tableView.adjustedContentInset.top)
        guard tableView.contentOffset.y > top.y + 1 else { return }
        tableView.setContentOffset(top, animated: true)
    }

    /// 标记需要刷新（发帖成功后调用）
    func markNeedsRefresh() {
        needsRefresh = true
        // 新帖对所有筛选都可见 ⇒ 其它筛选的缓存已过期
        dropStaleFeedSnapshots()
    }

    override func didAppear() {
        super.didAppear()
        if isPageVisible {
            markAllReadIfNeeded()
        }
        refreshReplyBadge()
    }

    /// 视图进入窗口时刷一次收件箱红点。
    /// `didAppear` 只在翻页滚动时才会被 `FZMScrollPageView` 调用，首次进页面不一定触发。
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        refreshReplyBadge(force: true)
    }

    /// 供外面（消息页 `viewWillAppear`）主动刷新收件箱红点
    func refreshInboxBadge() {
        refreshReplyBadge(force: true)
    }

    // MARK: - 广场开关

    /// 能否发帖：已登录 + 广场开关允许（半关闭时只能看）
    private var canCreatePost: Bool {
        return LoginUser.shared().isLogin && SquareStatusStore.canPost
    }

    /// 广场关闭时整页顶一层说明（不再展示筛选 / 列表 / 发帖入口）
    private func applyReadableState() {
        let closed = LoginUser.shared().isLogin && !SquareStatusStore.canRead
        closedView.isHidden = !closed
        if closed {
            closedMessageLab?.text = SquareStatusStore.closedMessage
        }
    }

    /// 开关变化：同步整页状态；从「关闭」变回「可读」时补拉一次列表
    @objc private func squareStatusChanged() {
        applyReadableState()
        updateEmptyState()
        // 状态刚就绪/切换时强制刷一次收件箱红点：首次 didAppear 可能因为状态/登录未就绪直接 return
        refreshReplyBadge(force: true)
        guard !SquareStatusStore.canRead else {
            if LoginUser.shared().isLogin, posts.isEmpty, !isLoading, hasLoadedOnce {
                refresh(showLoading: true)
            }
            return
        }
        // 关闭：正在飞的请求结果不再展示（令牌自增后旧回调自身会丢弃）
        feedToken += 1
        isLoading = false
        hideProgress()
        tableView.mj_header?.endRefreshing()
        tableView.mj_footer?.endRefreshing()
    }

    /// 关闭页的「刷新」：强制重问一次开关（运营可能重新开了）。
    /// 刷新中只在**按钮**上给反馈（禁用 + 「加载中…」），不动服务端文案 ——
    /// 以前是把正文改成「加载中…」，刷新失败时那行文案就看起来丢了。
    /// `refreshIfNeeded` 无论成功/失败/被节流都会回调，所以按钮一定会恢复。
    @objc private func closedRefreshTap() {
        closedRefreshBtn?.isEnabled = false
        closedRefreshBtn?.setTitle(L("加载中…"), for: .normal)
        SquareStatusStore.refreshIfNeeded(force: true) { [weak self] in
            guard let self = self else { return }
            self.closedRefreshBtn?.isEnabled = true
            self.closedRefreshBtn?.setTitle(L("刷新"), for: .normal)
            self.applyReadableState()
            self.updateEmptyState()
            guard SquareStatusStore.canRead else { return }
            self.refresh(showLoading: true)
        }
    }

    /// 关注名单变化：关注流要重新过滤（名单晚到 / 关注取关后都会走到这里）
    /// 语言切换：整页文案都要重刷 —— 帖子里的（「举报 / 分享 / 身份标签 / 时间」）靠 `reloadData()`；
    /// 但**两排筛选（一级胶囊 / 二级下划线）与空态文案是建视图时取的 `L()`**，光 reload 表格不会变。
    /// ⚠️ 本类是 **UIView**（`FZMScrollPageItemBaseView`），没有 `isViewLoaded`，直接刷表格即可
    @objc private func languageChanged() {
        refreshFilterTitles()
        // 这两处也是建视图时取的 `L()`（`updateEmptyState()` 里只重算了空态主文案）
        loginLab.text = L("登录后即可使用广场")
        emptyActionBtn?.setTitle(L("发帖"), for: .normal)
        updateEmptyState()
        tableView.reloadData()
    }

    /// 语言切换后重刷**两排筛选**的文案与字号。
    /// （用户 2026-09-29：切换多语言时广场页一级/二级列表没有实时切换）
    /// - 一级胶囊：`setTitle` 重取 `SquareFeedCategory.title`；再靠 `applyCategoryUI` 重刷选中态并把选中项重新居中
    ///   （英文胶囊更宽，居中位置跟着变）
    /// - 二级下划线：`ChatHeadSegment` 的**字号本身跟着语言走**（中文 17/14、英文 14/12，见 `ChatHeadSegment.show`）
    ///   ⇒ 不能只改 `.text`，必须再走一遍 `show(_:)`。而 `applyFilterUI` 自带「同一项直接 return」的去抖，
    ///   所以先把 `appliedFilterIndex` 置空再调，保证样式一定被重算
    private func refreshFilterTitles() {
        for (index, item) in SquareFeedCategory.allCases.enumerated() where index < categoryButtons.count {
            categoryButtons[index].setTitle(item.title, for: .normal)
        }
        for (index, item) in SquareFeedPageView.filterTabs.enumerated() where index < filterSegments.count {
            filterSegments[index].text = item.title
        }
        appliedFilterIndex = nil
        applyFilterUI(SquareFeedPageView.filterTabs.firstIndex(of: tab) ?? 0)
        applyCategoryUI(animated: false)
    }

    @objc private func followStateChanged() {
        guard tab == .following, SquareStatusStore.canRead else { return }
        guard hasLoadedOnce, !isLoading else { return }
        // 静默重拉第一页（不会再去动关注名单，不会成环）
        loadFeed(page: 1, showLoading: false)
    }

    /// 拉列表失败时的统一处理：广场关闭 / 不能发帖时同步本地开关，其余才弹提示
    private func handleFeedFailure(_ failure: SquareFailure) {
        if failure.isSquareClosed {
            SquareStatusStore.markClosed(message: failure.message)
            return
        }
        if failure.isCannotPost {
            SquareStatusStore.markCannotPost(message: failure.message)
            return
        }
        // 接口还没上线（404）时不弹「网络连接错误」，只记日志
        if failure.shouldStaySilent {
            FZMLog("广场拉列表失败(静默) \(failure.rawCode) \(failure.message)")
            return
        }
        self.showToast(failure.message)
    }

    // MARK: - 金标公众号目录墙

    /// 金标墙当前占的高度（没挂表头时是 0）
    private var goldWallHeight: CGFloat {
        return tableView.tableHeaderView == nil ? 0 : SquareGoldWallView.preferredHeight
    }

    /// 骨架 / 空态是固定叠层，必须跟着内容一起滚：金标墙占 96pt 时整体下移
    /// （与「我的信息」/「作者页」的 `syncOverlayPositions()` 同一套做法）
    private func syncOverlayPositions() {
        let offset = max(0, goldWallHeight - tableView.contentOffset.y)
        skeletonTopConstraint?.update(offset: offset)
        emptyTopConstraint?.update(offset: offset)
    }

    /// 只在「公众号」筛选且真拿到金标卡片时挂表头；其它情况摘掉
    private func updateGoldWall() {
        // 金标墙暂不上线：确保不挂表头（老版本可能已经挂上过）
        guard SquareFeedPageView.showsGoldWall else {
            if tableView.tableHeaderView != nil {
                tableView.tableHeaderView = nil
            }
            syncOverlayPositions()
            return
        }
        let shouldShow = category == .official && !goldCards.isEmpty
        guard shouldShow != (tableView.tableHeaderView != nil) else {
            if shouldShow {
                goldWallView.update(cards: goldCards)
            }
            syncOverlayPositions()
            return
        }
        if shouldShow {
            goldWallView.update(cards: goldCards)
            // ⚠️ tableHeaderView 不走 Auto Layout：frame 必须先给出宽度，否则整块不显示
            goldWallView.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: SquareGoldWallView.preferredHeight)
            tableView.tableHeaderView = goldWallView
        } else {
            tableView.tableHeaderView = nil
        }
        syncOverlayPositions()
    }

    /// 金标目录数据：只拉一次，下拉刷新时强制重拉；失败按普通错误提示（不做静默降级）
    /// ⚠️ 金标墙虽然暂不上线（`showsGoldWall`），但这份数据**照旧要拉**：
    /// 作者页的「公众号简介 / 粉丝数」、金标标记都靠它（`SquareOfficialDirectoryStore`）。
    private func loadGoldCardsIfNeeded(force: Bool = false) {
        guard category == .official, LoginUser.shared().isLogin, SquareStatusStore.canRead else { return }
        guard !isLoadingGoldCards else { return }
        if goldCardsLoaded, !force { return }
        // ⚠️ 临时调试：用本地假数据顶住（不请求 /officials），见上面 `debugUseFakeGoldCards`
        if SquareFeedPageView.debugUseFakeGoldCards {
            isLoadingGoldCards = false
            goldCardsLoaded = true
            goldCards = SquareFeedPageView.debugFakeGoldCards
            updateGoldWall()
            return
        }
        isLoadingGoldCards = true
        SquareService.shared.officials(gold: true, page: 1, pageSize: SquareLimits.maxPageSize, success: { [weak self] pageData in
            guard let self = self else { return }
            self.isLoadingGoldCards = false
            self.goldCardsLoaded = true
            self.goldCards = pageData.list
            // 服务端给的 followed 是权威的单条状态，写回本地集合（关注按钮靠它）
            pageData.list.forEach { SquareFollowStore.apply(followed: $0.followed, address: $0.address, authoritative: true) }
            // 顺着目录把「别人的」公众号简介 / 粉丝数缓存下来（作者页要用，服务端没有按地址查资料的接口）
            SquareOfficialDirectoryStore.save(pageData.list)
            // 名单完整时顺手校正本机缓存的 `gold`：被摘掉金标的号不能继续靠旧缓存显示金标
            if !pageData.hasMore {
                SquareOfficialDirectoryStore.applyGoldRoster(Set(pageData.list.map { $0.address }))
            }
            self.updateGoldWall()
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isLoadingGoldCards = false
            // 失败也置位，避免下拉刷新之外反复重试；下拉刷新会 force 重拉
            self.goldCardsLoaded = true
            // 404（后端还没上线）不弹提示
            if failure.shouldStaySilent {
                FZMLog("金标目录拉取失败(静默) \(failure.rawCode) \(failure.message)")
            } else {
                self.showToast(failure.message)
            }
            self.updateGoldWall()
        })
    }

    // MARK: - 数据

    private func refresh(showLoading: Bool) {
        guard LoginUser.shared().isLogin else {
            pendingUnreadRefresh = false
            isLoading = false
            self.tableView.mj_header?.endRefreshing()
            self.updateEmptyState()
            return
        }
        // 广场被运营关闭：不请求列表，整页展示关闭说明（《App增量-广场开关与审核强度》§4.2）
        guard SquareStatusStore.canRead else {
            pendingUnreadRefresh = false
            isLoading = false
            self.tableView.mj_header?.endRefreshing()
            self.applyReadableState()
            self.updateEmptyState()
            return
        }

        // 关注流：并发拉一次本地关注名单（**不阻塞**列表加载）；名单回来 / 变化后会走 `.squareFollowDidChange`
        // 通知再过滤一遍（见 followStateChanged()）—— 所以不要在这里等它的回调。
        // 下拉刷新时强制刷新名单（列表已加载过的话默认会复用缓存），保证「别处刚关注的人」也能出现。
        if tab == .following {
            SquareFollowStore.refresh(force: !showLoading)
        }
        loadFeed(page: 1, showLoading: showLoading)
    }

    /// 真正拉列表（`refresh` 与 `loadMore` 共用；关注流会按本地关注名单过滤）
    private func loadFeed(page: Int, showLoading: Bool) {
        // 切换筛选时允许打断上一次请求：令牌自增后旧回调会被丢弃
        feedToken += 1
        let token = feedToken
        let tab = self.tab
        // 一级参数一起取快照：回调回来时用户可能又换了一级
        let category = self.category
        isLoading = true
        // 首屏 / 切筛选且列表里还没有内容时用骨架屏顶住（不是转圈），已有内容的下拉刷新不动旧内容
        if showLoading && !posts.isEmpty {
            self.showProgress()
        }
        // 金标墙只在「公众号」筛选有意义；首页下拉刷新时跟着重拉（上拉加载不动它）
        if page == 1 {
            loadGoldCardsIfNeeded(force: !showLoading)
        }
        updateEmptyState()
        SquareService.shared.feed(page: page, feedMode: tab.feedMode, kind: category.kind, tag: category.apiTag, success: { [weak self] pageData in
            guard let self = self, token == self.feedToken else { return }
            self.isLoading = false
            self.hideProgress()
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            let list = self.filtered(list: pageData.list, tab: tab)
            self.page = page
            self.hasMore = pageData.hasMore
            self.posts = page > 1 ? self.posts + list : list
            self.tableView.mj_footer?.isHidden = !self.hasMore || self.posts.isEmpty
            self.tableView.reloadData()
            self.updateEmptyState()
            // 首屏那批图往往还在排队等下下载：数据一到就提前预热（低优先级，不抢可见图的带宽）
            if page == 1 {
                self.prefetchFirstScreenThumbnails()
            }
            // 最新一页已经拿到 ⇒ 可以按新数据清红点了
            self.pendingUnreadRefresh = false
            self.markAllReadIfNeeded()
        }, failure: { [weak self] failure in
            guard let self = self, token == self.feedToken else { return }
            self.isLoading = false
            self.hideProgress()
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            // 拉失败：红点保留（下次进页仍会重试刷新）
            self.pendingUnreadRefresh = false
            self.updateEmptyState()
            self.handleFeedFailure(failure)
        })
    }

    /// 关注流兜底过滤。
    /// 文档《App增量-关注热门举报流量》§2：`feed=following` 由**服务端**过滤，未关注任何人时返回空列表
    /// （不会回落到最新流）。但旧部署可能忽略这个参数、把最新流整条返回，所以本地再兜一层。
    /// ⚠️ 只在**关注名单确实拉到过**（`SquareFollowStore.isLoaded`）时才过滤：名单没拉到时过滤会把整页过滤成空，
    /// 看着就像「关注流是坏的」（用户 2026-09-24 报过关注功能异常）。
    private func filtered(list: [SquarePost], tab: SquareFeedTab) -> [SquarePost] {
        guard tab == .following, SquareFollowStore.isLoaded else { return list }
        return list.filter { SquareFollowStore.isFollowing($0.authorAddr) }
    }

    private func loadMore() {
        guard !isLoading, hasMore else {
            self.tableView.mj_footer?.endRefreshing()
            return
        }
        guard SquareStatusStore.canRead else {
            self.tableView.mj_footer?.endRefreshing()
            return
        }
        loadFeed(page: page + 1, showLoading: false)
    }

    /// 用最新一条帖子的 id 判断是否有新内容（本地红点，不依赖服务端未读接口）
    func checkUnread() {
        guard LoginUser.shared().isLogin else {
            self.hasUnreadFlag = false
            self.onUnreadChanged?(false)
            return
        }
        // 广场关着就不发这个探测请求了
        guard SquareStatusStore.canRead else { return }
        SquareService.shared.feed(page: 1, pageSize: 1, feedMode: .latest, kind: .all, success: { [weak self] pageData in
            guard let self = self else { return }
            let unread = SquareUnreadStore.hasUnread(newestPostId: pageData.list.first?.id)
            self.hasUnreadFlag = unread
            self.onUnreadChanged?(unread)
        }, failure: { _ in })
    }

    private func markAllReadIfNeeded() {
        guard isPageVisible, let newest = posts.first?.id else { return }
        // 带红点进来时最新一页还在路上：此时清掉会变成「红点没了、内容还是旧的」，
        // 等 loadFeed 拿到结果（会复位该标记）再清
        guard !pendingUnreadRefresh else { return }
        SquareUnreadStore.markRead(newestPostId: newest)
        hasUnreadFlag = false
        onUnreadChanged?(false)
    }

    private func updateEmptyState() {
        let isLogin = LoginUser.shared().isLogin
        // 未出结果前不展示空态，避免首屏闪一下「暂无内容」
        let isEmpty = posts.isEmpty && !isLoading && hasLoadedOnce
        emptyView.isHidden = !isEmpty
        loginLab.isHidden = isLogin
        // 未登录时只展示「登录后即可使用广场」，不显示空态文案与发帖入口
        emptyTitleLab?.isHidden = !isLogin
        emptyIconView?.isHidden = !isLogin
        // 关注流没内容时不给「发帖」入口（引导发帖解决不了「没关注人」）；广场半关闭时也不能发
        emptyActionBtn?.isHidden = !isLogin || tab == .following || !SquareStatusStore.canPost
        emptyTitleLab?.text = tab == .following ? L("暂未关注任何人") : L("暂无内容，来发第一帖")
        // 未登录 / 不允许发帖时不显示悬浮发帖按钮（避免点了只弹提示）
        createBtn.isHidden = !canCreatePost
        // 列表为空时不给上拉刷新（没有内容可加载，下拉刷新就够了）
        tableView.mj_footer?.isHidden = !hasMore || posts.isEmpty
        updateSkeletonState()
    }

    /// 骨架屏显隐：只有「正在加载 + 当前一条内容都没有」才顶骨架，
    /// 这样下拉刷新（列表里已经有帖子）时保持旧内容不动，不会闪成骨架
    private func updateSkeletonState() {
        let shouldShow = LoginUser.shared().isLogin && isLoading && posts.isEmpty
        skeletonView.isHidden = !shouldShow
        if shouldShow {
            skeletonView.startAnimating()
        } else {
            skeletonView.stopAnimating()
        }
    }

    // MARK: - 一级筛选（全部 / 个人 / 公众号 / 公告 / 消息 / 活动）

    private func setupCategoryBar() {
        categoryScrollView.addSubview(categoryStack)
        // 一级栏自己的横滑手势：自己驱动滚动（scrollView 的 isScrollEnabled 已关），
        // 只用来滚胶囊；外层翻页与切二级筛选都被 `blocksHorizontalPaging` / `shouldReceive` 挡住
        categoryPan.delegate = self
        self.addGestureRecognizer(categoryPan)
        // 横向滚动内容：只约束左边（不约束右边，否则 stack 会被拉成屏宽、内容被压缩）
        categoryStack.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(SquareFeedPageView.categorySideInset)
            m.top.bottom.equalToSuperview()
            m.height.equalToSuperview()
        }
        SquareFeedCategory.allCases.forEach { item in
            let btn = self.makeCategoryButton(item)
            categoryButtons.append(btn)
            categoryStack.addArrangedSubview(btn)
            btn.snp.makeConstraints { (m) in
                m.height.equalTo(SquareFeedPageView.categoryButtonHeight)
            }
        }
        self.applyCategoryUI(animated: false)
    }

    /// 一级胶囊栏的横滑处理（scrollView 自带 pan 已关，这里全权负责）。
    /// 顺带记 `categoryBarPanTime`：外层分页在 `blocksHorizontalPaging` 里靠它「滑完 0.35s 内不翻页」
    @objc private func handleCategoryPan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            categoryPanStartOffset = categoryScrollView.contentOffset.x
            categoryBarPanTime = Date().timeIntervalSince1970
        case .changed:
            let dx = pan.translation(in: self).x
            let maxOffset = maxCategoryOffset
            categoryScrollView.contentOffset.x = min(max(categoryPanStartOffset - dx, 0), maxOffset)
            categoryBarPanTime = Date().timeIntervalSince1970
        case .ended, .cancelled, .failed:
            // 简单惯性：按松手速度再滑一小段（不做完全体减速曲线，够用且不会冲过头）
            let velocity = pan.velocity(in: self).x
            let maxOffset = maxCategoryOffset
            let target = min(max(categoryScrollView.contentOffset.x - velocity * 0.12, 0), maxOffset)
            categoryBarPanTime = Date().timeIntervalSince1970
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) { [weak self] in
                self?.categoryScrollView.contentOffset.x = target
            }
        default:
            break
        }
    }

    /// 一级胶囊栏可滚动到的最大 `contentOffset.x`。
    /// ⚠️ 关掉 `isScrollEnabled` 后系统不再帮忙夹边界，必须自己按「内容宽度 - 可视宽度」算。
    /// `contentSize.width` 在 Auto Layout 下由 stack 宽度决定，兜底再取 `categoryStack.frame.maxX`。
    private var maxCategoryOffset: CGFloat {
        categoryScrollView.layoutIfNeeded()
        let contentWidth = max(categoryScrollView.contentSize.width, categoryStack.frame.maxX)
        let visibleWidth = categoryScrollView.bounds.width - categoryScrollView.contentInset.right
        return max(0, contentWidth - visibleWidth)
    }

    /// 当前触摸是否落在一级胶囊栏上。
    /// 用一级栏自己的 pan 手势取触摸点判定 —— 外层是在**手势开始时**问 `blocksHorizontalPaging`，
    /// 那时两边手势的 began 先后顺序不确定（读手势状态/时间戳都不够可靠），而触摸位置是确定的。
    private var isTouchOnCategoryBar: Bool {
        // ⚠️ 用一级栏自己的 pan：`categoryScrollView` 的系统 pan 已禁用，读它永远是 0 个触摸
        guard categoryPan.numberOfTouches > 0 else { return false }
        return categoryScrollView.frame.contains(categoryPan.location(in: self))
    }

    /// 一颗一级胶囊（宽度自适应：文字 + 左右内边距；选中态在 `applyCategoryUI` 里刷）
    private func makeCategoryButton(_ category: SquareFeedCategory) -> UIButton {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(category.title, for: .normal)
        // 比二级筛选（最新 / 热门 / 关注）小 2 号
        btn.titleLabel?.font = .regularFont(12)
        btn.layer.cornerRadius = SquareFeedPageView.categoryButtonHeight / 2
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_E6EAEE.cgColor
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets.init(top: 0, left: SquareFeedPageView.categoryButtonPadding,
                                                  bottom: 0, right: SquareFeedPageView.categoryButtonPadding)
        btn.tag = category.rawValue
        btn.addTarget(self, action: #selector(categoryTap(_:)), for: .touchUpInside)
        return btn
    }

    /// 同步一级选中态（选中 = 主题色浅底 + 主题色文字；未选中 = 白底 + 灰字 + 细描边）
    private func applyCategoryUI(animated: Bool = false) {
        for (index, btn) in categoryButtons.enumerated() {
            let selected = (index == category.rawValue)
            btn.backgroundColor = selected ? Color_Theme_Light : Color_FFFFFF
            btn.setTitleColor(selected ? Color_Theme : Color_8A97A5, for: .normal)
            btn.layer.borderWidth = selected ? 0 : 1
            btn.layer.borderColor = Color_E6EAEE.cgColor
        }
        // 选中的那颗滚进可视区（英文下 6 颗必然超出可视区，后面几颗默认看不到）
        guard category.rawValue < categoryButtons.count else { return }
        let btn = categoryButtons[category.rawValue]
        categoryScrollView.layoutIfNeeded()
        // ⚠️ 不用 `scrollRectToVisible`：`isScrollEnabled == false` 时它是否生效依赖实现细节，
        // 这里直接按「把选中项居中」算 contentOffset 并自行夹取（确定性更好）
        let maxOffset = maxCategoryOffset
        let centered = btn.convert(btn.bounds, to: categoryScrollView).midX - categoryScrollView.bounds.width / 2
        let offset = min(max(centered, 0), maxOffset)
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) { [weak self] in
                self?.categoryScrollView.contentOffset.x = offset
            }
        } else {
            categoryScrollView.contentOffset.x = offset
        }
    }

    /// 点一级：作废旧请求 → 清列表 → 重新拉第一页（二级保持当前选中，两个参数一起下发）
    @objc private func categoryTap(_ sender: UIButton) {
        guard let target = SquareFeedCategory(rawValue: sender.tag), target != category else { return }
        cacheCurrentFeed()
        category = target
        self.applyCategoryUI(animated: true)
        feedToken += 1
        isLoading = false
        hideProgress()
        tableView.mj_header?.endRefreshing()
        tableView.mj_footer?.endRefreshing()
        posts = []
        page = 1
        hasMore = false
        // 当作「还没拉过」：否则空列表 + hasLoadedOnce 会先闪一下「暂无内容」
        hasLoadedOnce = false
        updateGoldWall()
        tableView.reloadData()
        refresh(showLoading: true)
    }

    // MARK: - 二级筛选

    /// 把当前筛选的列表（含滚动位置）存回缓存（切走时调用）
    private func cacheCurrentFeed() {
        feedSnapshots[FeedKey(category: category, tab: tab)] = FeedSnapshot(posts: posts, page: page, hasMore: hasMore, contentOffset: tableView.contentOffset)
    }

    /// 发帖 / 删帖 / 改帖后，对其它筛选来说缓存已经过期，直接丢掉（避免切过去先闪一眼旧内容）
    private func dropStaleFeedSnapshots() {
        feedSnapshots.removeAll()
    }

    /// 切换二级筛选（点顶部「最新 / 热门 / 关注」）。
    /// 已经切过这个筛选时直接用缓存铺上、并后台静默刷新 —— 来回切不会等网络、不会闪骨架。
    private func selectFilter(_ index: Int, animated: Bool = true) {
        guard let target = SquareFeedTab(rawValue: index) else { return }
        let previous = tab.rawValue
        let direction: CGFloat = index > previous ? 1 : -1
        applyFilterUI(index, animated: animated)
        guard target != tab else { return }

        // 切走前把当前筛选的列表状态存下来
        cacheCurrentFeed()
        tab = target
        // 令牌自增：旧筛选还在飞的 feed / loadMore 响应会被作废（它们的回调不会再收尾控件）
        feedToken += 1
        isLoading = false
        hideProgress()
        tableView.mj_header?.endRefreshing()

        let cached = feedSnapshots.removeValue(forKey: FeedKey(category: category, tab: target))
        posts = cached?.posts ?? []
        page = cached?.page ?? 1
        hasMore = cached?.hasMore ?? false
        hasLoadedOnce = true
        // 切到「公众号」才需要金标墙（其它筛选把表头摘掉）
        updateGoldWall()

        // 列表跟着切换方向左右推入，避免显得“凭空”
        slideTable(direction: direction, animated: animated) { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            self.tableView.setContentOffset(cached?.contentOffset ?? .zero, animated: false)
            self.updateEmptyState()
            // 有缓存 = 屏幕上已经有内容：后台静默刷新（不顶骨架、不转圈）
            self.refresh(showLoading: cached == nil)
        }
    }

    /// 用快照做一次左右推入过渡（旧内容推出、新内容推入）
    private func slideTable(direction: CGFloat, animated: Bool, applyData: @escaping () -> Void) {
        // 上一次过渡还没播完就又切了：先收尾（复位 transform、移除快照）。
        // 否则新快照会把带位移的表格一起拍下来 —— 表现为画面错位 / 抖动
        finishPendingSlide()
        guard animated, let snapshot = tableView.snapshotView(afterScreenUpdates: false) else {
            applyData()
            return
        }
        let width = tableView.bounds.width
        snapshot.frame = tableView.frame
        // 过渡期间不拦截点击（右下角悬浮发帖按钮就在这个区域里）
        snapshot.isUserInteractionEnabled = false
        self.addSubview(snapshot)
        slideSnapshotView = snapshot

        applyData()
        tableView.transform = CGAffineTransform(translationX: direction * width, y: 0)
        slideToken += 1
        let token = slideToken
        UIView.animate(withDuration: 0.26, delay: 0, options: [.curveEaseOut], animations: {
            snapshot.transform = CGAffineTransform(translationX: -direction * width, y: 0)
            self.tableView.transform = .identity
        }, completion: { [weak self] _ in
            guard let self = self, token == self.slideToken else { return }
            snapshot.removeFromSuperview()
            self.slideSnapshotView = nil
        })
    }

    /// 收尾上一次未播完的推入过渡
    private func finishPendingSlide() {
        slideToken += 1
        slideSnapshotView?.removeFromSuperview()
        slideSnapshotView = nil
        tableView.transform = .identity
    }

    /// 同步筛选项选中态（文字加粗变色 + 蓝色下划线，下划线跟着滑过去）
    private func applyFilterUI(_ index: Int, animated: Bool = false) {
        guard appliedFilterIndex != index else { return }
        appliedFilterIndex = index
        for (i, segment) in filterSegments.enumerated() {
            segment.show(i == index)
        }
        filterUnderlineLeftConstraint?.update(offset: SquareFeedPageView.filterUnderlineCenteredLeft(index))
        guard animated else {
            filterBar.layoutIfNeeded()
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.filterBar.layoutIfNeeded()
        }
    }

    @objc private func filterBarTap(_ gesture: UITapGestureRecognizer) {
        let x = gesture.location(in: filterBar).x - SquareFeedPageView.filterLeftInset
        let index = min(max(Int(x / SquareFeedPageView.filterItemWidth), 0), SquareFeedPageView.filterTabs.count - 1)
        selectFilter(index)
    }

    /// 左右滑动列表切**二级**筛选（最新 / 热门 / 关注）：
    /// 手指向左划 = 下一个（最新 → 热门 → 关注），向右划 = 上一个；横向位移超过阈值才切。
    /// 已经在最右「关注」时向左划（或最左「最新」时向右划）这里什么都不做，
    /// 这一划由 `blocksHorizontalPaging(direction:)` 判给外层翻页。
    @objc private func handleHorizontalPan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let translation = gesture.translation(in: self)
        // 斜着划（纵向分量更大）不切筛选：那多半是在翻列表
        guard abs(translation.x) > abs(translation.y) else { return }
        guard abs(translation.x) > SquareFeedPageView.swipeSwitchThreshold else { return }
        switchFilter(step: translation.x < 0 ? 1 : -1)
    }

    /// 切换二级筛选：step = 1 下一个 / -1 上一个；越界时什么都不做（交给外层翻页）
    private func switchFilter(step: Int) {
        let target = tab.rawValue + step
        guard SquareFeedTab(rawValue: target) != nil else { return }
        selectFilter(target)
    }

    /// 自己帖子的三个点：编辑 / 删除 / （公众号帖）关评论
    private func showPostActions(_ post: SquarePost) {
        guard let vc = self.hostViewController else { return }
        SquarePostActionSheet.present(from: vc, post: post, onUpdated: { [weak self] updated in
            self?.applyUpdatedPost(updated)
        }, onDeleted: { [weak self] deletedId in
            guard let self = self else { return }
            self.posts.removeAll { $0.id == deletedId }
            // 帖子对所有筛选都可见 ⇒ 其它筛选的缓存已过期
            self.dropStaleFeedSnapshots()
            self.tableView.reloadData()
            self.updateEmptyState()
        }, onEdited: { [weak self] in
            // 编辑后要重新审核 ⇒ 直接整体刷一次，用服务端的最新状态为准
            guard let self = self else { return }
            self.dropStaleFeedSnapshots()
            self.refresh(showLoading: false)
        })
    }

    // MARK: - 交互

    /// 我的入口：我的信息 + 我的帖子
    @objc private func mineTap() {
        guard LoginUser.shared().isLogin else {
            self.showToast(L("请先登录"))
            return
        }
        openMyPosts()
    }

    // MARK: - 收件箱

    /// 最近一次刷未读红点的时间（毫秒）：`didAppear` 会被翻页反复调，60s 内不重复请求
    private static var lastReplyBadgeCheckTime: Int = 0

    @objc private func inboxTap() {
        guard LoginUser.shared().isLogin else {
            self.showToast(L("请先登录"))
            return
        }
        guard let host = self.hostViewController else { return }
        let inbox = SquareReplyInboxVC()
        inbox.onUnreadChanged = { [weak self] count in
            self?.inboxDot.isHidden = count <= 0
        }
        inbox.hidesBottomBarWhenPushed = true
        host.navigationController?.pushViewController(inbox, animated: true)
    }

    /// 静默刷收件箱未读红点（默认 60s 节流；`force` 用于状态就绪等需要立刻刷新的场景）
    private func refreshReplyBadge(force: Bool = false) {
        guard LoginUser.shared().isLogin, SquareStatusStore.canRead else {
            inboxDot.isHidden = true
            return
        }
        let now = Date.timestamp
        if !force {
            guard now - SquareFeedPageView.lastReplyBadgeCheckTime > 60 * 1000 else { return }
        }
        SquareFeedPageView.lastReplyBadgeCheckTime = now
        SquareService.shared.replyUnreadCount(success: { [weak self] count in
            FZMLog("广场收件箱：红点 count=\(count) hidden=\(count <= 0)")
            self?.inboxDot.isHidden = count <= 0
        }, failure: { error in
            FZMLog("广场收件箱：红点刷新失败 code=\(error.rawCode)")
        })
    }

    /// 进「我的信息」页（右上角头像按钮、以及点自己的头像都走这里）
    private func openMyPosts() {
        let vc = SquareMyPostsVC.init()
        vc.hidesBottomBarWhenPushed = true
        self.hostViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func createTap() {
        guard LoginUser.shared().isLogin else {
            self.showToast(L("请先登录"))
            return
        }
        guard SquareStatusStore.canPost else {
            self.showToast(SquareStatusStore.cannotPostMessage)
            return
        }
        let vc = SquareCreatePostVC.init()
        vc.hidesBottomBarWhenPushed = true
        vc.onPosted = { [weak self] in
            self?.markNeedsRefresh()
            self?.refresh(showLoading: false)
        }
        self.hostViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    /// 点头像 → 自己的头像进「我的信息」（和右上角头像按钮一致），别人的进作者信息页
    private func openAuthor(_ address: String, name: String, kind: SquareAuthorKind) {
        guard !address.isEmpty else { return }
        if address == LoginUser.shared().address {
            openMyPosts()
            return
        }
        let vc = SquareAuthorVC.init(address: address, name: name, authorKind: kind)
        vc.hidesBottomBarWhenPushed = true
        self.hostViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    private func openDetail(_ post: SquarePost) {
        let vc = SquarePostDetailVC.init(postId: post.id)
        vc.hidesBottomBarWhenPushed = true
        vc.onPostUpdated = { [weak self] updated in
            self?.applyUpdatedPost(updated)
        }
        vc.onPostDeleted = { [weak self] deletedId in
            guard let self = self else { return }
            self.posts.removeAll { $0.id == deletedId }
            // 帖子对所有筛选都可见 ⇒ 其它筛选的缓存已过期
            self.dropStaleFeedSnapshots()
            self.tableView.reloadData()
            self.updateEmptyState()
        }
        self.hostViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    /// 详情页回传的单条更新（避免整页刷新丢滚动位置）
    private func applyUpdatedPost(_ post: SquarePost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
        self.tableView.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .none)
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
        self.tableView.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .none)

        SquareService.shared.toggleLike(post: post, success: { [weak self] result in
            guard let self = self else { return }
            self.likingPostIds.remove(post.id)
            guard let index = self.posts.firstIndex(where: { $0.id == post.id }) else { return }
            self.posts[index].liked = result.liked
            self.posts[index].likeCount = result.likeCount
            self.tableView.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .none)
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.likingPostIds.remove(post.id)
            if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                self.posts[index].liked = previousLiked
                self.posts[index].likeCount = previousCount
                self.tableView.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .none)
            }
            self.showToast(failure.message)
        })
    }

    private func showPhotoBrowser(urls: [String], index: Int, from imageView: UIImageView) {
        guard let vc = self.hostViewController else { return }
        SquarePhotoPresenter.present(urls: urls, index: index, from: imageView, in: vc)
    }
}

// MARK: - 列表

extension SquareFeedPageView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SquarePostCell.identifier, for: indexPath) as! SquarePostCell
        guard indexPath.row < posts.count else { return cell }

        let post = posts[indexPath.row]
        // 举报入口只加在广场流（我的帖子全是自己的；详情页右上角已有举报）
        // ⚠️ 必须在 configure **之前**设置
        cell.showsReport = true
        // 昵称过长时**换行完整显示**；标签（身份 / 公告等）在昵称下面另起一行，时间跟金标在第一行
        // ⚠️ 与下面 heightForRowAt 的 height(for:) 必须同参，否则行高会算小
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
        cell.onAvatarTapped = { [weak self] post in
            self?.openAuthor(post.authorAddr, name: post.authorName, kind: post.authorKind)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < posts.count else { return }
        openDetail(posts[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < posts.count else { return 0 }
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : k_ScreenWidth
        // 与 cellForRowAt 的 configure 同参：昵称可换行 ⇒ 行高随之变化
        return SquarePostCell.height(for: posts[indexPath.row], width: width, wrapsLongName: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 金标墙挂在表头上（随内容滚走），空态 / 骨架这两个叠层要跟着一起动
        syncOverlayPositions()
    }
}

extension SquareFeedPageView: UIGestureRecognizerDelegate {
    /// 允许与列表纵向滚动同时识别，避免滑动切筛选把列表滚动吃掉。
    /// ⚠️ 一级栏的手动 pan 例外：它绝不能与别人同时识别，否则会出现「胶囊在滚、页面同时翻走」
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === categoryPan || otherGestureRecognizer === categoryPan {
            return false
        }
        return true
    }

    /// 切筛选的 pan 只接管「横向为主」的滑动：纵向滑动一律不接，否则列表上下滑不动
    /// ⚠️ 必须写 `override`：`gestureRecognizerShouldBegin` 是 **UIView** 自己声明的方法
    /// （`UIView (UIViewGestureRecognizers)` 分类，"subclasses may override…"），不是协议方法。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        if pan === categoryPan {
            // 一级胶囊栏：只接管「横向为主」的拖动（纵向拖动留给下面的列表）
            return abs(velocity.x) > abs(velocity.y)
        }
        guard pan === horizontalPan else {
            return true
        }
        return abs(velocity.x) > abs(velocity.y)
    }

    /// 手指落在**一级胶囊栏**上时，这个「左右滑切二级筛选」的手势不要接这一下 ——
    /// 这一滑是给胶囊栏自己横滑的（否则划胶囊会顺带把二级筛选切掉，看着像「划不动」）
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let onCategoryBar = categoryScrollView.frame.contains(touch.location(in: self))
        if gestureRecognizer === categoryPan {
            return onCategoryBar
        }
        return !onCategoryBar
    }
}

// MARK: - 图片预取
//
// 列表快滑到某一行时才去下九宫格图片，就会出现「先看到灰块再出图」。
// 这里在 cell 进入可视区之前，先把后面几屏的**同一批小图地址**下下来放进 Kingfisher 缓存：
// 地址必须与 `SquarePostCell` 里加载的完全一致（同一个 `cellWidth` 算法），否则缓存对不上、白下。

extension SquareFeedPageView: UITableViewDataSourcePrefetching {

    /// 数据到位后立刻预热首屏缩略图。
    /// `prefetchRowsAt` 只在滚动时触发，首屏那几屏图会一直等到 cell 真正配置才开始下载。
    private func prefetchFirstScreenThumbnails() {
        guard !self.posts.isEmpty else { return }
        var urls = [URL]()
        for post in self.posts.prefix(8) {
            urls.append(contentsOf: SquarePostCell.mediaThumbnailURLs(for: post, cellWidth: k_ScreenWidth))
        }
        guard !urls.isEmpty else { return }
        // 低优先级：让屏幕上真正可见的图先走（Kingfisher 下载还是同一批连接）
        let options: KingfisherOptionsInfo = [.scaleFactor(UIScreen.main.scale),
                                              .backgroundDecode,
                                              .downloadPriority(0.1)]
        // 延后一拍：让当前可见 cell 的请求先入队
        DispatchQueue.main.async {
            for url in urls.prefix(24) {
                KingfisherManager.shared.retrieveImage(with: url, options: options) { _ in }
            }
        }
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard !posts.isEmpty else { return }
        // 与 cellForRowAt 里保持一致（cell.configure(post, cellWidth: k_ScreenWidth)）
        var urls = [URL]()
        for indexPath in indexPaths where indexPath.row < posts.count {
            urls.append(contentsOf: SquarePostCell.mediaThumbnailURLs(for: posts[indexPath.row], cellWidth: k_ScreenWidth))
        }
        // 一次最多预取 24 张（≈2~3 屏），避免把带宽全占了、当前可见的图反而变慢；
        // 优先级调低，进一步保证可见图先出
        let options: KingfisherOptionsInfo = [.scaleFactor(UIScreen.main.scale),
                                              .backgroundDecode,
                                              .downloadPriority(0.1)]
        for url in urls.prefix(24) {
            KingfisherManager.shared.retrieveImage(with: url, options: options) { _ in }
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // 故意不取消：这些图马上就会用到，取消了还得重下
    }
}
