//
//  FZMAnimationTool.swift
//  Chat33
//
//  Created by fzm on 2018/9/19.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit
import pop

class FZMAnimationTool: NSObject {

    //倒计时动画
    class func countdown(with view:UIView,fromValue:Double,toValue:Double, block:@escaping (CGFloat)->(),finishBlock:(()->())?){
        self.removeCountdown(with: view)
        let prop = POPAnimatableProperty.property(withName: "CountDown") {(property) in
            guard let property = property else { return }
            property.writeBlock = { (obj, value) in
                // pop 的 value 指针可能为空：强解包会崩
                guard let value = value else { return }
                let number = value[0]
                block(number)
            }
            property.threshold = 1.0
        }
        guard let basicProperty = prop as? POPAnimatableProperty else {
            FZMLog("倒计时动画创建失败：POPAnimatableProperty 为空")
            return
        }
        let basic = POPBasicAnimation()
        basic.property = basicProperty
        basic.timingFunction = CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.linear)
        basic.duration = fromValue
        basic.fromValue = fromValue
        basic.toValue = 0
        view.pop_add(basic, forKey: "CountDownAnimation")
        basic.animationDidReachToValueBlock = {[weak view] animation in
            finishBlock?()
            view?.pop_removeAnimation(forKey: "CountDownAnimation")
        }
    }
    
    //移除倒计时动画
    class func removeCountdown(with view:UIView){
        if view.pop_animation(forKey: "CountDownAnimation") != nil {
            view.pop_removeAnimation(forKey: "CountDownAnimation")
        }
    }
    
    
}
