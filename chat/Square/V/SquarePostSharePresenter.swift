//
//  SquarePostSharePresenter.swift
//  chat
//
//  广场帖子分享：先把帖子画成一张图（正文 + 最多 3 张帖图 + 底部谈信下载链接），
//  再弹系统分享面板；面板里除系统渠道外额外加「谈信好友 / 谈信群聊」两项，
//  选中后走应用内选人页，把这张图发到对应会话。
//

import Foundation
import UIKit
import Kingfisher

enum SquarePostSharePresenter {

    /// 帖图最多带几张（需求：最多 3 张）
    static let maxImages = 3
    /// 帖图 / 头像的准备超时（用户要求：分享转圈最多 2 秒）
    /// （同文件的 `SquareShareImageFetcher` 也要用这个值，所以是 fileprivate 而不是 private）
    fileprivate static let imageTimeout: TimeInterval = 2

    /// 正在准备分享图：连点直接忽略，避免叠好几个 HUD / 重复弹面板
    private static var isPreparing = false

    // MARK: - 对外

    /// 分享一条帖子
    /// - Parameters:
    ///   - host: 弹面板的页面（cell 里调用时可传 nil，`from:` 会沿响应链自己找）
    ///   - sourceView: iPad 弹出气泡的锚点视图
    static func present(post: SquarePost, from host: UIViewController?, sourceView: UIView?) {
        guard !isPreparing else { return }
        guard let host = host ?? UIViewController.current() else { return }
        isPreparing = true

        // 帖图 + 作者头像**并行**准备；整体最多等 imageTimeout 秒，到点就用已经拿到的部分出图
        var photos = [UIImage]()
        var avatar: UIImage?
        var pending = 2
        var finished = false
        // 转圈延迟 0.25s 出现（图片都在缓存里就不会闪），结束早于 0.25s 直接取消
        let hudWork = DispatchWorkItem { host.showProgress() }
        let finish: () -> Void = {
            guard !finished else { return }
            finished = true
            hudWork.cancel()
            isPreparing = false
            host.hideProgress()
            let card = SquarePostShareCard.render(post: post, avatar: avatar, images: photos)
            showShareSheet(card: card, from: host, sourceView: sourceView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + imageTimeout) { finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: hudWork)

        SquareShareAvatarLoader.image(for: post) { image in
            avatar = image
            pending -= 1
            if pending <= 0 { finish() }
        }

        let urls = Array(post.mediaUrls.prefix(maxImages))
        // 取图尺寸按卡片上的实际显示宽度来：1 张 = 整宽大图，2~3 张 = 三列小图，
        // 小图没必要拉整宽大图，拉小一点下载更快、分享图也不糊
        let displayWidth = (urls.count <= 1) ? SquarePostShareCard.cardWidth : SquarePostShareCard.cardWidth / 2
        fetchImages(urls, maxPixelWidth: displayWidth * UIScreen.main.scale) { images in
            photos = images
            pending -= 1
            if pending <= 0 { finish() }
        }
    }

    /// cell 自己不知道在哪个页面里：沿响应链往上找宿主页面
    static func hostViewController(from view: UIView?) -> UIViewController? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return UIViewController.current()
    }

    // MARK: - 帖图下载

    private static func fetchImages(_ urls: [String], maxPixelWidth: CGFloat, completion: @escaping ([UIImage]) -> Void) {
        // 下载器内部用**强引用 self** 保活（否则函数返回后它就被释放，回调永远不会回来）
        let fetcher = SquareShareImageFetcher(urls: urls, maxPixelWidth: maxPixelWidth, completion: completion)
        fetcher.start()
    }

    // MARK: - 分享面板

    private static func showShareSheet(card: UIImage, from host: UIViewController, sourceView: UIView?) {
        let friend = SquareShareToChatActivity(kind: .friend, image: card, host: host)
        let group = SquareShareToChatActivity(kind: .group, image: card, host: host)
        let controller = UIActivityViewController(activityItems: [card], applicationActivities: [friend, group])
        if let popover = controller.popoverPresentationController {
            popover.sourceView = sourceView ?? host.view
            popover.sourceRect = sourceView?.bounds
                ?? CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = (sourceView == nil) ? [] : UIPopoverArrowDirection.any
        }
        host.present(controller, animated: true)
    }
}

