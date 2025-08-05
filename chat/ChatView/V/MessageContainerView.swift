//
//  MessageContainerView.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import UIKit

class MessageContainerView: UIView {
    
    enum Style {
        case incoming
        case outgoing
        case incomingDark
        case outgoingDark
        case none
    }
    
    private let bubbleImageView = UIImageView.init()
    
    var style = Style.none {
        didSet { self.applyStyle() }
    }
    
    override var frame: CGRect {
        didSet { self.sizeMaskToView() }
    }
    
    func applyStyle() {
        guard self.style != .none else {
            self.bubbleImageView.isHidden = true
            return
        }
        self.bubbleImageView.isHidden = false
        self.bubbleImageView.image = self.style.image
    }
    
    func sizeMaskToView() {
        self.bubbleImageView.frame = self.bounds
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupViews() {
        self.addSubview(self.bubbleImageView)
    }
}

extension MessageContainerView.Style {
    var image: UIImage? {
        guard let imageName = self.imageName else { return nil }
        if let cachedImage = MessageContainerView.Style.bubbleImageCache.object(forKey: imageName as NSString) {
            return cachedImage
        }
        guard let bubbleImage = UIImage.init(named: imageName) else { return nil }
        let stretchedImage = self.stretch(bubbleImage)
        MessageContainerView.Style.bubbleImageCache.setObject(stretchedImage, forKey: imageName as NSString)
        return stretchedImage
    }
    
    private static let bubbleImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        return cache
    }()
    
    private var imageName: String? {
        switch self {
        case .incoming:
            return "bubble_left"
        case .outgoing:
            return "bubble_right"
        case .incomingDark:
            return "bubble_left_dark"
        case .outgoingDark:
            return "bubble_right_dark"
        case .none:
            return nil
        }
    }
    
    private func stretch(_ image: UIImage) -> UIImage {
        let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
        let capInsets = UIEdgeInsets(top: center.y, left: center.x, bottom: center.y, right: center.x)
        return image.resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
    }
}
