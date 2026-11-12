
import UIKit

class MessageLabel: UILabel {
    
    // MARK: - Private Properties
    
    private lazy var layoutManager: NSLayoutManager = {
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(self.textContainer)
        return layoutManager
    }()
    
    private lazy var textContainer: NSTextContainer = {
        let textContainer = NSTextContainer()
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = self.numberOfLines
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.size = self.bounds.size
        return textContainer
    }()
    
    private lazy var textStorage: NSTextStorage = {
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(self.layoutManager)
        return textStorage
    }()
    
    private var isConfiguring: Bool = false
    
    // MARK: - Public Properties
    
    weak var delegate: MessageLabelDelegate?
    
    override var attributedText: NSAttributedString? {
        didSet {
            setTextStorage(attributedText)
        }
    }
    
    override var text: String? {
        didSet {
            setTextStorage(attributedText)
        }
    }
    
    override var font: UIFont! {
        didSet {
            setTextStorage(attributedText)
        }
    }
    
    override var textColor: UIColor! {
        didSet {
            setTextStorage(attributedText)
        }
    }
    
    override var lineBreakMode: NSLineBreakMode {
        didSet {
            textContainer.lineBreakMode = lineBreakMode
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    override var numberOfLines: Int {
        didSet {
            textContainer.maximumNumberOfLines = numberOfLines
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    override var textAlignment: NSTextAlignment {
        didSet {
            setTextStorage(attributedText)
        }
    }
    
    var textInsets: UIEdgeInsets = .zero {
        didSet {
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += textInsets.horizontal
        size.height += textInsets.vertical
        return size
    }
    
    internal var messageLabelFont: UIFont?

    /// 链接色（默认主题色）。
    ///
    /// 由 cell 在 `configure` 时按**收发**写入：自己发的气泡背景是**浅蓝**
    /// （`bubble_right` = `#C1E9FF`），主题色 `#32B2F7` 压在它上面实测对比度只有 ~1.85:1
    /// （WCAG 正文最低 3:1）—— 会看不清，反而失去「可点击」的暗示，所以那种情况改用 `outgoingLinkColor`。
    var linkColor: UIColor = Color_Theme

    /// 浅蓝背景（自己发的气泡）上用的链接色：主题色同色系压暗一档。
    ///
    /// 实测对比度：浅蓝 `#C1E9FF` 上 ≈3.55:1，白底上 ≈4.56:1（都过 WCAG 3:1 / 4.5:1）。
    static let outgoingLinkColor = #colorLiteral(red: 0.03921568627, green: 0.4823529412, blue: 0.768627451, alpha: 1)
    
    // MARK: - Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    // MARK: -  Methods
    
    override func drawText(in rect: CGRect) {
        
        let insetRect = rect.inset(by: textInsets)
        // ⚠️ 宽度**必须留一点余量**（这里 +3pt）：
        //    气泡宽度是 `TextMessageSizeCalculator` 用 `boundingRect`（CoreText）量出来的，
        //    和这里 TextKit 的实际排版在字距/字偶上会差零点几到一两 pt。差这一点，
        //    TextKit 就把末尾一个词（如「（21）」）挤到第二行；而气泡高度是按一行算的，
        //    第二行被 `clipsToBounds` 裁掉 ⇒ 用户看到"尾部字符消失、也没有省略号"。
        //    余量落在气泡 12pt 的左右内边距里，视觉上看不出来。
        textContainer.size = CGSize(width: insetRect.width + 3, height: rect.height)
        
        let origin = insetRect.origin
        let range = layoutManager.glyphRange(for: textContainer)
        
        layoutManager.drawBackground(forGlyphRange: range, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: range, at: origin)
    }
    
    // MARK: - Public Methods
    
    public func configure(block: () -> Void) {
        isConfiguring = true
        block()
        isConfiguring = false
        setNeedsDisplay()
    }
    
    // MARK: - Private Methods
    
    private func setTextStorage(_ newText: NSAttributedString?) {
        
        guard let newText = newText, newText.length > 0 else {
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }
        
        let style = paragraphStyle(for: newText)
        let range = NSRange(location: 0, length: newText.length)
        
        let mutableText = NSMutableAttributedString(attributedString: newText)
        mutableText.addAttribute(.paragraphStyle, value: style, range: range)
        underlineLinks(in: mutableText)
        
        let modifiedText = NSAttributedString(attributedString: mutableText)
        textStorage.setAttributedString(modifiedText)
        
        if !isConfiguring { setNeedsDisplay() }
        
    }
    
    /// 把文本里的 http/https 链接标成**主题色 + 下划线**，让它看起来就是可点的。
    ///
    /// 背景：气泡是**整条文本**响应点击（本类 `handleGesture` 恒返回 false，
    /// 点击最终交给 `ChatVC.openUrl(urlStr:)`），所以这里只负责「视觉上的可点击暗示」，
    /// **不改变点击行为**。判定用与 `ChatVC.firstLink(in:)` 同一套 `NSDataDetector`，两侧一致。
    private func underlineLinks(in text: NSMutableAttributedString) {
        // 绝大多数消息根本没有链接：先用最便宜的字符串判断挡掉，避免每条消息都跑一次探测器
        guard text.string.range(of: "http", options: .caseInsensitive) != nil else { return }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
        
        let fullRange = NSRange(location: 0, length: text.length)
        for match in detector.matches(in: text.string, options: [], range: fullRange) {
            guard let url = match.url else { continue }
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else { continue }
            let linkRange = match.range
            guard linkRange.location != NSNotFound, NSMaxRange(linkRange) <= text.length else { continue }
            
            // 链接用**主题色** + 下划线，和正文明确区分（只有下划线不够显眼）
            // ⚠️ 不要用 `.link` 属性：那会让 UILabel 自己去处理点击，而本类把点击统一交给了
            //    `ChatVC.openUrl(urlStr:)`（`handleGesture` 恒返回 false）。
            text.addAttribute(.foregroundColor, value: linkColor, range: linkRange)
            text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            text.addAttribute(.underlineColor, value: linkColor, range: linkRange)
        }
    }
    
    private func paragraphStyle(for text: NSAttributedString) -> NSParagraphStyle {
        guard text.length > 0 else { return NSParagraphStyle() }
        
        var range = NSRange(location: 0, length: text.length)
        let existingStyle = text.attribute(.paragraphStyle, at: 0, effectiveRange: &range) as? NSMutableParagraphStyle
        let style = existingStyle ?? NSMutableParagraphStyle()
        
        style.lineBreakMode = lineBreakMode
        style.alignment = textAlignment
        
        return style
    }
    
    private func setupView() {
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
    }
    
    // MARK: - Gesture Handling
    
    func handleGesture(_ touchLocation: CGPoint) -> Bool {
        return false
    }
}


