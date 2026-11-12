//
//  FZMPhotoBrowser.swift
//  IMSDK
//
//  Created by fzm on 2019/2/11.
//

import UIKit
import IDMPhotoBrowser
import RxSwift


class FZMPhotoBrowser: IDMPhotoBrowser {
//    fileprivate var burnProgressView :FZMBurnProgressView?
    fileprivate let disposeBag = DisposeBag()
    fileprivate var idmPhotoIndex = -1
    
    override init!(photos photosArray: [Any]!, animatedFrom view: UIView!) {
        super.init(photos: photosArray, animatedFrom: view)
        self.delegate = self
        self.senderThumbnailView = view
        self.photoCount = photosArray?.count ?? 0
        if let imageView = view as? UIImageView {
            self.scaleImage = imageView.image
        }
        self.displayToolbar = false
        self.displayDoneButton = false
        self.dismissOnTouch = true
        self.modalPresentationStyle = .overCurrentContext
    }

    // MARK: - 来源缩略图的显示状态
    //
    // IDM 的「从缩略图放大」动画会把来源缩略图隐藏（`_senderViewForAnimation.hidden = YES`），
    // 只有走它自己的关闭动画（点 X / 轻点收起 / 下拉）才会恢复成显示。
    // 我们手动 `dismiss` 时它不会恢复，页面回来后那张缩略图就一直不显示 —— 看起来就是「图片消失了」。
    private weak var senderThumbnailView: UIView?

    /// 手动关闭大图（不走 IDM 自带的关闭动画）：先把来源缩略图恢复显示
    private func dismissManually(completion: (() -> Void)? = nil) {
        self.restoreSenderThumbnail()
        self.dismiss(animated: false, completion: completion)
    }

    /// 恢复来源缩略图的显示（已释放或已被复用也无害）
    private func restoreSenderThumbnail() {
        self.senderThumbnailView?.isHidden = false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 兜底：不管是哪种方式关掉的，离开后都保证缩略图是显示的
        self.restoreSenderThumbnail()
    }
    
    convenience init(url: String, from imageView:UIImageView) {
        var photos = [Any]()
        if let url = URL.init(string: url), let photo = IDMPhoto.init(url: url) {
            photos.append(photo)
        } else if let photo = IDMPhoto.init(image: imageView.image) {
            photos.append(photo)
        }
        self.init(photos: photos, animatedFrom: imageView)
    }

