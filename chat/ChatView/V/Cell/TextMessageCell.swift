//
//  TextMessageCell.swift
//  chat
//
//  Created by fzm on 2020/12/25.
//

import UIKit
import Kingfisher

/// 正文为空（解密失败 / 对端发了空消息）时的占位文案。
/// 之前这种情况会画出一个**空气泡**（用户 2026-11-04 反馈），现在统一显示这句文案，
/// 并且**点一下气泡可以重新拉密钥解密**（见 `ChatVC.retryUnparsedMessage`）。
/// 尺寸计算（`TextMessageSizeCalculator`）也用它量宽度，保证气泡能装下。
let EmptyTextPlaceholder = L("该消息内容无法显示，点击重试")

class TextMessageCell: MessageContentCell {
    
    override weak var delegate: MessageCellDelegate? {
        didSet {
            messageLabel.delegate = delegate
        }
    }
    
    var messageLabel = MessageLabel.init()

    /// 语音 / 视频聊天邀请消息的卡片（图标 + 标题 + 副标题）。
    ///
    /// 邀请消息正文里那行房间链接在**展示层**被整条替换成这张卡片，正文不再显示。
    /// 点击不另开路径：卡片不拦触摸 ⇒ 点气泡走 `ChatVC.didTapMessage` → `.text` → `openUrl`
    /// → 第一个链接 → `VoiceRoomLauncher.open`（与旧版本点链接完全同一条路）。
    ///
    /// 尺寸常量全在 `VoiceRoomInvite`（`TextMessageSizeCalculator` 用同一组算气泡大小）。
    private let voiceCardView = VoiceInviteCardView.init()

    /// 分享链接卡片（AI 客服 / 商城等 H5 通过 `__tanxinHost.share` 发出来的消息）。
    /// 跟邀请卡片同一套做法：正文（标题 + 摘要 + 链接 + 来源）**整条不显示**，换成一张卡片，
    /// 链接不再露在气泡里；点击整张卡片仍走气泡点击（`ChatVC.didTapMessage` → 打开卡片里的链接）。
    private let shareCardView = ShareLinkCardView.init()

    /// 本条消息的房间链接（不是邀请消息时为 nil）
    private var inviteLink: URL?

