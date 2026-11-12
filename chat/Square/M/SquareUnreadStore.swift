//
//  SquareUnreadStore.swift
//  chat
//
//  广场红点：本地记录「上次浏览到的最新帖子 id」（服务端帖子 id 单调递增，无需未读接口）
//  按钱包地址隔离，切换账号互不影响。
//

import Foundation

enum SquareUnreadStore {

    private static let keyPrefix = "chat_square_last_seen_post_"

    private static var key: String {
        return keyPrefix + LoginUser.shared().address
    }

    /// 上次浏览到的最新帖子 id（0 表示从未浏览过）
    static var lastSeenPostId: Int {
        get {
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    /// 最新帖 id 大于上次浏览记录 → 有新内容
    static func hasUnread(newestPostId: Int?) -> Bool {
        guard let newestPostId = newestPostId, newestPostId > 0 else { return false }
        return newestPostId > lastSeenPostId
    }

    /// 浏览广场后标记已读（只在更新时写入，避免频繁写 UserDefaults）
    static func markRead(newestPostId: Int?) {
        guard let newestPostId = newestPostId, newestPostId > lastSeenPostId else { return }
        lastSeenPostId = newestPostId
    }
}
