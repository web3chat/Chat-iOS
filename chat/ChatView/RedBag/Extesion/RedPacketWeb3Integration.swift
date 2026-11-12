//
//  RedPacketWeb3Integration.swift
//  chat
//
//  RedPacketUpgradeable web3swift integration.
//

import Foundation
import UIKit
import BigInt
import SwiftyJSON
import web3swift
import Web3Core

private let redPacketZeroAddress = "0x0000000000000000000000000000000000000000"

/// 42 位 `0x…` 更像合约地址而不是币种名：记录页 / 旧缓存可能把地址当 `coinName` 传进来。
private func redPacketLooksLikeContractAddress(_ text: String) -> Bool {
    let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return s.count == 42 && s.lowercased().hasPrefix("0x")
}

/// 将任意值递归展开为 `JSONSerialization` 合法对象，避免 Optional/nil 经 `[String: Any]` 桥接到 `NSDictionary` 时在系统内部触发崩溃。
private enum RedPacketJSONSerializationHelper {
    static func unwrapAny(_ value: Any) -> Any? {
        var current: Any = value
        while true {
            let mirror = Mirror(reflecting: current)
            guard mirror.displayStyle == .optional else { return current }
            guard let first = mirror.children.first else { return nil }
            current = first.value
        }
    }

    static func jsonSafe(_ value: Any) -> Any {
        guard let concrete = unwrapAny(value) else {
            return NSNull()
        }
        switch concrete {
        case is NSNull:
            return NSNull()
        case let s as String:
            return s
        case let n as NSNumber:
            return n
        case let b as Bool:
            return b
        case let i as Int:
            return i
        case let u as UInt:
            return NSNumber(value: u)
        case let i64 as Int64:
            return NSNumber(value: i64)
        case let u64 as UInt64:
            return NSNumber(value: u64)
        case let f as Float:
            return NSNumber(value: f)
        case let d as Double:
            return NSNumber(value: d)
        case let big as BigUInt:
            return String(big)
        case let d as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in d {
                let j = jsonSafe(v)
                if j is NSNull { continue }
                out[k] = j
            }
            return out
        case let a as [Any]:
            return a.map { jsonSafe($0) }
        default:
            return String(describing: concrete)
        }
    }
}

enum RedPacketWeb3Error: LocalizedError {
    case invalidConfig(String)
    case invalidParameter(String)
    case walletUnavailable
    case passwordInvalid
    case privateKeyUnavailable
    case walletAddressMismatch(expected: String, actual: String)
    case contractDecodeFailed
    case transactionFailed
    case transactionReverted(String)
    case receiptTimeout
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidConfig(let message), .invalidParameter(let message):
            return message
        case .walletUnavailable:
            return L("未找到当前钱包")
        case .passwordInvalid:
            return L("密码错误")
        case .privateKeyUnavailable:
            return L("无法获取钱包私钥")
        case .walletAddressMismatch(let expected, let actual):
            return L("当前钱包地址与私钥不匹配：") + "\(expected) / \(actual)"
        case .contractDecodeFailed:
            return L("合约返回解析失败")
        case .transactionFailed:
            return L("交易执行失败")
        case .transactionReverted(let message):
            return message
        case .receiptTimeout:
            return L("交易已提交，等待链上确认超时")
        case .underlying(let error):
            return RedPacketWeb3Error.friendlyNodeMessage(error.localizedDescription)
        }
    }

    /// 节点/网关侧错误 → 用户可读文案；无法识别时返回原始报文。
    /// BTY 网关在自身未同步时会拒绝广播并返回 `ErrNotSync`，需翻译成人话。
    static func friendlyNodeMessage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("errnotsync") || lower.contains("not sync") {
            return L("链上节点同步中，暂时无法提交交易，请稍后重试")
        }
        if lower.contains("chainid no support") {
            return L("链上节点不支持当前网络")
        }
        if lower.contains("insufficient funds") {
            return L("余额不足，无法支付矿工费")
        }
        return raw
    }
}

struct RedPacketWeb3Config {
    let contractAddress: String
    let rpcURL: URL
    let chainID: BigUInt
    let nativeSymbol: String

    static func current() throws -> RedPacketWeb3Config {
        // ⚠️ 安全整改（2026-11-06）：合约地址 / RPC / chainID / 符号**不再读 UserDefaults**。
        //
        // 原因：这些键可被「备份注入 / 越狱插件 / 本机篡改」改写，之后用户发红包的
        // value / approve 会全部进入攻击者合约，而界面仍显示「发送成功」。
        // 现在只认 App 包内的 Info.plist（随签名校验），并在代码里做兜底。
        let info = Bundle.main.infoDictionary
        let contract = ((info?["RedPacketContractAddress"] as? String) ?? "0xCb75aE299c7C3C16DE9EB045e0A70406c78cf393")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard EthereumAddress(contract, ignoreChecksum: true) != nil, contract != redPacketZeroAddress else {
            throw RedPacketWeb3Error.invalidConfig(L("请先配置红包合约地址 RedPacketContractAddress"))
        }

        let rpc = ((info?["RedPacketRPCURL"] as? String) ?? "https://mainnet.bityuan.com/eth")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rpcURL = URL(string: rpc), rpcURL.scheme?.lowercased() == "https" else {
            throw RedPacketWeb3Error.invalidConfig(L("红包 RPC 地址无效"))
        }

        let chain = (info?["RedPacketChainID"] as? Int) ?? 2999
        let nativeSymbol = ((info?["RedPacketNativeSymbol"] as? String) ?? "BTY")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return RedPacketWeb3Config(
            contractAddress: contract,
            rpcURL: rpcURL,
            chainID: BigUInt(chain > 0 ? chain : 2999),
            nativeSymbol: nativeSymbol.isEmpty ? "BTY" : nativeSymbol
        )
    }
}

enum RedPacketChainType: Int {
    case fixed = 0
    case random = 1
}

enum RedPacketChainStatus {
    case active
    case claimedAll
    case expired
    /// 已链上取回且已过有效期（发起人取回未领余额）
    case expiredWithdrawn
    /// 已取回（未与过期组合展示时使用）
    case withdrawn
}

struct RedPacketChainInfo {
    let id: String
    let creator: String
    let token: String
    let type: RedPacketChainType
    let totalAmount: BigUInt
    let totalCount: BigUInt
    let claimedCount: BigUInt
    let expireAt: BigUInt
    let whitelistCount: BigUInt
    let amountPerShare: BigUInt
    let withdrawn: Bool
    let claimedAmount: BigUInt
    let remainingAmount: BigUInt
    /// 代币展示名。记录页拿到链上 `symbol()` 后会回填，所以是 `var`。
    var tokenSymbol: String
    let userClaimed: Bool
    let userClaimedAmount: BigUInt?
    let decimals: Int
    /// 当前钱包地址是否在红包白名单内（无白名单时为 true）
    let userInWhitelist: Bool

    var status: RedPacketChainStatus {
        let now = BigUInt(Date().timeIntervalSince1970)
        if withdrawn {
            if now >= expireAt {
                return .expiredWithdrawn
            }
            return .withdrawn
        }
        if claimedCount >= totalCount { return .claimedAll }
        if now >= expireAt { return .expired }
        return .active
    }

    var remainingCount: BigUInt {
        totalCount > claimedCount ? totalCount - claimedCount : 0
    }

    /// 是否为专属红包（创建时传入了非空白名单）
    var hasWhitelist: Bool {
        whitelistCount > 0
    }

    /// 当前钱包地址是否可领取：进行中 + 未领过 + （无白名单 或 自己在白名单内）
    var canClaim: Bool {
        status == .active && !userClaimed && (!hasWhitelist || userInWhitelist)
    }
}

struct RedPacketChainClaimRecord {
    let user: String
    let amount: BigUInt
    /// 领取时间（链上 ClaimRecord 不带时间，由 `Claimed` 事件所在区块时间戳还原；拿不到为 nil）
    var claimedAt: Date? = nil
}

/// 红包记录分页结果：`infos` 是当前页，`total` 是当前筛选下的总条数（用于表头「共 N 个」）。
struct RedPacketRecordPage {
    let infos: [RedPacketChainInfo]
    let total: Int
}

final class RedPacketWeb3Service {
    static let shared = RedPacketWeb3Service()

    private let abi = """
    [
      {"type":"function","name":"createFixedRedPacket","stateMutability":"payable","inputs":[{"name":"token","type":"address"},{"name":"totalAmount","type":"uint256"},{"name":"totalCount","type":"uint256"},{"name":"expireAt","type":"uint256"},{"name":"allowedAddresses","type":"address[]"}],"outputs":[{"name":"id","type":"uint256"}]},
      {"type":"function","name":"createRandomRedPacket","stateMutability":"payable","inputs":[{"name":"token","type":"address"},{"name":"totalAmount","type":"uint256"},{"name":"totalCount","type":"uint256"},{"name":"expireAt","type":"uint256"},{"name":"allowedAddresses","type":"address[]"}],"outputs":[{"name":"id","type":"uint256"}]},
      {"type":"function","name":"claim","stateMutability":"nonpayable","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"amount","type":"uint256"}]},
      {"type":"function","name":"withdraw","stateMutability":"nonpayable","inputs":[{"name":"id","type":"uint256"}],"outputs":[]},
      {"type":"function","name":"getRedPacket","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"creator","type":"address"},{"name":"token","type":"address"},{"name":"ptype","type":"uint8"},{"name":"totalAmount","type":"uint256"},{"name":"totalCount","type":"uint256"},{"name":"claimedCount","type":"uint256"},{"name":"expireAt","type":"uint256"},{"name":"whitelistCount","type":"uint256"},{"name":"amountPerShare","type":"uint256"},{"name":"withdrawn","type":"bool"}]},
      {"type":"function","name":"getClaimedAmount","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"uint256"}]},
      {"type":"function","name":"getRemainingAmount","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"uint256"}]},
      {"type":"function","name":"isClaimed","stateMutability":"view","inputs":[{"name":"id","type":"uint256"},{"name":"user","type":"address"}],"outputs":[{"name":"","type":"bool"}]},
      {"type":"function","name":"hasWhitelist","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
      {"type":"function","name":"isInWhitelist","stateMutability":"view","inputs":[{"name":"id","type":"uint256"},{"name":"account","type":"address"}],"outputs":[{"name":"","type":"bool"}]},
      {"type":"function","name":"getClaimRecords","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"tuple[]","components":[{"name":"user","type":"address"},{"name":"amount","type":"uint256"}]}]},
      {"type":"function","name":"getMyRedPacketIds","stateMutability":"view","inputs":[{"name":"account","type":"address"},{"name":"asReceiver","type":"bool"},{"name":"year","type":"uint256"},{"name":"month","type":"uint256"},{"name":"symbolFilter","type":"string"}],"outputs":[{"name":"","type":"uint256[]"}]},
      {"type":"function","name":"getRedPacketTokenSymbol","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"string"}]},
      {"type":"event","name":"RedPacketCreated","anonymous":false,"inputs":[{"indexed":true,"name":"id","type":"uint256"},{"indexed":true,"name":"creator","type":"address"},{"indexed":false,"name":"token","type":"address"},{"indexed":true,"name":"tokenSymbolKey","type":"bytes32"},{"indexed":false,"name":"ptype","type":"uint8"},{"indexed":false,"name":"totalAmount","type":"uint256"},{"indexed":false,"name":"totalCount","type":"uint256"},{"indexed":false,"name":"expireAt","type":"uint256"},{"indexed":false,"name":"whitelistCount","type":"uint256"}]},
      {"type":"event","name":"Claimed","anonymous":false,"inputs":[{"indexed":true,"name":"id","type":"uint256"},{"indexed":true,"name":"user","type":"address"},{"indexed":false,"name":"amount","type":"uint256"}]},
      {"type":"event","name":"Withdrawn","anonymous":false,"inputs":[{"indexed":true,"name":"id","type":"uint256"},{"indexed":true,"name":"creator","type":"address"},{"indexed":false,"name":"amount","type":"uint256"}]}
    ]
    """

    private let erc20ABI = """
    [
      {"type":"function","name":"approve","stateMutability":"nonpayable","inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
      {"type":"function","name":"allowance","stateMutability":"view","inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
      {"type":"function","name":"decimals","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"uint8"}]},
      {"type":"function","name":"symbol","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"string"}]}
    ]
    """

    func createRedPacket(
        isRandom: Bool,
        token: String,
        totalAmount: BigUInt,
        totalCount: BigUInt,
        expireAt: BigUInt,
        allowedAddresses: [String],
        privateKey: Data,
        completion: @escaping (Result<String, RedPacketWeb3Error>) -> Void
    ) {
        run {
            let context = try await self.makeContext(privateKey: privateKey)
            let normalizedToken = self.normalizedTokenAddress(token)
            if normalizedToken != redPacketZeroAddress {
                try await self.ensureAllowance(token: normalizedToken, amount: totalAmount, context: context)
            }

            let method = isRandom ? "createRandomRedPacket" : "createFixedRedPacket"
            let value = normalizedToken == redPacketZeroAddress ? totalAmount : BigUInt(0)
            let params = try self.createParams(token: normalizedToken, totalAmount: totalAmount, totalCount: totalCount, expireAt: expireAt, allowedAddresses: allowedAddresses)
            let result = try await self.sendContract(method: method, parameters: params, value: value, context: context)
            let receipt = try await self.waitReceipt(hash: result.hash, eth: context.eth)
            try self.ensureReceiptSucceeded(receipt, action: L("创建红包"))
            return try self.createdPacketId(from: receipt, contract: context.contract)
        } completion: { completion($0) }
    }

    func claimRedPacket(id: String, privateKey: Data, completion: @escaping (Result<BigUInt, RedPacketWeb3Error>) -> Void) {
        run {
            let packetId = try self.bigUInt(id, name: L("红包ID"))
            let context = try await self.makeContext(privateKey: privateKey)
            let result = try await self.sendContract(method: "claim", parameters: [packetId], value: 0, context: context)
            let receipt = try await self.waitReceipt(hash: result.hash, eth: context.eth)
            try self.ensureReceiptSucceeded(receipt, action: L("领取红包"))
            return self.claimedAmount(from: receipt, contract: context.contract) ?? 0
        } completion: { [weak self] result in
            // 领取成功：链上详情缓存要失效，否则消息 cell 还会按缓存显示「进行中」
            if case .success = result {
                self?.invalidateRedPacketInfoCache(id: id)
            }
            completion(result)
        }
    }

    func withdrawRedPacket(id: String, privateKey: Data, completion: @escaping (Result<Void, RedPacketWeb3Error>) -> Void) {
        run {
            let packetId = try self.bigUInt(id, name: L("红包ID"))
            let context = try await self.makeContext(privateKey: privateKey)
            let result = try await self.sendContract(method: "withdraw", parameters: [packetId], value: 0, context: context)
            let receipt = try await self.waitReceipt(hash: result.hash, eth: context.eth)
            try self.ensureReceiptSucceeded(receipt, action: L("取回红包"))
            return ()
        } completion: { [weak self] result in
            if case .success = result {
                self?.invalidateRedPacketInfoCache(id: id)
            }
            completion(result)
        }
    }

