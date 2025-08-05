//
//  ViewControllerProtocol.swift
//  xls
//
//  Created by 陈健 on 2020/7/30.
//  Copyright © 2020 陈健. All rights reserved.
//

import UIKit



private struct AssociationKey {
    static var isNavigationBarHidden = "XLS_AssociationKey_isNavigationBarHidden"
    static var navigationBarBackgroundColor = "XLS_AssociationKey_navigationBarBackgroundColor"
    static var navigationBarTintColor = "XLS_AssociationKey_navigationBarTintColor"
    static var navigationLineHidden = "XLS_AssociationKey_navigationLineHidden"
}
protocol ViewControllerProtocol where Self: UIViewController {
    var xls_isNavigationBarHidden: Bool { get set }
    var xls_navigationBarBackgroundColor: UIColor? { get set }
    var xls_navigationBarTintColor: UIColor? { get set }
    var xls_isNavigationLineHidden: Bool { get set }
}

extension ViewControllerProtocol {
    
    var xls_isNavigationBarHidden: Bool {
        set {
            objc_setAssociatedObject(self, &AssociationKey.isNavigationBarHidden, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        get {
            return (objc_getAssociatedObject(self, &AssociationKey.isNavigationBarHidden) as? Bool) ?? false
        }
    }
    
    var xls_navigationBarBackgroundColor: UIColor? {
        set {
            objc_setAssociatedObject(self, &AssociationKey.navigationBarBackgroundColor, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return (objc_getAssociatedObject(self, &AssociationKey.navigationBarBackgroundColor) as? UIColor)
        }
    }
    
    var xls_navigationBarTintColor: UIColor? {
        set {
            objc_setAssociatedObject(self, &AssociationKey.navigationBarTintColor, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return (objc_getAssociatedObject(self, &AssociationKey.navigationBarTintColor) as? UIColor)
        }
    }
    
    var xls_isNavigationLineHidden: Bool {
        set {
            objc_setAssociatedObject(self, &AssociationKey.navigationLineHidden, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        get {
            return (objc_getAssociatedObject(self, &AssociationKey.navigationLineHidden) as? Bool) ?? false
        }
    }
    
}
