//
//  DAppBrowser.swift
//  chat
//
//  基于 web3swift 的 EIP-1193 DApp 浏览器：账户、签名、交易构造、本地签名与发送；
//  账户一律使用当前钱包 EVM 地址（RedPacketWalletDataSource）。
//

import UIKit
import WebKit
import os.lock
import BigInt
import web3swift
import Web3Core

// MARK: - 链与 RPC 配置

/// 与 `WebViewController.m` 中 `BTYRPCUrl` / `BNBRPCUrl` / `ETHRPCUrl` 及 `-setNetAndLoadView` 的 `_selectedChainID` 对齐。
///
/// ⚠️ 这里是**默认值**（用户没改过时用）；用户可在「选择网络」页 → 编辑 里按网络覆盖，
///    取地址一律走 `DAppRPCSettings.currentURL(for:)`，不要直接引用本常量。
enum AppExploreWebRPC {
    static let bty = URL(string: "https://mainnet.bityuan.com/eth")!
    static let bnb = URL(string: "https://bsc-dataseed.bnbchain.org/")!
    static let eth = URL(string: "https://rpc.flashbots.net")!
}

/// 全局区块链节点配置
@objc public class BlockchainRPC: NSObject {
    /// 所有支持的网络 RPC URL 字符串（含用户在「选择网络 → 编辑」里改过的自定义地址）
    @objc public static var allURLs: [String] {
        return DAppRPCSettings.supportedNets.map { DAppRPCSettings.currentURL(for: $0).absoluteString }
    }
    /// 当前网络 RPC URL 字符串
    @objc public static var currentURL: String {
        return current.absoluteString
    }
    /// 当前网络 RPC URL
    public static var current: URL {
        return DAppBrowserConfiguration.current().rpcURL
    }
    /// 当前网络 Chain ID
    public static var currentChainID: BigUInt {
        return DAppBrowserConfiguration.current().chainID
    }
}

public struct DAppBrowserConfiguration: Equatable {
    public var rpcURL: URL
    public var chainID: BigUInt

    public init(rpcURL: URL, chainID: BigUInt) {
        self.rpcURL = rpcURL
        self.chainID = chainID
    }

    /// 与 `WebViewController` `-setNetAndLoadView` 一致：通过 `[[PWAppsettings instance] getAPPNetType]` 选择链与 RPC，不使用 Info.plist / UserDefaults。
    public static func current() -> DAppBrowserConfiguration {
        let net = PWAppsettings.instance().getAPPNetType()
        return configuration(forAppNetType: net)
    }

    /// `NetType` 见 `PWAppsettings.h`（NetBTY / NetETH / NetBNB）；未知类型回退为 BNB。
    ///
    /// RPC 地址**从配置取**（`DAppRPCSettings`）：用户在「选择网络 → 编辑」里改过的优先，
    /// 没改过就是 `AppExploreWebRPC` 里的默认值 —— 这里不再写死地址。
    private static func configuration(forAppNetType net: NetType) -> DAppBrowserConfiguration {
        let rpcURL = DAppRPCSettings.currentURL(for: net)
        switch net.rawValue {
        case 0: // NetBTY
            return DAppBrowserConfiguration(rpcURL: rpcURL, chainID: BigUInt(2999))
        case 1: // NetETH
            return DAppBrowserConfiguration(rpcURL: rpcURL, chainID: BigUInt(1))
        case 2: // NetBNB
            return DAppBrowserConfiguration(rpcURL: rpcURL, chainID: BigUInt(56))
        default:
            return DAppBrowserConfiguration(rpcURL: rpcURL, chainID: BigUInt(2999))
        }
    }
}

// MARK: - 错误

private enum DAppWeb3Error: LocalizedError {
    case walletUnavailable
    case passwordInvalid
    case privateKeyUnavailable
    case addressMismatch
    case invalidParams(String)
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .walletUnavailable: return L("未找到当前钱包地址")
        case .passwordInvalid: return L("密码错误")
        case .privateKeyUnavailable: return L("无法获取私钥")
        case .addressMismatch: return L("交易 from 与当前钱包地址不一致")
        case .invalidParams(let m): return m
        case .rpcError(let m): return m
        }
    }
}

// MARK: - Web3 桥（签名 / 交易 / 发送均走 web3swift）

private final class DAppWeb3Bridge {
    private var unfairLock = os_unfair_lock_s()
    private var configuration: DAppBrowserConfiguration

    init(configuration: DAppBrowserConfiguration) {
        self.configuration = configuration
    }

    /// 与 `PWAppsettings.getAPPNetType` 对齐（例如从探索 Web 返回、切换 App 网络后再进入 DApp）。
    func syncWithAppSettings() {
        updateConfiguration(DAppBrowserConfiguration.current())
    }

    private func withLock<T>(_ body: () -> T) -> T {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return body()
    }

    func updateConfiguration(_ config: DAppBrowserConfiguration) {
        withLock { configuration = config }
    }

    func configurationSnapshot() -> DAppBrowserConfiguration {
        withLock { configuration }
    }