    // MARK: - 本地红包档案（已知「是不是专属」）+ 链上详情缓存
    //
    // 红包消息（pb）里 `packetType` 只有 0=拼手气 / 1=普通，**没有「专属」标记**；
    // 「专属」只能靠链上 `getRedPacket(...)` 的 `whitelistCount > 0` 判断 —— 所以 cell 会出现
    // 「先显示拼手气红包、查询回来再跳成专属红包」的闪变（用户 2026-09-24 反馈）。
    //
    // 这里用三件事把闪变消掉：
    // ① `knownPackets`：本地已知「是不是专属」。发红包成功时发送方就知道；链上查询回来也会补写；
    //    并**持久化到 UserDefaults** ⇒ 杀进程重进会话、断网也能直接显示对（不用再等查询）。
    // ② `infoCache`：`getRedPacketInfo` 的结果缓存（TTL）+ 同 id 并发请求合并 ——
    //    原来 cell 每次 `configure`（滚动复用、翻页）都要重打一轮链上查询（`getRedPacketDetail` 一次 5 个 RPC）。
    // ③ `prefetchRedPacketInfo(id:)`：让 `ChatVC` 在「消息刚进数据源」时就把查询跑掉，cell 上屏时已是热缓存。
    // ⚠️ 都是单例上的可变状态、会被异步回调并发访问 ⇒ 一律加锁（本工程踩过字典被写坏的坑）；
    //    锁里**不要**做网络/回调（只包住集合读写），避免把并发调用串行化甚至死锁。
    private var exclusivePacketIds = Set<String>()
    private var normalPacketIds = Set<String>()
    private var exclusivePacketOrder = [String]()
    private var normalPacketOrder = [String]()
    private var didLoadKnownPackets = false
    private let knownPacketsLock = NSLock()

    private var infoCache = [String: (info: RedPacketChainInfo, time: Date)]()
    private let infoCacheLock = NSLock()
    /// 领取记录缓存：和 info 同一 TTL。
    /// 聊天页点红包时已经查过详情（含记录），详情页直接复用，避免刚查完又重查 6～8 个 RPC。
    private var recordsCache = [String: (records: [RedPacketChainClaimRecord], time: Date)]()
    private let recordsCacheLock = NSLock()
    private var infoRequestsInFlight = [String: [(Result<RedPacketChainInfo, RedPacketWeb3Error>) -> Void]]()
    private let infoRequestsLock = NSLock()

    // MARK: - 领取时间
    //
    // ⚠️ 2026-09-28 **移除了「本地观测时刻」兜底**：它会把自己**第一次注意到**某个领取人的时刻
    // 当成对方的领取时间显示（三天前的领取会显示成"刚刚"），比空着更误导。
    // 现在的规则很简单：**只用链上 `Claimed` 事件的区块时间**；拿不到就**不显示**那行时间。

    private static let exclusivePacketIdsStoreKey = "FZMRedPacketExclusiveIds"
    private static let normalPacketIdsStoreKey = "FZMRedPacketNormalIds"
    /// 持久化上限（超出丢最早的），避免无限增长
    private static let knownPacketsMaxCount = 500
    /// 链上详情缓存有效期：短一点，避免领取/过期状态显示滞后
    private let infoCacheTTL: TimeInterval = 20

