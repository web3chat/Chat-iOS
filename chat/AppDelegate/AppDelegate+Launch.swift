//
//  AppDelegate+Launch.swift
//  chat
//
//  Created by fzm on 2021/1/12.
//

import Foundation
import Kingfisher

extension AppDelegate {
    func launch() {
        // 有场景生命周期时窗口由 SceneDelegate 创建（iOS 27 起不接场景会直接崩），
        // 只有没有场景的旧路径才在这里建窗。
        if !AppDelegate.isSceneLifecycleEnabled {
            self.launchView()
        }
        let _ = APP.shared()
        let _ = DBManager.shared()
        let _ = SessionManager.shared()
        let _ = UserManager.shared()
        let _ = GroupManager.shared()
        let _ = TeamManager.shared()
        
        // 定时删除聊天记录：App 启动时执行一次
        ChatManager.shared().autoDeleteExpiredMessages()
        // 阅后即焚：补发待确认（登录后才会有用户库；接口幂等）
        ChatManager.shared().resendPendingBurnConfirms()
        
        // 定时删除聊天记录：App 进入前台时执行
        FZM_NotificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { (_) in
            ChatManager.shared().autoDeleteExpiredMessages()
            ChatManager.shared().resendPendingBurnConfirms()
        }
        
        // 配置 Kingfisher 图片缓存：存到不会被系统清理的 Application Support 目录。
        // ⚠️ 因为这个目录系统不会帮忙清，所以「配额 / 过期」必须自己控制 ——
        //    目前由「省图模式」开关（`FZM_EnableImageSaveMode`）决定是否启用：
        //    关闭时保持原策略（永不过期、不限量）；开启后 30 天过期 + 400MB 上限。
        // 系统目录理论上一定有；空数组时强解包会崩，兜底到沙盒 Library/Application Support
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        ImageCache.default.diskStorage.config.cachePathBlock = { _, cacheName in
            return appSupportURL.appendingPathComponent(cacheName, isDirectory: true)
        }
        if FZM_EnableImageSaveMode {
            ImageCache.default.diskStorage.config.expiration = .days(30)
            ImageCache.default.diskStorage.config.sizeLimit = 400 * 1024 * 1024// 400MB
            ImageCache.default.cleanExpiredDiskCache()
        } else {
            ImageCache.default.diskStorage.config.expiration = .never
            ImageCache.default.diskStorage.config.sizeLimit = 0// 0 = 不限量
        }
        // 内存缓存设置上限，避免图片缓存无界增长导致内存压力（真机卡顿/被系统杀）
        ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024// 100MB
        ImageCache.default.memoryStorage.config.countLimit = 200

        // 聊天媒体专用缓存（`ChatMediaCache`，见 CommonTools）：同样落到 Application Support，
        // 但**永不过期、不限量** —— 聊天图片属于消息内容，「清理缓存」不会清它，
        // 清理统一走「聊天记录 / 单个会话」的清理入口。
        ChatMediaCache.diskStorage.config.cachePathBlock = { _, cacheName in
            return appSupportURL.appendingPathComponent(cacheName, isDirectory: true)
        }
        ChatMediaCache.diskStorage.config.expiration = .never
        ChatMediaCache.diskStorage.config.sizeLimit = 0
        ChatMediaCache.memoryStorage.config.totalCostLimit = 60 * 1024 * 1024// 60MB
        ChatMediaCache.memoryStorage.config.countLimit = 150

        // SDWebImage（广场大图）：只在省图模式下配额 + 过期
        if let sdCache = SDWebImageManager.shared().imageCache {
            sdCache.config.maxCacheSize = FZM_EnableImageSaveMode ? 200 * 1024 * 1024 : 0
            sdCache.config.maxCacheAge = FZM_EnableImageSaveMode ? 7 * 24 * 60 * 60 : 60 * 60 * 24 * 7
        }
        
        OSS.launchClient()
        DispatchQueue.main.async {
            MultipleSocketManager.shared().updateConnectedSockets()
        }
    }
}

