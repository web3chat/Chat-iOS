//
//  SquareRichText.swift
//  chat
//
//  广场正文富文本（列表 / 详情页共用）：
//  · 支持 Markdown 子集：# 标题、**粗体**、*斜体*、`行内代码`、``` 代码块、- / 1. 列表、> 引用、[文字](链接)
//  · 自动识别 http(s) 链接、@提及、#话题（单个 # 前缀）
//  · 保留原始排版：换行、空行、emoji
//  · @提及 / #话题 / 链接 / 「查看更多」都写成一个自定义属性的 URL，
//    点击命中由 `tap(at:in:)` 自己算（不依赖系统链接交互，各系统版本行为一致；
//    同时把文本视图设成 isSelectable，长按仍可选中复制）
//

import Foundation
import UIKit

/// 正文里被点到的元素
enum SquareRichTap {
    /// http(s) 链接
    case url(URL)
    /// @提及（昵称）
    case mention(String)
    /// #话题（话题名，不含 #）
    case topic(String)
    /// 「查看更多」
    case more
}

/// 正文块（图文混排：文字块与内联图片块按出现顺序排列）
enum SquareRichBlock {
    /// 一段文字（已渲染成富文本）
    case text(NSAttributedString)
    /// 一张内联图片（aspect = 宽 / 高，缺省 4:3）
    case image(url: String, aspect: CGFloat)
}

enum SquareRichText {

    // MARK: - 样式

    struct Style {
        var font: UIFont
        var textColor: UIColor
        var accentColor: UIColor
        var lineSpacing: CGFloat
        /// 链接是否加下划线（帖子正文保持原样 false；评论按需求「蓝 + 下划线」用 true）
        var linkUnderline: Bool = false

        /// 帖子正文（列表与详情页一致）
        static let post = Style(font: .regularFont(15), textColor: Color_24374E,
                                accentColor: Color_Theme, lineSpacing: 5)
        /// 评论内容（字号小一档）
        static let comment = Style(font: .regularFont(13), textColor: Color_24374E,
                                   accentColor: Color_Theme, lineSpacing: 3)
    }

    /// 列表里正文最多显示的字符数（超出截断成「… 查看更多」）
    static let listCharacterLimit = 100

    // MARK: - 内联图片（图文混排）

    /// 内联图片标记：`![](url)`、`![说明](url "1.3333")`（title 里存宽高比）
    static let inlineImageRegex = try? NSRegularExpression(
        pattern: "!\\[[^\\]\\n]*\\]\\(\\s*([^)\\s]+)(?:\\s+\"([^\"]*)\")?\\s*\\)",
        options: [])

    /// 图片宽高比缺省值（4:3）
    static let defaultImageAspect: CGFloat = 4.0 / 3.0

    /// 生成内联图片标记（发帖提交时把附件替换成它）
    static func imageMarkdown(url: String, aspect: CGFloat) -> String {
        let safeAspect = (aspect > 0.2 && aspect < 5) ? aspect : defaultImageAspect
        return "![](\(url) \"\(String(format: "%.4f", safeAspect))\")"
    }