    private func normalizedPacketKey(_ id: String?) -> String {
        (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 懒加载持久化的档案。**必须在 `knownPacketsLock` 内调用**。
    private func loadKnownPacketsIfNeededLocked() {
        guard !didLoadKnownPackets else { return }
        didLoadKnownPackets = true
        let defaults = UserDefaults.standard
        let exclusive = (defaults.array(forKey: Self.exclusivePacketIdsStoreKey) as? [String]) ?? []
        let normal = (defaults.array(forKey: Self.normalPacketIdsStoreKey) as? [String]) ?? []
        exclusivePacketOrder = exclusive
        normalPacketOrder = normal
        exclusivePacketIds = Set(exclusive)
        normalPacketIds = Set(normal)
    }

    private func persistKnownPacketsLocked() {
        let defaults = UserDefaults.standard
        defaults.set(exclusivePacketOrder, forKey: Self.exclusivePacketIdsStoreKey)
        defaults.set(normalPacketOrder, forKey: Self.normalPacketIdsStoreKey)
    }

    /// 记下某个包「是不是专属红包」（会持久化）
    func markKnownPacket(id: String?, isExclusive: Bool) {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else { return }
        knownPacketsLock.lock()
        loadKnownPacketsIfNeededLocked()
        defer { knownPacketsLock.unlock() }
        if isExclusive {
            normalPacketIds.remove(key)
            normalPacketOrder.removeAll { $0 == key }
            if exclusivePacketIds.insert(key).inserted {
                exclusivePacketOrder.append(key)
                trimKnownPacketsLocked()
            }
        } else {
            exclusivePacketIds.remove(key)
            exclusivePacketOrder.removeAll { $0 == key }
            if normalPacketIds.insert(key).inserted {
                normalPacketOrder.append(key)
                trimKnownPacketsLocked()
            }
        }
        persistKnownPacketsLocked()
    }

    /// 超出上限就丢最早的
    private func trimKnownPacketsLocked() {
        while exclusivePacketOrder.count > Self.knownPacketsMaxCount {
            let dropped = exclusivePacketOrder.removeFirst()
            exclusivePacketIds.remove(dropped)
        }
        while normalPacketOrder.count > Self.knownPacketsMaxCount {
            let dropped = normalPacketOrder.removeFirst()
            normalPacketIds.remove(dropped)
        }
    }

    /// 本地是否已知该包是专属红包：true=专属 / false=不是专属 / nil=未知
    func knownPacketExclusiveFlag(id: String?) -> Bool? {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else { return nil }
        knownPacketsLock.lock()
        loadKnownPacketsIfNeededLocked()
        defer { knownPacketsLock.unlock() }
        if exclusivePacketIds.contains(key) { return true }
        if normalPacketIds.contains(key) { return false }
        return nil
    }

    /// 等价于「已知且是专属」
    func isKnownExclusivePacket(id: String?) -> Bool {
        knownPacketExclusiveFlag(id: id) == true
    }

    /// 标记为专属红包（发送方在创建成功时调；链上查询回来也会调）
    func markExclusivePacket(id: String) {
        markKnownPacket(id: id, isExclusive: true)
    }

    /// 同步读链上详情缓存（TTL 内），**不触发网络请求** —— cell 渲染时用它判断类型/状态
    func cachedRedPacketInfo(id: String?) -> RedPacketChainInfo? {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else { return nil }
        return cachedInfo(key)
    }

    /// 同步读领取记录缓存（TTL 内），详情页首帧用它直接铺列表，**不触发网络请求**。
    func cachedRedPacketRecords(id: String?) -> [RedPacketChainClaimRecord]? {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else { return nil }
        return cachedRecords(key)
    }

    private func cachedInfo(_ key: String) -> RedPacketChainInfo? {
        infoCacheLock.lock()
        defer { infoCacheLock.unlock() }
        guard let entry = infoCache[key] else { return nil }
        guard Date().timeIntervalSince(entry.time) < infoCacheTTL else { return nil }
        return entry.info
    }

    private func storeInfo(_ info: RedPacketChainInfo, for key: String) {
        infoCacheLock.lock()
        infoCache[key] = (info, Date())
        // 顺手清掉过期的，避免常驻大量条目
        if infoCache.count > 200 {
            let deadline = Date().addingTimeInterval(-infoCacheTTL)
            infoCache = infoCache.filter { $0.value.time > deadline }
        }
        infoCacheLock.unlock()
    }

    private func cachedRecords(_ key: String) -> [RedPacketChainClaimRecord]? {
        recordsCacheLock.lock()
        defer { recordsCacheLock.unlock() }
        guard let entry = recordsCache[key] else { return nil }
        guard Date().timeIntervalSince(entry.time) < infoCacheTTL else { return nil }
        return entry.records
    }

    private func storeRecords(_ records: [RedPacketChainClaimRecord], for key: String) {
        recordsCacheLock.lock()
        recordsCache[key] = (records, Date())
        if recordsCache.count > 200 {
            let deadline = Date().addingTimeInterval(-infoCacheTTL)
            recordsCache = recordsCache.filter { $0.value.time > deadline }
        }
        recordsCacheLock.unlock()
    }

    /// 领取/取回成功后失效缓存，避免 cell 显示旧状态
    func invalidateRedPacketInfoCache(id: String?) {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else { return }
        infoCacheLock.lock()
        infoCache[key] = nil
        infoCacheLock.unlock()

        recordsCacheLock.lock()
        recordsCache[key] = nil
        recordsCacheLock.unlock()
    }

    /// 预取：把链上查询提前到「消息刚进数据源」的时刻（`ChatVC` 里调）。
    /// 等 cell 上屏时缓存已就绪 ⇒ 首帧就能显示「专属红包」，不再先拼手气后专属。
    /// 命中缓存 / 已在查询中都会直接复用，重复调用安全且廉价。
    func prefetchRedPacketInfo(id: String?) {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else { return }
        if cachedInfo(key) != nil { return }
        getRedPacketInfo(id: key) { [weak self] result in
            guard case .success(let info) = result else { return }
            // 查询回来就把「是不是专属」写进本地档案（持久化），后面渲染不用再等
            self?.markKnownPacket(id: key, isExclusive: info.hasWhitelist)
        }
    }

    /// 链上红包详情（**结果带 TTL 缓存 + 同 id 并发合并**，是 cell 刷新状态的主入口）
    func getRedPacketInfo(id: String, completion: @escaping (Result<RedPacketChainInfo, RedPacketWeb3Error>) -> Void) {
        let key = normalizedPacketKey(id)
        // 1) 缓存命中：异步回调（与 `run` 一致，都在主线程），cell 渲染即可直接判断类型/状态
        if let cached = cachedInfo(key) {
            DispatchQueue.main.async { completion(.success(cached)) }
            return
        }
        // 2) 同一个包的并发请求合并：只发一次链上查询，其它回调挂到一起
        infoRequestsLock.lock()
        if infoRequestsInFlight[key] != nil {
            infoRequestsInFlight[key]?.append(completion)
            infoRequestsLock.unlock()
            return
        }
        infoRequestsInFlight[key] = [completion]
        infoRequestsLock.unlock()

        run {
            let (info, records) = try await self.getRedPacketDetail(id: key)
            // 详情页紧接着要用：info + records 一起缓存，避免刚查完又重查一遍
            self.storeInfo(info, for: key)
            self.storeRecords(records, for: key)
            return info
        } completion: { [weak self] result in
            self?.finishInfoRequests(key: key, result: result)
        }
    }

    private func finishInfoRequests(key: String, result: Result<RedPacketChainInfo, RedPacketWeb3Error>) {
        infoRequestsLock.lock()
        let callbacks = infoRequestsInFlight[key] ?? []
        infoRequestsInFlight[key] = nil
        infoRequestsLock.unlock()
        callbacks.forEach { $0(result) }
    }

    /// 一次性获取红包详情 + 领取记录（避免重复 RPC）。
    ///
    /// 优化（2026-11-06）：聊天页点红包时已经查过 `getRedPacketInfo`，这里优先复用
    /// `info + records` 的 TTL 缓存；只有 info 时只补一次领取记录，不再重查整份详情。
    func getRedPacketInfoWithRecords(id: String,
                                     knownSymbol: String? = nil,
                                     completion: @escaping (Result<(RedPacketChainInfo, [RedPacketChainClaimRecord]), RedPacketWeb3Error>) -> Void) {
        let key = normalizedPacketKey(id)
        guard !key.isEmpty else {
            completion(.failure(.invalidParameter(L("红包ID无效"))))
            return
        }

        // 1) info + records 都在 TTL 内：直接返回，0 个 RPC
        if let info = cachedInfo(key), let records = cachedRecords(key) {
            DispatchQueue.main.async { completion(.success((info, records))) }
            return
        }

        // 2) 只有 info：只补领取记录（1 个 RPC），不重查详情
        if let info = cachedInfo(key) {
            run {
                let packetId = try self.bigUInt(id, name: L("红包ID"))
                let context = try await self.makeReadContext()
                return try await self.claimRecords(packetId: packetId, context: context)
            } completion: { [weak self] result in
                switch result {
                case .success(let records):
                    self?.storeRecords(records, for: key)
                    completion(.success((info, records)))
                case .failure:
                    // 记录补拉失败时仍展示已有详情，不把整页卡死
                    completion(.success((info, [])))
                }
            }
            return
        }

        // 3) 无缓存：完整查询
        run {
            let (info, records) = try await self.getRedPacketDetail(id: id, knownSymbol: knownSymbol)
            self.storeInfo(info, for: key)
            self.storeRecords(records, for: key)
            return (info, records)
        } completion: { completion($0) }
    }

    func getClaimRecords(id: String, completion: @escaping (Result<[RedPacketChainClaimRecord], RedPacketWeb3Error>) -> Void) {
        run {
            let packetId = try self.bigUInt(id, name: L("红包ID"))
            let context = try await self.makeReadContext()
            return try await self.claimRecords(packetId: packetId, context: context)
        } completion: { completion($0) }
    }

    /// 只读「领取进度」（1 次 `getRedPacket` RPC）：详情页停留时轻量轮询用，
    /// 只有份数变化 / 过期了才去拉完整详情，避免每几秒发一堆请求。
    func getRedPacketClaimProgress(id: String, completion: @escaping (Result<(claimedCount: BigUInt, totalCount: BigUInt, expireAt: BigUInt), RedPacketWeb3Error>) -> Void) {
        run {
            let packetId = try self.bigUInt(id, name: L("红包ID"))
            let context = try await self.makeReadContext()
            let result = try await self.callContract(method: "getRedPacket", parameters: [packetId], context: context)
            guard
                let totalCount = self.uintValue(result, index: "4", name: "totalCount"),
                let claimedCount = self.uintValue(result, index: "5", name: "claimedCount"),
                let expireAt = self.uintValue(result, index: "6", name: "expireAt")
            else { throw RedPacketWeb3Error.contractDecodeFailed }
            return (claimedCount, totalCount, expireAt)
        } completion: { completion($0) }
    }

    /// 领取记录（**带真实领取时间**）。链上 `ClaimRecord` 只有 (user, amount)，
    /// 时间通过 `Claimed` 事件所在区块的 timeStamp 还原；解析失败时 `claimedAt` 为 nil（UI 不显示时间）。
    /// - Parameter knownRecords: 刚拉过详情的调用方可以把 `getClaimRecords` 的结果直接传进来，省一次 RPC
    func getClaimRecordsWithTime(id: String,
                                 knownRecords: [RedPacketChainClaimRecord]? = nil,
                                 knownExpireAt: BigUInt? = nil,
                                 completion: @escaping (Result<[RedPacketChainClaimRecord], RedPacketWeb3Error>) -> Void) {
        run {
            let packetId = try self.bigUInt(id, name: L("红包ID"))
            let context = try await self.makeReadContext()
            var records: [RedPacketChainClaimRecord]
            if let knownRecords = knownRecords {
                records = knownRecords
            } else {
                records = try await self.claimRecords(packetId: packetId, context: context)
            }
            guard !records.isEmpty else { return records }
            // **只用链上时间**：`Claimed` 事件所在区块的 timeStamp。
            // 拿不到（网关日志索引不全 / 断网）就保持 `claimedAt == nil` ⇒ UI 不显示时间，
            // 绝不用「当前时间 / 我注意到的时刻」充数。
            // 详情里已经有 `expireAt` 时直接传进来，省一次 `getRedPacket`。
            let expireAt: BigUInt?
            if let knownExpireAt = knownExpireAt {
                expireAt = knownExpireAt
            } else {
                expireAt = try? await self.packetExpireAt(packetId: packetId, context: context)
            }
            if let expireAt = expireAt {
                let times = await self.claimTimes(packetId: packetId, expireAt: expireAt, context: context)
                if !times.isEmpty {
                    records = records.map { record in
                        var record = record
                        record.claimedAt = times[record.user.lowercased()]
                        return record
                    }
                }
            }
            return records
        } completion: { completion($0) }
    }

    /// 只取红包的 `expireAt`（用于由有效期反推创建时间，限定领取日志的区块区间）
    private func packetExpireAt(packetId: BigUInt, context: Context) async throws -> BigUInt? {
        let result = try await callContract(method: "getRedPacket", parameters: [packetId], context: context)
        return uintValue(result, index: "6", name: "expireAt")
    }

    func getMyRedPacketInfos(asReceiver: Bool, year: Int, month: Int, symbol: String,
                             page: Int = 0, pageSize: Int = 20,
                             completion: @escaping (Result<RedPacketRecordPage, RedPacketWeb3Error>) -> Void) {
        run {
            let context = try await self.makeReadContext()
            FZMLog("红包记录：query address=\(context.from.address) asReceiver=\(asReceiver) year=\(year) month=\(month) symbol=\(symbol) page=\(page) pageSize=\(pageSize)")
            let idsResult = try await self.callContract(method: "getMyRedPacketIds", parameters: [
                context.from,
                asReceiver,
                BigUInt(year),
                BigUInt(month),
                symbol
            ] as [Any], context: context)
            let rawIds = idsResult["0"] ?? idsResult[""] ?? idsResult.values.first
            let ids = self.parseRedPacketIds(rawIds)
            let total = ids.count
            if ids.isEmpty {
                FZMLog("红包记录：getMyRedPacketIds 未解析到 ID（asReceiver=\(asReceiver) year=\(year) month=\(month) symbol=\(symbol)）raw=\(String(describing: rawIds).prefix(200))")
            }

            // 分页：只取当前页的 ID 去查详情，首屏只加载 20 条，滑到底再加载下一页。
            let reversedIds = Array(ids.reversed())
            let size = pageSize > 0 ? pageSize : reversedIds.count
            let start = max(0, page) * max(size, 1)
            guard start < reversedIds.count else {
                return RedPacketRecordPage(infos: [], total: total)
            }
            let end = min(start + size, reversedIds.count)
            let pageIds = Array(reversedIds[start..<end])

            // 列表只需要「红包基础信息 + 我的领取金额」。
            // 用 JSON-RPC batch 把当前页的 `getRedPacket`（收到再叠加 `getClaimRecords`）
            // 合并成 1 个 HTTP 请求；逐笔单发时 152 条记录要 ~80 秒。
            var infos = [RedPacketChainInfo]()
            /// batch 里失败的 ID：最后用并发逐笔补，避免 batch 不受支持时退化成串行
            var failedIds = [BigUInt]()
            let batchSize = 40
            var cursor = 0
            while cursor < pageIds.count {
                let chunkEnd = min(cursor + batchSize, pageIds.count)
                let chunk = Array(pageIds[cursor..<chunkEnd])

                var calls: [(method: String, parameters: [Any])] = chunk.map {
                    (method: "getRedPacket", parameters: [$0] as [Any])
                }
                if asReceiver {
                    calls += chunk.map {
                        (method: "getClaimRecords", parameters: [$0] as [Any])
                    }
                }

                let batchResults = await self.batchCallContract(methods: calls, context: context)
                for (offset, id) in chunk.enumerated() {
                    guard offset < batchResults.count, let packetResult = batchResults[offset] else {
                        // 批次里单笔失败：先记下来，最后并发补（不要在这里串行 await）
                        failedIds.append(id)
                        continue
                    }
                    var records: [RedPacketChainClaimRecord]?
                    if asReceiver, offset + chunk.count < batchResults.count,
                       let rawRecords = batchResults[offset + chunk.count] {
                        records = self.parseClaimRecords(
                            rawRecords["0"] ?? rawRecords["records"] ?? rawRecords[""] ?? rawRecords.values.first)
                    }
                    if let info = try? self.makeRedPacketListInfo(
                        id: id.description,
                        packetResult: packetResult,
                        records: records,
                        asReceiver: asReceiver,
                        context: context) {
                        infos.append(info)
                    }
                }
                cursor = chunkEnd
            }

            // batch 没拿到 / 节点拒绝 batch 的项：并发逐笔补，避免串行拖慢
            if !failedIds.isEmpty {
                let recovered = await withTaskGroup(of: RedPacketChainInfo?.self) { group in
                    for id in failedIds {
                        group.addTask {
                            try? await self.getRedPacketListInfo(
                                id: id.description, asReceiver: asReceiver, context: context)
                        }
                    }
                    var results = [RedPacketChainInfo]()
                    for await info in group {
                        if let info = info { results.append(info) }
                    }
                    return results
                }
                infos.append(contentsOf: recovered)
            }
            // 记录页币名兜底：本地钱包里没有这个合约币时，`makeRedPacketListInfo` 只能回退合约地址，
            // 列表就会把 `0x…` 当币名显示。这里收集当前页「币名仍是合约地址」的代币，**批量**读一次
            // 链上 `symbol()` 补名称；失败 / 空名保持合约地址，不影响列表加载。
            var unknownTokenAddresses = [String]()
            var seenTokenAddresses = Set<String>()
            for info in infos {
                let address = info.token.lowercased()
                guard address != redPacketZeroAddress,
                      info.tokenSymbol.lowercased() == address,
                      seenTokenAddresses.insert(address).inserted else { continue }
                unknownTokenAddresses.append(info.token)
            }
            if !unknownTokenAddresses.isEmpty {
                let resolvedSymbols = await self.batchTokenSymbols(for: unknownTokenAddresses, context: context)
                if !resolvedSymbols.isEmpty {
                    infos = infos.map { info in
                        guard let symbol = resolvedSymbols[info.token.lowercased()] else { return info }
                        var info = info
                        info.tokenSymbol = symbol
                        return info
                    }
                }
            }
            if infos.count < pageIds.count {
                FZMLog("红包记录：本页详情解析成功 \(infos.count)/\(pageIds.count)（总 \(total)）")
            }
            // batch 返回顺序按 id 对应，这里仍统一按链上过期时间（= 创建时间 + 24h）降序
            return RedPacketRecordPage(
                infos: infos.sorted { $0.expireAt > $1.expireAt },
                total: total
            )
        } completion: { completion($0) }
    }

    /// 批量读取 ERC20 `symbol()`：记录页里「本地钱包查不到名称」的代币，一次 HTTP 请求补齐。
    ///
    /// 每个 `eth_call` 的 `to` 是对应的**代币合约地址**（与红包合约的 batch 不同）。
    /// 任一子调用失败 / 代币没实现 `symbol()` 时该项不返回，调用方保持合约地址，不阻塞列表。
    private func batchTokenSymbols(for tokens: [String], context: Context) async -> [String: String] {
        var addresses = [String]()
        var seen = Set<String>()
        for token in tokens {
            let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty,
                  key != redPacketZeroAddress,
                  EthereumAddress(key, ignoreChecksum: true) != nil,
                  seen.insert(key).inserted,
                  cachedTokenSymbol(for: key) == nil else { continue }
            addresses.append(key)
        }
        guard !addresses.isEmpty,
              let sample = EthereumAddress(addresses[0], ignoreChecksum: true),
              let erc20Contract = try? EthereumContract(erc20ABI, at: sample),
              let callData = erc20Contract.method("symbol", parameters: [], extraData: nil)
        else { return [:] }

        var payloads = [[String: Any]]()
        payloads.reserveCapacity(addresses.count)
        for (index, address) in addresses.enumerated() {
            payloads.append([
                "jsonrpc": "2.0",
                "id": index,
                "method": "eth_call",
                "params": [
                    [
                        "from": context.from.address,
                        "to": address,
                        "data": "0x" + callData.toHexString()
                    ],
                    "latest"
                ]
            ])
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payloads, options: []) else {
            return [:]
        }

        var request = URLRequest(url: context.config.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChatWallet/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        request.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                let body = String(data: data, encoding: .utf8) ?? ""
                FZMLog("红包记录：batch 读取代币名称响应不是数组（\(addresses.count) 个调用）：\(body.prefix(200))")
                return [:]
            }
            var output = [String: String]()
            for item in items {
                guard let id = (item["id"] as? NSNumber)?.intValue ?? (item["id"] as? Int),
                      id >= 0, id < addresses.count,
                      let hex = item["result"] as? String else {
                    continue
                }
                let hexBody = hex.replacingOccurrences(of: "0x", with: "")
                guard !hexBody.isEmpty,
                      let raw = Data.fromHex(hexBody),
                      let decoded = erc20Contract.decodeReturnData("symbol", data: raw),
                      let value = decoded["0"] as? String else {
                    continue
                }
                let symbol = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = addresses[id]
                // 空名 / 返回的还是地址 ⇒ 视为没查到，不缓存、不回填
                guard !symbol.isEmpty, symbol.lowercased() != address else { continue }
                storeTokenSymbol(symbol, for: address)
                output[address] = symbol
            }
            return output
        } catch {
            FZMLog("红包记录：batch 读取代币名称失败 \(error)")
            return [:]
        }
    }

    /// 列表用的轻量详情：只读 `getRedPacket`，再按需补「我的领取金额」/代币精度。
    ///
    /// 与 `getRedPacketDetail` 的区别：不查 `getClaimedAmount` / `getRemainingAmount` /
    /// `isClaimed` / 白名单；这些字段列表用不到，逐笔查会把记录页拖到十几秒。
    private func getRedPacketListInfo(id: String, asReceiver: Bool, context: Context) async throws -> RedPacketChainInfo {
        let packetId = try bigUInt(id, name: L("红包ID"))
        let result = try await callContract(method: "getRedPacket", parameters: [packetId], context: context)
        var records: [RedPacketChainClaimRecord]?
        if asReceiver {
            records = try? await claimRecords(packetId: packetId, context: context)
        }
        return try makeRedPacketListInfo(
            id: id, packetResult: result, records: records, asReceiver: asReceiver, context: context)
    }

    /// 把 `getRedPacket` 的解码结果组装成列表用的 `RedPacketChainInfo`（纯本地，不发 RPC）。
    private func makeRedPacketListInfo(id: String,
                                       packetResult result: [String: Any],
                                       records: [RedPacketChainClaimRecord]?,
                                       asReceiver: Bool,
                                       context: Context) throws -> RedPacketChainInfo {
        guard
            let creator = addressValue(result, index: "0", name: "creator"),
            let token = addressValue(result, index: "1", name: "token"),
            let typeValue = uintValue(result, index: "2", name: "ptype"),
            let totalAmount = uintValue(result, index: "3", name: "totalAmount"),
            let totalCount = uintValue(result, index: "4", name: "totalCount"),
            let claimedCount = uintValue(result, index: "5", name: "claimedCount"),
            let expireAt = uintValue(result, index: "6", name: "expireAt"),
            let whitelistCount = uintValue(result, index: "7", name: "whitelistCount"),
            let amountPerShare = uintValue(result, index: "8", name: "amountPerShare"),
            let withdrawn = boolValue(result, index: "9", name: "withdrawn")
        else {
            throw RedPacketWeb3Error.contractDecodeFailed
        }
        guard creator.address.lowercased() != redPacketZeroAddress else {
            throw RedPacketWeb3Error.invalidParameter(L("红包不存在"))
        }

        let isNativeToken = token.address.lowercased() == redPacketZeroAddress
        let decimals = isNativeToken
            ? 18
            : (cachedDecimals(for: token.address.lowercased()) ?? 18)

        let symbol: String
        if isNativeToken {
            symbol = context.config.nativeSymbol
        } else if let local = RedPacketWalletDataSource.shared.symbol(forTokenContract: token.address), !local.isEmpty {
            symbol = local
        } else if let cached = cachedTokenSymbol(for: token.address) {
            // 前几页 / 上次进页面已经查过链上 `symbol()`：直接复用，列表解析本身仍然不发 RPC
            symbol = cached
        } else {
            symbol = token.address
        }

        // 收到的红包才需要「我领了多少」；发出列表不查领取记录。
        var userClaimed = asReceiver
        var userClaimedAmount: BigUInt?
        if asReceiver, let records = records {
            let me = context.from.address.lowercased()
            if let record = records.first(where: { $0.user.lowercased() == me }) {
                userClaimed = true
                userClaimedAmount = record.amount
            }
        }

        return RedPacketChainInfo(
            id: id,
            creator: creator.address,
            token: token.address,
            type: RedPacketChainType(rawValue: Int(typeValue.description) ?? 1) ?? .random,
            totalAmount: totalAmount,
            totalCount: totalCount,
            claimedCount: claimedCount,
            expireAt: expireAt,
            whitelistCount: whitelistCount,
            amountPerShare: amountPerShare,
            withdrawn: withdrawn,
            // 列表不展示已领总额 / 剩余总额；置 0，避免为它们多打 RPC
            claimedAmount: 0,
            remainingAmount: 0,
            tokenSymbol: symbol,
            userClaimed: userClaimed,
            userClaimedAmount: userClaimedAmount,
            decimals: decimals,
            // 列表不判断「我能不能领」，置 true 即可
            userInWhitelist: true
        )
    }

    /// JSON-RPC batch `eth_call`：一次 HTTP 请求里发多个只读合约调用。
    ///
    /// 记录页有 150+ 笔红包时，逐笔单发 `getRedPacket`（收到还要再发 `getClaimRecords`）
    /// 会产生 300+ 个请求，这是“加载几十秒”的根因。batch 后 40 个调用/请求，
    /// 152 条记录只需 3～5 个往返。
    ///
    /// - Returns: 与 `methods` 一一对应的解码结果；某项失败为 nil。
    private func batchCallContract(methods: [(method: String, parameters: [Any])],
                                   context: Context) async -> [[String: Any]?] {
        guard !methods.isEmpty else { return [] }

        var payloads: [[String: Any]] = []
        payloads.reserveCapacity(methods.count)
        for (index, item) in methods.enumerated() {
            guard let data = context.contract.method(item.method, parameters: item.parameters, extraData: nil) else {
                return Array(repeating: nil, count: methods.count)
            }
            payloads.append([
                "jsonrpc": "2.0",
                "id": index,
                "method": "eth_call",
                "params": [
                    [
                        "from": context.from.address,
                        "to": context.config.contractAddress,
                        "data": "0x" + data.toHexString()
                    ],
                    "latest"
                ]
            ])
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payloads, options: []) else {
            return Array(repeating: nil, count: methods.count)
        }

        var request = URLRequest(url: context.config.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChatWallet/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        request.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                let body = String(data: data, encoding: .utf8) ?? ""
                FZMLog("红包记录：batch 响应不是数组（\(methods.count) 个调用）：\(body.prefix(200))")
                return Array(repeating: nil, count: methods.count)
            }
            var output = Array<[String: Any]?>(repeating: nil, count: methods.count)
            for item in items {
                guard let id = (item["id"] as? NSNumber)?.intValue ?? (item["id"] as? Int),
                      id >= 0, id < methods.count,
                      let hex = item["result"] as? String else {
                    continue
                }
                let body = hex.replacingOccurrences(of: "0x", with: "")
                guard !body.isEmpty,
                      let raw = Data.fromHex(body),
                      let decoded = context.contract.decodeReturnData(methods[id].method, data: raw) else {
                    continue
                }
                output[id] = decoded
            }
            return output
        } catch {
            FZMLog("红包记录：batch eth_call 失败，回退逐笔查询 \(error)")
            return Array(repeating: nil, count: methods.count)
        }
    }

