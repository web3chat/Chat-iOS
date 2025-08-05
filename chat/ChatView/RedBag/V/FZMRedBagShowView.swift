//
//  IMRedBagShowView.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/11.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class FZMRedBagShowView: UIView {
    //是否为新人红包
    var isNew : Bool = false
    
    var packet : Message
    
    var openCompleteBlock : (()->())?
    
    var seeDetailInfoBlock : (()->())?
    
    var receiveAllBlock : (()->())?
    
    var pastBlock : (()->())?
    
    var inputAccountBlock : ((String,Double)->())?
    
    //中间视图
    lazy var centerView : UIView = {
        let view = UIView()
        view.layer.cornerRadius = 10.0
        view.clipsToBounds = true
        return view
    }()
    
    //红包视图
    lazy var redBagView : UIView = {
        let view = UIView()
        let bottomView = UIImageView.init(image: UIImage(named:"open_bag_bg")?.withRenderingMode(.alwaysOriginal))
        view.addSubview(bottomView)
        bottomView.snp.makeConstraints({ (m) in
            m.edges.equalToSuperview()
        })
        return view
    }()
    
    lazy var pastView: UIView = {
       let v = UIView.init()
        v.backgroundColor = UIColor.init(hex: 0xE14D5C)
        let lab = UILabel.getLab(font: UIFont.boldFont(30), textColor: UIColor.init(hex: 0xFBDA30), textAlignment: .center, text: "红包已过期")
        v.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(103)
            m.centerX.equalToSuperview()
            m.height.equalTo(30)
        })
        let lab2 = UILabel.getLab(font: UIFont.regularFont(17), textColor: UIColor.init(hex: 0xFBDA30), textAlignment: .center, text: "超过24小时未领取的红包将会\n被退回至原账户")
        lab2.numberOfLines = 0
        v.addSubview(lab2)
        lab2.snp.makeConstraints({ (m) in
            m.top.equalTo(lab.snp.bottom).offset(35)
            m.centerX.equalToSuperview()
        })
        v.isHidden = true
        return v
    }()
    
    //二维码展示视图
    lazy var codeShowView : UIView = {
        let view = UIView()
        view.backgroundColor = FZM_LuckyPacketColor
        let backBtn = UIButton(type: UIButton.ButtonType.custom)
        backBtn.setImage(UIImage(named: "nav_back_blue"), for: UIControl.State.normal)
        backBtn.addTarget(self, action: #selector(backRedBagBtnClick), for: UIControl.Event.touchUpInside)
        view.addSubview(backBtn)
        backBtn.snp.makeConstraints({ (m) in
            m.top.equalTo(view).offset(22)
            m.left.equalTo(view).offset(20)
            m.size.equalTo(CGSize.init(width: 9, height: 16))
        })
        let backTitleBtn = UIButton(type: UIButton.ButtonType.custom)
        backTitleBtn.setAttributedTitle(NSAttributedString.init(string: "打开红包", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(15)]), for: UIControl.State.normal)
        backTitleBtn.addTarget(self, action: #selector(backRedBagBtnClick), for: UIControl.Event.touchUpInside)
        backTitleBtn.enlargeClickEdge( 20, 20, 20, 20)
        view.addSubview(backTitleBtn)
        backTitleBtn.snp.makeConstraints({ (m) in
            m.centerY.equalTo(backBtn)
            m.left.equalTo(backBtn.snp.right).offset(10)
            m.size.equalTo(CGSize.init(width: 60, height: 16))
        })
        let platView = FZMSharePlatformView.init { (clickIndex) in
            
        }
        view.addSubview(platView)
        platView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(19)
            m.right.equalToSuperview().offset(-19)
            m.bottom.equalToSuperview().offset(-30)
            m.height.equalTo(94)
        }
        return view
    }()
    
    //打开红包按钮
    lazy var openBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(named:"open_bag_btn"), for: .normal)
        btn.addTarget(self, action: #selector(openBtnClick), for: .touchUpInside)
        return btn
    }()
    
    //查看分享按钮
    lazy var shareBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setAttributedTitle(NSAttributedString.init(string: "查看/分享红包二维码", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(15)]), for: UIControl.State.normal)
        btn.addTarget(self, action: #selector(shareBtnClick), for: .touchUpInside)
        return btn
    }()
    
    lazy var receiveCompleteView : UIImageView = {
        let imageView = UIImageView(image: UIImage(named:"open_bag_receiveall"))
        imageView.isUserInteractionEnabled = true
        let btn = UIButton(type: .custom)
        btn.setAttributedTitle(NSAttributedString.init(string: "查看领取详情", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(15)]), for: UIControl.State.normal)
        btn.addTarget(self, action: #selector(detailBtnClick), for: .touchUpInside)
        imageView.addSubview(btn)
        btn.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalToSuperview().offset(-13)
            m.size.equalTo(CGSize(width: 100, height: 45))
        })
        return imageView
    }()
    
    init(packet : Message , sendId : String, isPast: Bool = false) {
        self.packet = packet
        let new = packet.packetType == .promote
        self.isNew = new
        super.init(frame: k_ScreenBounds)
        let backCtrl = UIControl.init(frame: k_ScreenBounds)
        backCtrl.addTarget(self, action: #selector(hide), for: .touchUpInside)
        self.addSubview(backCtrl)
        self.backgroundColor = UIColor.init(white: 0, alpha: 0.3)
        self.addSubview(centerView)
        centerView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 303, height: 450))
        }
        centerView.addSubview(redBagView)
        redBagView.snp.makeConstraints { (m) in
            m.size.equalToSuperview()
            m.top.equalToSuperview()
            m.right.equalToSuperview()
        }
        redBagView.addSubview(openBtn)
        openBtn.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalToSuperview().offset(-87)
            m.size.equalTo(CGSize.init(width: 107, height: 107))
        }
        let headImageView = UIImageView.init(image: UIImage(named: "open_bag_humanhead"))
        headImageView.layer.cornerRadius = 5
        headImageView.clipsToBounds = true
        redBagView.addSubview(headImageView)
        headImageView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(33)
            m.size.equalTo(CGSize.init(width: 60, height: 60))
        }
        let uidLab = UILabel.getLab(font: UIFont.regularFont(16), textColor: UIColor.white, textAlignment: NSTextAlignment.center, text: nil)
        redBagView.addSubview(uidLab)
        uidLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.top.equalTo(headImageView.snp.bottom).offset(10)
            m.height.equalTo(17)
        }
        let alertLab = UILabel.getLab(font: UIFont.regularFont(14), textColor:UIColor.white, textAlignment: NSTextAlignment.center, text: "发了一个\(self.packet.coinname ?? "")红包")
        redBagView.addSubview(alertLab)
        alertLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(uidLab.snp.bottom).offset(5)
            m.height.equalTo(17)
        }
        
