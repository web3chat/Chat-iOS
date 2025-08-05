//
//  InputBarView+Keyboard.swift
//  chat
//
//  Created by 陈健 on 2021/2/3.
//

import Foundation
import SnapKit

extension InputBarView {
    
    private struct AssociationKey {
        static var keyboardObserver = "InputBarView_AssociationKey_KeyboardObserver"
        static var isKeyboardObserveEnable = "InputBarView_AssociationKey_isKeyboardObserveEnable"
        static var bottomConstraintHeight = "InputBarView_AssociationKey_bottomConstraintHeight"
    }
    
    private var keyboardObserver: KeyboardObserver {
        get {
            if (objc_getAssociatedObject(self, &AssociationKey.keyboardObserver) as? KeyboardObserver) == nil {
                let keyboardObserver = KeyboardObserver.init()
                objc_setAssociatedObject(self, &AssociationKey.keyboardObserver, keyboardObserver, .OBJC_ASSOCIATION_RETAIN)
            }
            return objc_getAssociatedObject(self, &AssociationKey.keyboardObserver) as! KeyboardObserver
        }
    }
    
    var isKeyboardObserveEnable: Bool {
        get {
            return (objc_getAssociatedObject(self, &AssociationKey.isKeyboardObserveEnable) as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(self, &AssociationKey.isKeyboardObserveEnable, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    private var bottomConstraintHeight: CGFloat? {
        get {
            return objc_getAssociatedObject(self, &AssociationKey.bottomConstraintHeight) as? CGFloat
        }
        
        set {
            objc_setAssociatedObject(self, &AssociationKey.bottomConstraintHeight, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    
    func observeKeyboard() {
        self.keyboardObserver.callbacks[.willShow] = { [weak self] (notification) in
            guard let self = self, self.isKeyboardObserveEnable else { return }
            let keyboardHeight = notification.endFrame.height
            self.showMore = false
            self.showVoice = false
            guard self.bottomConstraintHeight != keyboardHeight else { return }
            self.bottomConstraintHeight = keyboardHeight
            
            self.changeSpaceToBottom?(keyboardHeight + self.height)
            
//            self.bottomConstraint?.update(offset: -keyboardHeight)
            self.snp.updateConstraints { m in
                m.bottom.equalTo(-keyboardHeight)
            }
            self.animateAlongside(notification) { [weak self] in
                self?.superview?.layoutIfNeeded()
            }
        }
        self.keyboardObserver.callbacks[.willChangeFrame] = { [weak self] (notification) in
            guard let self = self, self.isKeyboardObserveEnable else { return }
            let keyboardHeight = notification.endFrame.height
            guard self.bottomConstraintHeight != keyboardHeight else { return }
            self.bottomConstraintHeight = keyboardHeight
            
            self.changeSpaceToBottom?(keyboardHeight + self.height)
            
//            self.bottomConstraint?.update(offset: -keyboardHeight)
            self.snp.updateConstraints { m in
                m.bottom.equalTo(-keyboardHeight)
            }
            self.animateAlongside(notification) { [weak self] in
                self?.superview?.layoutIfNeeded()
            }
        }
        self.keyboardObserver.callbacks[.willHide] = { [weak self] (notification) in
            guard let self = self, self.isKeyboardObserveEnable else { return }
            guard self.bottomConstraintHeight != k_SafeBottomInset else { return }
            self.bottomConstraintHeight = k_SafeBottomInset
            
            self.changeSpaceToBottom?(k_SafeBottomInset + self.height)
            
//            self.bottomConstraint?.update(offset: -k_SafeBottomInset)
//            self.snp.updateConstraints { m in
//                m.bottom.equalTo(-k_SafeBottomInset)
//            }
            //键盘收回的时候重置键盘类型
            self.emojiBtn.isSelected = false
            self.inputTextView.textView.inputView = nil
            
            self.hideKeyboardBlock?()
            self.animateAlongside(notification) { [weak self] in
                self?.superview?.layoutIfNeeded()
            }
        }
    }
    
    private func animateAlongside(_ notification: KeyboardNotification, animations: @escaping ()->Void) {
        UIView.animate(withDuration: notification.timeInterval, delay: 0, options: [notification.animationOptions, .allowAnimatedContent, .beginFromCurrentState], animations: animations, completion: nil)
    }
}
