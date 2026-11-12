//
//  SquareAPI.swift
//  chat
//
//  谈信广场接口定义（对接文档 §4 接口一览）
//  注意：广场响应 HTTP 恒为 200，业务结果看 body 里的 result；
//  因此这里覆盖 validation，把「整个响应信封」交给 SquareService 判定，不复用基类的 data-only 逻辑。
//

import Foundation
import Moya
import Alamofire
import SwiftyJSON

/// 公众号相关能力开关：客户端代码已按约定实现，后端把接口补上后把开关打开即可
enum SquareOfficialAPI {

    /// 公众号资料修改（名称 / 头像）是否可用
    /// 对接文档 §6.12：`PUT /square/app/official`，body `{ name, avatar }`
    /// - 仅 `state=approved` 可用；封禁号 `-20405`，未开号 `-20404`
    /// - 成功返回 `data: { address, name, avatar }`；改昵称后历史公众号帖展示名同步
    static let supportsProfileUpdate = true
}

enum SquareAPI {
    /// 探活 GET /square/healthz（无需签名）
    case healthz
    /// 广场流 GET /square/app/posts（可选 `feed` 排序口径 + `kind` / `tag` / `authorAddr` 过滤）
    case feed(page: Int, pageSize: Int, feed: String?, kind: Int?, tag: String?, authorAddr: String?)
    /// 帖子详情 GET /square/app/posts/:id
    case postDetail(id: Int)
    /// 发帖 POST /square/app/posts
    case createPost(content: String, nickname: String?, mediaUrls: [String], commentsEnabled: Bool?)
    /// 删自己的帖 DELETE /square/app/posts/:id
    case deletePost(id: Int)
    /// 点赞 POST /square/app/posts/:id/like
    case like(id: Int)
    /// 取消点赞 DELETE /square/app/posts/:id/like
    case unlike(id: Int)
    /// 评论列表 GET /square/app/posts/:id/comments（`thread=true` 只返回楼，带 `replies` / `replyCount`）
    case comments(postId: Int, page: Int, pageSize: Int, thread: Bool)
    /// 发评论 / 回复 POST /square/app/posts/:id/comments（`replyToId > 0` 表示回复某条评论）
    case createComment(postId: Int, content: String, nickname: String?, replyToId: Int?)
    /// 某楼回复分页 GET /square/app/posts/:postId/comments/:commentId/replies
    case commentReplies(postId: Int, commentId: Int, page: Int, pageSize: Int)
    /// 收件箱 GET /square/app/replies（`read`：nil 全部 / 0 未读 / 1 已读）
    case replyInbox(read: Int?, page: Int, pageSize: Int)
    /// 标已读 POST /square/app/replies/read（`all=true` 或指定 `ids`）
    case markRepliesRead(ids: [Int], all: Bool)
    /// 删自己的评论 DELETE /square/app/comments/:id
    case deleteComment(id: Int)
    /// 开关评论 PUT /square/app/posts/:id/comments-enabled（仅公众号作者）
    case setCommentsEnabled(postId: Int, enabled: Bool)
    /// 我的公众号 GET /square/app/official/me
    case officialMe
    /// 申请公众号 POST /square/app/official/apply
    case officialApply(name: String, avatar: String?, intro: String?)
    /// 修改公众号名称 / 头像 PUT /square/app/official（仅已通过公众号）
    case officialUpdate(name: String, avatar: String?)

    // MARK: - 2026-09 增量（《App增量-广场开关》《关注热门举报流量》《公众号金标》《置顶与二次编辑》）
    // 不做「接口没上线就先藏起来」的功能开关：入口全部放出，失败按普通错误提示（码以服务端为准）。

    /// 广场开关 GET /square/app/status（canRead / canPost）
    case status
    /// 公众号目录 GET /square/app/officials（`gold` 传 nil = **全部**正常号，true = 只出金标）
    case officials(gold: Bool?, page: Int, pageSize: Int)
    /// 我的帖子 + 流量汇总 GET /square/app/me/posts
    case myPosts(page: Int, pageSize: Int)
    /// 关注 POST /square/app/follows（body `{ targetAddr }`）
    case follow(targetAddr: String)
    /// 取消关注 DELETE /square/app/follows/:addr
    case unfollow(targetAddr: String)
    /// 我关注的列表 GET /square/app/follows
    case followList(page: Int, pageSize: Int)
    /// 关注我的列表 GET /square/app/followers
    case followerList(page: Int, pageSize: Int)
    /// 举报帖子 / 公众号文章 POST /square/app/posts/:id/report
    case report(postId: Int, reason: String, detail: String)
    /// 二次编辑自己的已发帖 PUT /square/app/posts/:id
    case updatePost(id: Int, content: String, nickname: String?, mediaUrls: [String], commentsEnabled: Bool?)
}

extension SquareAPI: XLSTargetType {

    var baseURL: URL {
        // 基址见 SeverContext.swift 的 SquareBaseURL（未配置时为空字符串）
        return URL.init(string: SquareBaseURL) ?? UNCONFIGURED_SERVER_URL
    }