    convenience init(msg:Message ,msgList:[Message], from imageView:UIImageView) {
        var photos = [Any]()
        var currentIndex = 0
        for i in 0..<msgList.count {
            let message = msgList[i]
            if let url = URL.init(string: message.msgType.url), let photo = IDMPhoto.init(url: url) {
                photos.append(photo)
                if !msg.msgId.isEmpty && !message.msgId.isEmpty {
                    if msg.msgId == message.msgId {
                        currentIndex = i
                    }
                } else if !msg.msgId.isEmpty && !message.msgId.isEmpty {
                    if message.msgId == msg.msgId {
                        currentIndex = i
                    }
                } else if msg.datetime == message.datetime {
                    currentIndex = i
                }
                
            } else {
                message.msgType.imageAsync { (image) in
                    if let image = image, let photo = IDMPhoto.init(image: image){
                        photos.append(photo)
                        if message.msgId == msg.msgId {
                            currentIndex = i
                        }
                    }
                }
            }
        }
        
        if currentIndex >= photos.count {
            photos.removeAll()
            if let url = URL.init(string: msg.msgType.url), let photo = IDMPhoto.init(url: url) {
                photos.append(photo)
                currentIndex = 0
            } else {
                msg.msgType.imageAsync { (image) in
                    if let image = image, let photo = IDMPhoto.init(image: image){
                        photos.append(photo)
                        currentIndex = 0
                    }
                }
            }
        }
        
        if photos.isEmpty, let photo = IDMPhoto.init(image: UIImage.imageWithColor(with: .black, size: CGSize.init(width: k_ScreenWidth, height: k_ScreenHeight))) {
            photos.append(photo)
        }
        self.init(photos: photos, animatedFrom: imageView)
        if photos.count > currentIndex {
            (photos[currentIndex] as? IDMPhoto)?.placeholderImage = imageView.image
            self.setInitialPageIndex(UInt(currentIndex))
        }
    }
   
//    convenience init(msg:SocketMessage, conversationType:SocketChannelType,conversationID:String, from imageView:UIImageView) {
//        let msgList = SocketMessage.getAllMsg(with: conversationType, conversationId: conversationID, msgType: .image)
//        self.init(msg: msg, msgList: msgList, from: imageView)
//    }
//
//    convenience init(msg:SocketMessage, conversation:SocketConversationModel, from imageView:UIImageView) {
//        self.init(msg: msg, conversationType: conversation.type, conversationID: conversation.conversationId, from: imageView)
//    }
//
//    init(burnBrowserWith msg:SocketMessage, from imageView:UIImageView) {
//        let distance = (msg.snapTime - Date.timestamp)/1000
//        var photos = [IDMPhoto]()
//
//        if let imageURl = URL.init(string: msg.body.imageUrl),
//            let photo = IDMPhoto.init(url: imageURl) {
//            photo.placeholderImage = imageView.image
//            photos = [photo]
//        }
//
//        super.init(photos: photos, animatedFrom: imageView)
//        self.delegate = self
//        self.scaleImage = imageView.image
//        self.displayToolbar = false
//        self.displayDoneButton = false
//        self.dismissOnTouch = true
//
//        let burnProgressView = FZMBurnProgressView(endTime: distance)
//        burnProgressView.countDownCompleteBlock = {[weak self, weak burnProgressView] in
//            burnProgressView?.removeFromSuperview()
//            self?.dismiss(animated: true, completion: nil)
//        }
//        UIApplication.shared.keyWindow?.addSubview(burnProgressView)
//        self.burnProgressView = burnProgressView
//
//    }
    
//    func viewDidLongPressed() {
//        guard idmPhotoIndex >= 0,
//            let img = (self.photo(at: UInt(self.idmPhotoIndex)) as? IDMPhoto)?.value(forKey: "underlyingImage") as? UIImage else { return }
//        VoiceMessagePlayerManager.shared().vibrateAction()
//        if let str = FZMQRCodeGenerator.detectorQRCode(with: img) {
//            FZMBottomSelectView.show(with: [
//                FZMBottomOption(title: "转发图片", block: {
//                    FZMUIMediator.shared().pushVC(.multipleSendMsg(type: .image(image: img)))
//                }),FZMBottomOption(title: "保存图片", block: {[weak self] in
//                    self?.saveBtnClick(img: img)
//                }),FZMBottomOption(title: "识别图中二维码", block: {[weak self] in
//                    self?.dismiss(animated: false, completion: {
//                        FZMUIMediator.shared().parsingUrl(with: str)
//                    })
//                })])
//        }else {
//            FZMBottomSelectView.show(with: [
//                FZMBottomOption(title: "转发图片", block: {
//                    FZMUIMediator.shared().pushVC(.multipleSendMsg(type: .image(image: img)))
//                }),FZMBottomOption(title: "保存图片", block: {[weak self] in
//                    self?.saveBtnClick(img: img)
//                })])
//        }
//    }
    
//    func saveBtnClick(img:UIImage) {
//    func saveBtnClick() {
//        guard idmPhotoIndex >= 0,
//              let img = (self.photo(at: UInt(self.idmPhotoIndex)) as? IDMPhoto)?.value(forKey: "underlyingImage") as? UIImage else { return }
//        UIImageWriteToSavedPhotosAlbum(img, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
//    }
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = L("图片保存失败")
        }else{
            showMessage = L("图片已保存")
            
        }
        APP.shared().showToast(showMessage)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameorNil:String?,bundle nibBundleOrNil:Bundle?){
        super.init(nibName:nibNameorNil,bundle:nibBundleOrNil)
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 长按大图：弹出底部菜单（转发 / 识别二维码 / 保存）。
        // 原来右下角那个「下载」按钮已移除，保存收进菜单里
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        self.view.addGestureRecognizer(longPress)
    }

    // MARK: - 长按菜单

    /// 本次浏览共几张。IDM 的 `numberOfPhotos` 是私有方法，Swift 里取不到，自己记一份
    /// （不光为了防止越界：`photo(at:)` 越界会直接抛异常）
    private var photoCount = 0

    /// 当前正在看的那一页（委托还没回调时按第 0 页兜底）
    private func currentPhoto() -> IDMPhoto? {
        guard photoCount > 0 else { return nil }
        let index = (idmPhotoIndex >= 0 && idmPhotoIndex < photoCount) ? idmPhotoIndex : 0
        return self.photo(at: UInt(index)) as? IDMPhoto
    }

    /// 原图：只有 SDWebImage 下载完成才有值
    private func originalImage() -> UIImage? {
        guard let photo = currentPhoto() else { return nil }
        return photo.value(forKey: "underlyingImage") as? UIImage
    }

    /// 屏幕上真正显示着的那张图：原图没下完时就是 IDM 正在显示的缩略图 / 占位图。
    /// （原来这里只认 `underlyingImage`，所以图还没下完的那几张长按完全没反应）
    private func displayedImage() -> UIImage? {
        return originalImage() ?? PhotoLongPressHelper.visibleImage(in: self.view)
    }

    /// 原图还没下完时的提示（比“什么都不发生”清楚）
    private func showImageLoadingToast() {
        APP.shared().showToast(L("图片还在加载中，请稍后再试"))
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        // 只要能定位到当前这一页就先弹菜单（原图可能还在下载，具体动作里再判断）
        guard currentPhoto() != nil else { return }
        VoiceMessagePlayerManager.shared().vibrateAction()

        // 识别放后台（多档兜底：小二维码 / 低清缩略图也要认出来；
        // 一张图里的**所有**二维码都要收，多点几张图时用户才能「点哪个扫哪个」），回来再弹菜单
        PhotoLongPressHelper.qrCodes(in: originalImage() ?? displayedImage()) { [weak self] hits in
            // 识别期间大图可能已经被关掉
            guard let self = self, self.view.window != nil else { return }
            self.showLongPressMenu(qrCodes: hits)
        }
    }

    /// 长按菜单：转发图片 / （图里有二维码时）识别图中二维码 / 保存图片
    private func showLongPressMenu(qrCodes: [QRCodeHit]) {
        var options = [FZMBottomOption]()
        options.append(FZMBottomOption(title: L("转发图片"), block: { [weak self] in
            guard let self = self else { return }
            guard let image = self.originalImage() else { return self.showImageLoadingToast() }
            self.chooseShareTarget(image)
        }))
        // 有二维码才加这一项
        if !qrCodes.isEmpty {
            options.append(FZMBottomOption(title: L("识别图中二维码"), block: { [weak self] in
                self?.handleQRCode(qrCodes)
            }))
        }
        options.append(FZMBottomOption(title: L("保存图片"), block: { [weak self] in
            guard let self = self else { return }
            guard let image = self.originalImage() else { return self.showImageLoadingToast() }
            self.saveImage(image)
        }))
        FZMBottomSelectView.show(with: "", arr: options)
    }

    /// 处理二维码：图里有**多个**码时先在图上框出来让用户点选（点哪个扫哪个），
    /// 只有一个码时和以前一样直接识别（不多点一次）
    private func handleQRCode(_ hits: [QRCodeHit]) {
        guard hits.count > 1 else {
            if let hit = hits.first { handlePickedQRCode(hit.value) }
            return
        }
        PhotoLongPressHelper.pickQRCode(in: self.view, hits: hits) { [weak self] hit in
            guard let self = self, let hit = hit else { return }   // 点空白处 = 取消，什么都不做
            self.handlePickedQRCode(hit.value)
        }
    }

    /// 按选中的二维码内容办事（和「扫一扫」同一套逻辑：加好友 / 加群 / 开链接…）
    private func handlePickedQRCode(_ qrString: String) {
        self.dismissManually {
            if !QRCodeResultHandler.handle(qrString, from: UIViewController.current()) {
                APP.shared().showToast(qrString)
            }
        }
    }

    /// 转发图片：好友和群聊放在同一张列表里，选完直接进会话
    private func chooseShareTarget(_ image: UIImage) {
        // 弹选择页的宿主必须在关闭大图之前取好（关完 presentingViewController 就没了）
        let host = self.presentingViewController
        self.dismissManually {
            PhotoLongPressHelper.forward(image, from: host ?? UIViewController.current())
        }
    }

    /// 保存到相册（原来的下载按钮换成这里）
    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
    }

}


