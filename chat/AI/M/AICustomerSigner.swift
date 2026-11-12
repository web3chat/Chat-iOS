//
//  AICustomerSigner.swift
//  chat
//
//  AI 客服免登录：**私钥来自当前钱包账户，与「开红包」共用同一份内存缓存**。
//
//  ① 私钥：`WalletPrivateKeyStore`（首次用到时弹**一次**密码 → `GoFunction.deckey` 解助记词
//          → `goCreateHDWallet("ETH")` → `newKeyPriv(0)`；小钱包直接取私钥），
//          之后本次启动内复用内存里的私钥，**不再弹密码**（AI 客服 / 红包共用）。
//  ② 签名：上面这把 0x 私钥对 SIWE 原文做 EIP-191（personal_sign）。
//  ③ 地址：提交给客服的地址 = **当前钱包的 eth 地址**（`RedPacketWalletDataSource`）；
//          私钥必须与它同源（`matchesAddress`），否则服务端报 `401 签名账号与请求地址不匹配`。
//
//  ⚠️ 早期版本用 `LoginUser.seed`（登录后常驻内存的**明文**助记词）直接派生私钥、绕开密码 ——
//     已废弃：私钥必须由用户在**钱包密码**保护下取出。
//
//  ⚠️ **不能用 go 包的 `WalletapiBtyAddrToEthAddr` 当 EVM 地址**（真机已验证不一致）：
//     它只是把 BTY 地址里的 20 字节重新编码成 `0x…`，而 BTY 的 20 字节来自 `ripemd160(sha256(pub))`，
//     与 EVM 的 `keccak256(pub)[12:]` 不是同一段数据。
//
//  对接文档 §2 / §3 —— 详见 chat/AI/README_TanxinAICustomerService.md
//

import Foundation
import CryptoSwift
import Web3Core

enum AICustomerSigner {

    // MARK: - 地址（提交地址 = 当前钱包 eth 地址）

    /// ★ 提交给 AI 客服的地址：**当前钱包的 EVM 地址（`0x` + 40 位 hex）**。
    ///
    /// 对接文档 §4.1：本方法必须是**纯本地**操作（不发 HTTP、**不弹密码**、不触发登录）。
    ///
    /// 🔴 为什么不能直接用 `getCurrentWalletAddress()`：
    ///    对接文档 §2.1 明确要求 `address` 是 **`0x` + 40 位 hex 的 EVM 地址**
    ///    （Chain33 的 `1…` / `3…` 地址会让同一个人在网页端落到另一个账号）。
    ///    而**新注册账号**的 `LoginUser.ethAddr` 可能是 Chain33 地址 —— 登录流程里
    ///    「没有地址则上传地址」取的是**币列表第一条**的 `coin_address`，那条可能是 BTY/BTY 的 `1…`。
    ///    原来这里 `guard count == 42 && hasPrefix("0x")` 直接返回 nil ⇒
    ///    `getAuth()` 抛 `walletAddressUnavailable` ⇒ 页面退回自己的登录页（"连接钱包"），
    ///    而 App 刻意不注入 `window.ethereum` ⇒ 新账号**永远卡在链接钱包**，连密码框都弹不出来
    ///    （用户 2026-11-04 反馈）。
    ///    ⇒ 现在按「ethAddr（0x 才认）→ 钱包库里的 ETH/BTY-EVM 地址 → 私钥缓存地址」依次兜底。
    static func currentAddress() -> String? {
        // ① 优先用「当前登录账号绑定的钱包」——切换账号后不能再用全局 ethAddr/选中钱包，
        //    那两个值在切账号瞬间可能还是上一个账号的（LoginUser.refreshUserInfo 的竞态）。
        if let wallet = currentAccountWallet() {
            if let address = evmAddress(from: wallet) {
                return address
            }
            // 账号钱包已经存在，但 EVM 币还没补进来：先不返回地址，
            // 避免回退到上一个账号的 ethAddr/选中钱包而连错账号。
            FZMLog("AI 客服：当前账号钱包尚未生成 EVM 币地址，暂不返回地址")
            return nil
        }

        // ② 账号钱包还没建好（刚切账号、PreCoin 尚未完成）：退回原有兜底逻辑。
        if let address = evmAddress(fromRawAddress: RedPacketWalletDataSource.shared.getCurrentWalletAddress()) {
            return address
        }
        if let address = preferredEVMCoinAddress() {
            FZMLog("AI 客服：当前账号 ethAddr 不是 EVM 地址，改用钱包库里的 0x 地址 \(maskedAddress(address))")
            return address
        }
        if let address = evmAddress(fromRawAddress: WalletPrivateKeyStore.shared.currentAddress) {
            return address
        }
        return nil
    }