// MARK: - 帖子图片下载（并行 + 超时兜底）

/// 把帖图下下来：全部成功、或超时、或只剩失败项时回调一次；
/// 下载失败的图片直接从结果里去掉（不挡住整张卡片的生成）
private final class SquareShareImageFetcher {

    private let urls: [String]
    private let maxPixelWidth: CGFloat
    private var images: [UIImage?]
    private var finished = false
    /// 结果回调；结束后置 nil，避免继续持有页面 / 帖子
    private var completion: (([UIImage]) -> Void)?

    init(urls: [String], maxPixelWidth: CGFloat, completion: @escaping ([UIImage]) -> Void) {
        self.urls = urls
        self.maxPixelWidth = maxPixelWidth
        self.completion = completion
        self.images = [UIImage?](repeating: nil, count: urls.count)
    }

    func start() {
        guard !urls.isEmpty else {
            finish()
            return
        }
        // ⚠️ 这里（以及下面的下载回调）必须**强引用自己**：
        // 调用方只用一个局部变量接住本对象，`fetchImages` 返回后它就会被释放，
        // 回调里若用 weak self 会全部变成 nil ⇒ HUD 一直转、分享面板永远不弹。
        DispatchQueue.main.asyncAfter(deadline: .now() + SquarePostSharePresenter.imageTimeout) {
            self.finish()
        }
        for (index, raw) in urls.enumerated() {
            guard let url = SquareMediaURLParser.previewURL(from: raw, maxPixelWidth: maxPixelWidth) else {
                downloaded(index: index, image: nil)
                continue
            }
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case .success(let value): self.downloaded(index: index, image: value.image)
                case .failure: self.downloaded(index: index, image: nil)
                }
            }
        }
    }

    /// 只允许在主线程改状态：超时兜底和下载回调都在主线程收口，不用加锁
    private func downloaded(index: Int, image: UIImage?) {
        DispatchQueue.main.async {
            guard !self.finished, index < self.images.count else { return }
            self.images[index] = image
            if self.images.allSatisfy({ $0 != nil }) {
                self.finish()
            }
        }
    }

    /// 幂等：超时兜底和「图片下齐了」谁先到都只回调一次
    private func finish() {
        guard !finished else { return }
        finished = true
        let result = images.compactMap { $0 }
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}

// MARK: - 作者头像（解析 → 取图 → 裁圆）

/// 分享图左上角的作者头像。头像很小、且广场列表里基本已经加载过，所以：
/// 先看广场自己的头像内存缓存（同步命中，零等待），没命中才走 Kingfisher。
private enum SquareShareAvatarLoader {

    /// 头像显示边长（pt）：与 `SquarePostShareCard` 里的一致
    private static let displaySide: CGFloat = 36
    /// 头像取图像素边长：**与列表头像保持一致**（40pt × scale × 2），
    /// 这样刚在广场里看过的帖子，分享时能直接命中已经加载过的头像、不用等下载
    private static var pixelSide: CGFloat { return 40 * UIScreen.main.scale * 2 }

    /// 取头像（已经裁好圆）；解析不到 / 没下完就回 nil（分享图会用默认头像占位）
    static func image(for post: SquarePost, completion: @escaping (UIImage?) -> Void) {
        resolveURL(for: post) { url in
            guard let url = url else {
                completion(nil)
                return
            }
            let size = CGSize(width: pixelSide, height: pixelSide)
            if let cached = SquareAvatarLoader.cachedImage(url: url, downsampleSize: size) {
                completion(circular(cached))
                return
            }
            KingfisherManager.shared.retrieveImage(with: url,
                                                   options: [.processor(DownsamplingImageProcessor(size: size))]) { result in
                switch result {
                case .success(let value): completion(circular(value.image))
                case .failure: completion(nil)
                }
            }
        }
    }