extension FZMPhotoBrowser: IDMPhotoBrowserDelegate {
    func willDisappear(_ photoBrowser: IDMPhotoBrowser!) {
        self.idmPhotoIndex = -1
//        self.burnProgressView?.removeFromSuperview()
    }
    func photoBrowser(_ photoBrowser: IDMPhotoBrowser!, didShowPhotoAt index: UInt) {
        self.idmPhotoIndex = Int(index)
    }
}

// MARK: - 大图长按的公共能力（广场 FZMPhotoBrowser / 聊天 Lantern 共用）

/// 大图长按菜单（转发图片 / 识别图中二维码 / 保存图片）的公共实现。
/// 广场用的是 `FZMPhotoBrowser`（IDMPhotoBrowser 子类，代码在 SquarePhotoPresenter），
/// 聊天用的是 `Lantern`（见 ChatVC.showBigImageViewFromView）—— 两边表现要一致，所以抽到这里。
enum PhotoLongPressHelper {

    /// 当前屏幕上可见面积最大的那个 imageView（大图浏览里就是用户正在看的那张）。
    /// 不依赖具体浏览器的内部实现（IDMPhotoBrowser / Lantern 各有一套），遍历视图层级即可。
    static func visibleImageView(in container: UIView?) -> UIImageView? {
        guard let container = container else { return nil }
        var best: (view: UIImageView, area: CGFloat)?
        walk(container, in: container) { imageView in
            guard imageView.image != nil, !imageView.isHidden, imageView.alpha > 0.01 else { return }
            let frame = imageView.convert(imageView.bounds, to: container)
            let visible = frame.intersection(container.bounds)
            guard !visible.isNull, visible.width > 1, visible.height > 1 else { return }
            let area = visible.width * visible.height
            if area > (best?.area ?? 0) { best = (imageView, area) }
        }
        return best?.view
    }

