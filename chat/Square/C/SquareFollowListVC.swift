//
//  SquareFollowListVC.swift
//  chat
//
//  我的关注 / 我的粉丝（《App增量-关注热门举报流量》§3）：
//  顶部两段（关注 / 粉丝），行 = 头像 + 名称 + 身份 + 关注按钮，点行进作者页。
//
//  接口：GET /square/app/follows（我关注的）、GET /square/app/followers（关注我的）。
//  ⚠️ 帖子对象**不带** followed 字段，关注按钮的状态统一读 `SquareFollowStore`
//  （`GET /follows` 那份名单）；接口没上线时整体不显示按钮，不弹错误。
//

import Foundation
import UIKit
import SnapKit
import MJRefresh
import Kingfisher

final class SquareFollowListVC: UIViewController, ViewControllerProtocol {

    private enum ListTab: Int {
        case following = 0
        case followers = 1

        var emptyText: String {
            return self == .following ? L("暂未关注任何人") : L("还没有粉丝")
        }
    }

    /// ⚠️ 不要命名为 `tab`：`UIViewController` 上已有同名成员，子类里的 `private var tab` 会被当成「覆盖」
    /// 并报 `Overriding property must be as accessible as its enclosing type`。
    private var listTab: ListTab = .following
    private var followItems = [SquareFollowItem]()
    private var page = 1
    private var hasMore = false
    private var isLoading = false
    /// 每次发请求（切段 / 下拉 / 上拉）自增，回调只认最新的那一个。
    /// ⚠️ 旧请求的**回调必须靠它作废**，不能只靠「当前段是不是发起时的段」判断：
    /// 那样判断的话旧回调会直接 return，`isLoading` 就永远停在 true（见 `reload()` 注释）。
    private var requestSeq = 0
    /// 避免连点关注按钮
    private var pendingAddresses = Set<String>()

    private static let rowHeight: CGFloat = 68

    // MARK: - 子视图

