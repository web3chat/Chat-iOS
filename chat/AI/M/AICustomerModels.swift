//
//  AICustomerModels.swift
//  chat
//
//  AI 客服（BTY 智能客服 H5 · SIWE 免登录）—— 站点配置、凭证模型与错误定义。
//  对接文档见 chat/AI/README_TanxinAICustomerService.md
//

import Foundation

// MARK: - 站点与桥配置

/// 站点地址与桥通道名（对接文档 §3 / §4）。
enum AICustomerConfig {

    /// UserDefaults / Info.plist 里的站点地址键；不配置则用默认站点。
    static let siteURLKey = "AICustomerServiceSiteURL"

    /// 默认站点（未配置时为空字符串，需在 UserDefaults / Info.plist 的 `AICustomerServiceSiteURL` 配置）
    static let defaultSiteURLString = ""

    /// 页面脚本之前注入惰性提供者时使用的桥通道名（页面侧 `webkit.messageHandlers.csAuth`）。
    static let scriptHandlerName = "csAuth"

    /// 取原文 / 提交登录的单次请求超时
    static let requestTimeout: TimeInterval = 10

    /// 站点首页（WKWebView 首次加载地址）
    static var siteURL: URL {
        let configured = (UserDefaults.standard.string(forKey: siteURLKey) ?? infoPlistSiteURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let configured = configured, !configured.isEmpty, let url = URL(string: configured) {
            return url
        }
        // 兜底：默认站点（理论上一定可解析）
        return URL(string: defaultSiteURLString) ?? URL(fileURLWithPath: "/")
    }

    private static var infoPlistSiteURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: siteURLKey) as? String else { return nil }
        return value
    }
}

// MARK: - 凭证

/// 登录成功后交给页面的凭证（对接文档 §3.3 响应里的 `data`）。
///
/// `raw` 是服务端返回的**原始字典**，注入页面时用它（避免因为多出字段被裁剪导致页面校验不过）；
/// 其余属性只用于本地校验与取值。
struct AICustomerCredentials {

    let token: String
    let uid: Int
    let ethAddress: String
    let role: String
    let sessionID: String
    let livekitToken: String
    let roomName: String
    let displayName: String
    let raw: [String: Any]

    /// 字段不全返回 nil（对接文档 §3.4：交付前必须确认字段完整，避免"看似登录成功却连不上房间"）。
    init?(json: [String: Any]) {
        guard let token = AICustomerCredentials.nonEmptyString(json["token"]),
              let ethAddress = AICustomerCredentials.nonEmptyString(json["eth_address"]),
              let livekitToken = AICustomerCredentials.nonEmptyString(json["livekit_token"]),
              let roomName = AICustomerCredentials.nonEmptyString(json["room_name"]),
              let role = AICustomerCredentials.nonEmptyString(json["role"]),
              role == "user",
              let uid = AICustomerCredentials.intValue(json["uid"])
        else { return nil }

        self.token = token
        self.uid = uid
        self.ethAddress = ethAddress
        self.role = role
        self.sessionID = AICustomerCredentials.nonEmptyString(json["session_id"]) ?? ""
        self.livekitToken = livekitToken
        self.roomName = roomName
        self.displayName = AICustomerCredentials.nonEmptyString(json["display_name"]) ?? ""
        self.raw = json
    }

    /// 服务端可能给字符串或数字，统一取值。
    private static func nonEmptyString(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}

// MARK: - 分享载荷（对接文档 §6.1）

/// AI 客服分享的版式约定。
///
/// 载荷解析与「发到会话 / 发到广场」的落地已统一到 `TanxinSharePayload` + `TanxinHostBridge`
/// （`window.__tanxinHost`，AI 客服与 DApp 浏览器共用），这里只保留 AI 页专用的抬头。
/// 页面传来的字段仍是 `title` / `summary` / `url`（新文档叫 `description`，两个键都兼容）。
enum AICustomerShareStyle {

    /// 分享内容的固定抬头（永远在**第一行**；后面接「标题 / 摘要 / 链接」逐行显示）。
    static let header = "来自小Y的分享"
}

// MARK: - 错误

/// AI 客服免登录过程中的错误（语义对齐对接文档 §3.3 / §7）。
enum AICustomerServiceError: Error {

    /// 未登录谈信账号
    case notLoggedIn
    /// 当前没有可用的 0x 账户地址
    case walletAddressUnavailable
    /// 私钥不可得 / 与当前 0x 地址不匹配
    case keyUnavailable
    /// 用户在密码框里点了取消（**静默**：不弹任何提示、不当作失败上报）
    case cancelled
    /// 网络失败或响应不是合法 JSON
    case network(String)
    /// 服务端业务码非 0（HTTP 200 也可能是失败）
    case business(code: Int, message: String)
    /// data 字段不全
    case credentialsIncomplete

    /// 服务端业务码（非 business 为 nil）
    var businessCode: Int? {
        if case .business(let code, _) = self { return code }
        return nil
    }

    /// `400`：原文过期 / 已被用过 / 参数不合法 —— 由 `AICustomerAPI` 决定是否重取原文重签一次
    var isBusinessCode400: Bool { businessCode == 400 }

    /// `429`：触发限流 —— 不重试
    var isRateLimited: Bool { businessCode == 429 }

    /// 401 的"签名账号与请求地址不匹配"：说明用错了密钥
    var isAddressMismatch: Bool {
        guard case .business(let code, let message) = self, code == 401 else { return false }
        return message.contains("不匹配")
    }

    /// 给用户看的简短描述（不含敏感信息）
    var displayDescription: String {
        switch self {
        case .notLoggedIn:              return L("未登录")
        case .walletAddressUnavailable: return L("未获取到钱包地址")
        case .keyUnavailable:           return L("钱包密钥不可用")
        case .cancelled:                return ""
        case .network(let detail):      return detail
        case .business(_, let message): return message
        case .credentialsIncomplete:    return L("客服登录信息不完整")
        }
    }
}
