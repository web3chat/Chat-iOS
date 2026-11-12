//
//  FZMBurnDetailVC.swift
//  chat
//
//  阅后即焚独立详情页：只展示这一条消息，禁止左右滑到其它消息。
//  · 「打开即已读」：viewDidAppear 即写入待确认队列（落库）
//  · 「关闭才焚」：viewWillDisappear 调 burn-confirm（幂等），等信令回来换气泡
//  文档：《阅后即焚_App对接文档》
//

import UIKit
import AVKit
import Kingfisher
import SnapKit
import RxSwift

final class FZMBurnDetailVC: UIViewController {

    private let message: Message
    /// 对端 uid（这条 burn 消息的发送者）
    private let targetId: String
    private let bag = DisposeBag()
    private var hasConfirmed = false

    private lazy var vm = FZMMessageBaseVM(with: message)

    private lazy var contentContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }()

    // MARK: - 自绘标题栏（不用系统导航栏）

    /// 系统导航栏在 iOS 26/27 上会套「液态玻璃」，返回按钮在浅色背景上会看不见；
    /// 这里整页隐藏系统导航栏、自绘一条纯色标题栏，彻底避开玻璃效果。
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(
            UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = Color_Theme
        button.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        return button
    }()

    private lazy var headerTitleLabel: UILabel = {
        return UILabel.getLab(
            font: .mediumFont(17), textColor: Color_24374E, textAlignment: .center,
            text: L("阅后即焚"))
    }()

    private lazy var headerLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: 0xE6EAEF)
        return view
    }()

    // MARK: - 防截屏（系统截屏 / 录屏显示黑块）

    /// 所有内容的父容器：运行时整体搬进 secure 画布
    private let protectedContainer = UIView()
    /// `isSecureTextEntry` 的隐藏输入框 —— 它的子视图层会被系统排除在截屏/录屏之外，
    /// 搬进去的内容在系统截图里就是黑的。⚠️ 依赖 UIKit 私有视图层级，属于业界通用 hack。
    private lazy var secureField: UITextField = {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.backgroundColor = .clear
        field.tintColor = .clear
        return field
    }()
    private var didAttachSecureCanvas = false
    /// 标题栏高度（安全区 + 44），跟随安全区更新
    private var headerHeight: CGFloat = 88
    /// 底部提示距离（安全区 + 16）
    private var bottomInset: CGFloat = 16

    private lazy var hintLabel: UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(13), textColor: Color_8A97A5,
                              textAlignment: .center, text: L("关闭后将焚毁这条消息"))
    }()

    init(message: Message, targetId: String) {
        self.message = message
        self.targetId = targetId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = Color_F6F7F8
        self.title = L("阅后即焚")

        // 防截屏用的隐藏 secure 输入框（先挂上，布局完成后再把内容搬进它的画布）
        self.view.addSubview(secureField)
        secureField.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }

        setupUI()
        buildContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let newHeader = self.view.safeAreaInsets.top + 44
        if abs(newHeader - self.headerHeight) > 0.5 {
            self.headerHeight = newHeader
            self.headerView.snp.updateConstraints { (m) in
                m.height.equalTo(newHeader)
            }
        }
        let newBottom = self.view.safeAreaInsets.bottom + 16
        if abs(newBottom - self.bottomInset) > 0.5 {
            self.bottomInset = newBottom
            self.hintLabel.snp.updateConstraints { (m) in
                m.bottom.equalToSuperview().offset(-newBottom)
            }
        }

        self.attachSecureCanvasIfNeeded()
    }

    /// 把内容容器搬进 secure 画布：搬进去之后系统截屏 / 录屏拍到的就是黑块
    private func attachSecureCanvasIfNeeded() {
        guard !didAttachSecureCanvas else { return }
        guard let canvas = self.secureField.subviews.first, canvas.bounds.width > 0 else { return }
        didAttachSecureCanvas = true

        canvas.isUserInteractionEnabled = true
        self.protectedContainer.removeFromSuperview()
        self.protectedContainer.translatesAutoresizingMaskIntoConstraints = true
        canvas.addSubview(self.protectedContainer)
        self.protectedContainer.frame = canvas.bounds
        self.protectedContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        FZMLog("【防截屏】已挂到 secure 画布 size=\(canvas.bounds.size)")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 隐藏系统导航栏（避免液态玻璃 + 返回按钮不可见），退场时恢复
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 打开即已读：正文开始展示就写入待确认表（不要等用户看完）
        guard !message.isOutgoing, let logId = message.logId, logId > 0 else { return }
        ChatManager.shared().enqueueBurnPending(logId: logId, targetId: targetId)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 先恢复系统导航栏，否则返回到上一页时导航栏还是隐藏的
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        guard !hasConfirmed else { return }
        hasConfirmed = true
        // 发方看自己的 burn 消息不 confirm
        guard !message.isOutgoing, let logId = message.logId, logId > 0 else { return }
        ChatManager.shared().confirmBurn(logId: logId, targetId: targetId)
    }

    @objc private func goBack() {
        if let nav = self.navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }

    // MARK: - UI

    private func setupUI() {
        // 所有内容先挂在一个容器里：运行时再把这个容器搬进「安全画布」，系统截屏/录屏会显示黑块
        self.view.addSubview(protectedContainer)
        protectedContainer.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }

        // 自绘标题栏（系统导航栏已隐藏）
        protectedContainer.addSubview(headerView)
        headerView.snp.makeConstraints { (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(self.headerHeight)
        }
        headerView.addSubview(backButton)
        backButton.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(6)
            m.bottom.equalToSuperview().offset(-2)
            m.width.height.equalTo(44)
        }
        headerView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.centerY.equalTo(backButton)
        }
        headerView.addSubview(headerLine)
        headerLine.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }

        self.protectedContainer.addSubview(contentContainer)
        contentContainer.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.left.greaterThanOrEqualToSuperview().offset(24)
            m.right.lessThanOrEqualToSuperview().offset(-24)
            m.width.lessThanOrEqualTo(300)
            m.height.lessThanOrEqualTo(460)
        }

        self.protectedContainer.addSubview(hintLabel)
        hintLabel.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.bottom.equalToSuperview().offset(-(self.bottomInset))
            m.height.equalTo(20)
        }
    }

    private func buildContent() {
        switch message.msgType {
        case .text:
            addTextContent(message.msgType.textValue)
        case .image:
            addImageContent()
        case .video:
            addMediaButton(title: L("点击播放视频"), icon: "play.circle.fill") { [weak self] in
                self?.playVideo()
            }
        case .audio:
            addMediaButton(title: L("点击播放语音"), icon: "Play.fill") { [weak self] in
                self?.playAudio()
            }
        case .file:
            addMediaButton(title: message.msgType.fileName ?? L("点击查看文件"), icon: "doc.fill") { [weak self] in
                self?.openFile()
            }
        default:
            addTextContent(L("不支持的消息类型"))
        }
    }

    private func addTextContent(_ text: String) {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = Color_24374E
        label.text = text
        contentContainer.addSubview(label)
        label.snp.makeConstraints { (m) in
            m.edges.equalToSuperview().inset(16)
        }
    }

    private func addImageContent() {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = Color_F6F7F8
        contentContainer.addSubview(imageView)
        imageView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview().inset(8)
            m.width.equalTo(260)
            m.height.equalTo(320)
        }
        loadImage { (image) in
            imageView.image = image ?? UIImage(systemName: "photo")
        }
    }

    private func addMediaButton(title: String, icon: String, action: @escaping () -> Void) {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.setTitle("  " + title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.tintColor = Color_Theme
        button.rx.tap.subscribe(onNext: { action() }).disposed(by: bag)
        contentContainer.addSubview(button)
        button.snp.makeConstraints { (m) in
            m.edges.equalToSuperview().inset(24)
            m.height.equalTo(44)
            m.width.equalTo(220)
        }
    }

    // MARK: - 图片：按需下载 + 解密

    private func loadImage(_ complete: @escaping (UIImage?) -> Void) {
        if let cacheKey = message.msgType.cachekey {
            ChatMediaCache.safeRetrieveImage(forKey: cacheKey, maxPixelSize: 2048) { [weak self] image in
                if let image = image {
                    complete(image)
                } else {
                    self?.downloadImage(complete)
                }
            }
        } else {
            downloadImage(complete)
        }
    }

    private func downloadImage(_ complete: @escaping (UIImage?) -> Void) {
        guard let urlStr = message.msgType.url else { complete(nil); return }
        let address = message.fromId == LoginUser.shared().address ? message.targetId : message.fromId
        let msg = message
        ChatManager.getPublickey(by: address, isGetUserKey: msg.sessionId.isPersonChat) { (pubkey) in
            DispatchQueue.global(qos: .userInitiated).async {
                var data = try? Data(contentsOf: URL(string: urlStr) ?? URL(fileURLWithPath: ""))
                if !pubkey.isBlank, let d = data, d.count > 0 {
                    let decrypted = ChatManager.decryptUploadData(d, publickey: pubkey, isEncryptPersionChatData: msg.sessionId.isPersonChat)
                    if decrypted.count > 0 { data = decrypted }
                }
                let image = data.flatMap { UIImage.safeDecodedImage(data: $0, maxPixelSize: 2048) }
                DispatchQueue.main.async {
                    if let image = image, let cacheKey = msg.msgType.cachekey {
                        ChatMediaCache.store(image, forKey: cacheKey)
                    }
                    complete(image)
                }
            }
        }
    }

    // MARK: - 视频 / 语音 / 文件：下载后播放 / 预览

    private func ensureDownloaded(then complete: @escaping () -> Void) {
        if vm.isLocalFileExist {
            complete()
            return
        }
        vm.fileDownloadSucceedSubject.subscribe(onNext: { [weak self] (_) in
            guard let self = self else { return }
            self.vm.isLocalFileExist = true
            complete()
        }).disposed(by: bag)
        vm.fileDownloadFailedSubject.subscribe(onNext: { [weak self] (_) in
            self?.showToast(L("文件下载失败"))
        }).disposed(by: bag)
        vm.downloadData()
    }

    private func playVideo() {
        ensureDownloaded { [weak self] in
            guard let self = self else { return }
            let player = AVPlayerViewController()
            player.player = AVPlayer(url: URL(fileURLWithPath: self.vm.localFilePath))
            self.present(player, animated: true) { player.player?.play() }
        }
    }

    private func playAudio() {
        ensureDownloaded { [weak self] in
            guard let self = self else { return }
            VoiceMessagePlayerManager.shared().playVoice(msg: self.message)
        }
    }

    private func openFile() {
        ensureDownloaded { [weak self] in
            guard let self = self else { return }
            let url = URL(fileURLWithPath: self.vm.localFilePath)
            let document = UIDocumentInteractionController(url: url)
            document.delegate = self
            self.documentInteractionController = document
            document.presentPreview(animated: true)
        }
    }

    private var documentInteractionController: UIDocumentInteractionController?
}

extension FZMBurnDetailVC: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}
