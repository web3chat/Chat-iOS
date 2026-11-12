//
//  SquareMyPostStore.swift
//  chat
//
//  「我的帖子」本地待审快照：
//  服务端待审帖（-20402）不返回 id，广场流也只返回已过审帖，
//  所以本机发帖进人工审核时在这里留一份快照，保证用户能在「我的帖子」里看到自己刚发的内容。
//

import Foundation
import SwiftyJSON

struct SquareMyPendingPost {

    /// 本地唯一标识（快照无法走服务端删除，只能本地清理）
    var localId = ""
    var content = ""
    var mediaUrls = [String]()
    /// RFC3339 时间文本
    var createdAt = ""
    /// 发帖时的身份：0 个人 / 1 公众号（已通过公众号的作者，快照也要按公众号展示）
    var authorKind = 0
    /// 发帖时的公众号头像（个人帖为空）
    var authorAvatar = ""
    /// 发帖时的公众号名称（个人帖为空，列表用短地址兜底）
    var authorName = ""
    /// 发帖时选的「是否允许评论」（个人帖恒为 true）
    var commentsEnabled = true

    var createdDate: Date? {
        return SquareDateParser.date(from: createdAt)
    }

    init(localId: String = UUID().uuidString,
         content: String,
         mediaUrls: [String],
         createdAt: String,
         authorKind: SquareAuthorKind = .person,
         authorAvatar: String = "",
         authorName: String = "",
         commentsEnabled: Bool = true) {
        self.localId = localId
        self.content = content
        self.mediaUrls = Array(mediaUrls.prefix(SquareLimits.maxImageCount))
        self.createdAt = createdAt
        self.authorKind = authorKind.rawValue
        self.authorAvatar = authorAvatar
        self.authorName = authorName
        self.commentsEnabled = commentsEnabled
    }

    init?(dict: [String: Any]) {
        let content = dict["content"] as? String ?? ""
        guard !content.isEmpty else { return nil }
        self.localId = dict["localId"] as? String ?? UUID().uuidString
        self.content = content
        self.mediaUrls = dict["mediaUrls"] as? [String] ?? []
        self.createdAt = dict["createdAt"] as? String ?? ""
        self.authorKind = dict["authorKind"] as? Int ?? 0
        self.authorAvatar = dict["authorAvatar"] as? String ?? ""
        self.authorName = dict["authorName"] as? String ?? ""
        // 老快照没有这个字段，缺省当作允许评论
        self.commentsEnabled = dict["commentsEnabled"] as? Bool ?? true
    }

    var dict: [String: Any] {
        return ["localId": localId,
                "content": content,
                "mediaUrls": mediaUrls,
                "createdAt": createdAt,
                "authorKind": authorKind,
                "authorAvatar": authorAvatar,
                "authorName": authorName,
                "commentsEnabled": commentsEnabled]
    }

    /// 转成帖子对象用于列表展示（status = 待审，作者是自己，因此只在本机可见）
    func post() -> SquarePost {
        let json: [String: Any] = [
            "id": 0,
            "authorAddr": LoginUser.shared().address,
            // 个人帖留空，由列表用短地址兜底展示；公众号帖用发帖时记下的公众号名称
            "authorName": authorName,
            "authorKind": authorKind,
            "authorAvatar": authorAvatar,
            "content": content,
            "mediaUrls": mediaUrls,
            "commentsEnabled": commentsEnabled,
            "status": SquarePostStatus.pendingReview.rawValue,
            "commentCount": 0,
            "likeCount": 0,
            "viewCount": 0,
            "liked": false,
            "createdAt": createdAt
        ]
        return SquarePost(json: JSON(json))
    }
}

enum SquareMyPostStore {

    /// 最多保留多少条快照
    private static let maxCount = 50

    private static func key(for address: String) -> String {
        return "chat_square_my_pending_posts_\(address)"
    }

    /// 当前登录地址的待审快照（新 → 旧）
    static func pendingPosts() -> [SquareMyPendingPost] {
        return pendingPosts(for: LoginUser.shared().address)
    }

