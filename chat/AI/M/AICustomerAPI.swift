//
//  AICustomerAPI.swift
//  chat
//
//  AI 客服免登录接口：GET /api/auth/nonce → 本地 EIP-191 签名 → POST /api/auth/login/user。
//  对接文档 §3（接口契约）、§5（限流口径）、§7（失败与降级）。
//

import Foundation

enum AICustomerAPI {

    // MARK: - 编排：取凭证（给页面用）

    /// 完整走一遍 SIWE 三步并把凭证返回给页面。
    ///
    /// - 只在页面**明确需要登录**时被调用（惰性 provider 的 `getAuth`），不做任何预登录/缓存原文，
    ///   因此用户反复进出客服**不消耗**登录配额（对接文档 §4.4 / §5）。
    /// - ★ §3.6（2026-09-24 新增）：页面在聊天中途吃到 401 时还会再调一次（登录态自愈）。因此：
    ///   ① 每次都**当场新签**、不缓存凭证；② 自愈路径必须**静默**（`allowPasswordPrompt: false`）；
    ///   ③ `getAuth()` 要 15 秒内返回，所以网络阶段共用一个 `networkDeadline` 预算。
    /// - `nonce` 是一次性的：服务端返回 `400` 表示原文过期或已被用过 ⇒ **只重取原文重签一次**。
    /// - `429` 等其它失败一律直接抛出（不循环重试），由调用方降级为"页面显示自己的登录页"。
    /// - Parameter allowPasswordPrompt: 允许弹密码框取私钥吗？首次进入（用户主动点进客服）true；
    ///   **聊天中途自愈必须 false** —— §3.6 明确要求不自愈时弹窗、不阻塞页面。
    /// - Parameter networkDeadline: 网络阶段总预算（秒）。密码是用户动作，不计入这个预算。
    static func obtainCredentials(allowPasswordPrompt: Bool = true,
                                  networkDeadline: TimeInterval = 15) async throws -> AICustomerCredentials {
        guard LoginUser.shared().isLogin else {
            throw AICustomerServiceError.notLoggedIn
        }
        guard let address = AICustomerSigner.currentAddress() else {
            throw AICustomerServiceError.walletAddressUnavailable
        }
        // ★ 先拿到私钥（首次会弹**一次**密码，之后命中内存缓存；取消 → .cancelled 静默退出）。
        //   必须在重试循环外解析：否则「原文过期重签」会把密码框再弹一次。
        let privateKey = try await requirePrivateKey(address: address, allowPrompt: allowPasswordPrompt)
        // 预算从「私钥已就绪」开始算（§3.1：`getAuth()` 15 秒内返回）
        let deadlineAt = Date().addingTimeInterval(networkDeadline)

        let tabID = AICustomerStore.tabID
        let lastSessionID = AICustomerStore.sessionID(for: address) ?? ""

        var lastError: Error = AICustomerServiceError.credentialsIncomplete
        FZMLog("AI 客服开始静默登录：address=\(address)，tab_id=\(tabID)，session_id=\(lastSessionID.isEmpty ? "空" : "有")")
        for attempt in 0..<2 {
            do {
                let siweMessage = try await fetchSIWEMessage(address: address, deadlineAt: deadlineAt)
                // 只签客服站点的 SIWE 登录原文：防止服务端/中间人塞入任意文本让用户签名。
                guard AICustomerSigner.isValidSIWE(siweMessage, address: address) else {
                    FZMLog("AI 客服：SIWE 原文校验失败，拒绝签名")
                    throw AICustomerServiceError.network(L("登录原文校验失败"))
                }
                let signature = try AICustomerSigner.signPersonalMessage(siweMessage, privateKey: privateKey)
                let credentials = try await login(address: address,
                                                  signature: signature,
                                                  sessionID: lastSessionID,
                                                  tabID: tabID,
                                                  deadlineAt: deadlineAt)
                // 会话连续性：记住 session_id，下次登录带上即可继续上次那段对话（对接文档 §6）
                AICustomerStore.saveSessionID(credentials.sessionID, for: address)
                FZMLog("AI 客服静默登录成功：服务端 eth_address=\(AICustomerSigner.maskedAddress(credentials.ethAddress))，uid=\(credentials.uid)，room_name=\(credentials.roomName)")
                return credentials
            } catch let error as AICustomerServiceError {
                lastError = error
                // 原文过期 / 已被用过：重新取一份原文再签一次（仅一次）
                if error.isBusinessCode400, attempt == 0 { continue }
                FZMLog("AI 客服免登录失败：\(error.displayDescription)")
                throw error
            }
        }
        throw lastError
    }

