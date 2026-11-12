//
//  SquareStatusStore.swift
//  chat
//
//  广场 2026-09 增量用到的几个轻量本地状态：
//  · `SquareStatusStore` —— 广场开关（canRead / canPost / message）。
//    文档建议「启动或进入广场先问一次」，这里做 60 秒节流；`official/me` 带回的 `square` 字段也会写进来。
//  · `SquareFollowStore` —— 我关注了哪些地址。
//    帖子对象**不带** `followed` 字段（文档《App增量-关注热门举报流量》§3 明确），
//    所以作者页 / 公众号页的关注按钮状态只能靠这份集合，不能从帖子上推。
//  · `SquareOfficialDirectoryStore` —— **别人的**公众号简介 / 粉丝数（从金标目录学到，见下面的注释）。
//
//  ⚠️ 不对功能做「接口没上线就先藏起来」的降级：所有入口照常显示，
//  请求失败时按普通错误提示（错误码以服务端为准），后端上线即生效。
//

import Foundation

extension Notification.Name {
    /// 广场开关发生变化（canRead / canPost / 关闭文案）
    static let squareStatusDidChange = Notification.Name("chat.squareStatusDidChange")
    /// 某条关注关系变化（userInfo: `address` / `followed`）
    static let squareFollowDidChange = Notification.Name("chat.squareFollowDidChange")
}

// MARK: - 广场开关

enum SquareStatusStore {

    /// **临时调试开关**（用户 2026-09-23）：true = 一律按「广场已关闭」显示，
    /// **服务端说什么都盖不掉**，不用等后端把开关打开就能看关闭态；
    /// 当前 **false = 正常按服务端开关走**（要再看一遍关闭页就改成 true，或连同下面两处
    /// `!debugForceSquareClosed &&` 一起删掉）。
    static let debugForceSquareClosed = false

    /// 最近一次已知状态；**没取到就是「可读可发」**（接口报错不对功能做任何限制）
    private(set) static var status = SquareStatus.empty

    private static var lastFetchTime: TimeInterval = 0
    private static var isFetching = false
    /// 节流窗口：60 秒内不重复请求
    private static let throttleInterval: TimeInterval = 60

    /// 能否看广场
    static var canRead: Bool {
        return !debugForceSquareClosed && status.canRead
    }

    /// 能否发帖 / 评论 / 改帖
    static var canPost: Bool {
        return !debugForceSquareClosed && status.canPost
    }

    /// 广场完全关闭时的说明文案（服务端文案优先，未给时才用兜底）
    static var closedMessage: String {
        return status.message.isEmpty ? L("广场功能已经关闭") : status.message
    }

    /// 服务端在 `-20414` 里给的发帖限制说明
    private(set) static var postBlockedMessage = ""

    /// 不能发帖时的提示文案（服务端文案优先）
    static var cannotPostMessage: String {
        return postBlockedMessage.isEmpty ? L("当前账号暂时不能发帖") : postBlockedMessage
    }

    /// 收到 `-20413`（广场已完全关闭）时调用：运营可能刚关掉，本地立刻同步成关闭态
    static func markClosed(message: String) {
        let text = message.isEmpty ? closedMessage : message
        apply(SquareStatus(canRead: false, canPost: false, message: text))
    }

    /// 收到 `-20414`（当前账号不能发帖）时调用：仍可看帖、评论、点赞，只是不能发
    static func markCannotPost(message: String) {
        if !message.isEmpty {
            postBlockedMessage = message
        }
        apply(SquareStatus(canRead: status.canRead, canPost: false, message: status.message))
    }

    /// 让下一次 `refreshIfNeeded` 一定发请求（下拉刷新、运营刚改过开关时用）
    static func invalidate() {
        lastFetchTime = 0
    }

    /// 用 `official/me` 里带回的 `square` 字段更新（少发一次请求）
    static func update(from me: SquareOfficialMe) {
        guard let square = me.square else { return }
        apply(square)
    }