    var path: String {
        switch self {
        case .healthz:
            return "/square/healthz"
        case .feed:
            return "/square/app/posts"
        case .postDetail(let id):
            return "/square/app/posts/\(id)"
        case .createPost:
            return "/square/app/posts"
        case .deletePost(let id):
            return "/square/app/posts/\(id)"
        case .like(let id):
            return "/square/app/posts/\(id)/like"
        case .unlike(let id):
            return "/square/app/posts/\(id)/like"
        case .comments(let postId, _, _, _):
            return "/square/app/posts/\(postId)/comments"
        case .createComment(let postId, _, _, _):
            return "/square/app/posts/\(postId)/comments"
        case .commentReplies(let postId, let commentId, _, _):
            return "/square/app/posts/\(postId)/comments/\(commentId)/replies"
        case .replyInbox:
            return "/square/app/replies"
        case .markRepliesRead:
            return "/square/app/replies/read"
        case .deleteComment(let id):
            return "/square/app/comments/\(id)"
        case .setCommentsEnabled(let postId, _):
            return "/square/app/posts/\(postId)/comments-enabled"
        case .officialMe:
            return "/square/app/official/me"
        case .officialApply:
            return "/square/app/official/apply"
        case .officialUpdate:
            return "/square/app/official"
        case .status:
            return "/square/app/status"
        case .officials:
            return "/square/app/officials"
        case .myPosts:
            return "/square/app/me/posts"
        // 关注 / 我的关注同一路径，方法不同（POST / GET）
        case .follow, .followList:
            return "/square/app/follows"
        case .unfollow(let targetAddr):
            return "/square/app/follows/\(targetAddr)"
        case .followerList:
            return "/square/app/followers"
        case .report(let postId, _, _):
            return "/square/app/posts/\(postId)/report"
        case .updatePost(let id, _, _, _, _):
            return "/square/app/posts/\(id)"
        }
    }

    var method: Moya.Method {
        switch self {
        case .healthz, .feed, .postDetail, .comments, .commentReplies, .replyInbox, .officialMe,
             .status, .officials, .myPosts, .followList, .followerList:
            return .get
        case .createPost, .like, .createComment, .markRepliesRead, .officialApply, .follow, .report:
            return .post
        case .deletePost, .unlike, .deleteComment, .unfollow:
            return .delete
        case .setCommentsEnabled, .officialUpdate, .updatePost:
            return .put
        }
    }

    /// GET → query 参数；写接口 → JSON body 参数（可选项为空时不传，避免服务端 -1012）
    var parameters: [String: Any] {
        switch self {
        case .healthz, .postDetail, .deletePost, .like, .unlike, .deleteComment, .officialMe,
             .status, .unfollow:
            return [:]
        case .feed(let page, let pageSize, let feed, let kind, let tag, let authorAddr):
            var params: [String: Any] = ["page": page, "pageSize": pageSize]
            if let feed = feed, !feed.isEmpty {
                params["feed"] = feed
            }
            if let kind = kind {
                params["kind"] = kind
            }
            // 官方帖分类筛选（《App增量-官方帖标签》§3）：只对平台官方帖有意义，中文原样上传
            if let tag = tag, !tag.isEmpty {
                params["tag"] = tag
            }
            if let authorAddr = authorAddr, !authorAddr.isEmpty {
                params["authorAddr"] = authorAddr
            }
            return params
        case .officials(let gold, let page, let pageSize):
            var params: [String: Any] = ["page": page, "pageSize": pageSize]
            // 文档 §3：`gold` **可多值** —— `gold=1&gold=0` 出**全部**正常号；省略或无法解析时默认 `1`（只出金标）。
            // 用 Int 而不是 Bool，避免各编码器把 true 写成 "true"；nil = 全部（数组 + 下面 `.noBrackets` 编码）
            params["gold"] = gold.map { [$0 ? 1 : 0] } ?? [1, 0]
            return params
        case .myPosts(let page, let pageSize),
             .followList(let page, let pageSize),
             .followerList(let page, let pageSize):
            return ["page": page, "pageSize": pageSize]
        case .follow(let targetAddr):
            return ["targetAddr": targetAddr]
        case .report(_, let reason, let detail):
            var params: [String: Any] = ["reason": reason]
            if !detail.isEmpty {
                params["detail"] = detail
            }
            return params
        case .updatePost(_, let content, let nickname, let mediaUrls, let commentsEnabled):
            // 与 POST /posts 同一套字段（文档：《App增量-置顶与二次编辑》§3）
            var params: [String: Any] = ["content": content, "mediaUrls": mediaUrls]
            if let nickname = nickname, !nickname.isEmpty {
                params["nickname"] = nickname
            }
            if let commentsEnabled = commentsEnabled {
                params["commentsEnabled"] = commentsEnabled
            }
            return params
        case .comments(_, let page, let pageSize, let thread):
            var params: [String: Any] = ["page": page, "pageSize": pageSize]
            if thread {
                params["thread"] = 1
            }
            return params
        case .commentReplies(_, _, let page, let pageSize):
            return ["page": page, "pageSize": pageSize]
        case .replyInbox(let read, let page, let pageSize):
            var params: [String: Any] = ["page": page, "pageSize": pageSize]
            if let read = read {
                params["read"] = read
            }
            return params
        case .markRepliesRead(let ids, let all):
            return all ? ["all": true] : ["ids": ids]
        case .createPost(let content, let nickname, let mediaUrls, let commentsEnabled):
            var params: [String: Any] = ["content": content, "mediaUrls": mediaUrls]
            if let nickname = nickname, !nickname.isEmpty {
                params["nickname"] = nickname
            }
            if let commentsEnabled = commentsEnabled {
                params["commentsEnabled"] = commentsEnabled
            }
            return params
        case .createComment(_, let content, let nickname, let replyToId):
            var params: [String: Any] = ["content": content]
            if let nickname = nickname, !nickname.isEmpty {
                params["nickname"] = nickname
            }
            // 不传或 0 = 一级评论；> 0 = 回复该条可见评论
            if let replyToId = replyToId, replyToId > 0 {
                params["replyToId"] = replyToId
            }
            return params
        case .setCommentsEnabled(_, let enabled):
            return ["enabled": enabled]
        case .officialApply(let name, let avatar, let intro):
            var params: [String: Any] = ["name": name]
            if let avatar = avatar, !avatar.isEmpty {
                params["avatar"] = avatar
            }
            if let intro = intro, !intro.isEmpty {
                params["intro"] = intro
            }
            return params
        case .officialUpdate(let name, let avatar):
            // 注意：文档只接受 name + avatar（没有 intro）；avatar 传空字符串表示清空
            var params: [String: Any] = ["name": name]
            if let avatar = avatar {
                params["avatar"] = avatar
            }
            return params
        }
    }

