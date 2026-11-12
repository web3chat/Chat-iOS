//
//  WalletPrivateKeyStore.swift
//  chat
//
//  当前钱包账户「0x 私钥」的**内存缓存** + 「按需输入一次密码」的统一入口。
//
//  背景（2026-09-24 需求）：AI 客服签名、开/发/取回红包都需要当前账户的 0x 私钥，
//  而私钥只能用**钱包密码**解开 `wallet.wallet_remembercode`
//  （本工程里密聊密码与钱包密码是同一个：`SetChatPwdVC` 改密时同时更新 `wallet_password`
//   并重新加密 `wallet_remembercode`）：
//      `GoFunction.checkPassword` 校验 → `GoFunction.deckey` 解出助记词
//      → `goCreateHDWallet("ETH")` → `newKeyPriv(0)`
//      （小钱包 `wallet_issmall == 2` 时，`deckey` 解出来的直接就是私钥）
//
//  行为（三条取用策略，不同业务不同口径，**别混用**）：
//  ① `cachedPrivateKey()` / `requestPrivateKey(...)` —— **缓存优先（内存 → Keychain）**：
//     用于 **AI 客服** 与 **领红包 / 过期取回**。
//  ② `requestPrivateKeyByPassword(...)` —— **每次都真弹密码框，不看缓存也不写缓存**：
//     用于 **发红包**（2026-09-24 用户要求：「发红包的时候，每次都需要输入密码，不依据缓存密钥来做」）。
//
//  ★★★ 流程（用户 2026-09-24 定稿）——**私钥存起来，存过就不用再拿**：
//  · **第一次**进入 AI 客服 / 领红包 ⇒ 过一次认证拿私钥（**开了人脸就用人脸；没开就输密码**，`ChatPasswordGate`
//    已天然这么分流）→ 派生 0x 私钥 → **存进 Keychain**（按地址分键）。
//  · **第二次以后**（含 **杀 App 冷启动**）⇒ 直接用存着的那份私钥，**不再弹人脸、也不再输密码**。
//  · 弹人脸 / 输密码的作用就是「拿一次私钥去做后续操作」；已经存了就不用再拿。
//  · Keychain 条目**不加生物识别锁**（`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）：
//    加了的话冷启动读它又得弹人脸，与上面“存了就直接用”相悖。
//    历史中间版本加过 ACL，读取时用 `interactionNotAllowed` 让它**直接失败而不弹窗**，
//    回退到认证流程并覆写成普通条目（自愈）。
//  · 缓存**按地址分键**（换账号不会串用）；退出登录（`FZM_Notify_UserLogout`）全部清掉。
//  · **绝不打印**私钥；同一时刻只弹一个认证，期间来的其它**缓存优先**请求搭车等同一个结果。
//

import UIKit
import Security
import LocalAuthentication
import Web3Core

enum WalletPrivateKeyError: Error {
    /// 用户在密码框里取消（**不要弹提示**）
    case cancelled
    /// 没有选中 / 可用的钱包
    case noWallet
    /// 密码错误
    case passwordInvalid
    /// 解密 / 派生私钥失败
    case privateKeyUnavailable

    /// 给用户看的文案；`.cancelled` 为空串（调用方据此静默处理）
    var message: String {
        switch self {
        case .cancelled:             return ""
        case .noWallet:              return L("未获取到钱包地址")
        case .passwordInvalid:       return L("密码错误")
        case .privateKeyUnavailable: return L("钱包密钥不可用")
        }
    }
}

final class WalletPrivateKeyStore: NSObject {

    static let shared = WalletPrivateKeyStore()

    /// address(小写) → 0x 私钥。
    /// 用 `NSCache`：内存吃紧时系统可回收（回收后下次再输一次密码即可，不影响正确性）。
    private let cache = NSCache<NSString, NSData>()

    /// 是否正在弹密码框（同一时刻只允许一个）
    private var isPrompting = false
    /// 弹框期间来的其它请求：搭车等同一个结果
    private var pendingSuccess: [(Data) -> Void] = []
    private var pendingFailure: [(WalletPrivateKeyError) -> Void] = []

    private override init() {
        super.init()
        // 退出登录 ⇒ 清空（登录态都变了，这份私钥不能再复用）
        FZM_NotificationCenter.addObserver(self,
                                          selector: #selector(clear),
                                          name: FZM_Notify_UserLogout,
                                          object: nil)
    }

    deinit {
        FZM_NotificationCenter.removeObserver(self)
    }

    // MARK: - 当前账户