    /// 宽容解析 `getMyRedPacketIds` 的返回值：不同 web3swift/ABI 版本可能给
    /// `[BigUInt]` / `[Any]` / `[String]`，之前只接受 `[BigUInt]`，解析失败就整页空白。
    private func parseRedPacketIds(_ raw: Any?) -> [BigUInt] {
        if let ids = raw as? [BigUInt] { return ids }
        if let ids = raw as? [Any] { return ids.compactMap { bigUIntValue($0) } }
        if let ids = raw as? [String] { return ids.compactMap { bigUIntValue($0) } }
        if let id = bigUIntValue(raw) { return [id] }
        return []
    }

    private func bigUIntValue(_ raw: Any?) -> BigUInt? {
        if let value = raw as? BigUInt { return value }
        if let value = raw as? NSNumber { return BigUInt(value.stringValue) }
        if let value = raw as? String {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            if text.lowercased().hasPrefix("0x") {
                return BigUInt(String(text.dropFirst(2)), radix: 16)
            }
            return BigUInt(text)
        }
        return nil
    }

    func currentAddress() -> String? {
        // 优先当前登录账号绑定的钱包：切账号后 `LoginUser.ethAddr` / 全局选中钱包
        // 可能还是上一个账号的，直接拿来查记录会查到别人的/空列表。
        if let wallet = currentAccountWallet(),
           let address = evmAddress(from: wallet) {
            return address
        }
        return RedPacketWalletDataSource.shared.getCurrentWalletAddress()
    }

