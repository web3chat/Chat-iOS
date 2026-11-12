//
//  ScanLoginModels.swift
//  chat
//
//  扫码登录（PC 网页版）—— 二维码载荷解析 + 错误模型
//  对接文档：app-qr-login-integration.md §2 二维码内容解析 / §6 状态机 / §8 FAQ
//

import Foundation

// MARK: - 二维码载荷

/// 扫码登录二维码载荷（仅支持 v2 / ECDH）
///
/// ```json
/// { "type": "qr-login-v2", "sessionId": "...", "pubKey": "<33 字节压缩公钥 hex>" }
/// ```
/// 安全约定：ECDH 共享密钥只在本次登录中一次性使用，**用后即弃：不落盘、不写日志**。
///
/// ⚠️ 旧版 `qr-login`（二维码里带对称 `key` / `iv`）已停用：扫到只提示「请在电脑端刷新」，
///    不再解析、不再参与登录。
final class ScanLoginQRPayload {

    /// v2 二维码 `type` 约定值（ECDH）
    static let qrTypeV2 = "qr-login-v2"
    /// 旧版二维码 `type`：仅用于识别并提示刷新，不再支持登录
    static let legacyQrType = "qr-login"
    /// 服务端会话 TTL（秒）；二维码未带有效期时按此倒计时
    static let defaultExpiresIn = 300

    /// 会话 id
    let sessionId: String
    /// PC 端临时公钥（33 字节压缩 / 65 字节非压缩 hex）
    let pcPublicKeyHex: String
    /// 发起登录的设备（二维码未带则为 nil，界面上回落到「电脑端」）
    let device: String?
    /// 二维码生成时间（二维码未带则为 nil）
    let createdAt: Date?
    /// 会话有效期（秒）
    let expiresIn: Int

    private init(sessionId: String,
                 pcPublicKeyHex: String,
                 device: String?,
                 createdAt: Date?,
                 expiresIn: Int) {
        self.sessionId = sessionId
        self.pcPublicKeyHex = pcPublicKeyHex
        self.device = device
        self.createdAt = createdAt
        self.expiresIn = expiresIn
    }

    /// 解析并校验二维码内容（只接受 v2）
    /// - Returns: 不是扫码登录二维码 / 字段缺失或非法时返回 nil（调用方按普通二维码继续处理）
    static func parse(_ raw: String) -> ScanLoginQRPayload? {
        guard let json = jsonObject(raw) else { return nil }

        // type：只认 v2；v1（qr-login）已停用
        let type = (stringValue(json["type"]) ?? "").lowercased()
        guard type == qrTypeV2 else { return nil }

        guard let sessionId = stringValue(json["sessionId"]) else {
            FZMLog("扫码登录：二维码字段校验不通过")
            return nil
        }

        // 设备信息 / 时间 / 有效期：字段名尚未与服务端对齐，做多候选兼容，缺失即回落
        let device = stringValue(json["device"])
            ?? stringValue(json["deviceName"])
            ?? stringValue(json["platform"])
        let createdAt = dateValue(json)
        let expiresIn = expiresInValue(json)

        // v2：二维码只放 PC 临时公钥（不含任何秘密），key / iv 由 APP 本地生成
        let pubKey = strippingHexPrefix(stringValue(json["pubKey"]) ?? "")
        guard isSecp256k1PublicKey(pubKey) else {
            FZMLog("扫码登录：二维码公钥校验不通过")
            return nil
        }
        return ScanLoginQRPayload(sessionId: sessionId,
                                  pcPublicKeyHex: pubKey,
                                  device: device,
                                  createdAt: createdAt,
                                  expiresIn: expiresIn)
    }

    /// 是否是已停用的 v1 二维码（`type == "qr-login"`）。
    /// 供 `ScanLoginRouter` 给出「请在电脑端刷新」提示，避免它被当成普通二维码处理。
    static func isLegacyQRCode(_ raw: String) -> Bool {
        guard let json = jsonObject(raw) else { return false }
        return (stringValue(json["type"]) ?? "").lowercased() == legacyQrType
    }

    // MARK: - 字段解析

