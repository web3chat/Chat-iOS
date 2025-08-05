//
//  UIImageView+Tool.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/19.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import Foundation
import YYImage
import UIKit

extension UIImageView{
    
    func loadNetworkImage(with url: String, placeImage: UIImage?, completeBlock: OptionImageBlock? = nil) {
        self.yy_cancelCurrentImageRequest()
        if url.count > 0 && url.contains("http") {
            self.yy_setImage(with: URL(string: url), placeholder: placeImage, options: .setImageWithFadeAnimation) { (image, _, _, _, _) in
                completeBlock?(image)
            }
        }else {
            self.image = placeImage
        }
    }
    
    private var topClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "topClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "topClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    private var rightClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "rightClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "rightClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    private var bottomClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "bottomClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "bottomClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    private var leftClickOffset: CGFloat? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "leftClickOffset".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "leftClickOffset".hashValue)
            let obj: CGFloat? = objc_getAssociatedObject(self, key) as? CGFloat
            return obj ?? 0
        }
    }
    
    func enlargeClickEdge(_ top : CGFloat? ,_ left : CGFloat? ,_ bottom : CGFloat? ,_ right : CGFloat?){
        self.topClickOffset = top
        self.leftClickOffset = left
        self.bottomClickOffset = bottom
        self.rightClickOffset = right
    }
    
    private func enlargedRect() -> CGRect{
        return CGRect.init(x : self.bounds.origin.x - self.leftClickOffset!,
                           y :  self.bounds.origin.y - self.topClickOffset!,
                           width : self.bounds.size.width + self.leftClickOffset! + self.rightClickOffset!,
                           height : self.bounds.size.height + self.topClickOffset! + self.bottomClickOffset!);
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let rect : CGRect = self.enlargedRect()
        if rect.equalTo(self.bounds) {
            return super.hitTest(point, with: event)
        }
        if rect.contains(point) && !self.isHidden {
            return self
        }
        return nil
    }
}
