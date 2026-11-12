//
//  SquareModels.swift
//  chat
//
//  谈信广场数据模型（对接文档 §2 错误码、§5 数据结构）
//

import Foundation
import UIKit
import SwiftyJSON

// MARK: - 上限与默认值

enum SquareLimits {
    /// 帖子正文最长 2000 字
    static let maxPostLength = 5000
    /// 评论最长 500 字
    static let maxCommentLength = 600
    /// 帖子图片最多 9 张
    static let maxImageCount = 9
    /// 公众号名称最长 32 字
    static let maxOfficialNameLength = 32
    /// 公众号简介最长 200 字
    static let maxOfficialIntroLength = 200
    /// 列表分页
    static let defaultPageSize = 20
    static let maxPageSize = 100
    /// 单张图片压缩上限（1.5MB）
    static let maxImageBytes = 1536 * 1024
    /// 举报补充说明最长 500 字（《App增量-关注热门举报流量》§4）
    static let maxReportDetailLength = 500
}

// MARK: - 关注按钮尺寸

/// 「关注 / 已关注」按钮宽度（三处共用：`SquarePostCell` / `SquareAuthorInfoCell` / `SquareFollowCell`）。
///
/// 各页面原来把它写死成 62pt：中文「已关注」（14pt medium ≈ 42pt）放得下，
/// 但英文 `Following`（≈ 63pt）**比按钮还宽**，会被压成截断态
/// （用户 2026-09-28 报「英文模式下关注按钮显示不全」）。
/// 这里按当前语言「关注 / 已关注」两份文案里更宽的那个算 + 左右内边距，
/// 中文仍由 `minWidth`（= 改前的 62pt）兜底 ⇒ 中文布局与改前完全一致。
enum SquareFollowButtonSize {

    /// 最小宽度（= 改前各处写死的 62pt）
    static let minWidth: CGFloat = 62
    /// 左右内边距合计（文案左右各留 8pt）
    private static let horizontalPadding: CGFloat = 16

    /// - Parameter font: **按钮实际使用的字体**（各页面 13 / 14pt 不一样，不能统一取一个值）
    static func width(font: UIFont) -> CGFloat {
        let follow = (L("关注") as NSString).size(withAttributes: [.font: font]).width
        let following = (L("已关注") as NSString).size(withAttributes: [.font: font]).width
        return max(minWidth, ceil(max(follow, following)) + horizontalPadding)
    }
}

// MARK: - 错误码

/// 广场业务错误码（文档 §2.2）
enum SquareResultCode: Int {
    case ok = 0
    case internalError = -1000
    /// 无效签名（含 MOCK）
    case invalidSign = -1010
    /// 签名过期
    case expiredSign = -1011
    /// 参数错误
    case invalidParam = -1012
    /// 内容不合规
    case contentRejected = -20401
    /// 已提交，等待审核（按成功待审处理）
    case pendingReview = -20402
    /// 无权操作
    case forbidden = -20403
    /// 资源不存在（已删/隐藏/非作者看未过审内容）
    case notFound = -20404
    /// 公众号已封禁
    case officialBanned = -20405
    /// 非公众号
    case notOfficial = -20406
    /// 评论已关闭
    case commentsClosed = -20407
    /// 不能回复该评论（目标不可见 / 已删 / 不属于这条帖）
    case replyUnavailable = -20418
    /// 已有待审申请
    case applyPending = -20408
    /// 账号被封禁
    case banned = -20409
    /// 已举报过该内容
    case alreadyReported = -20410
    /// 不能关注自己
    case cannotFollowSelf = -20411
    /// 广场已完全关闭（拉帖 / 详情 / 发帖 / 评论 / 点赞 / 举报）
    case squareClosed = -20413
    /// 当前账号不能发帖（广场半关闭）
    case cannotPost = -20414
    /// 超过可编辑时间
    case editExpired = -20415
    /// 操作过于频繁
    case rateLimited = -20429
    /// 客户端本地码：未登录 / 无密钥，未发起请求
    case notLogin = 100001
    /// 未识别错误码
    case unknown = 999999

    init(rawCode: Int) {
        self = SquareResultCode(rawValue: rawCode) ?? .unknown
    }

    /// 兜底文案（服务端 message 为空时才用）
    var message: String {
        switch self {
        case .ok: return L("操作失败，请稍后再试")
        case .internalError: return L("服务器开小差了，请稍后再试")
        case .invalidSign: return L("签名校验失败，请重新登录")
        case .expiredSign: return L("签名已过期，请重试")
        case .invalidParam: return L("参数有误，请检查后重试")
        case .contentRejected: return L("内容不合规，无法发布")
        case .pendingReview: return L("已提交，等待审核")
        case .forbidden: return L("无权操作")
        case .notFound: return L("内容不存在或已被删除")
        case .officialBanned: return L("公众号已被封禁，请联系运营")
        case .notOfficial: return L("当前账号不是公众号")
        case .commentsClosed: return L("评论已关闭")
        case .replyUnavailable: return L("不能回复该评论，请刷新后重试")
        case .applyPending: return L("已有待审申请，请耐心等待")
        case .banned: return L("账号已被封禁")
        case .alreadyReported: return L("已举报过该内容")
        case .cannotFollowSelf: return L("不能关注自己")
        case .squareClosed: return L("广场功能已经关闭")
        case .cannotPost: return L("当前账号暂时不能发帖")
        case .editExpired: return L("超过可编辑时间")
        case .rateLimited: return L("操作过于频繁，请稍后再试")
        case .notLogin: return L("请先登录")
        case .unknown: return L("操作失败，请稍后再试")
        }
    }
}

/// 广场请求失败（业务码 / 网络错误 / 未登录统一走这里）
struct SquareFailure: Error {

    let code: SquareResultCode
    let rawCode: Int
    let rawMessage: String

    /// 展示文案：优先服务端 message，其次客户端兜底文案
    var message: String {
        rawMessage.isEmpty ? code.message : rawMessage
    }

    var isNotLogin: Bool { code == .notLogin }
    var isPendingReview: Bool { code == .pendingReview }
    var isRateLimited: Bool { code == .rateLimited }
    /// 内容不可见（已删 / 隐藏 / 无权查看 / 已过 TTL 被服务端软删）
    var isNotFound: Bool { code == .notFound }
    /// 接口不存在（HTTP 404）：后端网关还没部署这些新路由
    var isEndpointMissing: Bool { rawCode == 404 }
    /// 这类失败**要不要给用户弹提示**。
    /// 404（接口还没上线）时一律不弹：用户点哪儿都收到一句「网络连接错误」比没有提示更糟；
    /// 功能入口照常显示，后端上线后自然就好了。其余错误（断网 / 超时 / 业务码）照常提示。
    var shouldStaySilent: Bool { return isEndpointMissing }
    /// 广场被运营关闭（-20413）：展示服务端 message，不要当接口故障
    var isSquareClosed: Bool { code == .squareClosed }
    /// 当前账号不能发帖（-20414）
    var isCannotPost: Bool { code == .cannotPost }
    /// 超过可编辑时间（-20415）：当「不能再改」而不是签名错误
    var isEditExpired: Bool { code == .editExpired }
    /// 已举报过该内容（-20410）
    var isAlreadyReported: Bool { code == .alreadyReported }

    init(rawCode: Int, message: String = "") {
        self.rawCode = rawCode
        self.code = SquareResultCode(rawCode: rawCode)
        self.rawMessage = message
    }