    static func pendingPosts(for address: String) -> [SquareMyPendingPost] {
        guard !address.isEmpty,
              let raw = UserDefaults.standard.string(forKey: key(for: address)),
              let data = raw.data(using: .utf8),
              let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { SquareMyPendingPost(dict: $0) }
    }

    /// 发帖进审时记一条快照（公众号作者把当时的身份 / 头像 / 名称一起记下，快照帖也按公众号展示）
    static func appendPending(content: String,
                              mediaUrls: [String],
                              createdAt: Date = Date(),
                              authorKind: SquareAuthorKind = .person,
                              authorAvatar: String = "",
                              authorName: String = "",
                              commentsEnabled: Bool = true) {
        let address = LoginUser.shared().address
        guard !address.isEmpty, !content.isEmpty else { return }

        var list = pendingPosts(for: address)
        list.insert(SquareMyPendingPost(content: content,
                                        mediaUrls: mediaUrls,
                                        createdAt: SquareDateParser.string(from: createdAt),
                                        authorKind: authorKind,
                                        authorAvatar: authorAvatar,
                                        authorName: authorName,
                                        commentsEnabled: commentsEnabled),
                    at: 0)
        if list.count > maxCount {
            list = Array(list.prefix(maxCount))
        }
        save(list, address: address)
    }

    /// 删除某条快照（本地清理）
    static func removePending(localId: String) {
        let address = LoginUser.shared().address
        guard !address.isEmpty, !localId.isEmpty else { return }
        let list = pendingPosts(for: address).filter { $0.localId != localId }
        save(list, address: address)
    }

    /// 找出与已过审帖对应的快照（按正文 + 图片数 + 同地址匹配），避免「我的帖子」里重复展示
    static func removePendingIfMatched(post: SquarePost) {
        let address = LoginUser.shared().address
        guard !address.isEmpty, post.id > 0, post.authorAddr == address else { return }

        let content = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        var list = pendingPosts(for: address)
        let before = list.count
        list.removeAll { record in
            return record.content.trimmingCharacters(in: .whitespacesAndNewlines) == content
                && record.mediaUrls.count == post.mediaUrls.count
        }
        if list.count != before {
            save(list, address: address)
        }
    }

    private static func save(_ list: [SquareMyPendingPost], address: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: list.map { $0.dict }),
              let raw = String.init(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key(for: address))
    }
}

// MARK: - 本人公众号资料缓存（「我的信息」卡）

/// 本人公众号资料：状态 / 名称 / 头像 / 简介
struct SquareMyOfficialProfile {
    var state: SquareOfficialState = .none
    var name = ""
    var avatar = ""
    /// 公众号简介（`official/me` 返回的 `official.intro`，或将来别的公众号接口）
    var intro = ""
}

/// 「我的信息」页的数据来源：进页面先用缓存渲染（这样已通过的公众号名称与头像立刻就在，
/// 不会先显示个人昵称/占位头像再跳成公众号资料），接口回来后再静默刷新。
enum SquareMyOfficialStore {

    private static let keyPrefix = "chat_square_my_official_profile"
    /// 内存缓存：同一进程内切页面不再读 UserDefaults
    private static var memory = [String: SquareMyOfficialProfile]()

    static func profile(for address: String) -> SquareMyOfficialProfile? {
        guard !address.isEmpty else { return nil }
        if let cached = memory[address] { return cached }
        guard let raw = UserDefaults.standard.string(forKey: key(for: address)),
              let data = raw.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        let profile = SquareMyOfficialProfile(state: SquareOfficialState(raw: dict["state"] as? String ?? "none"),
                                             name: dict["name"] as? String ?? "",
                                             avatar: dict["avatar"] as? String ?? "",
                                             intro: dict["intro"] as? String ?? "")
        memory[address] = profile
        return profile
    }

    static func save(_ profile: SquareMyOfficialProfile, for address: String) {
        guard !address.isEmpty else { return }
        memory[address] = profile
        let dict: [String: Any] = ["state": profile.state.rawValue,
                                   "name": profile.name,
                                   "avatar": profile.avatar,
                                   "intro": profile.intro]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let raw = String.init(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key(for: address))
    }

    private static func key(for address: String) -> String {
        return "\(keyPrefix)_\(address)"
    }
}