    /// 当前登录账号绑定的钱包。
    ///
    /// 优先按 `encryptedSeed` 反查（钱包一创建就能找到，不依赖币是否已补完），
    /// 再按登录地址反查。
    private static func currentAccountWallet() -> LocalWallet? {
        let encryptedSeed = LoginUser.shared().encryptedSeed
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !encryptedSeed.isEmpty,
           let wallet = PWDataBaseManager.shared().queryWallet(byRememberCode: encryptedSeed) {
            return wallet
        }

        let account = LoginUser.shared().address
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !account.isEmpty,
           let wallet = PWDataBaseManager.shared().queryWallet(byCoinAddress: account) {
            return wallet
        }
        return nil
    }

    /// 是否是文档要求的 EVM 地址（`0x` + 40 位 hex），是则返回小写规范化形式，否则 nil。
    static func evmAddress(fromRawAddress raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let lower = trimmed.lowercased()
        let body = lower.hasPrefix("0x") ? String(lower.dropFirst(2)) : lower
        guard body.count == 40, body.allSatisfy({ $0.isHexDigit }) else { return nil }
        return "0x" + body
    }

    /// 从指定钱包的币列表里挑一个 EVM 地址。
    ///
    /// 顺序与 DApp 浏览器一致（`GameGoFunction.queryAddressByChain`）：
    /// ETH 主网币 → BTY 主网的 EVM 地址（`coin_type=BTY` + `coin_chain=ETH`）→ 任意 `coin_chain=ETH` → 任意 0x 币。
    private static func evmAddress(from wallet: LocalWallet) -> String? {
        guard let coins = PWDataBaseManager.shared().queryCoinArrayBased(on: wallet) as? [LocalCoin] else {
            return nil
        }
        return evmAddress(from: coins)
    }

    /// 从当前选中钱包的币列表里挑一个 EVM 地址（账号钱包未就绪时的兜底）。
    private static func preferredEVMCoinAddress() -> String? {
        let coins = (PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID() as? [LocalCoin]) ?? []
        return evmAddress(from: coins)
    }

    private static func evmAddress(from coins: [LocalCoin]) -> String? {
        guard !coins.isEmpty else { return nil }
        func type(_ coin: LocalCoin) -> String { (coin.coin_type ?? "").uppercased() }
        func chain(_ coin: LocalCoin) -> String { (coin.coin_chain ?? "").uppercased() }

        let predicates: [(LocalCoin) -> Bool] = [
            { type($0) == "ETH" && chain($0) == "ETH" },
            { type($0) == "BTY" && chain($0) == "ETH" },
            { chain($0) == "ETH" },
            { _ in true }
        ]
        for predicate in predicates {
            if let coin = coins.first(where: predicate),
               let address = evmAddress(fromRawAddress: coin.coin_address) {
                return address
            }
        }
        return nil
    }

    /// 由 0x 私钥推导**标准 EVM 地址**。
    ///
    /// 步骤：`privateKey` → secp256k1 未压缩公钥（65 字节 `0x04 ‖ X ‖ Y`）→
    /// 丢掉首字节后做 keccak256 → 取后 20 字节。
    static func evmAddress(fromPrivateKey privateKey: Data) -> String? {
        guard !privateKey.isEmpty else { return nil }
        guard let publicKey = SECP256K1.privateToPublic(privateKey: privateKey, compressed: false) else { return nil }
        // 未压缩公钥：65 字节 = 0x04 ‖ X(32) ‖ Y(32)；兼容已去掉前缀的 64 字节，其余长度直接失败
        let body: Data
        switch publicKey.count {
        case 65: body = Data(publicKey.dropFirst())
        case 64: body = publicKey
        default: return nil
        }
        let hash = body.sha3(.keccak256)
        return "0x" + Data(hash.suffix(20)).toHexString()
    }