    /// 从响应信封解析
    init(json: JSON) {
        let rawCode = json["result"].int ?? json["code"].int ?? SquareResultCode.internalError.rawValue
        var message = json["message"].string ?? ""
        if message.isEmpty {
            message = json["msg"].string ?? ""
        }
        self.init(rawCode: rawCode, message: message)
    }

    /// 从网络层错误解析（Transport / 超时 / 无网）
    init(error: Error) {
        let nsError = error as NSError
        var message = nsError.localizedDescription
        if message.isEmpty {
            message = L("网络连接错误，请稍后再试")
        }
        self.init(rawCode: nsError.code, message: message)
    }

    /// 未登录（本地拦截，不发请求）
    static let notLogin = SquareFailure(rawCode: SquareResultCode.notLogin.rawValue)
}

// MARK: - 枚举

/// 作者类型：0 个人 / 1 公众号
enum SquareAuthorKind: Int {
    case person = 0
    case official = 1
    case unknown = -1

    init(raw: Int) {
        self = SquareAuthorKind(rawValue: raw) ?? .unknown
    }

    /// 容错解析：服务端可能给数字（0 / 1），也可能给字符串（"official" / "person" / "1"），
    /// 字段缺失时按 `unknown`（调用方据此决定要不要用其他信号推断）
    init(json: JSON) {
        if let value = json.int {
            self = SquareAuthorKind(rawValue: value) ?? .unknown
            return
        }
        switch json.string?.lowercased() ?? "" {
        case "official", "1", "true": self = .official
        case "person", "0", "false": self = .person
        default: self = .unknown
        }
    }
}

/// 帖子/评论状态（文档 §5.1）
enum SquarePostStatus: Int {
    /// 可见
    case visible = 1
    /// 隐藏
    case hidden = 2
    /// 已删除
    case deleted = 3
    /// AI / 审核拒绝
    case rejected = 4
    /// 待人工审核
    case pendingReview = 5
    case unknown = -1

    init(raw: Int) {
        self = SquarePostStatus(rawValue: raw) ?? .unknown
    }
}

/// 平台官方账号地址（判定官方帖：正文 Markdown、带 tag、编辑不限时）
enum SquareOfficialAccount {
    static let platform = "square-official"
}

/// 正文格式（《App增量-官方帖Markdown》§2）
enum SquareContentFormat {
    case plain
    case markdown

    init(raw: String) {
        self = raw.lowercased() == "markdown" ? .markdown : .plain
    }
}

/// 广场流筛选：不传 kind 为全部可见帖
enum SquareFeedKind: Int {
    case all = -1
    case person = 0
    case official = 1

    /// 传给接口的值（`.all` 不传该参数）
    var apiValue: Int? {
        return self == .all ? nil : rawValue
    }
}

/// 广场流的排序口径（《App增量-关注热门举报流量》§2）；不传 feed 等价于 latest
enum SquareFeedMode: String {
    case latest
    case hot
    case following
}

/// 广场**一级**筛选：全部 / 个人 / 公众号 / 公告 / 消息 / 活动。
/// 「个人 / 公众号」走 `kind`，「公告 / 消息 / 活动」走官方帖分类 `tag`（《App增量-官方帖标签》§2）。
/// 与二级的 `feed` 是 AND 关系，两边任意组合都合法（例：关注 + 公告 = 我关注的号发的公告帖）。
enum SquareFeedCategory: Int, CaseIterable {
    case all = 0
    case person = 1
    case official = 2
    case notice = 3
    case news = 4
    case activity = 5

    /// 传给接口的 `kind`（`.all` 时上层不传这个参数）
    var kind: SquareFeedKind {
        switch self {
        case .person: return .person
        case .official: return .official
        case .all, .notice, .news, .activity: return .all
        }
    }

    /// 传给接口的 `tag`（官方帖分类）。
    /// ⚠️ 这里返回的**必须是服务端原样的中文枚举值**（公告 / 消息 / 活动），不要跟着本地化走
    var apiTag: String? {
        switch self {
        case .notice: return "公告"
        case .news: return "消息"
        case .activity: return "活动"
        case .all, .person, .official: return nil
        }
    }

    var title: String {
        switch self {
        case .all: return L("全部")
        case .person: return L("个人")
        case .official: return L("公众号")
        case .notice: return L("公告")
        case .news: return L("消息")
        case .activity: return L("活动")
        }
    }
}

/// 广场**二级**筛选（排序口径）：最新 / 热门 / 关注 —— 只决定 `feed` 参数。
/// 与一级是 AND 关系；「关注」也要带上一级的 kind / tag（后端支持任意组合）。
/// ⚠️ **声明顺序 = 筛选栏从左到右的显示顺序**（`allCases` / `rawValue` 都被当列表下标用），
/// 用户 2026-09-24 要求顺序为「最新 → 热门 → 关注」；改顺序只动这里，别去动别处的下标。
enum SquareFeedTab: Int, CaseIterable {
    case latest = 0
    case hot = 1
    case following = 2

    /// 传给接口的 `feed` 参数
    var feedMode: SquareFeedMode {
        switch self {
        case .following: return .following
        case .hot: return .hot
        case .latest: return .latest
        }
    }

    /// 筛选条文案
    var title: String {
        switch self {
        case .following: return L("关注")
        case .latest: return L("最新")
        case .hot: return L("热门")
        }
    }
}

/// 举报原因（《App增量-关注热门举报流量》§4）
///
/// ⚠️ `rawValue` **就是上报给服务端的 `reason`**，取值必须与后端枚举一一对应：
/// `spam` 垃圾 / `porn` 色情 / `scam` 诈骗 / `abuse` 辱骂 / `other` 其他（文档 §4）。
/// 想加更细的分类必须先让后端扩枚举 —— App 侧自造取值会被判非法值。
enum SquareReportReason: String, CaseIterable {
    case spam
    case porn
    case scam
    case abuse
    case other

    /// 顺序即列表顺序（`allCases` 按声明顺序）
    var title: String {
        switch self {
        case .spam: return L("垃圾信息")
        case .porn: return L("色情低俗")
        case .scam: return L("诈骗")
        case .abuse: return L("辱骂攻击")
        case .other: return L("其他")
        }
    }
}

/// 公众号状态（文档 §6.10）
enum SquareOfficialState: Equatable {
    case none
    case pending
    case approved
    case rejected
    case banned
    case unknown(String)

    init(raw: String) {
        switch raw.lowercased() {
        case "none": self = .none
        case "pending": self = .pending
        case "approved": self = .approved
        case "rejected": self = .rejected
        case "banned": self = .banned
        default: self = .unknown(raw)
        }
    }

    var rawValue: String {
        switch self {
        case .none: return "none"
        case .pending: return "pending"
        case .approved: return "approved"
        case .rejected: return "rejected"
        case .banned: return "banned"
        case .unknown(let raw): return raw
        }
    }

    /// 状态文案（「我的信息」页副标题用；公众号管理页 `SquareOfficialVC` 另有自己的文案）。
    /// ⚠️ `.approved` 在「我的信息」里显示「已认证」（用户 2026-09-28 改，原来是「已通过」）
    var displayText: String {
        switch self {
        case .none: return L("尚未申请公众号")
        case .pending: return L("审核中")
        case .approved: return L("已认证")
        case .rejected: return L("申请未通过")
        case .banned: return L("已封禁")
        case .unknown: return L("状态未知")
        }
    }

    /// 是否可提交公众号申请（未申请 / 被拒后可再申请）
    var canApply: Bool {
        return self == .none || self == .rejected
    }

    /// 是否是公众号作者（可关评论、以公众号名义发帖）
    var isApproved: Bool {
        return self == .approved
    }

