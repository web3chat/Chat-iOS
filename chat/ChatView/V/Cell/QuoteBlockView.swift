//
//  QuoteBlockView.swift
//  chat
//
//  消息引用（引用消息）—— 气泡**下方**那条灰色引用条：
//  第一行「昵称」、第二行「内容摘要」，内容单行、超出省略。
//
//  ⚠️ 高度必须与 `QuoteBlockMetrics.totalHeight`、`MessageSizeCalculator` 里加的高度严格一致，
//    否则气泡和引用条会重叠（算多了留白、算少了压住气泡）。
//

import Kingfisher
import SnapKit
import UIKit

/// 被引用消息的"媒体"部分：图片/视频显示缩略图，文件显示类型图标（用户 2026-11-04 要求，
/// 不要再退化成「[图片]」这种占位文字）
enum QuoteMedia {
    case none
    /// 图片：本地缓存 key 优先，没有缓存再按 url 拉
    case photo(cacheKey: String?, url: String?)
    /// 视频：只有本地封面缓存可用（video 的 `url` 指向视频文件，不能当图片加载）
    case video(cacheKey: String?)
    /// 文件：类型图标（`fileName.pathExtension.matchingFileType()`）
    case file(iconName: String?)

    var exists: Bool {
        if case .none = self { return false }
        return true
    }

    /// 缩略图占用的宽度（0 = 不占）
    var thumbWidth: CGFloat {
        return exists ? QuoteBlockMetrics.thumbSide + QuoteBlockMetrics.thumbGap : 0
    }
}

/// 一条消息要显示的引用信息（由 `ChatVC` 从被引用的原消息解析出来）
struct QuotePreview {
    /// 被引用消息发送人的显示名（私聊取昵称、群聊取群昵称）；可能为空
    let name: String
    /// 被引用消息的内容摘要（文本原文 / 文件名）；图片、视频为空（用缩略图表达）
    let content: String
    /// 直接引用的那条消息的 logId（点引用条时用它跳到原消息）
    let refLogId: Int
    /// 图片 / 视频 / 文件的缩略图信息
    var media: QuoteMedia = .none

    /// 没有文字内容时用来兜底的占位说明（图片/视频）
    private var placeholderText: String {
        switch media {
        case .photo: return L("[图片]")
        case .video: return L("[视频]")
        default: return ""
        }
    }

    /// 「昵称：内容」；没有昵称时只显示内容
    var displayText: String {
        let body = content.isBlank ? placeholderText : content
        if name.isBlank { return body }
        return body.isBlank ? name : "\(name)：\(body)"
    }

    /// 输入框上方那条引用条用的文本：图片/视频有缩略图，就不再重复写「[图片]」
    var barText: String {
        if content.isBlank { return name }
        return name.isBlank ? content : "\(name)：\(content)"
    }
}

/// 引用条的尺寸常量 —— 视图布局与行高计算共用这一份
enum QuoteBlockMetrics {
    /// 引用条本体高度
    static let blockHeight: CGFloat = 42
    /// 引用条与气泡之间的间距
    static let gap: CGFloat = 4
    /// 引用条占用的总高度（行高计算用这个）
    static var totalHeight: CGFloat { return blockHeight + gap }

    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 5
    static let lineHeight: CGFloat = 16
    static let cornerRadius: CGFloat = 5

    /// 缩略图 / 文件图标边长，及其与文字的间距
    static let thumbSide: CGFloat = 32
    static let thumbGap: CGFloat = 6

    /// 引用条宽度**只跟引用文字走**，不和气泡宽度绑定（用户 2026-11-04 要求）
    static let minWidth: CGFloat = 90

    static let nameFont = UIFont.mediumFont(12)
    static let contentFont = UIFont.regularFont(12)

    /// 按「昵称 / 内容」里较长的一行 + 缩略图宽度算引用条宽度（单行、不换行，超宽由 `maxWidth` 截断）
    static func width(for preview: QuotePreview, maxWidth: CGFloat) -> CGFloat {
        let nameWidth = (preview.name as NSString).size(withAttributes: [.font: nameFont]).width
        let contentWidth = (preview.content as NSString).size(withAttributes: [.font: contentFont]).width
        let textWidth = max(nameWidth, contentWidth)
        let width = textWidth + preview.media.thumbWidth + horizontalPadding * 2
        // 纯缩略图（没有文字）时不套用文字用的最小宽度，否则左边会空一大块
        let minAllowed = textWidth > 0 ? minWidth : width
        return min(max(width.rounded(.up), minAllowed), max(maxWidth, minAllowed))
    }
}

final class QuoteBlockView: UIView {

    // MARK: - 子视图