    /// 本条消息的分享卡片（不是分享消息时为 nil）
    private var shareCard: ShareLinkCard?
    
    
    override func setupViews() {
        super.setupViews()
        self.messageContainerView.addSubview(messageLabel)
        self.messageLabel.numberOfLines = 0
        // 邀请卡片铺满气泡内容区（气泡 `clipsToBounds`，尺寸由 `TextMessageSizeCalculator` 给出）
        self.messageContainerView.addSubview(voiceCardView)
        voiceCardView.isHidden = true
        self.messageContainerView.addSubview(shareCardView)
        shareCardView.isHidden = true
    }
    
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.messageLabel.attributedText = nil
        self.messageLabel.text = nil
        self.messageLabel.isHidden = false
        self.inviteLink = nil
        self.voiceCardView.isHidden = true
        self.shareCard = nil
        self.shareCardView.isHidden = true
        self.shareCardView.reset()
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        guard let attributes = layoutAttributes as? MessageCollectionViewLayoutAttributes else { return }
        self.messageLabel.textInsets = attributes.messageLabelInsets
        self.messageLabel.messageLabelFont = attributes.messageLabelFont
        self.layoutContent()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // ⚠️ 正文的 frame 是按**气泡 bounds** 摆的，而 `apply`（摆气泡）和 `configure`（设文字）
        //    的先后顺序不固定（项目里已有注释承认这点）。一旦 `configure` 时气泡还是旧尺寸/零尺寸，
        //    正文就被摆成 0 大小；之后只要没有新的 `apply`，气泡里就一直是空白
        //    —— 表现为「偶发空气泡」，但气泡高度是对的（用户 2026-11-04 反馈）。
        //    这里每次布局都按当前气泡尺寸重摆一次：幂等、成本极低，能兜住任何顺序问题。
        self.layoutContent()
    }

    /// 摆内容：邀请 / 分享消息是整张卡片；其它消息还是普通正文铺满。
    private func layoutContent() {
        let bounds = self.messageContainerView.bounds
        // 气泡还没被 `apply` 摆过（零尺寸）时先不动，避免把正文摆成 0 大小；
        // 等 `layoutSubviews` / 下一次 `apply` 拿到真实尺寸再摆。
        guard bounds.width > 0, bounds.height > 0 else { return }
        let isInvite = (self.inviteLink != nil)
        let isShare = (self.shareCard != nil)
        // 卡片都是**白底卡片**：不再用气泡底图（蓝底和卡片里的蓝色图标太像、卡在中间很难看），
        // 由卡片视图自己画白底 + 圆角 + 细描边。
        // ⚠️ `super.configure` 每次都会根据代理重新设 style，所以这里覆盖是安全的。
        if isInvite || isShare {
            self.messageContainerView.style = .none
        }
        self.voiceCardView.isHidden = !isInvite
        self.shareCardView.isHidden = !isShare
        self.messageLabel.isHidden = isInvite || isShare
        self.messageLabel.frame = bounds
        if isInvite {
            self.voiceCardView.frame = bounds
        }
        if isShare {
            self.shareCardView.frame = bounds
        }

        // 【临时诊断】正文为空：重进会话时消息来自本地库，打出来能看到「存的时候是不是就已经是空的」
        if let msg = self.msg, case .text = msg.msgType, msg.msgType.textValue.isBlank,
            !isInvite, !isShare
        {
            FZMLog(
                "【空正文】msgId=\(msg.msgId) logId=\(msg.logId ?? -1) type=\(msg.msgType.rawValue.value) json=\(msg.msgType.rawValue.json.rawString() ?? "nil")"
            )
        }

        // 【临时诊断】正文是否被裁：对着气泡宽度和文字宽度比较
        if let text = self.msg?.msgType.textValue, !text.isBlank, !isInvite, !isShare,
            !self.messageLabel.isHidden
        {
            let font = self.messageLabel.font ?? UIFont.preferredFont(forTextStyle: .body)
            let needWidth =
                (text as NSString).size(withAttributes: [.font: font]).width + self.messageLabel.textInsets.horizontal
            FZMLog(
                "【正文】bubbleW=\(bounds.width) bubbleH=\(bounds.height) labelW=\(self.messageLabel.frame.width) insetsH=\(self.messageLabel.textInsets.horizontal) textW=\(needWidth) text=\(text.prefix(20))"
            )
        }
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        
        super.configure(with: message, at: indexPath, and: messageCollectionView)
        
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            FZMLog("TextMessageCell：messagesDisplayDelegate 为空，跳过配置")
            return
        }

        // 链接色按**收发**区分：自己发的气泡是浅蓝底，直接用主题色会看不清
        //（见 `MessageLabel.linkColor` 的对比度注释）。
        // ⚠️ 必须写在 `configure` **之前**：`underlineLinks` 是在文本/字体/颜色 setter 里跑的，
        //    那时就要读到这个值。
        messageLabel.linkColor = message.isOutgoing ? MessageLabel.outgoingLinkColor : Color_Theme

        // 每次 configure 先复位：非邀请 / 非分享消息不能残留上一条的卡片状态
        self.inviteLink = nil
        self.shareCard = nil

        messageLabel.configure {
            switch message.kind {
            case .text(let text):
                let textColor = displayDelegate.textColor(for: message, at: indexPath, in: messageCollectionView)
                // 正文为空（解密失败 / 对端发了空消息）：不给空白气泡，显示占位文案
                if text.isBlank {
                    messageLabel.text = EmptyTextPlaceholder
                    messageLabel.textColor = Color_8A97A5
                    // ⚠️ 字体必须和测量宽度时用的一致（`TextMessageSizeCalculator` 按
                    //    `attributes.messageLabelFont` 量）。漏设就会沿用 UILabel 默认的 17pt：
                    //    系统文字大小不是默认档时（`preferredFont(.body)` = 16/18…），
                    //    绘制比气泡量出来的宽度大一截 ⇒ 末尾「重试」被挤到第二行、被气泡裁掉
                    //    （用户 2026-11-09 反馈：只显示「该消息内容无法显示，点击」）。
                    if let font = messageLabel.messageLabelFont {
                        messageLabel.font = font
                    }
                    break
                }
                // 语音 / 视频邀请：正文（文案 + 房间链接）**整条不显示**，换成「图标 + 语音聊天 + 点击加入聊天 · 房间 …」卡片。
                // ⚠️ 消息正文本身不变（其它端和老版本仍靠正文里的链接进房），这里只是展示层替换。
                let link = VoiceRoomInvite.link(in: text)
                self.inviteLink = link
                // 分享链接（AI 客服 / 商城 H5）：正文「抬头 + 标题/摘要/链接/来源」**整条不显示**，
                // 换成「图标 + 标题 + 摘要 + 来源」卡片 —— 链接不再露在气泡里。
                // ⚠️ 同样不动消息正文（正文是唯一的数据源，历史消息 / 其它端都靠它）。
                let card: ShareLinkCard? = (link == nil) ? ShareLinkCard.parse(text) : nil
                // 卡片样式开关关闭时：不画卡片，把结构化内容还原成**之前的文本版式**
                // （历史 JSON 消息也能正常显示，不会露出原始 JSON）
                self.shareCard = FZM_EnableShareLinkCard ? card : nil
                if let link = link {
                    messageLabel.text = ""
                    voiceCardView.configure(link: link)
                } else if FZM_EnableShareLinkCard, let card = card {
                    messageLabel.text = ""
                    shareCardView.configure(card: card)
                } else if let card = card {
                    messageLabel.text = card.plainText
                } else {
                    messageLabel.text = text
                }
                messageLabel.textColor = textColor
                if let font = messageLabel.messageLabelFont {
                    messageLabel.font = font
                }
            case .attributedText(let text):
                messageLabel.attributedText = text
            case .notification:
                messageLabel.text = L("【通知消息】")
                messageLabel.textColor = Color_8A97A5
                if let font = messageLabel.messageLabelFont {
                    messageLabel.font = font
                }
            default:
                messageLabel.text = "[\(UnSupportedMsgType)]"
                messageLabel.textColor = Color_8A97A5
                if let font = messageLabel.messageLabelFont {
                    messageLabel.font = font
                }
                break
            }
        }

        // 复用 cell 时 `apply` 可能早于 `configure` 跑过 ⇒ 这里按当前尺寸再摆一次（幂等）
        self.layoutContent()
    }
    
    override func handleTapGesture(_ gesture: UIGestureRecognizer) {
        // 邀请卡片 / 分享卡片：整张卡片就是入口，直接交给气泡点击
        // （→ `ChatVC.didTapMessage` → 打开房间链接 / 分享里的链接）
        if self.inviteLink != nil || self.shareCard != nil {
            super.handleTapGesture(gesture)
            return
        }

        let touchLocation = gesture.location(in: self)
        let translateTouchLocation = convert(touchLocation, to: self.messageContainerView)

        guard self.messageLabel.frame.contains(translateTouchLocation),
              self.messageLabel.handleGesture(translateTouchLocation) else {
                  super.handleTapGesture(gesture)
                  return
              }
    }
}

