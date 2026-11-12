//
//  ChatPasswordGate.swift
//  chat
//
//  需要密聊密码的统一入口：优先人脸/指纹，失败一律回落「密聊密码弹窗」。
//
//  约定（重要）：
//  1. 门面只负责「把密码给到调用方」，**不校验用户手输的密码** —— 各调用点原有的
//     `GoFunction.checkPassword` 与「密码错误」文案保持不动，改动面最小。
//  2. 人脸/指纹取回来的密码会先复核一次 `checkPassword(取回密码, 当前钱包密码)`：
//     不通过说明密聊密码已变（改密未同步/换了钱包），此时清掉绑定并回落密码弹窗。
//  3. 切换账号、登录流程不接这里（按需求：切换账号必须手输密码）。
//

import UIKit

final class ChatPasswordGate: NSObject {

    // MARK: - 统一入口（会弹密码弹窗）

    /// 取一次已校验的密聊密码：人脸/指纹可用就直接回调，否则弹密聊密码输入框。
    /// - Parameters:
    ///   - title: 密码弹窗标题（人脸验证弹窗的说明文案也用它）
    ///   - cancelled: 用户在密码弹窗里取消（点叉/点蒙层）时回调；人脸取消不会走这里
    ///   - success: 拿到密码（人脸验证通过 或 用户手输并点了确定）
    @objc(requestVerifiedPasswordWithTitle:cancelled:success:)
    static func requestVerifiedPassword(title: String,
                                        cancelled: (() -> Void)?,
                                        success: @escaping (String) -> Void) {
        let reason = title.isEmpty ? L("验证身份") : title

        if FZM_EnableBiometricUnlock, BiometricAuthManager.shared.bindState == .bound {
            BiometricAuthManager.shared.fetchPassword(reason: reason) { pwd, result in
                if let pwd = pwd, GoFunction.checkPassword(pwd, hash: currentWalletPassword()) {
                    success(pwd)
                    return
                }
                switch result {
                case .success:
                    // 人脸通过了，但存着的那份密码已不是当前密聊密码：清绑定 + 提示重新开启
                    BiometricAuthManager.shared.disable()
                    showToast(L("密聊密码已变更，请重新开启面容/指纹验证"))
                case .notBound, .accountMismatch:
                    // 未绑定 / 系统里的人脸指纹变过导致条目作废 / 账号不匹配
                    BiometricAuthManager.shared.disable()
                    showToast(L("面容/指纹验证已失效，请重新开启并输入密聊密码"))
                default:
                    break // 用户取消、识别失败、锁屏或后台：静默回落密码弹窗
                }
                showPasswordAlert(title: title, cancelled: cancelled, success: success)
            }
            return
        }

        showPasswordAlert(title: title, cancelled: cancelled, success: success)
    }

    // MARK: - 给自带密码输入框的弹层用（不弹密码弹窗）

    /// 仅供「自己已经有密码输入框」的界面使用（DApp 授权弹层、取消授权弹层）：
    /// 人脸/指纹可用且复核通过时回调明文密码，否则回调 nil，由调用方决定是否让用户手输。
    @objc(fetchVerifiedPasswordWithReason:completion:)
    static func fetchVerifiedPassword(reason: String, completion: @escaping (String?) -> Void) {
        guard FZM_EnableBiometricUnlock, BiometricAuthManager.shared.bindState == .bound else {
            completion(nil)
            return
        }
        BiometricAuthManager.shared.fetchPassword(reason: reason) { pwd, result in
            if let pwd = pwd, GoFunction.checkPassword(pwd, hash: currentWalletPassword()) {
                completion(pwd)
                return
            }
            if result == .success || result == .notBound {
                BiometricAuthManager.shared.disable()
                if result == .success {
                    showToast(L("密聊密码已变更，请重新开启面容/指纹验证"))
                }
            }
            completion(nil)
        }
    }

    // MARK: - 私有

    private static func currentWalletPassword() -> String? {
        PWDataBaseManager.shared().queryWalletIsSelected()?.wallet_password
    }

    private static func showPasswordAlert(title: String,
                                          cancelled: (() -> Void)?,
                                          success: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            let alert = InputAlertView()
            alert.title = title.isEmpty ? L("请输入密聊密码") : title
            alert.textFieldAttributedPlaceholder = NSAttributedString(
                string: L("请输入密码"),
                attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                             NSAttributedString.Key.foregroundColor: Color_8A97A5])
            alert.isSecureTextEntry = true
            // ⚠️ InputAlertView 在「确定」后也会走 hideBlock，用这个标记区分「取消」与「已提交」
            var didConfirm = false
            alert.confirmBlock = { password in
                didConfirm = true
                success(password)
            }
            alert.hideBlock = {
                if !didConfirm { cancelled?() }
            }
            alert.show()
        }
    }

    private static func showToast(_ text: String) {
        DispatchQueue.main.async {
            APP.shared().showToast(text)
        }
    }
}