    /// 节流刷新；失败（404 / 网络）保持当前值，不弹错
    /// - Parameter completion: 无论成功失败都会回调（调用方据此决定要不要继续拉帖子列表）
    static func refreshIfNeeded(force: Bool = false, completion: (() -> Void)? = nil) {
        guard LoginUser.shared().isLogin else {
            completion?()
            return
        }
        let now = Date().timeIntervalSince1970
        if !force, now - lastFetchTime < throttleInterval {
            completion?()
            return
        }
        if isFetching {
            completion?()
            return
        }
        isFetching = true
        SquareService.shared.status(success: { newStatus in
            isFetching = false
            lastFetchTime = Date().timeIntervalSince1970
            apply(newStatus)
            completion?()
        }, failure: { failure in
            // 开关只用于「运营关掉广场」这一件事；拉不到就保持当前值（默认可读可发），
            // 真正的读写失败会在拉帖 / 发帖时如实报给用户，不在这里抢着提示
            isFetching = false
            lastFetchTime = Date().timeIntervalSince1970
            FZMLog("广场开关拉取失败 \(failure.rawCode) \(failure.message)，按可读可发处理")
            completion?()
        })
    }

    private static func apply(_ newStatus: SquareStatus) {
        let changed = (newStatus.canRead != status.canRead)
            || (newStatus.canPost != status.canPost)
            || (newStatus.message != status.message)
        status = newStatus
        if changed {
            NotificationCenter.default.post(name: .squareStatusDidChange, object: nil)
        }
    }
}

// MARK: - 关注关系
enum SquareFollowStore {

    /// 当前缓存归属的地址：切账号后自动失效（不用在退出登录里加钩子）
    private static var cachedAddress = ""
    /// 已关注地址集合
    private static var followedAddresses = Set<String>()
    /// 名单是否已从服务端完整拉过一次（拉失败不置位，下次进页会重试）
    private(set) static var isLoaded = false
    private static var isFetching = false
    /// 一次拉 100（接口上限），最多 5 页（500 人），够用且不会在关注很多时反复往返
    private static let pageSize = SquareLimits.maxPageSize
    private static let maxPages = 5

    // MARK: - 本机名单缓存（按账号隔离）
    //
    // 用户 2026-09-24 报「关注之后退出 app 重开，关注被重置了」：
    // 名单原来只在内存里 —— 冷启动后到服务端名单回来之前（或名单拉失败时），所有关注按钮都是「关注」，
    // 看着就像关注被清空了。这里把**服务端权威名单**顺手写到本机，冷启动先用它显示，
    // 服务端名单回来后**覆盖**（覆盖是权威的 ⇒ 服务端真的没有这条关注时会正确变回未关注，不会盖住后端问题）。
    private static let localCachePrefix = "chat_square_follow_list_"

    private static func localCacheKey(_ address: String) -> String {
        return localCachePrefix + address
    }

    /// 用整份名单覆盖本机缓存（只在从服务端拿到完整名单时调用）
    private static func saveLocalCache(_ addresses: Set<String>, for address: String) {
        guard !address.isEmpty else { return }
        UserDefaults.standard.set(Array(addresses), forKey: localCacheKey(address))
    }

    private static func loadLocalCache(for address: String) -> Set<String> {
        guard !address.isEmpty else { return [] }
        return Set(UserDefaults.standard.stringArray(forKey: localCacheKey(address)) ?? [])
    }

    /// 单条关注状态写回本机缓存。
    /// ⚠️ 不能拿内存集合整体覆盖：名单还没拉全时（只 follow 了 1 条）那样会把本机其它关注冲掉
    private static func updateLocalCache(followed: Bool, address: String, for ownerAddress: String) {
        guard !ownerAddress.isEmpty, !address.isEmpty else { return }
        var cached = loadLocalCache(for: ownerAddress)
        if followed {
            cached.insert(address)
        } else {
            cached.remove(address)
        }
        saveLocalCache(cached, for: ownerAddress)
    }

    /// 某个地址是否已被我关注（名单没拉到时一律 false，按钮显示「关注」）
    static func isFollowing(_ address: String) -> Bool {
        guard !address.isEmpty else { return false }
        return followedAddresses.contains(address)
    }

    /// 当前缓存的关注人数（关注列表页可先展示本地数量）
    static var followedCount: Int {
        return followedAddresses.count
    }