    /// 当前登录账号绑定的钱包（先按 encryptedSeed，再按登录地址反查）。
    private func currentAccountWallet() -> LocalWallet? {
        let seed = LoginUser.shared().encryptedSeed
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !seed.isEmpty,
           let wallet = PWDataBaseManager.shared().queryWallet(byRememberCode: seed) {
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

    /// 从钱包的币列表里挑一个 EVM 地址（与 AI 客服 / DApp 浏览器同一套优先级）。
    private func evmAddress(from wallet: LocalWallet) -> String? {
        guard let coins = PWDataBaseManager.shared().queryCoinArrayBased(on: wallet) as? [LocalCoin] else {
            return nil
        }
        func type(_ coin: LocalCoin) -> String { (coin.coin_type ?? "").uppercased() }
        func chain(_ coin: LocalCoin) -> String { (coin.coin_chain ?? "").uppercased() }
        let predicates: [(LocalCoin) -> Bool] = [
            { type($0) == "ETH" && chain($0) == "ETH" },
            { type($0) == "BTY" && chain($0) == "ETH" },
            { chain($0) == "ETH" },
            { ($0.coin_address ?? "").lowercased().hasPrefix("0x") }
        ]
        for predicate in predicates {
            if let coin = coins.first(where: predicate),
               let raw = coin.coin_address?.trimmingCharacters(in: .whitespacesAndNewlines),
               let address = EthereumAddress(raw, ignoreChecksum: true) {
                return address.address
            }
        }
        return nil
    }

    func amountToSmallestUnit(_ amount: String, decimals: Int) -> BigUInt? {
        let parts = amount.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ".")
        guard parts.count <= 2, let integer = BigUInt(parts[0].isEmpty ? "0" : parts[0]) else { return nil }
        let base = BigUInt(10).power(decimals)
        var value = integer * base
        if parts.count == 2 {
            let fractional = String(parts[1].prefix(decimals)).padding(toLength: decimals, withPad: "0", startingAt: 0)
            value += BigUInt(fractional.isEmpty ? "0" : fractional) ?? 0
        }
        return value
    }

    func format(_ amount: BigUInt, decimals: Int, maxFractionDigits: Int = 8) -> String {
        let base = BigUInt(10).power(decimals)
        let integer = amount / base
        let fraction = amount % base
        if decimals == 0 || fraction == 0 {
            return integer.description
        }
        var fractionText = fraction.description
        if fractionText.count < decimals {
            fractionText = String(repeating: "0", count: decimals - fractionText.count) + fractionText
        }
        fractionText = String(fractionText.prefix(maxFractionDigits))
        while fractionText.hasSuffix("0") {
            fractionText.removeLast()
        }
        return fractionText.isEmpty ? integer.description : "\(integer).\(fractionText)"
    }

    /// 展示用金额：**统一保留 4 位小数**。
    /// 详情页头部的大金额和领取列表都走它 ⇒ 两处小数位不会再不一致。
    /// 复用 `format` 的裁剪逻辑 ⇒ 末尾多余的 0 会被去掉（1.2300 → 1.23），不会出现 `1.2300` 这种尾巴。
    func displayAmount(_ amount: BigUInt, decimals: Int) -> String {
        return format(amount, decimals: decimals, maxFractionDigits: 4)
    }

    private struct Context {
        let config: RedPacketWeb3Config
        let web3: Web3
        /// ⚠️ **必须用这个，不要再写 `web3.eth`**（见 `connection(config:contractAddress:from:)` 里的注释）：
        /// `Web3.eth` 是未加锁的懒加载属性（每次访问都会**回写**），并发访问会崩溃。
        let eth: IEth
        let contract: EthereumContract
        let from: EthereumAddress
        let privateKey: Data?
    }

    /// 代币精度缓存，避免重复 RPC
    ///
    /// ⚠️ **必须加锁**：`RedPacketWeb3Service` 是单例，`getRedPacketDetail(id:)` 是 async，
    /// 而且会被**并发**调用（`getMyRedPacketInfos` 里用 `withTaskGroup` 并行拉多个红包，
    /// `run` 也是每次调用各起一个 Task）。多个线程同时写这个字典会把它的存储写坏，
    /// 崩溃栈就是：`Dictionary._Variant.setValue(_:forKey:)` ← `getRedPacketDetail(id:)`。
    private var decimalsCache = [String: Int]()
    private let decimalsCacheLock = NSLock()

    /// 读缓存（锁只包住字典读写，**不要跨 await 持锁**，否则会把并发调用串成串行/死锁）
    private func cachedDecimals(for token: String) -> Int? {
        decimalsCacheLock.lock()
        defer { decimalsCacheLock.unlock() }
        return decimalsCache[token]
    }

    private func storeDecimals(_ decimals: Int, for token: String) {
        decimalsCacheLock.lock()
        defer { decimalsCacheLock.unlock() }
        decimalsCache[token] = decimals
    }

    /// 代币名称缓存（合约地址小写 → 展示名）
    ///
    /// 记录页/详情页都会按合约地址反查代币名；链上 `symbol()` 虽是只读调用，但每次都要一个
    /// 网络往返，翻页 / 重新进页面时没必要重复查。与 `decimalsCache` 一样是单例上的可变状态，
    /// 会被并发 async 调用访问 ⇒ 必须加锁，且锁只包字典读写、不跨 await。
    private var tokenSymbolCache = [String: String]()
    private let tokenSymbolCacheLock = NSLock()

    private func cachedTokenSymbol(for token: String) -> String? {
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        tokenSymbolCacheLock.lock()
        defer { tokenSymbolCacheLock.unlock() }
        return tokenSymbolCache[key]
    }

    private func storeTokenSymbol(_ symbol: String, for token: String) {
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        // 空名 /「名称」就是合约地址时没有缓存价值，别把地址当币名缓存下来
        guard !key.isEmpty, !value.isEmpty, value.lowercased() != key else { return }
        tokenSymbolCacheLock.lock()
        defer { tokenSymbolCacheLock.unlock() }
        tokenSymbolCache[key] = value
    }

    /// 并行化获取红包详情 + 领取记录，消除串行 RPC 开销
    /// - Parameter knownSymbol: 消息里已带的币种名；非空且不是合约地址时跳过链上 `symbol()` RPC。
    private func getRedPacketDetail(id: String, knownSymbol: String? = nil) async throws -> (RedPacketChainInfo, [RedPacketChainClaimRecord]) {
        let packetId = try bigUInt(id, name: L("红包ID"))
        let context = try await makeReadContext()
        // 下面这几个读只依赖 packetId，和 getRedPacket **并行**发出去：
        // 原来要等 getRedPacket 回来才发，详情页/领完刷新的等待都白多一个网络往返
        async let aClaimed = try? callContract(method: "getClaimedAmount", parameters: [packetId], context: context)
        async let aRemaining = try? callContract(method: "getRemainingAmount", parameters: [packetId], context: context)
        async let aIsClaimed = try? callContract(method: "isClaimed", parameters: [packetId, context.from], context: context)
        async let aRecords = try? claimRecords(packetId: packetId, context: context)

        let result = try await callContract(method: "getRedPacket", parameters: [packetId], context: context)
        guard
            let creator = addressValue(result, index: "0", name: "creator"),
            let token = addressValue(result, index: "1", name: "token"),
            let typeValue = uintValue(result, index: "2", name: "ptype"),
            let totalAmount = uintValue(result, index: "3", name: "totalAmount"),
            let totalCount = uintValue(result, index: "4", name: "totalCount"),
            let claimedCount = uintValue(result, index: "5", name: "claimedCount"),
            let expireAt = uintValue(result, index: "6", name: "expireAt"),
            let whitelistCount = uintValue(result, index: "7", name: "whitelistCount"),
            let amountPerShare = uintValue(result, index: "8", name: "amountPerShare"),
            let withdrawn = boolValue(result, index: "9", name: "withdrawn")
        else {
            throw RedPacketWeb3Error.contractDecodeFailed
        }
        guard creator.address.lowercased() != redPacketZeroAddress else {
            throw RedPacketWeb3Error.invalidParameter(L("红包不存在"))
        }

        let isNativeToken = token.address.lowercased() == redPacketZeroAddress

        // 白名单查询依赖上面的 whitelistCount，只能等 getRedPacket（无白名单时直接返回、不发请求）
        async let aInWhitelist = self.isUserInWhitelist(
            packetId: packetId, context: context, whitelistRequired: whitelistCount > 0)

        // decimals：缓存命中则跳过 RPC
        let decimals: Int
        if isNativeToken {
            decimals = 18
        } else if let cached = cachedDecimals(for: token.address.lowercased()) {
            decimals = cached
        } else {
            let d = try await self.decimals(for: token.address, context: context)
            // 并发调用时可能有两个任务同时取到 d，值一样，重复写没影响（锁不跨 await）
            storeDecimals(d, for: token.address.lowercased())
            decimals = d
        }

        // 收集并发结果
        let claimedResult = await aClaimed
        let remainingResult = await aRemaining
        let isClaimedResult = await aIsClaimed
        let inWhitelist = await aInWhitelist
        let records = await aRecords ?? []

        let claimedAmount = claimedResult?["0"] as? BigUInt ?? 0
        let remainingAmount = remainingResult?["0"] as? BigUInt ?? 0
        let isClaimed = isClaimedResult?["0"] as? Bool ?? false
        // 代币展示名：不使用链上红包合约存的 symbol（部分代币存的是中文等非英文名），
        // 而是直接按合约地址在本地钱包反查该币的 coin_type（英文符号）；钱包里没这个合约币时读链上 symbol() 兜底。
        // 消息里已经带了币种名时直接用，省一个 RPC；但地址不算币种名（记录页/旧缓存会传地址进来）。
        let symbol: String
        if let knownSymbol = knownSymbol?.trimmingCharacters(in: .whitespacesAndNewlines),
           !knownSymbol.isEmpty,
           !redPacketLooksLikeContractAddress(knownSymbol) {
            symbol = knownSymbol
        } else {
            symbol = await tokenSymbol(
                for: token.address, context: context, isNativeToken: isNativeToken)
        }
        let lowerAddress = context.from.address.lowercased()
        let userAmount = records.first(where: { $0.user.lowercased() == lowerAddress })?.amount

        let info = RedPacketChainInfo(
            id: id,
            creator: creator.address,
            token: token.address,
            type: RedPacketChainType(rawValue: Int(typeValue.description) ?? 1) ?? .random,
            totalAmount: totalAmount,
            totalCount: totalCount,
            claimedCount: claimedCount,
            expireAt: expireAt,
            whitelistCount: whitelistCount,
            amountPerShare: amountPerShare,
            withdrawn: withdrawn,
            claimedAmount: claimedAmount,
            remainingAmount: remainingAmount,
            tokenSymbol: symbol,
            userClaimed: isClaimed,
            userClaimedAmount: userAmount,
            decimals: decimals,
            userInWhitelist: inWhitelist
        )
        return (info, records)
    }

    /// 专属红包（白名单非空）时查询当前钱包地址是否在白名单内。
    /// 无白名单直接返回 true；RPC 查询失败时不拦截（交由链上 claim 自行校验），避免误挡可领用户。
    private func isUserInWhitelist(packetId: BigUInt, context: Context, whitelistRequired: Bool) async -> Bool {
        guard whitelistRequired else { return true }
        guard
            let result = try? await callContract(
                method: "isInWhitelist", parameters: [packetId, context.from], context: context)
        else {
            return true
        }
        return boolValue(result, index: "0", name: "") ?? true
    }

    /// 代币展示名：原生币 → 本地钱包里该合约币的 `coin_type`（英文符号，与发红包/气泡一致）
    /// → 名称缓存 → 读取链上 `symbol()`（钱包里没添加过这个合约币时用）→ 合约地址
    private func tokenSymbol(for token: String, context: Context, isNativeToken: Bool) async -> String {
        if isNativeToken { return context.config.nativeSymbol }
        if let local = RedPacketWalletDataSource.shared.symbol(forTokenContract: token), !local.isEmpty {
            storeTokenSymbol(local, for: token)
            return local
        }
        if let cached = cachedTokenSymbol(for: token) {
            return cached
        }
        if let tokenAddress = EthereumAddress(token, ignoreChecksum: true),
           let tokenContract = try? EthereumContract(erc20ABI, at: tokenAddress),
           let output = try? await call(contract: tokenContract, method: "symbol", parameters: [], context: context),
           let value = output["0"] as? String,
           !value.isEmpty {
            storeTokenSymbol(value, for: token)
            return value
        }
        return token
    }

    /// 连接/合约复用：同一套（RPC + chainID + 合约 + 钱包地址）**只建一次**。
    /// web3swift 的 `Web3HttpProvider` 每次初始化都自带一个 `URLSession`，
    /// 原来「每次调用都新建 provider」= 每个 context 都要重新握手 TLS（移动网络 100~400ms）；
    /// 领取红包要连发好几个请求、领完还要刷详情，复用后除了第一次都是长连接直接发。
    private struct Connection {
        let web3: Web3
        /// 预热好的 `web3.eth`（见下面 `connection(...)` 的注释）
        let eth: IEth
        let contract: EthereumContract
    }
    private var connectionCache = [String: Connection]()
    private let connectionCacheLock = NSLock()

    /// 读缓存（锁只包住字典读写，不跨 await）
    private func cachedConnection(for key: String) -> Connection? {
        connectionCacheLock.lock()
        defer { connectionCacheLock.unlock() }
        return connectionCache[key]
    }

    private func storeConnection(_ connection: Connection, for key: String) {
        connectionCacheLock.lock()
        defer { connectionCacheLock.unlock() }
        // 正常只会有一套（换钱包/换 RPC 才会多），超了直接清掉重新建，防脏数据
        if connectionCache.count > 8 { connectionCache.removeAll() }
        connectionCache[key] = connection
    }

    /// 取（必要时建）一套可复用的 `Web3` + 合约
    private func connection(config: RedPacketWeb3Config, contractAddress: EthereumAddress, from: EthereumAddress) async throws -> Connection {
        let key = [
            config.rpcURL.absoluteString,
            config.chainID.description,
            contractAddress.address.lowercased(),
            from.address.lowercased()
        ].joined(separator: "|")
        if let cached = cachedConnection(for: key) { return cached }

        let provider = try await Web3HttpProvider(url: config.rpcURL, network: .Custom(networkID: config.chainID))
        // 默认每 host 只 6 条连接：详情页/记录页会并行发好几个请求，放宽一点少排队
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 10
        provider.session = URLSession(configuration: sessionConfig)
        let web3 = Web3(provider: provider)
        // ⚠️⚠️ **踩过的崩溃点（EXC_BAD_ACCESS，线上 1.1(18)）**：
        //   web3swift 3.1.2 的 `Web3.eth` 是**未加锁的懒加载缓存**：
        //     `let ethInstance = ethInstance ?? Web3.Eth(provider: provider); self.ethInstance = ethInstance`
        //   —— 即使已经非 nil，**每次访问都会再写一次**这个属性（ARC 是 release 旧值 + retain 新值）。
        //   而红包详情/记录页用 `async let` **并发**发多个 RPC 共用同一个 `Web3`，
        //   并发读写 `ethInstance` 会过度释放/读到半写指针 ⇒
        //   崩溃栈：`protocol witness for IEth.provider.getter` ← `IEth.callTransaction(_:)` ← 我们的 `call(...)`。
        //   修法：在**建连接时（单线程、还没进缓存）** 取一次 `eth`，后续所有请求都用它，热路径上不再访问 `web3.eth`。
        let eth = web3.eth
        let contract = try EthereumContract(abi, at: contractAddress)
        let connection = Connection(web3: web3, eth: eth, contract: contract)
        storeConnection(connection, for: key)
        return connection
    }

    private func makeReadContext() async throws -> Context {
        let config = try RedPacketWeb3Config.current()
        guard let contractAddress = EthereumAddress(config.contractAddress, ignoreChecksum: true) else {
            throw RedPacketWeb3Error.invalidConfig(L("红包合约地址无效"))
        }
        guard let fromAddress = currentAddress(), let from = EthereumAddress(fromAddress, ignoreChecksum: true) else {
            throw RedPacketWeb3Error.walletUnavailable
        }
        let connection = try await connection(config: config, contractAddress: contractAddress, from: from)
        return Context(config: config, web3: connection.web3, eth: connection.eth, contract: connection.contract, from: from, privateKey: nil)
    }

    /// 写操作上下文：私钥由调用方从 `WalletPrivateKeyStore` 取（**首次弹一次密码，之后命中内存缓存**）。
    /// 这里只做**同源校验**：派生地址必须等于当前钱包地址，不同源直接拒绝（避免发一笔注定失败的交易）。
    private func makeContext(privateKey: Data) async throws -> Context {
        let read = try await makeReadContext()
        guard !privateKey.isEmpty else { throw RedPacketWeb3Error.privateKeyUnavailable }
        guard let address = address(fromPrivateKey: privateKey) else {
            throw RedPacketWeb3Error.privateKeyUnavailable
        }
        guard address.address.lowercased() == read.from.address.lowercased() else {
            throw RedPacketWeb3Error.walletAddressMismatch(expected: read.from.address, actual: address.address)
        }
        return Context(config: read.config, web3: read.web3, eth: read.eth, contract: read.contract, from: read.from, privateKey: privateKey)
    }

    private func address(fromPrivateKey privateKey: Data) -> EthereumAddress? {
        guard let publicKey = Utilities.privateToPublic(privateKey) else { return nil }
        return Utilities.publicToAddress(publicKey)
    }

    private func resultValue(_ result: [String: Any], index: String, name: String) -> Any? {
        result[index] ?? result[name]
    }

    private func addressValue(_ result: [String: Any], index: String, name: String) -> EthereumAddress? {
        addressFromAny(resultValue(result, index: index, name: name))
    }

    private func addressFromAny(_ value: Any?) -> EthereumAddress? {
        if let address = value as? EthereumAddress {
            return address
        }
        if let address = value as? String {
            return EthereumAddress(address, ignoreChecksum: true)
        }
        return nil
    }

    private func uintValue(_ result: [String: Any], index: String, name: String) -> BigUInt? {
        uintFromAny(resultValue(result, index: index, name: name))
    }

    private func uintFromAny(_ value: Any?) -> BigUInt? {
        if let number = value as? BigUInt {
            return number
        }
        if let number = value as? UInt8 {
            return BigUInt(number)
        }
        if let number = value as? UInt {
            return BigUInt(number)
        }
        if let number = value as? UInt64 {
            return BigUInt(number)
        }
        if let number = value as? Int, number >= 0 {
            return BigUInt(number)
        }
        if let text = value as? String {
            return BigUInt(text)
        }
        return nil
    }

    private func boolValue(_ result: [String: Any], index: String, name: String) -> Bool? {
        let value = resultValue(result, index: index, name: name)
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? BigUInt {
            return number != 0
        }
        if let number = value as? Int {
            return number != 0
        }
        return nil
    }

    private func ensureAllowance(token: String, amount: BigUInt, context: Context) async throws {
        guard let tokenAddress = EthereumAddress(token, ignoreChecksum: true),
              let spender = EthereumAddress(context.config.contractAddress, ignoreChecksum: true) else {
            throw RedPacketWeb3Error.invalidParameter(L("代币地址无效"))
        }
        let tokenContract = try EthereumContract(erc20ABI, at: tokenAddress)
        let allowance = try await call(contract: tokenContract, method: "allowance", parameters: [context.from, spender], context: context)["0"] as? BigUInt ?? 0
        guard allowance < amount else { return }
        let approveResult = try await send(contract: tokenContract, method: "approve", parameters: [spender, amount], value: 0, context: context)
        let approveReceipt = try await waitReceipt(hash: approveResult.hash, eth: context.eth)
        try ensureReceiptSucceeded(approveReceipt, action: L("代币授权"))
    }

    private func decimals(for token: String, context: Context) async throws -> Int {
        if token.lowercased() == redPacketZeroAddress { return 18 }
        guard let tokenAddress = EthereumAddress(token, ignoreChecksum: true) else { return 18 }
        let tokenContract = try EthereumContract(erc20ABI, at: tokenAddress)
        if let decimals = try? await call(contract: tokenContract, method: "decimals", parameters: [], context: context)["0"] as? UInt8 {
            return Int(decimals)
        }
        return 18
    }

    private func callContract(method: String, parameters: [Any], context: Context) async throws -> [String: Any] {
        try await call(contract: context.contract, method: method, parameters: parameters, context: context)
    }

    private func call(contract: EthereumContract, method: String, parameters: [Any], context: Context) async throws -> [String: Any] {
        guard let data = contract.method(method, parameters: parameters, extraData: nil) else {
            throw RedPacketWeb3Error.invalidParameter(L("合约方法编码失败"))
        }
        var tx = CodableTransaction(to: contract.address ?? EthereumAddress.contractDeploymentAddress(), chainID: context.config.chainID, data: data)
        tx.from = context.from
        let output = try await context.eth.callTransaction(tx)
        guard let decoded = contract.decodeReturnData(method, data: output) else {
            throw RedPacketWeb3Error.contractDecodeFailed
        }
        return decoded
    }

    private func sendContract(method: String, parameters: [Any], value: BigUInt, context: Context) async throws -> TransactionSendingResult {
        try await send(contract: context.contract, method: method, parameters: parameters, value: value, context: context)
    }

    private func send(contract: EthereumContract, method: String, parameters: [Any], value: BigUInt, context: Context) async throws -> TransactionSendingResult {
        guard let privateKey = context.privateKey else { throw RedPacketWeb3Error.privateKeyUnavailable }
        guard let data = contract.method(method, parameters: parameters, extraData: nil) else {
            throw RedPacketWeb3Error.invalidParameter(L("合约方法编码失败"))
        }
        var tx = CodableTransaction(to: contract.address ?? EthereumAddress.contractDeploymentAddress(), chainID: context.config.chainID, value: value, data: data)
        tx.from = context.from

        // 发交易前的 4 个请求互不依赖（nonce / gasPrice / 预执行校验 / gas 估算），
        // 原来串行发就是 4 个网络往返；并行发出去只等 1 个，领取/发红包都快很多。
        // （estimateGas 不需要 nonce 和 gasPrice，预执行校验只要 from/to/value/data）
        async let nonceTask = nonce(for: context.from, eth: context.eth)
        async let gasPriceTask = context.eth.gasPrice()
        async let preflightTask: Void = preflightTransaction(tx, context: context)
        async let gasLimitTask = estimateGasLimit(method: method, parameters: parameters, tx: tx, context: context)

        tx.nonce = try await nonceTask
        tx.gasPrice = try await gasPriceTask
        // 预执行（eth_call）带回 revert 原因，最准，优先抛它
        try await preflightTask
        tx.gasLimit = try await gasLimitTask

        try tx.sign(privateKey: privateKey)
        guard let raw = tx.encode(for: .transaction) else {
            throw RedPacketWeb3Error.transactionFailed
        }
        return try await sendRawWithRetry(raw, eth: context.eth)
    }

    /// 广播原始交易：对节点侧「临时」错误（如 BTY 网关的 ErrNotSync / 超时 / 连接失败）做有限重试，
    /// revert / 余额不足 / nonce 冲突等确定性错误立即抛出，避免无意义重试。
    private func sendRawWithRetry(_ raw: Data, eth: IEth, attempts: Int = 3) async throws -> TransactionSendingResult {
        var lastError: Error = RedPacketWeb3Error.transactionFailed
        for attempt in 0..<attempts {
            do {
                return try await eth.send(raw: raw)
            } catch {
                lastError = error
                let desc = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                guard Self.isTransientNodeError(desc), attempt < attempts - 1 else { throw error }
                // 线性退避：1.2s / 2.4s
                try? await Task.sleep(nanoseconds: 1_200_000_000 * UInt64(attempt + 1))
            }
        }
        throw lastError
    }

    /// 节点/网关临时错误（可重试）：未同步 / 超时 / 连接类
    private static func isTransientNodeError(_ description: String) -> Bool {
        let lower = description.lowercased()
        if lower.contains("errnotsync") || lower.contains("not sync") { return true }
        if lower.contains("timed out") || lower.contains("timeout") { return true }
        if lower.contains("connection") || lower.contains("network") { return true }
        return false
    }

    /// gas 估算（含 20% 余量）：普通估算失败且是「参数不合法」时，
    /// 再走一次不带 block 参数的估算，最后退到固定值
    private func estimateGasLimit(method: String, parameters: [Any], tx: CodableTransaction, context: Context) async throws -> BigUInt {
        do {
            let estimatedGas = try await context.eth.estimateGas(for: tx)
            return estimatedGas + estimatedGas / BigUInt(5)
        } catch {
            guard isInvalidParamsError(error) else {
                throw RedPacketWeb3Error.transactionReverted(L("交易预检查失败：") + error.localizedDescription)
            }
            let estimatedGas = try await estimateGasWithoutBlockParameter(tx, method: method, parameters: parameters, context: context)
            return estimatedGas + estimatedGas / BigUInt(5)
        }
    }

    private func nonce(for address: EthereumAddress, eth: IEth) async throws -> BigUInt {
        do {
            return try await eth.getTransactionCount(for: address, onBlock: .pending)
        } catch {
            guard isInvalidParamsError(error) else { throw error }
            return try await eth.getTransactionCount(for: address, onBlock: .latest)
        }
    }

    private func fallbackGasLimit(method: String, parameters: [Any]) -> BigUInt {
        if method == "approve" {
            return BigUInt(100_000)
        }
        if method == "claim" || method == "withdraw" {
            return BigUInt(500_000)
        }
        if method == "createFixedRedPacket" || method == "createRandomRedPacket" {
            let token = (parameters.first as? EthereumAddress)?.address.lowercased() ?? redPacketZeroAddress
            let whitelistCount = (parameters.last as? [EthereumAddress])?.count ?? 0
            let base = token == redPacketZeroAddress ? 1_200_000 : 1_800_000
            return BigUInt(base + whitelistCount * 80_000)
        }
        return BigUInt(1_000_000)
    }

    private func transactionObject(_ tx: CodableTransaction, context: Context) -> [String: String] {
        let fromRaw = tx.from?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let from = fromRaw.isEmpty ? context.from.address : fromRaw
        let toAddr = tx.to.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = toAddr.isEmpty ? redPacketZeroAddress : toAddr
        let dataHex = tx.data.toHexString().addHexPrefix()
        var transaction: [String: String] = [
            "from": from,
            "to": to,
            "value": quantityHex(tx.value),
            "data": dataHex.isEmpty ? "0x" : dataHex
        ]
        if let gasPrice = tx.gasPrice, gasPrice > 0 {
            transaction["gasPrice"] = quantityHex(gasPrice)
        }
        return transaction
    }

    private func preflightTransaction(_ tx: CodableTransaction, context: Context) async throws {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_call",
            "params": [transactionObject(tx, context: context), "latest"]
        ]
        guard let json = try await rpcJSON(body: body, context: context) else { return }
        if let error = json["error"] as? [String: Any] {
            throw RedPacketWeb3Error.transactionReverted(rpcErrorMessage(error, fallback: L("交易预执行失败")))
        }
    }

