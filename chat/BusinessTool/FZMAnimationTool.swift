//
//  FZMAnimationTool.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/19.
//  Copyright © 2018年 吴文拼. All rights reserved.
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
                let number = value![0]
                block(number)
            }
            property.threshold = 1.0
        }
        let basic = POPBasicAnimation()
        basic.property = (prop as! POPAnimatableProperty)
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
