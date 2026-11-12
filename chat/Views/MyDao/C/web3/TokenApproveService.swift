//
//  TokenApproveService.swift
//  chat
//
//  Created by on 2024/6/4.
//

import Foundation
import web3swift
import Web3Core
import BigInt

/// 授权管理使用的链配置（仅保留授权查询/撤销需要的字段）
struct TokenChainConfig {
    let netRaw: Int
    let nativeSymbol: String
    let fallbackRPCs: [String]

    /// 用户在「选择网络 → 编辑」里填的自定义地址优先，其余走兜底池。
    var rpcCandidates: [String] {
        var list: [String] = []
        if let net = NetType(rawValue: netRaw),
           let custom = DAppRPCSettings.customURLString(for: net),
           let url = DAppRPCSettings.validated(custom) {
            list.append(url.absoluteString)
        }
        for rpc in fallbackRPCs where !list.contains(rpc) {
            list.append(rpc)
        }
        return list
    }

    static let bityuan = TokenChainConfig(
        netRaw: 0,
        nativeSymbol: "BTY",
        fallbackRPCs: ["https://mainnet.bityuan.com/eth"]
    )

    static let ethereum = TokenChainConfig(
        netRaw: 1,
        nativeSymbol: "ETH",
        fallbackRPCs: [
            "https://ethereum-rpc.publicnode.com",
            "https://eth.drpc.org",
            "https://rpc.mevblocker.io",
            "https://eth-mainnet.public.blastapi.io",
        ]
    )

    static let bnb = TokenChainConfig(
        netRaw: 2,
        nativeSymbol: "BNB",
        fallbackRPCs: [
            "https://bsc-dataseed.bnbchain.org/",
            "https://bsc.publicnode.com",
        ]
    )

    static let all: [TokenChainConfig] = [bityuan, ethereum, bnb]

    static func config(forNet raw: Int) -> TokenChainConfig? {
        all.first { $0.netRaw == raw }
    }

    static func current() -> TokenChainConfig {
        let raw = Int(PWAppsettings.instance().getAPPNetType().rawValue)
        return config(forNet: raw) ?? bnb
    }
}

/// 授权查询只关心这三条链
enum TokenApproveChain: String {
    case eth = "ETH"
    case bnb = "BNB"
    case bty = "BTY"
    /// 币种里判断不出链时，退回「当前选择的网络」
    case current = "CUR"

    var config: TokenChainConfig {
        switch self {
        case .eth:  return TokenChainConfig.ethereum
        case .bnb:  return TokenChainConfig.bnb
        case .bty:  return TokenChainConfig.bityuan
        case .current: return TokenChainConfig.current()
        }
    }

    /// 按顺序尝试，第一个能正常返回 `eth_call` 的节点就用它。
    /// ⚠️ 不能用 `AppExploreWebRPC.eth`（flashbots）：它只接受交易广播，
    ///    `eth_call` 直接 403 —— 这正是「授权页看不到 ETH 链授权」的根因。
    var rpcURLs: [String] { config.rpcCandidates }

    var gasSymbol: String {
        switch self {
        case .eth: return "ETH"
        case .bnb: return "BNB"
        case .bty: return "BTY"
        case .current: return config.nativeSymbol
        }
    }
}

struct TokenApprovalInfo {
    let tokenSymbol: String
    let tokenAddress: String
    let spender: String
    let spenderName: String
    let allowance: BigUInt
    let decimals: Int
    let approveTime: Date?
    /// 该授权所在链（撤销时按这条链的节点池发交易）
    let chain: TokenApproveChain
}

class TokenApproveService {
    static let shared = TokenApproveService()

    /// 币种 → 链
    static func chain(for coin: LocalCoin) -> TokenApproveChain {
        let raw = "\((coin.coin_chain ?? "")) \((coin.coin_type ?? ""))".uppercased()
        if raw.contains("BTY") || raw.contains("BITYUAN") { return .bty }
        if raw.contains("BSC") || raw.contains("BNB") { return .bnb }
        if raw.contains("ETH") { return .eth }
        return .current
    }

    /// 钱包里每条链上有多少个可查的合约代币（列表页用来解释「为什么没有记录」）
    static func tokenCounts(in coinList: [LocalCoin]) -> [(chain: TokenApproveChain, count: Int)] {
        var counts: [TokenApproveChain: Int] = [:]
        var seen = Set<String>()
        for coin in coinList {
            guard coin.coin_type_nft == 10,
                  let raw = coin.coin_pubkey?.trimmingCharacters(in: .whitespacesAndNewlines),
                  raw.count == 42, raw.lowercased().hasPrefix("0x") else { continue }
            let chain = chain(for: coin)
            let key = chain.rawValue + raw.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            counts[chain, default: 0] += 1
        }
        let order: [TokenApproveChain] = [.eth, .bnb, .bty, .current]
        return order.compactMap { chain in
            guard let count = counts[chain], count > 0 else { return nil }
            return (chain, count)
        }
    }