    private lazy var segment: UISegmentedControl = {
        let control = UISegmentedControl.init(items: [L("我的关注"), L("我的粉丝")])
        control.selectedSegmentIndex = 0
        control.tintColor = Color_Theme
        control.addTarget(self, action: #selector(tabChanged(_:)), for: .valueChanged)
        return control
    }()

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = Color_FFFFFF
        view.separatorColor = Color_E6EAEE
        view.separatorInset = UIEdgeInsets.init(top: 0, left: 65, bottom: 0, right: 0)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        // 关掉系统自动内边距：否则初始 contentOffset 为负，MJRefresh 的下拉文字会露在页面上
        view.contentInsetAdjustmentBehavior = .never
        view.rowHeight = SquareFollowListVC.rowHeight
        view.tableFooterView = UIView(frame: .zero)
        view.dataSource = self
        view.delegate = self
        view.register(SquareFollowCell.self, forCellReuseIdentifier: SquareFollowCell.identifier)
        view.mj_header = MJRefreshNormalHeader.init(refreshingBlock: { [weak self] in
            self?.reload()
        })
        view.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: { [weak self] in
            self?.loadMore()
        })
        return view
    }()

    private lazy var emptyLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: "")
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_FFFFFF
        self.navigationItem.title = L("我的关注")
        self.xls_navigationBarBackgroundColor = Color_FFFFFF

        self.view.addSubview(segment)
        self.view.addSubview(tableView)
        self.view.addSubview(emptyLab)

        segment.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(10)
        }
        tableView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(segment.snp.bottom).offset(10)
        }
        emptyLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(tableView).offset(120)
        }

        // 关注关系在别处变化（作者页关注 / 取关）时刷新按钮状态
        NotificationCenter.default.addObserver(self, selector: #selector(followStateChanged), name: .squareFollowDidChange, object: nil)
        // 语言切换：行内的「关注 / 已关注」「官方号 / 公众号」标签与空态文案都要重刷
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: LanguageManager.LanguageChangedNotification, object: nil)

        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏白底、去掉滚动时出现的底部细线
        applySquareNavBarStyle()
    }

    // MARK: - 数据

    @objc private func tabChanged(_ sender: UISegmentedControl) {
        guard let target = ListTab(rawValue: sender.selectedSegmentIndex), target != listTab else { return }
        listTab = target
        self.navigationItem.title = target == .following ? L("我的关注") : L("我的粉丝")
        // ⚠️ 切段先把上一段的人清掉：否则新段数据回来之前，列表里显示的仍是上一段的内容
        followItems = []
        page = 1
        hasMore = false
        tableView.reloadData()
        reload()
    }

    private func reload() {
        // ⚠️ 作废在飞的旧请求，并把 `isLoading` 复位。
        // 少了这两行会出「切到粉丝页不刷新、再切两边都没数据」：
        // 切段时若上一段的请求还没回来，新请求会被 `load` 里的 `guard !isLoading` 挡掉（一个都不发），
        // 而旧请求回来时又因「当前段已变」被直接丢弃、没把 `isLoading` 复位 ⇒ 之后两个段都永远发不出请求。
        requestSeq += 1
        isLoading = false
        page = 1
        hasMore = false
        guard LoginUser.shared().isLogin else {
            followItems = []
            tableView.reloadData()
            updateEmptyState()
            return
        }
        // 关注名单（按钮状态用）；粉丝列表里的 followed 只能靠它
        SquareFollowStore.refresh(force: true)
        load(page: 1, replacing: true)
    }

    private func loadMore() {
        guard !isLoading, hasMore else {
            tableView.mj_footer?.endRefreshing()
            return
        }
        load(page: page + 1, replacing: false)
    }

    private func load(page: Int, replacing: Bool) {
        // 每次请求领一个序号：回调时序号已不是最新的，说明中间又切段 / 刷新过 ⇒ 整份结果丢掉。
        // ⚠️ 这里**不能**再用 `guard !isLoading` 拦（切段时会把新请求一起拦掉）；
        // 并发只由序号控制，`isLoading` 只反映「最新那次请求」的状态。
        requestSeq += 1
        let seq = requestSeq
        isLoading = true
        let currentTab = listTab
        let success: (SquarePage<SquareFollowItem>) -> Void = { [weak self] pageData in
            guard let self = self, seq == self.requestSeq else { return }
            self.isLoading = false
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            self.page = page
            self.hasMore = pageData.hasMore
            self.followItems = replacing ? pageData.list : self.followItems + pageData.list
            // 「我的关注」这一份是权威名单，写回本地集合（粉丝页的按钮状态也靠它）
            if currentTab == .following {
                pageData.list.forEach { SquareFollowStore.apply(followed: true, address: $0.address, authoritative: false) }
            }
            self.tableView.reloadData()
            self.updateEmptyState()
        }
        let failure: (SquareFailure) -> Void = { [weak self] failure in
            guard let self = self, seq == self.requestSeq else { return }
            self.isLoading = false
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            if replacing {
                self.followItems = []
                self.hasMore = false
                self.tableView.reloadData()
            }
            self.updateEmptyState()
            // 404（后端还没上线）不弹提示
            if failure.shouldStaySilent {
                FZMLog("关注/粉丝列表拉取失败(静默) \(failure.rawCode) \(failure.message)")
            } else {
                self.showToast(failure.message)
            }
        }
        if currentTab == .following {
            SquareService.shared.follows(page: page, pageSize: SquareLimits.defaultPageSize, success: success, failure: failure)
        } else {
            SquareService.shared.followers(page: page, pageSize: SquareLimits.defaultPageSize, success: success, failure: failure)
        }
    }

    private func updateEmptyState() {
        let isEmpty = followItems.isEmpty && !isLoading
        emptyLab.isHidden = !isEmpty
        emptyLab.text = listTab.emptyText
        tableView.mj_footer?.isHidden = !hasMore || followItems.isEmpty
    }

    /// 语言切换：整表重刷一次文案（行内「关注 / 已关注」、身份标签、空态）
    @objc private func languageChanged() {
        guard isViewLoaded else { return }
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func followStateChanged() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    /// 关注 / 取关：乐观更新，失败回滚（两个接口都幂等）
    private func toggleFollow(address: String) {
        guard !address.isEmpty, address != LoginUser.shared().address else { return }
        guard !pendingAddresses.contains(address) else { return }
        let wasFollowing = SquareFollowStore.isFollowing(address)
        let target = !wasFollowing
        pendingAddresses.insert(address)
        SquareFollowStore.setFollowed(target, address: address)
        tableView.reloadData()
        let finish: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.pendingAddresses.remove(address)
            self.tableView.reloadData()
        }
        let success: (SquareFollowResult) -> Void = { result in
            SquareFollowStore.setFollowed(result.followed, address: address)
            finish()
        }
        let failure: (SquareFailure) -> Void = { [weak self] failure in
            SquareFollowStore.setFollowed(wasFollowing, address: address)
            finish()
            // 404（接口未上线）/ -20411（不能关注自己）不弹提示（乐观更新已回滚，按钮回到原状态）
            if SquareFollowStore.isSilentFailure(failure) {
                FZMLog("关注/取关失败(静默) \(failure.rawCode)")
            } else {
                self?.showToast(failure.message)
            }
        }
        if target {
            SquareService.shared.follow(targetAddr: address, success: success, failure: failure)
        } else {
            SquareService.shared.unfollow(targetAddr: address, success: success, failure: failure)
        }
    }

    private func openAuthor(_ item: SquareFollowItem) {
        guard !item.address.isEmpty else { return }
        let vc = SquareAuthorVC.init(address: item.address, name: item.name, authorKind: item.targetKind)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 列表

extension SquareFollowListVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return followItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SquareFollowCell.identifier, for: indexPath) as! SquareFollowCell
        guard indexPath.row < followItems.count else { return cell }
        let item = followItems[indexPath.row]
        cell.selectionStyle = .none
        cell.configure(item: item,
                       isFollowing: SquareFollowStore.isFollowing(item.address),
                       isBusy: pendingAddresses.contains(item.address))
        cell.onFollowTapped = { [weak self] in
            self?.toggleFollow(address: item.address)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < followItems.count else { return }
        openAuthor(followItems[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SquareFollowListVC.rowHeight
    }
}

// MARK: - 行

/// 关注 / 粉丝列表一行：头像 + 名称（+ 身份标签）+ 关注按钮
final class SquareFollowCell: UITableViewCell {

    static let identifier = "SquareFollowCell"

    /// 点关注 / 取关
    var onFollowTapped: (() -> Void)?

    private static let avatarSide: CGFloat = 44
    private static let avatarPixelSize = CGSize(width: avatarSide * UIScreen.main.scale * 2,
                                               height: avatarSide * UIScreen.main.scale * 2)
    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = SquareFollowCell.avatarSide / 2
        view.backgroundColor = Color_F6F7F8
        view.image = SquareFollowCell.defaultAvatar
        return view
    }()

    private lazy var nameLab: UILabel = {
        let lab = UILabel.getLab(font: .mediumFont(15), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()

    /// 身份标签（官方号 / 公众号），没有身份时不占位
    private lazy var tagLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(10), textColor: Color_FFFFFF, textAlignment: .center, text: nil)
        // 默认蓝色；平台官方号在 configure 里换成金橙
        lab.backgroundColor = Color_Identity_Tag
        lab.layer.cornerRadius = 3
        lab.clipsToBounds = true
        lab.isHidden = true
        return lab
    }()
    private var tagWidthConstraint: SnapKit.Constraint?

    /// 关注 / 已关注（接口未上线 / 名单未加载时不展示）
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

    private var appliedAvatarKey = ""
    private var currentAddress = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = Color_FFFFFF
        self.contentView.backgroundColor = Color_FFFFFF
        self.contentView.addSubview(avatarView)
        self.contentView.addSubview(nameLab)
        self.contentView.addSubview(tagLab)
        self.contentView.addSubview(followBtn)

        avatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: SquareFollowCell.avatarSide, height: SquareFollowCell.avatarSide))
        }
        // 按钮 / 「让位」宽度：按当前语言文案算（中文 = 62pt；英文要容纳 "Following"）
        let followWidth = SquareFollowButtonSize.width(font: .mediumFont(14))
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(avatarView.snp.right).offset(12)
            // 右边给标签 / 关注按钮让位（用常量，不引用按钮视图）；⚠️ 必须与按钮宽度一致
            m.right.lessThanOrEqualToSuperview().offset(-(15 + followWidth + 8))
            m.centerY.equalToSuperview()
        }
        nameLab.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // 身份标签：跟在名字后面。
        // ⚠️ 必须给它右边界（与昵称用同一个让位值），否则名字一长标签会被顶到关注按钮下面
        tagLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.right).offset(6)
            m.centerY.equalTo(nameLab)
            m.height.equalTo(16)
            tagWidthConstraint = m.width.equalTo(0).constraint
            m.right.lessThanOrEqualToSuperview().offset(-(15 + followWidth + 8))
        }
        followBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: followWidth, height: 28))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        appliedAvatarKey = ""
        currentAddress = ""
        avatarView.kf.cancelDownloadTask()
        avatarView.image = SquareFollowCell.defaultAvatar
        nameLab.text = nil
        tagLab.text = nil
        tagLab.isHidden = true
        tagWidthConstraint?.update(offset: 0)
        followBtn.isHidden = true
        onFollowTapped = nil
    }

    func configure(item: SquareFollowItem, isFollowing: Bool, isBusy: Bool) {
        currentAddress = item.address
        nameLab.text = item.displayName

        let isOfficial = item.targetKind == .official
        // 「官方号」只给平台官方号（唯一），其它认证号是「公众号」
        let isPlatformOfficial = item.address == SquareOfficialAccount.platform
        let tag = isOfficial ? (isPlatformOfficial ? L("官方号") : L("公众号")) : ""
        tagLab.backgroundColor = isPlatformOfficial ? Color_Official_Tag : Color_Identity_Tag
        tagLab.text = tag.isEmpty ? nil : tag
        tagLab.isHidden = tag.isEmpty
        let tagFont = tagLab.font ?? .regularFont(10)
        let tagWidth = tag.isEmpty ? 0 : ceil((tag as NSString).size(withAttributes: [.font: tagFont]).width + 12)
        tagWidthConstraint?.update(offset: tagWidth)

        // 自己的行不给关注按钮（不能关注自己，服务端会回 -20411）
        let shows = !item.address.isEmpty && item.address != LoginUser.shared().address
        followBtn.isHidden = !shows
        if shows {
            followBtn.isEnabled = !isBusy
            followBtn.setTitle(isFollowing ? L("已关注") : L("关注"), for: .normal)
            followBtn.setTitleColor(isFollowing ? Color_8A97A5 : Color_FFFFFF, for: .normal)
            followBtn.backgroundColor = isFollowing ? Color_F6F7F8 : Color_Theme
        }

        loadAvatar(item)
    }

    @objc private func followTap() {
        onFollowTapped?()
    }

    /// 头像：服务端给了就用，为空才按地址解析（与作者页 / 帖子列表同一套规则）
    private func loadAvatar(_ item: SquareFollowItem) {
        if !item.avatar.isEmpty {
            applyAvatar(rawURL: item.avatar)
            return
        }
        let address = item.address
        SquareAvatarResolver.avatarURL(for: address) { [weak self] url in
            guard let self = self, self.currentAddress == address else { return }
            guard let url = url, !url.isEmpty else {
                self.appliedAvatarKey = ""
                self.avatarView.image = SquareFollowCell.defaultAvatar
                return
            }
            self.applyAvatar(rawURL: url)
        }
    }

    private func applyAvatar(rawURL: String) {
        guard rawURL != appliedAvatarKey || avatarView.image == nil else { return }
        guard let link = SquareMediaURLParser.displayURL(from: rawURL, pixelSide: SquareFollowCell.avatarPixelSize.width) else {
            appliedAvatarKey = ""
            avatarView.image = SquareFollowCell.defaultAvatar
            return
        }
        appliedAvatarKey = rawURL
        SquareAvatarLoader.apply(to: avatarView,
                                 url: link,
                                 key: rawURL,
                                 placeholder: SquareFollowCell.defaultAvatar,
                                 downsampleSize: SquareFollowCell.avatarPixelSize) { [weak self] success in
            guard let self = self, !success, self.appliedAvatarKey == rawURL else { return }
            self.appliedAvatarKey = ""
        }
    }
}
