//
//  UIImage+Extension.swift
//  xls
//
//  Created by fzm on 2020/12/8.
//  Copyright © 2020 fzm. All rights reserved.
//

import Foundation
import ImageIO
import Kingfisher
import UIKit

extension UIImage{
    
    /// 安全解码图片数据：先只读元数据，再用 ImageIO **降采样解码**成位图。
    ///
    /// 背景（TestFlight 1.1(18) / iOS 26.6.2，2026-10-13 崩溃）：
    /// 未解码的 JPEG（`UIImage(data:)`、或从磁盘缓存恢复的图片）直接赋给 `UIImageView` 时，
    /// CA 提交会在**主线程**走 `CA::Layer::prepare_contents` → ImageIO → `CMPhotoUnifiedJPEGDecoderDecode`
    /// 硬解；原图尺寸过大时 `CMPhotoCreateMemorySurface` 创建 IOSurface 直接 SIGSEGV（无 App 栈）。
    /// ⇒ 图片数据一律先在这里按最大边 `maxPixelSize` 解码；尺寸异常的直接丢弃（宁可不显示也不崩）。
    static func safeDecodedImage(data: Data,
                                 maxPixelSize: CGFloat = 1280,
                                 maxDimension: CGFloat = 12000,
                                 maxTotalPixels: CGFloat = 60_000_000) -> UIImage? {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let pixelSize = UIImage.pixelSize(of: source) else {
            return nil
        }
        guard pixelSize.width <= maxDimension,
              pixelSize.height <= maxDimension,
              pixelSize.width * pixelSize.height <= maxTotalPixels else {
            FZMLog("【图片解码】尺寸超限已丢弃 \(Int(pixelSize.width))x\(Int(pixelSize.height)) data=\(data.count)B")
            return nil
        }
        // 用缩略图接口解码（只会按 maxPixelSize 解码，不会按原图尺寸开 IOSurface）
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            FZMLog("【图片解码】缩略图解码失败 data=\(data.count)B")
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// 只读元数据拿像素尺寸（不解码像素）
    static func pixelSize(of source: CGImageSource) -> CGSize? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    /// 判断图片是否为空
    /// - Returns: bool值，图片是否为空判断结果
    func imageIsEmpty() -> Bool {
        guard let cgImage = self.cgImage,
              let dataProvider = cgImage.dataProvider else
        {
            return true
        }

        let pixelData = dataProvider.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let imageWidth = Int(self.size.width)
        let imageHeight = Int(self.size.height)
        for x in 0..<imageWidth {
            for y in 0..<imageHeight {
                let pixelIndex = ((imageWidth * y) + x) * 4
                let r = data[pixelIndex]
                let g = data[pixelIndex + 1]
                let b = data[pixelIndex + 2]
                let a = data[pixelIndex + 3]
                if a != 0 {
                    if r != 0 || g != 0 || b != 0 {
                        return false
                    }
                }
            }
        }

        return true
    }
    
    func compress(bytesSize: Int) -> Data? {
        var data = self.jpegData(compressionQuality: 1)!
        guard data.count > bytesSize else { return data }
        
        var compression: CGFloat = 1
        var max: CGFloat = 1
        var min: CGFloat = 0
        
        for _ in 0..<6 {
            compression = (max + min) / 2
            data = self.jpegData(compressionQuality: compression)!
            if CGFloat(data.count) < CGFloat(bytesSize) * 0.9 {
                min = compression
            } else if data.count > bytesSize {
                max = compression
            } else {
                break
            }
        }
        
        guard data.count > bytesSize else { return data }
        
        var resultImage: UIImage = UIImage(data: data)!
        var lastDataLength = 0
        while data.count > bytesSize && data.count != lastDataLength {
            lastDataLength = data.count
            let ratio: CGFloat = CGFloat(bytesSize) / CGFloat(data.count)
            let size: CGSize = CGSize(width: Int(resultImage.size.width * sqrt(ratio)),
                                      height: Int(resultImage.size.height * sqrt(ratio)))
            UIGraphicsBeginImageContext(size)
            resultImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            resultImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            data = resultImage.jpegData(compressionQuality: compression)!
        }
        return data
    }
    
}

// MARK: - 安全取图（磁盘缓存里的图片同样要先降采样解码）

extension ImageCache {

    /// 安全取图：内存命中直接用；磁盘命中时读原始 Data → `UIImage.safeDecodedImage` 降采样解码 → 回写内存。
    ///
    /// 为什么不能直接用 `retrieveImage(forKey:)`：Kingfisher 从磁盘取图时默认**不解码**（`backgroundDecode=false`），
    /// 拿到的是未解码的 JPEG，赋给 `UIImageView` 后 CA 提交会在主线程硬解 —— 正是 2026-10-13 的崩溃栈。
    func safeRetrieveImage(forKey key: String,
                           maxPixelSize: CGFloat = 1280,
                           completion: @escaping (UIImage?) -> Void) {
        if let image = self.retrieveImageInMemoryCache(forKey: key) {
            completion(image)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // 磁盘缓存里存的是编码后的原始数据；不解码直接构造 UIImage 会留下懒解码隐患
            let data = try? self.diskStorage.value(forKey: key)
            let image = data.flatMap { UIImage.safeDecodedImage(data: $0, maxPixelSize: maxPixelSize) }
            if let image = image {
                // 只回写内存（降采样后的图不再写回磁盘）
                self.store(image, forKey: key, toDisk: false)
            }
            DispatchQueue.main.async { completion(image) }
        }
    }
}