    // MARK: - ⓪ 取私钥（内存缓存优先，首次弹一次密码）

    /// 拿到与 `address` **同源**的 0x 私钥。
    ///
    /// - 命中 `WalletPrivateKeyStore` 内存缓存 → 直接返回，**不弹密码**；
    /// - 未命中 → 弹一次密码（已开启面容/指纹时直接通过）→ 解助记词 → 派生 → 写回缓存，
    ///   所以「AI 客服」与「开红包」只会在**第一次用到时**各弹一次（共用同一份缓存）。
    /// - 用户取消 ⇒ 抛 `.cancelled`（调用方静默处理，不当失败上报）；其它失败 ⇒ `.keyUnavailable`。
    /// - Parameter allowPrompt: 允许弹密码框吗？**§3.6 的登录态自愈必须传 `false`**：
    ///   页面对不起用户预期地弹密码框（它可能发生在用户正在聊天时），拿不到缓存私钥就**如实失败**。
    static func requirePrivateKey(address: String, allowPrompt: Bool = true) async throws -> Data {
        if let cached = WalletPrivateKeyStore.shared.cachedPrivateKey(),
           AICustomerSigner.matchesAddress(privateKey: cached, address: address) {
            return cached
        }
        guard allowPrompt else {
            FZMLog("AI 客服登录态自愈：私钥未在内存缓存中，且本次不允许弹密码框 ⇒ 如实失败（页面会停手，稍后再试）")
            throw AICustomerServiceError.keyUnavailable
        }

        let privateKey = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            // 密码框是 UI 操作，统一回主线程发起
            DispatchQueue.main.async {
                WalletPrivateKeyStore.shared.requestPrivateKey(
                    title: L("请输入密聊密码"),
                    success: { key in
                        continuation.resume(returning: key)
                    },
                    failure: { error in
                        switch error {
                        case .cancelled:
                            continuation.resume(throwing: AICustomerServiceError.cancelled)
                        default:
                            FZMLog("AI 客服取私钥失败：\(error.message.isEmpty ? "取消" : error.message)")
                            continuation.resume(throwing: AICustomerServiceError.keyUnavailable)
                        }
                    }
                )
            }
        }