    /// 当前屏幕上可见面积最大的那张图 —— 大图浏览里就是用户正在看的那张。
    static func visibleImage(in container: UIView?) -> UIImage? {
        return visibleImageView(in: container)?.image
    }

    /// imageView 里**实际画出来**的图片区域（会考虑 contentMode：aspectFit 有留白、aspectFill 会溢出）。
    /// 二维码的归一化坐标必须乘到这个区域上，否则框画不到正确位置。
    static func drawnImageRect(in imageView: UIImageView) -> CGRect {
        let bounds = imageView.bounds
        guard let size = imageView.image?.size, size.width > 0, size.height > 0,
              bounds.width > 0, bounds.height > 0 else { return bounds }
        switch imageView.contentMode {
        case .scaleAspectFit:
            let scale = min(bounds.width / size.width, bounds.height / size.height)
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            return CGRect(x: (bounds.width - drawn.width) / 2, y: (bounds.height - drawn.height) / 2,
                          width: drawn.width, height: drawn.height)
        case .scaleAspectFill:
            let scale = max(bounds.width / size.width, bounds.height / size.height)
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            return CGRect(x: (bounds.width - drawn.width) / 2, y: (bounds.height - drawn.height) / 2,
                          width: drawn.width, height: drawn.height)
        default:
            // scaleToFill / center 这些：直接用整个 bounds 近似（大图浏览用不到）
            return bounds
        }
    }

    /// 图里**所有**二维码（带位置）。
    /// 一张图可能有好几个码（截图 / 拼图很常见），长按菜单据此让用户「点哪个扫哪个」。
    ///
    /// 识别跑在**后台队列**：多档兜底在没码时要把所有档跑一遍，放主线程会让长按明显卡一下。
    static func qrCodes(in image: UIImage?, completion: @escaping ([QRCodeHit]) -> Void) {
        guard let image = image else {
            completion([])
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let hits = QRCodeGenerator.robustQRCodes(in: image)
            DispatchQueue.main.async { completion(hits) }
        }
    }

