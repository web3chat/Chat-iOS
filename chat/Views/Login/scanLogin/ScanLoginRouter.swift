//
//  ScanLoginRouter.swift
//  chat
//
//  扫码登录（PC 网页版）入口接管
//  扫一扫拿到二维码内容后先走这里：命中扫码登录二维码 → 弹确认页并消费掉该内容
//

import UIKit

@objc final class ScanLoginRouter: NSObject {

    /// 处理扫码结果中的「扫码登录」二维码
    /// - Parameters:
    ///   - qrString: 二维码原始内容
    ///   - host: 发起扫码的页面（一般为 `UIViewController.current()`）
    /// - Returns: `true` 表示内容已被消费，调用方不要再走其它扫码分支
    @discardableResult
    @objc static func handle(qrString: String, from host: UIViewController?) -> Bool {
        // 旧版 v1 二维码已停用：明确提示并消费掉，避免被后面的分支当成普通网址/文本
        if ScanLoginQRPayload.isLegacyQRCode(qrString) {
            let presenter = host ?? UIViewController.current()
            presenter?.showToast(L("该二维码为旧版登录码，请在电脑端刷新后重试"))
            FZMLog("扫码登录：识别到已停用的 v1 二维码")
            return true
        }

        guard let payload = ScanLoginQRPayload.parse(qrString) else {
            // 不是扫码登录二维码，交回调用方按普通二维码处理
            return false
        }

        guard let presenter = host ?? UIViewController.current() else {
            FZMLog("扫码登录：找不到可用的弹窗宿主")
            return true
        }
        // 没有本地账号就没有私钥，无法完成确认
        guard LoginUser.shared().isLogin else {
            presenter.showToast(L("未登录，无法确认网页登录"))
            return true
        }

        FZMLog("扫码登录：识别到登录二维码 version=v2(ECDH) session=\(payload.sessionId)")

        let vc = ScanLoginConfirmVC(payload: payload)
        let nav = FZMNavigationController(rootViewController: vc)
        // 必须走页面里的「取消」才关闭：避免下滑随手关掉导致会话一直等待、PC 端不知情
        nav.isModalInPresentation = true
        presenter.present(nav, animated: true, completion: nil)
        return true
    }
}