        // 同源校验：不同源则签名必被服务端拒（401），提前卡住以免白耗一次登录配额
        guard AICustomerSigner.matchesAddress(privateKey: privateKey, address: address) else {
            FZMLog("AI 客服私钥与提交地址不同源，丢弃缓存")
            WalletPrivateKeyStore.shared.clear()
            throw AICustomerServiceError.keyUnavailable
        }
        return privateKey
    }

    // MARK: - ① 取 SIWE 原文

    /// `GET /api/auth/nonce?address=<0x…>`
    static func fetchSIWEMessage(address: String, deadlineAt: Date? = nil) async throws -> String {
        FZMLog("AI 客服取原文：GET \(nonceURL.absoluteString)?address=\(address)")
        guard var components = URLComponents(url: nonceURL, resolvingAgainstBaseURL: false) else {
            throw AICustomerServiceError.network(L("网络连接错误，请稍后再试"))
        }
        components.queryItems = [URLQueryItem(name: "address", value: address)]
        guard let url = components.url else {
            throw AICustomerServiceError.network(L("网络连接错误，请稍后再试"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = try remainingTimeout(until: deadlineAt)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let envelope = try await send(request)
        guard let data = envelope.data,
              let message = data["siwe_message"] as? String,
              !message.isBlank else {
            throw AICustomerServiceError.network(L("取签名原文失败，请稍后再试"))
        }
        // SIWE 原文不含敏感信息（地址公开 + nonce 一次性），但对排查最关键，完整打出
        FZMLog("AI 客服 SIWE 原文（\(message.count) 字符）：\n\(message)")
        return message
    }

    // MARK: - ③ 提交登录

    /// `POST /api/auth/login/user`
    static func login(address: String,
                      signature: String,
                      sessionID: String,
                      tabID: String,
                      deadlineAt: Date? = nil) async throws -> AICustomerCredentials {
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.timeoutInterval = try remainingTimeout(until: deadlineAt)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "address": address,
            "signature": signature,
            "session_id": sessionID,
            "tab_id": tabID
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            throw AICustomerServiceError.network(L("网络连接错误，请稍后再试"))
        }
        request.httpBody = bodyData
        // 提交参数日志：地址与 tab_id 完整（非敏感），签名按 §8-8 脱敏
        FZMLog("AI 客服提交登录：address=\(address)，signature=\(AICustomerSigner.maskedSignature(signature))，session_id=\(sessionID.isEmpty ? "空" : "有")，tab_id=\(tabID)")

        let envelope = try await send(request)
        // 交付前的字段校验（对接文档 §3.4）；本行只打字段名与脱敏值，**不打 token / livekit_token**
        FZMLog("AI 客服登录响应：code=\(envelope.code)，message=\(envelope.message.isEmpty ? "空" : envelope.message)，返回字段=\(envelope.data?.keys.sorted().joined(separator: ",") ?? "无")")
        guard let data = envelope.data, let credentials = AICustomerCredentials(json: data) else {
            throw AICustomerServiceError.credentialsIncomplete
        }
        return credentials
    }

    // MARK: - 私有

    /// 单次请求可用的超时：按「距总预算 deadline 还剩多少」给，不足 1 秒直接放弃。
    ///
    /// §3.1 / §3.6 要求 `getAuth()` **15 秒内返回**（页面 Promise 在等），所以不能只靠单次 10 秒超时
    /// 叠加（取原文 10 + 登录 10 最坏 20 秒）。这里按剩余预算收紧，超预算就如实失败 ——
    /// 页面对失败的处理是「记一条结论并停手，至少 60 秒后再试」，不会把限流打光。
    private static func remainingTimeout(until deadlineAt: Date?) throws -> TimeInterval {
        guard let deadlineAt = deadlineAt else { return AICustomerConfig.requestTimeout }
        let left = deadlineAt.timeIntervalSinceNow
        guard left >= 1 else {
            FZMLog("AI 客服登录超出 15 秒预算，放弃本次（页面会稍后自行重试）")
            throw AICustomerServiceError.network(L("网络连接错误，请稍后再试"))
        }
        return min(AICustomerConfig.requestTimeout, left)
    }

    private static var nonceURL: URL {
        AICustomerConfig.siteURL.appendingPathComponent("api/auth/nonce")
    }

    private static var loginURL: URL {
        AICustomerConfig.siteURL.appendingPathComponent("api/auth/login/user")
    }

    /// 发请求并解析完整信封。**HTTP 200 也可能是业务失败**，所以 `code != 0` 一律抛业务错误。
    private static func send(_ request: URLRequest) async throws -> (code: Int, message: String, data: [String: Any]?) {
        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch {
            throw AICustomerServiceError.network(L("网络连接错误，请稍后再试"))
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            throw AICustomerServiceError.network(L("网络连接错误，请稍后再试"))
        }

        let code = intValue(json["code"]) ?? -1
        let message = (json["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let payload = json["data"] as? [String: Any]

        guard code == 0 else {
            // 不打印完整响应（可能含凭证）；只记业务码
            FZMLog("AI 客服接口业务失败：code=\(code)")
            throw AICustomerServiceError.business(code: code,
                                                  message: message.isEmpty ? L("客服登录失败") : message)
        }
        return (code, message, payload)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