    /// 是否被封禁（禁发帖、评论、点赞）
    var isBanned: Bool {
        if case .banned = self {
            return true
        }
        return false
    }
}

/// 发帖/评论提交结果：`-20402` 视为「待审成功」
enum SquareSubmitOutcome<T> {
    /// 已发布（result == 0）
    case published(T)
    /// 已提交，等待审核（result == -20402）
    case pendingReview
}

// MARK: - 帖子

struct SquarePost {

    var id = 0
    var authorAddr = ""
    /// 展示名；公众号帖为公众号名称（服务端已处理，忽略请求里的 nickname）
    var authorName = ""
    var authorKind: SquareAuthorKind = .person
    /// 作者头像（服务端 2026-09-16 增量）：公众号帖 = 当前公众号头像 URL；个人帖恒为空串
    var authorAvatar = ""
    var content = ""
    var mediaUrls: [String] = []
    var commentsEnabled = true
    var status: SquarePostStatus = .unknown
    var commentCount = 0
    var likeCount = 0
    var viewCount = 0
    /// 当前登录地址是否已点赞
    var liked = false
    /// RFC3339 原文
    var createdAt = ""
    var createdDate: Date?
    /// 正文格式：官方帖 markdown，其余 plain（《App增量-官方帖Markdown》）
    var contentFormat: SquareContentFormat = .plain
    /// 官方帖分类标签（公告 / 消息 / 活动），非官方帖为空串
    var tag = ""
    /// 运营置顶（仅广场流第 1 页会带，第 2 页起不再重复）
    var pinned = false
    var pinnedAt = ""
    /// 可编辑截止时间（RFC3339）；运营台官方帖为 nil（不限时）
    var editUntil: String?
    var editUntilDate: Date?
    /// 作者是否为金标公众号（个人帖恒为 false）
    var authorGold = false
    /// 个人帖 / 普通公众号帖的可编辑窗口（发布后 20 分钟内）
    static let editWindowSeconds: TimeInterval = 20 * 60

    init(json: JSON) {
        self.id = Int(json["id"].int64Value)
        self.authorAddr = json["authorAddr"].string ?? ""
        self.authorName = json["authorName"].string ?? ""
        self.authorKind = SquareAuthorKind(json: json["authorKind"])
        self.authorAvatar = json["authorAvatar"].string ?? ""
        self.content = json["content"].string ?? ""
        self.mediaUrls = SquareMediaURLParser.urls(from: json)
        #if DEBUG
        FZMLog("广场帖子解析 id=\(self.id) 图片数=\(self.mediaUrls.count) 正文字数=\(self.content.count) 头像=\(self.authorAvatar.isEmpty ? "无" : self.authorAvatar) 图片=\(self.mediaUrls)")
        #endif
        self.commentsEnabled = json["commentsEnabled"].bool ?? true
        self.status = SquarePostStatus(raw: json["status"].int ?? 1)
        self.commentCount = json["commentCount"].int ?? 0
        self.likeCount = json["likeCount"].int ?? 0
        self.viewCount = json["viewCount"].int ?? 0
        self.liked = json["liked"].bool ?? false
        self.createdAt = json["createdAt"].string ?? ""
        self.createdDate = SquareDateParser.date(from: self.createdAt)
        // 正文格式：服务端没给这个字段（旧版本）时按作者兜底 ——
        // 平台官方帖一定是 Markdown，漏判会把 `##`、`**` 原样摆到界面上
        if let raw = json["contentFormat"].string, !raw.isEmpty {
            self.contentFormat = SquareContentFormat(raw: raw)
        } else {
            self.contentFormat = self.authorAddr == SquareOfficialAccount.platform ? .markdown : .plain
        }
        self.tag = json["tag"].string ?? ""
        self.pinned = json["pinned"].bool ?? false
        self.pinnedAt = json["pinnedAt"].string ?? ""
        if let editUntil = json["editUntil"].string, !editUntil.isEmpty {
            self.editUntil = editUntil
            self.editUntilDate = SquareDateParser.date(from: editUntil)
        }
        self.authorGold = json["authorGold"].bool ?? false
        #if DEBUG
        // 排查「昵称显示不全」（用户 2026-09-28）：把服务端下发的昵称**原文**打出来，
        // 一眼就能分清「服务端给的就是短名字」还是「客户端显示不全」
        FZMLog("广场帖子昵称字段 id=\(self.id) authorName=[\(self.authorName)] 字数=\(self.authorName.count) displayName=[\(self.displayName)] addr=\(self.authorAddr) kind=\(self.authorKind) gold=\(self.authorGold) tag=[\(self.tag)] pinned=\(self.pinned)")
        #endif
    }

    /// 是否本人发布（UI 判断能否删除 / 关评论）
    var isMine: Bool {
        return !authorAddr.isEmpty && authorAddr == LoginUser.shared().address
    }

    var isOfficialPost: Bool {
        return authorKind == .official
    }

    /// **平台官方号**（全平台唯一，地址恒为 `square-official`）发的帖。
    /// ⚠️ 与「认证公众号」区分开：`isOfficialPost` 对**所有**公众号成立，
    /// 只有它才能拿到「官方号」这个标签。
    var isPlatformOfficial: Bool {
        return !authorAddr.isEmpty && authorAddr == SquareOfficialAccount.platform
    }

    /// 昵称一栏展示：名字为空或名字本身是地址时显示短地址
    var displayName: String {
        return SquareDisplayName.of(name: authorName, address: authorAddr)
    }

    /// 昵称后的身份标签：「我」优先；然后是「官方号」（**只有平台官方号那一个**）与「公众号」（认证号）
    /// - Parameter showsSelfTag: 自己的普通帖是否也标「我」（详情页传 true；列表里不标，免得满屏「我」）
    func identityTag(showsSelfTag: Bool) -> String {
        if isMine, showsSelfTag || isOfficialPost { return L("我") }
        guard isOfficialPost else { return "" }
        return isPlatformOfficial ? L("官方号") : L("公众号")
    }

    /// 作者自己可见的未过审帖（status 4 拒绝 / 5 待审）
    var isUnderReview: Bool {
        return status == .pendingReview || status == .rejected
    }

    /// 是否展示二次编辑入口（`PUT /square/app/posts/:id`）。
    /// - 运营台官方帖不限时（`editUntil == nil`）；个人帖 / 公众号帖按服务端给的截止时间判断；
    /// - 服务端没给 `editUntil` 时按「发布后 20 分钟」兜底，避免入口永不出现；
    /// - 这里只用本地钟控制**入口显隐**，真正拦截以服务端 `-20415` 为准。
    func canEdit(now: Date = Date()) -> Bool {
        guard isMine, status != .deleted, !isUnderReview else { return false }
        if let until = editUntilDate {
            return now <= until
        }
        if authorAddr == SquareOfficialAccount.platform {
            return true
        }
        guard let created = createdDate else { return false }
        return now.timeIntervalSince(created) <= SquarePost.editWindowSeconds
    }
}

// MARK: - 昵称展示

/// 昵称展示规则：名字为空、或名字本身就是地址（等于作者地址 / 形如 0x 开头的长十六进制串）时，
/// 一律显示短地址，不把完整地址摆到界面上；其余情况原样展示
enum SquareDisplayName {

