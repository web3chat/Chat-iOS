//
//  IMRedBagShareView.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/12.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class FZMRedBagShareView: UIView {
    
    var shareUrl : String?

    //中间视图
    lazy var centerView : UIView = {
        let view = UIView()
        view.layer.cornerRadius = 10.0
        view.clipsToBounds = true
        view.backgroundColor = FZM_LuckyPacketColor
        view.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(centerClick)))
        return view
    }()
    
    init(title : String?,shareUrl : String?) {
        self.shareUrl = shareUrl
        super.init(frame: k_ScreenBounds)
        self.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(hide)))
        self.backgroundColor = UIColor.init(white: 0, alpha: 0.3)
        self.addSubview(centerView)
        centerView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 300, height: 450))
        }
        let cancelBtn = UIButton(type: UIButton.ButtonType.custom)
        cancelBtn.setImage(UIImage(named: "tool_reject"), for: UIControl.State.normal)
        cancelBtn.addTarget(self, action: #selector(hide), for: UIControl.Event.touchUpInside)
        cancelBtn.enlargeClickEdge( 20, 20, 20, 20)
        centerView.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(15)
            m.size.equalTo(CGSize.init(width: 20, height: 20))
        }
        let titleLab = UILabel.getLab(font: UIFont.regularFont(18), textColor: UIColor.white, textAlignment: NSTextAlignment.center, text: title)
        centerView.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(30)
            m.height.equalTo(20)
        }
        let desLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: UIColor.white, textAlignment: NSTextAlignment.center, text: "未领取红包将于24小时后退回账户")
        centerView.addSubview(desLab)
        desLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(titleLab.snp.bottom).offset(10)
            m.height.equalTo(14)
        }
        let codeView = UIView.init()
        codeView.backgroundColor = UIColor.white
        codeView.layer.cornerRadius = 5.0
        codeView.clipsToBounds = true
        centerView.addSubview(codeView)
        codeView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(desLab.snp.bottom).offset(19)
            m.size.equalTo(CGSize.init(width: 180, height: 200))
        }
        let image = QRCodeGenerator.setupQRCodeImage(shareUrl ?? "", image: nil)
        let qrImageView = UIImageView.init(image: image)
        codeView.addSubview(qrImageView)
        qrImageView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(19)
            m.size.equalTo(CGSize.init(width: 146, height: 146))
        }
        let alertLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: FZM_BlackWordColor, textAlignment: NSTextAlignment.center, text: "点击复制红包链接")
        codeView.addSubview(alertLab)
        alertLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalToSuperview().offset(-10)
            m.size.equalTo(CGSize.init(width: 120, height: 16))
        }
        codeView.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(pasteClick)))
        
        let platView = FZMSharePlatformView.init { (clickIndex) in
            
        }
        centerView.addSubview(platView)
        platView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(19)
            m.right.equalToSuperview().offset(-19)
            m.bottom.equalToSuperview().offset(-30)
            m.height.equalTo(94)
        }
    }
    
    @objc func show() -> Void {
        UIApplication.shared.keyWindow?.addSubview(self)
    }
    
    @objc func hide() -> Void {
        self.removeFromSuperview()
    }
    
    @objc func centerClick() -> Void {
        
    }
    
    @objc func pasteClick() {
        UIPasteboard.general.string = self.shareUrl
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
