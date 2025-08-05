//
//  FZMNoDataView.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/6.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import RxSwift
import SnapKit

class FZMNoDataView: UIView {
    
    let disposeBag = DisposeBag()
    
    var hideBottomBtn : Bool = false {
        didSet{
            bottomBtn.isHidden = hideBottomBtn
            bottom2Btn.isHidden = hideBottomBtn
        }
    }
    
    lazy var contentView : UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var imageView : UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var desLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: nil)
    }()
    
    lazy var bottomBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 17.5
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.clipsToBounds = true
        return btn
    }()
    
    lazy var bottom2Btn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 17.5
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.clipsToBounds = true
        return btn
    }()
    
    init(image: UIImage?, imageSize: CGSize, desText: String, btnTitle: String?, clickBlock: NormalBlock? = nil) {
        super.init(frame: k_ScreenBounds)
        self.addSubview(contentView)
        contentView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(imageSize)
        }
        contentView.addSubview(desLab)
        desLab.snp.makeConstraints { (m) in
            m.top.equalTo(imageView.snp.bottom).offset(10)
            m.centerX.equalToSuperview()
            m.height.equalTo(20)
        }
        contentView.addSubview(bottomBtn)
        bottomBtn.snp.makeConstraints { (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 150, height: 35))
        }
        
        imageView.image = image
        desLab.text = desText
        guard let btnTitle = btnTitle  else {
            bottomBtn.alpha = 0
            return
        }
        bottomBtn.setAttributedTitle(NSAttributedString(string: btnTitle, attributes: [.font:UIFont.regularFont(16),.foregroundColor:Color_Theme]), for: .normal)
        bottomBtn.rx.controlEvent(.touchUpInside).subscribe { (_) in
            clickBlock?()
            }.disposed(by: disposeBag)
    }
    
    convenience init(image: UIImage?, imageSize: CGSize, desText: String, btn1Title: String?, btn1Image: UIImage?, btn2Title: String?, btn2Image: UIImage?, isVertical: Bool = true ,btn1ClickBlock: NormalBlock? = nil, btn2ClickBlock: NormalBlock? = nil) {
        self.init(image: image, imageSize: imageSize, desText: desText, btnTitle: btn1Title, clickBlock: btn1ClickBlock)
        if let btn1Image = btn1Image {
            bottomBtn.setImage(btn1Image, for: .normal)
            bottomBtn.setImage(btn1Image, for: .highlighted)
            if let btn1Title = btn1Title {
                bottom2Btn.setAttributedTitle(NSAttributedString(string: "  \(btn1Title)", attributes: [.font:UIFont.regularFont(16),.foregroundColor:Color_Theme]), for: .normal)
            }
        }
        
        guard let btn2Title = btn2Title else { return }
        contentView.addSubview(bottom2Btn)
        
        if let btn2Image = btn2Image {
            bottom2Btn.setImage(btn2Image, for: .normal)
            bottom2Btn.setImage(btn2Image, for: .highlighted)
            bottom2Btn.setAttributedTitle(NSAttributedString(string: "  \(btn2Title)", attributes: [.font:UIFont.regularFont(16),.foregroundColor:Color_Theme]), for: .normal)
        } else {
            bottom2Btn.setAttributedTitle(NSAttributedString(string: btn2Title, attributes: [.font:UIFont.regularFont(16),.foregroundColor:Color_Theme]), for: .normal)
        }
        
        if isVertical {
            bottomBtn.snp.remakeConstraints { (m) in
                m.bottom.equalToSuperview().offset(-50)
                m.centerX.equalToSuperview()
                m.size.equalTo(CGSize(width: 150, height: 35))
            }
            bottom2Btn.snp.makeConstraints { (m) in
                m.bottom.equalToSuperview()
                m.centerX.equalTo(bottomBtn)
                m.size.equalTo(bottomBtn)
            }
        } else {
            bottomBtn.snp.remakeConstraints { (m) in
                m.bottom.equalToSuperview()
                m.right.equalTo(contentView.snp.centerX).offset(-5)
                m.size.equalTo(CGSize(width: 150, height: 35))
            }
            bottom2Btn.snp.makeConstraints { (m) in
                m.bottom.equalTo(bottomBtn)
                m.left.equalTo(contentView.snp.centerX).offset(5)
                m.size.equalTo(bottomBtn)
            }
        }
        bottom2Btn.rx.controlEvent(.touchUpInside).subscribe { (_) in
            btn2ClickBlock?()
            }.disposed(by: disposeBag)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