    /// 退出登录 / 换账号时清掉（`refresh` 也会按地址自动失效）
    static func reset() {
        cachedAddress = ""
        followedAddresses.removeAll()
        isLoaded = false
        isFetching = false
    }

    /// 拉一次完整关注名单（已加载过也允许强制刷新）
    /// 分页按文档 §1.3：`pageSize` 默认 20、**最大 100**，所以这里一次取 100（吃得满、往返少）
    /// - Parameter completion: 无论成功失败都会回调
    static func refresh(force: Bool = false, completion: (() -> Void)? = nil) {
        let address = LoginUser.shared().address
        guard !address.isEmpty else {
            completion?()
            return
        }
        // 换账号（含冷启动：cachedAddress 还为空）：作废内存数据，并**先用本机缓存垫上**
        // （冷启动到服务端名单回来之前，按钮就能显示对；`isLoaded` 保持 false ⇒ 下面照样会去拉一次服务端名单）
        if cachedAddress != address {
            cachedAddress = address
            followedAddresses = loadLocalCache(for: address)
            isLoaded = false
        }
        if isLoaded, !force {
            completion?()
            return
        }
        guard !isFetching else {
            completion?()
            return
        }
        isFetching = true
        fetch(page: 1, collected: [])
    }

    private static func fetch(page: Int, collected: Set<String>) {
        SquareService.shared.follows(page: page, pageSize: pageSize, success: { pageData in
            var collected = collected
            pageData.list.forEach { collected.insert($0.address) }
            if pageData.hasMore, page < maxPages {
                fetch(page: page + 1, collected: collected)
                return
            }
            finish(address: cachedAddress, addresses: collected)
        }, failure: { failure in
            // 拉不到就保持现状（按钮照常显示，状态按本地已知的来），下次进页会重试
            isFetching = false
            FZMLog("关注名单拉取失败 \(failure.rawCode) \(failure.message)")
            NotificationCenter.default.post(name: .squareFollowDidChange, object: nil)
        })
    }

    private static func finish(address: String, addresses: Set<String>) {
        isFetching = false
        guard cachedAddress == address else { return }
        followedAddresses = addresses
        isLoaded = true
        // 服务端权威名单顺手存本机（下次冷启动先用它显示）
        saveLocalCache(addresses, for: address)
        NotificationCenter.default.post(name: .squareFollowDidChange, object: nil)
    }

    /// 关注 / 取关成功后本地更新（避免整表重拉，列表状态立刻正确）
    static func setFollowed(_ followed: Bool, address: String) {
        guard !address.isEmpty else { return }
        if cachedAddress != LoginUser.shared().address {
            cachedAddress = LoginUser.shared().address
            followedAddresses.removeAll()
        }
        // ⚠️ 先记下旧状态：粉丝数（官方号目录缓存）只在**真的变了**时才 ±1，
        // 否则重复点 / 每次名单刷新都会把这个数字越加越大
        let wasFollowed = followedAddresses.contains(address)
        if followed {
            followedAddresses.insert(address)
        } else {
            followedAddresses.remove(address)
        }
        isLoaded = true
        // 关注状态真变了 ⇒ 顺手把「作者页信息卡」的粉丝数缓存 ±1。
        // 那份缓存是「学到就留着」的、服务端不会主动推，不跟着动作者页就一直是旧数字
        // （用户 2026-09-28 报的「关注之后作者页粉丝数没刷新」）。
        if wasFollowed != followed {
            SquareOfficialDirectoryStore.applyFollowerDelta(followed ? 1 : -1, for: address)
        }
        // 单条写回本机缓存（App 被强杀时也不会丢掉刚点的关注）
        updateLocalCache(followed: followed, address: address, for: cachedAddress)
        NotificationCenter.default.post(name: .squareFollowDidChange,
                                        object: nil,
                                        userInfo: ["address": address, "followed": followed])
    }