    static func of(name: String, address: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return address.shortAddress }
        if isAddress(trimmed, address: address) { return trimmed.shortAddress }
        return trimmed
    }

    /// 判断这串字是不是地址
    private static func isAddress(_ text: String, address: String) -> Bool {
        if !address.isEmpty, text.caseInsensitiveCompare(address) == .orderedSame { return true }
        let lower = text.lowercased()
        let hex = lower.hasPrefix("0x") ? String(lower.dropFirst(2)) : lower
        // 真地址是 40 位十六进制；阈值给到 30，避免把普通昵称误判成地址
        guard hex.count >= 30 else { return false }
        return hex.allSatisfy { $0.isHexDigit }
    }
}

// MARK: - 图片地址解析
/// 广场图片地址解析：兼容数组 / JSON 字符串 / 逗号分隔，以及 [{ "url": ... }] 等结构，
/// 并对缺少协议或含空白的地址做归一化，避免服务端字段形态变化导致图片不显示。
enum SquareMediaURLParser {

    /// 依次尝试这些字段名（服务端文档为 mediaUrls）
    private static let arrayKeys = ["mediaUrls", "media_urls", "images", "imageUrls", "image_urls", "urls", "pics", "pictures"]

    static func urls(from json: JSON) -> [String] {
        for key in arrayKeys {
            let value = json[key]
            guard value.exists(), value.type != .null else { continue }
            let list = parse(value)
            if !list.isEmpty {
                return Array(list.prefix(SquareLimits.maxImageCount))
            }
        }
        logUnexpectedKeysIfNeeded(json)
        return []
    }

    private static func parse(_ value: JSON) -> [String] {
        switch value.type {
        case .array:
            return value.arrayValue.compactMap { element in
                if element.type == .string {
                    return clean(element.stringValue)
                }
                // 兼容 [{ "url": "..." }] / [{ "key": "..." }]
                for key in ["url", "src", "uri", "key", "path"] {
                    if let text = element[key].string, !text.isEmpty {
                        return clean(text)
                    }
                }
                return nil
            }
        case .string:
            return parseString(value.stringValue)
        default:
            return []
        }
    }

    /// 兼容 "[\"a\",\"b\"]" 与 "a,b" 两种字符串形态
    private static func parseString(_ raw: String) -> [String] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        if text.hasPrefix("["),
           let data = text.data(using: .utf8),
           let json = try? JSON.init(data: data) {
            return parse(json)
        }
        return text.components(separatedBy: ",").compactMap { clean($0) }
    }

    private static func clean(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.trimmingCharacters(in: CharacterSet.init(charactersIn: "\"'"))
        return value.isEmpty ? nil : value
    }

    /// 生成可加载的 URL：
    /// - 完整 URL（http/https、// 开头）直接用
    /// - 缺协议的域名自动补 https://
    /// - 只给了 OSS key（如 zk-retail/picture/xxx.jpg）时，按 OSS 公共域名补全
    static func url(from raw: String) -> URL? {
        guard var value = clean(raw) else { return nil }

        if value.hasPrefix("//") {
            value = "https:" + value
        } else if !value.lowercased().hasPrefix("http") {
            if value.contains("/") || value.lowercased().hasSuffix(".jpg") || value.lowercased().hasSuffix(".png") || value.lowercased().hasSuffix(".jpeg") {
                // 纯 key 形态
                value = ossPublicURLPrefix + value
            } else {
                value = "https://" + value
            }
            FZMLog("广场图片地址非完整 URL，已补全为: \(value)")
        }

        if let url = URL.init(string: value) {
            return url
        }
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL.init(string: encoded)
    }

    /// 按显示尺寸取「服务端裁好的小图」地址：
    /// OSS 图直接在 URL 上加 `x-oss-process=image/resize,w_N,h_N,m_fill`
    /// （方图等比裁切，体积往往只有原图的 1/5~1/10，广场列表 / 头像会明显快很多）；
    /// 非 OSS 域名、或地址上已经带了处理参数时原样返回。
    /// ⚠️ 调用方要处理「取小图失败」的情况：回退到原图（见 `SquareImageGridView.loadImage`），
    ///    避免某个地址不支持处理参数时图直接出不来。
    /// - Parameter pixelSide: 需要的像素边长（pt × 屏幕 scale）
    static func displayURL(from raw: String, pixelSide: CGFloat) -> URL? {
        guard let url = url(from: raw) else { return nil }
        guard pixelSide > 0, let host = url.host,
              host.contains("aliyuncs.com") || host.contains("oss-") else { return url }
        let text = url.absoluteString
        // 已经带过处理参数（比如聊天那边拼的缩略地址）就不要重复拼
        guard !text.contains("x-oss-process") else { return url }
        // 宽度取整到 20 的倍数：地址更规整，也更容易命中同一份缓存
        let side = max(Int((pixelSide / 20.0).rounded(.up)) * 20, 40)
        let separator = text.contains("?") ? "&" : "?"
        let processed = "\(text)\(separator)x-oss-process=image/resize,w_\(side),h_\(side),m_fill"
        return URL.init(string: processed) ?? url
    }

    /// 九宫格「完整显示」用的小图地址：等比缩放到不超过 N×N 的方框内、**不裁切**（m_lfit），
    /// 图会完整落在格子里（比例不同时留白），体积与裁切版相当。
    /// ⚠️ 只有「详情页的图片要完整显示」时才用它；`displayURL`（m_fill 方形裁切）保持给头像 /
    /// 广场流九宫格 / 发帖预览用，别把 `displayURL` 改成不裁切。
    /// - Parameter pixelSide: 需要的像素边长（pt × 屏幕 scale），与展示格子边长一致
    static func thumbnailURL(from raw: String, pixelSide: CGFloat) -> URL? {
        guard let url = url(from: raw) else { return nil }
        guard pixelSide > 0, let host = url.host,
              host.contains("aliyuncs.com") || host.contains("oss-") else { return url }
        let text = url.absoluteString
        guard !text.contains("x-oss-process") else { return url }
        let side = max(Int((pixelSide / 20.0).rounded(.up)) * 20, 40)
        let separator = text.contains("?") ? "&" : "?"
        let processed = "\(text)\(separator)x-oss-process=image/resize,w_\(side),h_\(side),m_lfit"
        return URL.init(string: processed) ?? url
    }

    /// 图文混排里的内联大图：按显示宽度缩放、**不裁切**（高度由图片自身比例决定，
    /// 正文里的图片标记同时记了宽高比，所以加载前后高度一致、不会跳动）
    static func inlineImageURL(from raw: String, pixelWidth: CGFloat) -> URL? {
        guard let url = url(from: raw) else { return nil }
        guard pixelWidth > 0, let host = url.host,
              host.contains("aliyuncs.com") || host.contains("oss-") else { return url }
        let text = url.absoluteString
        guard !text.contains("x-oss-process") else { return url }
        let width = max(Int((pixelWidth / 20.0).rounded(.up)) * 20, 120)
        let separator = text.contains("?") ? "&" : "?"
        let processed = "\(text)\(separator)x-oss-process=image/resize,w_\(width)"
        return URL.init(string: processed) ?? url
    }

    /// 大图浏览用的「按屏宽取图」地址：只限宽、不裁切（保留原始比例）。
    /// 原图动辄几 MB，按屏宽取往往只有几十~几百 KB，点开大图快很多；非 OSS 域名原样返回。
    /// - Parameter maxPixelWidth: 需要的像素宽度（一般 = 屏宽 × scale × 1.5，留一点放大余量）
    static func previewURL(from raw: String, maxPixelWidth: CGFloat) -> URL? {
        guard let url = url(from: raw) else { return nil }
        guard maxPixelWidth > 0, let host = url.host,
              host.contains("aliyuncs.com") || host.contains("oss-") else { return url }
        let text = url.absoluteString
        guard !text.contains("x-oss-process") else { return url }
        let width = max(Int((maxPixelWidth / 100.0).rounded(.up)) * 100, 200)
        let separator = text.contains("?") ? "&" : "?"
        return URL.init(string: "\(text)\(separator)x-oss-process=image/resize,w_\(width)") ?? url
    }

    /// OSS 公共访问地址前缀（bucket + endpoint），用于兜底拼接只给了 key 的图片
    private static var ossPublicURLPrefix: String {
        let host = URL.init(string: OSS_End_Point)?.host ?? "oss-cn-shanghai.aliyuncs.com"
        return "https://\(OSS_Buket).\(host)/"
    }

    /// mediaUrls 取不到、但响应里出现疑似图片字段时打日志，便于定位字段名不一致
    private static func logUnexpectedKeysIfNeeded(_ json: JSON) {
        #if DEBUG
        guard let dict = json.dictionary, !dict.isEmpty else { return }
        let suspects = dict.keys.filter { key in
            let lower = key.lowercased()
            return lower.contains("media") || lower.contains("image") || lower.contains("pic")
                || lower.contains("photo") || lower.contains("attach")
        }
        if !suspects.isEmpty {
            FZMLog("广场帖子图片字段疑似命名不一致: \(suspects)")
        }
        #endif
    }
}