    /// 各链常见 DEX / 合约 spender 地址
    private func spenders(for chain: TokenApproveChain) -> [(address: String, name: String)] {
        var list: [(address: String, name: String)]
        switch chain {
        case .bnb:
            list = [
                ("0x10ED43C718714eb63d5aA57B78B54704E256024E", "PancakeSwap Router"),
                ("0x13f4EA83D0bd40E75C8222255bc855a974568Dd4", "PancakeSwap Smart Router"),
                ("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "Uniswap V2 Router"),
                ("0x1111111254EEB25477B68fb85Ed929f73A960582", "1inch Router"),
            ]
        case .bty:
            list = [
                ("0xf7f7b487c0e0afdbe5681c1d2f4cec7c6e0daa8f", "PMM DEX"),
            ]
        case .eth, .current:
            list = [
                ("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "Uniswap V2 Router"),
                ("0xE592427A0AEce92De3Edee1F18E0157C05861564", "Uniswap V3 Router"),
                ("0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45", "Uniswap Universal Router"),
                ("0x1111111254EEB25477B68fb85Ed929f73A960582", "1inch Router V5"),
                ("0xDef1C0ded9bec7F1a1670819833240f027b25EfF", "0x Exchange"),
                ("0x6131B5fae19EA4f9D964eAc0408E4408b66337b5", "KyberSwap"),
                ("0x10ED43C718714eb63d5aA57B78B54704E256024E", "PancakeSwap Router"),
            ]
        }
        return list
    }

    /// 查询单个代币对单个 spender 的授权额度
    func queryAllowance(tokenAddress: String,
                        ownerAddress: String,
                        spenderAddress: String,
                        rpcURL: String) async throws -> BigUInt {
        guard let owner = EthereumAddress(ownerAddress, ignoreChecksum: true),
              let token = EthereumAddress(tokenAddress, ignoreChecksum: true),
              let spender = EthereumAddress(spenderAddress, ignoreChecksum: true),
              let url = URL(string: rpcURL) else {
            throw NSError(domain: "TokenApprove", code: -1, userInfo: [NSLocalizedDescriptionKey: L("无效地址")])
        }
        
        let web3 = try await Web3.new(url)
        let erc20 = ERC20(web3: web3, provider: web3.provider, address: token)
        return try await erc20.getAllowance(originalOwner: owner, delegate: spender)
    }

    // MARK: - 裸 RPC（批量 eth_call）

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 25
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    private static func addressWord(_ address: String) -> String {
        let hex = address.lowercased().replacingOccurrences(of: "0x", with: "")
        return String(repeating: "0", count: max(0, 64 - hex.count)) + hex.suffix(64)
    }

    private func post(_ body: Any, to rpcURL: String) async throws -> Any {
        guard let url = URL(string: rpcURL) else {
            throw NSError(domain: "TokenApprove", code: -1, userInfo: [NSLocalizedDescriptionKey: L("无效地址")])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: "RPC HTTP \(http.statusCode)"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] ?? (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: "RPC 返回异常"])
        }
        if let error = json["error"] as? [String: Any] {
            throw NSError(domain: "TokenApprove", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: (error["message"] as? String) ?? "RPC error"])
        }
        return json
    }

    /// 一次请求查完某代币对所有 spender 的授权（批量 `eth_call`）。
    /// 任何一个节点整体不可用（403 / 拒绝批量）都会抛出，由调用方换下一个节点。
    private func allowances(token: String,
                            owner: String,
                            spenders: [(address: String, name: String)],
                            rpcURL: String) async throws -> [BigUInt] {
        var payload: [[String: Any]] = []
        for (index, spender) in spenders.enumerated() {
            let data = "0xdd62ed3e" + Self.addressWord(owner) + Self.addressWord(spender.address)
            payload.append([
                "jsonrpc": "2.0",
                "id": index,
                "method": "eth_call",
                "params": [["to": token, "data": data], "latest"],
            ])
        }
        guard let url = URL(string: rpcURL) else {
            throw NSError(domain: "TokenApprove", code: -1, userInfo: [NSLocalizedDescriptionKey: L("无效地址")])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (data, response) = await (try? session.data(for: request)) ?? (Data(), nil as URLResponse?)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: "RPC HTTP \(http.statusCode)"])
        }
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: "RPC 不支持批量调用"])
        }
        var values = Array<BigUInt?>(repeating: nil, count: spenders.count)
        for item in list {
            guard let index = (item["id"] as? NSNumber)?.intValue, index >= 0, index < values.count,
                  let hex = item["result"] as? String else { continue }
            let body = hex.replacingOccurrences(of: "0x", with: "")
            values[index] = body.isEmpty ? BigUInt(0) : BigUInt(body, radix: 16)
        }
        // 一个都没返回结果 ⇒ 这个节点不可用
        guard values.contains(where: { $0 != nil }) else {
            throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: "RPC 无返回"])
        }
        return values.map { $0 ?? BigUInt(0) }
    }

    /// 代币精度（失败按 18 处理）
    private func decimals(token: String, rpcURL: String) async -> Int {
        let body: [String: Any] = [
            "jsonrpc": "2.0", "id": 1, "method": "eth_call",
            "params": [["to": token, "data": "0x313ce567"], "latest"],
        ]
        guard let json = try? await post(body, to: rpcURL),
              let dict = json as? [String: Any],
              let hex = dict["result"] as? String,
              let value = BigUInt(hex.replacingOccurrences(of: "0x", with: ""), radix: 16),
              value > 0, value <= 36 else {
            return 18
        }
        return Int(value)
    }

    /// 查某代币在指定链上的全部授权（逐节点回退）
    private func approvals(token: String,
                           symbol: String,
                           chain: TokenApproveChain,
                           owner: String) async -> [TokenApprovalInfo] {
        let spenders = spenders(for: chain)
        for rpcURL in chain.rpcURLs {
            guard let values = try? await allowances(token: token, owner: owner, spenders: spenders, rpcURL: rpcURL),
                  values.count == spenders.count else { continue }
            let digit = await decimals(token: token, rpcURL: rpcURL)
            var results: [TokenApprovalInfo] = []
            for (index, value) in values.enumerated() where value > 0 {
                results.append(TokenApprovalInfo(tokenSymbol: symbol,
                                                 tokenAddress: token,
                                                 spender: spenders[index].address,
                                                 spenderName: spenders[index].name,
                                                 allowance: value,
                                                 decimals: digit,
                                                 approveTime: nil,
                                                 chain: chain))
            }
            return results
        }
        return []
    }

    
    /// 查询当前钱包所有代币在所有网络上的授权情况
    ///
    /// 与旧实现的区别：
    ///  1. **按币种所属链**去查（旧实现对每个币都打 3 条链，浪费且容易超时）；
    ///  2. 每条链用钱包的**节点池逐节点回退** —— 旧实现只用一个节点，
    ///     而 ETH 的默认节点 flashbots 对 `eth_call` 返回 403，
    ///     导致 ETH 的授权一条都查不出来（这就是「授权页看不到 ETH 链授权」的根因）；
    ///  3. 一个代币的所有 spender 用**批量 eth_call** 一次查完，请求数从 N×7 降到 2。
    func queryWalletApprovals(walletAddress: String,
                              coinList: [LocalCoin],
                              progress: @escaping (Int, Int) -> Void,
                              completion: @escaping ([TokenApprovalInfo]) -> Void) {
        var tasks: [(symbol: String, token: String, chain: TokenApproveChain)] = []
        var seen = Set<String>()
        for coin in coinList {
            // 仅查询 ERC20 合约代币 (coin_type_nft == 10)
            guard coin.coin_type_nft == 10,
                  let raw = coin.coin_pubkey?.trimmingCharacters(in: .whitespacesAndNewlines),
                  raw.count == 42, raw.lowercased().hasPrefix("0x") else { continue }
            let token = raw.lowercased()
            let chain = Self.chain(for: coin)
            let key = chain.rawValue + token
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            tasks.append((coin.coin_type ?? "", token, chain))
        }

        let total = max(tasks.count, 1)
        guard !tasks.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        let owner = walletAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            var allResults: [TokenApprovalInfo] = []
            var completed = 0
            for task in tasks {
                let found = await self.approvals(token: task.token,
                                                 symbol: task.symbol,
                                                 chain: task.chain,
                                                 owner: owner)
                allResults.append(contentsOf: found)
                completed += 1
                let done = completed
                DispatchQueue.main.async { progress(done, total) }
            }
            let results = allResults
            DispatchQueue.main.async { completion(results) }
        }
    }

    /// 取消授权：按节点池逐个尝试（ETH 的默认节点 flashbots 不支持 eth_call / 广播，必须能换节点）
    func revokeApproval(tokenAddress: String,
                        spenderAddress: String,
                        rpcURLs: [String],
                        password: String) async throws -> String {
        var lastError: Error?
        for rpcURL in rpcURLs {
            do {
                return try await revokeApproval(tokenAddress: tokenAddress,
                                                spenderAddress: spenderAddress,
                                                rpcURL: rpcURL,
                                                password: password)
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? NSError(domain: "TokenApprove", code: -4,
                                   userInfo: [NSLocalizedDescriptionKey: L("没有可用的节点")])
    }

    /// 取消授权（将 allowance 设为 0）
    func revokeApproval(tokenAddress: String,
                        spenderAddress: String,
                        rpcURL: String,
                        password: String) async throws -> String {
        guard let token = EthereumAddress(tokenAddress, ignoreChecksum: true),
              let spender = EthereumAddress(spenderAddress, ignoreChecksum: true),
              let url = URL(string: rpcURL) else {
            throw NSError(domain: "TokenApprove", code: -1, userInfo: [NSLocalizedDescriptionKey: L("无效地址")])
        }
        
        let web3 = try await Web3.new(url)
        
        // 获取私钥 Data（与 DAppBrowser 一致的逻辑）
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        guard let wallet = wallet else {
            throw NSError(domain: "TokenApprove", code: -2, userInfo: [NSLocalizedDescriptionKey: L("钱包未找到")])
        }
        guard let seedOrPrivateKey = GoFunction.deckey(wallet.wallet_remembercode, password: password), !seedOrPrivateKey.isEmpty else {
            throw NSError(domain: "TokenApprove", code: -2, userInfo: [NSLocalizedDescriptionKey: L("解密私钥失败")])
        }
        
        let privateKeyData: Data
        if wallet.wallet_issmall == 2 {
            // 导入的私钥
            guard let key = Data.fromHex(seedOrPrivateKey) else {
                throw NSError(domain: "TokenApprove", code: -2, userInfo: [NSLocalizedDescriptionKey: L("私钥格式错误")])
            }
            privateKeyData = key
        } else {
            // HD 钱包，派生 ETH 私钥
            guard let hdWallet = GoFunction.goCreateHDWallet("ETH", rememberCode: seedOrPrivateKey) else {
                throw NSError(domain: "TokenApprove", code: -2, userInfo: [NSLocalizedDescriptionKey: L("创建HD钱包失败")])
            }
            guard let key = try? hdWallet.newKeyPriv(0) else {
                throw NSError(domain: "TokenApprove", code: -2, userInfo: [NSLocalizedDescriptionKey: L("派生私钥失败")])
            }
            privateKeyData = key
        }
        
        // 从私钥推导地址（与 DAppBrowser 一致，不经过 Keystore）
        let fromAddress: EthereumAddress
        do {
            guard let pubKey = Utilities.privateToPublic(privateKeyData, compressed: false) else {
                throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: L("推导公钥失败")])
            }
            guard let addr = Utilities.publicToAddress(pubKey) else {
                throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: L("推导地址失败")])
            }
            fromAddress = addr
        } catch {
            throw NSError(domain: "TokenApprove", code: -3, userInfo: [NSLocalizedDescriptionKey: L("推导地址失败")])
        }
        
        // 构建取消授权交易
        let isBityuan = rpcURL.lowercased().contains("bityuan")
        
        var tx = CodableTransaction.emptyTransaction
        tx.from = fromAddress
        tx.to = token
        
        if isBityuan {
            // Bityuan 链 approve 只接受 1 个参数 (address spender)，手动编码避免 ABI 解析歧义
            let selector = "approve(address)".data(using: .utf8)!.sha3(.keccak256).prefix(4)
            guard let encoded = ABIEncoder.encode(types: [.address], values: [spender]) else {
                throw NSError(domain: "TokenApprove", code: -4, userInfo: [NSLocalizedDescriptionKey: L("编码参数失败")])
            }
            tx.data = selector + encoded
        } else {
            guard let contract = web3.contract(Web3.Utils.erc20ABI, at: token) else {
                throw NSError(domain: "TokenApprove", code: -4, userInfo: [NSLocalizedDescriptionKey: L("加载合约失败")])
            }
            contract.transaction = tx
            guard let writeOp = contract.createWriteOperation("approve", parameters: [spender, BigUInt(0) as Any]) else {
                throw NSError(domain: "TokenApprove", code: -4, userInfo: [NSLocalizedDescriptionKey: L("合约不支持 approve")])
            }
            tx = writeOp.transaction
        }
        
        // 与 DAppBrowser 一致的签名和发送方式
        tx.from = fromAddress
        tx.nonce = try await web3.eth.getTransactionCount(for: fromAddress, onBlock: .pending)
        tx.gasPrice = try await web3.eth.gasPrice()
        if tx.gasLimit == 0 {
            tx.gasLimit = 100_000 // Bityuan 的 eth_estimateGas 可能不兼容，使用固定值
        }
        tx.chainID = BlockchainRPC.currentChainID
        
        try tx.sign(privateKey: privateKeyData)
        guard let raw = tx.encode(for: .transaction) else {
            throw NSError(domain: "TokenApprove", code: -5, userInfo: [NSLocalizedDescriptionKey: L("交易编码失败")])
        }
        let sent = try await web3.eth.send(raw: raw)
        return sent.hash
    }
}
