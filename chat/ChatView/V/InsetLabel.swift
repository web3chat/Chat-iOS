//
//  InsetLabel.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import UIKit

class InsetLabel: UILabel {
    
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
        textContainer.size = CGSize(width: insetRect.width, height: rect.height)
        
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
        
        let modifiedText = NSAttributedString(attributedString: mutableText)
        textStorage.setAttributedString(modifiedText)
        
        if !isConfiguring { setNeedsDisplay() }
        
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
}