// MARK: - 评论

struct SquareComment {

    var id = 0
    var postId = 0
    var authorAddr = ""
    var authorName = ""
    /// 作者头像（服务端给评论带了就用）：**公众号评论必须用公众号头像**，不能回退成个人头像
    var authorAvatar = ""
    var content = ""
    var status: SquarePostStatus = .unknown
    var createdAt = ""
    var createdDate: Date?
    /// 作者类型（0 个人 / 1 公众号）：以服务端返回为准；字段缺失时是 `.unknown`，
    /// 再由「是否带作者头像 / 是否本人已通过公众号」推断（见 `isOfficialComment`）
    var authorKind: SquareAuthorKind = .person
    /// 本地标记：服务端返回 -20402（待审）时，先本地展示一条「审核中」的评论
    var isPendingReview = false

    // MARK: - 评论回复（《App增量-评论回复》）

    /// 所属一级评论 id；0 = 自身就是一级评论（老数据也可能为 0）
    var parentId = 0
    /// 被回复的评论 id；0 = 一级评论
    var replyToId = 0
    /// 被回复人地址（服务端给才有）
    var replyToAddr = ""
    /// 被回复人展示名（服务端给才有）
    var replyToName = ""
    /// 该楼回复总数（仅 `thread=1` 的主评论有意义）
    var replyCount = 0
    /// 一级评论已不可见但仍保留回复时，服务端返回 `deleted=true`
    var deleted = false

    /// 是否是一条回复（挂在一级评论下面）
    var isReplyComment: Bool {
        return parentId > 0 || replyToId > 0
    }

    init(json: JSON) {
        self.id = json["id"].int ?? 0
        self.postId = json["postId"].int ?? 0
        self.authorAddr = json["authorAddr"].string ?? ""
        self.authorName = json["authorName"].string ?? ""
        self.authorAvatar = json["authorAvatar"].string ?? ""
        self.content = json["content"].string ?? ""
        self.status = SquarePostStatus(raw: json["status"].int ?? 1)
        self.createdAt = json["createdAt"].string ?? ""
        self.createdDate = SquareDateParser.date(from: self.createdAt)
        self.authorKind = SquareAuthorKind(json: json["authorKind"])
        self.parentId = json["parentId"].int ?? 0
        self.replyToId = json["replyToId"].int ?? 0
        self.replyToAddr = json["replyToAddr"].string ?? ""
        self.replyToName = json["replyToName"].string ?? ""
        self.replyCount = json["replyCount"].int ?? 0
        self.deleted = json["deleted"].bool ?? false
        applyLocalOfficialIfNeeded()
        #if DEBUG
        SquareComment.logKeysIfNeeded(json)
        #endif
    }

    /// 本地构造一条「审核中」评论（服务端 -20402 时用于即时反馈，刷新后会被服务端数据替换）
    static func pendingComment(postId: Int, content: String) -> SquareComment {
        var comment = SquareComment(json: JSON([:]))
        comment.postId = postId
        comment.authorAddr = LoginUser.shared().address
        comment.authorName = LoginUser.shared().nickName?.value ?? ""
        comment.content = content
        comment.createdDate = Date()
        comment.isPendingReview = true
        // 本人是已通过的公众号：本地这条待审评论也按公众号展示（拿缓存里的公众号头像，别用个人头像）
        comment.applyLocalOfficialIfNeeded()
        return comment
    }

    /// 本人账号是已通过的公众号时，把自己的评论在本地补成公众号评论：
    /// 补上公众号头像，并标记 `authorKind = .official`。
    /// 为什么得本地补：服务端评论对象不一定带 `authorKind` / `authorAvatar`（帖子带、评论常缺），
    /// 不补的话「我发的公众号评论」会显示成个人头像。
    private mutating func applyLocalOfficialIfNeeded() {
        guard authorAddr == LoginUser.shared().address,
              let profile = SquareMyOfficialStore.profile(for: authorAddr),
              profile.state.isApproved else { return }
        if authorAvatar.isEmpty { authorAvatar = profile.avatar }
        authorKind = .official
    }

    #if DEBUG
    /// 只打一次评论字段，便于确认服务端到底给了哪些字段（authorKind / authorAvatar 在不在）
    private static var didLogKeys = false
    private static func logKeysIfNeeded(_ json: JSON) {
        guard !didLogKeys, let dict = json.dictionary, !dict.isEmpty else { return }
        didLogKeys = true
        FZMLog("广场评论字段：\(dict.keys.sorted())")
    }
    #endif

    var isMine: Bool {
        return !authorAddr.isEmpty && authorAddr == LoginUser.shared().address
    }

    /// 公众号发的评论。
    /// 服务端显式标了公众号就听它的；**没给标记但带了作者头像**也当成公众号 ——
    /// 帖子的个人作者恒为空头像，所以「有头像」基本等价于公众号，这是服务端缺字段时的兼容。
    var isOfficialComment: Bool {
        if authorKind == .official { return true }
        if authorKind == .unknown, !authorAvatar.isEmpty { return true }
        return false
    }

    /// 昵称一栏展示：名字为空或名字本身是地址时显示短地址
    var displayName: String {
        return SquareDisplayName.of(name: authorName, address: authorAddr)
    }
}

// MARK: - 本地「回复了哪条评论」记录

enum SquareLocalReplyTargetStore {

    private static let keyPrefix = "chat_square_reply_target_"

    /// 每个帖子最多记多少条（防止长期使用无限增长）
    private static let maxEntriesPerPost = 200
    /// 最多保留多少个帖子
    private static let maxPosts = 100

    private static var storageKey: String {
        return keyPrefix + LoginUser.shared().address
    }