    /// 当前账户的 0x 地址（小写）。私钥与它一一对应（服务端会 ecrecover 比对）。
    var currentAddress: String? {
        guard let address = RedPacketWalletDataSource.shared.getCurrentWalletAddress()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else { return nil }
        return address.lowercased()
    }

    // MARK: - 缓存（内存 → Keychain 持久化）

    /// 命中缓存直接返回（**同步、不弹任何东西**）。
    ///
    /// 查找顺序：内存 `NSCache` → **Keychain**（上次“第一次认证”时存下的）。
    /// Keychain 命中后回填内存 —— 这就是「第二次、以及杀 App 冷启动后都不用再弹人脸/输密码」的实现点。
    func cachedPrivateKey() -> Data? {
        guard let address = currentAddress else { return nil }
        if let cached = cache.object(forKey: address as NSString) {
            return cached as Data
        }
        guard let hex = WalletPrivateKeyKeychain.load(address: address),
              let key = Data.fromHex(hex), !key.isEmpty else { return nil }
        cache.setObject(key as NSData, forKey: address as NSString)
        FZMLog("钱包私钥：命中已存的私钥（本次无需再弹人脸/输密码）")
        return key
    }

    /// 存一份（由 `requestPrivateKey` 在**认证通过、派生成功后**调用）。
    ///
    /// - Note: 同时写内存与 **Keychain**（跨启动保留）。
    ///   发红包走的是 `requestPrivateKeyByPassword`，它**不调用这里** ⇒ 每次都要重新输密码。
    func store(_ privateKey: Data, for address: String? = nil) {
        guard !privateKey.isEmpty,
              let key = address?.lowercased() ?? currentAddress else { return }
        cache.setObject(privateKey as NSData, forKey: key as NSString)
        // 用工程统一的 Go 桥做 hex 编码（不依赖具体 pod 的 `Data.toHexString()` 归属）
        WalletPrivateKeyKeychain.save(hex: WalletapiBytes2Hex(privateKey), address: key)
    }

    /// 清空缓存（退出登录自动调用；切换钱包后也可手动调用）
    /// - Note: ① 等待中的请求会以 `.cancelled` 结束 —— 否则 `await` 它们的调用方会永久挂起；
    ///         ② **Keychain 里的也一起删**：登出后不该还把上一账号的私钥留在设备上。
    @objc func clear() {
        isPrompting = false
        let waiting = pendingFailure
        pendingSuccess.removeAll()
        pendingFailure.removeAll()
        cache.removeAllObjects()
        WalletPrivateKeyKeychain.removeAll()
        waiting.forEach { $0(.cancelled) }
    }

    // MARK: - 统一入口（可能弹一次密码）

    /// 取当前账户的 0x 私钥。
    ///
    /// 命中内存缓存 → 直接回调；否则弹一次密码（带面容/指纹）→ 校验 → 解助记词 → 派生 → 缓存 → 回调。
    /// - Parameters:
    ///   - title: 密码弹窗标题；不传用工程统一的「请输入密聊密码」
    ///   - success: 主线程回调私钥（32 字节 `Data`）
    ///   - failure: 失败/取消（`.cancelled` 表示用户主动取消，**不要弹提示**）
    /// - Note: 弹框期间来的重复请求会搭车等同一个结果，不会弹出第二个密码框。
    func requestPrivateKey(title: String? = nil,
                           success: @escaping (Data) -> Void,
                           failure: @escaping (WalletPrivateKeyError) -> Void) {
        if let cached = cachedPrivateKey() {
            success(cached)
            return
        }

        pendingSuccess.append(success)
        pendingFailure.append(failure)
        guard !isPrompting else { return }

        guard let wallet = PWDataBaseManager.shared().queryWalletIsSelected(),
              let address = currentAddress else {
            finish(.failure(.noWallet))
            return
        }

        isPrompting = true
        let alertTitle = (title?.isBlank == false) ? title! : L("请输入密聊密码")
        ChatPasswordGate.requestVerifiedPassword(title: alertTitle, cancelled: {
            // 用户取消：静默（调用方据 `.cancelled` 不弹提示）
            DispatchQueue.main.async { [weak self] in self?.finish(.failure(.cancelled)) }
        }, success: { [weak self] password in
            guard let self = self else { return }
            do {
                let key = try Self.derivePrivateKey(password: password, wallet: wallet)
                self.store(key, for: address)
                self.finish(.success(key))
            } catch let error as WalletPrivateKeyError {
                self.finish(.failure(error))
            } catch {
                self.finish(.failure(.privateKeyUnavailable))
            }
        })
    }

