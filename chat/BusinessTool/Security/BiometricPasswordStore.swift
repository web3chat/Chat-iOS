//
//  BiometricPasswordStore.swift
//  chat
//
//  面容/指纹绑定记录的 Keychain 存储（原生 Security API + 生物识别 ACL）
//
//  ⚠️ 为什么不复用 KeychainSwift（SeedManager 里那种写法）：
//  它的生物识别参数只有 `.userPresence`，即「人脸/指纹 **或设备密码**」都能解开；
//  这里必须用 `.biometryCurrentSet`，即「只认当前录入的人脸/指纹」，不允许设备密码兜底，
//  用户新增/删除指纹后该条目会被系统自动作废（读取返回 errSecItemNotFound）。
//
//  条目内容 = 绑定记录 JSON（见 BiometricBindingRecord）：
//  人脸/指纹 ↔ 账号地址 ↔ 密聊密码，三者任一不符上层都会判定为「未绑定」。
//

import Foundation
import LocalAuthentication
import Security

/// 读取绑定记录的结果（上层据此决定「回落密码弹窗」还是「提示重新开启」）
enum BiometricFetchResult: Int {
    case success = 0
    /// 未绑定；或用户改动过系统里的人脸/指纹导致条目已被系统作废
    case notBound
    /// 记录存在但归属另一个账号
    case accountMismatch
    /// 用户主动取消
    case cancelled
    /// 识别失败（含连续失败被系统锁定）
    case failed
    /// App 不在前台 / 设备锁屏，无法弹出验证
    case notAllowed
}

/// 绑定记录：人脸/指纹 ↔ 账号 ↔ 密聊密码
struct BiometricBindingRecord: Codable {
    /// 记录版本，便于以后升级结构
    var v: Int = 1
    /// 绑定时登录的账号地址（小写）
    var address: String
    /// 明文密聊密码（整条记录由生物识别 ACL 保护，只有验证通过才能读出）
    var pwd: String
    /// 绑定时间（秒）
    var boundAt: TimeInterval
    /// faceID / touchID / unknown，仅用于日志与提示
    var biometry: String
}

enum BiometricPasswordStore {

    private static let service = Bundle.main.bundleIdentifier ?? "com.chat"

    /// 每个账号一条记录，互不影响（切换账号不会串用别人的绑定）
    private static func accountKey(_ address: String) -> String {
        "chatPwd.bio.v1." + address.lowercased()
    }

    /// 只认当前生物识别集合、仅本机（不进 iCloud 钥匙串、不随备份迁移）
    private static func makeAccessControl() -> SecAccessControl? {
        SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )
    }

    // MARK: - 写入 / 删除（不需要验证）

    /// 保存绑定记录（同账号重复保存会先删旧条目：ACL 条目无法原地换 ACL）
    @discardableResult
    static func save(_ record: BiometricBindingRecord) -> Bool {
        guard let acl = makeAccessControl(),
              let data = try? JSONEncoder().encode(record) else { return false }

        delete(address: record.address)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey(record.address),
            kSecAttrAccessControl as String: acl,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete(address: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey(address)
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - 读取（会弹出人脸/指纹验证）

    /// ⚠️ 会阻塞当前线程直到用户完成/取消验证，请在后台线程调用（`BiometricAuthManager` 已处理）。
    /// - Parameter reason: 系统验证弹窗上的说明文案，**请调用方提前本地化好再传进来**。
    static func load(address: String, reason: String) -> (BiometricBindingRecord?, BiometricFetchResult) {
        let context = LAContext()
        // 置空后系统不显示「输入设备密码」这类兜底按钮：本项目只允许人脸/指纹
        context.localizedFallbackTitle = ""
        context.localizedReason = reason

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey(address),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        // 部分系统版本上弹窗文案取自这里，保留兼容（iOS 11 起官方推荐上面的 context 写法）
        if !reason.isEmpty {
            query[kSecUseOperationPrompt as String] = reason
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let record = try? JSONDecoder().decode(BiometricBindingRecord.self, from: data) else {
                return (nil, .notBound)
            }
            return (record, .success)
        case errSecItemNotFound:
            // 未绑定，或系统里的指纹/面容集合被改动过 → 条目已被系统作废，需要重新开启
            return (nil, .notBound)
        case errSecUserCanceled:
            return (nil, .cancelled)
        case errSecInteractionNotAllowed:
            return (nil, .notAllowed)
        default:
            // errSecAuthFailed（含连续失败被锁定）等一律当作识别失败
            return (nil, .failed)
        }
    }
}
