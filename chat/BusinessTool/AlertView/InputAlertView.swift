//
//  InputAlertView.swift
//  chat
//
//  Created by 陈健 on 2021/1/28.
//

import UIKit
import SnapKit

class InputAlertView: UIView {
    
    private lazy var titleLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .center, text: "")
        lab.numberOfLines = 0
        return lab
    }()

    private lazy var textField: UITextField = {
        let input = UITextField()
        input.font = UIFont.systemFont(ofSize: 20)
        input.leftView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 10, height: 10))
//        input.rightView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 10, height: 10))
        input.leftViewMode = .always
//        input.rightViewMode = .always
        input.textColor = Color_24374E
        input.backgroundColor = Color_F6F7F8
        input.layer.cornerRadius = 5
        input.keyboardType = .asciiCapable
        input.isSecureTextEntry = false
        input.clearButtonMode = .whileEditing
        return input
    }()
    
    private lazy var crossBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage.init(named: "tool_cross"), for: .normal)
        btn.addTarget(self, action: #selector(hide), for: .touchUpInside)
        btn.enlargeClickEdge(.init(top: 10, left: 10, bottom: 10, right: 10))
        return btn
    }()
    
    private lazy var confirmBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 20
        btn.setTitle("确定", for: .normal)
        btn.addTarget(self, action: #selector(confirmClick), for: .touchUpInside)
        return btn
    }()
    
    private lazy var contentView: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_FFFFFF
        v.layer.cornerRadius = 5
        return v
    }()
    
    private lazy var hideControl: UIControl = {
        let control = UIControl.init()
        control.addTarget(self, action: #selector(hide), for: .touchUpInside)
        return control
    }()
    
    var confirmBlock: ((String)->())?
    
    var hideBlock: NormalBlock?
    
    var title: String? {
        didSet {
            self.titleLab.text = title
        }
    }
    
    var attributedTitle: NSAttributedString? {
        didSet {
            self.titleLab.attributedText = attributedTitle
        }
    }
    
    var confirmBtnTitle: String? {
        didSet {
            self.confirmBtn.setTitle(confirmBtnTitle, for: .normal)
        }
    }
    
    var confirmBtnAttributedTitle: NSAttributedString? {
        didSet {
            self.confirmBtn.setAttributedTitle(confirmBtnAttributedTitle, for: .normal)
        }
    }
    
    var textFieldDefaultText: String? {
        didSet {
            self.textField.text = textFieldDefaultText
        }
    }
    
    var textFieldPlaceholder: String? {
        didSet {
            self.textField.placeholder = textFieldPlaceholder
        }
    }
    
    var textFieldAttributedPlaceholder: NSAttributedString? {
        didSet {
            self.textField.attributedPlaceholder = textFieldAttributedPlaceholder
        }
    }
    
    var isSecureTextEntry: Bool = false {
        didSet {
            self.textField.isSecureTextEntry = isSecureTextEntry
        }
    }
    
    var touchBackgroundToHide: Bool = true {
        didSet {
            self.hideControl.isEnabled = touchBackgroundToHide
        }
    }
    
    var autoHide = true
    
    init() {
        super.init(frame: k_ScreenBounds)
        self.backgroundColor = UIColor.init(white: 0, alpha: 0.2)
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.addSubview(hideControl)
        self.hideControl.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.addSubview(self.contentView)
        self.contentView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(30)
            m.right.equalToSuperview().offset(-30)
            m.centerY.equalToSuperview().offset(-100)
            m.height.equalTo(230)
        }
        
        self.contentView.addSubview(self.crossBtn)
        self.crossBtn.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(23)
            m.right.equalToSuperview().offset(-18)
            m.size.equalTo(CGSize.init(width: 14, height: 14))
        }
        
        self.contentView.addSubview(self.titleLab)
        self.titleLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(35)
            m.right.equalToSuperview().offset(-35)
            m.height.equalTo(60)
        }
                
        self.contentView.addSubview(self.textField)
        self.textField.snp.makeConstraints { (m) in
            m.top.equalTo(self.titleLab.snp.bottom).offset(15)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(50)
        }
        
        self.contentView.addSubview(self.confirmBtn)
        self.confirmBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(self.textField.snp.bottom).offset(30)
            m.height.equalTo(40)
        }
    }
    
    @objc private func hide() {
        self.endEditing(true)
        self.hideBlock?()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.hideViews()
        } completion: { (_) in
            self.removeFromSuperview()
        }
    }
    
    @objc private func confirmClick() {
        self.confirmBlock?(self.textField.text ?? "")
        if self.autoHide  {
            self.hide()
        }
    }
    
    func show() {
        self.hideViews()
        UIApplication.shared.keyWindow?.addSubview(self)
        self.contentView.transform = CGAffineTransform.init(scaleX: 1.2, y: 1.2)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.showViews()
            self.contentView.transform = CGAffineTransform.init(scaleX: 1, y: 1)
            self.textField.becomeFirstResponder()
        } completion: { (_) in }
    }
    
    private func hideViews() {
        self.alpha = 0
        self.contentView.alpha = 0
        self.hideControl.alpha = 0
    }
    
    private func showViews() {
        self.alpha = 1
        self.contentView.alpha = 1
        self.hideControl.alpha = 1
    }
    
}
