//
//  SquarePostShareCard.swift
//  chat
//
//  广场帖子分享卡片：把一条帖子画成一张分享图
//  —— 顶部「谈信」品牌行（图标 + 名称 + 一句话介绍）/ 昵称（+ 身份标签）· 时间 / 正文 /
//     最多 3 张帖图 / 底部「来自「谈信」」+「扫码下载「谈信」」+ 下载二维码
//

import Foundation
import UIKit

/// 帖子分享图渲染器：纯离屏绘制，不依赖任何页面状态
enum SquarePostShareCard {

    /// 卡片宽度（pt）：与常见聊天窗口等宽，转发出去不会被压得太小
    static let cardWidth: CGFloat = 375
    /// 卡片左右 / 上下内边距
    private static let padding: CGFloat = 20
    /// 昵称行高度
    private static let nameRowHeight: CGFloat = 22
    /// 作者头像边长（圆形）
    private static let avatarSide: CGFloat = 36
    /// 头像与右侧昵称 / 时间的间距
    private static let avatarSpacing: CGFloat = 10
    /// 头像取不到时的占位图（与列表里一致）
    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")
    /// 正文最多渲染的行数（超长截断，避免分享图长得离谱）
    private static let maxContentLines = 10
    /// 正文行距
    private static let contentLineSpacing: CGFloat = 6
    /// 帖图圆角
    private static let imageCornerRadius: CGFloat = 8
    /// 多图之间的间距
    private static let imageSpacing: CGFloat = 6
    /// 垫底层的不透明度（压淡，不与上层完整图抢视线）
    private static let backdropAlpha: CGFloat = 0.35
    /// 底部二维码边长
    private static let qrSide: CGFloat = 72
    /// 顶部「谈信」品牌行：图标边长 / 与下方作者行的间距
    /// ⚠️ 品牌行两行文字（约 21 + 2 + 17）比图标（36）还高 4pt，实际空隙比这个值小，
    ///    所以这里比设计稿目测值再给大一些（用户 2026-10-12：跟作者头像太近不好看）
    private static let brandIconSide: CGFloat = 36
    private static let brandBottomSpacing: CGFloat = 30
    /// 品牌行的名称与一句话介绍（key）
    private static let brandTitle = "谈信"
    private static let brandSubtitle = "端到端加密 · 安全私密"

    /// 分享图里的下载地址：**一个链接同时兼容 iOS / 安卓**（用户指定，二维码就是它）
    static let downloadLink = ""

    // MARK: - 渲染

