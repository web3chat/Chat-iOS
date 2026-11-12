//
//  SceneDelegate.swift
//  chat
//
//  iOS 13+ 场景生命周期入口。
//
//  ⚠️ 为什么必须有这个类：
//  iOS 27（24B5099f 起）对「Info.plist 声明了 UIApplicationSceneManifest，
//  却没有接场景生命周期」的 App 直接抛运行时问题并 `__builtin_trap`：
//    _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption
//    → EXC_BREAKPOINT (SIGTRAP)，表现为一启动就闪退。
//
//  这里只负责「在场景里创建窗口」+「把前后台回调转发给 AppDelegate」，
//  其余启动逻辑（launch()）完全保持在 AppDelegate，行为与原来一致。
//

import UIKit

@available(iOS 13.0, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - 连接

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        // 复用 AppDelegate 里原有的建窗逻辑（rootViewController 仍是同一套）
        appDelegate.launchView(in: windowScene)
        window = appDelegate.window
    }

    // MARK: - 生命周期转发

    /// 原来写在 AppDelegate 的前后台逻辑（socket 断开/重连、通知权限）在这里继续生效：
    /// 接入场景后 UIKit 不再调用 AppDelegate 的 applicationDidEnterBackground 等方法。

    func sceneDidBecomeActive(_ scene: UIScene) {
        appDelegate?.applicationDidBecomeActive(UIApplication.shared)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        appDelegate?.applicationWillResignActive(UIApplication.shared)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        appDelegate?.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        appDelegate?.applicationDidEnterBackground(UIApplication.shared)
    }

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }
}
