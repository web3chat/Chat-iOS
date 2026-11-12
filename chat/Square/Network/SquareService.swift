//
//  SquareService.swift
//  chat
//
//  谈信广场数据门面：
//  - 所有回调都在主线程（Moya 的 callbackQueue 为 main，Alamofire 的 response 默认也是 main）
//  - 业务以响应体里的 result 为准，HTTP 状态码不做业务判断
//  - result = -20402（已提交，等待审核）按「成功待审」处理
//  - 写接口（发帖/评论/点赞/删除）不做自动重试，避免重复提交；仅 -1011 重签重试一次
//

import Foundation
import UIKit
import Moya
import Alamofire
import SwiftyJSON

final class SquareService {

    static let shared = SquareService()

    private init() {}

    // MARK: - 探活

    /// 环境探活（无需签名）：成功返回 {"ok":true}
    @discardableResult
    func healthz(success: ((Bool) -> Void)?, failure: ((SquareFailure) -> Void)? = nil) -> Cancellable? {
        FZMLog("广场探活 \(SquareBaseURL)/square/healthz")
        return Provider.request(SquareAPI.healthz, successBlock: { json in
            let ok = json["ok"].bool ?? (json["result"].int == 0)
            success?(ok)
        }, failureBlock: { error in
            failure?(SquareFailure(error: error))
        })
    }

    // MARK: - 广场流 / 详情

    /// 广场流（列表只返回 status=1 的可见帖）
    /// - Parameter feedMode: 排序口径 `latest` / `hot` / `following`（《App增量-关注热门举报流量》§2）
    /// - Parameter authorAddr: 只看某个地址发的帖（对接文档 §6.1 `authorAddr`），用于「作者信息页」
    @discardableResult
    func feed(page: Int = 1,
              pageSize: Int = SquareLimits.defaultPageSize,
              feedMode: SquareFeedMode = .latest,
              kind: SquareFeedKind = .all,
              tag: String? = nil,
              authorAddr: String? = nil,
              success: ((SquarePage<SquarePost>) -> Void)?,
              failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.feed(page: max(page, 1), pageSize: size,
                                 feed: feedMode.rawValue, kind: kind.apiValue, tag: tag, authorAddr: authorAddr)
        return request(api, decode: { json in
            guard json.type != .null else { return nil }
            return SquarePage<SquarePost>(json: json, decode: { SquarePost(json: $0) })
        }, success: success, failure: failure)
    }

    /// 帖子详情（非作者且当日未读过会 +1 阅读数；非作者看未过审帖会 -20404）
    @discardableResult
    func postDetail(id: Int,
                    success: ((SquarePost) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.postDetail(id: id), decode: { json in
            guard json.type != .null else { return nil }
            return SquarePost(json: json)
        }, success: success, failure: failure)
    }

    // MARK: - 发帖 / 删除

