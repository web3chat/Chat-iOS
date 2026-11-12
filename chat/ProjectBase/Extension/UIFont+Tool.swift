//
//  UIFont+Tool.swift
//  Chat33
//
//  Created by fzm on 2018/9/19.
//  Copyright © 2018年 fzm. All rights reserved.
//

import Foundation
import UIKit

extension UIFont{
    
    class func regularFont(_ size : CGFloat) -> UIFont{
        return UIFont.init(name: "PingFangSC-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    class func mediumFont(_ size : CGFloat) -> UIFont{
        return UIFont.init(name: "PingFangSC-Medium", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    class func boldFont(_ size : CGFloat) -> UIFont{
        return UIFont.init(name: "PingFangSC-Semibold", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    class func thinFont(_ size : CGFloat) -> UIFont{
        return UIFont.init(name: "PingFangSC-Thin", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    class func lightFont(_ size : CGFloat) -> UIFont{
        return UIFont.init(name: "PingFangSC-Light", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    
}
