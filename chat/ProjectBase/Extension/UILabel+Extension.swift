//
//  UILabel+Extension.swift
//  xls
//
//  Created by 陈健 on 2020/8/6.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import UIKit

extension UILabel {
    class func getLab(font: UIFont, textColor: UIColor?, textAlignment: NSTextAlignment, text: String?) -> UILabel {
        let lab = UILabel()
        lab.font = font
        lab.textColor = textColor ?? UIColor.black
        lab.textAlignment = textAlignment
        lab.text = text
        return lab
    }
}