    /// 当前选中钱包的 EVM 地址字符串（钱包地址）
    func walletAddressString() -> String? {
        RedPacketWalletDataSource.shared.getCurrentWalletAddress()?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// `eth_sendTransaction` 手续费预览（与 `buildCodableTransaction` 一致：含 estimateGas / RPC gasPrice）。
    func previewEthSendFee(dict: [String: Any]) async throws -> DAppEthSendFeePreview {
        let cfg = configurationSnapshot()
        let w3 = try await web3()
        let wallet = try resolvedWalletAddress()
        let rpcGas = try await w3.eth.gasPrice()
        let tx = try await buildCodableTransaction(from: dict, wallet: wallet, chainID: cfg.chainID, web3: w3)
        let uses1559 = dict["maxFeePerGas"] != nil || dict["maxPriorityFeePerGas"] != nil
        let gl = tx.gasLimit
        let feeWei: BigUInt
        let legacyGP = tx.gasPrice
        let mf = tx.maxFeePerGas
        let mp = tx.maxPriorityFeePerGas
        if uses1559 {
            feeWei = gl * (mf ?? 0)
        } else {
            feeWei = gl * (legacyGP ?? 0)
        }
        return DAppEthSendFeePreview(
            gasLimit: gl,
            feeWei: feeWei,
            uses1559: uses1559,
            rpcGasPriceWei: rpcGas,
            legacyGasPriceWei: legacyGP,
            maxFeePerGasWei: mf,
            maxPriorityFeeWei: mp
        )
    }

    func web3() async throws -> Web3 {
        let snap = configurationSnapshot()
        let provider = try await Web3HttpProvider(url: snap.rpcURL, network: .Custom(networkID: snap.chainID))
        return Web3(provider: provider)
    }

    func handleMethod(method: String, params: [Any]?, password: String?) async throws -> Any {
        let cfg = configurationSnapshot()
        switch method {
        case "eth_requestAccounts", "eth_accounts":
            guard let addr = walletAddressString() else { throw DAppWeb3Error.walletUnavailable }
            return [addr]

        /// 老式 dapp（多为游戏/Unity WebGL 导出）仍用 `eth_coinbase` 取当前账号。
        /// MetaMask 也实现了它（单地址字符串，非数组）；节点不支持，必须本地返回，
        /// 否则会原样抛出 `the method eth_coinbase does not exist/is not available`。
        case "eth_coinbase":
            guard let addr = walletAddressString() else { throw DAppWeb3Error.walletUnavailable }
            return addr

        /// 与 `eth_coinbase` 同类：MetaMask 本地返回、公链节点不实现，老式游戏 dapp 常用来探测环境。
        /// 返回 MetaMask 一致值，避免站点收到 `does not exist/is not available` 而中断初始化。
        case "eth_mining":
            return false

        case "eth_hashrate":
            return "0x0"

        case "eth_chainId":
            return hexChainId(cfg.chainID)

        case "net_version":
            return String(cfg.chainID)

        case "web3_clientVersion":
            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
            return "TanxinDApp/\(ver)"

        /// Uniswap / wagmi 连接流程会调用，节点 RPC 不支持，需本地返回（与 `WebViewMetaMaskCoordinator` 一致）。
        case "wallet_getPermissions":
            guard walletAddressString() != nil else { return [] }
            return [["parentCapability": "eth_accounts", "caveats": []]]

        case "wallet_requestPermissions":
            guard walletAddressString() != nil else {
                throw NSError(
                    domain: "DAppBrowser",
                    code: 4001,
                    userInfo: [NSLocalizedDescriptionKey: L("未连接钱包")]
                )
            }
            return [["parentCapability": "eth_accounts", "caveats": []]]

        case "personal_sign":
            guard let pwd = password, !pwd.isEmpty else { throw DAppWeb3Error.invalidParams(L("需要钱包密码")) }
            guard let messagePayload = personalSignParams(params) else { throw DAppWeb3Error.invalidParams(L("personal_sign 参数无效")) }
            let key = try privateKeyData(password: pwd)
            let data = try personalMessageData(from: messagePayload)
            guard let hash = Utilities.hashPersonalMessage(data) else { throw DAppWeb3Error.privateKeyUnavailable }
            let sig = SECP256K1.signForRecovery(hash: hash, privateKey: key, useExtraEntropy: false)
            guard let raw = sig.serializedSignature else { throw DAppWeb3Error.privateKeyUnavailable }
            return raw.toHexString().addHexPrefix()

        /// EIP-712 结构化数据（登录 / Permit / 挂单等）。参数形如 `[address, jsonString]`，
        /// 少数库会直接传对象。签名前必须校验地址与当前钱包一致，否则签出来的签名从链上角度看是无效的。
        case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
            guard let pwd = password, !pwd.isEmpty else { throw DAppWeb3Error.invalidParams(L("需要钱包密码")) }
            guard let typed = EIP712TypedData.parse(params: params) else {
                throw DAppWeb3Error.invalidParams(L("结构化签名参数无效"))
            }
            if let declared = typed.declaredAddress,
               let wallet = walletAddressString(),
               declared.lowercased() != wallet.lowercased() {
                throw DAppWeb3Error.addressMismatch
            }
            let typedKey = try privateKeyData(password: pwd)
            do {
                let signature = try typed.sign(privateKey: typedKey)
                FZMLog("DApp 浏览器：结构化签名成功 primaryType=\(typed.primaryType)")
                return signature
            } catch let error as EIP712Error {
                FZMLog("DApp 浏览器：结构化签名失败 primaryType=\(typed.primaryType) reason=\(error.debugReason)")
                throw DAppWeb3Error.invalidParams(error.errorDescription ?? L("签名失败"))
            }

        case "eth_sign":
            // 🚫 直接禁用：eth_sign 签的是**任意 32 字节哈希**，攻击者可让这个哈希恰好等于
            // 一笔转账交易的哈希 ⇒ 用户以为在「签名验证」，实际签掉了一笔转账。
            // 主流钱包（MetaMask / Ledger 等）均已禁用；dApp 如需签名请用 personal_sign / eth_signTypedData。
            throw DAppWeb3Error.invalidParams(L("出于安全考虑，已禁用 eth_sign（原始数据签名），请使用 personal_sign"))

        case "eth_sendTransaction":
            guard let pwd = password, !pwd.isEmpty else { throw DAppWeb3Error.invalidParams(L("需要钱包密码")) }
            guard let dict = (params?.first as? [String: Any]) ?? (params as? [String: Any]) else {
                throw DAppWeb3Error.invalidParams(L("eth_sendTransaction 参数无效"))
            }
            let w3 = try await web3()
            let wallet = try resolvedWalletAddress()
            var tx = try await buildCodableTransaction(from: dict, wallet: wallet, chainID: cfg.chainID, web3: w3)
            let key = try privateKeyData(password: pwd)
            try tx.sign(privateKey: key)
            guard let raw = tx.encode(for: .transaction) else { throw DAppWeb3Error.privateKeyUnavailable }
            let sent = try await w3.eth.send(raw: raw)
            return sent.hash

        case "wallet_switchEthereumChain", "wallet_addEthereumChain":
            throw DAppWeb3Error.invalidParams(L("链切换由浏览器处理"))

        default:
            return try await forwardJSONRPC(method: method, params: params ?? [], rpcURL: cfg.rpcURL)
        }
    }

    // MARK: - JSON-RPC 转发（读链请求仍通过同一 RPC，与 web3 实例一致）

    private func forwardJSONRPC(method: String, params: [Any], rpcURL: URL) async throws -> Any {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1 ... Int.max - 1),
            "method": method,
            "params": params
        ]
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let err = json?["error"] as? [String: Any] {
            let message = err["message"] as? String ?? "RPC error"
            throw DAppWeb3Error.rpcError(message)
        }
        return json?["result"] ?? NSNull()
    }

    // MARK: - 交易构造（web3swift CodableTransaction + eth.estimateGas / gasPrice）

    private func buildCodableTransaction(
        from dict: [String: Any],
        wallet: EthereumAddress,
        chainID: BigUInt,
        web3: Web3
    ) async throws -> CodableTransaction {
        if let fromStr = dict["from"] as? String,
           let fromAddr = EthereumAddress(fromStr, ignoreChecksum: true),
           fromAddr.address.lowercased() != wallet.address.lowercased() {
            throw DAppWeb3Error.addressMismatch
        }

        guard let toStr = dict["to"] as? String, let to = EthereumAddress(toStr, ignoreChecksum: true) else {
            throw DAppWeb3Error.invalidParams(L("缺少有效的 to 地址"))
        }

        let value = parseHexUInt(dict["value"] as? String) ?? 0
        let dataHex = dict["data"] as? String ?? "0x"
        let payload = Data.fromHex(dataHex) ?? Data()

        let nonce: BigUInt
        if let ns = dict["nonce"] as? String, let n = parseHexUInt(ns) {
            nonce = n
        } else {
            nonce = try await web3.eth.getTransactionCount(for: wallet, onBlock: .pending)
        }

        let uses1559 = dict["maxFeePerGas"] != nil || dict["maxPriorityFeePerGas"] != nil

        var tx: CodableTransaction
        if uses1559 {
            let baseGas = try await web3.eth.gasPrice()
            let maxPriority = parseHexUInt(dict["maxPriorityFeePerGas"] as? String) ?? (baseGas / 10)
            let maxFee = parseHexUInt(dict["maxFeePerGas"] as? String) ?? (baseGas * 2 + maxPriority)
            tx = CodableTransaction(
                type: .eip1559,
                to: to,
                nonce: nonce,
                chainID: chainID,
                value: value,
                data: payload,
                gasLimit: 0,
                maxFeePerGas: maxFee,
                maxPriorityFeePerGas: maxPriority,
                gasPrice: nil
            )
        } else {
            let rpcGasPrice = try await web3.eth.gasPrice()
            let gasPrice = parseHexUInt(dict["gasPrice"] as? String) ?? rpcGasPrice
            tx = CodableTransaction(
                type: .legacy,
                to: to,
                nonce: nonce,
                chainID: chainID,
                value: value,
                data: payload,
                gasLimit: 0,
                gasPrice: gasPrice
            )
        }

        tx.from = wallet

        if let gl = dict["gas"] as? String ?? dict["gasLimit"] as? String, let g = parseHexUInt(gl), g > 0 {
            tx.gasLimit = g
        } else {
            let est = try await web3.eth.estimateGas(for: tx)
            tx.gasLimit = est + est / 5
        }

        return tx
    }

    // MARK: - 参数解析

    /// 返回待签名的消息字符串（不使用单元素命名元组，避免 Swift 将其与 `String` 混淆导致 `.message` 编译错误）。
    private func personalSignParams(_ params: [Any]?) -> String? {
        guard let p = params, p.count >= 2 else { return nil }
        if let s = p[0] as? String {
            return s
        }
        if let data = p[0] as? Data {
            return data.toHexString().addHexPrefix()
        }
        return nil
    }

    private func ethSignParams(_ params: [Any]?) -> (address: EthereumAddress, dataHex: String)? {
        guard let p = params, p.count >= 2,
              let addrStr = p[0] as? String,
              let addr = EthereumAddress(addrStr, ignoreChecksum: true),
              let dataHex = p[1] as? String else { return nil }
        return (address: addr, dataHex: dataHex)
    }

    private func personalMessageData(from message: String) throws -> Data {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("0x"), let d = Data.fromHex(trimmed) { return d }
        guard let utf8 = trimmed.data(using: .utf8) else {
            throw DAppWeb3Error.invalidParams(L("消息编码失败"))
        }
        return utf8
    }

    private func resolvedWalletAddress() throws -> EthereumAddress {
        guard let s = walletAddressString(), let a = EthereumAddress(s, ignoreChecksum: true) else {
            throw DAppWeb3Error.walletUnavailable
        }
        return a
    }

    // MARK: - 私钥（与 RedPacketWeb3Integration 一致：HD / 导入私钥）

    private func privateKeyData(password: String) throws -> Data {
        guard let wallet = PWDataBaseManager.shared().queryWalletIsSelected() else {
            throw DAppWeb3Error.walletUnavailable
        }
        guard GoFunction.checkPassword(password, hash: wallet.wallet_password) else {
            throw DAppWeb3Error.passwordInvalid
        }
        guard let seedOrPrivateKey = GoFunction.deckey(wallet.wallet_remembercode, password: password), !seedOrPrivateKey.isEmpty else {
            throw DAppWeb3Error.privateKeyUnavailable
        }

        if wallet.wallet_issmall == 2 {
            guard let key = Data.fromHex(seedOrPrivateKey) else { throw DAppWeb3Error.privateKeyUnavailable }
            return key
        }

        guard let hdWallet = GoFunction.goCreateHDWallet("ETH", rememberCode: seedOrPrivateKey) else {
            throw DAppWeb3Error.privateKeyUnavailable
        }
        guard let key = try? hdWallet.newKeyPriv(0) else {
            throw DAppWeb3Error.privateKeyUnavailable
        }
        return key
    }
}

