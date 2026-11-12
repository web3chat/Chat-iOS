//
//  QRCodeGenerator.swift
//  Chat33
//
//  Created by fzm on 2018/9/19.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit
import Vision

/// 识别到的一个二维码（`QRCodeGenerator.robustQRCodes(in:)` 的产物）
struct QRCodeHit {
    /// 二维码内容
    let value: String
    /// 在**原图**里的归一化位置（0~1，**左上角为原点** —— UIKit 习惯，方便直接映射到屏幕上那张图）
    let normalizedRect: CGRect
}

class QRCodeGenerator: NSObject {

    //MARK: -传进去字符串,生成二维码图片
    open class func setupQRCodeImage(_ text: String, image: UIImage?) -> UIImage {
        //创建滤镜
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setDefaults()
        //将url加入二维码
        filter?.setValue(text.data(using: String.Encoding.utf8), forKey: "inputMessage")
        //取出生成的二维码（不清晰）
        if let outputImage = filter?.outputImage {
            //生成清晰度更好的二维码
            let qrCodeImage = setupHighDefinitionUIImage(outputImage, size: 300)
            //如果有一个头像的话，将头像加入二维码中心
            if var image = image {
                //给头像加一个白色圆边（如果没有这个需求直接忽略）
                image = circleImageWithImage(image, borderWidth: 0, borderColor: UIColor.white)
                //合成图片
                let newImage = syntheticImage(qrCodeImage, iconImage: image, width: 90, height: 90)
                
                return newImage
            }
            
            return qrCodeImage
        }
        
        return UIImage()
    }
    
    //image: 二维码 iconImage:头像图片 width: 头像的宽 height: 头像的宽
    open class func syntheticImage(_ image: UIImage, iconImage:UIImage?, width: CGFloat, height: CGFloat) -> UIImage{
        //开启图片上下文
        UIGraphicsBeginImageContext(image.size)
        //绘制背景图片
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
        
        let x = (image.size.width - width) * 0.5
        let y = (image.size.height - height) * 0.5
        if let iconImage = iconImage {
            iconImage.draw(in: CGRect(x: x, y: y, width: width, height: height))
        }
        //取出绘制好的图片
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        //关闭上下文
        UIGraphicsEndImageContext()
        //返回合成好的图片
        if let newImage = newImage {
            return newImage
        }
        return UIImage()
    }
    
    //MARK: - 生成高清的UIImage
    private class func setupHighDefinitionUIImage(_ image: CIImage, size: CGFloat) -> UIImage {
        let integral: CGRect = image.extent.integral
        let proportion: CGFloat = min(size/integral.width, size/integral.height)
        
        let width = integral.width * proportion
        let height = integral.height * proportion
        let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapRef = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: 0)!
        
        let context = CIContext(options: nil)
        let bitmapImage: CGImage = context.createCGImage(image, from: integral)!
        