    /// 关注失败要不要**静默**（不弹提示），由调用方在 failure 回调里用：
    /// - `isEndpointMissing`（404）：后端网关还没部署这些新路由（见 `SquareFailure.shouldStaySilent`）
    /// - `-20411` 不能关注自己：文档《App增量-关注热门举报流量》§7 的建议交互是「隐藏自己主页的关注按钮」，
    ///   不是弹错误（客户端已按地址提前隐藏，这里只是兜底）
    static func isSilentFailure(_ failure: SquareFailure) -> Bool {
        return failure.shouldStaySilent || failure.code == .cannotFollowSelf
    }

    /// 关注 / 取关（**乐观更新 → 失败回滚 → 广播 `.squareFollowDidChange`**）。
    ///
    /// 作者信息页与帖子详情页昵称行右侧的关注按钮共用这一套，保证两处表现一致
    /// （两个接口都是幂等的，先改本地再发请求，失败了回滚）。
    /// - Parameter onUpdate: 每次状态变化（乐观 / 成功 / 失败回滚）都回调一次，调用方据此刷新 UI
    /// - Parameter onFailure: 失败时回调（调用方决定要不要弹提示；接口未上线时 `shouldStaySilent` 为 true）
    static func toggleFollow(address: String,
                             onUpdate: (() -> Void)? = nil,
                             onFailure: ((SquareFailure) -> Void)? = nil) {
        guard !address.isEmpty else { return }
        let wasFollowing = isFollowing(address)
        let target = !wasFollowing
        setFollowed(target, address: address)
        onUpdate?()
        let success: (SquareFollowResult) -> Void = { result in
            setFollowed(result.followed, address: address)
            onUpdate?()
        }
        let failure: (SquareFailure) -> Void = { failure in
            setFollowed(wasFollowing, address: address)
            onUpdate?()
            onFailure?(failure)
        }
        if target {
            SquareService.shared.follow(targetAddr: address, success: success, failure: failure)
        } else {
            SquareService.shared.unfollow(targetAddr: address, success: success, failure: failure)
        }
    }

    /// 用接口返回的 `followed` 字段补正单条状态（作者页 / 公众号卡片用过即写回）
    static func apply(followed: Bool, address: String, authoritative: Bool = false) {
        guard !address.isEmpty else { return }
        guard cachedAddress == LoginUser.shared().address else { return }
        if followed {
            followedAddresses.insert(address)
            updateLocalCache(followed: true, address: address, for: cachedAddress)
        } else if authoritative {
            followedAddresses.remove(address)
            updateLocalCache(followed: false, address: address, for: cachedAddress)
        }
    }
}

// MARK: - 别人的公众号资料（简介 / 粉丝数）

/// 「别人的」公众号资料（简介 / 粉丝数 / 帖子数）。
///
/// ⚠️ 服务端目前**没有**「按地址查公众号资料」的接口（`official/me` 只能查自己），
/// 所以作者页能显示的简介与粉丝数只能从**金标目录** `GET /square/app/officials` 学到：
/// 用户进过一次「公众号」筛选（那里会拉目录）之后，再点作者页就有简介和粉丝数了。
/// 将来后端给出「查别人资料」的接口，把结果喂进 `save` 即可，页面不用改。
///
/// 实在拿不到的字段保持 0 / 空（页面据此隐藏那一行），不编假数据。
struct SquareOfficialDirectoryItem {
    var address = ""
    var intro = ""
    var followerCount = 0
    var postCount = 0
    /// 是不是金标号（`GET /officials?gold=1` 回来的名单里就有它）——
    /// 帖子没带 `authorGold` 字段时，靠它给昵称后的标签右边补金标
    var gold = false
}

enum SquareOfficialDirectoryStore {

    private static let keyPrefix = "chat_square_official_directory"
    /// 内存缓存：同一进程内切页面不再读 UserDefaults
    private static var memory = [String: SquareOfficialDirectoryItem]()

    /// 目录有更新（写入 / 修正某条资料）时在主线程广播。
    /// ⚠️ 每进程只拉一次目录 ⇒ 请求可能是**别的页面**发起的（作者页 A 发起、作者页 B 在等同一条数据），
    /// 只有发起方刷新自己的卡片的话，B 会一直停在「…」（用户 2026-09-29 报的「粉丝不显示数量」）。
    static let didUpdateNotification = Notification.Name("chat_square_official_directory_did_update")