    /// 在图上把识别到的二维码都框出来，等用户点选：**点了哪个扫哪个**；点空白处 = 取消（回调 nil）。
    static func pickQRCode(in container: UIView, hits: [QRCodeHit], onPick: @escaping (QRCodeHit?) -> Void) {
        QRCodePickOverlay.present(in: container, hits: hits, onPick: onPick)
    }

    /// 转发：好友 + 群聊合并列表，选中后开该会话把图片发出去
    /// （图片交给 `ChatManager.setPendingShareImage`，进会话后由 ChatVC 用自己的发送逻辑发出）
    static func forward(_ image: UIImage, from host: UIViewController?) {
        let picker = ChoiceContactCardVC()
        picker.showsFriendAndGroup = true
        picker.seletedBlock = { [weak picker] contact in
            let address = contact.user?.address ?? contact.group?.address ?? ""
            guard !address.isEmpty else { return }
            // 会话类型看这条联系人自己是好友还是群，不让用户先选一遍
            let sessionID: SessionID = contact.type == .group ? SessionID.group(address) : SessionID.person(address)
            ChatManager.shared().setPendingShareImage(image, for: sessionID)
            picker?.dismiss(animated: true) {
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: sessionID))
            }
        }
        let nav = FZMNavigationController(rootViewController: picker)
        (host ?? UIViewController.current())?.present(nav, animated: true)
    }

    private static func walk(_ view: UIView, in container: UIView, visit: (UIImageView) -> Void) {
        if let imageView = view as? UIImageView { visit(imageView) }
        view.subviews.forEach { walk($0, in: container, visit: visit) }
    }
}

// MARK: - 大图上的「点选二维码」浮层

/// 把识别到的每个二维码在图上框出来，点哪个回调哪个（点空白处 = 取消）。
///
/// ⚠️ 挂在 **keyWindow** 上（而不是浏览器自己的 view 上）：这样浏览器的
/// 「单击关闭 / 双击放大 / 下拉关闭」这些手势收不到触摸，
/// 否则点一下框大图就被关掉了（IDMPhotoBrowser 的 `dismissOnTouch = true` 尤其明显）。
final class QRCodePickOverlay: UIView {

    private let hits: [QRCodeHit]
    private let onPick: (QRCodeHit?) -> Void
    private var isFinishing = false

    /// 同一时间只留一个（重复长按不会叠层）
    private static weak var current: QRCodePickOverlay?

    static func present(in container: UIView, hits: [QRCodeHit], onPick: @escaping (QRCodeHit?) -> Void) {
        // 已经有一个在选：先把它当「取消」收掉
        current?.finish(nil)
        guard !hits.isEmpty,
              let window = container.window,
              let imageView = PhotoLongPressHelper.visibleImageView(in: container) else { return }

        // 图片在屏幕上实际画出来的区域（大图浏览里还叠着缩放 / 滚动，convert 会一起算进去）
        let drawnInImageView = PhotoLongPressHelper.drawnImageRect(in: imageView)
        let drawn = window.convert(drawnInImageView, from: imageView)

        let overlay = QRCodePickOverlay(frame: window.bounds, hits: hits, onPick: onPick)
        overlay.build(drawnImageRect: drawn)
        window.addSubview(overlay)
        current = overlay
        overlay.appear()
    }