    /// 发送人
    private let nameLabel: UILabel = {
        let lab = UILabel.getLab(
            font: QuoteBlockMetrics.nameFont, textColor: Color_8A97A5, textAlignment: .left, text: "")
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()

    /// 内容摘要
    private let contentLabel: UILabel = {
        let lab = UILabel.getLab(
            font: QuoteBlockMetrics.contentFont, textColor: Color_8A97A5, textAlignment: .left,
            text: "")
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()

    /// 图片 / 视频缩略图、文件类型图标
    private let thumbView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor = UIColor.init(hexString: "#8A97A5", transparency: 0.12)
        iv.isHidden = true
        return iv
    }()

    /// 视频/文件的播放角标
    private let playIconView: UIImageView = {
        let iv = UIImageView(image: UIImage.init(named: "icon_video_play"))
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    /// 最近一次配置的引用（异步缩略图回来时校验，防止 cell 复用串图）
    private var currentRefLogId: Int = 0

    // MARK: - 生命周期

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        self.backgroundColor = UIColor.init(hexString: "#8A97A5", transparency: 0.09)
        self.layer.cornerRadius = QuoteBlockMetrics.cornerRadius
        self.layer.masksToBounds = true
        // 点击统一由 `MessageContentCell.handleTapGesture` 判定，这里不拦手势
        self.isUserInteractionEnabled = false

        self.addSubview(self.nameLabel)
        self.addSubview(self.contentLabel)
        self.addSubview(self.thumbView)
        self.addSubview(self.playIconView)

        let padding = QuoteBlockMetrics.horizontalPadding
        let lineHeight = QuoteBlockMetrics.lineHeight
        let top = QuoteBlockMetrics.verticalPadding

        self.nameLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(padding)
            m.right.equalToSuperview().offset(-padding)
            m.top.equalToSuperview().offset(top)
            m.height.equalTo(lineHeight)
        }
        self.contentLabel.snp.makeConstraints { (m) in
            m.left.equalTo(self.nameLabel)
            m.right.equalTo(self.nameLabel)
            m.top.equalTo(self.nameLabel.snp.bottom)
            m.height.equalTo(lineHeight)
        }
        self.thumbView.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-padding)
            m.centerY.equalToSuperview()
            m.width.height.equalTo(QuoteBlockMetrics.thumbSide)
        }
        self.playIconView.snp.makeConstraints { (m) in
            m.center.equalTo(self.thumbView)
            m.width.height.equalTo(16)
        }
    }

    // MARK: - 数据

    /// 上一次配置的签名：布局阶段会反复调 `configure`，内容没变就不重复加载缩略图
    private var lastSignature: String = ""

    func configure(with preview: QuotePreview) {
        let signature = "\(preview.refLogId)|\(preview.name)|\(preview.content)|\(preview.media.exists)"
        guard signature != self.lastSignature else { return }
        self.lastSignature = signature
        self.currentRefLogId = preview.refLogId

        // 有缩略图时给文字让出右侧空间（同一条 `right` 约束，目标superview没变，可以 update）
        let trailing = -(QuoteBlockMetrics.horizontalPadding + preview.media.thumbWidth)
        self.nameLabel.snp.updateConstraints { (m) in
            m.right.equalToSuperview().offset(trailing)
        }

        // ⚠️ 这里**不切换 top 约束**：`contentLabel` 的 top 固定挂在 `nameLabel.bottom` 上，
        //    昵称为空时把内容改放到第一行（`nameLabel`）显示。
        //    原来用 `updateConstraints` 把 top 从「兄弟视图」改成「父视图」会触发 SnapKit 的
        //    「Updated constraint could not find existing matching constraint」直接闪退。
        if preview.name.isBlank {
            self.nameLabel.text = preview.content.isBlank ? "" : preview.content
            self.nameLabel.isHidden = self.nameLabel.text?.isEmpty ?? true
            self.contentLabel.text = nil
            self.contentLabel.isHidden = true
        } else {
            self.nameLabel.text = preview.name
            self.nameLabel.isHidden = false
            self.contentLabel.text = preview.content
            self.contentLabel.isHidden = preview.content.isBlank
        }

        self.applyMedia(preview.media)
    }

    /// 图片/视频/文件的缩略图
    private func applyMedia(_ media: QuoteMedia) {
        self.thumbView.kf.cancelDownloadTask()
        self.thumbView.image = nil
        self.thumbView.isHidden = !media.exists
        self.thumbView.contentMode = .scaleAspectFill
        self.thumbView.backgroundColor = UIColor.init(hexString: "#8A97A5", transparency: 0.12)
        self.playIconView.isHidden = true
        guard media.exists else { return }

        let token = self.currentRefLogId
        switch media {
        case .none:
            break
        case .photo(let cacheKey, let url):
            self.loadCachedThumb(cacheKey) { [weak self] image in
                guard let self = self, self.currentRefLogId == token else { return }
                if let image = image {
                    self.thumbView.image = image
                } else if let urlString = url, let url = URL(string: urlString) {
                    self.thumbView.kf.setImage(
                        with: url,
                        options: [
                            .processor(
                                DownsamplingImageProcessor(
                                    size: CGSize(width: 64, height: 64))),
                            .targetCache(ChatMediaCache)
                        ])
                }
            }
        case .video(let cacheKey):
            self.playIconView.isHidden = false
            self.loadCachedThumb(cacheKey) { [weak self] image in
                guard let self = self, self.currentRefLogId == token else { return }
                self.thumbView.image = image
            }
        case .file(let iconName):
            // 文件图标是透明底的小图，用 fit + 透明底，别被 scaleAspectFill 裁掉
            self.thumbView.contentMode = .scaleAspectFit
            self.thumbView.backgroundColor = .clear
            self.thumbView.image =
                UIImage.init(named: iconName ?? "") ?? UIImage.init(named: "chat_file_default")
        }
    }

    private func loadCachedThumb(_ key: String?, completion: @escaping (UIImage?) -> Void) {
        guard let key = key, !key.isBlank else {
            completion(nil)
            return
        }
        ChatMediaCache.safeRetrieveImage(forKey: key, maxPixelSize: 200) { image in
            completion(image)
        }
    }
}
