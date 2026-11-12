//
//  AICustomerStore.swift
//  chat
//
//  AI 客服本地持久化：tab_id、按地址分键的 session_id、入口行标识、悬浮球位置。
//  对接文档 §5 / §6 / §8
//

import Foundation
import CoreGraphics

/// 全部走 UserDefaults（与工程其它本地小状态一致；不含任何密钥/凭证）。
enum AICustomerStore {

    private static let tabIDKey = "AICustomerServiceTabID"
    private static let floatCenterXKey = "AICustomerFloatCenterX"
    private static let floatCenterYKey = "AICustomerFloatCenterY"
    private static let sessionIDKeyPrefix = "AICustomerServiceSessionID_"

    // MARK: - 私聊列表入口

    /// 「AI 客服」在私聊列表里占的那一行所用的**虚拟会话 id**。
    ///
    /// 该行只在本地渲染（永远排最上面），**不会写入会话数据库**，
    /// 也不会进入 `SessionManager` 的数据源 —— 因为客服是 H5 页面，
    /// 本地既没有聊天记录也没有真实的用户/群信息。
    /// 仅用于给 `Session` 造一个稳定的 id（与真实地址不会冲突）。
    static let entrySessionID = "ai_customer_service"

    /// 入口行是否展示：未登录时不展示（客服登录依赖登录态密钥）。
    static var isEntryVisible: Bool {
        return LoginUser.shared().isLogin
    }

    private static let entryOnTopKey = "AICustomerServiceEntryOnTop"

    /// 私聊列表里「小Y」那一行是否**置顶**（长按菜单可切换）。
    ///
    /// 默认 `true`：与"客服常驻列表最上面"的既有表现一致。
    /// 取消置顶后它没有消息时间可排序，就排到私聊列表**末尾**（把位置交给用户自己决定）。
    static var isEntryOnTop: Bool {
        get {
            // 没存过时默认置顶（`UserDefaults.bool` 对缺省键返回 false，所以要先判断键是否存在）
            guard UserDefaults.standard.object(forKey: entryOnTopKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: entryOnTopKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: entryOnTopKey)
        }
    }

    // MARK: - tab_id

    /// 本"客服标签页"的唯一标识：首次生成后长期复用（参与 LiveKit identity，必须稳定）。
    static var tabID: String {
        if let existing = UserDefaults.standard.string(forKey: tabIDKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: tabIDKey)
        return created
    }

    // MARK: - session_id（会话连续性）

    /// 上次的会话 id；**按 0x 地址分键**，换账号不会串（对接文档 §6）。
    static func sessionID(for address: String) -> String? {
        let key = sessionIDKeyPrefix + address.lowercased()
        guard let value = UserDefaults.standard.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }

    /// 登录成功后回写，下次登录带上即可继续上次那段对话。
    static func saveSessionID(_ value: String?, for address: String) {
        let key = sessionIDKeyPrefix + address.lowercased()
        guard let value = value, !value.isEmpty else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    /// 清掉会话 id（登出/切账号等场景备用；当前无调用点）
    static func clearSessionID(for address: String) {
        UserDefaults.standard.removeObject(forKey: sessionIDKeyPrefix + address.lowercased())
    }

    // MARK: - 一次性迁移（方式 B → 方式 A）

    private static let pageSessionPurgeKey = "AICustomerServicePageSessionPurged"
    private static let legacyCredentialKeyPrefix = "AICustomerServiceCredentials_"

    /// 是否需要做「清掉页面本地会话」的一次性迁移。
    ///
    /// 旧实现（方式 B）会把 App 侧 **24h 缓存**的凭证注入给页面，而服务端 token 更短命：
    /// 页面会把一份过期 token 当成自己的会话存下来，此后一直报「token 失效」。
    /// 升级后第一次进入客服页时清一次本站 localStorage，让页面重新要一份新鲜凭证。
    static var needsLegacyPageSessionPurge: Bool {
        get { return !UserDefaults.standard.bool(forKey: pageSessionPurgeKey) }
        set { UserDefaults.standard.set(!newValue, forKey: pageSessionPurgeKey) }
    }

    /// 清掉旧版本存在 App 侧的凭证缓存（新版本不再读写这些键）。
    static func purgeLegacyCredentialCache() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(legacyCredentialKeyPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - 悬浮球位置（归一化 0~1，避免换机型后跑出屏幕）

    /// 已保存的归一化中心点；没有保存过返回 nil（由视图用默认位置）。
    static var floatButtonNormalizedCenter: CGPoint? {
        guard UserDefaults.standard.object(forKey: floatCenterXKey) != nil,
              UserDefaults.standard.object(forKey: floatCenterYKey) != nil else { return nil }
        let x = UserDefaults.standard.double(forKey: floatCenterXKey)
        let y = UserDefaults.standard.double(forKey: floatCenterYKey)
        guard x > 0, x < 1, y > 0, y < 1 else { return nil }
        return CGPoint(x: x, y: y)
    }

    static func saveFloatButtonNormalizedCenter(_ point: CGPoint) {
        UserDefaults.standard.set(Double(point.x), forKey: floatCenterXKey)
        UserDefaults.standard.set(Double(point.y), forKey: floatCenterYKey)
    }
}
