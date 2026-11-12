//
//  SquareSignature.swift
//  chat
//
//  谈信广场专用签名（对接文档 §1.2）
//  Header: FZM-SIGNATURE: {base64签名}#{毫秒时间戳}*{appId}#{压缩公钥hex}
//  算法与聊天客户端完全一致（sha256 + secp256k1 + base64），仅签名原文中的随机串换成 appId。
//

import Foundation

final class SquareSignature {

    static let shared = SquareSignature()

    private init() {}

    /// 服务端有效期 120s；这里做 10s 短缓存，避免同一屏多个请求重复做 secp256k1 运算
    private let cacheInterval: Int = 10 * 1000

    private var cachedToken: String?
    private var cachedAt: Int = 0
    private var cachedFingerprint = ""

    /// 生成 FZM-SIGNATURE
    /// - Parameter forceRefresh: 服务端返回 -1011（签名过期）时强制重签
    /// - Returns: 未登录 / 无密钥时返回 nil
    func token(forceRefresh: Bool = false) -> String? {
        let user = LoginUser.shared()
        guard user.isLogin, !user.privateKey.isEmpty, !user.publicKey.isEmpty else {
            return nil
        }

        // 切换账号 / 重新登录后公私钥会变，用指纹让缓存自动失效（无需侵入登录模块）
        let fingerprint = user.address + "#" + user.publicKey
        let now = Date.timestamp

        if !forceRefresh,
           fingerprint == cachedFingerprint,
           let token = cachedToken,
           now - cachedAt < cacheInterval {
            return token
        }

        let message = "\(now)" + "*" + APPID
        guard let rawValue = message.data(using: .utf8)?.sha256(),
              let signature = EncryptManager.signBase64(data: rawValue, privateKey: user.privateKey) else {
            FZMLog("广场签名生成失败")
            return nil
        }

        let token = signature.finalKey + "#" + message + "#" + user.publicKey
        cachedToken = token
        cachedAt = now
        cachedFingerprint = fingerprint
        return token
    }

    /// 清空缓存（切号 / 登出时可选调用，指纹机制已能兜底）
    func reset() {
        cachedToken = nil
        cachedAt = 0
        cachedFingerprint = ""
    }
}
