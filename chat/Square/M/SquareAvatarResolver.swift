//
//  SquareAvatarResolver.swift
//  chat
//
//  广场头像解析：帖子/评论接口只返回 authorAddr，不返回头像，
//  这里按地址依次从「本地登录信息 → 内存/数据库 → 链上」解析，并做缓存与并发合并。
//  文件末尾的 `SquareAvatarLoader` 负责贴图：已加载过的头像同步贴，避免刷新时闪占位图。
//

import Foundation
import UIKit
import Kingfisher

enum SquareAvatarResolver {

    /// address → 头像地址（空串表示查询过但没有头像，做负缓存避免重复请求）
    private static var cache = [String: String]()
    /// 同一地址的并发请求合并，避免列表里每个 cell 各发一次
    private static var pending = [String: [(String?) -> Void]]()
    /// 注意：`UserManager.getUser(by:)` 的回调可能在**后台线程**回来，
    /// 而 cache / pending 是全局可变字典（每行 cell 都会读写）——不加锁会并发读写同一个 Dictionary，
    /// 轻则数据错乱，重则直接崩（Simultaneous accesses / EXC_BAD_ACCESS）。
    private static let lock = NSLock()

    /// 解析某地址的头像 URL（回调保证在主线程；没有头像时回 nil）
    static func avatarURL(for address: String, completion: @escaping (String?) -> Void) {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            deliver(nil, to: [completion])
            return
        }

        // 自己：直接用本地登录信息，保证改头像后立即生效
        if address == LoginUser.shared().address {
            let url = LoginUser.shared().avatarUrl
            deliver(url.isEmpty ? nil : url, to: [completion])
            return
        }

        // 已经解析过（含负缓存）：直接回，注意加锁
        lock.lock()
        let cached = cache[address]
        let alreadyPending = pending[address] != nil
        if alreadyPending {
            pending[address]?.append(completion)
        } else if cached == nil {
            pending[address] = [completion]
        }
        lock.unlock()

        if let cached = cached {
            deliver(cached.isEmpty ? nil : cached, to: [completion])
            return
        }
        if alreadyPending {
            return
        }

        // UserManager 内部顺序：内存缓存 → 本地数据库 → 链上拉取（会写回数据库）
        // 注意：这个回调可能在后台线程回来，所以写 cache / pending 必须加锁
        UserManager.shared().getUser(by: address) { user in
            let url = user?.avatarURLStr ?? ""

            lock.lock()
            cache[address] = url
            let callbacks = pending[address] ?? []
            pending[address] = nil
            lock.unlock()

            deliver(url.isEmpty ? nil : url, to: callbacks)
        }
    }

    /// 回调统一在主线程；已经在主线程时**同步**回调 ——
    /// 多一次 RunLoop 跳转就意味着列表里会先闪一帧占位图（头像会“闪一下”）
    private static func deliver(_ url: String?, to completions: [(String?) -> Void]) {
        let run = { completions.forEach { $0(url) } }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    /// 清空缓存（登录用户切换时可选调用）
    static func reset() {
        lock.lock()
        cache.removeAll()
        pending.removeAll()
        lock.unlock()
    }
}

// MARK: - 头像贴图

/// 广场头像加载：**已加载过的头像同步贴上去**（同一个 RunLoop 内完成，
/// 复用/重启 cell 时用户看不到占位图），没加载过才走 Kingfisher 并写回内存。
///
/// 为什么需要它：`kf.setImage` 即使命中缓存，图片也是在**下一个 RunLoop** 才赋到
/// imageView 上（`CallbackQueue.mainCurrentOrAsync`），而列表刷新会先给 cell 置占位图，
/// 这一帧就是用户看到的「头像闪一下」。
///
/// key 统一用**图片地址串**（地址不变 = 图片内容不变，OSS key 带时间戳，换头像必换地址）。
enum SquareAvatarLoader {

    /// 已加载过的头像（按「地址 + 降采样尺寸」存，避免同一地址的不同尺寸互相顶掉）
    static func cachedImage(forKey key: String) -> UIImage? {
        SquareImageMemoryCache.image(forKey: key)
    }

    /// 已加载过的头像：按「地址 + 降采样尺寸」查（同步命中内存缓存，没加载过返回 nil）
    /// - Parameter downsampleSize: 必须与 `apply(to:...)` 传的尺寸一致才能命中
    static func cachedImage(url: URL, downsampleSize: CGSize) -> UIImage? {
        return cachedImage(forKey: cacheKey(key: url.absoluteString, downsampleSize: downsampleSize))
    }

    /// 贴头像
    /// - Parameters:
    ///   - downsampleSize: 需要降采样到的像素尺寸（不传就按原图）
    ///   - completion: 结果回调（主线程）；失败时调用方要清掉自己「已贴过」的记录，以便下次重试
    static func apply(to imageView: UIImageView,
                      url: URL,
                      key: String,
                      placeholder: UIImage,
                      downsampleSize: CGSize? = nil,
                      completion: ((Bool) -> Void)? = nil) {
        let storageKey = cacheKey(key: key, downsampleSize: downsampleSize)

        // 命中内存：同步贴，不闪
        if let cached = cachedImage(forKey: storageKey) {
            imageView.kf.cancelDownloadTask()
            imageView.image = cached
            completion?(true)
            return
        }

        var options: KingfisherOptionsInfo = [.keepCurrentImageWhileLoading]
        if let size = downsampleSize {
            options.append(.processor(DownsamplingImageProcessor(size: size)))
        }
        imageView.kf.setImage(with: url, placeholder: placeholder, options: options,
                              completionHandler: { result in
            switch result {
            case .success(let value):
                // 存的是「处理之后」的图（与直接显示的一致），下次就能同步贴
                store(value.image, forKey: storageKey)
                completion?(true)
            case .failure:
                completion?(false)
            }
        })
    }

    /// 内存缓存的 key（同一地址的不同降采样尺寸不能混用）
    private static func cacheKey(key: String, downsampleSize: CGSize?) -> String {
        guard let size = downsampleSize else { return key }
        return "\(key)@\(Int(size.width))x\(Int(size.height))"
    }

    static func store(_ image: UIImage, forKey key: String) {
        SquareImageMemoryCache.store(image, forKey: key)
    }
}

// MARK: - 图片内存缓存（头像 / 九宫格共用）

/// 广场图片内存缓存：key = **图片地址串**（地址不变 = 内容不变；OSS key 带时间戳，换图必换地址）。
///
/// 存在的意义：Kingfisher 即使命中缓存，赋值也发生在**下一个 RunLoop**
/// （`CallbackQueue.mainCurrentOrAsync`），而 cell 重新配置时先会置占位图/空图，
/// 那一帧就是用户看到的「刷新时闪一下」。命中这份缓存就能**同步**贴图，一帧都不闪。
enum SquareImageMemoryCache {

    /// 图片都很小（头像降采样后几十 KB、九宫格小图几百 KB），500 张够来回滚好几屏
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        return cache
    }()

    static func image(forKey key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        return cache.object(forKey: key as NSString)
    }

    static func store(_ image: UIImage, forKey key: String) {
        guard !key.isEmpty else { return }
        cache.setObject(image, forKey: key as NSString)
    }

    /// 清空内存缓存（设置页「清理缓存」用）。只丢内存，磁盘缓存与消息数据不动。
    static func removeAll() {
        cache.removeAllObjects()
    }
}