// MARK: - 工具

private func hexChainId(_ id: BigUInt) -> String {
    if id == 0 { return "0x0" }
    return String(id, radix: 16).addHexPrefix()
}

private func parseHexUInt(_ hex: String?) -> BigUInt? {
    guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
    let stripped = hex.hasPrefix("0x") || hex.hasPrefix("0X") ? String(hex.dropFirst(2)) : hex
    return BigUInt(stripped, radix: 16)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - DApp 浏览器页

/// 内置 WKWebView + `window.ethereum`（EIP-1193），签名与交易走 web3swift。
public final class DAppBrowserViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    private var webView: WKWebView?
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var progressKVO: NSKeyValueObservation?
    /// 进度停滞看门狗（子资源卡住时兜底收掉进度条）
    private var progressStallWorkItem: DispatchWorkItem?
    /// 本次导航的进度条是否已收尾。
    /// WKWebView 的 `estimatedProgress` 在**有子资源超时/挂起**时永远到不了 1
    /// （`bityuan.com/pool-detail` 的 `telegram-widget.js`、walletconnect websocket 就是），
    /// 只靠 `>= 1` 收不掉，表现为「进度条卡在五分之四（0.8）不消失」。
    /// 收尾后忽略同一导航的后续进度，避免进度条反复闪现；新导航开始时复位。
    private var isProgressFinished = false
    private var titleKVO: NSKeyValueObservation?
    /// 与 `WebViewController` 的 `WKWebViewJavascriptBridge` 对齐，供 H5 调用 `sign` / `getAddress` 等。
    private var wvjb: WKWebViewJavascriptBridge?
    private let bridge: DAppWeb3Bridge
    /// 本次打开的地址。语音房判定（`isVoiceRoom`）与「重复 push 去重」都要用它，故对外只读暴露。
    public let initialURL: URL
    private let messageHandlerName = "dappBrowserBridge"

    /// H5 通用宿主对象 `window.__tanxinHost`（《谈信 App × H5 通用对接说明》）。
    ///
    /// **所有 DApp 页面**（含联邦商城 `fedmall.bityuan.com`）都可分享到谈信 / 广场、保存图片、原生返回。
    /// 与钱包桥（`dappBrowserBridge` / `window.ethereum`）互不干扰：这是另一条独立通道。
    private let tanxinBridge = TanxinHostBridge()

    /// 语音房支持：媒体配置 / `window.H5Wallet` 地址桥 / 麦克风 / 音频会话 / 自签证书 / 自动登录。
    /// **只有本次打开的就是语音房链接时才启用**（见 `isVoiceRoom`），其它 dapp 行为完全不变。
    private let voiceRoomSupport = VoiceRoomWebSupport()
    private var isVoiceRoom: Bool { VoiceRoomWebSupport.isVoiceRoomLink(initialURL) }

    /// 本次打开的是不是 **bityuan 官网**。
    ///
    /// 官网客服弹框（「联系客服」/「智能客服」）的 `window.open` 拦截**只对它生效**。
    /// 站点侧没有任何 JS 桥接（两个按钮都是裸的 `window.open(url, "_blank")`），
    /// 只能按 URL 认 —— 详见 `handleOfficialCustomerService(_:)`。
    private var isOfficialSite: Bool {
        let host = (initialURL.host ?? "").lowercased()
        return host == "bityuan.com" || host == "www.bityuan.com"
    }

    /// 最近一次已用 App 原生页面接管的官网客服链接（URL + 时间）。
    ///
    /// 一次 `window.open(_blank)` 可能先走 `decidePolicyFor`、再过 `createWebViewWith`，
    /// 用它保证同一次点击只 push 一个页面（1 秒内同一 URL 视为同一次）。
    private var lastHandledCustomerServiceURL: String?
    private var lastHandledCustomerServiceAt: CFTimeInterval = 0

    /// 语音房：页面是否**加载失败**。
    /// 通话容器据此把顶部的「缩放」按钮换成「返回」—— 页面都没出来，缩小了也没用，得能退出去。
    public private(set) var isVoiceRoomLoadFailed = false
    /// 语音房页面加载状态变化回调（true = 失败）
    public var onVoiceRoomLoadFailureChanged: ((Bool) -> Void)?

    /// 语音房**加载看门狗**：这么久还没 `didFinish` 就先按加载失败处理。
    ///
    /// ⚠️ WKWebView / URLSession 默认要 **60 秒**才报超时 —— 用户 2026-09-30 要求把
    ///    「进不去时多久出返回按钮」从 1 分钟改成 **10 秒**，所以自己起表，不等系统超时。
    /// ⚠️ 页面如果只是慢、10 秒之后才加载完，`didFinish` 会把状态改回正常（按钮自己变回「缩放」）。
    private static let voiceRoomLoadTimeout: TimeInterval = 10
    private var voiceRoomLoadWatchdog: DispatchWorkItem?
    /// 语音房页面**顶栏实测高度**（pt）；通话容器靠它决定「缩小 / 返回」按钮放哪
    public var onVoiceRoomHeaderHeightMeasured: ((CGFloat) -> Void)?

    /// 页面**真实标题**回调：WebView 的 `title` 变化时回调（已去首尾空白，空标题不回调）。
    ///
    /// 用途：「发现页」的搜索历史用它给那条记录补**默认显示名**（用户自己改过名字的不覆盖）。
    @objc public var onPageTitleChanged: ((String) -> Void)?

    /// 真正加载的地址：**语音 / 视频房会在 `initialURL` 上补 `name`**（H5 拿它当参与者显示名），
    /// 其它 dapp 原样返回。
    ///
    /// ⚠️ H5 端 `room` + `pin` + `name` **三者齐全才会自动加入房间**，缺 name 得用户手填。
    /// ⚠️ 名字**按人、在打开时**补：消息里分享的那条链接本身不带名字，
    ///    否则收链接的人会顶着发起人的名字进房。
    /// ⚠️ `initialURL` 保持**原样**（导航栏标题、`VoiceRoomLauncher` 的去重都比它）。
    private var voiceRoomEntryURL: URL {
        guard isVoiceRoom else { return initialURL }
        return VoiceRoomService.link(initialURL, addingName: VoiceRoomWebSupport.currentDisplayName())
    }

    /// 已同步给页面的钱包地址（用于判定账号是否**真的**发生变化，见 `syncInjectedAccount`）。
    private var injectedAddress: String?
    /// 正在展示授权弹层的请求 key（方法 + 参数）；非 nil 表示当前已有弹层，其余请求排队。
    private var activeAuthKey: String?
    /// 弹层展示期间到达的待授权请求（按到达顺序排队），保证同一时刻只有一个弹层。
    private var queuedAuthRequests: [(reqId: String, method: String, params: [Any]?, key: String)] = []

    /// - Parameters:
    ///   - url: 打开的 DApp 地址（Uniswap、OpenSea 等 HTTPS 站点）
    ///   - configuration: 不传则使用 `DAppBrowserConfiguration.current()`
    public init(url: URL, configuration: DAppBrowserConfiguration? = nil) {
        self.initialURL = url
        self.bridge = DAppWeb3Bridge(configuration: configuration ?? DAppBrowserConfiguration.current())
        super.init(nibName: nil, bundle: nil)
    }

    /// 供 Objective-C 调用（`DAppBrowserConfiguration` 非 ObjC 类型，故仅暴露 URL；链配置走 `DAppBrowserConfiguration.current()`）。
    @objc public convenience init(dappURL: URL) {
        self.init(url: dappURL, configuration: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupExploreNavigationBar()
        setupWebView()
        navigationItem.title = initialURL.absoluteString
        webView?.load(URLRequest(url: voiceRoomEntryURL))
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        applyExploreNavigationBarAppearance()
        bridge.syncWithAppSettings()
        reinjectChainId()
        DAppWVJBLegacyHandlers.prefetchBtyFeeConfig()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 语音房：请求麦克风 + 把音频会话切到 `.playAndRecord`（输出扬声器）
        if isVoiceRoom { voiceRoomSupport.prepareMedia() }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 只在**真的离开这一页**时释放音频（被别的页 push 覆盖时还要继续听）
        if isMovingFromParent || isBeingDismissed {
            voiceRoomSupport.deactivateAudioSession()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 语音房：**退出页面就自动挂断**（让页面主动断连，不等 WebView 被销毁 ——
        // 否则对端还会看到我们「在房间里」、麦克风/摄像头轨道也还开着）。
        // ⚠️ 放在 `viewDidDisappear` 而不是 `viewWillDisappear`：侧滑返回**可以中途取消**，
        //    `viewWillDisappear` 在滑动一开始就触发，那时挂断的话用户滑回来会发现自己已经退房了。
        guard isMovingFromParent || isBeingDismissed else { return }
        if isVoiceRoom { voiceRoomSupport.hangUp() }
    }

    /// 语音房：开始媒体会话（请求麦克风 + 挂音频会话观察者 + 看门狗）。
    ///
    /// ⚠️ 由**通话容器**在出现时显式调用：通话界面不进导航栈，子 VC 的 `viewDidAppear`
    ///    不保证被转发到，不能只依赖它。幂等，与 `viewDidAppear` 里那次重复也没关系。
    public func startVoiceRoomMedia() {
        guard isVoiceRoom else { return }
        voiceRoomSupport.prepareMedia()
    }

    /// 语音房：**真的挂断**（页面断开 + 释放音频会话），供通话容器在收到页面「挂断」时调用
    public func hangUpVoiceRoomCall() {
        guard isVoiceRoom else { return }
        voiceRoomSupport.hangUp()
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }

    // MARK: - 导航栏（对齐 `WebViewController`：`setNavBar` / `viewWillAppear` 导航栏样式）

    /// 与 `SGColorFromRGB(0x333649)`、`0xffffff` 一致。
    private static let exploreNavTitleColor = UIColor(red: 51 / 255, green: 54 / 255, blue: 73 / 255, alpha: 1)

    private func setupExploreNavigationBar() {
        let leftBar = UIView(frame: .zero)
        leftBar.backgroundColor = .white
        leftBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leftBar.widthAnchor.constraint(equalToConstant: 96),
            leftBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        let backBtn = UIButton(type: .custom)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.setBackgroundImage(UIImage(named: "webBack"), for: .normal)
        backBtn.addTarget(self, action: #selector(exploreNavBackTapped), for: .touchUpInside)
        leftBar.addSubview(backBtn)
        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: leftBar.leadingAnchor, constant: -16),
            backBtn.centerYAnchor.constraint(equalTo: leftBar.centerYAnchor)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBar)

        let rightBar = UIView(frame: .zero)
        rightBar.backgroundColor = .white
        rightBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rightBar.widthAnchor.constraint(equalToConstant: 96),
            rightBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        let moreBtn = UIButton(type: .custom)
        moreBtn.translatesAutoresizingMaskIntoConstraints = false
        moreBtn.setImage(UIImage(named: "web_more"), for: .normal)
        moreBtn.addTarget(self, action: #selector(exploreNavMoreTapped), for: .touchUpInside)
        rightBar.addSubview(moreBtn)
        NSLayoutConstraint.activate([
            moreBtn.trailingAnchor.constraint(equalTo: rightBar.trailingAnchor, constant: 16),
            moreBtn.centerYAnchor.constraint(equalTo: rightBar.centerYAnchor),
            moreBtn.widthAnchor.constraint(equalToConstant: 50)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBar)
    }

    private func applyExploreNavigationBarAppearance() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.backgroundColor = .white
            appearance.backgroundEffect = nil
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: Self.exploreNavTitleColor
            ]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.setBackgroundImage(Self.whitePixelImage(), for: .default)
            navigationController?.navigationBar.shadowImage = UIImage()
        }
    }

    private static func whitePixelImage() -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        UIColor.white.setFill()
        UIRectFill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }

    /// 当前页 URL；复制 / 外链与 `WebViewController.webUrl` 语义对齐（优先 WebView 当前地址）。
    private func currentDisplayURLString() -> String {
        if let u = webView?.url?.absoluteString, !u.isEmpty { return u }
        return initialURL.absoluteString
    }

    /// 优先展示网页 `<title>`；无标题或空白时再显示当前 URL。
    private func applyExploreNavigationTitle(for webView: WKWebView) {
        let urlText = {
            if let u = webView.url?.absoluteString, !u.isEmpty { return u }
            return self.currentDisplayURLString()
        }()
        if let t = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            navigationItem.title = t
        } else {
            navigationItem.title = urlText
        }
    }

    @objc private func exploreNavBackTapped() {
        if webView?.canGoBack == true {
            webView?.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    /// 当前 DApp 名称（分享抬头的「来自…」用它）：
    /// 优先页面 `<title>`（各站点自己的名称，如「BitYuan联邦商城」），取不到回退到域名（去掉 `www.`）。
    private func currentDAppName() -> String {
        if let title = webView?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        var host = (webView?.url?.host ?? initialURL.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    @objc private func exploreNavMoreTapped() {
        let sheet = WebSheetView(frame: CGRect(origin: .zero, size: UIScreen.main.bounds.size), isLiked: false)
        sheet.sheetBlock = { [weak self] sheetType in
            guard let self else { return }
            switch sheetType {
            case .refresh:
                self.exploreReloadWeb()
            case .copyUrl:
                UIPasteboard.general.string = self.currentDisplayURLString()
                self.showCustomMessage(L("复制成功"), hideAfterDelay: 2)
            case .openUrl:
                let s = self.currentDisplayURLString()
                if let url = URL(string: s) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            case .exit:
                self.navigationController?.popViewController(animated: true)
            case .changeAccount, .like:
                break
            @unknown default:
                break
            }
        }
        sheet.presentSheet(on: view)
    }

    private func exploreReloadWeb() {
        guard let wv = webView else { return }
        if wv.url != nil {
            wv.reloadFromOrigin()
        } else {
            wv.load(URLRequest(url: voiceRoomEntryURL))
        }
    }

    deinit {
        progressKVO?.invalidate()
        progressKVO = nil
        progressStallWorkItem?.cancel()
        progressStallWorkItem = nil
        voiceRoomLoadWatchdog?.cancel()
        voiceRoomLoadWatchdog = nil
        titleKVO?.invalidate()
        titleKVO = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: VoiceRoomWebSupport.walletHandlerName)
        voiceRoomSupport.deactivateAudioSession()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        // 语音房 H5（LiveKit / WebRTC）需要摄像头 + 麦克风 + 地址桥。
        // 只有本次打开的就是语音房链接时才启用 —— **其它 dapp 一律不放开媒体自动播放**。
        if isVoiceRoom {
            voiceRoomSupport.configure(config)
        }
        let bundle = bridge.configurationSnapshot()
        let chainHex = hexChainId(bundle.chainID)
        let script = WKUserScript(source: Self.injectedProviderJS(chainIdHex: chainHex), injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        let endPing = WKUserScript(
            source: "(function(){try{window.dispatchEvent(new Event('ethereum#initialized'));if(typeof window.__dapp6963Announce==='function')window.__dapp6963Announce();}catch(e){}})();",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(endPing)
        config.userContentController.add(self, name: messageHandlerName)

        // ★ H5 通用宿主对象（`window.__tanxinHost`，页面脚本之前注入）：
        //   `name: 'tanxin-ios'` + 返回 / 分享 / 分享到广场 / 保存图片（含分片）。
        //   只注入主框架：DApp 站点的能力入口都在主页面，没必要让三方 iframe 也能调起 App 能力。
        tanxinBridge.host = self
        tanxinBridge.onBack = { [weak self] in self?.exploreNavBackTapped() }
        // 分享抬头与 AI 客服同款版式（`来自X的分享` + `「标题/摘要/链接」`），
        // X = 当前 DApp 名称（优先页面标题，取不到用域名）
        tanxinBridge.shareHeaderProvider = { [weak self] in
            guard let self = self else { return nil }
            let name = self.currentDAppName()
            return name.isEmpty ? nil : "来自\(name)的分享"
        }
        config.userContentController.add(tanxinBridge, name: TanxinHostConfig.handlerName)
        config.userContentController.addUserScript(TanxinHostScript.userScript(forMainFrameOnly: true))

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = UIColor(red: 240 / 255, green: 240 / 255, blue: 240 / 255, alpha: 1)
        progressView.progressTintColor = UIColor(red: 113 / 255, green: 144 / 255, blue: 255 / 255, alpha: 1)
        progressView.alpha = 0
        view.addSubview(progressView)

        let wv = WKWebView(frame: .zero, configuration: config)
        // `uiDelegate` 决定 `window.open` / `target="_blank"` 的去向（见 `createWebViewWith`）：
        //  · 语音房：媒体授权（`getUserMedia`）回调必需；
        //  · bityuan 官网：客服弹框两个按钮都是 `window.open(_blank)`，要在这里接住转原生页面。
        // ⚠️ 其它 dapp 一律**不设** —— 它们 `_blank` 链接「点了没反应」的既有行为保持不变。
        if isVoiceRoom || isOfficialSite {
            wv.uiDelegate = self
        }
        if isVoiceRoom {
            voiceRoomSupport.attach(to: wv, host: self)
            // 页面里点了「挂断」⇒ **真的结束通话**：销毁通话界面（页面也一起没，不留悬浮框）
            voiceRoomSupport.onCallEnded = {
                FZMLog("语音房：页面点了挂断，结束通话")
                VoiceRoomCallContainerVC.finish()
            }
            // 页面自报的顶栏高度 ⇒ 转给通话容器定位按钮
            voiceRoomSupport.onHeaderHeightMeasured = { [weak self] height in
                self?.onVoiceRoomHeaderHeightMeasured?(height)
            }
        }
        wv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wv)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3),

            wv.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        WKWebViewJavascriptBridge.enableLogging()
        /// ObjC `+bridgeForWebView:` 在新 Swift 中映射为 `init(for:)`。
        let jb = WKWebViewJavascriptBridge(for: wv)!
        jb.setWebViewDelegate(self)
        DAppWVJBLegacyHandlers.register(with: jb, host: self, originProvider: { [weak self] in
            // 主框架当前站点：`sign` / `signTxGroup` 的「按站点授权」用它做来源展示与去重。
            guard let self else { return nil }
            return self.webView?.url?.host ?? self.initialURL.host
        })
        wvjb = jb

        progressKVO = wv.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard !self.isProgressFinished else { return }
                self.progressView.alpha = 1
                let p = Float(webView.estimatedProgress)
                self.progressView.setProgress(p, animated: p > self.progressView.progress)
                if webView.estimatedProgress >= 1 {
                    self.finishProgressBar()
                } else if p >= 0.7 {
                    // 已过“主体加载”阶段，只剩零散子资源：若长时间不再变化就收尾
                    self.scheduleProgressStallWatchdog()
                }
            }
        }

        webView = wv

        titleKVO = wv.observe(\.title, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.applyExploreNavigationTitle(for: webView)
                // 站点真实标题回传（供「发现页」给搜索历史补默认显示名）
                if let pageTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !pageTitle.isEmpty {
                    self.onPageTitleChanged?(pageTitle)
                }
            }
        }

        wv.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            guard let self else { return }
            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let ua = "\(result ?? "")"
            let addStr = ";wallet;\(ver) AlphaWallet/\(ver) 1inchWallet"
            let newUA = ua + addStr
            UserDefaults.standard.register(defaults: ["UserAgent": newUA])
            self.webView?.customUserAgent = newUA
            self.wvjb?.setWebViewDelegate(self)
        }
    }

    /// 同步页内 `ethereum.chainId`，且**仅在链确实发生变化时**触发 `chainChanged`（DApp 内切链或回到前台后与 App 全局网络一致）。
    /// ⚠️ 不能无条件 emit：站点普遍把 `chainChanged` 当作「用户切网」处理，会清登录态并整页 reload
    /// （如 `bityuan.com/pool-detail`：`localStorage.removeItem("bityuan_token")` + `location.reload()`），
    /// 无条件 emit 会造成「进入即 reload → 重新自动连接 → 再弹签名」的死循环。
    private func reinjectChainId() {
        let hex = hexChainId(bridge.configurationSnapshot().chainID)
        let js = """
        (function(){
          var h='\(hex)';
          if(!window.ethereum)return;
          var changed=!!window.ethereum.chainId&&window.ethereum.chainId!==h;
          window.ethereum.chainId=h;
          if(changed){window.ethereum.emit&&window.ethereum.emit('chainChanged',h);}
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    /// 钱包桥只接受「主框架 + 同源」的调用。
    ///
    /// 背景：`window.webkit.messageHandlers` 在**所有 frame** 都可见；此前只校验 handler 名，
    /// 任意第三方 iframe（广告/统计/支付组件）都能借主站信誉发起签名/转账，而授权弹层
    /// 展示的是主框架 URL。这里把非主框架、跨域 frame 一律拒绝。
    private func isTrustedWalletMessage(_ message: WKScriptMessage) -> Bool {
        guard message.frameInfo.isMainFrame else { return false }
        let originHost = message.frameInfo.securityOrigin.host.lowercased()
        guard let pageHost = (webView?.url?.host ?? initialURL.host)?.lowercased(),
              !pageHost.isEmpty else { return false }
        return originHost == pageHost
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == messageHandlerName else { return }
        guard isTrustedWalletMessage(message) else {
            FZMLog("DApp 桥：拒绝非主框架/跨域请求 frame=\(message.frameInfo.isMainFrame) origin=\(message.frameInfo.securityOrigin.host)")
            return
        }
        let bodyString: String? = {
            switch message.body {
            case let s as String:
                return s
            case let s as NSString:
                return s as String
            case let d as [String: Any]:
                guard let data = try? JSONSerialization.data(withJSONObject: d, options: []) else { return nil }
                return String(data: data, encoding: .utf8)
            default:
                return nil
            }
        }()
        guard let bodyString,
              let data = bodyString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reqId = obj["reqId"] as? String,
              let method = obj["method"] as? String else {
            return
        }
        let params = Self.normalizedParams(obj["params"])

        let needsPassword = Self.needsPassword(for: method)
        if needsPassword {
            // 统一走弹层调度：同一时刻只展示一个授权弹层，其余请求排队，避免站点连发请求导致弹窗叠加/不停弹。
            Task { @MainActor [weak self] in
                self?.enqueueAuthRequest(reqId: reqId, method: method, params: params)
            }
        } else {
            Task { [weak self] in
                guard let self else { return }
                await self.finishRequest(reqId: reqId, method: method, params: params, password: nil)
            }
        }
    }

    private func finishRequest(reqId: String, method: String, params: [Any]?, password: String?) async {
        if method == "wallet_switchEthereumChain" || method == "wallet_addEthereumChain" {
            await handleWalletEthereumChain(reqId: reqId, params: params)
            return
        }
        if Self.needsPassword(for: method), password == nil || password?.isEmpty == true {
            await MainActor.run {
                self.respond(reqId: reqId, result: nil, error: DAppWeb3Error.invalidParams(L("需要钱包密码")))
            }
            return
        }
        do {
            let result = try await bridge.handleMethod(method: method, params: params, password: password)
            await MainActor.run {
                if let accounts = result as? [String], let first = accounts.first {
                    if method == "eth_requestAccounts" {
                        self.syncInjectedAccount(first, announceConnect: true)
                    } else if method == "eth_accounts" {
                        self.syncInjectedAccount(first, announceConnect: false)
                    }
                } else if method == "eth_coinbase", let single = result as? String, !single.isEmpty {
                    // 老式 dapp 以 `eth_coinbase` 作为连接入口，同样要回填 `selectedAddress`
                    // （该写法不会监听 `connect`，故 announceConnect 为 false，避免多余事件）。
                    self.syncInjectedAccount(single, announceConnect: false)
                }
                respond(reqId: reqId, result: result, error: nil)
            }
        } catch {
            await MainActor.run { respond(reqId: reqId, result: nil, error: error) }
        }
    }

    // MARK: - 页内账号同步（EIP-1193 事件语义）

    /// 同步页内 `ethereum.selectedAddress`。
    ///
    /// ⚠️ `accountsChanged` 只在账号**确实发生切换**时发送：
    /// 页面自己调用 `eth_requestAccounts` 时绝不能发 —— EIP-1193 里该事件的语义是「用户切换了账号」，
    /// 而站点普遍按此清登录态并整页 reload（`bityuan.com/pool-detail`：删 `bityuan_token` 后 `location.reload()`；
    /// reload 后站点按 `autoLink` 自动重连 → 再次收到 `accountsChanged` → 无限 reload + 反复弹「消息签名」）。
    /// 首次连接改为发送语义正确的 `connect`（该站点未监听 `connect`，不会触发 reload）。
    private func syncInjectedAccount(_ address: String, announceConnect: Bool) {
        guard !address.isEmpty else { return }
        let previous = injectedAddress
        injectedAddress = address
        let e = Self.jsEscaped(address)
        let changed = previous != nil && previous?.lowercased() != address.lowercased()
        var events = ""
        if changed {
            events = "window.ethereum.emit&&window.ethereum.emit('accountsChanged',['\(e)']);"
        } else if previous == nil, announceConnect {
            let chainHex = Self.jsEscaped(hexChainId(bridge.configurationSnapshot().chainID))
            events = "window.ethereum.emit&&window.ethereum.emit('connect',{chainId:'\(chainHex)'});"
        }
        let js = "if(window.ethereum){window.ethereum.selectedAddress='\(e)';\(events)}"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - 授权弹层调度（同一时刻只弹一个）

    /// EIP-1193 用户拒绝（4001）。
    private static var userRejectedError: NSError {
        NSError(domain: "DAppBrowser", code: 4001, userInfo: [NSLocalizedDescriptionKey: L("用户已取消")])
    }

    /// 同方法 + 同参数视为同一笔授权（站点重复发起的同一个签名请求）。
    private static func authRequestKey(method: String, params: [Any]?) -> String {
        var key = method + "|"
        if let params, let data = try? JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]) {
            key += String(data: data, encoding: .utf8) ?? ""
        }
        return key
    }

    /// 同一次授权可安全复用的方法（同参数的签名结果一致，且无链上副作用）。
    /// `eth_sendTransaction` 不在此列：复用会导致重复发送交易。
    /// `eth_sign` 也已被禁用（见 `case "eth_sign"`），不再参与复用。
    private static func isReusableSignatureMethod(_ method: String) -> Bool {
        method == "personal_sign"
    }

    /// 弹层入口：无弹层则立即弹出，已有弹层则排队。
    @MainActor
    private func enqueueAuthRequest(reqId: String, method: String, params: [Any]?) {
        let key = Self.authRequestKey(method: method, params: params)
        guard activeAuthKey == nil else {
            queuedAuthRequests.append((reqId: reqId, method: method, params: params, key: key))
            return
        }
        activeAuthKey = key
        promptWalletAuth(method: method, params: params) { [weak self] pwd, txOverrides in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let approved = (pwd?.isEmpty == false) ? pwd : nil
                if let approved {
                    let merged = Self.mergedEthSendParams(params, txOverrides)
                    await self.finishRequest(reqId: reqId, method: method, params: merged, password: approved)
                } else {
                    self.respond(reqId: reqId, result: nil, error: Self.userRejectedError)
                }
                self.drainQueuedAuthRequests(approvedKey: key, password: approved)
            }
        }
    }

    /// 弹层结束后的收尾：复用 / 排队 / 拒绝剩余请求。
    /// - 同 key 的签名类请求：复用本次密码直接回包（不再二次弹窗）；
    /// - 用户取消：一次性拒绝排队中的全部请求，避免站点连发导致弹窗不停；
    /// - 其余请求：串行弹下一个（始终只有一个弹层）。
    @MainActor
    private func drainQueuedAuthRequests(approvedKey: String, password: String?) {
        let queued = queuedAuthRequests
        queuedAuthRequests.removeAll()
        activeAuthKey = nil
        guard !queued.isEmpty else { return }

        guard let approved = password, !approved.isEmpty else {
            for item in queued {
                respond(reqId: item.reqId, result: nil, error: Self.userRejectedError)
            }
            return
        }

        var pending: [(reqId: String, method: String, params: [Any]?)] = []
        for item in queued {
            if item.key == approvedKey, Self.isReusableSignatureMethod(item.method) {
                Task { [weak self] in
                    guard let self else { return }
                    await self.finishRequest(reqId: item.reqId, method: item.method, params: item.params, password: approved)
                }
            } else {
                pending.append((reqId: item.reqId, method: item.method, params: item.params))
            }
        }

        guard let first = pending.first else { return }
        for item in pending.dropFirst() {
            queuedAuthRequests.append(
                (reqId: item.reqId, method: item.method, params: item.params,
                 key: Self.authRequestKey(method: item.method, params: item.params))
            )
        }
        enqueueAuthRequest(reqId: first.reqId, method: first.method, params: first.params)
    }

    /// 站点请求 `wallet_switchEthereumChain` / `wallet_addEthereumChain` 时，与 App 全局主链（`PWAppsettings`）对齐并持久化。
    @MainActor
    private func handleWalletEthereumChain(reqId: String, params: [Any]?) async {
        guard let chainIdHex = Self.chainIdHexFromWalletParams(params),
              let chainId = parseHexUInt(chainIdHex) else {
            respond(reqId: reqId, result: nil, error: DAppWeb3Error.invalidParams(L("无效的 chainId")))
            return
        }
        guard let targetNet = Self.appNetType(forChainID: chainId) else {
            respond(reqId: reqId, result: nil, error: DAppWeb3Error.invalidParams(L("仅支持 BTY / ETH / BNB 主网，请在 App 设置中切换主链后再试")))
            return
        }
        let currentNet = PWAppsettings.instance().getAPPNetType()
        if currentNet.rawValue == targetNet.rawValue {
            bridge.syncWithAppSettings()
            reinjectChainId()
            respond(reqId: reqId, result: nil, error: nil)
            return
        }
        let message = String(
            format: L("当前 App 主链为「%@」，站点请求「%@」。确认后将保存为 App 主链并与探索 Web 一致。"),
            Self.appNetworkDisplayName(for: currentNet),
            Self.appNetworkDisplayName(for: targetNet)
        )
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let alert = UIAlertController(title: L("切换主链"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("取消"), style: .cancel) { [weak self] _ in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.respond(reqId: reqId, result: nil, error: DAppWeb3Error.invalidParams(L("已取消切换网络")))
                continuation.resume()
            })
            alert.addAction(UIAlertAction(title: L("确认"), style: .default) { [weak self] _ in
                guard let self else {
                    continuation.resume()
                    return
                }
                PWAppsettings.instance().setAPPNetType(targetNet)
                self.bridge.syncWithAppSettings()
                self.reinjectChainId()
                self.showCustomMessage(L("已切换"), hideAfterDelay: 2)
                self.respond(reqId: reqId, result: nil, error: nil)
                continuation.resume()
            })
            present(alert, animated: true)
        }
    }

    private static func chainIdHexFromWalletParams(_ params: [Any]?) -> String? {
        guard let obj = params?.first as? [String: Any],
              let chainIdHex = obj["chainId"] as? String else { return nil }
        return chainIdHex
    }

    /// 与 `DAppBrowserConfiguration` / `WebViewController` 主链 ID 一致。
    private static func appNetType(forChainID id: BigUInt) -> NetType? {
        switch id {
        case BigUInt(2999): return NetType(rawValue: 0)
        case BigUInt(1): return NetType(rawValue: 1)
        case BigUInt(56): return NetType(rawValue: 2)
        default: return nil
        }
    }

    private static func appNetworkDisplayName(for net: NetType) -> String {
        switch net.rawValue {
        case 0: return L("BTY主网")
        case 1: return L("以太坊主网")
        case 2: return L("BNB Chain")
        default: return L("未知网络")
        }
    }

    private static func jsEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    @MainActor
    private func respond(reqId: String, result: Any? = nil, error: Error? = nil) {
        let payload: [String: Any]
        if let error = error {
            let ns = error as NSError
            var errPayload: [String: Any] = ["__error": true, "message": error.localizedDescription]
            if ns.code != 0 {
                errPayload["code"] = ns.code
            }
            payload = errPayload
        } else {
            payload = ["value": unwrapJSONSafe(result)]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              !data.isEmpty else {
            return
        }
        let b64 = data.base64EncodedString()
        let js = "window.__dappResolve && window.__dappResolve('\(Self.jsEscaped(reqId))', '\(b64)')"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    /// JSONSerialization 仅接受有限类型，去掉 Swift Optional 包装与弱类型
    private func unwrapJSONSafe(_ value: Any?) -> Any {
        switch value {
        case let v as String: return v
        case let v as Int: return v
        case let v as UInt: return v
        case let v as Bool: return v
        case let v as BigUInt: return "0x" + String(v, radix: 16)
        case let v as NSNumber: return v
        case let v as NSArray:
            return Array(v).map { unwrapJSONSafe($0) }
        case let v as [Any]:
            return v.map { unwrapJSONSafe($0) }
        case let v as [String: Any]:
            return v.mapValues { unwrapJSONSafe($0) }
        case let v as NSDictionary:
            var out: [String: Any] = [:]
            v.enumerateKeysAndObjects { k, o, _ in
                if let ks = k as? String { out[ks] = unwrapJSONSafe(o) }
            }
            return out
        case is NSNull:
            return NSNull()
        case nil:
            return NSNull()
        default:
            return String(describing: value as Any)
        }
    }

    /// 底部授权说明 + 密码（对齐 ObjC `DappAlertSheetView` 的信息密度）。`txOverrides` 仅 `eth_sendTransaction` 可能非空（用户调整矿工费）。
    @MainActor
    private func promptWalletAuth(method: String, params: [Any]?, completion: @escaping (String?, [String: Any]?) -> Void) {
        let pageURL = webView?.url?.absoluteString ?? ""
        let wallet = bridge.walletAddressString() ?? ""
        let chainHex = hexChainId(bridge.configurationSnapshot().chainID)
        let chainSymbol = Self.chainSymbolForDisplay()

        if method == "eth_sendTransaction", let dict = params?.first as? [String: Any] {
            Task { [weak self] in
                guard let self else { return }
                let preview: DAppEthSendFeePreview?
                do {
                    preview = try await bridge.previewEthSendFee(dict: dict)
                } catch {
                    preview = nil
                }
                let payload = DappAuthSheetPayload.build(
                    method: method,
                    params: params,
                    pageURL: pageURL.isEmpty ? L("—") : pageURL,
                    walletAddress: wallet,
                    chainIdHex: chainHex,
                    feePreview: preview
                )
                await MainActor.run {
                    let sheet = DappAuthSheetView(
                        payload: payload,
                        method: method,
                        pageURL: pageURL.isEmpty ? L("—") : pageURL,
                        walletAddress: wallet,
                        chainIdHex: chainHex,
                        ethSendParams: params,
                        initialFeePreview: preview,
                        chainSymbol: chainSymbol,
                        fetchFeePreview: { [weak self] updated in
                            guard let self else { throw CancellationError() }
                            return try await self.bridge.previewEthSendFee(dict: updated)
                        },
                        completion: completion
                    )
                    sheet.present(on: self.view, hostController: self)
                }
            }
        } else {
            let payload = DappAuthSheetPayload.build(
                method: method,
                params: params,
                pageURL: pageURL.isEmpty ? L("—") : pageURL,
                walletAddress: wallet,
                chainIdHex: chainHex,
                feePreview: nil
            )
            let sheet = DappAuthSheetView(
                payload: payload,
                method: method,
                pageURL: pageURL.isEmpty ? L("—") : pageURL,
                walletAddress: wallet,
                chainIdHex: chainHex,
                ethSendParams: nil,
                initialFeePreview: nil,
                chainSymbol: chainSymbol,
                fetchFeePreview: nil,
                completion: completion
            )
            sheet.present(on: view, hostController: self)
        }
    }

    private static func chainSymbolForDisplay() -> String {
        switch PWAppsettings.instance().getAPPNetType().rawValue {
        case 0: return "BTY"
        case 1: return "ETH"
        case 2: return "BNB"
        default: return "ETH"
        }
    }

    private static func mergedEthSendParams(_ original: [Any]?, _ overrides: [String: Any]?) -> [Any]? {
        guard let overrides, !overrides.isEmpty else { return original }
        guard var first = original?.first as? [String: Any] else { return original }
        for (k, v) in overrides {
            first[k] = v
        }
        return [first]
    }

    /// WKWebView 里 `params` 可能是 `NSArray`，直接 `as? [Any]` 会失败。
    private static func normalizedParams(_ raw: Any?) -> [Any]? {
        if let a = raw as? [Any] { return a }
        if let a = raw as? NSArray { return Array(a) }
        return nil
    }

    private static func needsPassword(for method: String) -> Bool {
        switch method {
        case "personal_sign", "eth_sign", "eth_sendTransaction",
             "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
            return true
        default:
            return false
        }
    }

    // MARK: - 顶部进度条

    /// 进度条收尾：补满 → 淡出 → 归零。
    /// ⚠️ 不能只等 `estimatedProgress >= 1`：
    /// 站点有子资源超时/挂起时（如 `bityuan.com/pool-detail` 会去请求 `telegram.org` 的
    /// telegram-widget.js、并连 walletconnect websocket），WKWebView 的进度会一直停在 0.8，
    /// 表现为「加载完了但进度条卡在五分之四不走」。
    private func finishProgressBar() {
        progressStallWorkItem?.cancel()
        progressStallWorkItem = nil
        guard !isProgressFinished else { return }
        isProgressFinished = true
        guard progressView.alpha > 0 else {
            progressView.progress = 0
            return
        }
        progressView.setProgress(1, animated: true)
        UIView.animate(withDuration: 0.25, delay: 0.12, options: .curveEaseOut) {
            self.progressView.alpha = 0
        } completion: { _ in
            self.progressView.progress = 0
        }
    }

    /// 进度长时间不动（子资源卡住）时也把进度条收掉，超时后若有新进度会重新出现。
    private func scheduleProgressStallWatchdog() {
        progressStallWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.finishProgressBar() }
        }
        progressStallWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    // MARK: - WKNavigationDelegate（由 `WKWebViewJavascriptBridge` 转发）

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 新导航开始：复位收尾标记，允许进度条重新显示
        progressStallWorkItem?.cancel()
        progressStallWorkItem = nil
        isProgressFinished = false
        // 语音房：每开始一次新导航都重新起表
        startVoiceRoomLoadWatchdog()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyExploreNavigationTitle(for: webView)
        finishProgressBar()
        // 语音房：替用户点一次页面自己的「登录获取钱包地址」（页面挂载时不会自动取）
        if isVoiceRoom { voiceRoomSupport.didFinish(in: webView) }
        cancelVoiceRoomLoadWatchdog()
        reportVoiceRoomLoadFailure(false)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishProgressBar()
        // 「被取消 / 被新导航顶掉」不算失败，也不要动状态（新导航会重新起表）
        guard !Self.isBenignNavigationError(error) else { return }
        cancelVoiceRoomLoadWatchdog()
        reportVoiceRoomLoadFailure(true)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishProgressBar()
        guard !Self.isBenignNavigationError(error) else { return }
        cancelVoiceRoomLoadWatchdog()
        reportVoiceRoomLoadFailure(true)
    }

    /// 语音房加载看门狗：超时就**先**按加载失败处理（顶部按钮变「返回」），不等系统 60 秒超时。
    private func startVoiceRoomLoadWatchdog() {
        guard isVoiceRoom else { return }
        cancelVoiceRoomLoadWatchdog()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            FZMLog("语音房：\(Int(Self.voiceRoomLoadTimeout)) 秒仍未加载完成，先按加载失败处理")
            self.reportVoiceRoomLoadFailure(true)
        }
        voiceRoomLoadWatchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.voiceRoomLoadTimeout, execute: item)
    }

    private func cancelVoiceRoomLoadWatchdog() {
        voiceRoomLoadWatchdog?.cancel()
        voiceRoomLoadWatchdog = nil
    }

    /// 「被自己取消 / 被新导航顶掉」不算加载失败。
    /// ⚠️ 不滤掉的话「返回」按钮会乱闪：我们在 `decidePolicyFor` 里会主动 `.cancel`，
    ///    页面内部重定向、以及被下一次导航打断，都会走 `didFail*`。
    private static func isBenignNavigationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return true }
        // WebKitErrorDomain 102 = Frame load interrupted
        if nsError.domain == "WebKitErrorDomain", nsError.code == 102 { return true }
        return false
    }

    /// 上报语音房页面加载状态（只在真的变化时回调）
    private func reportVoiceRoomLoadFailure(_ failed: Bool) {
        guard isVoiceRoom, isVoiceRoomLoadFailed != failed else { return }
        isVoiceRoomLoadFailed = failed
        FZMLog("语音房：页面加载\(failed ? "失败" : "成功")")
        onVoiceRoomLoadFailureChanged?(failed)
    }

    /// 语音房链接分流：**另开一个语音房专用的 DApp 浏览器**来加载它。
    ///
    /// 为何不就地加载：媒体能力（`allowsInlineMediaPlayback` / `WKUIDelegate` 授权 /
    /// `window.H5Wallet` 地址桥）是在 `setupWebView()` 里按 `initialURL` **一次性配好**的，
    /// 页内跳转已经晚于配置时机 ⇒ 就地加载拿不到麦克风。新开一个则重新走一遍配置。
    ///
    /// ⚠️ 两个必须注意的点：
    ///  1. `WKWebViewJavascriptBridge` **只在 delegate 不响应时**才自己调 `decisionHandler(.allow)`
    ///     （`Pods/WebViewJavascriptBridge/WebViewJavascriptBridge/WKWebViewJavascriptBridge.m:153-159`）
    ///     ⇒ 一旦实现这个方法，就**必须恰好调用一次** decisionHandler，否则导航会卡死。
    ///  2. 其余链接**原样 `.allow`**（只有语音房链接、以及 bityuan 官网客服弹框的新窗口请求会 `cancel`）。
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 只允许 http/https 在 WebView 内导航；`file:` / `data:` / `javascript:` /
        // 自定义 scheme 一律拒绝，避免页面借 WebView 读取本地文件或唤起其它 App。
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           scheme != "https" && scheme != "http" {
            FZMLog("DApp 浏览器：拒绝非 http(s) 导航 scheme=\(scheme)")
            decisionHandler(.cancel)
            return
        }
        // 新窗口请求（`window.open` / `target="_blank"`）会先过这里：官网客服弹框在这一步就拦下来
        // （`cancel` 之后 WebKit 不再调 `createWebViewWith`；万一只走那一条也有同一处去重兜底）。
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url,
           handleOfficialCustomerService(url) {
            decisionHandler(.cancel)
            return
        }
        // `!isVoiceRoom`：本页已经是语音房浏览器时，页内跳转就地完成，不再重复新开
        if let url = navigationAction.request.url,
           !isVoiceRoom,
           VoiceRoomLauncher.isVoiceRoomLink(url) {
            FZMLog("DApp 浏览器：命中语音房链接，另开语音房浏览器 \(url.absoluteString)")
            decisionHandler(.cancel)
            VoiceRoomLauncher.open(url: url, from: self)
            return
        }
        decisionHandler(.allow)
    }

    /// EIP-1193 + EIP-6963 注入（Uniswap 等依赖多钱包发现；勿仅用 rAF 兑现 Promise，参见 `provider.js` 注释）。
    private static func injectedProviderJS(chainIdHex: String) -> String {
        """
        (function(){
          if (window.ethereum) return;
          var pending = {};
          var listeners = {};
          function emit(ev, arg) {
            (listeners[ev]||[]).forEach(function(fn){ try { fn(arg); } catch(e) {} });
          }
          function runSoon(fn) {
            if (typeof queueMicrotask === 'function') { queueMicrotask(fn); }
            else { setTimeout(fn, 0); }
          }
          var EIP6963_INFO = Object.freeze({
            uuid: '8f7e6d5c-4b3a-2918-efdc-ba0987654321',
            name: 'Tanxin Wallet',
            icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="16" cy="16" r="16" fill="%234891ff"/></svg>',
            rdns: 'com.tanxin.wallet'
          });
          function announceEip6963() {
            if (!window.ethereum) return;
            try {
              window.dispatchEvent(new CustomEvent('eip6963:announceProvider', {
                detail: Object.freeze({ info: EIP6963_INFO, provider: window.ethereum })
              }));
            } catch (e) {}
          }
          window.__dapp6963Announce = announceEip6963;
          window.__dappResolve = function(id, b64) {
            var p = pending[id];
            if (!p) return;
            delete pending[id];
            try {
              var bin = atob(b64);
              var i, u8 = new Uint8Array(bin.length);
              for (i = 0; i < bin.length; i++) { u8[i] = bin.charCodeAt(i); }
              var jsonStr = (typeof TextDecoder !== 'undefined')
                ? new TextDecoder('utf-8').decode(u8)
                : decodeURIComponent(escape(bin));
              var o = JSON.parse(jsonStr);
              runSoon(function() {
                try {
                  if (o.__error) {
                    var err = new Error(o.message||'error');
                    if (typeof o.code === 'number') err.code = o.code;
                    p.reject(err);
                  } else {
                    p.resolve(o.value);
                  }
                } catch (e) { p.reject(e); }
              });
            } catch (e) { runSoon(function(){ p.reject(e); }); }
          };
          var eth = {
            isMetaMask: true,
            chainId: '\(chainIdHex)',
            selectedAddress: null,
            providers: null,
            request: function(args) {
              return new Promise(function(resolve, reject) {
                var id = String(Date.now()) + Math.random();
                pending[id] = { resolve: resolve, reject: reject };
                window.webkit.messageHandlers.dappBrowserBridge.postMessage(JSON.stringify({
                  reqId: id,
                  method: args.method,
                  params: args.params || []
                }));
              });
            },
            on: function(ev, fn) {
              if (!listeners[ev]) listeners[ev] = [];
              listeners[ev].push(fn);
            },
            removeListener: function(ev, fn) {
              var arr = listeners[ev];
              if (!arr) return;
              var i = arr.indexOf(fn);
              if (i >= 0) arr.splice(i, 1);
            },
            emit: emit,
            enable: function() { return eth.request({ method: 'eth_requestAccounts' }); },
            isConnected: function() {
              return Promise.resolve(!!(eth.selectedAddress && eth.selectedAddress.length));
            },
            sendAsync: function(payload, callback) {
              if (!payload || !payload.method) {
                if (callback) callback({ code: -32602, message: 'Invalid payload' }, null);
                return;
              }
              eth.request({ method: payload.method, params: payload.params || [] })
                .then(function(result) {
                  if (callback) callback(null, { jsonrpc: '2.0', id: payload.id, result: result });
                })
                .catch(function(err) {
                  if (callback) callback(err, null);
                });
            },
            send: function(payload, callback) { eth.sendAsync(payload, callback); }
          };
          eth.providers = [eth];
          window.ethereum = eth;
          window.addEventListener('eip6963:requestProvider', announceEip6963);
          window.dispatchEvent(new Event('ethereum#initialized'));
          announceEip6963();
          setTimeout(announceEip6963, 0);
          setTimeout(announceEip6963, 300);
        })();
        """
    }
}

// MARK: - 语音房：媒体授权 / 自签证书
//
// ⚠️ 这些代理只在 `isVoiceRoom` 时才生效（`uiDelegate` 也只给语音房设），
//    普通 dapp 的导航与链接行为完全不变。

extension DAppBrowserViewController {

    /// 页面调 `getUserMedia` 时系统会先问宿主 —— 不实现这个方法，iOS 15+ 上直接拒绝。
    public func webView(_ webView: WKWebView,
                        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                        initiatedByFrame frame: WKFrameInfo,
                        type: WKMediaCaptureType,
                        decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard isVoiceRoom else {
            decisionHandler(.deny)
            return
        }
        voiceRoomSupport.handleMediaCapturePermission(type: type, decisionHandler: decisionHandler)
    }

    /// `target="_blank"` / `window.open(...)`：**不新开窗口**。
    ///  · bityuan 官网客服弹框 → 转 App 原生页面（`handleOfficialCustomerService`）；
    ///  · 语音房 → 就地在本 WebView 里加载（既有行为，不实现的话这类链接点了没反应）；
    ///  · 其它 → 什么都不做（与未设 `uiDelegate` 时一致）。
    public func webView(_ webView: WKWebView,
                        createWebViewWith configuration: WKWebViewConfiguration,
                        for navigationAction: WKNavigationAction,
                        windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if handleOfficialCustomerService(url) { return nil }
            if isVoiceRoom {
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    /// bityuan 官网客服弹框的两个按钮 —— **站点侧没有桥接**，只能按 URL 自己认：
    ///  · 联系客服 → `https://web3chat.cc/download.html?address=<客服地址>`（客服地址就在 `address` 参数里）；
    ///  · 智能客服 → `https://aikf.bityuan.com/`（与 App 内 AI 客服是同一套 H5）。
    /// - Returns: true 表示已用 App 原生页面接管，调用方不要再加载该 URL。
    private func handleOfficialCustomerService(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        let isAICustomer = (host == "aikf.bityuan.com")
        // 「联系客服」的链接只在 bityuan 官网页面里认（用户要求「针对 bityuan.com」）
        let contactAddress = (isOfficialSite && (host == "web3chat.cc" || host == "www.web3chat.cc"))
            ? Self.queryValue("address", in: url)
            : nil
        guard isAICustomer || contactAddress != nil else { return false }

        // 去重：同一次 `window.open` 可能被下面两条回调各调一次
        let key = url.absoluteString
        let now = CACurrentMediaTime()
        if lastHandledCustomerServiceURL == key, now - lastHandledCustomerServiceAt < 1 {
            return true
        }
        lastHandledCustomerServiceURL = key
        lastHandledCustomerServiceAt = now

        if isAICustomer {
            FZMLog("DApp 浏览器：命中官网「智能客服」，转 App 内 AI 客服 \(key)")
            AICustomerLauncher.push(from: self)
        } else if let address = contactAddress {
            FZMLog("DApp 浏览器：命中官网「联系客服」，跳加好友页 address=\(address)")
            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: address, source: .sweep))
        }
        return true
    }

    /// 取 URL 查询参数（trim 后为空视为不存在）。
    private static func queryValue(_ name: String, in url: URL) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let value = items.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// 自签证书放行：**只对配置的语音房 host**，其它 host 一律走系统默认校验。
    /// 这条回调由 `WKWebViewJavascriptBridge` 转发（其 `.m:129`）。
    public func webView(_ webView: WKWebView,
                        didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        voiceRoomSupport.handleChallenge(challenge, completionHandler: completionHandler)
    }
}