    /// 私钥与地址**是否同源**（不同源则签名必然被服务端拒，提前卡住以免浪费一次登录配额）
    static func matchesAddress(privateKey: Data, address: String) -> Bool {
        guard !address.isEmpty, let derived = evmAddress(fromPrivateKey: privateKey) else { return false }
        return derived.lowercased() == address.lowercased()
    }

    /// 只接受客服站点的 EIP-4361（SIWE）登录原文。
    ///
    /// `personal_sign` 可以对任意文本签名；若服务端/中间人返回一段伪造原文，
    /// 用户就会在不知情的情况下签下攻击者构造的内容。这里校验 domain 与 address，
    /// 把签名范围收敛到「登录」这一种用途。
    static func isValidSIWE(_ message: String, address: String) -> Bool {
        guard !address.isEmpty,
              let configured = AICustomerConfig.siteURL.host?.lowercased(),
              !configured.isEmpty else { return false }
        let lower = message.lowercased()
        let domains = [configured, "bityuan.com", "www.bityuan.com"]
        let matched = domains.contains { domain in
            lower.hasPrefix("\(domain) wants you to sign in with your ethereum account:")
                || lower.contains("domain: \(domain)")
        }
        guard matched else { return false }
        return lower.contains(address.lowercased())
    }

    // MARK: - EIP-191 静默签名

    /// 对原文**一字不改**地做 EIP-191（`personal_sign`）签名，返回 `0x` + 130 位 hex（`r‖s‖v`，`v ∈ {27,28}`）。
    ///
    /// - Parameter privateKey: 32 字节 0x 私钥；由调用方通过 `WalletPrivateKeyStore` 取得
    ///   （首次弹一次密码，之后本次启动内命中内存缓存）。**本方法自己不弹任何框**。
    /// - Note: 全程静默：不弹密码框、不弹确认框（对接文档 §3.2）；不做任何重试，失败由调用方决定降级
    static func signPersonalMessage(_ message: String, privateKey: Data) throws -> String {
        guard !message.isEmpty else {
            throw AICustomerServiceError.network(L("签名原文为空"))
        }
        guard !privateKey.isEmpty else {
            throw AICustomerServiceError.keyUnavailable
        }
        let privateKeyHex = WalletapiBytes2Hex(privateKey)
        guard !privateKeyHex.isEmpty,
              let signature = MessageSigner.shared.signPersonalMessage(message: message, privateKey: privateKeyHex),
              !signature.isBlank else {
            throw AICustomerServiceError.keyUnavailable
        }
        // MessageSigner 返回的是裸 hex（不带 0x 前缀）
        return signature.lowercased().hasPrefix("0x") ? signature : ("0x" + signature)
    }

    /// 联调日志：地址来源、**私钥状态**与**同源校验**（不含私钥 / 签名 / token）。
    ///
    /// 只读缓存，**不会弹密码框**。
    static func addressChainDescription() -> String {
        let wallet = RedPacketWalletDataSource.shared.getCurrentWalletAddress() ?? "（无）"
        let submitted = currentAddress() ?? "（无）"
        let keyState: String
        if let key = WalletPrivateKeyStore.shared.cachedPrivateKey() {
            keyState = matchesAddress(privateKey: key, address: submitted)
                ? "已缓存（与地址同源）"
                : "已缓存（⚠️与地址不同源，服务端会报 401）"
        } else {
            keyState = "未就绪（用到时会过一次面容/指纹或输一次密码）"
        }
        return "钱包ethAddr=\(wallet)"
            + "；提交address=\(submitted)"
            + "；私钥=\(keyState)"
            + "；私钥来源=WalletPrivateKeyStore（内存缓存，与红包共用）"
    }

    /// 日志脱敏：地址只留前 6 后 4
    static func maskedAddress(_ address: String) -> String {
        guard !address.isEmpty else { return "空" }
        guard address.count > 12 else { return "非空(短)" }
        return String(address.prefix(6)) + "…" + String(address.suffix(4))
    }

    /// 日志脱敏：签名只留前 10 后 8（对接文档 §8-8：不把完整签名打进日志）
    static func maskedSignature(_ signature: String) -> String {
        guard !signature.isEmpty else { return "空" }
        guard signature.count > 30 else { return "非空(短)" }
        return String(signature.prefix(10)) + "…" + String(signature.suffix(8)) + "（共\(signature.count)位）"
    }
}