    private func estimateGasWithoutBlockParameter(_ tx: CodableTransaction, method: String, parameters: [Any], context: Context) async throws -> BigUInt {
        let transaction = transactionObject(tx, context: context)

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_estimateGas",
            "params": [transaction]
        ]
        do {
            guard
                let json = try await rpcJSON(body: body, context: context),
                let result = json["result"] as? String,
                let gas = BigUInt(removeHexPrefix(result), radix: 16),
                gas > 0
            else {
                return fallbackGasLimit(method: method, parameters: parameters)
            }
            return gas
        } catch {
            return fallbackGasLimit(method: method, parameters: parameters)
        }
    }

    private func quantityHex(_ value: BigUInt) -> String {
        value == 0 ? "0x0" : String(value, radix: 16).addHexPrefix()
    }

    private func removeHexPrefix(_ value: String) -> String {
        value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
    }

    private func rpcJSON(body: [String: Any], context: Context) async throws -> [String: Any]? {
        let safeRoot = RedPacketJSONSerializationHelper.jsonSafe(body)
        guard let safeBody = safeRoot as? [String: Any], JSONSerialization.isValidJSONObject(safeBody) else {
            throw RedPacketWeb3Error.invalidParameter(L("RPC 请求参数无法序列化"))
        }
        var request = URLRequest(url: context.config.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: safeBody, options: [])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }

    // MARK: - 领取时间（Claimed 事件 → 区块时间戳）

    /// 红包创建时固定 24h 有效期，用于由 `expireAt` 反推创建时间
    private var redPacketLifeTime: BigUInt { 24 * 60 * 60 }

    /// 领取时间表：`[领取人地址(小写): 领取时间]`。
    /// 任一步失败都返回空字典（详情页不显示时间），不影响领取记录本身。
    private func claimTimes(packetId: BigUInt, expireAt: BigUInt, context: Context) async -> [String: Date] {
        guard expireAt > redPacketLifeTime else { return [:] }
        let createdAt = expireAt - redPacketLifeTime
        guard let createdAtSeconds = Double(createdAt.description) else { return [:] }
        let now = Double(Date().timeIntervalSince1970)
        guard createdAtSeconds <= now else { return [:] }
        guard let latestBlock = try? await rpcBlockNumber(context: context) else { return [:] }
        let averageBlockSeconds = await averageBlockSeconds(latestBlock: latestBlock, context: context)

        // 领取只可能发生在 [创建, 过期] 之间：窗口恒定 ≤ 24h（过期很久的红包也只看这 24h，
        // 否则区间会被放大到几十万块而超出分片上限）；再给 20% + 200 块余量，避免估算偏差漏日志
        let expireAtSeconds = Double(expireAt.description) ?? now
        let windowEnd = min(now, expireAtSeconds)
        guard windowEnd > createdAtSeconds else { return [:] }
        let windowSeconds = windowEnd - createdAtSeconds
        let blocksBack = BigUInt((windowSeconds / averageBlockSeconds * 1.2).rounded()) + 200
        let fromBlock = latestBlock > blocksBack ? latestBlock - blocksBack : 0

        // 单次 eth_getLogs 的区块跨度可能被 RPC 限制，按 2 万块分片拉取。
        // 分片之间互不依赖：原来最多 12 个分片**串行**发（最坏就是 12 个网络往返，
        // 领完红包后紧接着跑，很容易把后面的请求一起拖慢），改成一次并发 4 个
        let chunkSize: BigUInt = 20_000
        var ranges = [(from: BigUInt, to: BigUInt)]()
        var cursor = fromBlock
        while cursor <= latestBlock, ranges.count < 12 {
            let end = min(cursor + chunkSize - 1, latestBlock)
            ranges.append((cursor, end))
            cursor = end + 1
        }

        var logs = [EventLog]()
        await withTaskGroup(of: [EventLog].self) { group in
            let maxConcurrent = 4
            var nextIndex = 0
            // 先塞满并发数，之后每回来一个再补一个
            while nextIndex < min(maxConcurrent, ranges.count) {
                let range = ranges[nextIndex]
                group.addTask { (try? await self.rpcLogs(fromBlock: range.from, toBlock: range.to, context: context)) ?? [] }
                nextIndex += 1
            }
            while let part = await group.next() {
                logs.append(contentsOf: part)
                if nextIndex < ranges.count {
                    let range = ranges[nextIndex]
                    group.addTask { (try? await self.rpcLogs(fromBlock: range.from, toBlock: range.to, context: context)) ?? [] }
                    nextIndex += 1
                }
            }
        }
        guard !logs.isEmpty else { return [:] }

        var result = [String: Date]()
        var blockTimestamps = [BigUInt: UInt64]()
        for log in logs {
            let parsed = context.contract.parseEvent(log)
            guard parsed.eventName == "Claimed",
                  let eventId = parsed.eventData?["id"] as? BigUInt,
                  eventId == packetId else { continue }
            guard let indexedUser = indexedAddress(from: log, topicIndex: 2) ?? addressFromAny(parsed.eventData?["user"])
            else { continue }

            let timestamp: UInt64
            if let cached = blockTimestamps[log.blockNumber] {
                timestamp = cached
            } else if let fetched = try? await rpcBlockTimestamp(log.blockNumber, context: context) {
                blockTimestamps[log.blockNumber] = fetched
                timestamp = fetched
            } else {
                continue
            }
            result[indexedUser.address.lowercased()] = Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        return result
    }

    /// 估算平均出块时间（秒）：取「最新块」与「1 万块前」两个采样点；采样失败时按 1s/块兜底
    private func averageBlockSeconds(latestBlock: BigUInt, context: Context) async -> Double {
        let span: BigUInt = latestBlock > 10_000 ? 10_000 : (latestBlock > 1 ? latestBlock - 1 : 0)
        guard span > 0,
              let latestTimestamp = try? await rpcBlockTimestamp(latestBlock, context: context),
              let olderTimestamp = try? await rpcBlockTimestamp(latestBlock - span, context: context) else {
            return 1
        }
        let delta = Double(latestTimestamp) - Double(olderTimestamp)
        guard delta > 0, let spanValue = Double(span.description), spanValue > 0 else { return 1 }
        return delta / spanValue
    }

    private func rpcBlockNumber(context: Context) async throws -> BigUInt {
        let body: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []]
        guard let json = try await rpcJSON(body: body, context: context),
              let result = json["result"] as? String,
              let number = BigUInt(removeHexPrefix(result), radix: 16) else {
            throw RedPacketWeb3Error.contractDecodeFailed
        }
        return number
    }

    private func rpcBlockTimestamp(_ block: BigUInt, context: Context) async throws -> UInt64 {
        let body: [String: Any] = [
            "jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber",
            "params": [quantityHex(block), false]
        ]
        guard let json = try await rpcJSON(body: body, context: context),
              let result = json["result"] as? [String: Any],
              let hexTimestamp = result["timestamp"] as? String,
              let timestamp = UInt64(removeHexPrefix(hexTimestamp), radix: 16) else {
            throw RedPacketWeb3Error.contractDecodeFailed
        }
        return timestamp
    }

    private func rpcLogs(fromBlock: BigUInt, toBlock: BigUInt, context: Context) async throws -> [EventLog] {
        let body: [String: Any] = [
            "jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
            "params": [[
                "address": context.config.contractAddress,
                "fromBlock": quantityHex(fromBlock),
                "toBlock": quantityHex(toBlock),
            ]]
        ]
        guard let json = try await rpcJSON(body: body, context: context) else { return [] }
        if let error = json["error"] as? [String: Any] {
            throw RedPacketWeb3Error.transactionReverted(
                rpcErrorMessage(error, fallback: L("查询领取日志失败")))
        }
        guard let result = json["result"] as? [[String: Any]] else { return [] }
        let data = try JSONSerialization.data(withJSONObject: result, options: [])
        return (try? JSONDecoder().decode([EventLog].self, from: data)) ?? []
    }

    /// 从 indexed 参数 topic 里取出地址（topic 后 20 字节）
    private func indexedAddress(from log: EventLog, topicIndex: Int) -> EthereumAddress? {
        guard log.topics.count > topicIndex else { return nil }
        let topic = log.topics[topicIndex]
        guard topic.count == 32 else { return nil }
        return EthereumAddress(
            "0x" + topic.suffix(20).toHexString(), ignoreChecksum: true)
    }

    private func rpcErrorMessage(_ error: [String: Any], fallback: String) -> String {
        let message = error["message"] as? String
        if let friendly = Self.friendlyRevertMessage(in: message) {
            return friendly
        }
        let code = error["code"].map { "\($0)" }
        return [fallback, code, message].compactMap { $0 }.joined(separator: " ")
    }

    /// 合约 revert 原因 → 本地化文案；未命中返回 nil（按原始报文展示）
    private static func friendlyRevertMessage(in raw: String?) -> String? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        let lowercased = raw.lowercased()
        // 顺序敏感：更具体的原因必须排在更宽泛的前面
        let mapping: [(pattern: String, text: String)] = [
            ("not in whitelist", L("该红包仅限指定好友领取")),
            ("already claimed", L("你已领取过该红包")),
            ("all claimed", L("红包已领完")),
            ("invalid id", L("红包不存在")),
        ]
        return mapping.first(where: { lowercased.contains($0.pattern) })?.text
    }

    private func isInvalidParamsError(_ error: Error) -> Bool {
        if case Web3Error.inputError(let desc) = error {
            return desc.contains("-32602") || desc.localizedCaseInsensitiveContains("Invalid parameters")
        }
        return error.localizedDescription.contains("-32602") ||
               error.localizedDescription.localizedCaseInsensitiveContains("Invalid parameters")
    }

    /// 等交易回执。
    /// 原来固定 2s 一次轮询：链上出回执往往比 2s 快，会白白多等最多 2s（领取红包的等待时间大头之一）。
    /// 改成「先密后疏」（0.3s → 0.6s → 1.2s → 2s 封顶），总时长仍是 60s，请求数也不会变多。
    private func waitReceipt(hash: String, eth: IEth) async throws -> TransactionReceipt {
        guard let hashData = Data(hexString: hash) else { throw RedPacketWeb3Error.transactionFailed }
        let deadline = Date().addingTimeInterval(60)
        var interval: UInt64 = 300_000_000
        while Date() < deadline {
            if let receipt = try? await eth.transactionReceipt(hashData), receipt.status != .notYetProcessed {
                return receipt
            }
            try await Task.sleep(nanoseconds: interval)
            interval = min(interval * 2, 2_000_000_000)
        }
        throw RedPacketWeb3Error.receiptTimeout
    }

    private func ensureReceiptSucceeded(_ receipt: TransactionReceipt, action: String) throws {
        guard receipt.status == .ok else {
            let hash = receipt.transactionHash.toHexString().addHexPrefix()
            throw RedPacketWeb3Error.transactionReverted(String(format: L("%@失败，交易已回滚：%@"), action, hash))
        }
    }

    private func createdPacketId(from receipt: TransactionReceipt, contract: EthereumContract) throws -> String {
        for log in receipt.logs {
            let parsed = contract.parseEvent(log)
            if parsed.eventName == "RedPacketCreated", let id = parsed.eventData?["id"] as? BigUInt {
                return id.description
            }
        }
        throw RedPacketWeb3Error.contractDecodeFailed
    }

    private func claimedAmount(from receipt: TransactionReceipt, contract: EthereumContract) -> BigUInt? {
        for log in receipt.logs {
            let parsed = contract.parseEvent(log)
            if parsed.eventName == "Claimed", let amount = parsed.eventData?["amount"] as? BigUInt {
                return amount
            }
        }
        return nil
    }

    private func claimRecords(packetId: BigUInt, context: Context) async throws -> [RedPacketChainClaimRecord] {
        let result = try await callContract(method: "getClaimRecords", parameters: [packetId], context: context)
        return parseClaimRecords(result["0"] ?? result["records"] ?? result[""] ?? result.values.first)
    }

    private func parseClaimRecords(_ rawRecords: Any?) -> [RedPacketChainClaimRecord] {
        if let records = rawRecords as? [[String: Any]] {
            return records.compactMap { record in
                guard
                    let user = addressValue(record, index: "0", name: "user"),
                    let amount = uintValue(record, index: "1", name: "amount")
                else { return nil }
                return RedPacketChainClaimRecord(user: user.address, amount: amount)
            }
        }

        if let records = rawRecords as? [[Any]] {
            return records.compactMap { record in
                guard record.count >= 2,
                      let user = addressFromAny(record[0]),
                      let amount = uintFromAny(record[1]) else { return nil }
                return RedPacketChainClaimRecord(user: user.address, amount: amount)
            }
        }

        if let records = rawRecords as? [Any] {
            return records.compactMap { record in
                if let record = record as? [String: Any],
                   let user = addressValue(record, index: "0", name: "user"),
                   let amount = uintValue(record, index: "1", name: "amount") {
                    return RedPacketChainClaimRecord(user: user.address, amount: amount)
                }
                if let record = record as? [Any],
                   record.count >= 2,
                   let user = addressFromAny(record[0]),
                   let amount = uintFromAny(record[1]) {
                    return RedPacketChainClaimRecord(user: user.address, amount: amount)
                }
                return nil
            }
        }

        return []
    }

    private func createParams(token: String, totalAmount: BigUInt, totalCount: BigUInt, expireAt: BigUInt, allowedAddresses: [String]) throws -> [Any] {
        guard let tokenAddress = EthereumAddress(token, ignoreChecksum: true) else {
            throw RedPacketWeb3Error.invalidParameter(L("代币地址无效"))
        }
        let addresses = try allowedAddresses.map { address -> EthereumAddress in
            guard let ethAddress = EthereumAddress(address, ignoreChecksum: true) else {
                throw RedPacketWeb3Error.invalidParameter(L("白名单地址无效"))
            }
            return ethAddress
        }
        return [tokenAddress, totalAmount, totalCount, expireAt, addresses]
    }

    private func normalizedTokenAddress(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? redPacketZeroAddress : trimmed
    }

    private func bigUInt(_ value: String, name: String) throws -> BigUInt {
        guard let result = BigUInt(value), result > 0 else {
            throw RedPacketWeb3Error.invalidParameter(String(format: L("%@无效"), name))
        }
        return result
    }

    private func run<T>(_ work: @escaping () async throws -> T, completion: @escaping (Result<T, RedPacketWeb3Error>) -> Void) {
        Task {
            do {
                let value = try await work()
                DispatchQueue.main.async { completion(.success(value)) }
            } catch let error as RedPacketWeb3Error {
                DispatchQueue.main.async { completion(.failure(error)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(.underlying(error))) }
            }
        }
    }
}

private extension Data {
    init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("0x") { hex.removeFirst(2) }
        guard hex.count % 2 == 0 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}