        bitmapRef.interpolationQuality = CGInterpolationQuality.none
        bitmapRef.scaleBy(x: proportion, y: proportion);
        bitmapRef.draw(bitmapImage, in: integral);
        let image: CGImage = bitmapRef.makeImage()!
        return UIImage(cgImage: image)
    }
    
    //生成边框
    private class func circleImageWithImage(_ sourceImage: UIImage, borderWidth: CGFloat, borderColor: UIColor) -> UIImage {
        let imageWidth = sourceImage.size.width + 2 * borderWidth
        let imageHeight = sourceImage.size.height + 2 * borderWidth
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: imageHeight), false, 0.0)
        UIGraphicsGetCurrentContext()
        
        let radius = (sourceImage.size.width < sourceImage.size.height ? sourceImage.size.width:sourceImage.size.height) * 0.5
        let bezierPath = UIBezierPath(arcCenter: CGPoint(x: imageWidth * 0.5, y: imageHeight * 0.5), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        bezierPath.lineWidth = borderWidth
        borderColor.setStroke()
        bezierPath.stroke()
        bezierPath.addClip()
        sourceImage.draw(in: CGRect(x: borderWidth, y: borderWidth, width: sourceImage.size.width, height: sourceImage.size.height))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image!
    }
    
    class func detectorQRCode(with image: UIImage) -> String? {
        guard let imageCI = CIImage(image: image) else { return nil}
        // 开始识别
        // 1. 创建一个二维码探测器
        guard let dector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            return nil
        }
        // 2. 直接探测二维码特征
        let features = dector.features(in: imageCI)
        guard let feature = features.first else { return nil }
        let qrFeature = feature as! CIQRCodeFeature
        return qrFeature.messageString
    }

    // MARK: - 大图长按「识别图中二维码」：多档兜底识别

    /// 比 `detectorQRCode` 更耐用的识别入口：**二维码在整张图里只占一小块、或者图本身是低清缩略图**时也尽量认出来。
    ///
    /// 为什么需要它：`CIDetector` 对「小二维码 + 低分辨率」很挑食 —— 私聊里点开的大图往往是
    /// 截图 / 别人转发的图（二维码只占画面一小块），或者图还没加载完、显示的还是消息气泡那张
    /// 450px 降采样图。结果就是「图里明明有二维码，长按却没有『识别图中二维码』」。
    ///
    /// 依次尝试（越往后越费时，命中即返回）：
    /// 1. Vision（iOS 11+，对「小 / 略糊」的二维码明显比 CIDetector 强）；
    /// 2. CIDetector（老办法，兜底 Vision 漏掉的情况）；
    /// 3. 图很小时整张放大 2 倍再试（小图里二维码只有几十像素，放大后才认得出）；
    /// 4. 还不行为把图切成「四宫格 + 中心块」（带重叠），各自放大 2 倍再跑 Vision。
    class func robustQRCode(with image: UIImage) -> String? {
        guard let base = normalizedForDetect(image) else { return nil }

        if let text = visionQRCode(in: base) ?? detectorQRCode(with: base) {
            return text
        }

        // 低清小图（比如消息气泡那张降采样图放大后的样子）：整张放大一倍再试，比切块更不容易把二维码切开
        if max(base.size.width, base.size.height) < 700, let bigger = scaled(base, factor: 2) {
            if let text = visionQRCode(in: bigger) ?? detectorQRCode(with: bigger) {
                return text
            }
        }

        // 大图里二维码占比小：切块 + 放大，让二维码在每块里「变大」
        for tile in tiles(of: base) {
            if let text = visionQRCode(in: tile) {
                return text
            }
        }
        return nil
    }

    // MARK: - 一张图里有多个二维码：全部识别 + 位置

    /// 把图里**所有**二维码都找出来（`robustQRCode` 只返回第一个）：
    /// 一张图里可能有好几个码（尤其截图 / 拼图），只认第一个会让用户拿到错的那个；
    /// 带上位置才能在图上让用户「点哪个扫哪个」。
    ///
    /// 多档兜底照旧（Vision → CIDetector → 整张放大 → 分块放大），只是每一档都收「全部结果」，
    /// 最后按归一化坐标合并去重。
    class func robustQRCodes(in image: UIImage) -> [QRCodeHit] {
        guard let base = normalizedForDetect(image) else { return [] }

        var hits = merge(visionHits(in: base) + detectorHits(in: base))
        if !hits.isEmpty { return hits }

        // 低清小图（消息气泡那张降采样图）：整张放大一倍再试
        if max(base.size.width, base.size.height) < 700, let bigger = scaled(base, factor: 2) {
            hits = merge(visionHits(in: bigger) + detectorHits(in: bigger))
            if !hits.isEmpty { return hits }
        }

        // 大图里二维码占比小：切块 + 放大，再把「块内坐标」映射回整图
        let baseSize = base.size
        for tile in tilesWithRect(of: base) {
            for hit in visionHits(in: tile.image) + detectorHits(in: tile.image) {
                hits.append(QRCodeHit(value: hit.value,
                                      normalizedRect: normalizedRect(hit.normalizedRect,
                                                                     fromTile: tile.pixelRect,
                                                                     imageSize: baseSize)))
            }
        }
        return merge(hits)
    }

    /// Vision 识别（一次能返回**多个**条码，对「小 / 略糊」的码比 CIDetector 耐用）
    private class func visionHits(in image: UIImage) -> [QRCodeHit] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])  
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let value = observation.payloadStringValue, !value.isEmpty else { return nil }
            // Vision 的 box 是「归一化 + 左下原点」，转成左上原点
            let box = observation.boundingBox
            return QRCodeHit(value: value,
                             normalizedRect: CGRect(x: box.minX, y: 1 - box.maxY,
                                                   width: box.width, height: box.height))
        }
    }

    /// CIDetector 识别（同样返回全部），兜底 Vision 漏掉的情况
    private class func detectorHits(in image: UIImage) -> [QRCodeHit] {
        guard let imageCI = CIImage(image: image),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return [] }
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return [] }
        return detector.features(in: imageCI).compactMap { feature in
            guard let qr = feature as? CIQRCodeFeature,
                  let value = qr.messageString, !value.isEmpty else { return nil }
            // CIQRCodeFeature.bounds 是「像素 + 左下原点」
            let box = qr.bounds
            return QRCodeHit(value: value,
                             normalizedRect: CGRect(x: box.minX / width, y: 1 - box.maxY / height,
                                                   width: box.width / width, height: box.height / height))
        }
    }

    /// 块内归一化坐标（左上原点） → 整图归一化坐标（左上原点）
    /// （`tile` 是「整图像素坐标、左上原点」下这一块的矩形，与 `cgImage.cropping(to:)` 同一套坐标）
    private class func normalizedRect(_ rect: CGRect, fromTile tile: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, tile.width > 0, tile.height > 0 else { return rect }
        return CGRect(x: (tile.minX + rect.minX * tile.width) / imageSize.width,
                      y: (tile.minY + rect.minY * tile.height) / imageSize.height,
                      width: rect.width * tile.width / imageSize.width,
                      height: rect.height * tile.height / imageSize.height)
    }

    /// 合并 Vision / CIDetector / 各切块的结果：内容相同且位置接近的算同一个码
    private class func merge(_ hits: [QRCodeHit]) -> [QRCodeHit] {
        var result = [QRCodeHit]()
        for hit in hits where !hit.value.isEmpty {
            let duplicated = result.contains { existing in
                existing.value == hit.value
                    && abs(existing.normalizedRect.midX - hit.normalizedRect.midX) < 0.05
                    && abs(existing.normalizedRect.midY - hit.normalizedRect.midY) < 0.05
            }
            if !duplicated { result.append(hit) }
        }
        return result
    }

    /// 统一成「方向摆正 + 最长边 ≤ 1200」的位图：后面所有裁剪 / 放大都基于它，坐标系才一致，
    /// 也避免在几千万像素的原图上白跑几百毫秒
    private class func normalizedForDetect(_ image: UIImage, maxSide: CGFloat = 1200) -> UIImage? {
        let side = max(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let scale = side > maxSide ? maxSide / side : 1
        return render(image, in: CGSize(width: max(ceil(image.size.width * scale), 1),
                                        height: max(ceil(image.size.height * scale), 1)))
    }

    /// 等比放大
    private class func scaled(_ image: UIImage, factor: CGFloat) -> UIImage? {
        return render(image, in: CGSize(width: ceil(image.size.width * factor),
                                        height: ceil(image.size.height * factor)))
    }

    /// 把图重画到指定尺寸（顺便把方向摆正、透明底填白）
    private class func render(_ image: UIImage, in size: CGSize) -> UIImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            // 透明区域填白：二维码是「浅底深格」，透明底直接变黑的话就认不出来了
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Vision 识别（对「小 / 略糊」的二维码比 CIDetector 强很多）
    private class func visionQRCode(in image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let payload = request.results?.first?.payloadStringValue, !payload.isEmpty else { return nil }
        return payload
    }

    /// 切块：四宫格 + 中心块（各带 5% 重叠，二维码刚好跨过切线也能认出来），每块放大 2 倍
    private class func tiles(of image: UIImage) -> [UIImage] {
        return tilesWithRect(of: image).map { $0.image }
    }

    /// 同上，但同时带回「这一块在整图里的像素矩形（左上原点，与 cgImage.cropping 同一套坐标）」——
    /// 多二维码识别要用它把「块内识别结果」映射回整图坐标
    private class func tilesWithRect(of image: UIImage) -> [(image: UIImage, pixelRect: CGRect)] {
        guard let cgImage = image.cgImage else { return [] }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width >= 80, height >= 80 else { return [] }

        let full = CGRect(x: 0, y: 0, width: width, height: height)
        let overlapX = width * 0.05
        let overlapY = height * 0.05
        var rects = [CGRect]()
        for row in 0..<2 {
            for column in 0..<2 {
                let rect = CGRect(x: CGFloat(column) * width / 2, y: CGFloat(row) * height / 2,
                                  width: width / 2, height: height / 2)
                rects.append(rect.insetBy(dx: -overlapX, dy: -overlapY).intersection(full))
            }
        }
        rects.append(CGRect(x: width * 0.2, y: height * 0.2, width: width * 0.6, height: height * 0.6))

        return rects.compactMap { rect in
            let integral = rect.integral
            guard integral.width >= 40, integral.height >= 40,
                  let cropped = cgImage.cropping(to: integral),
                  let tile = render(UIImage(cgImage: cropped),
                                    in: CGSize(width: integral.width * 2, height: integral.height * 2)) else { return nil }
            return (tile, integral)
        }
    }
    
}

