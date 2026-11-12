//
//  AIWalletBridge.swift
//  chat
//
//  AI 客服页的 `window.ethereum`（EIP-1193）注入与回包。
//
//  为什么需要它：AI 客服 H5 的登录页只有一个「连接钱包」按钮，走的是标准钱包连接
//  （`window.ethereum.request({ method: 'eth_requestAccounts' })` → `personal_sign`）。
//  容器原来**刻意不注入 `window.ethereum`**（对接文档 §0 的静默登录路线），
//  于是那个按钮点了没有任何反应 —— 新账号（拿不到 `__csAuthProvider` 凭证时页面会回退到登录页）
//  就永远卡在「链接钱包」（用户 2026-11-04 要求这条路必须能走）。
//
//  实现取舍：
//  · **不复用** `DAppBrowser` 里的 `DAppWeb3Bridge`：它是 `private`，且强绑定 DApp 浏览器的
//    链切换 / 交易确认 UI；这里只需要「连接 + 签名 + 只读 RPC」，自成一个精简实现更安全。
//  · 签名用的私钥来自 `AICustomerAPI.requirePrivateKey`（`WalletPrivateKeyStore`，
//    首次弹一次密聊密码，之后本次启动内复用）—— 与静默登录**共用同一份缓存**，不会多弹一次。
//  · **不支持 `eth_sendTransaction`**：客服页面不需要转账，真实转账有 DApp 浏览器 /
//    红包那套带确认页的链路，这里直接报错，避免页面一个调用就把资产转走。
//  · `eth_sign` 与 DApp 浏览器口径一致，**禁用**（签的是任意 32 字节哈希）。
//

import Foundation
import WebKit
import web3swift
import Web3Core

/// JSON-RPC 错误（回给页面的是 `{ code, message }`，与 MetaMask 一致）
private struct AIWalletRPCError: Error {
    let code: Int
    let message: String

    static let userRejected = AIWalletRPCError(code: 4001, message: "User rejected the request.")
    static let noAccount = AIWalletRPCError(code: 4100, message: "No wallet address available")
    static let methodNotFound = AIWalletRPCError(code: -32601, message: "Method not supported")
    static let invalidParams = AIWalletRPCError(code: -32602, message: "Invalid params")
    static let internalError = AIWalletRPCError(code: -32603, message: "Internal error")

    /// 通用异常 → JSON-RPC 错误（用户取消密码 = 4001，与 MetaMask 一致）
    static func from(_ error: Error) -> AIWalletRPCError {
        if let rpc = error as? AIWalletRPCError { return rpc }
        if let ai = error as? AICustomerServiceError {
            switch ai {
            case .cancelled:
                return .userRejected
            case .walletAddressUnavailable, .notLoggedIn:
                return .noAccount
            case .keyUnavailable:
                return AIWalletRPCError(code: 4100, message: L("钱包密钥不可用"))
            case .network(let detail):
                return AIWalletRPCError(code: -32603, message: detail)
            case .business(_, let message):
                return AIWalletRPCError(code: -32603, message: message)
            case .credentialsIncomplete:
                return .internalError
            }
        }
        return AIWalletRPCError(code: -32603, message: error.localizedDescription)
    }
}

/// 注入 `window.ethereum` + 处理页面发来的 EIP-1193 请求。
final class AIWalletBridge: NSObject {

    static let handlerName = "aiWallet"

