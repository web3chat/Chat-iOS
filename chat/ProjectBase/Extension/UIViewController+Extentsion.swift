//
//  UIViewController+Extentsion.swift
//  xls
//
//  Created by 陈健 on 2020/9/30.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import SnapKit
import UIKit

extension UIViewController {
    class func current(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return current(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return current(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return current(base: presented)
        }
        return base
    }
    
    func showProgress(with text : String? = nil){
        DispatchQueue.main.async {
            self.view.showProgress(with: text)
        }
    }
    
    func hideProgress(){
        DispatchQueue.main.async {
            self.view.hideProgress()
        }
    }
    
    func showToast(_ text: String){
        DispatchQueue.main.async {
            self.view.showToast(text)
        }
    }
}

//extension UIViewController :UIDocumentInteractionControllerDelegate {
//    
//    func previewDocument(url:URL,name:String = "") {
//        let vc = UIDocumentInteractionController.init(url: url)
//        vc.delegate = self
//        vc.name = name
//        let canOpen = vc.presentPreview(animated: true)
//        if !canOpen {
//            if var navRect = self.navigationController?.navigationBar.frame {
//                navRect.size = CGSize.init(width: 1500, height: 40)
//                vc.presentOpenInMenu(from: navRect, in: self.view, animated: true)
//            }
//        }
//    }
//    
//    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
//        return self
//    }
//    
//}


extension UIViewController{
    
    var safeArea : ConstraintRelatableTarget {
        return self.view.safeArea
    }
    
    var safeTop : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.view.safeAreaLayoutGuide.snp.top
        }
        return self.view.snp.top
    }
    
    var safeBottom : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.view.safeAreaLayoutGuide.snp.bottom
        }
        return self.view.snp.bottom
    }
    
    var safeCenterY : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.view.safeAreaLayoutGuide.snp.centerY
        }
        return self.view.snp.centerY
    }
    
    var safeAreaLeading : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.view.safeAreaLayoutGuide.snp.leading
        }
        return self.view.snp.leading
    }
    
    var safeAreaTrailing : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.view.safeAreaLayoutGuide.snp.trailing
        }
        return self.view.snp.trailing
    }
}
