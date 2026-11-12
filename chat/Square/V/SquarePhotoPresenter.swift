//
//  SquarePhotoPresenter.swift
//  chat
//
//  广场大图浏览统一入口（列表 / 帖子详情 / 我的页面共用）+ 预取
//
//  两个坑：
//  1. IDMPhotoBrowser 用 SDWebImage 加载网络图，而列表用的是 Kingfisher，两边缓存不共用，
//     不预热的话每次点开都要重新下载 → 先糊一阵再清晰；
//  2. 它的「从缩略图放大」动画是往 application window 上加临时图、并先把自身 view 的 alpha 置 0，
//     所以（a）presenting 视图必须保留（否则动画期间露黑底）、（b）不能再叠 UIKit 的呈现过渡动画
//     （crossDissolve 的淡入会和它抢 alpha，导致先闪一下大图再播放放大动画）。
//

import Foundation
import UIKit
import SDWebImage
import IDMPhotoBrowser

enum SquarePhotoPresenter {

    /// 打开大图
    /// - Parameters:
    ///   - urls: 该帖的全部图片（用于左右翻页）
    ///   - index: 当前点开的下标
    ///   - imageView: 动画源视图（缩略图所在的 imageView，不能为 nil，否则 IDM 会用 0 尺寸创建绘图上下文而崩溃）
    static func present(urls: [String], index: Int, from imageView: UIImageView, in viewController: UIViewController) {
        // 预热：IDM 内部用 SDWebImage 加载，这里先把图灌进它的缓存。
        // 按「离当前点开的这张最近」的顺序预热：用户最可能马上左右滑动，先保证相邻几张到位
        SquarePhotoPrefetcher.prefetch(urls, startingAt: index)

        var photos = [Any]()
        for url in urls {
            // 用归一化后的地址，兼容服务端返回相对 key / 缺协议的情况；
            // 并且按屏宽取图（原图几 MB，屏宽版往往只有几百 KB，点开快很多，缩放看也够清）
            guard let link = SquarePhotoPresenter.browserURL(from: url) else { continue }
            // 已在 SDWebImage 内存缓存里的（列表停留时已预热）：直接给 UIImage，
            // IDM 无需再走异步加载 ⇒ 点开 / 滑动都不会闪一下 loading
            if let cached = SquarePhotoPrefetcher.memoryCachedImage(for: link),
               let photo = IDMPhoto(image: cached) {
                photos.append(photo)
            } else if let photo = IDMPhoto(url: link) {
                photos.append(photo)
            }
        }
        guard !photos.isEmpty else {
            viewController.showToast(with: L("图片打开失败"))
            return
        }
        guard index >= 0, index < photos.count else { return }

        if let photo = photos[index] as? IDMPhoto {
            photo.placeholderImage = imageView.image
        }

        // 注意：FZMPhotoBrowser 的 init 声明为 `init!`，不标注类型会被推断成可选值
        let browser: FZMPhotoBrowser = FZMPhotoBrowser.init(photos: photos, animatedFrom: imageView)
        // overFullScreen：保留 presenting 视图（放大动画期间不黑屏），同时覆盖全屏遮住底部导航栏
        browser.modalPresentationStyle = .overFullScreen
        // 缩略图还没加载完时 image 为 nil，IDM 会退化成 [view.layer renderInContext:]
        // （view 尺寸为 0 时 UIGraphicsBeginImageContextWithOptions 返回 NULL → 崩），给一张 1×1 透明图兜住
        browser.scaleImage = imageView.image ?? transparentPixel()
        browser.setInitialPageIndex(UInt(index))
        // animated: false —— 只让 IDM 自己的放大动画生效，避免和 Present 过渡的淡入叠加出「闪一下」
        viewController.present(browser, animated: false)
    }

    /// 大图浏览要用的像素宽度：屏宽 × scale × 1.5（留一点捏合放大的余量）
    static var browserPixelWidth: CGFloat {
        return UIScreen.main.bounds.width * UIScreen.main.scale * 1.5
    }

