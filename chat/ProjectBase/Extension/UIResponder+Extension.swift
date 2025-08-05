//
//  UIResponder+Extension.swift
//  xls
//
//  Created by 陈健 on 2020/8/6.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import UIKit

private weak var xls_currentFirstResponder: UIResponder?

extension UIResponder {
    static func xls_firstResponder() -> UIResponder? {
        xls_currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(xls_findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return xls_currentFirstResponder
    }
    @objc private func xls_findFirstResponder(_ sender: AnyObject) {
        xls_currentFirstResponder = self
    }
}
