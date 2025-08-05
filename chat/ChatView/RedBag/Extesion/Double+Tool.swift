//
//  Double+Tool.swift
//  IMSDK
//
//  Created by 陈健 on 2019/3/21.
//

import Foundation

extension Double {
    func roundTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
extension Double {
    var numberStringWithoutZero:String{
        get {
            var str = String(self)
            guard str.contains(".") else {return str}
            while str.hasSuffix("0") {
                str.removeLast()
            }
            if str.hasSuffix(".") {
                str.removeLast()
            }
            
            return str
        }
    }
}
