//
//  MediaMessageCell.swift
//  chat
//
//  Created by fzm on 2021/3/17.
//

import UIKit
import Kingfisher
import TZImagePickerController

class MediaMessageCell: MessageContentCell {
    
    // GIF 动画图解码缓存（解码一次，滚动复用不再重复解码；NSCache 自动淘汰）
    private static let gifAnimatedCache = NSCache<NSString, UIImage>()
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 5
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        return imageView
    }()
    
    lazy var playView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage.init(named: "icon_video_play")//icon_video_download
        imageView.size = CGSize.init(width: 50, height: 50)
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var timeLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 16), textColor: Color_Auxiliary, textAlignment: .right, text: "00:00")
        return lab
    }()
    
    var downloadOrUploadProgressView = SectorProgress.init(frame: CGRect.init(x: 0, y: 0, width: 50, height: 50))

    /// 图片是否处于「加载失败」状态（直连 + 下载解密两条路都失败）。
    /// 点击这种 cell 时不打开大图（大图拿到的还是同一份密文），改为重新拉公钥 + 解密。
    private(set) var isPhotoLoadFailed = false

    /// 图片「加载中 / 加载失败」兜底视图。
    /// 🔴 图片下载失败、解密失败、甚至服务端根本没下发 URL 时，单元格里必须有可见内容 ——
    ///    消息本身不会丢（已经落库），但气泡里绝不能是一片空白。
    lazy var placeholderView: MediaPlaceholderView = {
        let view = MediaPlaceholderView()
        view.isHidden = true
        return view
    }()
    
    
    override func setupViews() {
        super.setupViews()
        self.messageContainerView.addSubview(self.imageView)
        self.messageContainerView.addSubview(self.placeholderView)
        self.messageContainerView.addSubview(self.playView)
        self.messageContainerView.addSubview(self.timeLab)
        
        self.messageContainerView.addSubview(downloadOrUploadProgressView)
        downloadOrUploadProgressView.isHidden = true
        downloadOrUploadProgressView.alpha = 0.6
        downloadOrUploadProgressView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 50, height: 50))
        }
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        self.imageView.frame = self.messageContainerView.bounds
        self.placeholderView.frame = self.messageContainerView.bounds
        self.playView.center = self.imageView.center
        self.timeLab.frame = CGRect.init(x: 5, y: self.messageContainerView.bounds.height - 27, width: self.messageContainerView.bounds.width - 10, height: 22)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.imageView.kf.cancelDownloadTask()
        self.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        self.playView.isHidden = true
        // 复用 cell 时必须把占位状态清干净，否则上一张图的「加载中」会带到下一条消息
        self.placeholderView.apply(.hidden)
        self.isPhotoLoadFailed = false
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messagesCollectionView: MessageCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            FZMLog("MediaMessageCell：messagesDisplayDelegate 为空，跳过配置")
            return
        }
        
        let currentMsgId = message.msgId
        
        switch message.kind {
        case .photo(let mediaItem):
            self.playView.isHidden = true
            self.timeLab.isHidden = true
            // 🔴 先把兜底占位显示出来：后面任何一步没走到，用户看到的也是「加载中」而不是一块空白
            self.placeholderView.apply(.loading)
            self.isPhotoLoadFailed = false
            // 缩略图只按 1280 安全取图（降采样 + 立即解码），避免大原图在 CA 提交时主线程硬解
            ChatMediaCache.safeRetrieveImage(forKey: mediaItem.mediaCachekey ?? "", maxPixelSize: 1280) { [weak self] (image) in
                guard let self = self else { return }
                // 防止 cell 复用导致图片错乱
                guard self.msg?.msgId == currentMsgId else { return }
                if let image = image {// 本地已有缓存则显示缓存图片
                    self.placeholderView.apply(.hidden)
                    // 判断是否为gif图
                    if let gifData = message.gifData {
                        // 优先显示静态帧（快），动画图后台解码一次并缓存，避免每次显示全量解码导致卡顿/变慢
                        let cacheKey = (message.msgType.cachekey ?? message.msgId) as NSString
                        if let cached = MediaMessageCell.gifAnimatedCache.object(forKey: cacheKey) {
                            self.imageView.image = cached
                        } else {
                            self.imageView.image = image// 先显示静态帧
                            let msgId = currentMsgId
                            DispatchQueue.global(qos: .userInitiated).async {
                                let animated = UIImage.sd_tz_animatedGIF(with: gifData)
                                if let animated = animated {
                                    MediaMessageCell.gifAnimatedCache.setObject(animated, forKey: cacheKey)
                                }
                                DispatchQueue.main.async {
                                    guard self.msg?.msgId == msgId else { return }
                                    self.imageView.image = animated ?? image
                                }
                            }
                        }
                    } else {
                        self.imageView.image = image
                    }
                } else if let url = mediaItem.url {
                    // ⚠️ 与大图保持一致：`FZMPhotoBrowser` 打开大图走的是 `IDMPhoto.init(url:)` —— **直接按 URL 加载**。
                    //    既然大图能显示，缩略图就应该同样直连（不再对 `$ENC$` 一律先下载解密 —— 那条路解不出就白块）。
                    //    直连真的拿不到图时，才回落到「下载 + 解密」兜底。
                    // 菊花统一由 `placeholderView` 画（kf 自带的会跟它叠在一起）
                    self.imageView.kf.indicatorType = .none
                    // 聊天图片显示最大边 150pt，用 Downsampling 降采样，避免大原图全尺寸解码导致卡顿/内存峰值
                    let targetSize = CGSize(width: 150 * UIScreen.main.scale, height: 150 * UIScreen.main.scale)
                    // 省图模式：去掉 `.cacheOriginalImage`（它会把原图再存一份，气泡只需要 150pt 缩略图）。
                    // 关闭时保持原行为 —— 原图也在缓存里，点开大图不用重新下载。
                    var thumbOptions: KingfisherOptionsInfo = [.processor(DownsamplingImageProcessor(size: targetSize))]
                    // 聊天图片写进专用缓存（`ChatMediaCache`）：「清理缓存」不会清掉它
                    thumbOptions.append(.targetCache(ChatMediaCache))
                    if !FZM_EnableImageSaveMode {
                        thumbOptions.append(.cacheOriginalImage)
                    }
                    self.imageView.kf.setImage(
                        with: URL.init(string: url),
                        options: thumbOptions,
                        completionHandler: { [weak self] (result) in
                            guard let self = self, self.msg?.msgId == currentMsgId else { return }
                            switch result {
                            case .success(_):
                                self.placeholderView.apply(.hidden)
                            case .failure(_):
                                // 直连拿不到图（真·密文等）⇒ 下载 + 解密兜底（与实时收图同款加解密）
                                ChatManager.shared().loadEncryptedImage(for: message) { [weak self] (image) in
                                    guard let self = self, self.msg?.msgId == currentMsgId else { return }
                                    if let image = image {
                                        self.imageView.image = image
                                        self.placeholderView.apply(.hidden)
                                    } else {
                                        // 🔴 兜底也失败：显示占位图 + 文案，绝不留白（消息本身已经在库里，不会丢）
                                        self.placeholderView.apply(.failed, title: L("图片加载失败"))
                                        self.isPhotoLoadFailed = true
                                    }
                                }
                            }
                        })
                } else {
                    // 服务端根本没下发 URL（字段缺失 / 老消息）⇒ 直接给占位，不留空白
                    self.placeholderView.apply(.failed, title: L("图片加载失败"))
                    self.isPhotoLoadFailed = true
                }
            }
        case .video(let mediaItem):
            self.playView.isHidden = false
            self.timeLab.isHidden = false
            self.timeLab.text = String.transToHourMinSec(time: mediaItem.duration ?? 0)
            // 视频自带深色底 + 播放/下载图标（本身就是占位），不需要图片那套菊花/占位
            self.placeholderView.apply(.hidden)
            // 视频消息设置深色占位背景，避免白屏
            self.imageView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            ChatMediaCache.safeRetrieveImage(forKey: mediaItem.mediaCachekey ?? "", maxPixelSize: 1280) { [weak self] (image) in
                guard let self = self else { return }
                // 防止 cell 复用导致图片错乱
                guard self.msg?.msgId == currentMsgId else { return }
                if let image = image {
                    // 本地已有缩略图缓存（发送方或已下载）
                    self.imageView.image = image
                    self.imageView.backgroundColor = .clear
                }
                // 注意：video 的 url 指向视频文件而非缩略图，不可用 kf.setImage 加载
                // 接收方需先下载视频，再通过 getVideoCoverImage 提取封面并调用 updateSatusAndImage
            }
            
            let fileName = "\(message.msgType.cachekey ?? "")"
            let filePath = DocumentPath.appendingPathComponent("Video/\(fileName).MOV")
            if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
                self.playView.image = UIImage.init(named: "icon_video_play")
            }else{
                self.playView.image = UIImage.init(named: "icon_video_download")
            }
            
        default:
            break
        }
        displayDelegate.configureMediaMessageImageView(self.imageView, for: message, at: indexPath, in: messagesCollectionView)
    }
    
    //下载完视频 更新状态
    func updateSatus(){
        DispatchQueue.main.async {
            self.playView.image = UIImage.init(named: "icon_video_play")
            
            ChatMediaCache.safeRetrieveImage(forKey: self.msg?.msgType.cachekey ?? "") { image in
                guard let image = image else { return }
                self.imageView.image = image
                self.imageView.backgroundColor = .clear
            }
        }
    }
    func updateSatusAndImage(_ image: UIImage){
        DispatchQueue.main.async {
            self.imageView.image = image
            self.imageView.backgroundColor = .clear
            self.playView.image = UIImage.init(named: "icon_video_play")
        }
    }
    
    //更新下载进度
    func updateDownLoadProcress(proress : CGFloat){
        if proress < 1 {
            self.downloadOrUploadProgressView.isHidden = false
            self.downloadOrUploadProgressView.progress = proress
        }else{
            self.downloadOrUploadProgressView.isHidden = true
            self.downloadOrUploadProgressView.progress = 0
        }
    }
}

