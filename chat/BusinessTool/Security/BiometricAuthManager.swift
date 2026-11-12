//
//  BiometricAuthManager.swift
//  chat
//
//  面容/指纹替代密聊密码 —— 绑定与取密码的门面
//
//  绑定 =（设备生物识别 ↔ 登录账号 address ↔ 密聊密码），三元组任一不符都算「未绑定」：
//  · 账号维度：绑定记录按 address 分开存，切换账号后另一个账号读不到本账号的记录
//  · 密码维度：取到的明文密码必须仍能通过 `GoFunction.checkPassword(取到, 当前钱包密码)` 复核
//    （`GoFunction.passwordhash` 是加盐 KDF，不能靠比较 hash 字符串判断，只能这样复核）
//
//  只在当前设备生效：Keychain 用 `.biometryCurrentSet` + ThisDeviceOnly，不写服务器、不进 iCloud。
//

import Foundation
import LocalAuthentication

/// 绑定状态（只做「账号维度」判定，不会弹人脸）
enum BiometricBindState: Int {
    /// 设备不支持，或系统里没录入人脸/指纹
    case notSupported
    /// 本账号未开启过
    case notBound
    /// 当前没有登录账号 / 记录不属于当前账号
    case accountMismatch
    /// 已开启且属于当前账号
    case bound
}

final class BiometricAuthManager {

    static let shared = BiometricAuthManager()

    private init() {}

    /// 是否开启过的本地标志位前缀（按账号存；不用 keychain 探测状态，避免「一探测就弹人脸」）
    private let flagKeyPrefix = "FZM_BiometricUnlock."

    /// 正在弹验证，避免同时弹两个系统验证框
    private var isAuthenticating = false

    // MARK: - 设备能力

    /// 硬件支持且系统已录入人脸/指纹（且设备设置了解锁密码）
    var isDeviceSupported: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// 设置页/文案用：面容 ID / 触控 ID / 人脸、指纹
    var biometryDisplayName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID:
            return L("面容 ID")
        case .touchID:
            return L("触控 ID")
        default:
            return L("人脸/指纹")
        }
    }

    /// 用于绑定记录里的类型标记（不展示给用户）
    private var biometryTypeName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "faceID"
        case .touchID: return "touchID"
        default: return "unknown"
        }
    }

    // MARK: - 绑定状态

    /// 当前登录账号（小写）；未登录返回 nil
    var currentAccount: String? {
        let address = LoginUser.shared().address.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? nil : address.lowercased()
    }

    /// 本账号是否开启过（本地标志位）
    var isEnabled: Bool {
        guard let account = currentAccount else { return false }
        return FZM_UserDefaults.bool(forKey: flagKeyPrefix + account)
    }

    /// 账号维度判定，不弹人脸；总开关关闭时一律按「未绑定」处理
    var bindState: BiometricBindState {
        guard FZM_EnableBiometricUnlock else { return .notBound }
        guard isDeviceSupported else { return .notSupported }
        guard currentAccount != nil else { return .accountMismatch }
        return isEnabled ? .bound : .notBound
    }

    // MARK: - 开启 / 关闭 / 同步

    /// 开启前先验一次人脸/指纹（系统级验证，失败就不允许开启）
    func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        guard !isAuthenticating else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        isAuthenticating = true
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                completion(success)
            }
        }
    }

    /// 开启绑定：写入 Keychain（账号 + 明文密码）并置位标志
    @discardableResult
    func enable(withPassword pwd: String, boundAddress: String) -> Bool {
        let account = boundAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !account.isEmpty, !pwd.isEmpty else { return false }
        guard BiometricPasswordStore.save(makeRecord(account: account, pwd: pwd)) else { return false }
        FZM_UserDefaults.set(true, forKey: flagKeyPrefix + account)
        return true
    }

    /// 关闭当前账号的绑定
    func disable() {
        guard let account = currentAccount else { return }
        disable(account: account)
    }

    /// 关闭指定账号的绑定（清理别的账号时用，不影响当前账号）
    func disable(account: String) {
        let key = account.lowercased()
        BiometricPasswordStore.delete(address: key)
        FZM_UserDefaults.removeObject(forKey: flagKeyPrefix + key)
    }

    // MARK: - 取密码（会弹人脸/指纹）

    /// 读取绑定的明文密码。`completion` 在主线程回调：
    /// - `pwd != nil`：验证通过且记录归属当前账号（仍需调用方用 `checkPassword` 复核密码是否已变）
    /// - `pwd == nil`：看 `result` 决定回落密码弹窗 / 提示重新开启
    func fetchPassword(reason: String, completion: @escaping (String?, BiometricFetchResult) -> Void) {
        guard let account = currentAccount else {
            DispatchQueue.main.async { completion(nil, .accountMismatch) }
            return
        }
        guard !isAuthenticating else {
            DispatchQueue.main.async { completion(nil, .failed) }
            return
        }
        isAuthenticating = true

        // 读取会同步阻塞到用户完成验证，放后台线程；reason 已由调用方本地化，避免后台线程取文案
        DispatchQueue.global(qos: .userInitiated).async {
            let (record, result) = BiometricPasswordStore.load(address: account, reason: reason)
            DispatchQueue.main.async {
                self.isAuthenticating = false

                guard let record = record else {
                    // 换指纹导致的条目失效：顺手清掉标志位，界面下次会显示为未开启
                    if result == .notBound { self.disable(account: account) }
                    completion(nil, result)
                    return
                }
                guard record.address.lowercased() == account else {
                    completion(nil, .accountMismatch)
                    return
                }
                completion(record.pwd, .success)
            }
        }
    }

    // MARK: - 私有

    private func makeRecord(account: String, pwd: String) -> BiometricBindingRecord {
        BiometricBindingRecord(
            address: account,
            pwd: pwd,
            boundAt: Date().timeIntervalSince1970,
            biometry: biometryTypeName
        )
    }
}
