//
//  SquareImageGridView.swift
//  chat
//
//  广场图片九宫格：1 张大图 / 4 张两列 / 其余三列（列表、详情、发帖预览共用）
//

import Foundation
import UIKit
import SnapKit
import Kingfisher
import SwifterSwift

final class SquareImageGridView: UIView {

    /// 图片间距
    static let spacing: CGFloat = 4
    /// 单张图片的最大边长
    static let singleMaxSide: CGFloat = 200

    /// 点击某张图片（index 从 0 开始，一并回传被点的图片视图，供大图浏览做过场动画）
    var onTapImage: ((Int, UIImageView) -> Void)?

    /// 是否「完整显示」图片：格子内等比缩放、整张图都看得见（比例不同会在格子里留白），**不做裁切**。
    /// 目前只有**帖子详情页**传 true（详见 `SquarePostCell.configure(showsImagesCompletely:)`）；
    /// 广场流 / 我的帖子 / 作者页保持原来的「方形格子 + `scaleAspectFill` 裁切」（默认 false）。
    /// ⚠️ 它同时决定缩略图地址（`m_lfit` 不裁切 / `m_fill` 方形裁切），两者必须一致，
    /// 否则会出现「地址给的是裁过的图、却按完整显示排」的错位。
    var displaysImagesCompletely: Bool = false

    private var imageViews = [UIImageView]()
    /// 每个 imageView 当前请求的图片地址（地址没变就不再走一遍加载，避免刷新时闪一下）
    private var imageViewKeys = [String]()

    /// 已知「加了 x-oss-process 的小图地址」拉不下来的地址：
    /// 服务端/OSS 没开图片处理时，每个 cell 都要先发一次注定失败的请求、还要多等一个来回，
    /// 记下来之后同一进程内直接跳过小图，用「大图浏览同款」的屏宽图（见 `loadImage`）。
    /// （只在主线程读写）
    private static var unusableThumbKeys = Set<String>()

    /// 已知**整个 host 都不支持 `x-oss-process`** 的情况。
    /// 只靠 `unusableThumbKeys`（按单张图片记）不够：每个帖子每张图的 key 都不同，
    /// 服务端没开图片处理时每张图都要先白白等一次 400。这里按 host 记，一次就能省掉后续所有试错。
    /// （只在主线程读写）
    private static var unusableThumbHosts = Set<String>()

