//
//  AICustomerLauncher.swift
//  chat
//
//  AI 客服统一入口：**push 进当前导航栈**打开客服 H5。
//
//  为什么是 push 而不是 present（2026-09-22 用户明确要求）：
//  客服页本质就是"一个聊天页面"，push 才能和私聊聊天页共用同一个导航栈 ——
//  导航栏样式、返回按钮、右滑返回手势、TabBar 隐藏行为全都自然一致。
//

import UIKit

enum AICustomerLauncher {

    /// 打开 AI 客服页（**push** 进当前导航栈，与私聊聊天页同款交互）。
    /// - Parameter host: 宿主 VC；不传则用当前最上层 VC。
    static func push(from host: UIViewController? = nil) {
        guard let base = host ?? UIViewController.current() else { return }

        let webVC = AICustomerServiceWebVC()
        // 与 FZMUIMediator.pushVC 的约定一致：push 时隐藏 TabBar
        webVC.hidesBottomBarWhenPushed = true

        if let navigationController = base.navigationController {
            navigationController.pushViewController(webVC, animated: true)
            return
        }

        // 兜底：宿主不在导航栈里。正常入口（私聊列表行 / 消息页悬浮球）都到不了这里，
        // 但与其静默失败（点了没反应），不如包一层导航控制器把页面给出去。
        let navigationController = UINavigationController(rootViewController: webVC)
        navigationController.modalPresentationStyle = .fullScreen
        base.present(navigationController, animated: true)
    }
}