    private static func notifyUpdated() {
        // 网络回调本来就在主线程；这里只是防御，将来若从后台线程写缓存也不会乱序
        if Thread.isMainThread {
            NotificationCenter.default.post(name: didUpdateNotification, object: nil)
        } else {
            DispatchQueue.main.async { NotificationCenter.default.post(name: didUpdateNotification, object: nil) }
        }
    }

    static func item(for address: String) -> SquareOfficialDirectoryItem? {
        guard !address.isEmpty else { return nil }
        if let cached = memory[address] { return cached }
        guard let raw = UserDefaults.standard.string(forKey: key(for: address)),
              let data = raw.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        let item = SquareOfficialDirectoryItem(address: address,
                                               intro: dict["intro"] as? String ?? "",
                                               followerCount: dict["followerCount"] as? Int ?? 0,
                                               postCount: dict["postCount"] as? Int ?? 0,
                                               gold: dict["gold"] as? Bool ?? false)
        memory[address] = item
        return item
    }

    /// 从金标目录批量写入（入参是 `GET /square/app/officials` 的 list）
    static func save(_ cards: [SquareOfficialCard]) {
        cards.forEach { card in
            guard !card.address.isEmpty else { return }
            store(SquareOfficialDirectoryItem(address: card.address,
                                              intro: card.intro,
                                              followerCount: card.followerCount,
                                              postCount: card.postCount,
                                              gold: card.gold))
        }
        // 一次 save 只广播一次（内部逐条写盘，别让 100 条变成 100 个通知）
        notifyUpdated()
    }

    /// 用**权威金标名单**校正本机缓存里的 `gold`（不在名单里的号一律置 false）。
    ///
    /// ⚠️ 以前 `save` 只写不清：运营摘掉某号的金标后，它不再出现在
    /// `GET /officials?gold=1` 名单里，但本机那条 `gold = true` 会永久留着 ⇒
    /// 「我的信息」卡（`SquareMyPostsVC` 读的正是这份缓存）、帖子昵称后的金标会一直显示。
    /// 用户 2026-09-28 报的「公众号已去掉金标，我的信息里还是金标」就是这个原因。
    ///
    /// ⚠️ 只在**拿到完整名单**（没有下一页）时调用：名单不全时不能推断「不在名单里 = 不是金标」。
    /// 只改 `gold`，简介 / 粉丝数等仍然保留（金标墙下线后作者页还在用这份数据）。
    static func applyGoldRoster(_ goldAddresses: Set<String>) {
        var addresses = Set(memory.keys)
        let prefix = keyPrefix + "_"
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { addresses.insert(String($0.dropFirst(prefix.count))) }
        addresses.forEach { address in
            guard !goldAddresses.contains(address),
                  var item = item(for: address),
                  item.gold else { return }
            item.gold = false
            store(item)
        }
        notifyUpdated()
    }

    /// 关注 / 取关后把本地缓存的粉丝数 ±1。
    /// 目录数据是「学到就留着」的、服务端不会主动推 ⇒ 不跟着动，作者页会一直显示旧值
    /// （用户 2026-09-28 报的「关注之后作者页粉丝数没刷新」）。
    /// 只在**关注状态真的变化**时调用（`SquareFollowStore.setFollowed` 里已判过）；
    /// 缓存里本来就没这个地址时不臆造一条。
    static func applyFollowerDelta(_ delta: Int, for address: String) {
        guard !address.isEmpty, delta != 0, var item = item(for: address) else { return }
        item.followerCount = max(0, item.followerCount + delta)
        store(item)
        notifyUpdated()
    }

    /// 写内存 + 落盘（修正 `gold` 与从目录学到资料共用同一条记录）
    private static func store(_ item: SquareOfficialDirectoryItem) {
        memory[item.address] = item
        let dict: [String: Any] = ["intro": item.intro,
                                  "followerCount": item.followerCount,
                                  "postCount": item.postCount,
                                  "gold": item.gold]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let raw = String.init(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key(for: item.address))
    }

    private static func key(for address: String) -> String {
        return "\(keyPrefix)_\(address)"
    }
}