    /// 把帖子渲染成一张分享图
    /// - Parameters:
    ///   - avatar: 作者头像（已经裁好圆；取不到传 nil，会用默认头像占位）
    ///   - images: 已经下载好的帖子图片（最多取前 3 张；一张都没下下来时只画文字卡片）
    static func render(post: SquarePost, avatar: UIImage?, images: [UIImage]) -> UIImage {
        let card = makeCard(post: post, avatar: avatar, images: Array(images.prefix(3)))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: card.bounds.size, format: format).image { context in
            card.layer.render(in: context.cgContext)
        }
    }

    // MARK: - 卡片组装

    /// 逐块往下堆：头像 + 作者行 → 正文 → 帖图 → 底部下载区（整体高度算出来后再设给卡片）
    private static func makeCard(post: SquarePost, avatar: UIImage?, images: [UIImage]) -> UIView {
        let contentWidth = cardWidth - padding * 2
        let card = UIView(frame: CGRect(x: 0, y: 0, width: cardWidth, height: cardWidth))
        card.backgroundColor = Color_FFFFFF
        card.clipsToBounds = true

        var y = padding

        // 0) 顶部「谈信」品牌行：图标 + 名称 + 一句话介绍（2026-10-12 按设计稿加）
        //    图标直接用 `logo_120`（自带的蓝底圆角 + 白色谈信，圆角外是透明），不用再画圆角
        let brandIconView = UIImageView(image: #imageLiteral(resourceName: "logo_120"))
        brandIconView.contentMode = .scaleAspectFit
        brandIconView.frame = CGRect(x: padding, y: y, width: brandIconSide, height: brandIconSide)
        card.addSubview(brandIconView)

        let brandTextX = padding + brandIconSide + avatarSpacing
        let brandTextWidth = cardWidth - padding - brandTextX
        let brandTitleLab = makeLabel(font: .boldFont(17), color: Color_24374E)
        brandTitleLab.text = L(brandTitle)
        let brandSubLab = makeLabel(font: .regularFont(13), color: Color_8A97A5)
        brandSubLab.text = L(brandSubtitle)
        let brandTitleHeight = ceil(brandTitleLab.font.lineHeight)
        let brandSubHeight = ceil(brandSubLab.font.lineHeight)
        // 两行文字作为一组，在图标高度里垂直居中
        let brandTextTop = y + max((brandIconSide - (brandTitleHeight + 2 + brandSubHeight)) / 2, 0)
        brandTitleLab.frame = CGRect(x: brandTextX, y: brandTextTop, width: brandTextWidth, height: brandTitleHeight)
        brandSubLab.frame = CGRect(x: brandTextX, y: brandTitleLab.frame.maxY + 2, width: brandTextWidth, height: brandSubHeight)
        card.addSubview(brandTitleLab)
        card.addSubview(brandSubLab)

        y += brandIconSide + brandBottomSpacing

        // 1) 作者头像（服务端头像 / 按地址解析，取不到就用默认头像占位，保证排版一致）
        let avatarView = UIImageView(image: avatar ?? SquarePostShareCard.defaultAvatar)
        avatarView.contentMode = .scaleAspectFill
        avatarView.backgroundColor = Color_F6F7F8
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = avatarSide / 2
        // 作者行起点（上方品牌行占掉的高度已经加进 y）
        let authorRowTop = y
        avatarView.frame = CGRect(x: padding, y: authorRowTop, width: avatarSide, height: avatarSide)
        card.addSubview(avatarView)

        // 头像右边一列：昵称（+ 身份标签）与时间，纵向居中于头像
        let leading = padding + avatarSide + avatarSpacing
        let headerTextWidth = cardWidth - padding - leading
        let rowTop = authorRowTop + (avatarSide - nameRowHeight) / 2

        let timeText = timeString(of: post)
        let timeFont = UIFont.regularFont(12)
        let timeLab = makeLabel(font: timeFont, color: Color_8A97A5, alignment: .right)
        timeLab.text = timeText
        let timeSize = timeLab.sizeThatFits(CGSize(width: headerTextWidth, height: nameRowHeight))
        let timeWidth = timeText.isEmpty ? 0 : ceil(timeSize.width)
        timeLab.frame = CGRect(x: cardWidth - padding - timeWidth,
                               y: rowTop + (nameRowHeight - timeSize.height) / 2,
                               width: timeWidth,
                               height: ceil(timeSize.height))
        if timeWidth > 0 { card.addSubview(timeLab) }

        let tagText = post.identityTag(showsSelfTag: false)
        let tagFont = UIFont.regularFont(10)
        let tagWidth = tagText.isEmpty ? 0 : ceil((tagText as NSString).size(withAttributes: [.font: tagFont]).width) + 12

        var nameMaxWidth = headerTextWidth - (timeWidth > 0 ? timeWidth + 12 : 0)
        if tagWidth > 0 { nameMaxWidth -= (tagWidth + 6) }
        nameMaxWidth = max(nameMaxWidth, 40)

        let nameFont = UIFont.mediumFont(16)
        let nameLab = makeLabel(font: nameFont, color: Color_24374E)
        nameLab.text = post.displayName
        let nameSize = nameLab.sizeThatFits(CGSize(width: nameMaxWidth, height: nameRowHeight))
        let nameHeight = min(max(ceil(nameSize.height), ceil(nameFont.lineHeight)), nameRowHeight)
        nameLab.frame = CGRect(x: leading,
                               y: rowTop + (nameRowHeight - nameHeight) / 2,
                               width: min(ceil(nameSize.width), nameMaxWidth),
                               height: nameHeight)
        card.addSubview(nameLab)

        if tagWidth > 0 {
            let tagLab = makeLabel(font: tagFont, color: Color_FFFFFF, alignment: .center)
            tagLab.text = tagText
            // 「官方号」只给平台官方号（唯一）用金橙底；「我」/「公众号」保持蓝色
            tagLab.backgroundColor = post.isPlatformOfficial ? Color_Official_Tag : Color_Identity_Tag
            tagLab.layer.cornerRadius = 3
            tagLab.clipsToBounds = true
            tagLab.frame = CGRect(x: nameLab.frame.maxX + 6,
                                  y: rowTop + (nameRowHeight - 16) / 2,
                                  width: tagWidth,
                                  height: 16)
            card.addSubview(tagLab)
        }
        y = authorRowTop + avatarSide

        // 2) 正文：与 App 内**同一套渲染**（Markdown 排版：粗体 / 斜体 / 标题 / 列表 / 引用 / 代码块），
        //    只有图片标记先去掉（帖图统一画在正文下方）。
        //    用户 2026-10-08：「帖子里的字是加粗的，到了分享图里变成不加粗了，需要一致」——
        //    之前这里先把 markdown 标记去掉再当纯文本画，所以粗体丢了。
        let plain = SquareRichText.plainText(of: post.content)
        if !plain.isEmpty {
            y += 12
            // 字号比 App 内（15）大 1 号：卡片在聊天窗口里会被缩小显示
            let style = SquareRichText.Style(font: .regularFont(16), textColor: Color_24374E,
                                             accentColor: Color_Theme, lineSpacing: contentLineSpacing)
            let attributed = applyTruncatingTailToLastParagraph(SquareRichText.attributed(plain, style: style))

            let contentLab = UILabel()
            contentLab.numberOfLines = maxContentLines
            contentLab.lineBreakMode = .byTruncatingTail
            contentLab.attributedText = attributed
            // 万一行高算小了也不允许溢出、压到下面的帖图
            contentLab.clipsToBounds = true
            // 高度用 UILabel 自己量（富文本里有标题这种大字号行也能量准）
            let fitHeight = ceil(contentLab.sizeThatFits(CGSize(width: contentWidth,
                                                               height: CGFloat.greatestFiniteMagnitude)).height)
            let tallestLine = tallestLineHeight(in: attributed, fallback: style.font.lineHeight)
            let maxHeight = ceil((tallestLine + style.lineSpacing) * CGFloat(maxContentLines))
            let textHeight = max(min(fitHeight, maxHeight), ceil(style.font.lineHeight))

            contentLab.frame = CGRect(x: padding, y: y, width: contentWidth, height: textHeight)
            card.addSubview(contentLab)
            y += textHeight
        }

        // 3) 帖图（最多 3 张）：1 张按图片自身比例画大图，2~3 张按三列方格（格内完整显示，不裁切）
        if !images.isEmpty {
            y += 12
            let imageHeight = imageAreaHeight(images: images, contentWidth: contentWidth)
            let grid = makeImageGrid(images: images, contentWidth: contentWidth)
            grid.frame = CGRect(x: padding, y: y, width: contentWidth, height: imageHeight)
            card.addSubview(grid)
            y += imageHeight
        }

        // 4) 底部：分割线 + 左侧「来自「谈信」」+ 中间「扫码下载「谈信」」（主题色）+ 右侧二维码
        y += 18
        let divider = UIView(frame: CGRect(x: padding, y: y, width: contentWidth, height: 0.5))
        divider.backgroundColor = Color_E6EAEE
        card.addSubview(divider)
        y += 14

        // 二维码内容 = 下载地址（https 链接，安卓相机 / 任何扫码工具都能识别打开）
        let qr = QRCodeGenerator.setupQRCodeImage(SquarePostShareCard.downloadLink,
                                                  image: #imageLiteral(resourceName: "logo_120"))
        let qrView = UIImageView(image: qr)
        qrView.contentMode = .scaleAspectFit
        qrView.frame = CGRect(x: cardWidth - padding - qrSide, y: y, width: qrSide, height: qrSide)
        card.addSubview(qrView)

        // 左：灰色「来自「谈信」」（在二维码高度里垂直居中）
        let fromText = L("来自「谈信」")
        let fromFont = UIFont.regularFont(13)
        let fromLab = makeLabel(font: fromFont, color: Color_8A97A5)
        fromLab.text = fromText
        let fromWidth = ceil((fromText as NSString).size(withAttributes: [.font: fromFont]).width)
        let fromHeight = ceil(fromFont.lineHeight)
        fromLab.frame = CGRect(x: padding, y: y + (qrSide - fromHeight) / 2,
                               width: min(fromWidth, contentWidth), height: fromHeight)
        card.addSubview(fromLab)

        // 中：主题色「扫码下载「谈信」」，居中在「来自…」与二维码之间（空间不够就跟着左文字，宽度截断）
        let scanText = L("扫码下载「谈信」")
        let scanFont = UIFont.mediumFont(14)
        let scanLab = makeLabel(font: scanFont, color: Color_Theme)
        scanLab.text = scanText
        let scanWidth = ceil((scanText as NSString).size(withAttributes: [.font: scanFont]).width)
        let scanHeight = ceil(scanFont.lineHeight)
        let scanAreaLeft = fromLab.frame.maxX + 12
        let scanAreaRight = qrView.frame.minX - 12
        let scanX = max(scanAreaLeft, scanAreaLeft + ((scanAreaRight - scanAreaLeft) - scanWidth) / 2)
        scanLab.frame = CGRect(x: scanX, y: y + (qrSide - scanHeight) / 2,
                               width: min(scanWidth, max(scanAreaRight - scanX, 0)), height: scanHeight)
        card.addSubview(scanLab)

        y += qrSide
        y += padding

        card.frame = CGRect(x: 0, y: 0, width: cardWidth, height: ceil(y))
        return card
    }

    // MARK: - 小工具

    /// 帖图区高度：1 张 = **按图片自身比例**（比例限幅，不裁切）；2~3 张 = 一行方格（三列宽度）
    private static func imageAreaHeight(images: [UIImage], contentWidth: CGFloat) -> CGFloat {
        guard !images.isEmpty else { return 0 }
        if images.count == 1 { return singleImageHeight(for: images[0], contentWidth: contentWidth) }
        return ceil(imageCellSide(contentWidth: contentWidth))
    }

    /// 单图高度：按图片**真实宽高比**撑满卡片宽度（这样图能完整显示、不会上下留白）。
    /// 比例限制在 3:4（竖图最高）~ 16:9（横图最扁）之间：超出范围的极端图（超长截图 / 全景）
    /// 不把卡片拉得离谱，多出来的部分交给 `aspectFit` 留边 —— **图片本身依旧完整**。
    private static func singleImageHeight(for image: UIImage, contentWidth: CGFloat) -> CGFloat {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return ceil(contentWidth * 0.75) }
        let aspect = min(max(size.width / size.height, 3.0 / 4.0), 16.0 / 9.0)
        return ceil(contentWidth / aspect)
    }

    private static func imageCellSide(contentWidth: CGFloat) -> CGFloat {
        return (contentWidth - imageSpacing * 2) / 3
    }

    private static func makeImageGrid(images: [UIImage], contentWidth: CGFloat) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: contentWidth, height: 0))
        container.backgroundColor = .clear

        if images.count == 1 {
            let height = singleImageHeight(for: images[0], contentWidth: contentWidth)
            container.addSubview(makeImageBox(image: images[0],
                                              frame: CGRect(x: 0, y: 0, width: contentWidth, height: height)))
            return container
        }

        let side = ceil(imageCellSide(contentWidth: contentWidth))
        for (index, image) in images.enumerated() {
            let x = (side + imageSpacing) * CGFloat(index)
            container.addSubview(makeImageBox(image: image,
                                              frame: CGRect(x: x, y: 0, width: side, height: side)))
        }
        return container
    }

    /// 一格帖图 = 垫底（同一张图 `.scaleAspectFill`，压淡）+ 前景（`.scaleAspectFit` 完整显示）
    /// ⇒ **不再裁切图片**，方框里也不会留白。
    /// ⚠️ 广场**列表**的九宫格没有采用这套（用户 2026-10-09 要求列表回到原来的方形裁切样式），
    ///    这套只用于分享卡片，别拿它去改 `SquareImageGridView`。
    /// 用户 2026-10-08：「分享的时候图片会被裁剪、显示不了全部图片」。
    private static func makeImageBox(image: UIImage, frame: CGRect) -> UIView {
        let box = UIView(frame: frame)
        box.backgroundColor = Color_F6F7F8
        box.layer.cornerRadius = imageCornerRadius
        box.clipsToBounds = true

        let backdrop = UIImageView(image: image)
        backdrop.contentMode = .scaleAspectFill
        backdrop.clipsToBounds = true
        backdrop.alpha = backdropAlpha
        backdrop.frame = box.bounds
        box.addSubview(backdrop)

        let imageView = UIImageView(image: image)
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.frame = box.bounds
        box.addSubview(imageView)
        return box
    }

    /// 富文本里出现过的最大行高（标题 18/20 号比正文高，「最多 10 行」的上限要按它算）
    private static func tallestLineHeight(in attributed: NSAttributedString, fallback: CGFloat) -> CGFloat {
        var tallest = fallback
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length), options: []) { value, _, _ in
            if let font = value as? UIFont { tallest = max(tallest, font.lineHeight) }
        }
        return tallest
    }

    /// 让**最后一个段落**以「…」收尾。
    /// `SquareRichText.attributed` 给的是 `.byWordWrapping`（App 内靠「查看更多」收尾，不需要省略号），
    /// 但分享图靠「最多 10 行 + label 高度」截断，不改的话末行会被硬切、看不出是截断。
    private static func applyTruncatingTailToLastParagraph(_ attributed: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributed)
        let length = result.length
        guard length > 0 else { return result }
        var lastRange: NSRange?
        var lastStyle: NSMutableParagraphStyle?
        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            if let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
                lastRange = range
                lastStyle = style
            }
        }
        guard let range = lastRange, let style = lastStyle else { return result }
        style.lineBreakMode = .byTruncatingTail
        result.addAttribute(.paragraphStyle, value: style, range: range)
        return result
    }

    private static func makeLabel(font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) -> UILabel {
        let lab = UILabel()
        lab.font = font
        lab.textColor = color
        lab.textAlignment = alignment
        lab.numberOfLines = 1
        lab.lineBreakMode = .byTruncatingTail
        lab.backgroundColor = .clear
        return lab
    }

    private static func timeString(of post: SquarePost) -> String {
        let text = SquareDateParser.displayText(from: post.createdDate)
        return text.isEmpty ? post.createdAt : text
    }
}
