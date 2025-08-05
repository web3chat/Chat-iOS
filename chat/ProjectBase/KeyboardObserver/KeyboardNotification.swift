//
//  KeyboardNotification.swift
//  chat
//
//  Created by 陈健 on 2021/2/3.
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
    
    var animationCurve: UIView.AnimationCurve? {
        guard let index = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue else { return nil }
        guard index >= 0 && index <= 3 else { return .linear }
        return UIView.AnimationCurve.init(rawValue: index) ?? .linear
    }
    
    var animationOptions: UIView.AnimationOptions {
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
