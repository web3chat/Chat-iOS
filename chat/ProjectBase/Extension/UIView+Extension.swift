//
//  UIView+Extension.swift
//  xls
//
//  Created by 陈健 on 2020/8/7.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import Toast_Swift
import MBProgressHUD

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach({ self.addSubview($0) })
    }
    
    func updateConstraints(with time: Double, updateBlock: NormalBlock?) {
        self.setNeedsUpdateConstraints()
        updateBlock?()
        UIView.animate(withDuration: time) {
            self.layoutIfNeeded()
        }
    }
    
    func updateConstraints(with time: Double, updateBlock: NormalBlock?, completeBlock: NormalBlock? = nil) {
        self.setNeedsUpdateConstraints()
        updateBlock?()
        UIView.animate(withDuration: time, animations: {
            self.layoutIfNeeded()
        }) { (finish) in
            if finish {
                completeBlock?()
            }
        }
    }
    
    func makeOriginalShdowShow() {
        self.layer.backgroundColor = Color_FAFBFC.cgColor
        self.layer.cornerRadius = 5
        self.makeNormalShadow()
    }
    
    func makeNormalShadow(with offset: CGSize = CGSize.zero) {
        self.layer.shadowColor = Color_E3EEF4.cgColor
        self.layer.shadowOffset = offset
        self.layer.shadowRadius = 5
        self.layer.shadowOpacity = 1.0
        self.clipsToBounds = false
    }
}


extension UITextField {
    func limitText(with limit:Int){
        guard let text = self.text, text.count > limit else { return }
        let lang = self.textInputMode?.primaryLanguage
        
        guard lang == "zh-Hans" else {
            self.text = text.slicing(from: 0, length: limit)
            return
        }
        guard let selectedRange = self.markedTextRange,
              let _ = self.position(from: selectedRange.start, offset: 0) else {
            self.text = text.slicing(from: 0, length: limit)
            return
        }
    }
    
    @discardableResult func addToolBar(with title: String, target: Any, sel: Selector) -> UIButton {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 70))
        view.backgroundColor = Color_FAFBFC
        let btn = UIButton.getNormalBtn(with: title)
        btn.frame = CGRect(x: 15, y: 15, width: k_ScreenWidth - 30, height: 40)
        btn.addTarget(target, action: sel, for: .touchUpInside)
        btn.layer.cornerRadius = 20
        view.addSubview(btn)
        self.inputAccessoryView = view
        return btn
    }
    
}

extension UITextView{
    func limitText(with limit:Int){
        guard let text = self.text, text.count > limit else { return }
        let lang = self.textInputMode?.primaryLanguage
        
        guard lang == "zh-Hans" else {
            self.text = text.slicing(from: 0, length: limit - 1)
            return
        }
        guard let selectedRange = self.markedTextRange,
              let _ = self.position(from: selectedRange.start, offset: 0) else {
            self.text = text.slicing(from: 0, length: limit - 1)
            return
        }
    }
    
    @discardableResult func addToolBar(with title: String, target: Any, sel: Selector) -> UIButton {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 70))
        view.backgroundColor = Color_FAFBFC
        let btn = UIButton.getNormalBtn(with: title)
        btn.frame = CGRect(x: 15, y: 15, width: k_ScreenWidth - 30, height: 40)
        btn.addTarget(target, action: sel, for: .touchUpInside)
        btn.layer.cornerRadius = 20
        view.addSubview(btn)
        self.inputAccessoryView = view
        return btn
    }
    
}

extension UIView {
    
    class func getNormalLineView() -> UIView{
        let view = UIView()
        view.backgroundColor = Color_F1F4F6
        return view
    }
    
    var safeArea : ConstraintRelatableTarget {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide
        }
        return self
    }
    
    var safeAreaTop : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.top
        }
        return self.snp.top
    }
    
    var safeAreaBottom : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.bottom
        }
        return self.snp.bottom
    }
    
    var safeAreaLeading : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.leading
        }
        return self.snp.leading
    }
    
    var safeAreaTrailing : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.trailing
        }
        return self.snp.trailing
    }
    
    var safeAreaCenter : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.center
        }
        return self.snp.center
    }
    
    var safeAreaCenterY : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.centerY
        }
        return self.snp.centerY
    }
    
    var safeAreaCenterX : ConstraintItem {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp.centerX
        }
        return self.snp.centerX
    }
}


extension UIView {
    
    func showToast(_ message: String) {
        self.hideAllToasts(includeActivity: true, clearQueue: true)
//        self.isUserInteractionEnabled = false
        self.makeToast(message, duration: 2, position: .center, title: nil, image: nil) { (bool) in
//            self.isUserInteractionEnabled = true
        }
    }
    
    func show(_ error: Error) {
        guard !error.localizedDescription.isEmpty else { return }
        self.showToast(error.localizedDescription)
    }
    
    func showProgress(with text : String? = nil){
        MBProgressHUD.hide(for: self, animated: true)
        let hud = MBProgressHUD.showAdded(to: self, animated: true)
        guard let text = text else {
            return
        }
        hud.label.text = text
        hud.mode = .indeterminate
        hud.show(animated: true)
    }
    
    func hideProgress(){
        MBProgressHUD.hide(for: self, animated: true)
    }

    func showActivity() {
        self.isUserInteractionEnabled = false
        self.makeToastActivity(.center)
    }

    func hideActivity() {
        self.isUserInteractionEnabled = true
        self.hideToastActivity()
    }
    
}

extension UIView {
    //将当前视图转为UIImage
    func asImage(with frame: CGRect) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: frame)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}
