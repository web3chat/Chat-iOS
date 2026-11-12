//
//  RedPacketWalletDataSource.swift
//  chat
//
//  红包钱包数据源
//  直接使用 PWDataBaseManager 数据库的 LocalCoin 数据
//

import Foundation
import UIKit

// MARK: - 红包钱包数据源
/// 直接使用项目现有的数据库模型 LocalCoin
@objc class RedPacketWalletDataSource: NSObject {

    @objc static let shared = RedPacketWalletDataSource()

    private override init() {}

    /// 获取当前钱包的所有币种（直接返回 LocalCoin 数组）
    func getSupportedTokens(completion: @escaping ([LocalCoin]) -> Void) {
        // 1. 获取当前选中的钱包
        guard let wallet = getCurrentWallet() else {
            completion([])
            return
        }

        // 2. 从数据库查询该钱包下的所有币种
        guard let coinArray = PWDataBaseManager.shared().queryCoinArrayBased(on: wallet) else {
            completion([])
            return
        }

        // 3. 过滤出有效的 LocalCoin
        let coins = coinArray.compactMap { coin -> LocalCoin? in
            return coin as? LocalCoin
        }

        completion(coins)
    }

    /// 获取指定币种的余额
    ///
    /// **实时刷新**：先回调本地缓存值（界面立刻有数、不会长时间停在「余额加载中」），
    /// 再向节点/合约接口查最新余额，拿到后回写 `LocalCoin` 与数据库并**再回调一次**；
    /// 查询失败就不再回调（界面上保留缓存值）。
    func getTokenBalance(coinId: Int, completion: @escaping (Double) -> Void) {
        guard let coin = PWDataBaseManager.shared().queryCoinBased(onCoinId: coinId) else {
            completion(0.0)
            return
        }
        // 1. 本地缓存值
        completion(Double(coin.coin_balance))
        // 2. 链上实时余额
        self.requestLiveBalance(for: coin) { live in
            guard let live = live else { return }
            completion(live)
        }
    }