    private static func jsonObject(_ raw: String) -> [String: Any]? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let data = text.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String {
            if let int = Int(text) { return int }
            if let double = Double(text) { return Int(double) }
        }
        return nil
    }

    /// hex 校验：长度必须是 byteCount * 2，且全部是合法 hex 字符
    static func isHex(_ hex: String, byteCount: Int) -> Bool {
        guard hex.count == byteCount * 2 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return hex.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// 去掉 `0x` / `0X` 前缀（二维码里偶尔会带）
    static func strippingHexPrefix(_ hex: String) -> String {
        (hex.hasPrefix("0x") || hex.hasPrefix("0X")) ? String(hex.dropFirst(2)) : hex
    }

    /// secp256k1 公钥校验：33 字节压缩（0x02 / 0x03 开头）或 65 字节非压缩
    static func isSecp256k1PublicKey(_ hex: String) -> Bool {
        let text = strippingHexPrefix(hex)
        if isHex(text, byteCount: 33) {
            let prefix = text.prefix(2).lowercased()
            return prefix == "02" || prefix == "03"
        }
        return isHex(text, byteCount: 65)
    }

    private static func expiresInValue(_ json: [String: Any]) -> Int {
        guard let raw = intValue(json["expiresIn"])
            ?? intValue(json["expires_in"])
            ?? intValue(json["ttl"]), raw > 0 else {
            return defaultExpiresIn
        }
        // 兼容毫秒返回
        let seconds = raw > 1000 ? raw / 1000 : raw
        return min(max(seconds, 30), 1800)
    }

    private static func dateValue(_ json: [String: Any]) -> Date? {
        if let raw = intValue(json["createdAt"])
            ?? intValue(json["created_at"])
            ?? intValue(json["time"]) {
            // 兼容秒 / 毫秒时间戳
            let seconds = abs(raw) > 100_000_000_000 ? Double(raw) / 1000 : Double(raw)
            return Date(timeIntervalSince1970: seconds)
        }
        if let text = stringValue(json["createdAt"]) ?? stringValue(json["created_at"]) {
            if let date = ScanLoginDateParser.parse(text) { return date }
        }
        return nil
    }
}

/// 时间字符串解析（二维码里的 createdAt 可能是 ISO8601，也可能是纯时间戳字符串）
enum ScanLoginDateParser {

    static func parse(_ text: String) -> Date? {
        if let seconds = Double(text) {
            return Date(timeIntervalSince1970: abs(seconds) > 100_000_000_000 ? seconds / 1000 : seconds)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }

        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: text)
    }
}

// MARK: - 失败模型

/// 扫码登录错误（统一归一后交给界面提示）
enum ScanLoginFailure: Error {

    /// 未登录 / 无账号
    case notLogin
    /// 二维码内容非法
    case invalidQR
    /// 本地私钥读取失败
    case privateKeyUnavailable
    /// 会话不存在、已过期或已确认（服务端 result = -1）
    case invalidSession(String?)
    /// HTTP 401：签名不合法或设备时间不同步
    case unauthorized
    /// 网络层错误
    case network(String)
    /// 其它业务错误
    case server(String)

    /// 界面提示文案
    var displayMessage: String {
        switch self {
        case .notLogin:
            return L("未登录，无法确认网页登录")
        case .invalidQR:
            return L("二维码格式不正确")
        case .privateKeyUnavailable:
            return L("私钥读取失败，请重新登录后再试")
        case .invalidSession:
            return L("二维码已失效，请重新扫码")
        case .unauthorized:
            return L("登录校验失败，请检查手机系统时间后重试")
        case .network(let message), .server(let message):
            return message.isEmpty ? L("操作失败，请稍后再试") : message
        }
    }

    /// 是否属于「重试也没用」的错误：提示后自动关闭确认页
    var shouldClosePage: Bool {
        switch self {
        case .notLogin, .invalidQR, .privateKeyUnavailable, .invalidSession:
            return true
        case .unauthorized, .network, .server:
            return false
        }
    }

    /// 由 HTTP / 网络层错误码归一
    init(error: Error) {
        let nsError = error as NSError
        if nsError.code == 401 {
            self = .unauthorized
            return
        }
        let message = nsError.localizedDescription
        self = .network(message.isEmpty ? L("网络连接错误，请稍后再试") : message)
    }

    /// 由响应信封归一（`result != 0`）
    init(envelope json: [String: Any]) {
        // SwiftyJSON 的 dictionaryObject 会把数字桥接成 NSNumber，这里两种都兼容
        let code = (json["result"] as? NSNumber)?.intValue ?? (json["result"] as? Int) ?? -1
        let message = (json["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if code == -1 {
            self = .invalidSession(message.isEmpty ? nil : message)
            return
        }
        self = .server(message)
    }
}