// MARK: - 语音聊天邀请卡片

/// 邀请消息的卡片样式：
/// ```
/// ┌────────────────────────┐
/// │ [电话图标]  语音聊天      │
/// │             点击加入聊天  │
/// │             房间 h5_xxx  │
/// └───────────────────────┘
/// ```
/// 只负责画，不处理点击 —— 点卡片会冒泡成「点气泡」，由 `ChatVC.didTapMessage` 打开房间。
final class VoiceInviteCardView: UIView {

    private let iconContainer = UIView.init()
    private let iconView = UIImageView.init()
    private let titleLabel = UILabel.init()
    private let subtitleLabel = UILabel.init()
    private let roomLabel = UILabel.init()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 白底卡片：盖住气泡底色，和聊天背景区分开
        backgroundColor = .white
        layer.cornerRadius = VoiceRoomInvite.cardCornerRadius
        layer.masksToBounds = true
        layer.borderWidth = VoiceRoomInvite.cardBorderWidth
        layer.borderColor = Color_E6EAEE.cgColor
        isUserInteractionEnabled = false

        iconContainer.layer.cornerRadius = VoiceRoomInvite.cardIconCorner
        iconContainer.layer.masksToBounds = true
        iconContainer.backgroundColor = Color_Theme.withAlphaComponent(0.14)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Color_Theme
        iconContainer.addSubview(iconView)