    /// 查询链上实时余额（成功回调最新值，失败回调 nil）
    /// - 合约币（`coin_type_nft == 10`）：走 `PWContractRequest.getBalanceWithChain`，`tokenSymbol` 传合约地址 `coin_pubkey`
    /// - 其它（主链/普通币）：走 `GoFunction.goGetBalance`（同步直连节点，必须切后台线程）
    ///
    /// 成功后会把最新余额写回 `LocalCoin` 与数据库，保证钱包其它页面/金额校验用的是同一个新值。
    private func requestLiveBalance(for coin: LocalCoin, completion: @escaping (Double?) -> Void) {
        let address = (coin.coin_address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let coinType = (coin.coin_type ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !coinType.isEmpty else {
            completion(nil)
            return
        }

        if self.isContractERC20Coin(coin) {
            let chain = (coin.coin_chain ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let contract = (coin.coin_pubkey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chain.isEmpty, !contract.isEmpty else {
                completion(nil)
                return
            }
            PWContractRequest.getBalanceWithChain(
                chain, address: address, tokenSymbol: contract,
                success: { [weak self] object in
                    guard let self = self, let balance = self.parseBalance(from: object) else {
                        completion(nil)
                        return
                    }
                    self.storeLiveBalance(balance, for: coin)
                    completion(balance)
                },
                failure: { _ in
                    completion(nil)
                })
            return
        }

        let platform = (coin.coin_platform ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let treaty = coin.treaty
        // goGetBalance 是同步阻塞的节点查询，必须切后台，避免卡住调用线程
        DispatchQueue.global().async { [weak self] in
            let balance = GoFunction.goGetBalance(
                coinType, platform: platform, address: address, andTreaty: treaty)
            // -1 表示查询失败
            guard balance >= 0 else {
                completion(nil)
                return
            }
            let value = Double(balance)
            self?.storeLiveBalance(value, for: coin)
            completion(value)
        }
    }

    /// 解析余额接口返回的 `{"result": {"balance": ...}}`（余额可能是数字也可能是字符串）
    private func parseBalance(from object: Any) -> Double? {
        guard let data = object as? Data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["result"] as? [String: Any]
        else {
            return nil
        }
        var balance: Double?
        if let number = result["balance"] as? NSNumber {
            balance = number.doubleValue
        } else if let text = result["balance"] as? String {
            balance = Double(text)
        }
        guard let value = balance, value >= 0 else { return nil }
        return value
    }

    /// 把链上最新余额写回 `LocalCoin` 与数据库（统一回主线程，与工程其它余额刷新写法一致）
    /// - 注：OC 的 `updateCoin:` 在 Swift 里被重命名为 `update(_:)`（参数类型已含 Coin，省略重复词），
    ///   与 `updateWallet:` → `update(_:)` 构成重载，按参数类型解析。
    private func storeLiveBalance(_ balance: Double, for coin: LocalCoin) {
        let apply = {
            coin.coin_balance = CGFloat(balance)
            _ = PWDataBaseManager.shared().update(coin)
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// 获取当前钱包地址（优先返回0x格式的ethAddr）
    @objc func getCurrentWalletAddress() -> String? {
        let ethAddr = LoginUser.shared().ethAddr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ethAddr.isEmpty {
            return ethAddr
        }
        guard let wallet = getCurrentWallet(),
              let coinArray = PWDataBaseManager.shared().queryCoinArrayBased(on: wallet) else {
            return nil
        }

        let coins = coinArray.compactMap { $0 as? LocalCoin }
        let preferredChains = ["ETH", "BNB", "BTY"]
        for chain in preferredChains {
            if let coin = coins.first(where: { $0.coin_chain?.uppercased() == chain || $0.coin_type?.uppercased() == chain }),
               let address = coin.coin_address,
               !address.isEmpty {
                return address
            }
        }

        return coins.first(where: { !($0.coin_address ?? "").isEmpty })?.coin_address
    }

    /// 根据 LocalCoin 获取 CoinPrice
    func getCoinPrice(for coin: LocalCoin) -> CoinPrice? {
        return PWDataBaseManager.shared().queryCoinPriceBased(
            on: coin.coin_type,
            platform: coin.coin_platform,
            andTreaty: coin.treaty
        )
    }

    /// 获取币种的小数位数
    func getDecimalPlaces(for coin: LocalCoin) -> Int {
        guard let type = coin.coin_type?.uppercased() else { return 18 }

        switch type {
        case "ETH": return 18
        case "BTY": return 8
        case "USDT", "USDC": return 6
        default: return 18
        }
    }

    /// 获取合约地址（行情库配置，与本地合约币无关）
    func getContractAddress(for coin: LocalCoin) -> String? {
        let coinPrice = getCoinPrice(for: coin)
        return coinPrice?.coinprice_heyueAddress
    }

    /// `coin_type_nft == 10` 为合约代币（ERC20），`coin_pubkey` 为代币合约地址
    func isContractERC20Coin(_ coin: LocalCoin) -> Bool {
        coin.coin_type_nft == 10
    }

    /// 发红包：非 10 走链上原生币（零地址）；10 走 ERC20 + `coin_pubkey`
    func isRedPacketNativeToken(_ coin: LocalCoin) -> Bool {
        !isContractERC20Coin(coin)
    }

    /// BTY 链 + BTY 币种（主链原生）：当前红包合约流程不支持
    func shouldBlockBTYMainCoinRedPacket(_ coin: LocalCoin) -> Bool {
        let chain = coin.coin_chain?.uppercased() ?? ""
        let type = coin.coin_type?.uppercased() ?? ""
        return chain == "BTY" && type == "BTY"
    }

    /// 是否需要剔除（1开头地址的BTY，或主链/币种均为BTY）
    func shouldExcludeBTYCoin(_ coin: LocalCoin) -> Bool {
        let type = coin.coin_type?.uppercased() ?? ""
        let chain = coin.coin_chain?.uppercased() ?? ""
        let addr = coin.coin_address ?? ""
        return type == "BTY" && (addr.hasPrefix("1") || chain == "BTY")
    }

    /// ERC20 发红包时使用的代币合约地址（仅 `coin_type_nft == 10`）
    func redPacketERC20ContractAddress(for coin: LocalCoin) -> String? {
        guard isContractERC20Coin(coin) else { return nil }
        let addr = coin.coin_pubkey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if addr.isEmpty { return nil }
        return addr
    }

    /// 列表/字典展示用：合约币展示 `coin_pubkey`，否则沿用行情合约或空（表示原生）
    func redPacketDisplayContractAddress(for coin: LocalCoin) -> String? {
        if isContractERC20Coin(coin) {
            return redPacketERC20ContractAddress(for: coin)
        }
        return getContractAddress(for: coin)
    }

    /// 按 ERC20 合约地址反查钱包里的代币英文符号（`coin_type`，如 PMM/USDT/BTY）。
    /// 红包币种展示以本地代币名为准（链上红包合约存的 symbol 可能是中文等非英文名）。
    /// 查找范围：当前选中钱包 → 全部钱包（红包可能是另一个钱包发/领的）；匹配 `coin_pubkey` 或 `coin_address`。
    /// 匹配不上时返回 nil（由调用方回退链上 `symbol()` / 合约地址）。
    func symbol(forTokenContract contract: String) -> String? {
        let target = contract.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty else { return nil }

        var coins = [LocalCoin]()
        if let wallet = getCurrentWallet(),
           let array = PWDataBaseManager.shared().queryCoinArrayBased(on: wallet) {
            coins.append(contentsOf: array.compactMap { $0 as? LocalCoin })
        }
        if let wallets = PWDataBaseManager.shared().queryAllWallets() as? [LocalWallet] {
            for wallet in wallets {
                guard let array = PWDataBaseManager.shared().queryAllCoinArrayBased(onWalletID: wallet.wallet_id) else {
                    continue
                }
                coins.append(contentsOf: array.compactMap { $0 as? LocalCoin })
            }
        }

        for coin in coins {
            let name = coin.coin_type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { continue }
            // 合约币的合约地址存在 coin_pubkey；个别币存放在 coin_address
            let pubkey = coin.coin_pubkey?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !pubkey.isEmpty, pubkey == target {
                return name
            }
            let address = coin.coin_address?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !address.isEmpty, address == target {
                return name
            }
        }
        return nil
    }

    /// 判断是否是原生代币（兼容旧逻辑；发红包请用 `isRedPacketNativeToken` / `isContractERC20Coin`）
    func isNativeToken(for coin: LocalCoin) -> Bool {
        if isContractERC20Coin(coin) {
            return false
        }
        let coinType = coin.coin_type?.uppercased() ?? ""
        let coinChain = coin.coin_chain?.uppercased() ?? ""
        if !coinType.isEmpty, coinType == coinChain {
            return true
        }
        if ["ETH", "BNB", "BTY"].contains(coinType) {
            return true
        }

        guard let contractAddress = getContractAddress(for: coin) else {
            return true
        }
        let normalizedContract = contractAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedContract.isEmpty ||
               normalizedContract == "0x0000000000000000000000000000000000000000"
    }

    // MARK: - 私有方法

    /// 获取当前选中的钱包
    private func getCurrentWallet() -> LocalWallet? {
        return PWDataBaseManager.shared().queryWalletIsSelected()
    }
}

// MARK: - 桥接类
/// 为 FZMCreateLuckyBagVC 提供简单的接口，直接使用 LocalCoin 数据
typealias LocalCoinBlock = (LocalCoin) -> Void

class RedPacketWalletBridge {

    /// 获取币种列表，直接返回 LocalCoin 数组
    static func fetchWalletTokensForRedPacket(completion: @escaping ([LocalCoin]) -> Void) {
        RedPacketWalletDataSource.shared.getSupportedTokens { coins in
            completion(coins)
        }
    }

    /// 获取指定币种余额
    static func getTokenBalanceWithUpdate(coinId: Int, completion: @escaping (Double) -> Void) {
        RedPacketWalletDataSource.shared.getTokenBalance(coinId: coinId, completion: completion)
    }

    /// 将 LocalCoin 转换为字典（供需要字典格式的场景使用）
    static func convertToDictionary(coin: LocalCoin) -> [String: Any] {
        let dataSource = RedPacketWalletDataSource.shared
        let decimalPlaces = dataSource.getDecimalPlaces(for: coin)
        let contractAddress = dataSource.redPacketDisplayContractAddress(for: coin)

        return [
            "coinId": Int(coin.coin_coinid),
            "coinName": coin.coin_type ?? "",
            "coinNickname": coin.optional_name ?? coin.coin_type ?? "",
            "iconUrl": coin.icon ?? "",
            "amount": Double(coin.coin_balance),
            "decimalPlaces": decimalPlaces,
            "contractAddress": contractAddress ?? "",
            "isNativeToken": dataSource.isRedPacketNativeToken(coin),
            "localCoin": coin
        ]
    }
}