    /// 发帖；`-20402` 走 success(.pendingReview)（内容已入库，等运营台审核）
    @discardableResult
    func createPost(content: String,
                    nickname: String? = nil,
                    mediaUrls: [String] = [],
                    commentsEnabled: Bool? = nil,
                    success: ((SquareSubmitOutcome<SquarePost>) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let nickname = nickname ?? LoginUser.shared().nickName?.value
        let api = SquareAPI.createPost(content: content,
                                      nickname: nickname,
                                      mediaUrls: Array(mediaUrls.prefix(SquareLimits.maxImageCount)),
                                      commentsEnabled: commentsEnabled)
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                if code == SquareResultCode.pendingReview.rawValue {
                    success?(.pendingReview)
                } else if code == 0 {
                    // data 可能为 null（服务端只回 result），此时也算发布成功，页面随后会刷新列表
                    let post = json["data"].type == .null ? SquarePost(json: JSON([:])) : SquarePost(json: json["data"])
                    success?(.published(post))
                } else {
                    failure?(SquareFailure(json: json))
                }
            }
        }
    }

    /// 删自己的帖子（软删，status=3）；success 回传被删的帖子 id
    @discardableResult
    func deletePost(id: Int,
                    success: ((Int) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.deletePost(id: id), decode: { json in
            let deletedId = json["id"].int ?? id
            return deletedId
        }, success: success, failure: failure)
    }

    // MARK: - 点赞

    /// 点赞（幂等）
    @discardableResult
    func like(postId: Int,
              success: ((SquareLikeResult) -> Void)?,
              failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.like(id: postId), decode: { json in
            guard json.type != .null else { return nil }
            return SquareLikeResult(json: json)
        }, success: success, failure: failure)
    }

    /// 取消点赞（幂等，不走点赞限流）
    @discardableResult
    func unlike(postId: Int,
                success: ((SquareLikeResult) -> Void)?,
                failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.unlike(id: postId), decode: { json in
            guard json.type != .null else { return nil }
            return SquareLikeResult(json: json)
        }, success: success, failure: failure)
    }

    /// 按当前状态切换点赞 / 取消点赞
    @discardableResult
    func toggleLike(post: SquarePost,
                    success: ((SquareLikeResult) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        if post.liked {
            return unlike(postId: post.id, success: success, failure: failure)
        }
        return like(postId: post.id, success: success, failure: failure)
    }

    // MARK: - 评论

    /// 评论列表（帖子必须对当前用户可见）
    @discardableResult
    func comments(postId: Int,
                  page: Int = 1,
                  pageSize: Int = SquareLimits.defaultPageSize,
                  success: ((SquarePage<SquareComment>) -> Void)?,
                  failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.comments(postId: postId, page: max(page, 1), pageSize: size, thread: false)
        return request(api, decode: { json in
            guard json.type != .null else { return nil }
            return SquarePage<SquareComment>(json: json, decode: { SquareComment(json: $0) })
        }, success: success, failure: failure)
    }

    /// 评论楼层（`thread=1`）：每楼带最多 2 条回复和总回复数
    @discardableResult
    func commentThreads(postId: Int,
                        page: Int = 1,
                        pageSize: Int = SquareLimits.defaultPageSize,
                        success: ((SquareCommentThreadPage) -> Void)?,
                        failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.comments(postId: postId, page: max(page, 1), pageSize: size, thread: true)
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                FZMLog("广场评论：thread 失败 post=\(postId) code=\(error.rawCode)")
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                guard code == 0 else {
                    failure?(SquareFailure(json: json))
                    return
                }
                guard json["data"].type != .null else {
                    failure?(SquareFailure(rawCode: SquareResultCode.internalError.rawValue))
                    return
                }
                let pageData = SquareCommentThreadPage(json: json["data"])
                self.logCommentThreadPage(postId: postId, pageData)
                success?(pageData)
            }
        }
    }

    /// 某楼回复分页（`commentId` 必须是该帖的一级评论）
    @discardableResult
    func commentReplies(postId: Int,
                        commentId: Int,
                        page: Int = 1,
                        pageSize: Int = SquareLimits.defaultPageSize,
                        success: ((SquareReplyPage) -> Void)?,
                        failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.commentReplies(postId: postId, commentId: commentId, page: max(page, 1), pageSize: size)
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                FZMLog("广场评论：回复分页失败 post=\(postId) comment=\(commentId) code=\(error.rawCode)")
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                guard code == 0 else {
                    failure?(SquareFailure(json: json))
                    return
                }
                guard json["data"].type != .null else {
                    failure?(SquareFailure(rawCode: SquareResultCode.internalError.rawValue))
                    return
                }
                let replyPage = SquareReplyPage(json: json["data"])
                self.logReplyPage(postId: postId, commentId: commentId, replyPage)
                success?(replyPage)
            }
        }
    }

    /// 发评论 / 回复；`-20402` 走 success(.pendingReview)
    /// - Parameter replyToId: 不传或 0 = 一级评论；> 0 = 回复该条可见评论
    @discardableResult
    func createComment(postId: Int,
                       content: String,
                       nickname: String? = nil,
                       replyToId: Int? = nil,
                       success: ((SquareSubmitOutcome<SquareComment>) -> Void)?,
                       failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let nickname = nickname ?? LoginUser.shared().nickName?.value
        let api = SquareAPI.createComment(postId: postId, content: content, nickname: nickname, replyToId: replyToId)
        // 日志只打正文前 30 字，避免整段用户内容进日志
        var contentPreview = content.replacingOccurrences(of: "\n", with: " ")
        if contentPreview.count > 30 {
            contentPreview = String(contentPreview.prefix(30)) + "…"
        }
        let replyTo = replyToId ?? 0
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                FZMLog("广场评论：发表网络失败 post=\(postId) replyTo=\(replyTo) code=\(error.rawCode)")
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                if code == SquareResultCode.pendingReview.rawValue {
                    FZMLog("广场评论：待审 post=\(postId) replyTo=\(replyTo)")
                    FZMLog("广场评论：待审正文 \(contentPreview)")
                    success?(.pendingReview)
                } else if code == 0 {
                    let comment = json["data"].type == .null ? SquareComment(json: JSON([:])) : SquareComment(json: json["data"])
                    FZMLog("广场评论：发表成功 post=\(postId) replyTo=\(replyTo) id=\(comment.id)")
                    FZMLog("广场评论：发表结果 parent=\(comment.parentId) replyToId=\(comment.replyToId)")
                    success?(.published(comment))
                } else {
                    let failureInfo = SquareFailure(json: json)
                    FZMLog("广场评论：发表失败 post=\(postId) replyTo=\(replyTo) code=\(failureInfo.rawCode)")
                    failure?(failureInfo)
                }
            }
        }
    }

    // MARK: - 评论日志

    /// 楼层列表日志：只打 id / 父子关系 / 回复数，不打正文
    private func logCommentThreadPage(postId: Int, _ pageData: SquareCommentThreadPage) {
        FZMLog("广场评论：thread 响应 post=\(postId) page=\(pageData.page)")
        FZMLog("广场评论：thread 统计 total=\(pageData.total) commentCount=\(pageData.commentCount) threads=\(pageData.threads.count)")
        for thread in pageData.threads {
            var replyIds: [String] = []
            for reply in thread.replies {
                replyIds.append(String(reply.id))
            }
            let replyIdText = replyIds.joined(separator: ",")
            FZMLog("广场评论：楼 id=\(thread.comment.id) parent=\(thread.comment.parentId) replyTo=\(thread.comment.replyToId)")
            FZMLog("广场评论：楼统计 id=\(thread.comment.id) replyCount=\(thread.replyCount) deleted=\(thread.comment.deleted) replies=[\(replyIdText)]")
        }
    }

    /// 某楼回复分页日志
    private func logReplyPage(postId: Int, commentId: Int, _ page: SquareReplyPage) {
        var ids: [String] = []
        for reply in page.list {
            ids.append(String(reply.id))
        }
        let idText = ids.joined(separator: ",")
        FZMLog("广场评论：回复分页 post=\(postId) comment=\(commentId) page=\(page.page)")
        FZMLog("广场评论：回复统计 total=\(page.total) count=\(page.list.count) ids=[\(idText)]")
    }

    // MARK: - 收件箱（《App增量-评论回复》§5）

    /// 收件箱列表；`read`：nil 全部 / 0 未读 / 1 已读
    @discardableResult
    func replyInbox(read: Int? = nil,
                    page: Int = 1,
                    pageSize: Int = SquareLimits.defaultPageSize,
                    success: ((SquareReplyInboxPage) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.replyInbox(read: read, page: max(page, 1), pageSize: size)
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                FZMLog("广场收件箱：请求失败 code=\(error.rawCode)")
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                guard code == 0 else {
                    FZMLog("广场收件箱：业务失败 result=\(code)")
                    failure?(SquareFailure(json: json))
                    return
                }
                // `unreadCount` 可能在 data 里，也可能在响应顶层（文档 `POST /replies/read` 就是顶层）
                let dataJSON = json["data"]
                let dataIsNull = dataJSON.type == .null
                let unreadInData = dataJSON["unreadCount"].int ?? dataJSON["unread_count"].int
                let unreadTopLevel = json["unreadCount"].int ?? json["unread_count"].int
                let unread = unreadInData ?? unreadTopLevel ?? 0
                let dataKeys = dataJSON.dictionary?.keys.sorted().joined(separator: ",") ?? "-"
                FZMLog("广场收件箱：dataNull=\(dataIsNull) dataKeys=[\(dataKeys)] unreadInData=\(unreadInData ?? -1) unreadTop=\(unreadTopLevel ?? -1) unread=\(unread)")
                var pageData: SquareReplyInboxPage
                if dataIsNull {
                    pageData = SquareReplyInboxPage(json: JSON([:]))
                } else {
                    pageData = SquareReplyInboxPage(json: dataJSON)
                }
                pageData.unreadCount = unread
                success?(pageData)
            }
        }
    }

    /// 只取未读数（走 `read=0` 第一页；文档没有单独的未读接口）
    ///
    /// `unreadCount` 字段后端不一定给，所以**同时用 `read=0` 列表兜底**：
    /// 列表非空即视为有未读（铃铛只关心“有没有”，不展示具体数字）。
    @discardableResult
    func replyUnreadCount(success: ((Int) -> Void)?,
                          failure: ((SquareFailure) -> Void)? = nil) -> Cancellable? {
        return replyInbox(read: 0, page: 1, pageSize: 20, success: { page in
            let count = max(page.unreadCount, page.list.count)
            FZMLog("广场收件箱：未读数 field=\(page.unreadCount) list=\(page.list.count) total=\(page.total) -> \(count)")
            success?(count)
        }, failure: failure)
    }

    /// 标已读：`ids` 为空表示全部已读（body `{ all: true }`）
    @discardableResult
    func markRepliesRead(ids: [Int] = [],
                         all: Bool = false,
                         success: ((Int) -> Void)?,
                         failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let api = SquareAPI.markRepliesRead(ids: ids, all: all || ids.isEmpty)
        // 响应里的 `unreadCount` 可能在 data 里，也可能直接在顶层（文档只写了 `{ "unreadCount": 0 }`）
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                guard code == 0 else {
                    failure?(SquareFailure(json: json))
                    return
                }
                let unread = json["data"]["unreadCount"].int ?? json["unreadCount"].int ?? 0
                success?(unread)
            }
        }
    }

    /// 删自己的评论；success 回传被删的评论 id
    @discardableResult
    func deleteComment(id: Int,
                       success: ((Int) -> Void)?,
                       failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.deleteComment(id: id), decode: { json in
            return json["id"].int ?? id
        }, success: { deletedId in
            FZMLog("广场评论：删除成功 id=\(deletedId)")
            success?(deletedId)
        }, failure: { error in
            FZMLog("广场评论：删除失败 id=\(id) code=\(error.rawCode) msg=\(error.message)")
            failure?(error)
        })
    }

    // MARK: - 评论开关（仅公众号作者）

    @discardableResult
    func setCommentsEnabled(postId: Int,
                            enabled: Bool,
                            success: ((SquareCommentsEnabledResult) -> Void)?,
                            failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.setCommentsEnabled(postId: postId, enabled: enabled), decode: { json in
            guard json.type != .null else { return nil }
            return SquareCommentsEnabledResult(json: json)
        }, success: success, failure: failure)
    }

    // MARK: - 我的公众号

    /// 我的公众号状态（state: none / pending / approved / rejected / banned）
    /// 顺带把响应里的 `square`（广场开关）同步到本地，少发一次 `/status`
    /// - 注意：`success` 这里是**内联闭包**，必须把泛型写死（`decode` 的返回类型 + 闭包入参都标注），
    ///   否则 `request<T>` 的 `T` 推不出来 → `Type of expression is ambiguous without a type annotation`
    @discardableResult
    func officialMe(success: ((SquareOfficialMe) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.officialMe, decode: { json -> SquareOfficialMe? in
            guard json.type != .null else { return nil }
            return SquareOfficialMe(json: json)
        }, success: { (me: SquareOfficialMe) in
            SquareStatusStore.update(from: me)
            success?(me)
        }, failure: failure)
    }

    /// 申请公众号（同一地址同时只能有一条 pending，`-20408` 表示已有待审）
    @discardableResult
    func officialApply(name: String,
                       avatar: String? = nil,
                       intro: String? = nil,
                       success: ((SquareApplyResult) -> Void)?,
                       failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return request(SquareAPI.officialApply(name: name, avatar: avatar, intro: intro), decode: { json in
            guard json.type != .null else { return nil }
            return SquareApplyResult(json: json)
        }, success: success, failure: failure)
    }

    /// 修改公众号资料（待后端提供，见 `SquareOfficialAPI.supportsProfileUpdate`）
    /// 与发帖一致：`-20402` 视为「已提交待审」算成功，`data` 为 null 也算成功
    @discardableResult
    /// 修改公众号名称 / 头像（`PUT /square/app/official`，仅已通过公众号）
    /// 文档 §6.12：成功 `result=0` + `data { address, name, avatar }`；封禁 `-20405`，未开号 `-20404`
    func officialUpdate(name: String,
                        avatar: String?,
                        success: ((SquareOfficialProfile) -> Void)?,
                        failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let api = SquareAPI.officialUpdate(name: name, avatar: avatar)
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                if code == 0 {
                    success?(SquareOfficialProfile(json: json["data"]))
                } else {
                    failure?(SquareFailure(json: json))
                }
            }
        }
    }

    // MARK: - 广场开关 / 金标目录 / 关注 / 举报 / 我的帖子流量（2026-09 增量）

    /// 广场开关：**始终 result=0**，用 `canRead` / `canPost` 判断，不要把关闭当接口失败
    @discardableResult
    func status(success: ((SquareStatus) -> Void)?,
                failure: ((SquareFailure) -> Void)? = nil) -> Cancellable? {
        return request(SquareAPI.status, decode: { json in
            guard json.type != .null else { return nil }
            return SquareStatus(json: json)
        }, success: success, failure: failure)
    }

    /// 公众号目录（`gold = nil` 出**全部**正常号；`true` 只出金标，按粉丝数降序；只含 status=1 的正常号）
    @discardableResult
    func officials(gold: Bool? = true,
                   page: Int = 1,
                   pageSize: Int = SquareLimits.defaultPageSize,
                   success: ((SquarePage<SquareOfficialCard>) -> Void)?,
                   failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.officials(gold: gold, page: max(page, 1), pageSize: size)
        return request(api, decode: { json in
            guard json.type != .null else { return nil }
            return SquarePage<SquareOfficialCard>(json: json, decode: { SquareOfficialCard(json: $0) })
        }, success: success, failure: failure)
    }

    /// 我的帖子 + 流量汇总（只返回当前验签地址的帖；不含已删、不含草稿）
    @discardableResult
    func myPosts(page: Int = 1,
                 pageSize: Int = SquareLimits.defaultPageSize,
                 success: ((SquareMyPostsPage) -> Void)?,
                 failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.myPosts(page: max(page, 1), pageSize: size)
        return request(api, decode: { json in
            guard json.type != .null else { return nil }
            return SquareMyPostsPage(json: json)
        }, success: success, failure: failure)
    }

    /// 关注（幂等）；`data` 为空也算成功（文档只承诺 `{ targetAddr, followed }`）
    /// ⚠️ 这里不用 `request(...)` 而直接走 `envelope(...)`：用户 2026-09-24 要求在点关注时把
    /// **接口原始返回**打出来排查（`request` 只把解码后的模型给出来，看不到原始 `result/message/data`）。
    @discardableResult
    func follow(targetAddr: String,
                success: ((SquareFollowResult) -> Void)?,
                failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        guard !targetAddr.isEmpty else {
            failure?(SquareFailure(rawCode: SquareResultCode.invalidParam.rawValue))
            return nil
        }
        let api = SquareAPI.follow(targetAddr: targetAddr)
        logFollowRequest(api: api, extra: ["targetAddr": targetAddr])
        return envelope(api) { result in
            switch result {
            case .success(let body):
                let code = body["result"].int ?? 0
                self.logFollowResponse(api: api,
                                       code: code,
                                       message: body["message"].string ?? "",
                                       body: body.rawString() ?? "(无法序列化)")
                guard code == 0 else {
                    failure?(SquareFailure(json: body))
                    return
                }
                if body["data"].type == .null {
                    success?(SquareFollowResult(targetAddr: targetAddr, followed: true))
                } else {
                    success?(SquareFollowResult(json: body["data"]))
                }
            case .failure(let error):
                self.logFollowResponse(api: api, code: error.rawCode, message: error.message, body: "(网络层失败，无返回体)")
                failure?(error)
            }
        }
    }

    /// 取消关注（幂等，不限流）；同样会打接口原始返回（见 `follow` 注释）
    @discardableResult
    func unfollow(targetAddr: String,
                  success: ((SquareFollowResult) -> Void)?,
                  failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        guard !targetAddr.isEmpty else {
            failure?(SquareFailure(rawCode: SquareResultCode.invalidParam.rawValue))
            return nil
        }
        let api = SquareAPI.unfollow(targetAddr: targetAddr)
        logFollowRequest(api: api, extra: ["targetAddr": targetAddr])
        return envelope(api) { result in
            switch result {
            case .success(let body):
                let code = body["result"].int ?? 0
                self.logFollowResponse(api: api,
                                       code: code,
                                       message: body["message"].string ?? "",
                                       body: body.rawString() ?? "(无法序列化)")
                guard code == 0 else {
                    failure?(SquareFailure(json: body))
                    return
                }
                if body["data"].type == .null {
                    success?(SquareFollowResult(targetAddr: targetAddr, followed: false))
                } else {
                    success?(SquareFollowResult(json: body["data"]))
                }
            case .failure(let error):
                self.logFollowResponse(api: api, code: error.rawCode, message: error.message, body: "(网络层失败，无返回体)")
                failure?(error)
            }
        }
    }

    // MARK: - 关注接口日志（用户 2026-09-24 要求，排查完可连同上面两处调用一起删）

    /// 点关注 / 取关时打请求。
    /// 按项目规则统一用 `FZMLog`（⚠️ 它是 `#if DEBUG` 的，**只有 Debug 包**能在 Xcode 控制台看到）。
    private func logFollowRequest(api: SquareAPI, extra: [String: Any]) {
        FZMLog("[SquareFollow] ➡️ \(api.method.rawValue) \(SquareBaseURL)\(api.path) 参数=\(extra)")
    }

    /// 点关注 / 取关时打**接口原始返回**（result / message / data 全文）
    private func logFollowResponse(api: SquareAPI, code: Int, message: String, body: String) {
        FZMLog("[SquareFollow] ⬅️ \(api.path) result=\(code) message=\(message) body=\(body)")
    }

    /// 我关注的人 / 号
    /// ⚠️ 用户 2026-09-24 排查「关注重启后没了」：这个接口的请求与返回也会打日志（同 `follow`），
    /// 用来区分「服务端没存住」还是「客户端名单没拉回来」
    @discardableResult
    func follows(page: Int = 1,
                 pageSize: Int = SquareLimits.defaultPageSize,
                 success: ((SquarePage<SquareFollowItem>) -> Void)?,
                 failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.followList(page: max(page, 1), pageSize: size)
        FZMLog("[SquareFollow] ➡️ GET \(SquareBaseURL)\(api.path)?page=\(max(page, 1))&pageSize=\(size)（我关注的）")
        // ⚠️ `request` 的泛型 T 只出现在 `decode` 的返回类型上，多语句闭包推不出 T
        // （会报 Type of expression is ambiguous without a type annotation）⇒ 闭包必须显式标注类型
        return request(api, decode: { (json: JSON) -> SquarePage<SquareFollowItem>? in
            // `data` 为 null 按空名单处理，**不要当失败**（当失败会让名单永远拉不到 ⇒ 关注按钮全变未关注）
            guard json.type != .null else { return SquarePage<SquareFollowItem>() }
            return SquarePage<SquareFollowItem>(json: json, decode: { SquareFollowItem(json: $0) })
        }, success: { (pageData: SquarePage<SquareFollowItem>) in
            FZMLog("[SquareFollow] ⬅️ \(api.path) 共\(pageData.list.count)条 hasMore=\(pageData.hasMore) 地址=\(pageData.list.map { $0.address })")
            success?(pageData)
        }, failure: { (err: SquareFailure) in
            FZMLog("[SquareFollow] ⬅️ \(api.path) 失败 code=\(err.rawCode) message=\(err.message)")
            failure?(err)
        })
    }

    /// 关注我的人 / 号
    @discardableResult
    func followers(page: Int = 1,
                   pageSize: Int = SquareLimits.defaultPageSize,
                   success: ((SquarePage<SquareFollowItem>) -> Void)?,
                   failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let size = min(max(pageSize, 1), SquareLimits.maxPageSize)
        let api = SquareAPI.followerList(page: max(page, 1), pageSize: size)
        FZMLog("[SquareFollow] ➡️ GET \(SquareBaseURL)\(api.path)?page=\(max(page, 1))&pageSize=\(size)（关注我的）")
        // 同 `follows`：泛型 T 在闭包返回类型上，必须显式标注
        return request(api, decode: { (json: JSON) -> SquarePage<SquareFollowItem>? in
            guard json.type != .null else { return SquarePage<SquareFollowItem>() }
            return SquarePage<SquareFollowItem>(json: json, decode: { SquareFollowItem(json: $0) })
        }, success: { (pageData: SquarePage<SquareFollowItem>) in
            FZMLog("[SquareFollow] ⬅️ \(api.path) 共\(pageData.list.count)条 hasMore=\(pageData.hasMore) 地址=\(pageData.list.map { $0.address })")
            success?(pageData)
        }, failure: { (err: SquareFailure) in
            FZMLog("[SquareFollow] ⬅️ \(api.path) 失败 code=\(err.rawCode) message=\(err.message)")
            failure?(err)
        })
    }

    /// 举报帖子 / 公众号文章（同一地址对同一帖只能举报一次，重复 `-20410`；举报不会立刻藏帖）
    @discardableResult
    func report(postId: Int,
                reason: SquareReportReason,
                detail: String = "",
                success: ((SquareReportResult) -> Void)?,
                failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let detail = String(detail.prefix(SquareLimits.maxReportDetailLength))
        // reason 直接用枚举 rawValue（spam/porn/scam/abuse/other，与后端枚举一一对应）
        let api = SquareAPI.report(postId: postId, reason: reason.rawValue, detail: detail)
        return request(api, decode: { json in
            guard json.type != .null else { return nil }
            return SquareReportResult(json: json)
        }, success: success, failure: failure)
    }

    /// 二次编辑自己的已发帖；与发帖一致，`-20402` 走 success(.pendingReview)、`data` 为 null 也算成功
    @discardableResult
    func updatePost(id: Int,
                    content: String,
                    nickname: String? = nil,
                    mediaUrls: [String] = [],
                    commentsEnabled: Bool? = nil,
                    success: ((SquareSubmitOutcome<SquarePost>) -> Void)?,
                    failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        let nickname = nickname ?? LoginUser.shared().nickName?.value
        let api = SquareAPI.updatePost(id: id,
                                      content: content,
                                      nickname: nickname,
                                      mediaUrls: Array(mediaUrls.prefix(SquareLimits.maxImageCount)),
                                      commentsEnabled: commentsEnabled)
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                if code == SquareResultCode.pendingReview.rawValue {
                    success?(.pendingReview)
                } else if code == 0 {
                    let post = json["data"].type == .null ? SquarePost(json: JSON([:])) : SquarePost(json: json["data"])
                    success?(.published(post))
                } else {
                    failure?(SquareFailure(json: json))
                }
            }
        }
    }

    // MARK: - 图片上传

    /// 上传广场图片（复用聊天服务器 /oss/upload，需聊天签名；服务端返回可直接展示的公网 URL）
    /// 性能要点：多张图片**并行压缩**、**限并发上传**（最多 3 张同时传），避免串行排队导致发送很慢。
    /// - Parameters:
    ///   - images: 已选图片，超过 9 张会被截断
    ///   - progress: (已完成张数, 总张数)
    ///   - success: 图片 URL 数组，顺序与入参一致
    @discardableResult
    func uploadImages(_ images: [UIImage],
                      progress: ((Int, Int) -> Void)? = nil,
                      success: (([String]) -> Void)?,
                      failure: ((SquareFailure) -> Void)?) -> Bool {
        let images = Array(images.prefix(SquareLimits.maxImageCount))
        guard !images.isEmpty else {
            failure?(SquareFailure(rawCode: SquareResultCode.invalidParam.rawValue, message: L("请先选择图片")))
            return false
        }
        guard LoginUser.shared().signature != nil else {
            failure?(.notLogin)
            return false
        }

        // 压缩比较耗时，放后台队列并行处理，回调仍在主线程
        DispatchQueue.global(qos: .userInitiated).async {
            var datas = [Data?](repeating: nil, count: images.count)
            DispatchQueue.concurrentPerform(iterations: images.count) { index in
                datas[index] = SquareService.compressedJPEGData(of: images[index])
            }
            let compressed = datas.compactMap { $0 }

            DispatchQueue.main.async {
                guard compressed.count == images.count else {
                    failure?(SquareFailure(rawCode: SquareResultCode.invalidParam.rawValue, message: L("图片处理失败，请重新选择")))
                    return
                }
                self.uploadCompressedImages(compressed, progress: progress, success: success, failure: failure)
            }
        }
        return true
    }

    /// 限并发上传（最多 3 张同时传），按原顺序回传 URL
    private func uploadCompressedImages(_ datas: [Data],
                                        progress: ((Int, Int) -> Void)?,
                                        success: (([String]) -> Void)?,
                                        failure: ((SquareFailure) -> Void)?) {
        let total = datas.count
        let maxConcurrent = 3

        var urls = [String?](repeating: nil, count: total)
        var finished = 0
        var active = 0
        var nextIndex = 0
        var hasFailed = false

        var dispatchNext: (() -> Void)!

        dispatchNext = { [weak self] in
            guard let self = self, !hasFailed else { return }

            while active < maxConcurrent, nextIndex < total, !hasFailed {
                let index = nextIndex
                nextIndex += 1
                active += 1

                self.uploadSingleImage(datas[index], index: index) { url, error in
                    active -= 1

                    if hasFailed { return }

                    guard let url = url, error == nil else {
                        hasFailed = true
                        dispatchNext = nil
                        failure?(error ?? SquareFailure(rawCode: SquareResultCode.internalError.rawValue, message: L("上传图片失败")))
                        return
                    }

                    urls[index] = url
                    finished += 1
                    progress?(finished, total)

                    if finished == total {
                        dispatchNext = nil
                        success?(urls.compactMap { $0 })
                    } else {
                        dispatchNext()
                    }
                }
            }
        }

        dispatchNext()
    }

    // MARK: - 私有：请求核心

    /// 基础请求：登录前置校验 + 网络层错误归一 + -1011 重签重试一次；把响应信封原样交给业务判定
    @discardableResult
    private func envelope(_ api: SquareAPI,
                          retryOnSignExpired: Bool = true,
                          completion: @escaping (Result<JSON, SquareFailure>) -> Void) -> Cancellable? {
        // 未登录不发请求，避免服务端按无效签名返回 -1010，造成误判
        guard SquareSignature.shared.token() != nil else {
            completion(.failure(.notLogin))
            return nil
        }

        #if DEBUG
        FZMLog("广场请求 \(api.path) 参数=\(api.parameters)")
        #endif

        return Provider.request(api, successBlock: { json in
            let code = json["result"].int ?? 0

            if code == SquareResultCode.invalidSign.rawValue {
                // 签名无效：清掉缓存，下次请求重新签名
                SquareSignature.shared.reset()
            }

            if code == SquareResultCode.expiredSign.rawValue, retryOnSignExpired {
                FZMLog("广场签名过期，重签后重试 \(api.path)")
                _ = SquareSignature.shared.token(forceRefresh: true)
                _ = self.envelope(api, retryOnSignExpired: false, completion: completion)
                return
            }

            completion(.success(json))
        }, failureBlock: { error in
            completion(.failure(SquareFailure(error: error)))
        })
    }

    /// 标准业务请求：result == 0 且能解析出模型才算成功
    @discardableResult
    private func request<T>(_ api: SquareAPI,
                            decode: @escaping (JSON) -> T?,
                            success: ((T) -> Void)?,
                            failure: ((SquareFailure) -> Void)?) -> Cancellable? {
        return envelope(api) { result in
            switch result {
            case .failure(let error):
                failure?(error)
            case .success(let json):
                let code = json["result"].int ?? 0
                guard code == 0 else {
                    failure?(SquareFailure(json: json))
                    return
                }
                guard let value = decode(json["data"]) else {
                    failure?(SquareFailure(rawCode: SquareResultCode.internalError.rawValue))
                    return
                }
                success?(value)
            }
        }
    }

    // MARK: - 私有：图片处理与上传

    /// 压缩到服务端可接受的大小。
    /// 性能要点：① 原图已够小则跳过重绘；② 超限时最多再编码一次（按比例缩小），避免反复重编码拖慢发送。
    private static func compressedJPEGData(of image: UIImage,
                                           maxDimension: CGFloat = 1080,
                                           quality: CGFloat = 0.75) -> Data? {
        // 用像素尺寸判断（避免 @2x/@3x 的 UIImage 被当成点尺寸误判）
        let pixelSize: CGSize
        if let cgImage = image.cgImage, cgImage.width > 0, cgImage.height > 0 {
            pixelSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        } else {
            pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        }
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        var target = image
        let longest = max(pixelSize.width, pixelSize.height)
        if longest > maxDimension {
            target = resized(image, to: maxDimension / longest)
        }

        guard var data = target.jpegData(compressionQuality: quality) else { return nil }

        // 体积仍超限：按需缩一次并只重编码一次
        if data.count > SquareLimits.maxImageBytes {
            let ratio = max(sqrt(CGFloat(SquareLimits.maxImageBytes) / CGFloat(data.count)), 0.4)
            let shrunk = resized(target, to: ratio)
            if let shrunkData = shrunk.jpegData(compressionQuality: quality) {
                data = shrunkData
            }
        }
        return data
    }

    /// 按比例缩放图片（输出 scale = 1，尺寸即像素）
    private static func resized(_ image: UIImage, to ratio: CGFloat) -> UIImage {
        let pixelSize: CGSize
        if let cgImage = image.cgImage, cgImage.width > 0, cgImage.height > 0 {
            pixelSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        } else {
            pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        }

        let newSize = CGSize(width: max(floor(pixelSize.width * ratio), 1),
                             height: max(floor(pixelSize.height * ratio), 1))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 单张图片上传到 /oss/upload（聊天服务器接口，用聊天签名）
    private func uploadSingleImage(_ data: Data,
                                   index: Int,
                                   completion: @escaping (String?, SquareFailure?) -> Void) {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYYMMdd"
        let day = formatter.string(from: Date())
        let uid = LoginUser.shared().address
        let key = "square/picture/\(day)/\(Date.timestamp)_\(index)_\(uid).jpg"

        var headers: HTTPHeaders {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let signature = LoginUser.shared().signature ?? ""
            return ["Content-type": "multipart/form-data",
                    "Content-Disposition": "form-data",
                    "FZM-SIGNATURE": signature,
                    "FZM-VERSION": version,
                    "FZM-UUID": String.uuid(),
                    "FZM-DEVICE": "iOS",
                    "FZM-DEVICE-NAME": k_DeviceName]
        }

        let multipartFormData = MultipartFormData()
        multipartFormData.append(data, withName: "file", fileName: "file")
        multipartFormData.append(APPID.data(using: .utf8)!, withName: "appId")
        multipartFormData.append(key.data(using: .utf8)!, withName: "key")

        FZMLog("广场图片上传开始 \(BackUpOSSURL) key=\(key) size=\(data.count)")

        AF.upload(multipartFormData: multipartFormData, to: BackUpOSSURL, headers: headers).response { response in
            var message = ""
            #if DEBUG
            if let jsonData = response.data, let raw = String.init(data: jsonData, encoding: .utf8) {
                FZMLog("广场图片上传响应(\(BackUpOSSURL)): \(raw.count > 300 ? String(raw.prefix(300)) : raw)")
            } else {
                FZMLog("广场图片上传失败(无响应体) \(BackUpOSSURL) error=\(String(describing: response.error))")
            }
            #endif
            if let jsonData = response.data, let json = try? JSON(data: jsonData) {
                let code = json["result"].int ?? -1
                message = json["message"].string ?? ""
                if code == 0 {
                    let url = json["data"]["url"].string ?? ""
                    if !url.isEmpty {
                        completion(url, nil)
                        return
                    }
                }
            }
            if message.isEmpty {
                message = L("上传图片失败")
            }
            FZMLog("广场图片上传失败 \(index) \(message)")
            completion(nil, SquareFailure(rawCode: SquareResultCode.internalError.rawValue, message: message))
        }
    }
}
