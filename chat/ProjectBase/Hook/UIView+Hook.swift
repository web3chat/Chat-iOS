//
//  UIView+Extension.swift
//  xls
//
//  Created by 陈健 on 2020/8/5.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    
    func enlargeClickEdge(_ edgeInsets: UIEdgeInsets) {
        guard edgeInsets != self.enlargeClickEdge else { return }
        if self.aspectToken?.responds(to: NSSelectorFromString("remove")) == true {
            self.aspectToken?.perform(NSSelectorFromString("remove"))
            self.aspectToken = nil
        }
        self.enlargeClickEdge = edgeInsets
        guard edgeInsets != .zero else { return }
        self.hookHitTest()
    }

    private var enlargeClickEdge: UIEdgeInsets {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "enlarge_Click_Edge".hashValue)
            objc_setAssociatedObject(self, key, NSValue.init(uiEdgeInsets: newValue), .OBJC_ASSOCIATION_RETAIN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "enlarge_Click_Edge".hashValue)
            let obj = (objc_getAssociatedObject(self, key) as? NSValue)?.uiEdgeInsetsValue
            return obj ?? UIEdgeInsets.zero
        }
    }
    
    private var enlargedHitRect: CGRect {
        CGRect.init(x : self.bounds.origin.x - self.enlargeClickEdge.left,
                    y :  self.bounds.origin.y - self.enlargeClickEdge.top,
                    width : self.bounds.size.width + self.enlargeClickEdge.left + self.enlargeClickEdge.right,
                    height : self.bounds.size.height + self.enlargeClickEdge.top + self.enlargeClickEdge.bottom)
    }
    
    private var aspectToken: NSObject? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "hook_AspectToken".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "hook_AspectToken".hashValue)
            return objc_getAssociatedObject(self, key) as? NSObject
        }
    }
    
    private var hitTestReturnValue: UIView? {
        set {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "hook_return_value".hashValue)
            objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        
        get {
            let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern: "hook_return_value".hashValue)
            return objc_getAssociatedObject(self, key) as? UIView
        }
    }
    
    private func hookHitTest()  {
        let hitTestBlock: @convention(block) (AspectInfo, CGPoint, UIEvent?) -> Void = { (aspectInfo, point, enent)  in
            guard let view = aspectInfo.instance() as? UIView else { return }
            guard let invocation = aspectInfo.originalInvocation() else { return }
            guard view.enlargeClickEdge != .zero else {
                invocation.invoke()
                return
            }
            view.hitTestReturnValue = view.hitTest(view, point, with: enent)
            invocation.setReturnValue(&view.hitTestReturnValue)
        }
        self.aspectToken = (try? self.aspect_hook(NSSelectorFromString("hitTest:withEvent:"), with: .positionInstead, usingBlock: hitTestBlock)) as? NSObject
    }
    
    private func hitTest(_ view: UIView, _ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard view.isUserInteractionEnabled else { return nil }
        guard !view.isHidden else { return nil }
        guard view.alpha >= 0.01 else { return nil }
        
        guard view.enlargedHitRect.contains(point) else { return nil }
        
        for subview in view.subviews {
            let convertedPoint = subview.convert(point, from: view)
            if let candidate = subview.hitTest(convertedPoint, with: event) {
                return candidate
            }
        }
        return view
    }
}