extension FZMCreateLuckyBagVC {
    func sendRedPacketWithWeb3(privateKey: Data) {
        guard let moneyText = bagMoneyTF.text,
              let coin = currentCoin else {
            showToast(L("参数错误"))
            return
        }

        // 专属红包：白名单传所有领取人地址，份数 = 领取人数（每人限领 1 份）
        let whitelistAddresses: [String]
        let totalCount: Int
        if isExclusive {
            guard !exclusiveAddresses.isEmpty,
                  exclusiveAddresses.allSatisfy({ $0.isValidEthereumAddressString }) else {
                showToast(L("未获取到对方地址"))
                return
            }
            whitelistAddresses = exclusiveAddresses
            totalCount = exclusiveAddresses.count
        } else {
            guard let numberText = bagNumberTF.text,
                  let number = Int(numberText),
                  number > 0 else {
                showToast(L("参数错误"))
                return
            }
            whitelistAddresses = []
            totalCount = number
        }

        let service = RedPacketWeb3Service.shared
        let dataSource = RedPacketWalletDataSource.shared

        if dataSource.shouldBlockBTYMainCoinRedPacket(coin) {
            showToast(L("BTY主链原生币暂不支持发红包"))
            return
        }

        let isNativeForRedPacket = dataSource.isRedPacketNativeToken(coin)
        if !isNativeForRedPacket {
            guard let erc20Addr = dataSource.redPacketERC20ContractAddress(for: coin),
                  EthereumAddress(erc20Addr, ignoreChecksum: true) != nil else {
                showToast(L("代币合约地址无效"))
                return
            }
        }

        let chainDecimals = isNativeForRedPacket ? 18 : decimalPlaces
        let totalAmount: BigUInt
        if isRandom {
            guard let amount = service.amountToSmallestUnit(moneyText, decimals: chainDecimals), amount > 0 else {
                showToast(L("金额格式错误"))
                return
            }
            totalAmount = amount
        } else {
            guard let singleAmount = service.amountToSmallestUnit(moneyText, decimals: chainDecimals) else {
                showToast(L("金额格式错误"))
                return
            }
            totalAmount = singleAmount * BigUInt(totalCount)
        }
        guard totalAmount > 0 else { showToast(L("金额格式错误")); return }

        let token: String
        if isNativeForRedPacket {
            token = redPacketZeroAddress
        } else {
            token = dataSource.redPacketERC20ContractAddress(for: coin) ?? redPacketZeroAddress
        }
        let expireAt = BigUInt(Date().addingTimeInterval(24 * 60 * 60).timeIntervalSince1970)
        let remark = bagRemark.text?.isEmpty == false ? (bagRemark.text ?? "") : L("恭喜发财，大吉大利！")
        let packetType: IMRedPacketType = isRandom ? .luck : .common
        let coinName = coin.coin_type ?? ""

        showProgress(with: L("创建红包中..."))
        service.createRedPacket(
            isRandom: isRandom,
            token: token,
            totalAmount: totalAmount,
            totalCount: BigUInt(totalCount),
            expireAt: expireAt,
            allowedAddresses: whitelistAddresses,
            privateKey: privateKey
        ) { [weak self] result in
            guard let self = self else { return }
            self.hideProgress()
            switch result {
            case .success(let packetId):
                // 本地档案记下这个包「专属 / 非专属」（消息体不带白名单标记）：消息 cell 一上屏就显示对，
                // 不用先拼手气再跳专属；同时会持久化，杀进程重进会话依然对
                RedPacketWeb3Service.shared.markKnownPacket(id: packetId, isExclusive: self.isExclusive)
                self.sendCompleteBlock?(Int(coin.coin_coinid), coinName, packetType, packetId, "", remark, self.isTextRedBag)
            case .failure(let error):
                self.showToast(error.localizedDescription)
            }
        }
    }
}

extension FZMRedBagInfoVC {
    @objc func claimRedPacketButtonClick() {
        claimRedPacketFromWeb3()
    }

    func loadRedPacketInfoFromWeb3() {
        loadRedPacketInfoFromWeb3(keepingProgress: false)
    }

    /// 拉链上详情 + 领取记录
    /// - Parameter keepingProgress: 领取成功后的刷新：沿用「领取中…」那个转圈，不要收起再重开
    ///   （否则会「转圈 → toast → 又转圈」，看着像卡住了）
    func loadRedPacketInfoFromWeb3(keepingProgress: Bool) {
        guard !packetId.isEmpty else {
            hideProgress()
            showToast(L("红包ID无效"))
            return
        }

        // 这一次拉取作废之前所有在途请求：旧的慢回包（典型：自己领取前发出的那份）
        // 到达时会被丢掉，不会再把领取记录覆盖回旧数据
        self.redPacketRequestGeneration += 1
        let generation = self.redPacketRequestGeneration

        // 聊天页点红包时通常已经查过同一笔详情（`getRedPacketInfo`），这里先看 TTL 缓存：
        // 命中就立即渲染，不再全屏转圈等 6～8 个 RPC；没有缓存才走原来的「先收起、转圈」。
        let cachedInfo = RedPacketWeb3Service.shared.cachedRedPacketInfo(id: packetId)
        let hasCachedInfo = cachedInfo != nil
        if let cachedInfo = cachedInfo {
            self.latestChainInfo = cachedInfo
            self.applyRedPacketInfo(cachedInfo)
            // 领取记录也命中缓存时直接铺列表，首帧就是完整详情
            if let cachedRecords = RedPacketWeb3Service.shared.cachedRedPacketRecords(id: packetId) {
                self.dataArray = self.makeClaimRecordModels(cachedRecords)
            }
            self.isPacketInfoLoaded = true
            self.updateHeaderViewsVisibility()
            self.tableView.reloadData()
            if !keepingProgress { self.hideProgress() }
        } else {
            // 拉取期间先收起详情（头部 + 「已领取」栏 + 领取记录）：等详情回来后再展示
            self.isPacketInfoLoaded = false
            self.updateHeaderViewsVisibility()
            self.tableView.reloadData()
            if !keepingProgress { showProgress(with: nil) }
        }

        self.isLoadingPacketInfo = true
        RedPacketWeb3Service.shared.getRedPacketInfoWithRecords(id: packetId, knownSymbol: messageCoinName) { [weak self] result in
            guard let self = self else { return }
            // 期间又发起过更新的拉取（典型：领取成功后的刷新）⇒ 这份旧数据不能用
            guard generation == self.redPacketRequestGeneration else { return }
            self.isLoadingPacketInfo = false
            self.hideProgress()
            switch result {
            case .success(let (info, records)):
                self.latestChainInfo = info
                self.applyRedPacketInfo(info)
                // 先用链上记录立即填充列表，再异步补上真实领取时间（Claimed 事件 → 区块时间戳）
                self.dataArray = self.makeClaimRecordModels(records)
                // 未领取成功前页面保持空白（领取中转圈时不露出详情），领取成功后才展示详情；
                // 已经用缓存展示过时保持展示，避免「先显示又收起」的闪烁。
                self.isPacketInfoLoaded = hasCachedInfo || FZMRedBagInfoVC.shouldRevealRedPacketDetail(for: info)
                self.updateHeaderViewsVisibility()
                self.tableView.reloadData()
                // 记录刚拉过，直接复用，省一次 getClaimRecords RPC
                self.reloadClaimRecordsWithTime(records: records, generation: generation)
                // 进页自动领取在等这份详情：拿到就能直接判断，不用再发一次查询
                if self.pendingAutoClaim {
                    self.pendingAutoClaim = false
                    self.autoClaimRedPacketIfNeeded()
                }
            case .failure(let error):
                self.showToast(error.localizedDescription)
            }
        }
    }

    /// 详情内容（头部 / 「已领取」栏 / 领取记录）是否允许展示：
    /// 仅当「自己已领取成功」或「红包本身已不可领」（已领完 / 已过期 / 已取回 / 专属红包但当前地址不在白名单）时展示；
    /// 可领取但自己还没领到时保持空白（领取流程中转圈，领取成功后再一次性展示），避免详情先出现又被收起。
    static func shouldRevealRedPacketDetail(for info: RedPacketChainInfo) -> Bool {
        if info.userClaimed { return true }
        if info.status != .active { return true }
        return !info.canClaim
    }

    func loadClaimRecordsFromWeb3() {
        guard !packetId.isEmpty else { return }
        reloadClaimRecordsWithTime()
    }