    private init(frame: CGRect, hits: [QRCodeHit], onPick: @escaping (QRCodeHit?) -> Void) {
        self.hits = hits
        self.onPick = onPick
        super.init(frame: frame)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // 轻微压暗：让框更明显，但压太暗反而看不清码
        self.backgroundColor = UIColor.black.withAlphaComponent(0.12)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 搭建

    private func build(drawnImageRect drawn: CGRect) {
        // ① 点空白处 = 取消：用一个铺满的按钮接住（比手势稳，不会和下面的框抢）
        let backButton = UIButton(type: .custom)
        backButton.frame = bounds
        backButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backButton.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        addSubview(backButton)

        // ② 每个二维码一个可点框（多个码时带编号，方便说「第几个」）
        let showsIndex = hits.count > 1
        for (index, hit) in hits.enumerated() {
            var rect = CGRect(x: drawn.minX + hit.normalizedRect.minX * drawn.width,
                              y: drawn.minY + hit.normalizedRect.minY * drawn.height,
                              width: hit.normalizedRect.width * drawn.width,
                              height: hit.normalizedRect.height * drawn.height)
            rect = rect.insetBy(dx: -6, dy: -6)
            // 屏幕上的码可能很小：保证点得到（44 是最小点击区）
            if rect.width < 44 || rect.height < 44 {
                rect = rect.insetBy(dx: -(max(44 - rect.width, 0)) / 2, dy: -(max(44 - rect.height, 0)) / 2)
            }
            // 只保留还压在图片上的部分（aspectFill 时框可能超出图片显示区域）
            let visible = rect.intersection(drawn)
            guard !visible.isNull, visible.width > 8, visible.height > 8 else { continue }

            let button = UIButton(type: .custom)
            button.frame = rect
            button.tag = index
            button.backgroundColor = Color_Theme.withAlphaComponent(0.18)
            button.layer.borderColor = Color_Theme.cgColor
            button.layer.borderWidth = 2
            button.layer.cornerRadius = 6
            button.addTarget(self, action: #selector(markerTap(_:)), for: .touchUpInside)
            addSubview(button)

            let title = showsIndex ? "\(L("二维码")) \(index + 1)" : L("二维码")
            let tag = UILabel()
            tag.text = title
            tag.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            tag.textColor = .white
            tag.textAlignment = .center
            tag.backgroundColor = Color_Theme
            tag.layer.cornerRadius = 9
            tag.layer.masksToBounds = true
            let textWidth = (title as NSString).size(withAttributes: [.font: tag.font as Any]).width
            tag.frame = CGRect(x: rect.minX, y: max(rect.minY - 22, 4),
                               width: max(ceil(textWidth) + 16, 34), height: 18)
            addSubview(tag)
        }

        addHintBar()
    }

    /// 底部提示条：告诉用户要干嘛 + 怎么退出
    private func addHintBar() {
        let bar = UIView()
        bar.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        bar.layer.cornerRadius = 18
        bar.layer.masksToBounds = true

        let label = UILabel()
        label.text = L("点击要识别的二维码")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white

        let cancel = UIButton(type: .custom)
        cancel.setTitle(L("取消"), for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        cancel.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        cancel.layer.borderWidth = 0.5
        cancel.layer.cornerRadius = 12
        cancel.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)

        let labelText = label.text ?? ""
        let labelWidth = ceil((labelText as NSString).size(withAttributes: [.font: label.font as Any]).width)
        let height: CGFloat = 36
        let width = min(labelWidth + 16 + 58 + 20, bounds.width - 24)
        bar.frame = CGRect(x: (bounds.width - width) / 2,
                           y: bounds.height - safeBottomInset - height - 20,
                           width: width, height: height)
        label.frame = CGRect(x: 10, y: 0, width: labelWidth, height: height)
        cancel.frame = CGRect(x: width - 12 - 46, y: (height - 24) / 2, width: 46, height: 24)
        bar.addSubview(label)
        bar.addSubview(cancel)
        bar.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]
        addSubview(bar)
    }

    private var safeBottomInset: CGFloat {
        if #available(iOS 11.0, *) {
            return window?.safeAreaInsets.bottom ?? 0
        }
        return 0
    }

    // MARK: - 交互

    @objc private func markerTap(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < hits.count else { return finish(nil) }
        finish(hits[sender.tag])
    }

    @objc private func cancelTap() {
        finish(nil)
    }

    private func appear() {
        alpha = 0
        UIView.animate(withDuration: 0.15) { self.alpha = 1 }
    }

    /// 收掉浮层并回调（点选 → 对应的二维码；取消 → nil）
    private func finish(_ hit: QRCodeHit?) {
        guard !isFinishing else { return }
        isFinishing = true
        let completion = onPick
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
            completion(hit)
        }
    }
}