/// 图片 / 视频「暂时没有内容可显示」时的兜底视图。
///
/// 🔴 底线要求：**任何情况下都不允许出现「气泡里什么都没有」**。
///    消息已经落库（不会丢），但缩略图没缓存 / 下载失败 / 解密失败 / 服务端没给 URL 时，
///    必须给用户看到「转圈」或「占位图标」，而不是一块空白。
final class MediaPlaceholderView: UIView {

    enum State {
        case hidden
        case loading
        case failed
    }

    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.color = UIColor(white: 0.45, alpha: 1)
        return view
    }()

    private let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = UIColor(white: 0.55, alpha: 1)
        if #available(iOS 13.0, *) {
            view.image = UIImage(systemName: "photo")
        }
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor(white: 0.45, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(white: 0.95, alpha: 1)
        self.isUserInteractionEnabled = false
        // 与 `imageView` 保持同样的圆角，避免占位块把圆角顶出来
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true

        let stack = UIStackView(arrangedSubviews: [self.iconView, self.spinner, self.titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -4),
            self.iconView.widthAnchor.constraint(equalToConstant: 26),
            self.iconView.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: State, title: String? = nil) {
        switch state {
        case .hidden:
            self.isHidden = true
            self.spinner.stopAnimating()
        case .loading:
            self.isHidden = false
            self.backgroundColor = UIColor(white: 0.95, alpha: 1)
            self.iconView.isHidden = true
            self.titleLabel.isHidden = true
            self.spinner.startAnimating()
        case .failed:
            self.isHidden = false
            self.backgroundColor = UIColor(white: 0.93, alpha: 1)
            self.spinner.stopAnimating()
            self.iconView.isHidden = false
            self.titleLabel.isHidden = false
            self.titleLabel.text = title
        }
    }
}