    var task: Task {
        switch self {
        case .healthz, .postDetail, .deletePost, .like, .unlike, .deleteComment, .officialMe,
             .status, .unfollow:
            // 无 query 也无 body，避免给 GET/DELETE 带上空的 JSON body
            return .requestPlain
        case .feed, .comments, .commentReplies, .replyInbox, .myPosts, .followList, .followerList:
            return .requestParameters(parameters: parameters, encoding: URLEncoding.queryString)
        case .officials:
            // `gold` 是多值参数，必须编成 `gold=1&gold=0`
            // （默认的 `.brackets` 会编成 `gold[]=1&gold[]=0`，服务端不认）
            return .requestParameters(parameters: parameters,
                                      encoding: URLEncoding(destination: .queryString, arrayEncoding: .noBrackets))
        default:
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        }
    }

    var headers: [String: String]? {
        // 探活不需要签名（文档 §4）
        if case .healthz = self {
            return nil
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let signature = SquareSignature.shared.token() ?? ""
        return [
            "FZM-SIGNATURE": signature,
            "FZM-VERSION": version,
            "FZM-UUID": String.uuid(),
            "FZM-DEVICE": "iOS",
            "FZM-DEVICE-NAME": k_DeviceName
        ]
    }

    /// 覆盖基类实现：返回完整响应信封（result / message / data），业务码判定交给 SquareService
    func validation(_ result: Result<Moya.Response, MoyaError>) -> Result<JSON, Error> {
        switch result {
        case .success(let response):
            guard response.statusCode == 200 else {
                let error = NSError.init(domain: "square", code: response.statusCode,
                                         userInfo: [NSLocalizedDescriptionKey: L("网络连接错误，请稍后再试")])
                return Result<JSON, Error>.failure(error)
            }

            guard let json = try? JSON.init(data: response.data) else {
                let error = NSError.init(domain: "square", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: L("数据解析失败，请稍后再试")])
                return Result<JSON, Error>.failure(error)
            }

            let rawString = response.data.count > 300 ? (String.init(data: response.data.prefix(300), encoding: .utf8) ?? "") : (String.init(data: response.data, encoding: .utf8) ?? "")
            // 带上完整 URL（含 query）方便排查「参数到底传了什么」
            let urlString = response.request?.url?.absoluteString ?? path
            FZMLog("广场响应 \(urlString) \(rawString)")

            return Result<JSON, Error>.success(json)

        case .failure(let error):
            var errorInfo = ""
            switch error.errorCode {
            case NSURLErrorNotConnectedToInternet:
                errorInfo = L("无网络，请检查网络连接")
            case NSURLErrorTimedOut:
                errorInfo = L("请求超时，请检查网络连接")
            default:
                errorInfo = L("网络连接错误，请稍后再试")
            }
            FZMLog("广场请求失败 \(path) \(error.errorCode) \(errorInfo)")
            let nsError = NSError.init(domain: "square", code: error.errorCode,
                                       userInfo: [NSLocalizedDescriptionKey: errorInfo])
            return Result<JSON, Error>.failure(nsError)
        }
    }
}