    /// 注入的 provider（页面脚本之前执行）。
    ///
    /// 🔴 必须 `atDocumentStart`：页面（wagmi / ethers 等）在模块初始化时就会读 `window.ethereum`，
    ///    注入晚了这一次进入就一直是「未检测到钱包」。
    static var providerScript: String {
        return #"""
        (function () {
          if (window.ethereum && window.ethereum.__tanxinAI) { return; }

          var listeners = {};
          var pending = {};
          var seq = 0;

          function fire(event, payload) {
            var arr = listeners[event] || [];
            for (var i = 0; i < arr.length; i++) {
              try { arr[i](payload); } catch (e) {}
            }
          }

          function post(message) {
            window.webkit.messageHandlers.\#(AIWalletBridge.handlerName).postMessage(message);
          }

          function request(args) {
            var method = (args && args.method) || '';
            var params = (args && args.params) || [];
            return new Promise(function (resolve, reject) {
              var id = 'w' + (++seq);
              pending[id] = { resolve: resolve, reject: reject };
              try {
                post({ id: id, method: method, params: params });
              } catch (e) {
                delete pending[id];
                reject({ code: -32603, message: 'wallet bridge unavailable' });
              }
              // 兜底超时：等用户输密码的最长等待；超时按「用户取消」处理（4001）
              setTimeout(function () {
                if (pending[id]) {
                  delete pending[id];
                  reject({ code: 4001, message: 'User rejected the request.' });
                }
              }, 90000);
            });
          }

          /// 原生回包：resultJson / errorJson 都是 JSON 字符串（'null' 表示没有）
          window.__aiWalletResolve = function (id, resultJson, errorJson) {
            var item = pending[id];
            if (!item) { return; }
            delete pending[id];
            var error = null, result = null;
            try { if (errorJson && errorJson !== 'null') { error = JSON.parse(errorJson); } } catch (e) {}
            try { if (resultJson && resultJson !== 'null') { result = JSON.parse(resultJson); } } catch (e) {}
            if (error) { item.reject(error); } else { item.resolve(result); }
          };

          /// 原生广播 `chainChanged`（页面切链后 wagmi / ethers 都在等这个事件）
          window.__aiWalletChainChanged = function (chainId) {
            try {
              if (!window.ethereum) { return; }
              window.ethereum.chainId = chainId || '';
              fire('chainChanged', chainId || '');
            } catch (e) {}
          };

          /// 原生同步状态（地址 / 链 id）：emitEvents=true 时额外抛 connect / accountsChanged
          window.__aiWalletSync = function (address, chainId, emitEvents) {
            try {
              var provider = window.ethereum;
              if (!provider) { return; }
              var changed = provider.selectedAddress !== (address || null);
              provider.selectedAddress = address || null;
              provider.chainId = chainId || '';
              if (emitEvents) {
                if (changed) { fire('accountsChanged', address ? [address] : []); }
                fire('connect', { chainId: chainId || '' });
              }
            } catch (e) {}
          };

          var provider = {
            __tanxinAI: true,
            isMetaMask: true,
            isTanxin: true,
            selectedAddress: null,
            chainId: '',
            networkVersion: '',
            request: request,
            enable: function () { return request({ method: 'eth_requestAccounts' }); },
            send: function (payloadOrMethod, paramsOrCallback) {
              // 老式 `send(payload, cb)` / `send(method, params)` 两种签名都要支持
              if (typeof payloadOrMethod === 'string') {
                return request({ method: payloadOrMethod, params: paramsOrCallback || [] });
              }
              var payload = payloadOrMethod || {};
              if (typeof payload.method === 'string' && !payload.jsonrpc) {
                return request({ method: payload.method, params: payload.params || [] });
              }
              return request({ method: payload.method || '', params: payload.params || [] });
            },
            sendAsync: function (payload, callback) {
              request({ method: (payload && payload.method) || '', params: (payload && payload.params) || [] })
                .then(function (result) { try { callback(null, { id: payload.id, jsonrpc: '2.0', result: result }); } catch (e) {} })
                .catch(function (error) { try { callback(error, null); } catch (e) {} });
            },
            on: function (event, handler) {
              if (typeof handler !== 'function') { return provider; }
              listeners[event] = listeners[event] || [];
              listeners[event].push(handler);
              return provider;
            },
            once: function (event, handler) {
              var wrapped = function (payload) {
                provider.removeListener(event, wrapped);
                try { handler(payload); } catch (e) {}
              };
              return provider.on(event, wrapped);
            },
            removeListener: function (event, handler) {
              var arr = listeners[event] || [];
              for (var i = arr.length - 1; i >= 0; i--) {
                if (arr[i] === handler) { arr.splice(i, 1); }
              }
              return provider;
            },
            removeAllListeners: function (event) {
              if (event) { delete listeners[event]; } else { listeners = {}; }
              return provider;
            },
            emit: fire
          };

          window.ethereum = provider;
          // 兼容只探测 `window.web3` 的老页面
          try {
            if (!window.web3) { window.web3 = { currentProvider: provider }; }
          } catch (e) {}
        })();
        """#
    }

    /// 宿主 WebView（弱引用，`WKUserContentController` 已经强引用了本对象）
    weak var webView: WKWebView?

    /// 上一次同步给页面的地址 / 链 id（用来判断要不要抛 `accountsChanged`）
    private var announcedAddress: String?
    private var announcedChainId: String?

    /// 页面上看到的链 id（`wallet_switchEthereumChain` 之后）。
    /// 只是让页面侧的 `eth_chainId` / `chainChanged` 自洽 —— 签名（personal_sign / EIP-712）
    /// 与具体链无关，签名用的仍是当前钱包私钥。
    private var pageChainIdHex: String?

    /// 地址 / 链变化（换账号、连接成功）后把状态推给页面。
    /// - Parameter emitEvents: 是否需要抛 `connect` / `accountsChanged`
    func syncInjectedState(emitEvents: Bool = false) {
        let address = AICustomerSigner.currentAddress() ?? ""
        let chainId = self.currentChainIdHex
        let changed = (address != (announcedAddress ?? "")) || (chainId != (announcedChainId ?? ""))
        guard changed || emitEvents else { return }
        announcedAddress = address
        announcedChainId = chainId
        evaluate("window.__aiWalletSync && window.__aiWalletSync(\(Self.jsString(address)), \(Self.jsString(chainId)), \(emitEvents ? "true" : "false"));")
    }

    // MARK: - 内部

    private static var appChainIdHex: String {
        let id = DAppBrowserConfiguration.current().chainID
        return "0x" + String(id, radix: 16)
    }

    private var currentChainIdHex: String {
        return self.pageChainIdHex ?? Self.appChainIdHex
    }

    private func evaluate(_ js: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func respond(id: String, result: Any?, error: AIWalletRPCError?) {
        guard !id.isEmpty else { return }
        let resultJSON = Self.jsonString(result) ?? "null"
        let errorJSON = error.map { Self.jsonString(["code": $0.code, "message": $0.message]) ?? "null" } ?? "null"
        evaluate("window.__aiWalletResolve && window.__aiWalletResolve(\(Self.jsString(id)), \(Self.jsString(resultJSON)), \(Self.jsString(errorJSON)));")
    }

    /// JS 字符串字面量（含引号）。用 `JSONSerialization` 生成，避免手写转义漏掉换行/引号。
    private static func jsString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let array = String(data: data, encoding: .utf8),
              array.count >= 2 else {
            return "\"\""
        }
        // `["xxx"]` → `"xxx"`
        return String(array.dropFirst().dropLast())
    }

    private static func jsonString(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        guard JSONSerialization.isValidJSONObject(value) || value is String || value is NSNumber else {
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}

// MARK: - 页面请求

extension AIWalletBridge: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let method = body["method"] as? String, !method.isEmpty else { return }
        // 只接受客服域名（含同源 iframe）；跨域 iframe 不得调用钱包能力。
        guard Self.isAllowedOrigin(message) else {
            FZMLog("AI 客服钱包桥：拒绝跨域调用 origin=\(message.frameInfo.securityOrigin.host)")
            return
        }
        let id = body["id"] as? String ?? ""
        let params = body["params"] as? [Any]

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.handle(method: method, params: params)
                await MainActor.run {
                    self.respond(id: id, result: result, error: nil)
                }
            } catch {
                let rpcError = AIWalletRPCError.from(error)
                FZMLog("AI 客服钱包桥：\(method) 失败 code=\(rpcError.code) \(rpcError.message)")
                await MainActor.run {
                    self.respond(id: id, result: nil, error: rpcError)
                }
            }
        }
    }
}

// MARK: - 方法实现

private extension AIWalletBridge {

    func handle(method: String, params: [Any]?) async throws -> Any {
        let config = DAppBrowserConfiguration.current()
        switch method {
        case "eth_requestAccounts", "eth_accounts":
            guard let address = AICustomerSigner.currentAddress() else {
                if method == "eth_accounts" { return [String]() }
                throw AIWalletRPCError.noAccount
            }
            if method == "eth_requestAccounts" {
                await MainActor.run { self.syncInjectedState(emitEvents: true) }
                FZMLog("AI 客服钱包桥：页面连接钱包 \(AICustomerSigner.maskedAddress(address))")
            }
            return [address]

        case "eth_coinbase":
            guard let address = AICustomerSigner.currentAddress() else { throw AIWalletRPCError.noAccount }
            return address

        case "eth_chainId":
            return self.currentChainIdHex

        case "net_version":
            return String(config.chainID)

        case "eth_mining":
            return false

        case "eth_hashrate":
            return "0x0"

        case "web3_clientVersion":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
            return "TanxinAI/\(version)"

        case "wallet_getPermissions":
            guard AICustomerSigner.currentAddress() != nil else { return [Any]() }
            return [["parentCapability": "eth_accounts", "caveats": [Any]()]]

        case "wallet_requestPermissions":
            guard AICustomerSigner.currentAddress() != nil else { throw AIWalletRPCError.noAccount }
            return [["parentCapability": "eth_accounts", "caveats": [Any]()]]

        case "personal_sign":
            return try await personalSign(params: params)

        case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
            // 🚫 客服页只需要 SIWE 登录签名，不需要 EIP-712。Permit / Seaport 等结构化签名
            //    可以一次授权转走全部资产，且页面无内容确认页，直接禁用。
            throw AIWalletRPCError(code: -32601, message: L("客服页不支持结构化签名"))

        case "wallet_switchEthereumChain", "wallet_addEthereumChain":
            // 客服页只需要登录签名，**不真的切 App 的网络**；但要把页面侧的链 id 改过去并抛
            // `chainChanged` —— wagmi / ethers 的 switchChain 在等这个事件，不回就会一直转圈。
            if let requested = Self.requestedChainIdHex(params) {
                self.pageChainIdHex = requested
                FZMLog("AI 客服钱包桥：页面请求 \(method) → \(requested)（仅页面侧生效）")
                evaluate("window.__aiWalletChainChanged && window.__aiWalletChainChanged(\(Self.jsString(requested)));")
            } else {
                FZMLog("AI 客服钱包桥：页面请求 \(method)（无 chainId，直接返回成功）")
            }
            return NSNull()

        case "eth_sign", "eth_signTransaction", "eth_sendTransaction", "eth_sendRawTransaction":
            // 安全边界：客服页不签名任意哈希、不发起交易（转账走 DApp 浏览器 / 红包那套带确认页的链路）
            throw AIWalletRPCError(code: -32601, message: L("客服页不支持该操作"))

        default:
            return try await forwardRPC(method: method, params: params ?? [], url: config.rpcURL)
        }
    }

    /// `personal_sign`：先按当前钱包地址取到私钥（首次会弹一次密聊密码，之后复用缓存），
    /// 再对**原始字节**做 EIP-191（`\x19Ethereum Signed Message:\n<len>`）签名。
    func personalSign(params: [Any]?) async throws -> String {
        guard let payload = Self.personalSignPayload(params) else { throw AIWalletRPCError.invalidParams }
        let address = try await currentAddressForSigning()
        let messageData = Self.personalMessageData(from: payload)
        guard !messageData.isEmpty else { throw AIWalletRPCError.invalidParams }
        // 只允许签客服站点的 SIWE 登录原文；其它文本（转账授权、钓鱼文案）一律拒绝。
        let messageText = String(data: messageData, encoding: .utf8) ?? payload
        guard Self.isValidSIWE(messageText, address: address) else {
            FZMLog("AI 客服钱包桥：拒绝非 SIWE 签名请求")
            throw AIWalletRPCError(code: -32602, message: L("签名内容不是预期的登录消息"))
        }
        let key = try await AICustomerAPI.requirePrivateKey(address: address, allowPrompt: true)
        guard let hash = Utilities.hashPersonalMessage(messageData) else { throw AIWalletRPCError.internalError }
        guard let signature = SECP256K1.signForRecovery(hash: hash, privateKey: key, useExtraEntropy: false).serializedSignature else {
            throw AIWalletRPCError(code: 4100, message: L("钱包密钥不可用"))
        }
        FZMLog("AI 客服钱包桥：personal_sign 成功 address=\(AICustomerSigner.maskedAddress(address))")
        return "0x" + signature.toHexString()
    }

    /// EIP-712（登录 / Permit 常用）。地址不一致直接拒绝，避免签出从链上看无效的签名。
    func signTypedData(params: [Any]?) async throws -> String {
        guard let typed = EIP712TypedData.parse(params: params) else { throw AIWalletRPCError.invalidParams }
        let address = try await currentAddressForSigning()
        if let declared = typed.declaredAddress,
           !declared.isEmpty,
           declared.lowercased() != address.lowercased() {
            throw AIWalletRPCError(code: -32602, message: L("签名地址与当前钱包不一致"))
        }
        let key = try await AICustomerAPI.requirePrivateKey(address: address, allowPrompt: true)
        do {
            let signature = try typed.sign(privateKey: key)
            FZMLog("AI 客服钱包桥：结构化签名成功 primaryType=\(typed.primaryType)")
            return signature
        } catch {
            FZMLog("AI 客服钱包桥：结构化签名失败 primaryType=\(typed.primaryType)")
            throw AIWalletRPCError(code: -32603, message: L("签名失败"))
        }
    }

    /// 只允许客服站点（含同源 iframe）调用钱包桥。
    static func isAllowedOrigin(_ message: WKScriptMessage) -> Bool {
        guard let allowed = AICustomerConfig.siteURL.host?.lowercased(), !allowed.isEmpty else { return false }
        return message.frameInfo.securityOrigin.host.lowercased() == allowed
    }

    /// 仅允许 EIP-4361（SIWE）登录原文签名，避免页面借 `personal_sign` 让用户签任意文本。
    static func isValidSIWE(_ message: String, address: String) -> Bool {
        AICustomerSigner.isValidSIWE(message, address: address)
    }

    func currentAddressForSigning() async throws -> String {
        guard let address = AICustomerSigner.currentAddress() else { throw AIWalletRPCError.noAccount }
        return address
    }

    /// 读链请求（`eth_call` / `eth_getBalance` / `eth_blockNumber` …）转发到当前网络 RPC
    func forwardRPC(method: String, params: [Any], url: URL) async throws -> Any {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1 ... Int.max - 1),
            "method": method,
            "params": params
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let err = json?["error"] as? [String: Any] {
            let message = err["message"] as? String ?? "RPC error"
            let code = err["code"] as? Int ?? -32603
            throw AIWalletRPCError(code: code, message: message)
        }
        return json?["result"] ?? NSNull()
    }

    // MARK: 参数解析（与 DApp 浏览器口径一致）

    /// `personal_sign` 的参数顺序两种都有：`[message, address]` 与 `[address, message]`
    /// ⇒ 先跳过「地址形态」的参数，剩下的第一个字符串才是待签名内容。
    static func personalSignPayload(_ params: [Any]?) -> String? {
        guard let params = params else { return nil }
        let texts = params.compactMap { $0 as? String }.filter { !$0.isEmpty }
        if let message = texts.first(where: { !isAddressLike($0) }) {
            return message
        }
        return texts.first
    }

    static func isAddressLike(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("0x"), trimmed.count == 42 else { return false }
        return trimmed.dropFirst(2).allSatisfy { $0.isHexDigit }
    }

    /// `wallet_switchEthereumChain` / `wallet_addEthereumChain` 的目标链 id（0x 十六进制）
    static func requestedChainIdHex(_ params: [Any]?) -> String? {
        guard let first = params?.first as? [String: Any],
              let raw = first["chainId"] as? String, !raw.isEmpty else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("0x") ? trimmed : ("0x" + trimmed)
    }

    /// `0x…` 视为原始字节，其它按 UTF-8 文本
    static func personalMessageData(from payload: String) -> Data {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x"),
           let data = Data.fromHex(trimmed), !data.isEmpty {
            return data
        }
        return trimmed.data(using: .utf8) ?? Data()
    }
}
