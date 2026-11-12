//
//  UIImageView+Tool.swift
//  Chat33
//
//  Created by fzm on 2018/9/19.
//  Copyright © 2018年 fzm. All rights reserved.
//

import Foundation
import YYImage
import UIKit

extension UIImageView{
    
    func loadNetworkImage(with url: String, placeImage: UIImage?, completeBlock: OptionImageBlock? = nil) {
        self.yy_cancelCurrentImageRequest()
        if url.count > 0 && url.contains("http") {
            self.yy_setImage(with: URL(string: url), placeholder: placeImage, options: .setImageWithFadeAnimation) { (image, _, _, _, _) in
                completeBlock?(image)
            }
        }else {
            self.image = placeImage
        }
    }
    
    private var topClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "topClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "topClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    private var rightClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "rightClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "rightClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    private var bottomClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "bottomClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "bottomClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    private var leftClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "leftClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "leftClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    func enlargeClickEdge(_ top : CGFloat? ,_ left : CGFloat? ,_ bottom : CGFloat? ,_ right : CGFloat?){
        self.topClickOffset = top
        self.leftClickOffset = left
        self.bottomClickOffset = bottom
        self.rightClickOffset = right
    }
    
    private func enlargedRect() -> CGRect{
        return CGRect.init(x : self.bounds.origin.x - self.leftClickOffset!,
                           y :  self.bounds.origin.y - self.topClickOffset!,
                           width : self.bounds.size.width + self.leftClickOffset! + self.rightClickOffset!,
                           height : self.bounds.size.height + self.topClickOffset! + self.bottomClickOffset!);
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let rect : CGRect = self.enlargedRect()
        if rect.equalTo(self.bounds) {
            return super.hitTest(point, with: event)
        }
        if rect.contains(point) && !self.isHidden {
            return self
        }
        return nil
    }
}

// MARK: - 头像：同步优先贴图（避免每次进页面「先闪默认头像」）

/// 头像缩略图缓存：按 `cacheKey|url` 把一张小图写到 **Application Support**，
/// 命中就**同步**贴到 imageView 上（同一个 RunLoop，用户看不到占位图）。
///
/// 为什么不用 Kingfisher 的缓存：
/// · `kf.setImage` 即使命中缓存，赋值也在**下一个 RunLoop**（`CallbackQueue.mainCurrentOrAsync`），
///   列表 reload / cell 复用复位的那一帧露出来的就是默认头像；
/// · 它的磁盘缓存在 Caches（可能被系统清理），且 key 依赖 URL（换 URL 就失效）。
///
/// key 里带 URL ⇒ 换头像（URL 变）会重新加载，不会把旧头像永久留住。
enum AvatarThumbnailStore {

    private static let memory = NSCache<NSString, UIImage>()
    private static let ioQueue = DispatchQueue(label: "com.fzm.avatar.thumbnail", qos: .utility)
    /// 本次启动内已经查过 Kingfisher 磁盘 / 确认过没有缩略图的 key（避免反复 IO）。
    /// ⚠️ 只在主线程（cell 配置）读写。
    private static var checkedKingfisherKeys = Set<String>()
    private static var missingThumbnailKeys = Set<String>()

    private static let directoryURL: URL? = {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = base.appendingPathComponent("AvatarThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }()

    /// 本地缩略图（内存 → 磁盘），没有返回 nil
    static func cached(forKey key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        if let image = memory.object(forKey: key as NSString) { return image }
        guard !missingThumbnailKeys.contains(key),
              let file = fileURL(for: key),
              let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else {
            missingThumbnailKeys.insert(key)
            return nil
        }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    /// 记录一张图（内存立即生效；缩略图落盘在后台）
    static func store(_ image: UIImage, forKey key: String, size: CGSize) {
        guard !key.isEmpty else { return }
        memory.setObject(image, forKey: key as NSString)
        missingThumbnailKeys.remove(key)
        ioQueue.async {
            guard let file = fileURL(for: key),
                  let data = thumbnail(image, size: size).pngData() else { return }
            try? data.write(to: file, options: .atomic)
        }
    }

    /// 同步读 Kingfisher 磁盘缓存（每个 URL 每次启动只读一次）。
    /// `loadDiskFileSynchronously` + `.untouch` 回调 ⇒ 读盘 + 解码 + 回调都在当前线程完成。
    static func kingfisherDiskImage(for urlString: String) -> UIImage? {
        guard !urlString.isEmpty, !checkedKingfisherKeys.contains(urlString) else { return nil }
        checkedKingfisherKeys.insert(urlString)
        var image: UIImage?
        ImageCache.default.retrieveImageInDiskCache(forKey: urlString,
                                                   options: [.loadDiskFileSynchronously],
                                                   callbackQueue: .untouch) { result in
            if case .success(let value) = result { image = value }
        }
        return image
    }

    // MARK: 内部

    private static func fileURL(for key: String) -> URL? {
        guard let directory = directoryURL else { return nil }
        return directory.appendingPathComponent(stableHash(key) + ".png")
    }

    /// FNV-1a（稳定、跨启动一致；不能直接用 `String.hashValue`，它每次启动都变）
    private static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    /// 等比铺满后居中裁剪成正方形缩略图（头像用，不变形）
    private static func thumbnail(_ image: UIImage, size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0, image.size.width > 0, image.size.height > 0 else { return image }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (size.width - drawSize.width) / 2,
                                  y: (size.height - drawSize.height) / 2,
                                  width: drawSize.width,
                                  height: drawSize.height))
        }
    }
}

extension UIImageView {

    /// 头像贴图：**同步优先**，三级取图都尽量在同一帧完成，避免「先闪默认头像」。
    ///
    /// ① 本地缩略图（自己落的盘，杀 App 重进也在）；
    /// ② Kingfisher 内存缓存（别的页面已经加载过）；
    /// ③ Kingfisher 磁盘缓存（同步读一次）；
    /// ④ 都没有 → 占位图 + 异步下载，成功后落本地缩略图。
    ///
    /// - Parameters:
    ///   - cacheKey: 业务主键（如会话地址 / 团队 id）；与 URL 拼成最终 key
    ///   - urlString: 头像地址（空 → 只显示占位图）
    ///   - placeholder: 占位图
    ///   - size: 缩略图尺寸（pt，按屏幕 scale 输出像素）
    func loadAvatarSynchronously(cacheKey: String,
                                 urlString: String,
                                 placeholder: UIImage,
                                 size: CGSize = CGSize(width: 35, height: 35)) {
        let url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "\(cacheKey)|\(url)"

        if let cached = AvatarThumbnailStore.cached(forKey: key) {
            kf.cancelDownloadTask()
            image = cached
            return
        }
        guard !url.isEmpty, let link = URL(string: url) else {
            kf.cancelDownloadTask()
            image = placeholder
            return
        }
        if let memoryImage = ImageCache.default.retrieveImageInMemoryCache(forKey: link.absoluteString) {
            AvatarThumbnailStore.store(memoryImage, forKey: key, size: size)
            kf.cancelDownloadTask()
            image = memoryImage
            return
        }
        if let diskImage = AvatarThumbnailStore.kingfisherDiskImage(for: link.absoluteString) {
            AvatarThumbnailStore.store(diskImage, forKey: key, size: size)
            kf.cancelDownloadTask()
            image = diskImage
            return
        }
        kf.setImage(with: link, placeholder: placeholder) { result in
            if case .success(let value) = result {
                AvatarThumbnailStore.store(value.image, forKey: key, size: size)
            }
        }
    }
}
