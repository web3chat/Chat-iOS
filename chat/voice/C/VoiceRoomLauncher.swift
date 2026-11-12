//
//  VoiceRoomLauncher.swift
//  chat
//
//  语音房的统一入口：**登录闸门 + 用 DApp 浏览器打开**。
//
//  ⚠️ 为什么用 DApp 浏览器（`DAppBrowserViewController`）而不是专用容器：
//     产品要求「进入语音房时用的浏览器必须是 DApp 浏览器」，所以音视频能力
//     （媒体配置、`window.H5Wallet` 地址桥、麦克风、音频会话、自签证书放行、自动登录）
//     统一由 `VoiceRoomWebSupport` 挂在 DApp 浏览器上 —— 原先的 `InAppBrowserVC` 已删除。
//
//  调用点（纯 Swift；`enum` 无 case，不需要对 OC 暴露 —— 发现页本来就打开 DApp 浏览器，无需改道）：
//   · 聊天消息里的语音房链接 → `ChatVC.openUrl(urlStr:)`
//   · 聊天「+」→「语音房」自建房 → `ChatVC.sendVoiceRoom()`
//   · DApp 浏览器内的导航命中语音房链接 → `DAppBrowserViewController.webView(_:decidePolicyFor:decisionHandler:)`
//

import UIKit

enum VoiceRoomLauncher {

    /// 是否语音房链接（唯一判定入口，转发到 `VoiceRoomWebSupport`）
    static func isVoiceRoomLink(_ url: URL) -> Bool {
        VoiceRoomWebSupport.isVoiceRoomLink(url)
    }

    /// 用 DApp 浏览器打开语音房
    /// - Parameters:
    ///   - url: 必须是 http/https（调用方负责过滤）
    ///   - host: 宿主 VC；不传则用当前最上层 VC
    static func open(url: URL, from host: UIViewController? = nil) {
        guard let base = host ?? UIViewController.current() else { return }

        // 语音房：进房身份靠 `window.H5Wallet.getAddress()` 提供，地址拿不到就别进
        // （否则会被服务端判为未授权进房）。未登录 / 未创建钱包时 `getCurrentWalletAddress()` 返回空串。
        if isVoiceRoomLink(url) {
            guard !VoiceRoomWebSupport.currentWalletAddress().isEmpty else {
                base.showToast(L("请先登录"))
                return
            }
        }

        // 语音房：走**通话界面**（全屏 ↔ 悬浮框），**不进导航栈**
        //
        // ⚠️ 页面本身仍然是 DApp 浏览器（`DAppBrowserViewController`）—— 媒体配置 / `H5Wallet`
        //    地址桥 / 麦克风 / 音频会话 / 自签证书这些能力全挂在它身上，只是改装进通话容器。
        //    不用 push 而用容器，是因为产品要的两件事 push 做不到：
        //      ① 悬浮框要能浮在 App 任意页面之上（用户一边通话一边继续用 App）；
        //      ② 通话期间不能有返回按钮、不能侧滑返回。
        //    同一个房间重复打开由 `VoiceRoomCallContainerVC.present` 内部去重。
        if isVoiceRoomLink(url) {
            let browser = DAppBrowserViewController(url: url)
            VoiceRoomCallContainerVC.present(browser: browser, from: base)
            return
        }

        // 非语音房（调用方都会先过 `isVoiceRoomLink`，这里只是兜底）：维持原来的 push 行为
        if let top = base.navigationController?.topViewController as? DAppBrowserViewController,
           top.initialURL == url {
            return
        }

        let vc = DAppBrowserViewController(url: url)
        // 与 `FZMUIMediator.pushVC` 的约定一致：push 时隐藏 TabBar
        vc.hidesBottomBarWhenPushed = true

        if let navigationController = base.navigationController {
            navigationController.pushViewController(vc, animated: true)
            return
        }

        // 兜底：宿主不在导航栈里。与其静默失败（点了没反应），不如包一层导航控制器给出去。
        let navigationController = UINavigationController(rootViewController: vc)
        navigationController.modalPresentationStyle = .fullScreen
        base.present(navigationController, animated: true)
    }
}