//        IMContactManager.shared().requestUserModel(with: packet.fromId) { (user, _, _) in
//            guard let user = user else { return }
//            uidLab.text = user.showName
//            headImageView.loadNetworkImage(with: user.avatar.getDownloadUrlString(width: 65), placeImage: GetBundleImage("open_bag_humanhead"))
//        }
        
        if isNew {
            let noteImageView = UIImageView.init(image: UIImage(named: "open_bag_newnote"))
            redBagView.addSubview(noteImageView)
            noteImageView.snp.makeConstraints { (m) in
                m.centerX.equalToSuperview()
                m.top.equalTo(alertLab.snp.bottom).offset(30)
                m.size.equalTo(CGSize.init(width: 238, height: 61))
            }
            shareBtn.setAttributedTitle(NSAttributedString.init(string: "红包二维码", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(15)]), for: UIControl.State.normal)
            redBagView.addSubview(shareBtn)
            shareBtn.snp.makeConstraints { (m) in
                m.left.equalToSuperview().offset(18)
                m.bottom.equalToSuperview().offset(-25)
                m.size.equalTo(CGSize.init(width: 80, height: 20))
            }
            let detailBtn = UIButton(type: UIButton.ButtonType.custom)
            detailBtn.setAttributedTitle(NSAttributedString.init(string: "领取详情", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(15)]), for: UIControl.State.normal)
            detailBtn.addTarget(self, action: #selector(detailBtnClick), for: .touchUpInside)
            redBagView.addSubview(detailBtn)
            detailBtn.snp.makeConstraints { (m) in
                m.right.equalToSuperview().offset(-18)
                m.bottom.equalToSuperview().offset(-25)
                m.size.equalTo(CGSize.init(width: 70, height: 20))
            }
        }else{
            let remaek = "" // packet.body.remark.count > 20 ? (packet.body.remark.substring(to: 20) + "...") : packet.body.remark
            let noteLab = UILabel.getLab(font: UIFont.boldFont(25), textColor: UIColor.init(hex: 0xFBDA30), textAlignment: NSTextAlignment.center, text: remaek)
            redBagView.addSubview(noteLab)
            noteLab.numberOfLines = 0
            noteLab.snp.makeConstraints { (m) in
                m.left.equalToSuperview().offset(10)
                m.right.equalToSuperview().offset(-10)
                m.top.equalTo(alertLab.snp.bottom).offset(36)
            }

        }
        
        centerView.addSubview(codeShowView)
        codeShowView.snp.makeConstraints { (m) in
            m.size.equalToSuperview()
            m.top.equalToSuperview()
            m.left.equalTo(redBagView.snp.right)
        }
        let codeView = UIView.init()
        codeView.backgroundColor = UIColor.white
        codeView.layer.cornerRadius = 5.0
        codeView.clipsToBounds = true
        codeShowView.addSubview(codeView)
        codeView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(66)
            m.size.equalTo(CGSize.init(width: 180, height: 200))
        }
        let image = QRCodeGenerator.setupQRCodeImage("http://www.--ffe--ses.com", image: nil)
        let qrImageView = UIImageView.init(image: image)
        codeView.addSubview(qrImageView)
        qrImageView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(19)
            m.size.equalTo(CGSize.init(width: 150, height: 150))
        }
        let pasteLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: FZM_BlackWordColor, textAlignment: NSTextAlignment.center, text: "点击复制红包链接")
        codeView.addSubview(pasteLab)
        pasteLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalToSuperview().offset(-10)
            m.size.equalTo(CGSize.init(width: 120, height: 16))
        }
        codeView.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(pasteClick)))
        
        redBagView.addSubview(pastView)
        pastView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.height.equalTo(225)
            m.top.equalToSuperview().offset(10)
        }
        
        if isPast {
            self.pastView.isHidden = false
            self.openBtn.isHidden = true
        }
    }
    
    @objc func show() -> Void {
        UIApplication.shared.keyWindow?.addSubview(self)
    }
    
    @objc func hide() -> Void {
        self.removeFromSuperview()
    }
    
    //开红包
    @objc func openBtnClick() -> Void {
        self.showProgress(with: nil)
//        HttpConnect.shared().receiveRedPacket(packetId: self.packet.body.packetId) { (response) in
//            self.hideProgress()
//            guard response.success || response.code == -4009 else {
//                if response.code == -4001 {
//                    self.showReceiveComplete()
//                }else if response.code == -4013 {
//                    self.pastView.isHidden = false
//                    self.openBtn.isHidden = true
//                    self.pastBlock?()
//                } else{
//                    self.showToast(with: response.message)
//                }
//                return
//            }
//            self.openCompleteBlock?()
//            self.hide()
//        }
    }
    //查看分享
    @objc func shareBtnClick() -> Void {
        self.setNeedsUpdateConstraints()
        redBagView.snp.remakeConstraints { (m) in
            m.size.equalToSuperview()
            m.top.equalToSuperview()
            m.right.equalTo(centerView.snp.left)
        }
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    //查看领取详情
    @objc func detailBtnClick() -> Void {
        self.hide()
        self.seeDetailInfoBlock?()
    }
    //返回红包
    @objc func backRedBagBtnClick() -> Void {
        self.setNeedsUpdateConstraints()
        redBagView.snp.remakeConstraints { (m) in
            m.size.equalToSuperview()
            m.top.equalToSuperview()
            m.right.equalTo(centerView.snp.right)
        }
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    //展示领取完页面
    func showReceiveComplete(){
//        centerView.addSubview(receiveCompleteView)
//        receiveCompleteView.snp.makeConstraints { (m) in
//            m.edges.equalToSuperview()
//        }
        self.hide()
        self.receiveAllBlock?()
    }
    //复制红包链接
    @objc func pasteClick() -> Void {
        UIPasteboard.general.string = "jkllll"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