    /// 该地址是否还可能拿到缩略图（host 出过 400 就不再试）
    private static func mayHaveThumbnail(_ url: URL) -> Bool {
        guard url.absoluteString.contains("x-oss-process") else { return true }
        guard let host = url.host else { return true }
        return !unusableThumbHosts.contains(host)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 尺寸计算

    /// 每行张数
    static func itemsPerRow(for count: Int) -> Int {
        if count <= 1 { return 1 }
        if count == 4 { return 2 }
        return 3
    }

    /// 单张图片边长
    static func itemSize(for count: Int, maxWidth: CGFloat) -> CGFloat {
        guard count > 0, maxWidth > 0 else { return 0 }
        if count == 1 {
            return min(singleMaxSide, maxWidth)
        }
        let perRow = CGFloat(itemsPerRow(for: count))
        let size = (maxWidth - spacing * (perRow - 1)) / perRow
        return max(size, 0)
    }

    /// 布局所需高度（count == 0 时为 0）
    static func height(for count: Int, maxWidth: CGFloat) -> CGFloat {
        let count = min(max(count, 0), SquareLimits.maxImageCount)
        guard count > 0 else { return 0 }
        let perRow = itemsPerRow(for: count)
        let rows = Int(ceil(Double(count) / Double(perRow)))
        let size = itemSize(for: count, maxWidth: maxWidth)
        return CGFloat(rows) * size + CGFloat(rows - 1) * spacing
    }

    // MARK: - 渲染

    /// 重新配置图片；返回布局后的高度
    /// - Parameter loadImages: 仅测量行高时传 false，跳过图片下载
    /// - Parameter tags: 每张图对应的业务下标（默认用数组下标）。
    ///   详情页正文里已内联展示过的图会从九宫格里去掉，这时下标与 `mediaUrls` 不再一致，
    ///   必须把「它在 mediaUrls 里的真实下标」传进来，否则点开大图会翻到另一张。
    @discardableResult
    func configure(urls: [String], maxWidth: CGFloat, loadImages: Bool = true, tags: [Int]? = nil) -> CGFloat {
        let urls = Array(urls.prefix(SquareLimits.maxImageCount))
        // 与 urls 一起截断，保证下标一一对应
        let tags = tags.map { Array($0.prefix(SquareLimits.maxImageCount)) }

        guard !urls.isEmpty, maxWidth > 0 else {
            removeAllImageViews()
            return 0
        }

        // 复用已有 imageView（不够就补）：每次重建会让九宫格在刷新时先空一帧（看起来就是闪一下）
        while imageViews.count < urls.count {
            let imageView = makeImageView()
            imageViews.append(imageView)
            imageViewKeys.append("")
        }
        if imageViews.count > urls.count {
            for index in urls.count..<imageViews.count {
                imageViews[index].kf.cancelDownloadTask()
                imageViews[index].removeFromSuperview()
            }
            imageViews.removeSubrange(urls.count...)
            imageViewKeys.removeSubrange(urls.count...)
        }

        let perRow = SquareImageGridView.itemsPerRow(for: urls.count)
        let size = SquareImageGridView.itemSize(for: urls.count, maxWidth: maxWidth)

        for (index, raw) in urls.enumerated() {
            let imageView = imageViews[index]
            imageView.tag = tags?.count == urls.count ? tags![index] : index
            imageView.snp.remakeConstraints { (m) in
                m.left.equalToSuperview().offset(CGFloat(index % perRow) * (size + SquareImageGridView.spacing))
                m.top.equalToSuperview().offset(CGFloat(index / perRow) * (size + SquareImageGridView.spacing))
                m.size.equalTo(size)
            }
            guard loadImages else { continue }
            loadImage(raw, into: imageView, displaySize: size, index: index)
        }

        return SquareImageGridView.height(for: urls.count, maxWidth: maxWidth)
    }

    private func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.backgroundColor = Color_F6F7F8
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        // 细描边：图片加载失败时也能看到九宫格占位，便于区分「本来没图」和「加载失败」
        imageView.layer.borderWidth = 0.5
        imageView.layer.borderColor = Color_E6EAEE.cgColor
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTap(_:))))
        self.addSubview(imageView)
        return imageView
    }

    private func removeAllImageViews() {
        imageViews.forEach {
            $0.kf.cancelDownloadTask()
            $0.removeFromSuperview()
        }
        imageViews.removeAll()
        imageViewKeys.removeAll()
    }

    /// 九宫格实际会请求的图片地址（预取用；必须与 `loadImage` 里算出来的完全一致，才能命中同一份缓存）
    static func thumbnailURLs(for urls: [String], maxWidth: CGFloat) -> [URL] {
        let urls = Array(urls.prefix(SquareLimits.maxImageCount))
        guard !urls.isEmpty, maxWidth > 0 else { return [] }
        let pixelSide = itemSize(for: urls.count, maxWidth: maxWidth) * UIScreen.main.scale
        return urls.compactMap { raw -> URL? in
            guard let url = SquareMediaURLParser.displayURL(from: raw, pixelSide: pixelSide) else { return nil }
            // 该 host 已经证实不支持图片处理：别把带宽浪费在注定 400 的地址上
            return mayHaveThumbnail(url) ? url : nil
        }
    }

    /// 加载单张图片：**按显示尺寸取服务端处理过的小图**（体积小很多 ⇒ 快）。
    ///
    /// 候选地址按「体积小 → 稳妥」依次尝试，任一成功就立刻显示：
    /// ① 服务端小图（完整显示模式 = 等比不裁切的 `m_lfit`；其它页面 = 方形裁切的 `m_fill`）；
    /// ② **与大图浏览完全同款的屏宽图**（只限宽、不裁切）
    /// （用户点开大图能看到 ⇒ 这个地址一定是可用的，所以小图拉不下来时它基本都能救命）；
    /// ③ 原图。三个都失败才显示占位图标。
    /// 以前只有「小图 → 原图」两档，遇到 OSS 不支持图片处理而原图又很大时，
    /// 就是「大图都出来了，小图还一直空着」。
    /// - Parameter index: 对应 `imageViewKeys` 的下标（地址没变时直接跳过，刷新不会闪）
    private func loadImage(_ raw: String, into imageView: UIImageView, displaySize: CGFloat, index: Int) {
        guard let original = SquareMediaURLParser.url(from: raw) else {
            FZMLog("广场图片地址非法: \(raw)")
            imageViewKeys[index] = ""
            showBrokenPlaceholder(in: imageView)
            return
        }

        let options: KingfisherOptionsInfo = [.transition(.fade(0.08)),
                                              .scaleFactor(UIScreen.main.scale),
                                              .backgroundDecode]
        // 缩略图地址：
        // ① 完整显示模式（详情页）用**不裁切**的等比缩略图（`m_lfit`，整图落在格子里）；
        // ② 其它页面仍用服务端裁好的方形小图（`m_fill`，体积最小）。
        // 两种地址不同 ⇒ 缓存 key 也不同，互不串图。
        // 缓存 key 固定用「缩略图地址」：命中内存缓存时能同步贴图，一帧都不闪
        let thumbSide = displaySize * UIScreen.main.scale
        let thumb: URL
        if displaysImagesCompletely {
            thumb = SquareMediaURLParser.thumbnailURL(from: raw, pixelSide: thumbSide) ?? original
        } else {
            thumb = SquareMediaURLParser.displayURL(from: raw, pixelSide: thumbSide) ?? original
        }
        let key = thumb.absoluteString

        // contentMode 必须写在「地址没变就早退」**之前**：cell 复用 / 模式切换时
        // 地址可能刚好没变，但显示方式要跟着 `displaysImagesCompletely` 走
        imageView.contentMode = displaysImagesCompletely ? .scaleAspectFit : .scaleAspectFill
        imageView.tintColor = nil

        // 地址没变就不用动（已经显示的就是这张）—— 刷新时完全不碰视图，所以不会闪
        guard imageViewKeys[index] != key || imageView.image == nil else { return }
        imageViewKeys[index] = key

        // 已加载过的图片：**同步**贴上去（与 cell 配置同一个 RunLoop，连一帧空图都看不见）
        if let cached = SquareImageMemoryCache.image(forKey: key) {
            imageView.kf.cancelDownloadTask()
            imageView.image = cached
            return
        }

        // 候选地址（去掉重复的；小图已知拉不下来时直接跳过，少发一次注定失败的请求）
        var candidates = [URL]()
        if SquareImageGridView.mayHaveThumbnail(thumb), !SquareImageGridView.unusableThumbKeys.contains(key) {
            candidates.append(thumb)
        }
        if let screenWide = SquareMediaURLParser.previewURL(from: raw,
                                                           maxPixelWidth: SquarePhotoPresenter.browserPixelWidth),
           !candidates.contains(screenWide) {
            candidates.append(screenWide)
        }
        if !candidates.contains(original) {
            candidates.append(original)
        }

        // 地址变了（cell 复用给了另一条帖子）且没缓存：先清空，避免显示上一条帖子的图
        imageView.image = nil
        loadCandidate(candidates, position: 0, thumbKey: key, into: imageView, index: index, options: options)
    }

    /// 依次尝试候选地址：任一成功即结束；全部失败才显示占位图标
    private func loadCandidate(_ candidates: [URL], position: Int, thumbKey: String,
                               into imageView: UIImageView, index: Int, options: KingfisherOptionsInfo) {
        guard position < candidates.count else {
            imageViewKeys[index] = ""
            showBrokenPlaceholder(in: imageView)
            return
        }
        let url = candidates[position]
        imageView.kf.setImage(with: url, placeholder: nil, options: options) { [weak self] result in
            // 期间地址变了（cell 复用）就丢弃这次结果，避免串图
            guard let self = self, index < self.imageViewKeys.count, self.imageViewKeys[index] == thumbKey else { return }
            switch result {
            case .success(let value):
                // 小图地址的缓存位也存一份（实际显示的就是这张）：下次配置直接命中，不用再发请求
                SquareImageMemoryCache.store(value.image, forKey: thumbKey)
                SquareImageMemoryCache.store(value.image, forKey: url.absoluteString)
                if position > 0 {
                    // 小图拉不下来（服务端没开图片处理等）：记下来，同一进程内不再重试它
                    if SquareImageGridView.unusableThumbKeys.count > 500 {
                        SquareImageGridView.unusableThumbKeys.removeAll()
                    }
                    SquareImageGridView.unusableThumbKeys.insert(thumbKey)
                }
            case .failure(let error):
                // ⚠️ `.notCurrentSourceTask`：这次请求其实**已经成功**，只是 imageView 上又设置了
                //    更新的请求（同一 URL 重复 configure / cell 复用）。它不是加载失败 ——
                //    不能递归下一候选、更不能显示占位图，否则会把新请求刚贴上的图覆盖成破图
                //    （用户 2026-11-09 日志：候选 1/1 却报 notCurrentSourceTask，小图时有时无）。
                if Self.isStaleOrCancelledTask(error) {
                    return
                }
                FZMLog("广场图片加载失败(候选 \(position + 1)/\(candidates.count)): \(url.absoluteString) \(error.localizedDescription)")
                // OSS 没开图片处理时返回 400：把整个 host 记下来，后续图片直接走屏宽图，
                // 不再每张都先等一次注定失败的请求
                if position == 0, Self.isUnsupportedProcessingError(error), let host = url.host {
                    if SquareImageGridView.unusableThumbHosts.count > 20 {
                        SquareImageGridView.unusableThumbHosts.removeAll()
                    }
                    SquareImageGridView.unusableThumbHosts.insert(host)
                }
                self.loadCandidate(candidates, position: position + 1, thumbKey: thumbKey,
                                   into: imageView, index: index, options: options)
            }
        }
    }

    /// 服务端不支持 `x-oss-process`（OSS 返回 400）—— 只有这种情况才把整个 host 判死，
    /// 单张图的 403/404 不算（可能只是这张图丢了）
    private static func isUnsupportedProcessingError(_ error: KingfisherError) -> Bool {
        if case .responseError(let reason) = error,
           case .invalidHTTPStatusCode(let response) = reason {
            return response.statusCode == 400
        }
        return false
    }

    /// 「过期 / 被取消」的 Kingfisher 任务：请求本身没有失败，只是被 imageView 上更新的请求取代了。
    /// 这类回调必须直接丢弃，不能当成加载失败去 fallback / 显示占位图。
    private static func isStaleOrCancelledTask(_ error: KingfisherError) -> Bool {
        switch error {
        case .imageSettingError(let reason):
            if case .notCurrentSourceTask = reason { return true }
            return false
        case .requestError(let reason):
            if case .taskCancelled = reason { return true }
            return false
        case .responseError(let reason):
            if case .cancelledByDelegate = reason { return true }
            return false
        default:
            return false
        }
    }

    private func showBrokenPlaceholder(in imageView: UIImageView) {
        imageView.contentMode = .center
        imageView.image = UIImage.init(systemName: "photo")?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = Color_C8D3DE
    }

    @objc private func imageTap(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        onTapImage?(imageView.tag, imageView)
    }
}