    /// 拉取「领取记录 + 领取时间」并刷新列表
    /// - Parameters:
    ///   - records: 已经拿到的领取记录（详情接口刚返回的），传了就不再重复拉一次
    ///   - generation: 所属的拉取代次（详情拉取里顺带刷新时传它，避免自己作废自己）；不传则新开一代
    func reloadClaimRecordsWithTime(records: [RedPacketChainClaimRecord]? = nil, generation: Int? = nil) {
        let token: Int
        if let generation = generation {
            token = generation
        } else {
            redPacketRequestGeneration += 1
            token = redPacketRequestGeneration
        }
        RedPacketWeb3Service.shared.getClaimRecordsWithTime(
            id: packetId,
            knownRecords: records,
            knownExpireAt: latestChainInfo?.expireAt
        ) { [weak self] result in
            guard let self = self else { return }
            // 期间又发起过更新的拉取（典型：领取成功后刷详情）⇒ 这份旧记录不能再用，
            // 否则「1 条记录的旧结果」会把「2 条记录的新结果」覆盖掉
            guard token == self.redPacketRequestGeneration else { return }
            switch result {
            case .success(let records):
                self.dataArray = self.makeClaimRecordModels(records)
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.localizedDescription)
            }
        }
    }

    // MARK: - 详情静默刷新 + 停留期间轻量轮询

    /// 页面出现时：先静默刷一次（离开期间别人领取了也能显示出来），再启动轻量轮询
    func startRedPacketClaimWatch() {
        // 本地只读模式（安卓端专属红包）没有链上 ID：既不轮询也不静默刷新
        guard localExclusiveCSV.isEmpty else { return }
        refreshRedPacketDetailSilently()
        guard redPacketClaimWatchTimer == nil else { return }
        redPacketClaimWatchTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.pollRedPacketProgress()
        }
    }

    /// 页面离开时停掉轮询（不要在后台一直请求）
    func stopRedPacketClaimWatch() {
        redPacketClaimWatchTimer?.invalidate()
        redPacketClaimWatchTimer = nil
    }

    /// 静默刷新详情 + 领取记录：不弹转圈、不收起已有内容（避免闪烁），
    /// 用于「重新回到页面」和「轮询发现有人新领取」两种场景。
    func refreshRedPacketDetailSilently() {
        // 详情还没展示过（首次加载 / 领取中转圈）时不打扰，交给正常流程
        guard isPacketInfoLoaded, !isLoadingPacketInfo else { return }
        redPacketRequestGeneration += 1
        let generation = redPacketRequestGeneration
        isLoadingPacketInfo = true
        RedPacketWeb3Service.shared.getRedPacketInfoWithRecords(id: packetId, knownSymbol: messageCoinName) { [weak self] result in
            guard let self = self else { return }
            guard generation == self.redPacketRequestGeneration else { return }
            self.isLoadingPacketInfo = false
            // 注意：这里不动转圈（`hideProgress`），否则「取回中…」这类写入操作的转圈会被静默刷新收起
            guard case .success(let (info, records)) = result else { return }
            self.latestChainInfo = info
            self.applyRedPacketInfo(info)
            self.dataArray = self.makeClaimRecordModels(records)
            self.tableView.reloadData()
            // 先显示链上记录，再异步补领取时间
            self.reloadClaimRecordsWithTime(records: records, generation: generation)
        }
    }

    /// 轻量轮询：只发 1 次 `getRedPacket` 看领取份数有没有变（变了才拉完整详情）；
    /// 红包已领完 / 已过期后自动停下。
    func pollRedPacketProgress() {
        guard isPacketInfoLoaded, !isLoadingPacketInfo, let info = latestChainInfo else { return }
        guard info.status == .active else {
            stopRedPacketClaimWatch()
            return
        }
        RedPacketWeb3Service.shared.getRedPacketClaimProgress(id: packetId) { [weak self] result in
            guard let self = self, case .success(let progress) = result else { return }
            guard let current = self.latestChainInfo else { return }
            let expired = BigUInt(UInt64(Date().timeIntervalSince1970)) >= progress.expireAt
            if progress.claimedCount != current.claimedCount || expired {
                self.refreshRedPacketDetailSilently()
            }
        }
    }

    /// 领取记录 → 列表模型；时间用 `Claimed` 事件时间，链表链上拿不到时不显示（不再拿当前时间充数）
    private func makeClaimRecordModels(_ records: [RedPacketChainClaimRecord]) -> [IMRedPacketReceiveModel] {
        records.map { record in
            let model = IMRedPacketReceiveModel()
            model.userId = record.user
            model.userName = record.user
            model.coinName = displayCoinName
            // 与头图用**同一个格式化入口**（4 位小数）：
            // `amount` 只给旧逻辑用，`amountDisplayText` 才是列表真正显示的文案
            //（`FZMRedBagReceiveCell` 优先用它）—— 两者都从同一串派生，不会再出现小数位不一致
            let amountText = RedPacketWeb3Service.shared.displayAmount(record.amount, decimals: displayDecimals)
            model.amount = Float(amountText) ?? 0
            model.amountDisplayText = "\(amountText) \(displayCoinName)"
            model.claimedAt = record.claimedAt
            if let claimedAt = record.claimedAt {
                model.createdAt = claimedAt
            }
            return model
        }
    }

    func claimRedPacketFromWeb3() {
        guard !packetId.isEmpty else { return }
        requestRedPacketPrivateKey { [weak self] privateKey in
            self?.claimRedPacketFromWeb3(privateKey: privateKey)
        }
    }

    func claimRedPacketFromWeb3(privateKey: Data) {
        guard !packetId.isEmpty else { return }
        showProgress(with: L("领取中..."))
        RedPacketWeb3Service.shared.claimRedPacket(id: packetId, privateKey: privateKey) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let amount):
                let amountText = RedPacketWeb3Service.shared.format(amount, decimals: self.displayDecimals)
                self.showToast(String(format: L("成功领取%@%@"), amountText, self.displayCoinName))
                // 领取成功后**不收转圈**，接着刷详情（结束后统一收起）：
                // 否则是「转圈 → toast → 又转圈」，看起来像没领成功
                self.loadRedPacketInfoFromWeb3(keepingProgress: true)
            case .failure(let error):
                self.hideProgress()
                self.showToast(error.localizedDescription)
            }
        }
    }

    func autoClaimRedPacketIfNeeded() {
        guard shouldAutoClaim, !didAutoClaim else { return }
        // 进页时（viewDidLoad）已经在拉详情了：等那一份回来直接用，
        // 原来这里会再发一遍完整查询，等于白等一个网络往返（而且两份查询是并发的）
        if let info = latestChainInfo {
            didAutoClaim = true
            startAutoClaimIfPossible(info)
            return
        }
        if isLoadingPacketInfo {
            pendingAutoClaim = true
            return
        }
        didAutoClaim = true
        RedPacketWeb3Service.shared.getRedPacketInfo(id: packetId) { [weak self] result in
            guard let self = self, case .success(let info) = result else { return }
            self.startAutoClaimIfPossible(info)
        }
    }

    /// canClaim 已包含白名单校验：专属红包下发起人 / 非白名单用户不自动发起交易
    private func startAutoClaimIfPossible(_ info: RedPacketChainInfo) {
        guard info.canClaim else { return }
        // 私钥统一由 `WalletPrivateKeyStore` 提供：
        // · 从聊天页带下来的那一把（用户在面板上刚输过）→ 直接用，不再二次弹框；
        // · 其它路径（直接进详情页）→ 命中内存缓存就直接领，没有缓存才弹**一次**密码。
        if let privateKey = self.autoClaimPrivateKey {
            self.autoClaimPrivateKey = nil
            self.claimRedPacketFromWeb3(privateKey: privateKey)
        } else {
            self.claimRedPacketFromWeb3()
        }
    }

    private func applyRedPacketInfo(_ info: RedPacketChainInfo) {
        // 记录页/旧消息可能把合约地址当 coinName 传进来：地址不算币名，改用链上解析出的 symbol
        let coinName = (messageCoinName.isEmpty || redPacketLooksLikeContractAddress(messageCoinName))
            ? info.tokenSymbol
            : messageCoinName
        displayCoinName = coinName
        displayDecimals = info.decimals
        // 头部不显示头像（链上只有 creator 的 0x 地址、反查不到用户）；
        // 昵称优先用聊天页解析出的真实昵称，拿不到才回落到链上短地址；
        // 链上 creator 为空时（安卓端专属红包走名片通道，本就没有 creator）再用会话地址的短串兜底，
        // 避免显示成光秃秃的「的红包」
        var nameFallback = shortAddress(info.creator)
        if nameFallback.isEmpty {
            nameFallback = shortAddress(senderAddress)
        }
        let displayName = displayNameForHeader(fallback: nameFallback, creator: info.creator)
        accountLab.text =
            displayName + L("的红包")
            + (info.hasWhitelist ? " · " + L("专属红包") : "")
        remarkLab.isHidden = true
        // 没有链上红包ID时（安卓端专属红包走的是名片消息，消息里没有 ID）把这一行隐掉，
        // 否则会显示成光禿禿的「· 红包ID 」
        hidesPacketIdRow = info.id.isEmpty
        if info.id.isEmpty {
            packetIdLab.attributedText = nil
        } else {
            packetIdLab.attributedText = FZMRedBagInfoVC.makePacketIdText(info.id)
        }

        if info.userClaimed, let claimed = info.userClaimedAmount {
            // 保留 4 位小数，与下面的领取列表一致（原来走 `format` 默认的 8 位，比列表多出一截）
            totalLab.text = "\(RedPacketWeb3Service.shared.displayAmount(claimed, decimals: info.decimals)) \(coinName)"
        } else {
            switch info.status {
            case .active:
                // 自己还没领取成功时不显示任何金额（避免看起来像「红包总数」），
                // 领取成功后由上面的 userClaimed 分支显示实际领到的金额。
                // 例外：**我发的**红包、且还没人领时，这一行空着很难看 ⇒ 显示「等待他人领取」。
                // ⚠️ 必须带上 `claimedCount == 0`：有人领了还写「等待」就是误导
                //（那种情况下面那条「已领取N个」栏会顶上）。
                // 别人发给我的红包空着是对的：那是在提示"你还没领"，由下面的领取按钮承担。
                if isSelfCreator(info.creator), info.claimedCount == 0 {
                    totalLab.text = L("等待他人领取")
                } else {
                    totalLab.text = ""
                }
            case .claimedAll:
                totalLab.text = L("红包已领完")
            case .expired:
                totalLab.text = L("红包已过期")
            case .expiredWithdrawn:
                totalLab.text = L("过期已取回")
            case .withdrawn:
                totalLab.text = L("红包已取回")
            }
        }

        // 领取进度：显示「当前已领取份数 + 剩余份数」，不显示总份数；
        // 还没人领取成功（0 份）时置空，领取成功后（claim 回来会重新拉详情）再显示。
        if info.claimedCount > 0 {
            remainLab.text = String(
                format: L("已领取%@个，余%@个"),
                info.claimedCount.description,
                info.remainingCount.description
            )
        } else {
            remainLab.text = ""
        }
        claimBtn.isHidden = !info.canClaim
        refreshRedBagNavigationRightItems(chainInfo: info)
    }

    /// 「本地数据」模式：安卓端发的「专属红包」走的是**名片消息兼容通道**（type = -1），
    /// csv 放在 `contactAvatar` 里（`领取人,金额,时间`）。
    /// 那条消息里**没有链上红包 ID / 币种 / 份数**，所以这里造一份只读详情直接渲染，**全程不查链**：
    /// - `claimedCount == totalCount` ⇒ 状态是「已领完」，头部显示「红包已领完」（而不是伪造一个金额）
    /// - `userClaimed = false` ⇒ 不会把它当成「我领到的金额」，也永远不会出现领取按钮
    /// - `id` 为空 ⇒ 详情页会隐藏「红包ID」那一行（见 `hidesPacketIdRow`）
    func applyLocalExclusiveRedPacket() {
        let parts = localExclusiveCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let claimer = parts.count > 0 ? parts[0] : ""
        let amountText = parts.count > 1 ? parts[1] : ""
        let timeText = parts.count > 2 ? parts[2] : ""

        let info = RedPacketChainInfo(
            id: "",
            creator: "",
            token: redPacketZeroAddress,
            type: .fixed,
            totalAmount: 0,
            totalCount: 1,
            claimedCount: 1,
            expireAt: 0,
            whitelistCount: 1,
            amountPerShare: 0,
            withdrawn: false,
            claimedAmount: 0,
            remainingAmount: 0,
            tokenSymbol: "",
            userClaimed: false,
            userClaimedAmount: nil,
            decimals: 0,
            userInWhitelist: false
        )

        redPacketRequestGeneration += 1
        isLoadingPacketInfo = false
        latestChainInfo = info
        isPacketInfoLoaded = FZMRedBagInfoVC.shouldRevealRedPacketDetail(for: info)
        applyRedPacketInfo(info)

        // 领取记录只有一条：金额/时间**直接透传 csv 里的显示文案**
        //（csv 里是给人看的字符串，转 Float/Date 会丢格式或解析失败）
        if claimer.isEmpty && amountText.isEmpty {
            dataArray = []
        } else {
            let model = IMRedPacketReceiveModel()
            model.userId = claimer
            model.userName = claimer
            model.amount = 0
            model.coinName = ""
            model.amountDisplayText = amountText
            model.timeDisplayText = timeText
            dataArray = [model]
        }

        updateHeaderViewsVisibility()
        tableView.reloadData()
    }

    /// 右上角：过期未取回、仍有剩余、且当前钱包为链上创建者（发红包地址）时显示「过期取回」，可与「红包记录」并存
    func refreshRedBagNavigationRightItems(chainInfo: RedPacketChainInfo?) {
        var items: [UIBarButtonItem] = []
        if let info = chainInfo, Self.shouldOfferWithdrawExpired(for: info) {
            let btn = UIButton(type: .custom)
            btn.setTitle(L("过期取回"), for: .normal)
            btn.titleLabel?.font = UIFont.boldFont(14)
            btn.setTitleColor(RP.onRedStrong, for: .normal)
            btn.addTarget(self, action: #selector(withdrawRedPacketNavButtonTapped), for: .touchUpInside)
            items.append(UIBarButtonItem(customView: btn))
        }
        if isShowRecord {
            let btn = UIButton(type: .custom)
            btn.addTarget(self, action: #selector(pushToRecord), for: .touchUpInside)
            btn.setTitle(L("红包记录"), for: .normal)
            btn.titleLabel?.font = UIFont.boldFont(14)
            btn.setTitleColor(RP.onRedStrong, for: .normal)
            items.append(UIBarButtonItem(customView: btn))
        }
        navigationItem.rightBarButtonItems = items.isEmpty ? nil : items
    }

    /// 规范化地址后再比较，避免 checksum / 空白符导致误判；仅当「当前选中钱包地址」与红包链上 `creator` 一致时才允许展示取回入口。
    private static func ethereumAddressesEqual(_ a: String?, _ b: String?) -> Bool {
        guard let na = normalizedEthereumAddressString(a), let nb = normalizedEthereumAddressString(b) else { return false }
        return na == nb
    }

    private static func normalizedEthereumAddressString(_ raw: String?) -> String? {
        let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s.isEmpty else { return nil }
        if let addr = EthereumAddress(s, ignoreChecksum: true) {
            return addr.address.lowercased()
        }
        return s.lowercased()
    }

    private static func shouldOfferWithdrawExpired(for info: RedPacketChainInfo) -> Bool {
        guard info.status == .expired, !info.withdrawn else { return false }
        guard info.remainingAmount > 0 else { return false }
        let current = RedPacketWeb3Service.shared.currentAddress()
        guard ethereumAddressesEqual(info.creator, current) else { return false }
        return true
    }

    @objc func withdrawRedPacketNavButtonTapped() {
        requestRedPacketPrivateKey(title: L("请输入密聊密码以取回过期红包余额")) { [weak self] privateKey in
            self?.withdrawRedPacketFromWeb3(privateKey: privateKey)
        }
    }

    func withdrawRedPacketFromWeb3(privateKey: Data) {
        guard !packetId.isEmpty else { return }
        showProgress(with: L("取回中..."))
        RedPacketWeb3Service.shared.withdrawRedPacket(id: packetId, privateKey: privateKey) { [weak self] result in
            guard let self = self else { return }
            self.hideProgress()
            switch result {
            case .success:
                self.showToast(L("取回成功"))
                // 优化：getRedPacketInfoWithRecords 一次调用即返回详情+记录
                self.loadRedPacketInfoFromWeb3()
            case .failure(let error):
                self.showToast(error.localizedDescription)
            }
        }
    }

    private func shortAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return String(address.prefix(4)) + "****" + String(address.suffix(4))
    }

    /// 取私钥：命中 `WalletPrivateKeyStore` 内存缓存直接回调（**不弹密码**），否则弹一次密码。
    /// 用户取消 ⇒ 静默什么都不做；其它失败 ⇒ toast 提示。
    private func requestRedPacketPrivateKey(title: String = L("请输入密聊密码"),
                                            completion: @escaping (Data) -> Void) {
        WalletPrivateKeyStore.shared.requestPrivateKey(title: title, success: { privateKey in
            completion(privateKey)
        }, failure: { [weak self] error in
            switch error {
            case .cancelled:
                break
            default:
                FZMLog("红包取私钥失败：\(error.message)")
                self?.showToast(error.message)
            }
        })
    }
}

extension FZMRedBagRecordView {
    func loadRedPacketRecordsFromWeb3(page: Int, replace: Bool) {
        if replace {
            self.page = 0
            showProgress(with: nil)
        }
        let filterDate = startTime.flatMap { Date(timeIntervalSince1970: TimeInterval($0) / 1000) } ?? Date()
        let year = filterDate.year
        let month = isAllYearFilter ? 0 : filterDate.month
        let symbol: String
        if let coinId = coinId, let coin = PWDataBaseManager.shared().queryCoinBased(onCoinId: coinId) as? LocalCoin {
            symbol = coin.coin_type ?? ""
        } else {
            symbol = ""
        }

        RedPacketWeb3Service.shared.getMyRedPacketInfos(
            asReceiver: operation == .receive,
            year: year,
            month: month,
            symbol: symbol,
            page: page,
            pageSize: pageSize
        ) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingRecords = false
            self.hideProgress()
            self.tableView.mj_footer?.endRefreshing()

            switch result {
            case .success(let pageResult):
                let infos = pageResult.infos
                let total = pageResult.total
                let isReceive = self.operation == .receive
                let packets = infos.map { info -> IMRedPacketModel in
                    let amount = RedPacketWeb3Service.shared.format(info.totalAmount, decimals: info.decimals)
                    var json: [String: Any] = [
                        "packetId": info.id,
                        "type": info.type == .random ? IMRedPacketType.luck.rawValue : IMRedPacketType.common.rawValue,
                        "senderId": info.creator,
                        "senderUid": info.creator,
                        "senderAvatar": "",
                        "senderName": info.creator,
                        "coinId": 0,
                        "coinName": info.tokenSymbol,
                        "amount": Float(amount) ?? 0,
                        "size": Int(info.totalCount.description) ?? 0,
                        "toUsers": "",
                        "remain": Int(info.remainingCount.description) ?? 0,
                        "status": self.socketStatus(for: info).rawValue,
                        "remark": L("恭喜发财，大吉大利！"),
                        "packetUrl": "",
                        "createdAt": Self.createdAtMilliseconds(fromExpireAt: info.expireAt)
                    ]
                    if isReceive {
                        let claimedAmount = info.userClaimedAmount ?? 0
                        let revStatus: Int
                        switch info.status {
                        case .active:
                            revStatus = 1
                        case .claimedAll:
                            revStatus = 2
                        default:
                            revStatus = 3
                        }
                        let revAmountStr = RedPacketWeb3Service.shared.format(claimedAmount, decimals: info.decimals)
                        let revInfo: [String: Any] = [
                            "userId": info.creator,
                            "userName": info.creator,
                            "coinName": info.tokenSymbol,
                            "coinId": 0,
                            "amount": Float(revAmountStr) ?? 0,
                            "status": revStatus,
                            "createdAt": Self.createdAtMilliseconds(fromExpireAt: info.expireAt),
                            "userAvatar": ""
                        ]
                        json["revInfo"] = revInfo
                    }
                    let packet = IMRedPacketModel(recordJson: JSON(json))
                    // 专属红包：链上带白名单，列表打标
                    packet.isExclusive = info.hasWhitelist
                    return packet
                }
                // 列表按时间降序（展示时间 = 链上 expireAt - 24h，与 cell 里显示的发放时间一致）
                let sortedPackets = packets.sorted { $0.createdAt > $1.createdAt }
                let pageSum = Float(infos.reduce(BigUInt(0)) { $0 + $1.totalAmount }.description) ?? 0

                if replace || self.model == nil {
                    let model = IMRedPacketRecordListModel(with: JSON([:]))
                    model.count = total
                    model.redPackets = sortedPackets
                    model.coinName = sortedPackets.first?.coinName ?? ""
                    model.sum = pageSum
                    self.model = model
                } else if let model = self.model {
                    model.redPackets.append(contentsOf: sortedPackets)
                    model.redPackets.sort { $0.createdAt > $1.createdAt }
                    model.count = total
                    model.sum += pageSum
                    if model.coinName.isEmpty {
                        model.coinName = model.redPackets.first?.coinName ?? ""
                    }
                    // 重新赋值触发 didSet（刷新表头 / 空态）
                    self.model = model
                }
                self.page = page
                self.tableView.reloadData()
                let loaded = self.model?.redPackets.count ?? 0
                // 已加载条数 >= 总数 / 本页一条都没解析出来 ⇒ 没有更多了，隐藏 footer
                self.tableView.mj_footer?.isHidden = (loaded >= total) || pageResult.infos.isEmpty
            case .failure(let error):
                if !replace {
                    // 失败时回退页码，用户上拉重试仍会请求同一页
                    self.page = max(0, page - 1)
                }
                self.tableView.mj_footer?.isHidden = true
                self.showToast(error.localizedDescription)
            }
        }
    }

    private func socketStatus(for info: RedPacketChainInfo) -> SocketLuckyPacketStatus {
        switch info.status {
        case .active:
            return .normal
        case .claimedAll:
            return .receiveAll
        case .expired, .withdrawn, .expiredWithdrawn:
            return .past
        }
    }

    /// `IMRedPacketModel` 的 `createdAt` 为毫秒；链上 `expireAt` 为秒。创建红包时一般为「创建时刻 +24h」，故列表展示的发放时间取「过期前一天」即 `expireAt - 24h`。
    private static func createdAtMilliseconds(fromExpireAt expireAt: BigUInt) -> Double {
        let expireSec = TimeInterval(expireAt.description) ?? 0
        let createdSec = max(0, expireSec - 24 * 60 * 60)
        return createdSec * 1000
    }
}
