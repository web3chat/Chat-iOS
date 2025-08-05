//
//  InfoAlertView.swift
//  chat
//
//  Created by 陈健 on 2021/1/28.
//

import UIKit
import SnapKit

class InfoAlertView: UIView {
    private lazy var titleLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .center, text: "")
        lab.numberOfLines = 0
        return lab
    }()

    private lazy var inforLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 18), textColor: Color_24374E, textAlignment: .center, text: "")
        lab.numberOfLines = 0
        return lab
    }()
    
    private lazy var crossBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage.init(named: "tool_cross"), for: .normal)
        btn.addTarget(self, action: #selector(hide), for: .touchUpInside)
        btn.enlargeClickEdge(.init(top: 10, left: 10, bottom: 10, right: 10))
        return btn
    }()
    
    private lazy var lineView: UIView = {
        let v = UIView()
        v.backgroundColor = Color_E6EAEE
        return v
    }()
    
    private lazy var confirmBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.setTitleColor(Color_Theme, for: .normal)
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
    
    var confirmBlock: (()->())?
    
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
    
    var info: String? {
        didSet {
            self.inforLab.text = info
        }
    }
    
    var attributedInfo: NSAttributedString? {
        didSet {
            self.inforLab.attributedText = attributedInfo
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
    
    
    var touchBackgroundToHide: Bool = true {
        didSet {
            self.hideControl.isEnabled = touchBackgroundToHide
        }
    }
    
    var hideCrossBtn = false {
        didSet {
            self.crossBtn.isHidden = hideCrossBtn
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
            m.centerY.equalToSuperview()
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
                
        self.contentView.addSubview(self.inforLab)
        self.inforLab.snp.makeConstraints { (m) in
            m.top.equalTo(self.titleLab.snp.bottom).offset(5)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        self.contentView.addSubview(self.lineView)
        self.lineView.snp.makeConstraints { make in
            make.top.equalTo(self.inforLab.snp.bottom).offset(15)
            make.left.right.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
        self.contentView.addSubview(self.confirmBtn)
        self.confirmBtn.snp.makeConstraints { (m) in
            m.top.equalTo(self.inforLab.snp.bottom).offset(15)
            m.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(50)
        }
    }
    
    @objc private func hide() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.hideViews()
        } completion: { (_) in
            self.removeFromSuperview()
        }
    }
    
    @objc private func confirmClick() {
        self.confirmBlock?()
        if self.autoHide {
            self.hide()
        }
    }
    
    func show() {
        self.hideViews()
        self.removeFromSuperview()
        UIApplication.shared.keyWindow?.addSubview(self)
        self.contentView.transform = CGAffineTransform.init(scaleX: 1.2, y: 1.2)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.showViews()
            self.contentView.transform = CGAffineTransform.init(scaleX: 1, y: 1)
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