// MARK: - 二维码内容处理（「扫一扫」与大图长按「识别图中二维码」共用）

/// 把一个二维码字符串按业务分发出去（加好友 / 加群 / 团队 H5 / 转账 / 网页 / 扫码登录网页版）
enum QRCodeResultHandler {

    /// 处理二维码内容
    /// - Parameters:
    ///   - qrString: 二维码原始内容
    ///   - host: 发起处理的页面（空则退回当前页面）
    ///   - onTeamJoined: 加入团队 H5 成功后的回调（扫一扫那边要顺带刷新员工信息）
    /// - Returns: 是否已被处理；false 表示内容不认识，交给调用方自己兜底
    @discardableResult
    static func handle(_ qrString: String, from host: UIViewController? = nil, onTeamJoined: (() -> Void)? = nil) -> Bool {
        let host = host ?? UIViewController.current()

        // 扫码登录网页版（PC 端）：必须先于其它分支判断，
        // 否则会被下面的 contains("http") 当成普通网页丢给 Safari
        if ScanLoginRouter.handle(qrString: qrString, from: host) {
            return true
        }

        if qrString.contains(ShareURL) {
            // 跳转到用户/好友详情页（加好友）
            let address = qrString.replacingOccurrences(of: ShareURL, with: "")
            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: address, source: .sweep))
            return true
        }

        if qrString.contains(TeamH5Url) {
            // 跳转到加入团队网页
            FZMUIMediator.shared().pushVC(.goTeamH5WebVC(type: .joinTeam(url: qrString), completeBlock: onTeamJoined))
            return true
        }

        if qrString.contains("gid") {
            // 加入群聊二维码
            let urlStr = URL(string: qrString)
            guard let groupId = urlStr?.queryValue(for: "gid"), !groupId.isEmpty else { return false }
            let inviterId = urlStr?.queryValue(for: "inviterId") ?? ""
            FZMUIMediator.shared().pushVC(.goAddGroup(groupId: groupId.intEncoded, inviterId: inviterId))
            return true
        }

        if qrString.contains("transfer") {
            guard let urlStr = URL(string: qrString),
                  let target = urlStr.queryValue(for: "transfer_target"),
                  let address = urlStr.queryValue(for: "address") else { return false }
            let chain = urlStr.queryValue(for: "chain")

            var localCoin = LocalCoin.init()
            if let coinArray = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID() {
                for data in NSArray(array: coinArray) {
                    if let coin = data as? LocalCoin, coin.coin_type == chain {
                        localCoin = coin
                    }
                }
            }

            let vc = TransferViewController.init()
            vc.contactDict = ["avatarUrl": "" as NSString, "address": target as NSString, "toAddr": address as NSString]
            vc.coin = localCoin
            vc.transferBlock = { (coinName, txHash, _) in
                guard let coinName = coinName, !coinName.isEmpty,
                      let txHash = txHash, !txHash.isEmpty else { return }
                let sessionId = SessionID.person(target)
                FZMUIMediator.shared().pushVC(.goChatVCToTransfer(sessionID: sessionId, coinName: coinName, txHash: txHash))
            }
            vc.hidesBottomBarWhenPushed = true
            host?.navigationController?.pushViewController(vc, animated: true)
            return true
        }

        if qrString.contains("http") {
            // 跳转到 Safari 打开网页
            APP.shared().openUrl(with: qrString)
            return true
        }

        return false
    }
}