    /// 正文里所有内联图片的地址（按出现顺序）
    static func inlineImageURLs(in content: String) -> [String] {
        guard let regex = inlineImageRegex else { return [] }
        let ns = content as NSString
        return regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length)).compactMap {
            let range = $0.range(at: 1)
            return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
    }

    /// 去掉图片标记后的正文（列表预览用）
    static func plainText(of content: String) -> String {
        guard let regex = inlineImageRegex else { return content }
        let ns = content as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        // 图片标记独占一行时删掉后会留下多余空行，折叠一下
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 去掉 Markdown 标记的纯文本（「只能画纯文字」的地方用）：
    /// 标题 `#`、列表符号、引用符号、代码围栏、`**`/`*`/`_`/`` ` `` 全去掉，链接只留文字。
    /// ⚠️ 只对 `contentFormat == markdown` 的帖用：纯文本帖里可能真的写着 `*`，硬去会把正文改掉。
    /// 📌 **当前没有调用方**（保留备用）：列表正文与分享卡片现在都直接走 `attributed` / `blocks` 渲染 markdown，
    ///    去标记反而会把粗体、标题这些排版丢掉（用户 2026-10-08 报过「分享图里粗体没了」）。
    static func plainTextWithoutMarkup(_ content: String) -> String {
        var lines = [String]()
        var inCodeBlock = false
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalized.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                continue
            }
            if inCodeBlock {
                lines.append(rawLine)
                continue
            }
            var line = trimmed
            for prefix in ["### ", "## ", "# "] where line.hasPrefix(prefix) {
                line = String(line.dropFirst(prefix.count))
                break
            }
            if line == ">" {
                line = ""
            } else if line.hasPrefix("> ") {
                line = String(line.dropFirst(2))
            } else if let item = unorderedItem(line) {
                line = item
            } else if let item = orderedItem(line) {
                line = item.0 + ". " + item.1
            }
            lines.append(stripInlineMarkup(line))
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 去掉内联标记（粗体 / 斜体 / 行内代码 / 链接），保留裸链接、`@提及`、`#话题`
    private static func stripInlineMarkup(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let regex = inlineRegex else { return text }
        let ns = text as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            guard match.range.location >= cursor else { continue }
            if match.range.location > cursor {
                result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            }
            let raw = ns.substring(with: match.range)
            if match.range(at: 1).location != NSNotFound {
                // [文字](链接) → 文字
                if let open = raw.firstIndex(of: "["), let close = raw.firstIndex(of: "]"), open < close {
                    result += String(raw[raw.index(after: open)..<close])
                } else {
                    result += raw
                }
            } else if match.range(at: 2).location != NSNotFound {
                result += raw.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            } else if match.range(at: 3).location != NSNotFound {
                result += raw.count > 4 ? String(raw.dropFirst(2).dropLast(2)) : raw
            } else if match.range(at: 4).location != NSNotFound || match.range(at: 5).location != NSNotFound {
                result += raw.count > 2 ? String(raw.dropFirst().dropLast()) : raw
            } else {
                result += raw
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            result += ns.substring(from: cursor)
        }
        return result
    }

    /// 拆成图文块（详情页图文混排用）：文字块与内联图片块按顺序
    static func blocks(of content: String, style: Style = .post) -> [SquareRichBlock] {
        guard let regex = inlineImageRegex else {
            let text = attributed(content, style: style)
            return text.length > 0 ? [.text(text)] : []
        }
        let ns = content as NSString
        var blocks = [SquareRichBlock]()
        var cursor = 0

        for match in regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) {
            let urlRange = match.range(at: 1)
            let url = urlRange.location == NSNotFound ? "" : ns.substring(with: urlRange)
            appendTextBlock(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)),
                            style: style, to: &blocks)
            if !url.isEmpty {
                var aspect = defaultImageAspect
                let aspectRange = match.range(at: 2)
                if aspectRange.location != NSNotFound,
                   let value = Double(ns.substring(with: aspectRange)), value > 0.2, value < 5 {
                    aspect = CGFloat(value)
                }
                blocks.append(.image(url: url, aspect: aspect))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            appendTextBlock(ns.substring(from: cursor), style: style, to: &blocks)
        }
        return blocks
    }

    /// 文字块：去掉首尾空白，空的不加
    private static func appendTextBlock(_ raw: String, style: Style, to blocks: inout [SquareRichBlock]) {
        let text = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r\t "))
        guard !text.isEmpty else { return }
        let attributed = attributed(text, style: style)
        guard attributed.length > 0 else { return }
        blocks.append(.text(attributed))
    }

    // MARK: - 可点标记
    //
    // 所有可点内容都存成一个 URL 塞在自定义属性里：
    // http 链接存原 URL；@ / # / 查看更多 用自定义 scheme（值放 query，避免 host 被规范化成小写）

    /// 命中可点内容用的属性（**故意不用 .link**：.link 会触发系统链接交互，行为在各系统上不一致）
    static let tapAttributeKey = NSAttributedString.Key("chat.squareRichTap")
    private static let tapScheme = "square-tap"

    private static func tapURL(kind: String, value: String = "") -> URL? {
        var comps = URLComponents()
        comps.scheme = tapScheme
        comps.host = "go"
        comps.queryItems = [URLQueryItem(name: "kind", value: kind),
                            URLQueryItem(name: "value", value: value)]
        return comps.url
    }

    /// 把命中的 URL 还原成具体动作
    static func tap(from url: URL) -> SquareRichTap? {
        guard url.scheme == tapScheme,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return (url.scheme == "http" || url.scheme == "https") ? .url(url) : nil
        }
        let kind = items.first { $0.name == "kind" }?.value ?? ""
        let value = items.first { $0.name == "value" }?.value ?? ""
        switch kind {
        case "mention":
            return value.isEmpty ? nil : .mention(value)
        case "topic":
            return value.isEmpty ? nil : .topic(value)
        case "more":
            return .more
        default:
            return nil
        }
    }

    // MARK: - 渲染

    /// 正文 → 富文本
    static func attributed(_ text: String, style: Style = .post) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var appendedAny = false
        func append(_ block: NSAttributedString) {
            if appendedAny {
                // 段落之间用换行分隔（空行本身也是一个段落 → 原样保留）
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(block)
            appendedAny = true
        }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var codeBuffer = [String]()
        var inCodeBlock = false

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // 代码块围栏：``` 之间的内容按原样等宽展示
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    append(codeBlock(codeBuffer, style: style))
                    codeBuffer = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeBuffer.append(rawLine)
                continue
            }

            if trimmed.isEmpty {
                // 空行：给一个空格，保证这一行有正常行高（纯空段落的高度不可靠）
                append(NSAttributedString(string: " ", attributes: bodyAttributes(font: style.font, color: style.textColor, style: style)))
                continue
            }

            append(paragraph(trimmed, style: style))
        }

        // 代码块没有闭合也要显示出来
        if inCodeBlock, !codeBuffer.isEmpty {
            append(codeBlock(codeBuffer, style: style))
        }

        return result
    }

    /// 评论内容：**按纯文本展示，只把 http(s) 链接**标成可点（蓝 + 下划线）。
    ///
    /// 故意不复用 `attributed(_:style:)`：那是 Markdown 渲染器，用在评论上会把评论里的
    /// `#` / `*` / `-` / `@` 当成标题、列表、粗体、提及 —— 评论不是 Markdown 文档，
    /// 用户（2026-10-12）只要求「带 http 链接时链接变蓝加下划线」。
    static func linkOnlyAttributed(_ text: String, style: Style) -> NSAttributedString {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.isEmpty else { return NSAttributedString(string: "") }

        let base = bodyAttributes(font: style.font, color: style.textColor, style: style)
        let result = NSMutableAttributedString(string: normalized, attributes: base)
        guard let regex = bareLinkRegex else { return result }

        let ns = normalized as NSString
        for match in regex.matches(in: normalized, options: [], range: NSRange(location: 0, length: ns.length)) {
            let split = splitLinkText(ns.substring(with: match.range))
            guard !split.link.isEmpty, let url = URL(string: split.link) else { continue }
            var attributes: [NSAttributedString.Key: Any] = [tapAttributeKey: url]
            applyLinkStyle(to: &attributes, style: style)
            result.addAttributes(attributes,
                                 range: NSRange(location: match.range.location,
                                                length: (split.link as NSString).length))
        }
        return result
    }

    /// 截断 + 「…」+「查看更多」（列表 100 字用；「查看更多」比正文小 2 号）
    static func collapsed(_ attributed: NSAttributedString, limit: Int, style: Style = .post) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let length = attributed.length
        guard length > limit else { return attributed }

        var cut = limit
        // 不要切在代理对（emoji）中间
        let text = attributed.string as NSString
        if cut < length, cut > 0, text.rangeOfComposedCharacterSequence(at: cut).location < cut {
            cut = text.rangeOfComposedCharacterSequence(at: cut).location
        }
        result.append(attributed.attributedSubstring(from: NSRange(location: 0, length: cut)))
        // 截断处补一个省略号（用户 2026-09-24）：紧跟第 limit 个字，用**正文样式**（不是蓝色），
        // 后面才是蓝色的「查看更多」
        result.append(NSAttributedString(string: "…", attributes: bodyAttributes(font: style.font, color: style.textColor, style: style)))

        var moreAttributes: [NSAttributedString.Key: Any] = [
            // 「查看更多」比正文小 2 号（正文 15 → 13）
            .font: UIFont.regularFont(max(style.font.pointSize - 2, 10)),
            .foregroundColor: style.accentColor,
        ]
        if let url = tapURL(kind: "more") {
            moreAttributes[tapAttributeKey] = url
        }
        // 用户 2026-09-24：去掉「查看更多」后面的小箭头（原来跟一个 SF Symbol 的 chevron.right）
        result.append(NSAttributedString(string: " " + L("查看更多"), attributes: moreAttributes))
        return result
    }

    // MARK: - 列表预览（与详情页同一套渲染，只做截断）

    /// 列表预览的正文块：**与详情页完全同一套渲染**（Markdown 排版 + 内联图片按原位置），
    /// 但文字累计到 `limit` 字后截断并接「… 查看更多」，**其后的块（含后面的图片）全部丢弃**。
    /// 用户 2026-10-08：广场列表的正文要与帖子详情页一致，纯文本 / Markdown 文档 / 图文混排各种形态都要一致。
    /// ⚠️ 与 `collapsed(_:limit:)` 的区别：那个只处理「一段纯文本」，而列表现在直接渲染 markdown，
    ///    在纯文本上截断容易切在语法中间（把 `**` 之类露出来）；这个在**块**层面截断，每个文字块都已渲染好。
    /// - Parameter limit: 文字字符数上限（图片不占字数：截断点之前的图片照常显示）
    static func collapsedBlocks(of content: String, limit: Int, style: Style = .post) -> [SquareRichBlock] {
        var result = [SquareRichBlock]()
        var used = 0
        for block in blocks(of: content, style: style) {
            switch block {
            case .image:
                // 图片不占字数；还没到截断点就照常显示（顺序与详情页一致）
                result.append(block)
            case .text(let attributed):
                let length = attributed.length
                if used + length <= limit {
                    used += length
                    result.append(block)
                } else {
                    // 截在第一个放不下的文字块上，后面的块（文字 / 图片）一律不再显示
                    result.append(.text(collapsed(attributed, limit: max(limit - used, 0), style: style)))
                    return result
                }
            }
        }
        return result
    }

    // MARK: - 高度

    /// 离屏测量用的文本视图（配置与 cell 里的完全一致，保证高度一致）
    private static let measuringTextView: UITextView = {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
    }()

    /// 富文本在指定宽度下需要的高度
    static func height(for attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        guard width > 0, attributed.length > 0 else { return 0 }
        measuringTextView.attributedText = attributed
        let size = measuringTextView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return ceil(size.height)
    }

    // MARK: - 点击命中

    /// 点在文本视图的哪个可点元素上（自己算，不依赖系统链接交互）
    static func tap(at point: CGPoint, in textView: UITextView) -> SquareRichTap? {
        // 用 UITextInput 的命中测试（iOS 16 起 UITextView 默认 TextKit 2，
        // 直接访问 layoutManager 会触发回退到 TextKit 1）
        guard let range = textView.characterRange(at: point) else { return nil }
        let index = textView.offset(from: textView.beginningOfDocument, to: range.start)
        guard index >= 0, index < textView.attributedText.length else { return nil }
        guard let url = textView.attributedText.attribute(tapAttributeKey, at: index, effectiveRange: nil) as? URL else {
            return nil
        }
        return tap(from: url)
    }

    /// 点在 **`UILabel`** 上的哪个可点元素上。
    ///
    /// 评论 cell 为了保持原有排版用的是 `UILabel`（不是 `UITextView`），这里用离屏 `NSLayoutManager`
    /// 按标签尺寸还原一次排版再取字符索引；点在文字范围外的空白处一律不算命中。
    static func tap(at point: CGPoint, inLabel label: UILabel) -> SquareRichTap? {
        guard let attributed = label.attributedText, attributed.length > 0 else { return nil }
        let size = label.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }

        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: size)
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = label.numberOfLines
        // UILabel 默认 lineBreakMode 是「截尾」；不限行数时按自动换行排版才与标签实际渲染一致
        container.lineBreakMode = label.numberOfLines == 0 ? .byWordWrapping : label.lineBreakMode
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)

        // UILabel 在垂直方向居中：先扣掉上下多出来的空白，避免点空白处命中最下面一行
        let used = layoutManager.usedRect(for: container)
        var p = point
        p.y -= max((size.height - used.height) / 2, 0)
        guard used.insetBy(dx: -1, dy: -1).contains(p) else { return nil }

        let index = layoutManager.characterIndex(for: p, in: container,
                                                fractionOfDistanceBetweenInsertionPoints: nil)
        guard index < attributed.length else { return nil }
        guard let url = attributed.attribute(tapAttributeKey, at: index, effectiveRange: nil) as? URL else {
            return nil
        }
        return tap(from: url)
    }

    // MARK: - @提及 → 地址

    /// 按昵称（或短地址）在本地通讯录里找地址，用于点 @提及 跳作者页；找不到返回 nil
    static func address(ofMention name: String) -> String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        // 自己
        let me = LoginUser.shared()
        if let mine = me.nickName?.value, mine == name, !me.address.isEmpty {
            return me.address
        }

        var users = UserManager.shared().users
        users.append(contentsOf: UserManager.shared().loadDBFriends())
        if let user = users.first(where: { ($0.nickname ?? "") == name }) {
            return user.address
        }
        // 名字本身就是地址（或短地址）的情况
        if let user = users.first(where: { $0.address == name || $0.address.shortAddress == name }) {
            return user.address
        }
        // 昵称为空时展示名就是短地址，允许直接用短地址匹配
        if let user = users.first(where: { ($0.nickname ?? "").isEmpty && $0.address.shortAddress == name }) {
            return user.address
        }
        return nil
    }

    // MARK: - 私有：块级

    /// 一个段落（含块级前缀与内联样式）
    private static func paragraph(_ line: String, style: Style) -> NSAttributedString {
        var body = line
        var prefix = ""
        var font = style.font
        var color = style.textColor
        var headIndent: CGFloat = 0
        var paragraphSpacing: CGFloat = 0

        if line.hasPrefix("### ") {
            body = String(line.dropFirst(4))
            font = .boldFont(16)
        } else if line.hasPrefix("## ") {
            body = String(line.dropFirst(3))
            font = .boldFont(18)
            paragraphSpacing = 4
        } else if line.hasPrefix("# ") {
            body = String(line.dropFirst(2))
            font = .boldFont(20)
            paragraphSpacing = 6
        } else if line == ">" || line.hasPrefix("> ") {
            body = line == ">" ? "" : String(line.dropFirst(2))
            color = Color_8A97A5
            prefix = "▏"
            headIndent = 0
            paragraphSpacing = 2
        } else if let item = unorderedItem(line) {
            body = item
            prefix = "•"
            headIndent = 16
        } else if let item = orderedItem(line) {
            body = item.1
            prefix = item.0 + "."
            headIndent = 16
        }

        let base = bodyAttributes(font: font, color: color, style: style,
                                 headIndent: headIndent,
                                 paragraphSpacing: paragraphSpacing)
        let paragraph = NSMutableAttributedString()
        if !prefix.isEmpty {
            paragraph.append(NSAttributedString(string: prefix + "  ", attributes: base))
        }
        paragraph.append(inline(body, style: style, font: font, color: color, base: base))
        return paragraph
    }

    /// `- xxx` / `* xxx` / `+ xxx`
    private static func unorderedItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    /// `1. xxx`
    private static func orderedItem(_ line: String) -> (String, String)? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let number = String(line[line.startIndex..<dot])
        guard !number.isEmpty, number.count <= 3, number.allSatisfy({ $0.isNumber }) else { return nil }
        let rest = String(line[line.index(after: dot)...])
        guard rest.hasPrefix(" ") else { return nil }
        return (number, String(rest.dropFirst(1)))
    }

    /// 代码块（``` 之间的内容按原样展示）
    private static func codeBlock(_ lines: [String], style: Style) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: max(style.font.pointSize - 2, 11), weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.headIndent = 10
        paragraphStyle.firstLineHeadIndent = 10
        paragraphStyle.paragraphSpacing = 2
        paragraphStyle.minimumLineHeight = font.lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Color_24374E,
            .backgroundColor: Color_F6F7F8,
            .paragraphStyle: paragraphStyle,
        ]
        return NSAttributedString(string: lines.joined(separator: "\n"), attributes: attributes)
    }

    // MARK: - 私有：内联

    /// 正文基础属性（含段落样式）
    private static func bodyAttributes(font: UIFont, color: UIColor, style: Style,
                                       headIndent: CGFloat = 0,
                                       paragraphSpacing: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = style.lineSpacing
        paragraphStyle.headIndent = headIndent
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping
        // 空段落（空行）也要有正常行高
        paragraphStyle.minimumLineHeight = font.lineHeight
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraphStyle]
    }

    /// 裸链接里**不允许**出现的字符（正则字符类的内容）：空白、尖括号，以及
    /// 中文 / 全角标点 / 通用标点 —— 否则 `（https://a.com）` 会把 `）` 一起吞进链接，跳转必然失败
    /// （用户 2026-09-24 报「链接后面多了个）」）。
    /// ⚠️ ICU 只认 `\uXXXX` 写法（写成 `\u{XXXX}` 会**静默**编译失败）。
    private static let bareLinkStopClass =
        "\\s<>"
        + "\\u2000-\\u206F"   // 通用标点：– — ‘ ’ “ ” … † ‡ •
        + "\\u2E80-\\u2EFF"   // CJK 部首补充
        + "\\u3000-\\u303F"   // CJK 标点：。，、；：！？「」『』【】
        + "\\u3400-\\u4DBF"   // CJK 扩展 A
        + "\\u4E00-\\u9FFF"   // CJK 基本区
        + "\\uF900-\\uFAFF"   // CJK 兼容表意文字
        + "\\uFE30-\\uFE4F"   // CJK 兼容形式（竖排标点）
        + "\\uFF00-\\uFFEF"   // 全角形式：（）｛｝［］！？：；，。等

    /// 单 `#` 话题（币安广场式 `#话题`）里**不允许**出现的字符（正则字符类的内容）：
    /// 空白、另一个 `#`，以及各类标点（ASCII / 中文 / 全角 / 通用标点）。
    /// ⇒ `#比特币，今天涨了` 只会把 `#比特币` 当话题，不会把后面整句都吞进去。
    /// ⚠️ 与 `bareLinkStopClass` 的关键区别：**汉字必须允许**（话题名基本都是汉字 / 字母 / 数字）。
    private static let topicStopClass =
        "\\s#"                // 空白（含全角空格）+ 另一个 #
        + "\\u0021-\\u002F"   // ! " # $ % & ' ( ) * + , - . /
        + "\\u003A-\\u0040"   // : ; < = > ? @
        + "\\u005B-\\u005E"   // [ \ ] ^（`_` 保留：`#crypto_market` 这种要算话题）
        + "\\u0060"           // `
        + "\\u007B-\\u007E"   // { | } ~
        + "\\u2000-\\u206F"   // 通用标点：– — ‘ ’ “ ” … † ‡ •
        + "\\u2E80-\\u2EFF"   // CJK 部首补充
        + "\\u3000-\\u303F"   // CJK 标点：。，、；：！？「」『』【】
        + "\\uFE10-\\uFE1F"   // 竖排标点
        + "\\uFE30-\\uFE4F"   // CJK 兼容形式
        + "\\uFF01-\\uFF0F"   // 全角：！＂＃＄％＆＇（）＊＋，－．／
        + "\\uFF1A-\\uFF20"   // 全角：：；＜＝＞？＠
        + "\\uFF3B-\\uFF40"   // 全角：［＼］＾＿｀
        + "\\uFF5B-\\uFF65"   // 全角：｛｜｝～｡｢｣､･

    /// 链接末尾常被一起吞掉的收尾标点（句读 / 引号 / 全角括号等）——都不属于链接本身
    private static let linkTrailingPunctuation = Set("。，、；：！？…—～·,.!?;:'\"”’》〉」』】〕｝］）＞")

    /// 成对包裹符：ASCII 的 `)` `]` `}` 只有「闭括号比开括号多」时才当作正文里的括号摘掉
    private static let linkPairedClosers: [Character: Character] = [")": "(", "]": "[", "}": "{"]

    /// 把链接末尾多出来的标点摘出来，返回（链接文字, 后面的普通文字）：
    /// `https://a.com）。` → `("https://a.com", "）。")`；
    /// `https://en.wikipedia.org/wiki/A_(b))` → `("…/A_(b)", ")")`（**配对括号要留着**）
    static func splitLinkText(_ raw: String) -> (link: String, trailing: String) {
        var link = raw
        var trailing = ""
        while let last = link.last {
            let shouldTrim: Bool
            if let opener = linkPairedClosers[last] {
                let closers = link.filter { $0 == last }.count
                let openers = link.filter { $0 == opener }.count
                shouldTrim = closers > openers
            } else {
                shouldTrim = last.unicodeScalars.count == 1 && linkTrailingPunctuation.contains(last)
            }
            guard shouldTrim else { break }
            trailing = String(last) + trailing
            link.removeLast()
        }
        return (link, trailing)
    }

    /// 裸 http(s) 链接（末尾标点由 `splitLinkText` 摘掉）
    private static let bareLinkPattern = "https?://[^" + bareLinkStopClass + "]+"

    /// 只认裸链接的正则（评论用：评论按纯文本展示，**不做 Markdown 解析**）
    private static let bareLinkRegex = try? NSRegularExpression(pattern: bareLinkPattern, options: [])

    /// 内联解析：粗体 / 斜体 / 行内代码 / 链接 / @提及 / #话题（单个 # 前缀）
    private static let inlineRegex = try? NSRegularExpression(
        pattern: "(\\[[^\\]\\n]+\\]\\([^)\\n]+\\))"      // 1 [文字](链接)
            + "|(`[^`\\n]+`)"                              // 2 `行内代码`
            + "|(\\*\\*(?:[^*\\n]|\\*(?!\\*))+\\*\\*)"           // 3 **粗体**（内部允许单个 *，就能嵌套 *斜体*）
            + "|(\\*[^*\\n]+\\*)"                          // 4 *斜体*
            + "|(_[^_\\n]+_)"                              // 5 _斜体_
            + "|(" + bareLinkPattern + ")"                // 6 裸链接（末尾标点由 splitLinkText 摘掉）
            + "|(@[A-Za-z0-9_.\\-\\u4e00-\\u9fa5]{1,24})" // 7 @提及（ICU 只认 \uXXXX 写法）
            + "|(#[^" + topicStopClass + "]{1,30})",       // 8 #话题（单个 # 前缀；到空白 / 标点 / 另一个 # 结束）
        options: [])

    private static func inline(_ text: String, style: Style, font: UIFont, color: UIColor,
                               base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        guard !text.isEmpty else { return result }
        guard let regex = inlineRegex else {
            return NSAttributedString(string: text, attributes: base)
        }

        let ns = text as NSString
        var cursor = 0
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.range.location >= cursor else { continue }
            if match.range.location > cursor {
                result.append(NSAttributedString(string: ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)),
                                                 attributes: base))
            }
            result.append(renderToken(match, in: ns, style: style, font: font, color: color, base: base))
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            result.append(NSAttributedString(string: ns.substring(from: cursor), attributes: base))
        }
        return result
    }

    /// 链接样式：主题色 +（按 `Style` 配置）下划线
    private static func applyLinkStyle(to attributes: inout [NSAttributedString.Key: Any], style: Style) {
        attributes[.foregroundColor] = style.accentColor
        if style.linkUnderline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
    }

    private static func renderToken(_ match: NSTextCheckingResult, in ns: NSString, style: Style,
                                    font: UIFont, color: UIColor,
                                    base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return nil }
            return ns.substring(with: range)
        }

        // 1: [文字](链接)
        if let raw = group(1), let open = raw.firstIndex(of: "["), let close = raw.firstIndex(of: "]") {
            let title = String(raw[raw.index(after: open)..<close])
            let rawURL = String(raw[raw.index(after: close)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                .trimmingCharacters(in: .whitespaces)
            // 链接后缀多出来的标点（例 `[文字](https://a.com。)`）不算链接的一部分
            let urlText = splitLinkText(rawURL).link
            var attributes = base
            applyLinkStyle(to: &attributes, style: style)
            if !urlText.isEmpty, let url = URL(string: urlText) {
                attributes[tapAttributeKey] = url
            }
            return NSAttributedString(string: title.isEmpty ? urlText : title, attributes: attributes)
        }

        // 2: `行内代码`
        if let raw = group(2) {
            let body = String(raw.dropFirst().dropLast())
            var attributes = base
            attributes[.font] = UIFont.monospacedSystemFont(ofSize: max(font.pointSize - 2, 11), weight: .regular)
            attributes[.backgroundColor] = Color_F6F7F8
            return NSAttributedString(string: body, attributes: attributes)
        }

        // 3: **粗体**
        if let raw = group(3) {
            let body = String(raw.dropFirst(2).dropLast(2))
            var attributes = base
            attributes[.font] = boldFont(matching: font)
            return inline(body, style: style, font: boldFont(matching: font), color: color, base: attributes)
        }

        // 4/5: *斜体* / _斜体_
        if let raw = group(4) ?? group(5) {
            let body = String(raw.dropFirst().dropLast())
            var attributes = base
            attributes[.font] = italicFont(matching: font)
            return NSMutableAttributedString(string: body, attributes: attributes)
        }

        // 6: 裸链接 —— 末尾被吞进来的标点按正文样式跟上（只把真正的链接标蓝、让它可点）
        if let raw = group(6) {
            let split = splitLinkText(raw)
            var attributes = base
            applyLinkStyle(to: &attributes, style: style)
            if !split.link.isEmpty, let url = URL(string: split.link) {
                attributes[tapAttributeKey] = url
            }
            let result = NSMutableAttributedString(string: split.link, attributes: attributes)
            if !split.trailing.isEmpty {
                result.append(NSAttributedString(string: split.trailing, attributes: base))
            }
            return result
        }

        // 7: @提及
        if let raw = group(7) {
            var attributes = base
            attributes[.foregroundColor] = style.accentColor
            if let url = tapURL(kind: "mention", value: String(raw.dropFirst())) {
                attributes[tapAttributeKey] = url
            }
            return NSAttributedString(string: raw, attributes: attributes)
        }

        // 8: #话题（单个 # 前缀；到空白 / 标点 / 另一个 # 结束）
        if let raw = group(8) {
            var attributes = base
            attributes[.foregroundColor] = style.accentColor
            let topic = String(raw.dropFirst())
            if let url = tapURL(kind: "topic", value: topic) {
                attributes[tapAttributeKey] = url
            }
            return NSAttributedString(string: raw, attributes: attributes)
        }

        return NSAttributedString(string: ns.substring(with: match.range), attributes: base)
    }

    /// 同字号的粗体（保持与正文字体同一字族）
    private static func boldFont(matching font: UIFont) -> UIFont {
        return .boldFont(font.pointSize)
    }

    /// 同字号的斜体（PingFang 没有斜体，用系统斜体）
    private static func italicFont(matching font: UIFont) -> UIFont {
        return UIFont.italicSystemFont(ofSize: font.pointSize)
    }
}