    /// postId → [回复评论id : 被回复评论id]
    private static var cache: [String: [String: Int]] {
        get {
            // UserDefaults 取回来是 [String: Any]，内层也要逐层转（直接强转嵌套字典不稳定）
            let raw = UserDefaults.standard.dictionary(forKey: storageKey) ?? [:]
            var result = [String: [String: Int]]()
            for (postKey, value) in raw {
                guard let inner = value as? [String: Any] else { continue }
                var map = [String: Int]()
                for (key, number) in inner {
                    if let number = number as? Int { map[key] = number }
                }
                result[postKey] = map
            }
            return result
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    /// 某个帖子下的映射（`回复评论id → 被回复评论id`），给楼层组装用
    static func targets(for postId: Int) -> [Int: Int] {
        guard postId > 0 else { return [:] }
        let raw = cache["\(postId)"] ?? [:]
        var result = [Int: Int]()
        result.reserveCapacity(raw.count)
        for (key, value) in raw {
            if let k = Int(key) { result[k] = value }
        }
        return result
    }

    /// 记一条：我发的回复 `replyId` 是在回 `parentId`
    static func save(replyId: Int, parentId: Int, postId: Int) {
        guard replyId > 0, parentId > 0, postId > 0, replyId != parentId else { return }
        var all = cache
        var postMap = all["\(postId)"] ?? [:]
        postMap["\(replyId)"] = parentId
        // 超上限时按 key 升序丢掉最旧的（评论 id 单调递增，数字大的是新的）
        if postMap.count > maxEntriesPerPost {
            let overflow = postMap.count - maxEntriesPerPost
            let oldKeys = postMap.keys.compactMap { Int($0) }.sorted().prefix(overflow).map { "\($0)" }
            oldKeys.forEach { postMap.removeValue(forKey: $0) }
        }
        all["\(postId)"] = postMap
        // 帖子数量也做个上限
        if all.count > maxPosts {
            let overflow = all.count - maxPosts
            let oldPosts = all.keys.compactMap { Int($0) }.sorted().prefix(overflow).map { "\($0)" }
            oldPosts.forEach { all.removeValue(forKey: $0) }
        }
        cache = all
    }
}

/// 评论楼层：主评论 + 其下的回复
/// 说明：接口（文档 §5.2）的评论对象没有 parentId/回复字段，所以回复关系按「正文开头的 @昵称 」约定推断，
/// 与客户端回复时自动插入的 `@昵称 ` 一一对应。服务端将来补上 parentId 后，只需替换本文件的组装规则。
struct SquareCommentThread {
    var comment: SquareComment
    var replies: [SquareComment]
    /// 服务端给的总回复数（旧本地组装时没有，用 `replies.count` 兜底）
    var replyCount: Int = 0
}

enum SquareCommentThreadBuilder {

    /// 把扁平评论列表组装成楼层
    /// - 规则：正文以「@某人」开头，且此前已有该人的评论 → 挂到该人最近的一条**主评论**下（只支持一层）
    /// - 找不目标时保持为独立评论，避免内容凭空消失
    /// - `localReplyTargets`：本机记下的「回复评论id → 被回复评论id」（`SquareLocalReplyTargetStore`）。
    ///   **优先用它的原因**：服务端没有 parentId，同一作者写多条评论时，纯文本只能挂到"最后一条"
    ///   （用户 2026-11-06：回复 A 的第 1 条评论，内容跑到了第 3 条下面）。本地有记录就用记录。
    static func build(_ comments: [SquareComment],
                      localReplyTargets: [Int: Int] = [:]) -> [SquareCommentThread] {
        guard !comments.isEmpty else { return [] }

        let indices = Array(comments.indices)

        // 按时间升序推断归属（本地待审评论 id = 0，视为最新）
        let ascending = indices.sorted { lhs, rhs in
            let leftId = comments[lhs].id
            let rightId = comments[rhs].id
            if leftId == rightId { return lhs < rhs }
            if leftId == 0 { return false }
            if rightId == 0 { return true }
            return leftId < rightId
        }

        var replyTarget = [Int: Int]()// 评论下标 → 主评论下标
        var mainByAuthor = [String: Int]()// 作者展示名 → 其最近的主评论下标

        // ① 先用「本机记下的回复关系」定楼层（最准），它们不再参与下面的文本推断
        var indexById = [Int: Int]()
        for index in indices where comments[index].id > 0 {
            indexById[comments[index].id] = index
        }
        var locallyResolved = Set<Int>()// 已经按本地记录挂好楼层的评论 id
        if !localReplyTargets.isEmpty {
            for (replyId, parentId) in localReplyTargets {
                guard let replyIndex = indexById[replyId],
                      let parentIndex = indexById[parentId],
                      replyIndex != parentIndex else { continue }
                // 被回复的那条本身可能是回复 ⇒ 一路找到它所属的**主评论**（最多 5 层，防脏数据死循环）
                var root = parentIndex
                var guardCount = 0
                while let up = localReplyTargets[comments[root].id],
                      let upIndex = indexById[up],
                      upIndex != root, guardCount < 5 {
                    root = upIndex
                    guardCount += 1
                }
                replyTarget[replyIndex] = root
                locallyResolved.insert(replyId)
            }
        }

        // ② 剩下的按「@昵称」文本推断（历史约定，服务端补 parentId 之前的老数据只能这样）
        for index in ascending {
            let comment = comments[index]
            if locallyResolved.contains(comment.id) { continue }
            if let mention = leadingMention(in: comment.content), let target = mainByAuthor[mention] {
                // 回复不再写入 mainByAuthor：回复的回复同样挂到该楼层下（保持一层）
                replyTarget[index] = target
            } else {
                mainByAuthor[displayName(of: comment)] = index
            }
        }

        var repliesByMain = [Int: [SquareComment]]()
        for index in indices {
            if let target = replyTarget[index] {
                repliesByMain[target, default: []].append(comments[index])
            }
        }

        // 楼层按主评论在服务端返回顺序中的位置输出
        return indices.compactMap { index -> SquareCommentThread? in
            guard replyTarget[index] == nil else { return nil }
            return SquareCommentThread(comment: comments[index], replies: repliesByMain[index] ?? [])
        }
    }

    /// 同一评论在列表/详情中展示的名字（与回复时插入的 @ 名称保持一致）
    static func displayName(of comment: SquareComment) -> String {
        return comment.displayName
    }

    /// 取正文开头的「@某人」（到第一个空格/换行为止），没有则返回 nil
    static func leadingMention(in content: String) -> String? {
        guard content.hasPrefix("@") else { return nil }
        let rest = content.dropFirst()
        guard let end = rest.firstIndex(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) else { return nil }
        let name = String(rest[rest.startIndex..<end])
        return name.isEmpty ? nil : name
    }
}

// MARK: - 评论回复分页 / 收件箱（《App增量-评论回复》）

/// 评论楼层分页（`GET /posts/:id/comments?thread=1`）
/// - `total`：楼数（翻页用）
/// - `commentCount`：含回复的可见评论数（显示「N 条评论」用）
/// - 每楼 `replies` 最多 2 条，更早的在前
struct SquareCommentThreadPage {

    var threads: [SquareCommentThread] = []
    var total = 0
    var commentCount = 0
    var page = 1
    var pageSize = SquareLimits.defaultPageSize

    var hasMore: Bool {
        // total 缺失时按「一次性返回全部」处理，避免服务端忽略分页参数时反复拉同一页
        guard total > threads.count else { return false }
        return page * pageSize < total
    }

    init(json: JSON) {
        self.total = json["total"].int ?? 0
        self.commentCount = json["commentCount"].int ?? 0
        self.page = max(json["page"].int ?? 1, 1)
        self.pageSize = max(json["pageSize"].int ?? SquareLimits.defaultPageSize, 1)
        self.threads = json["list"].arrayValue.compactMap { item in
            let comment = SquareComment(json: item)
            // 一级评论已删除但仍有回复：服务端给 deleted=true，正文/作者为空，仍要展示
            guard comment.id > 0 || comment.deleted else { return nil }
            let replies = item["replies"].arrayValue.map { SquareComment(json: $0) }
            let count = item["replyCount"].int ?? replies.count
            return SquareCommentThread(comment: comment, replies: replies, replyCount: count)
        }
    }
}

/// 某楼回复分页（`GET /posts/:id/comments/:commentId/replies`）
struct SquareReplyPage {

    var list: [SquareComment] = []
    var total = 0
    var page = 1
    var pageSize = SquareLimits.defaultPageSize

    var hasMore: Bool {
        guard total > list.count else { return false }
        return page * pageSize < total
    }

    init(json: JSON) {
        self.list = json["list"].arrayValue.map { SquareComment(json: $0) }
        self.total = json["total"].int ?? self.list.count
        self.page = max(json["page"].int ?? 1, 1)
        self.pageSize = max(json["pageSize"].int ?? SquareLimits.defaultPageSize, 1)
    }
}

/// 收件箱一条记录（`GET /replies`）
struct SquareReplyInboxItem {

    var id = 0
    var postId = 0
    /// 被回复/被评论的那条评论 id（点进详情后定位用）
    var commentId = 0
    /// 所属一级评论 id；服务端没给时用 0（定位时回退到 `commentId`）
    var parentId = 0
    /// 0 = 有人评论了我的帖；> 0 = 有人回复了我的评论
    var replyToId = 0
    var authorAddr = ""
    var authorName = ""
    var content = ""
    var postTitle = ""
    var postAvailable = false
    var available = false
    var read = false
    var createdAt = ""
    var createdDate: Date?

    /// 是否是「回复我的评论」（否则是「评论我的帖子」）
    var isReplyToComment: Bool { return replyToId > 0 }

    init(json: JSON) {
        // 字段名多候选兼容：后端不同版本可能用 id / replyId、authorAddr / fromAddress
        self.id = json["id"].int ?? json["replyId"].int ?? 0
        self.postId = json["postId"].int ?? 0
        self.commentId = json["commentId"].int ?? json["replyCommentId"].int ?? self.id
        self.parentId = json["parentId"].int ?? 0
        self.replyToId = json["replyToId"].int ?? 0
        self.authorAddr = json["authorAddr"].string ?? json["fromAddress"].string ?? ""
        self.authorName = json["authorName"].string ?? json["fromName"].string ?? ""
        self.content = json["content"].string ?? ""
        self.postTitle = json["postTitle"].string ?? ""
        self.postAvailable = json["postAvailable"].bool ?? true
        self.available = json["available"].bool ?? false
        self.read = json["read"].bool ?? ((json["readFlag"].int ?? 0) == 1)
        self.createdAt = json["createdAt"].string ?? ""
        self.createdDate = SquareDateParser.date(from: createdAt)
    }
}

/// 收件箱分页
struct SquareReplyInboxPage {

    var list: [SquareReplyInboxItem] = []
    var total = 0
    var page = 1
    var pageSize = SquareLimits.defaultPageSize
    /// 与 `read=0` 同一口径：未读且 `available=true`
    var unreadCount = 0

    var hasMore: Bool {
        // 文档没给收件箱分页参数：total 缺失 / 等于本页条数时按「全部返回」处理
        guard total > list.count else { return false }
        return page * pageSize < total
    }

    init(json: JSON) {
        self.list = json["list"].arrayValue.map { SquareReplyInboxItem(json: $0) }
        self.total = json["total"].int ?? self.list.count
        self.page = max(json["page"].int ?? 1, 1)
        self.pageSize = max(json["pageSize"].int ?? SquareLimits.defaultPageSize, 1)
        self.unreadCount = json["unreadCount"].int ?? 0
    }
}

// MARK: - 分页容器

struct SquarePage<T> {

    private(set) var list: [T] = []
    private(set) var total = 0
    private(set) var page = 1
    private(set) var pageSize = SquareLimits.defaultPageSize

    /// 是否还有下一页。
    /// ⚠️ `/follows`、`/followers` 文档只承诺分页参数，没承诺返回 `total`；
    /// 拿不到 `total` 时按「本页拿满」判断，否则会永远认为没有下一页（拉不到第二页）。
    var hasMore: Bool {
        guard total > 0 else { return list.count >= pageSize }
        return page * pageSize < total
    }

    /// 空分页（接口 `data` 为 null 时用）：按「空名单」处理，**不要当接口失败**
    /// （当失败会让关注名单永远拉不到、所有关注按钮都显示未关注）
    init() {}

    init(json: JSON, decode: (JSON) -> T?) {
        self.list = json["list"].arrayValue.compactMap { decode($0) }
        self.total = json["total"].int ?? 0
        let page = json["page"].int ?? 1
        let pageSize = json["pageSize"].int ?? SquareLimits.defaultPageSize
        self.page = page > 0 ? page : 1
        self.pageSize = pageSize > 0 ? pageSize : SquareLimits.defaultPageSize
    }
}

// MARK: - 点赞 / 删除 / 评论开关

struct SquareLikeResult {
    var likeCount = 0
    var liked = false

    init(json: JSON) {
        self.likeCount = json["likeCount"].int ?? 0
        self.liked = json["liked"].bool ?? false
    }
}

struct SquareIDResult {
    var id = 0

    init(json: JSON) {
        self.id = json["id"].int ?? 0
    }
}

struct SquareCommentsEnabledResult {
    var id = 0
    var enabled = true

    init(json: JSON) {
        self.id = json["id"].int ?? 0
        self.enabled = json["enabled"].bool ?? true
    }
}

/// 修改公众号资料返回：`PUT /square/app/official` → data `{ address, name, avatar }`
struct SquareOfficialProfile {
    var address = ""
    var name = ""
    var avatar = ""

    init(json: JSON) {
        self.address = json["address"].string ?? ""
        self.name = json["name"].string ?? ""
        self.avatar = json["avatar"].string ?? ""
    }
}

// MARK: - 公众号

struct SquareOfficialInfo {
    var name = ""
    var avatar = ""
    var intro = ""
    /// 1 正常 / 2 封禁
    var status = 1

    init(json: JSON) {
        self.name = json["name"].string ?? ""
        self.avatar = json["avatar"].string ?? ""
        self.intro = json["intro"].string ?? ""
        self.status = json["status"].int ?? 1
    }

    var isBanned: Bool { status == 2 }
}

struct SquareApplyInfo {
    var id = 0
    var status = ""
    var name = ""
    var remark = ""

    init(json: JSON) {
        self.id = json["id"].int ?? 0
        self.status = json["status"].string ?? ""
        self.name = json["name"].string ?? ""
        self.remark = json["remark"].string ?? ""
    }
}

struct SquareOfficialMe {

    var state: SquareOfficialState = .none
    var address = ""
    /// 已有公众号时存在
    var official: SquareOfficialInfo?
    /// 最近一次申请
    var apply: SquareApplyInfo?
    /// 广场开关（《App增量-广场开关与审核强度》§2）：这里的同结构字段可复用，少发一次请求
    var square: SquareStatus?

    init(json: JSON) {
        self.state = SquareOfficialState(raw: json["state"].string ?? "none")
        self.address = json["address"].string ?? ""
        if let officialJson = json["official"].dictionaryObject {
            self.official = SquareOfficialInfo(json: JSON(officialJson))
        }
        if let applyJson = json["apply"].dictionaryObject {
            self.apply = SquareApplyInfo(json: JSON(applyJson))
        }
        if let squareJson = json["square"].dictionaryObject {
            self.square = SquareStatus(json: JSON(squareJson))
        }
    }
}

struct SquareApplyResult {
    var id = 0
    var status = ""
    var name = ""

    init(json: JSON) {
        self.id = json["id"].int ?? 0
        self.status = json["status"].string ?? ""
        self.name = json["name"].string ?? ""
    }
}

// MARK: - 广场开关 / 金标 / 关注 / 举报 / 我的帖子流量

/// 广场开关（《App增量-广场开关与审核强度》§2）：
/// 始终 result=0，用 canRead / canPost 判断，不要把关闭当接口失败
struct SquareStatus {

    /// 未知 / 未取到接口时的默认值：可读可发（读不到就别拦用户）
    static let empty = SquareStatus()

    var canRead = true
    var canPost = true
    /// canRead == false 时的关闭说明（运营可改文案，原样展示）
    var message = ""

    init(canRead: Bool = true, canPost: Bool = true, message: String = "") {
        self.canRead = canRead
        self.canPost = canPost
        self.message = message
    }

    init(json: JSON) {
        self.canRead = json["canRead"].bool ?? true
        self.canPost = json["canPost"].bool ?? true
        self.message = json["message"].string ?? ""
    }
}

/// 金标公众号卡片（《App增量-公众号金标》§3）
struct SquareOfficialCard {

    var address = ""
    var name = ""
    var avatar = ""
    var intro = ""
    var gold = false
    var postCount = 0
    var followerCount = 0
    /// 当前登录地址是否已关注
    var followed = false

    init(json: JSON) {
        self.address = json["address"].string ?? ""
        self.name = json["name"].string ?? ""
        self.avatar = json["avatar"].string ?? ""
        self.intro = json["intro"].string ?? ""
        self.gold = json["gold"].bool ?? false
        self.postCount = json["postCount"].int ?? 0
        self.followerCount = json["followerCount"].int ?? 0
        self.followed = json["followed"].bool ?? false
    }

    /// 展示名（名字为空时回落短地址）
    var displayName: String {
        return SquareDisplayName.of(name: name, address: address)
    }
}

/// 关注 / 粉丝列表一行（《App增量-关注热门举报流量》§3）
struct SquareFollowItem {

    var address = ""
    var name = ""
    var avatar = ""
    /// 0 个人 / 1 公众号
    var targetKind: SquareAuthorKind = .person
    var followedAt = ""

    init(json: JSON) {
        self.address = json["address"].string ?? ""
        self.name = json["name"].string ?? ""
        self.avatar = json["avatar"].string ?? ""
        self.targetKind = SquareAuthorKind(raw: json["targetKind"].int ?? 0)
        self.followedAt = json["followedAt"].string ?? ""
    }

    /// 展示名（个人号没发过帖时服务端可能不给名字，回落短地址）
    var displayName: String {
        return SquareDisplayName.of(name: name, address: address)
    }
}

/// 关注 / 取关返回：`{ targetAddr, followed }`
struct SquareFollowResult {
    var targetAddr = ""
    var followed = false

    init(targetAddr: String = "", followed: Bool = false) {
        self.targetAddr = targetAddr
        self.followed = followed
    }

    init(json: JSON) {
        self.targetAddr = json["targetAddr"].string ?? ""
        self.followed = json["followed"].bool ?? false
    }
}

/// 举报返回：`{ id, targetId, reason, status }`
struct SquareReportResult {
    var id = 0
    var targetId = 0
    var reason = ""
    /// 0 待处理
    var status = 0

    init(json: JSON) {
        self.id = json["id"].int ?? 0
        self.targetId = json["targetId"].int ?? 0
        self.reason = json["reason"].string ?? ""
        self.status = json["status"].int ?? 0
    }
}

/// 我的帖子 + 流量汇总（《App增量-关注热门举报流量》§5，`GET /square/app/me/posts`）
/// 文档口径：不含已删、不含草稿；含可见 / 隐藏 / 待审 / AI 拒绝
struct SquareMyPostsPage {

    var list = [SquarePost]()
    /// 列表总数（同上口径）
    var total = 0
    var totalPosts = 0
    var totalViews = 0
    var totalLikes = 0
    var totalComments = 0

    init(json: JSON) {
        self.list = json["list"].arrayValue.map { SquarePost(json: $0) }
        self.total = json["total"].int ?? self.list.count
        self.totalPosts = json["totalPosts"].int ?? 0
        self.totalViews = json["totalViews"].int ?? 0
        self.totalLikes = json["totalLikes"].int ?? 0
        self.totalComments = json["totalComments"].int ?? 0
    }

    /// 是否还有下一页
    func hasMore(page: Int, pageSize: Int) -> Bool {
        guard total > 0 else { return list.count >= pageSize }
        return page * pageSize < total
    }
}

// MARK: - 时间解析

enum SquareDateParser {

    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// 解析服务端 RFC3339 时间（如 2026-09-15T11:00:00+08:00），失败返回 nil
    static func date(from string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return withFraction.date(from: string) ?? standard.date(from: string)
    }

    /// Date → RFC3339 文本（本地待审快照回填用，保持与服务端同一格式）
    static func string(from date: Date) -> String {
        return standard.string(from: date)
    }

    private static let todayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let thisYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // 用户 2026-09-24：超过一天只显示几月几号，**不显示具体时间点**（原来是 MM-dd HH:mm）
        formatter.dateFormat = "MM-dd"
        return formatter
    }()

    private static let otherYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 列表/详情展示用的时间文案：
    /// - 距今不足 24 小时：刚刚 / N分钟前 / N小时前（**不显示「昨天」**，凌晨看到昨晚发的帖子只会是「1小时前」）；
    /// - 距今超过 24 小时：昨天、今年 MM-dd、跨年 yyyy-MM-dd（**只到「几月几号」，不再带时间点**）
    static func displayText(from date: Date?) -> String {
        guard let date = date else { return "" }
        // 服务端时间可能比本机稍快（elapsed 为负），那种情况交给下面的日期分支处理
        let elapsed = Date().timeIntervalSince(date)
        if elapsed >= 0, elapsed < 24 * 60 * 60 {
            let minutes = Int(elapsed) / 60
            if minutes < 1 {
                return L("刚刚")
            }
            if minutes < 60 {
                return String(format: L("%d分钟前"), minutes)
            }
            return String(format: L("%d小时前"), minutes / 60)
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return todayFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return L("昨天")
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return thisYearFormatter.string(from: date)
        }
        return otherYearFormatter.string(from: date)
    }
}

// MARK: - 导航栏样式

extension UIViewController {

