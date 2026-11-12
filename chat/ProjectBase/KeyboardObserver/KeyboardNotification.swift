//
//  KeyboardNotification.swift
//  chat
//
//  Created by fzm on 2021/2/3.
//

import Foundation

public struct KeyboardNotification {
    
     enum KeyboardEvent {
        /// Event raised by UIKit's `.UIKeyboardWillShow`.
        case willShow
        /// Event raised by UIKit's `.UIKeyboardDidShow`.
        case didShow
        /// Event raised by UIKit's `.UIKeyboardWillShow`.
        case willHide
        /// Event raised by UIKit's `.UIKeyboardDidHide`.
        case didHide
        /// Event raised by UIKit's `.UIKeyboardWillChangeFrame`.
        case willChangeFrame
        /// Event raised by UIKit's `.UIKeyboardDidChangeFrame`.
        case didChangeFrame
        /// Non-keyboard based event raised by UIKit
        case unknown
    }
    
    /// The event that triggered the transition
     let event: KeyboardEvent
    
    /// The animation length the keyboards transition
     let timeInterval: TimeInterval
    
    /// The animation properties of the keyboards transition
     let animationOptions: UIView.AnimationOptions
    
    /// iPad supports split-screen apps, this indicates if the notification was for the current app
     let isForCurrentApp: Bool
    
    /// The keyboards frame at the start of its transition
     var startFrame: CGRect
    
    /// The keyboards frame at the beginning of its transition
     var endFrame: CGRect
    
    /// Requires that the `NSNotification` is based on a `UIKeyboard...` event
    ///
    /// - Parameter notification: `KeyboardNotification`
    public init?(from notification: NSNotification) {
        guard notification.event != .unknown else { return nil }
        self.event = notification.event
        self.timeInterval = notification.timeInterval ?? 0.25
        self.animationOptions = notification.animationOptions
        self.isForCurrentApp = notification.isForCurrentApp ?? true
        self.startFrame = notification.startFrame ?? .zero
        self.endFrame = notification.endFrame ?? .zero
    }
    
}


private extension NSNotification {
    
    var event: KeyboardNotification.KeyboardEvent {
        switch self.name {
        case UIResponder.keyboardWillShowNotification:
            return .willShow
        case UIResponder.keyboardDidShowNotification:
            return .didShow
        case UIResponder.keyboardWillHideNotification:
            return .willHide
        case UIResponder.keyboardDidHideNotification:
            return .didHide
        case UIResponder.keyboardWillChangeFrameNotification:
            return .willChangeFrame
        case UIResponder.keyboardDidChangeFrameNotification:
            return .didChangeFrame
        default:
            return .unknown
        }
    }
    
    var timeInterval: TimeInterval? {
        guard let value = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else { return nil }
        return TimeInterval(truncating: value)
    }
    
    /// 键盘在通知里给的**原始**曲线值。⚠️ 系统键盘用的是 **7**，而 `UIView.AnimationCurve` 只有 0~3。
    var rawAnimationCurveIndex: Int? {
        return (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue
    }
    
    var animationCurve: UIView.AnimationCurve? {
        guard let index = rawAnimationCurveIndex else { return nil }
        guard index >= 0 && index <= 3 else { return .linear }
        return UIView.AnimationCurve.init(rawValue: index) ?? .linear
    }
    
    var animationOptions: UIView.AnimationOptions {
        // ⚠️ 键盘的真实曲线是系统私有值 **7**（不在 0~3 里），只按 `animationCurve` 映射会被夹成
        // `.curveLinear` —— 于是「拿通知自己做动画」的地方变成**匀速直线**跟随，和键盘的真实运动
        // 对不上：键盘前半段跑得更快，它顶边那条深色描边就会穿过/扫过跟随的底栏
        // （广场评论输入条上那条「跟着键盘一起弹出来、一秒左右消失」的半透明黑细线就是这么来的）。
        // UIView 动画的曲线就存在 options 的高 16 位，把原始值原样搬过去即可，与键盘完全对齐。
        if let index = rawAnimationCurveIndex, index > 3 {
            return UIView.AnimationOptions(rawValue: UInt(index) << 16)
        }
        guard let curve = animationCurve else { return [] }
        switch curve {
        case .easeIn:
            return .curveEaseIn
        case .easeOut:
            return .curveEaseOut
        case .easeInOut:
            return .curveEaseInOut
        case .linear:
            return .curveLinear
        @unknown default:
            return .curveLinear
        }
    }
    
    var startFrame: CGRect? {
        return (userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
    }
    
    var endFrame: CGRect? {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    }
    
    var isForCurrentApp: Bool? {
        return (userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue
    }
    
}