        titleLabel.font = VoiceRoomInvite.cardTitleFont
        titleLabel.textColor = Color_24374E
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = VoiceRoomInvite.cardSubtitleFont
        subtitleLabel.textColor = Color_8A97A5
        subtitleLabel.lineBreakMode = .byTruncatingTail

        roomLabel.font = VoiceRoomInvite.cardRoomFont
        roomLabel.textColor = Color_8A97A5
        roomLabel.lineBreakMode = .byTruncatingMiddle

        addSubview(iconContainer)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(roomLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(link: URL) {
        let isVideo = VoiceRoomService.mode(of: link) == .video
        iconView.image = UIImage(systemName: isVideo ? "video.fill" : "phone.fill")
        titleLabel.text = VoiceRoomInvite.cardTitle(for: link)
        subtitleLabel.text = VoiceRoomInvite.cardSubtitle(for: link)
        roomLabel.text = VoiceRoomInvite.cardRoom(for: link)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let side = VoiceRoomInvite.cardIconSide
        let paddingH = VoiceRoomInvite.cardPaddingH
        iconContainer.frame = CGRect(x: paddingH,
                                     y: (bounds.height - side) / 2,
                                     width: side,
                                     height: side)
        // 图标本体缩进 22%，四周留呼吸空间
        let inset = (side * 0.22).rounded()
        iconView.frame = iconContainer.bounds.insetBy(dx: inset, dy: inset)

        let textLeft = iconContainer.frame.maxX + VoiceRoomInvite.cardIconGap
        let textWidth = max(0, bounds.width - textLeft - paddingH)
        let titleHeight = VoiceRoomInvite.cardTitleFont.lineHeight
        let subtitleHeight = VoiceRoomInvite.cardSubtitleFont.lineHeight
        let roomHeight = VoiceRoomInvite.cardRoomFont.lineHeight
        let spacing = VoiceRoomInvite.cardTitleSpacing
        let total = titleHeight + spacing + subtitleHeight + spacing + roomHeight
        let top = max(0, (bounds.height - total) / 2)

        titleLabel.frame = CGRect(x: textLeft, y: top, width: textWidth, height: titleHeight)
        subtitleLabel.frame = CGRect(x: textLeft,
                                     y: top + titleHeight + spacing,
                                     width: textWidth,
                                     height: subtitleHeight)
        roomLabel.frame = CGRect(x: textLeft,
                                 y: top + titleHeight + spacing + subtitleHeight + spacing,
                                 width: textWidth,
                                 height: roomHeight)
    }
}

// MARK: - 分享链接卡片（AI 客服 / 商城等 H5 分享）

/// AI 客服 / DApp（商城）分享出来的链接消息的**展示层**规格。
///
/// 无论**本端发的**还是**其他端发来的**，都只看消息正文能不能还原成这 5 个字段
/// （标题 / 内容 / 链接 / 头像 / 来源），不看是谁发的。支持三种正文形态：
///
/// 1. **卡片 JSON**（本端现在发这个，与 Android / Web 一致）：
///    `{"t":标题,"d":内容,"u":链接,"i":头像,"s":来源}`
///    （也接受全名 `title/description/url/iconUrl/source`，可再包一层 `card`）
/// 2. **Web 分享链接**：`{Web 分享域名}/web/?share=<base64url(JSON)>`
/// 3. **文本版式**（老消息 / 其它端的兑底格式）：
/// ```
/// 来自X的分享
/// 「标题
/// 摘要
/// https://…
/// 来源：xxx」
/// ```
///
/// 这里只负责还原 + 画卡片：气泡里不再出现那行链接，点整张卡片打开 `url`。
///
/// ⚠️ 文本版式的判定必须**足够严**，否则用户聊天的普通文本会被误判成卡片：
///    要么整体被 `「」` 包裹，要么首行是 `来自…的分享`；两种都得有一行**独占**的 http(s) 链接。
/// ⚠️ 尺寸常量必须与 `TextMessageSizeCalculator`（算高度）和 `ShareLinkCardView`（摆内容）**同源**。
struct ShareLinkCard {

    /// 抬头（`来自小Y的分享` / `来自BitYuan联邦商城的分享`），可能为空
    let header: String
    /// 标题
    let title: String
    /// 摘要（可能为空）
    let summary: String
    /// 链接（卡片点击打开的地址，**不在气泡里显示**）
    let url: String
    /// 「」里链接后面那一行（形如 `来源：xxx`），可能为空
    let footer: String
    /// 头像（只在结构化来源里有：卡片 JSON 的 `i` / Web 分享链接里编码的 `iconUrl`），可能为空
    let iconURL: String