    /// 广场各页统一的导航栏样式：白底、深色标题，**不要**底部那条细线。
    ///
    /// 为什么要显式设置：iOS 15 起导航栏走 `UINavigationBarAppearance` ——
    /// 列表在顶部时用 `scrollEdgeAppearance`（没有细线），一滚动就切成 `standardAppearance`，
    /// 而它自带一条分隔线，表现就是「只要滑动页面，导航栏下面就冒出一条黑线」。
    /// 把 shadowColor / shadowImage 清掉即可（工程里其它页面也是这么处理的）。
    func applySquareNavBarStyle() {
        guard let bar = self.navigationController?.navigationBar else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
        appearance.buttonAppearance.normal.backgroundImage = UIImage()
        appearance.buttonAppearance.highlighted.backgroundImage = UIImage()
        appearance.doneButtonAppearance.normal.backgroundImage = UIImage()
        appearance.doneButtonAppearance.highlighted.backgroundImage = UIImage()
        appearance.backButtonAppearance.normal.backgroundImage = UIImage()
        appearance.backButtonAppearance.highlighted.backgroundImage = UIImage()
        appearance.backgroundColor = Color_FFFFFF
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        appearance.titleTextAttributes = [.foregroundColor: Color_24374E]
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = Color_24374E
    }
}