    /// 头像地址：服务端带的（公众号帖 / 改过头像）优先，否则按地址解析（本地 → 通讯录 → 链上）
    private static func resolveURL(for post: SquarePost, completion: @escaping (URL?) -> Void) {
        let raw = post.authorAvatar
        if !raw.isEmpty, let link = SquareMediaURLParser.displayURL(from: raw, pixelSide: pixelSide) {
            completion(link)
            return
        }
        SquareAvatarResolver.avatarURL(for: post.authorAddr) { resolved in
            guard let resolved = resolved,
                  let link = SquareMediaURLParser.displayURL(from: resolved, pixelSide: pixelSide) else {
                completion(nil)
                return
            }
            completion(link)
        }
    }

    /// 裁圆（分享图上的头像都是圆的）
    private static func circular(_ image: UIImage) -> UIImage {
        let size = CGSize(width: displaySide, height: displaySide)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            // 等比填满、居中裁切（与列表头像观感一致）
            let scale = max(size.width / max(image.size.width, 1), size.height / max(image.size.height, 1))
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (size.width - drawSize.width) / 2,
                                  y: (size.height - drawSize.height) / 2,
                                  width: drawSize.width,
                                  height: drawSize.height))
        }
    }
}

// MARK: - 系统分享面板里的「谈信好友 / 谈信群聊」

/// 选中后走应用内选人页，把分享图发到该会话
/// （复用转发图片那条链路：`ChatManager.setPendingShareImage` + `goChatVC`）
final class SquareShareToChatActivity: UIActivity {

    enum Kind {
        case friend
        case group
    }

    private let kind: Kind
    private let image: UIImage
    private weak var host: UIViewController?

    init(kind: Kind, image: UIImage, host: UIViewController?) {
        self.kind = kind
        self.image = image
        self.host = host
    }

    override var activityType: UIActivity.ActivityType? {
        let name = (kind == .friend) ? "com.tanxin.square.share.friend" : "com.tanxin.square.share.group"
        return UIActivity.ActivityType(name)
    }

    override var activityTitle: String? {
        return (kind == .friend) ? L("谈信好友") : L("谈信群聊")
    }

    override var activityImage: UIImage? {
        let symbol = (kind == .friend) ? "person.crop.circle" : "person.3"
        return UIImage.init(systemName: symbol)?.withRenderingMode(.alwaysOriginal)
    }

    override class var activityCategory: UIActivity.Category {
        return .share
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return image.size.width > 0 && image.size.height > 0
    }

    override func perform() {
        // 先结束本项，让系统面板正常收起；面板还有收起动画，等它收完再弹选人页
        activityDidFinish(true)
        let host = self.host ?? UIViewController.current()
        let kind = self.kind
        let image = self.image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard let host = host else { return }
            SquareShareToChatActivity.presentPicker(kind: kind, image: image, from: host)
        }
    }

    /// 好友 / 群聊共用一张「选择会话」页（支持多选），选完后把这张图发到每个会话
    private static func presentPicker(kind: Kind, image: UIImage, from host: UIViewController) {
        let picker = ChoiceContactCardVC()
        picker.showsFriendAndGroup = true
        picker.allowsMultipleSelection = true
        picker.selectedBlock = { [weak picker] contacts in
            let sessionIDs: [SessionID] = contacts.compactMap { contact in
                let address = contact.sessionIDStr
                guard !address.isEmpty else { return nil }
                return contact.type == .group ? SessionID.group(address) : SessionID.person(address)
            }
            guard let first = sessionIDs.first else { return }
            picker?.dismiss(animated: true)

            // 先把图塞进 ImageCache，再走统一的转发通道（它会为每个会话各复制一份消息）
            let cacheKey = String.uuid()
            ImageCache.default.store(image, forKey: cacheKey)
            let msgType = Message.MsgType.init(
                image: nil, cacheKey: cacheKey,
                width: Double(image.size.width), height: Double(image.size.height))
            let source = Message(
                fromId: LoginUser.shared().address, sessionId: first, msgType: msgType)
            MessageForwarder.forward([source], to: sessionIDs, from: host)
        }
        host.present(FZMNavigationController(rootViewController: picker), animated: true)
    }
}