    /// 卡片样式关闭时（`FZM_EnableShareLinkCard == false`）气泡里要显示的**文本版式**。
    /// 与 `TanxinSharePayload.contentText` 生成的完全一致：
    /// ```
    /// 来自X的分享
    /// 「标题
    /// 摘要
    /// https://…
    /// 来源：xxx」
    /// ```
    var plainText: String {
        var lines = ["「" + title]
        if !summary.isEmpty { lines.append(summary) }
        lines.append(url)
        if !footer.isEmpty { lines.append(footer) }
        // 最后一行补右引号，与 `contentText` 的 `「…」` 壳子保持一致
        if !lines.isEmpty { lines[lines.count - 1] += "」" }
        let body = lines.joined(separator: "\n")
        return header.isEmpty ? body : "\(header)\n\(body)"
    }

    // MARK: - 解析

    /// 从消息正文里还原卡片；不是分享消息返回 nil。
    ///
    /// **其他端发来的**和本端发出的都要能认，所以支持三种形态：
    /// 1. 文本版式（本端 / 同一套文案的端）：`来自X的分享` + `「标题 / 摘要 / 链接 / 来源」`
    /// 2. 卡片 JSON：`{"t":"标题","d":"内容","u":"链接","i":"头像","s":"来源"}`
    ///    （也接受全名 `title/description/url/iconUrl/source`，可再包一层 `card`）
    /// 3. 谈信 Web 的分享链接：`{Web 分享域名}/web/?share=<base64url(JSON)>`
    static func parse(_ text: String) -> ShareLinkCard? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // ② 卡片 JSON（结构化，带头像）
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return parseJSON(trimmed)
        }
        // ③ Web 分享链接（单行；也可能带一行分享抬头）
        if trimmed.contains("share=") {
            let lines = trimmed.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            if let last = lines.last, Self.isBareLink(last), let card = parseWebShareLink(last) {
                let header = (lines.count > 1 && Self.isHeaderLine(lines[0])) ? lines[0] : ""
                return ShareLinkCard(header: header, title: card.title, summary: card.summary,
                                     url: card.url, footer: card.footer, iconURL: card.iconURL)
            }
        }
        // ① 文本版式
        return parseTextBlock(trimmed)
    }

    // MARK: ① 文本版式

    private static func parseTextBlock(_ text: String) -> ShareLinkCard? {
        // 便宜挡板：绝大多数文本消息没有「」或分享抬头，别为它们做分割与逐行扫描
        guard text.range(of: "http", options: .caseInsensitive) != nil,
              text.contains("「") || text.contains("来自") else { return nil }

        var body = text
        var header = ""
        var hadWrapper = false
        // 最多剥三轮：`抬头 + 「…」` 和 `「抬头 + …」` 两种写法都认
        for _ in 0..<3 {
            if body.hasPrefix("「"), body.hasSuffix("」"), body.count > 2 {
                body = String(body.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                hadWrapper = true
                continue
            }
            var lines = body.components(separatedBy: "\n")
            guard let first = lines.first, isHeaderLine(first) else { break }
            if header.isEmpty { header = first.trimmingCharacters(in: .whitespaces) }
            lines.removeFirst()
            body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 既没有「」壳子、也没有分享抬头 ⇒ 当普通聊天文本，别误判成卡片
        guard hadWrapper || !header.isEmpty else { return nil }

        let bodyLines = body.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // 分享的链接由 `contentText` 追加在摘要之后、来源之前 ⇒ 取**最后一行**独占的链接。
        // （摘要里可能也有链接行，取第一行就会把卡片点开目标弄错。）
        guard let urlIndex = bodyLines.lastIndex(where: { Self.isBareLink($0) }), urlIndex > 0 else { return nil }
        let title = bodyLines[0]
        guard !title.isEmpty else { return nil }

        // 摘要里那种「整行就是一个链接」的行直接丢掉：卡片不展示链接
        let summary = bodyLines[1..<urlIndex]
            .filter { !$0.isEmpty && !Self.isBareLink($0) }
            .joined(separator: "\n")
        let footer = urlIndex + 1 < bodyLines.count
            ? bodyLines[(urlIndex + 1)...].filter { !$0.isEmpty }.joined(separator: "\n")
            : ""

        return ShareLinkCard(header: header, title: title, summary: summary,
                             url: bodyLines[urlIndex], footer: footer, iconURL: "")
    }

    /// 抬头行：`来自…的分享`
    private static func isHeaderLine(_ line: String) -> Bool {
        let text = line.trimmingCharacters(in: .whitespaces)
        return text.hasPrefix("来自") && text.hasSuffix("的分享")
    }

    /// 「干净」的链接行：整行就是一个 http(s) 地址（不带空格 / 引号 / 包裹符）
    private static func isBareLink(_ line: String) -> Bool {
        let lowered = line.lowercased()
        guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://") else { return false }
        guard !line.contains(" "), !line.contains("「"), !line.contains("」"), !line.contains("\"") else { return false }
        return URL(string: line) != nil
    }

    // MARK: ② 卡片 JSON

    private static func parseJSON(_ text: String) -> ShareLinkCard? {
        guard let data = text.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        // 允许 `{"card":{…}}` 这种再包一层
        let dict = (object["card"] as? [String: Any]) ?? object
        let title = value(dict, "t", "title")
        let url = value(dict, "u", "url")
        guard !title.isEmpty, !url.isEmpty else { return nil }
        return ShareLinkCard(header: "",
                             title: title,
                             summary: value(dict, "d", "description", "summary"),
                             url: url,
                             footer: value(dict, "s", "source"),
                             iconURL: value(dict, "i", "iconUrl", "icon"))
    }

    /// 按顺序取第一个非空字符串（短键在前、全名在后）
    private static func value(_ dict: [String: Any], _ keys: String...) -> String {
        for key in keys {
            if let string = dict[key] as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    // MARK: ③ 谈信 Web 的分享链接

    /// `{Web 分享域名}/web/?share=<base64url(JSON)>` —— JSON 就是上面那 5 个字段
    private static func parseWebShareLink(_ urlString: String) -> ShareLinkCard? {
        guard let components = URLComponents(string: urlString),
              let value = components.queryItems?.first(where: { $0.name == "share" })?.value,
              let json = decodeBase64URL(value) else { return nil }
        return parseJSON(json)
    }

    /// base64url → 字符串（补 `=`、`-`/`_` 还原成 `+`/`/`）
    private static func decodeBase64URL(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 卡片底部那行：优先「来源：xxx」，其次分享抬头，最后退到域名（**不显示完整链接**）
    var footerText: String {
        if !footer.isEmpty {
            // 文本版式里 `来源：` 就在这一行里；结构化来源只有值，这里补上前缀
            return footer.hasPrefix("来源") ? footer : "来源：\(footer)"
        }
        if !header.isEmpty { return header }
        guard let host = URL(string: url)?.host, !host.isEmpty else { return "" }
        return host
    }

    // MARK: - 卡片样式（2026-10-30：与语音邀请卡片同一套白底卡片形制）

    static let cardPaddingH: CGFloat = 12
    static let cardPaddingV: CGFloat = 10
    /// 左侧图标边长
    static let cardIconSide: CGFloat = 34
    static let cardIconCorner: CGFloat = 8
    /// 图标与右侧文字的间距
    static let cardIconGap: CGFloat = 10
    /// 标题 / 摘要 / 来源之间的行距
    static let cardLineSpacing: CGFloat = 2
    /// 卡片（= 气泡）最大宽度：链接卡片走满这个宽度，文字靠截断
    static let maxCardWidth: CGFloat = 250
    static let cardCornerRadius: CGFloat = 10
    static let cardBorderWidth: CGFloat = 0.5
    static let cardTitleMaxLines = 2
    static let cardSummaryMaxLines = 2

    static var cardTitleFont: UIFont { UIFont.systemFont(ofSize: 15, weight: .semibold) }
    static var cardSummaryFont: UIFont { UIFont.systemFont(ofSize: 13) }
    static var cardFooterFont: UIFont { UIFont.systemFont(ofSize: 11) }

    /// 卡片宽度（= 气泡宽度）：受气泡最大宽度与 `maxCardWidth` 双重限制
    static func cardWidth(maxWidth: CGFloat) -> CGFloat {
        let limit = (maxWidth > 0) ? min(maxWidth, maxCardWidth) : maxCardWidth
        return ceil(limit)
    }

    /// 文字区宽度（卡片宽度扣掉左右内边距 + 左侧图标）
    func textWidth(for width: CGFloat) -> CGFloat {
        return max(0, width - ShareLinkCard.cardPaddingH * 2
            - ShareLinkCard.cardIconSide - ShareLinkCard.cardIconGap)
    }

    /// 三段文字各自的高度（标题 / 摘要 / 来源），供算高与摆位共用
    func textHeights(width: CGFloat) -> (title: CGFloat, summary: CGFloat, footer: CGFloat) {
        let textWidth = self.textWidth(for: width)
        let titleHeight = ShareLinkCard.clampedHeight(title, font: ShareLinkCard.cardTitleFont,
                                                     width: textWidth,
                                                     maxLines: ShareLinkCard.cardTitleMaxLines)
        let summaryHeight = ShareLinkCard.clampedHeight(summary, font: ShareLinkCard.cardSummaryFont,
                                                       width: textWidth,
                                                       maxLines: ShareLinkCard.cardSummaryMaxLines)
        let footerHeight = footerText.isEmpty ? 0 : ceil(ShareLinkCard.cardFooterFont.lineHeight)
        return (titleHeight, summaryHeight, footerHeight)
    }

    /// 文字列总高度（比图标矮时以图标为准）
    func contentHeight(width: CGFloat) -> CGFloat {
        let heights = textHeights(width: width)
        var content = heights.title
        if heights.summary > 0 { content += ShareLinkCard.cardLineSpacing + heights.summary }
        if heights.footer > 0 { content += ShareLinkCard.cardLineSpacing + heights.footer }
        return max(ShareLinkCard.cardIconSide, content)
    }

    /// 卡片高度（= 气泡高度）
    func height(width: CGFloat) -> CGFloat {
        return ceil(contentHeight(width: width) + ShareLinkCard.cardPaddingV * 2)
    }

    /// 按行数上限截断后的文字高度（多行文本用 `boundingRect` 量，再夹到 `maxLines` 行）
    static func clampedHeight(_ text: String, font: UIFont, width: CGFloat, maxLines: Int) -> CGFloat {
        guard !text.isEmpty, width > 0, maxLines > 0 else { return 0 }
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil)
        return ceil(min(rect.height, font.lineHeight * CGFloat(maxLines)))
    }
}

/// 分享链接卡片的展示视图：
/// ```
/// ┌──────────────────────────────┐
/// │ [链接图标]  标题（最多 2 行）    │
/// │             摘要（最多 2 行）    │
/// │             来源：xxx           │
/// └──────────────────────────────┘
/// ```
/// 只负责画，不处理点击 —— 点卡片会冒泡成「点气泡」，由 `ChatVC.didTapMessage` 打开链接。
final class ShareLinkCardView: UIView {

    private let iconContainer = UIView.init()
    private let iconView = UIImageView.init()
    private let titleLabel = UILabel.init()
    private let summaryLabel = UILabel.init()
    private let footerLabel = UILabel.init()

    /// 当前展示的卡片（摆位时要用它的文字量与字体）
    private var card: ShareLinkCard?

    /// 是否加载到了**真实头像**（有头像时铺满图标框，不再缩进；没有时用主题色的链接图标）
    private var showsRealIcon = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 白底卡片：盖住气泡底色，和聊天背景区分开（与语音邀请卡片同款）
        backgroundColor = .white
        layer.cornerRadius = ShareLinkCard.cardCornerRadius
        layer.masksToBounds = true
        layer.borderWidth = ShareLinkCard.cardBorderWidth
        layer.borderColor = Color_E6EAEE.cgColor
        isUserInteractionEnabled = false

        iconContainer.layer.cornerRadius = ShareLinkCard.cardIconCorner
        iconContainer.layer.masksToBounds = true
        iconContainer.backgroundColor = Color_Theme.withAlphaComponent(0.14)

        iconView.image = UIImage(systemName: "link")
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Color_Theme
        iconContainer.addSubview(iconView)

        titleLabel.font = ShareLinkCard.cardTitleFont
        titleLabel.textColor = Color_24374E
        titleLabel.numberOfLines = ShareLinkCard.cardTitleMaxLines
        titleLabel.lineBreakMode = .byTruncatingTail

        summaryLabel.font = ShareLinkCard.cardSummaryFont
        summaryLabel.textColor = Color_8A97A5
        summaryLabel.numberOfLines = ShareLinkCard.cardSummaryMaxLines
        summaryLabel.lineBreakMode = .byTruncatingTail

        footerLabel.font = ShareLinkCard.cardFooterFont
        footerLabel.textColor = Color_8A97A5
        footerLabel.numberOfLines = 1
        footerLabel.lineBreakMode = .byTruncatingTail

        addSubview(iconContainer)
        addSubview(titleLabel)
        addSubview(summaryLabel)
        addSubview(footerLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(card: ShareLinkCard) {
        self.card = card
        titleLabel.text = card.title
        summaryLabel.text = card.summary
        summaryLabel.isHidden = card.summary.isEmpty
        footerLabel.text = card.footerText
        footerLabel.isHidden = card.footerText.isEmpty
        applyIcon(card.iconURL)
        setNeedsLayout()
    }

    /// 复用时清掉上一条的卡片状态与头像下载
    func reset() {
        card = nil
        showsRealIcon = false
        iconView.kf.cancelDownloadTask()
        iconView.image = UIImage(systemName: "link")
        iconView.contentMode = .scaleAspectFit
        titleLabel.text = nil
        summaryLabel.text = nil
        footerLabel.text = nil
        setNeedsLayout()
    }

    /// 左侧图标：有 `iconURL`（其他端的卡片 JSON / Web 分享链接里带 `i`）就加载真头像，
    /// 没有（文本版式里没有头像字段）就用主题色的通用链接图标。
    private func applyIcon(_ urlString: String) {
        iconView.kf.cancelDownloadTask()
        let lowered = urlString.lowercased()
        guard lowered.hasPrefix("http"),
              let url = URL(string: urlString), (url.host ?? "").isEmpty == false else {
            showsRealIcon = false
            iconView.contentMode = .scaleAspectFit
            iconView.image = UIImage(systemName: "link")
            return
        }
        showsRealIcon = true
        iconView.contentMode = .scaleAspectFill
        iconView.image = UIImage(systemName: "link")
        iconView.kf.setImage(with: url, placeholder: UIImage(systemName: "link"),
                             options: [.scaleFactor(UIScreen.main.scale), .backgroundDecode]) { [weak self] result in
            guard let self = self else { return }
            // 下载失败：退回通用图标（否则图标框里会是一张放大的占位图）
            if case .failure = result {
                self.showsRealIcon = false
                self.iconView.contentMode = .scaleAspectFit
                self.iconView.image = UIImage(systemName: "link")
                self.setNeedsLayout()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let card = self.card else { return }

        let side = ShareLinkCard.cardIconSide
        iconContainer.frame = CGRect(x: ShareLinkCard.cardPaddingH,
                                     y: (bounds.height - side) / 2,
                                     width: side,
                                     height: side)
        // 图标本体缩进 24%（有真头像时铺满），四周留呼吸空间
        let inset = showsRealIcon ? 0 : (side * 0.24).rounded()
        iconView.frame = iconContainer.bounds.insetBy(dx: inset, dy: inset)

        let textLeft = iconContainer.frame.maxX + ShareLinkCard.cardIconGap
        let textWidth = card.textWidth(for: bounds.width)
        let heights = card.textHeights(width: bounds.width)
        let content = card.contentHeight(width: bounds.width)
        var y = max(ShareLinkCard.cardPaddingV, (bounds.height - content) / 2).rounded()

        titleLabel.frame = CGRect(x: textLeft, y: y, width: textWidth, height: heights.title)
        y += heights.title

        if heights.summary > 0 {
            y += ShareLinkCard.cardLineSpacing
            summaryLabel.frame = CGRect(x: textLeft, y: y, width: textWidth, height: heights.summary)
            y += heights.summary
        } else {
            summaryLabel.frame = .zero
        }

        if heights.footer > 0 {
            y += ShareLinkCard.cardLineSpacing
            footerLabel.frame = CGRect(x: textLeft, y: y, width: textWidth, height: heights.footer)
        } else {
            footerLabel.frame = .zero
        }
    }
}