    // MARK: - 每次都输密码（发红包专用：不看缓存、也不写缓存）

    /// 弹密码框取当前账户私钥：**每次都真弹**（既不读缓存、也不写缓存）。
    ///
    /// 用于**发红包**（2026-09-24 用户要求：「发红包的时候，每次都需要输入密码，不依据缓存密钥来做」）。
    /// 其它场景（AI 客服、开红包 / 过期取回）请用缓存优先的 `requestPrivateKey(...)`。
    ///
    /// - Note: 刻意**不走搭车队列** —— 既然要求「每次都要输」，就不该复用别人正在输的那一次结果。
    func requestPrivateKeyByPassword(title: String? = nil,
                                     success: @escaping (Data) -> Void,
                                     failure: @escaping (WalletPrivateKeyError) -> Void) {
        guard let wallet = PWDataBaseManager.shared().queryWalletIsSelected() else {
            failure(.noWallet)
            return
        }
        let alertTitle = (title?.isBlank == false) ? title! : L("请输入密聊密码")
        ChatPasswordGate.requestVerifiedPassword(title: alertTitle, cancelled: {
            // 用户取消：静默（调用方据 `.cancelled` 不弹提示）
            DispatchQueue.main.async { failure(.cancelled) }
        }, success: { password in
            do {
                let key = try Self.derivePrivateKey(password: password, wallet: wallet)
                success(key)
            } catch let error as WalletPrivateKeyError {
                failure(error)
            } catch {
                failure(.privateKeyUnavailable)
            }
        })
    }

    /// 把结果发给所有搭车的回调
    private func finish(_ result: Result<Data, WalletPrivateKeyError>) {
        isPrompting = false
        let successes = pendingSuccess
        let failures = pendingFailure
        pendingSuccess.removeAll()
        pendingFailure.removeAll()
        switch result {
        case .success(let key):
            successes.forEach { $0(key) }
        case .failure(let error):
            failures.forEach { $0(error) }
        }
    }

    // MARK: - 密码 → 私钥

    /// 用钱包密码解出 0x 私钥（与红包 / 转账 / DApp 浏览器**同一条链**）
    static func derivePrivateKey(password: String, wallet: LocalWallet) throws -> Data {
        guard GoFunction.checkPassword(password, hash: wallet.wallet_password) else {
            throw WalletPrivateKeyError.passwordInvalid
        }
        guard let seedOrPrivateKey = GoFunction.deckey(wallet.wallet_remembercode, password: password),
              !seedOrPrivateKey.isEmpty else {
            throw WalletPrivateKeyError.privateKeyUnavailable
        }
        // 小钱包（用私钥导入的钱包）里存的直接就是私钥
        if wallet.wallet_issmall == 2 {
            guard let key = Data.fromHex(seedOrPrivateKey) else {
                throw WalletPrivateKeyError.privateKeyUnavailable
            }
            return key
        }
        guard let hdWallet = GoFunction.goCreateHDWallet("ETH", rememberCode: seedOrPrivateKey) else {
            throw WalletPrivateKeyError.privateKeyUnavailable
        }
        guard let key = try? hdWallet.newKeyPriv(0), !key.isEmpty else {
            throw WalletPrivateKeyError.privateKeyUnavailable
        }
        return key
    }
}

// MARK: - Keychain（私钥持久化：存过就不用再拿）