    /// 大图地址：能取 OSS 小图就取小图（屏宽版），否则原地址
    static func browserURL(from raw: String) -> URL? {
        return SquareMediaURLParser.previewURL(from: raw, maxPixelWidth: browserPixelWidth)
            ?? SquareMediaURLParser.url(from: raw)
    }

    /// 1×1 透明图：给 IDMPhotoBrowser 当动画源图兜底
    private static func transparentPixel() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        UIColor.clear.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - 大图预取

/// IDMPhotoBrowser 内部用 SDWebImage 加载网络图，而列表用的是 Kingfisher，两边缓存不共用，
/// 所以点开大图前先预热：放大动画播放期间图片已经在下载/已进缓存，避免「先糊一下再变清晰」、换页也要等。
enum SquarePhotoPrefetcher {

    // 下面几个状态只在主线程访问（列表配置 / 点开大图都发生在主线程）
    /// 已经预热过的地址集合（同一批图不重复预热）
    private static var warmedKeys = Set<String>()
    /// 已排期但还没触发的预热（cell 被复用到别的帖子时取消，避免快速滑动时产生大量无效下载）
    private static var pendingItems = [String: DispatchWorkItem]()

    /// 预热（默认按传入顺序；`startingAt` 时按距该下标的远近由近及远）
    static func prefetch(_ urls: [String], startingAt startIndex: Int = 0) {
        for url in orderedURLs(urls, startingAt: startIndex) {
            // 必须和 SquarePhotoPresenter.present 里用的是同一个地址，否则预热全白做
            guard let link = SquarePhotoPresenter.browserURL(from: url), isRemote(link) else { continue }
            // 注意：SDWebImage 4 的 loadImage(with:...) 里有
            //   NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");
            // 传 nil 会在 Debug 下直接断言崩溃 —— 必须给一个空回调（这里的 block 是 6 个参数）
            SDWebImageManager.shared().loadImage(with: link, options: [], progress: nil, completed: { (_, _, _, _, _, _) in })
        }
    }

    /// 帖子图片进入可视区后延时预热「大图（屏宽版）」，让点开 / 左右滑动不再等下载。
    /// - Parameters:
    ///   - urls: 该帖全部图片（必须与 `present` 用的是同一批地址）
    ///   - key: 去重标识（通常是这批地址）；同一批只预热一次
    /// 延时 0.6s：快速滑过的帖子还没到时间就已经被取消，不会产生无效流量。
    static func prefetchWhenVisible(_ urls: [String], key: String) {
        guard !urls.isEmpty, !warmedKeys.contains(key) else { return }
        pendingItems[key]?.cancel()
        let item = DispatchWorkItem {
            pendingItems[key] = nil
            if warmedKeys.count > 300 { warmedKeys.removeAll() }
            warmedKeys.insert(key)
            prefetch(urls)
        }
        pendingItems[key] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    /// 取消尚未触发的预热（cell 被复用到别的帖子时调用）
    static func cancelPending(key: String) {
        pendingItems[key]?.cancel()
        pendingItems[key] = nil
    }

    /// SDWebImage 内存缓存命中则直接返回（key 与 SDWebImageManager 内部规则一致）
    static func memoryCachedImage(for url: URL) -> UIImage? {
        let manager = SDWebImageManager.shared()
        let key = manager.cacheKeyFilter?(url) ?? url.absoluteString
        return manager.imageCache?.imageFromMemoryCache(forKey: key)
    }

    /// 按距 `startIndex` 由近及远重排（1, 2, 3 … 而不是从 0 开始）
    private static func orderedURLs(_ urls: [String], startingAt startIndex: Int) -> [String] {
        guard urls.count > 1 else { return urls }
        let start = min(max(startIndex, 0), urls.count - 1)
        var ordered = [urls[start]]
        var step = 1
        while ordered.count < urls.count {
            let forward = start + step
            let backward = start - step
            if forward < urls.count { ordered.append(urls[forward]) }
            if backward >= 0 { ordered.append(urls[backward]) }
            step += 1
        }
        return ordered
    }

    /// 只预热网络图（发帖预览里的本地图片不需要）
    private static func isRemote(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