/// 私钥的 Keychain 存储（原生 `Security` API，与同目录 `BiometricPasswordStore` 同一套写法）。
///
/// 设计要点（2026-09-24 用户定稿的流程）：
/// · **第一次**进 AI 客服 / 领红包 ⇒ 过一次认证（开人脸 ⇒ 人脸；没开 ⇒ 密码）→ 派生私钥 → **存这里**；
/// · **第二次以后（含杀 App 冷启动）** ⇒ 直接读这里，**不再弹人脸/密码**；
/// · 所以条目**不加生物识别锁**，只用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
///   （设备解锁后才能读；**不随 iCloud 钥匙串 / 备份迁移到别的设备**）；
/// · 按地址分键（`walletPrivateKey.v1.<小写地址>`），换账号不会串用；退出登录时由 `clear()` 全删。
///
/// ⚠️ 历史中间版本曾给条目加过 `.biometryCurrentSet` ACL：那种条目**读的时候会弹人脸**（与“存过就直接用”相悖），
///    所以 `load` 统一带 `LAContext(interactionNotAllowed = true)` —— 需要认证就**直接失败、不弹窗**，
///    调用方于是回退到认证流程，派生后用 `save` 覆写成普通条目（自愈）。
///
/// ⚠️ 全部成员都写 `fileprivate`：本文件内另一个类型（`WalletPrivateKeyStore`）要调用它们，
///    按本工程踩过的坑（同文件跨类型访问 `private` 成员会报 inaccessible），不能写 `private`。
fileprivate enum WalletPrivateKeyKeychain {

    /// ⚠️ **必须用本模块专属 service，绝不能直接用 `Bundle.main.bundleIdentifier`。**
    ///
    /// 本工程里用 bundle id 当 Keychain service 的**不止这一个**：
    /// `Keychain.init()`（KeychainAccess pod，默认 service 就是 bundle id）存了
    /// **设备 uuid `LocalStaticDeviceUUID`**、红包类型引导标记、钱包卡片引导标记等；
    /// 同目录的 `BiometricPasswordStore` 也用它存生物识别密码。
    ///
    /// ⚠️ 2026-09-24 事故（改之前就是这么写的）：`removeAll()` 当时用 bundle id
    /// 做「整 service 删除」⇒ 退出登录/切换账号时把**设备 uuid 一起删了** ⇒
    /// 下次启动 `getDeviceUUID()` 找不到旧值、重新生成一个新 uuid ⇒
    /// 服务端按 uuid 判定「不是同一台设备」（`SocketManager` 里 `uuid != k_DeviceUUID`）
    /// ⇒ **当前设备被踢下线**（两个账号各中一次）。
    /// 结论：本模块的增/删/读都只许在自己这个 service 里做。
    fileprivate static let service = (Bundle.main.bundleIdentifier ?? "com.chat") + ".walletPrivateKey"

    /// 早期（同样 2026-09-24 修之前）写在了 app service 下的旧条目，登出时按**账号名前缀**精确清掉
    fileprivate static let legacyService = Bundle.main.bundleIdentifier ?? "com.chat"
    fileprivate static let accountPrefix = "walletPrivateKey.v1."

    fileprivate static func accountKey(_ address: String) -> String {
        accountPrefix + address.lowercased()
    }

    fileprivate static func baseQuery(service: String, address: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey(address)
        ]
    }

    /// 当前 service 下的条目
    fileprivate static func baseQuery(address: String) -> [String: Any] {
        baseQuery(service: service, address: address)
    }

    /// 写入私钥（hex）。先删旧条目再写：既能覆盖旧记录，也能把历史版本带 ACL 的条目换成普通条目。
    @discardableResult
    fileprivate static func save(hex: String, address: String) -> Bool {
        guard let data = hex.data(using: .utf8) else { return false }
        SecItemDelete(baseQuery(address: address) as CFDictionary)
        // 旧 service 里的同账号条目也一并清掉（避免同一个账号两份私钥）
        SecItemDelete(baseQuery(service: legacyService, address: address) as CFDictionary)

        var query = baseQuery(address: address)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            FZMLog("钱包私钥：写 Keychain 失败（status=\(status)），本次仅内存有效")
        }
        return status == errSecSuccess
    }

    /// 读取私钥（hex）：找不到 / 需要认证（历史 ACL 条目）/ 解不出来都返回 nil。
    fileprivate static func load(address: String) -> String? {
        if let hex = load(address: address, service: service) { return hex }
        // 兼容上午写在 app service 下的旧条目：读到就搬到专属 service，之后不再回读旧 service
        if let hex = load(address: address, service: legacyService) {
            save(hex: hex, address: address)
            return hex
        }
        return nil
    }

    fileprivate static func load(address: String, service: String) -> String? {
        var query = baseQuery(service: service, address: address)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        // 不弹系统认证窗：万一读到历史版本的 ACL 条目，让它直接失败（调用方会回退认证并覆写）
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 删除本模块的**全部**私钥条目（登出时用：一个账号的都不能留）。
    ///
    /// ⚠️ 只能删「本模块专属 service」与「旧 service 下账号名带本模块前缀」的条目 ——
    /// **绝不能**按 app 的 bundle id 做整 service 删除：那会连带删掉设备 uuid 等其它模块数据
    /// （2026-09-24 被踢下线事故就是这么来的）。
    fileprivate static func removeAll() {
        // ① 专属 service：整 service 删（里面只有本模块的东西）
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)

        // ② 旧 service：按账号名前缀过滤后逐个精确删，不碰其它条目
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return }
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(accountPrefix) else { continue }
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: legacyService,
                kSecAttrAccount as String: account
            ] as CFDictionary)
        }
    }
}
