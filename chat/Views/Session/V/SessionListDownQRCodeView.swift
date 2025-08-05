//
//  SessionListDownQRCodeView.swift
//  chat
//
//  Created by fzm on 2021/11/30.
//

import Foundation
import UIKit
import SnapKit

class SessionListDownQRCodeView: UIView{
    
    private let bag = DisposeBag.init()
    
    private var showWallet = false
    
    private var textColor = APPNAME.contains("公安") ? .white : Color_24374E
    
    lazy var titleLabel : UILabel = {
        let label = UILabel.getLab(font: .boldFont(17), textColor: textColor, textAlignment: .center, text: "我的二维码")
        return label
    }()
    
    lazy var detailLabel : UILabel = {
        let label = UILabel.getLab(font: .regularFont(14), textColor: textColor, textAlignment: .center, text: "扫二维码加我好友")
        return label
    }()
    
    lazy var qrBackView : UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 10
        return view
    }()
    
    lazy var qrImgView : UIImageView = {
       let img = UIImageView()
        return img
    }()

    lazy var addressLabel : UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: textColor, textAlignment: .center, text: "")
        lab.minimumScaleFactor = 0.5
        lab.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        lab.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { (ges) in
            guard ges.state == .ended else { return }
            guard !LoginUser.shared().address.isEmpty else { return }
            UIPasteboard.general.string = LoginUser.shared().address
            self.showToast("地址已复制")
        }).disposed(by: self.bag)
        return lab
    }()
    
    lazy var transBackView : UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.init(red: 255, green: 255, blue: 255, transparency: 0.19)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5
        return view
    }()
    
    lazy var transImg : UIImageView = {
        let img = UIImageView.init(image: UIImage.init(named: "合并形状"))
        img.isUserInteractionEnabled = true
        img.tag = 1
        return img
    }()
    
    
    lazy var transLabel : UILabel = {
        let label = UILabel.getLab(font: .boldFont(16), textColor: textColor, textAlignment: .left, text: "转账")
        label.isUserInteractionEnabled = true
        label.tag = 1
        return label
    }()//形状结合-1
    
    lazy var transRightImg : UIImageView = {
        let img = UIImageView.init(image: UIImage.init(named: "形状结合-1"))
        img.isUserInteractionEnabled = true
        img.tag = 1
        return img
    }()
    
    
    lazy var lineView : UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.init(hexString: "#EBAE44")
        return view
    }()
    
    
    lazy var piaoImg : UIImageView = {
        let img = UIImageView.init(image: UIImage.init(named: "形状结合"))
        img.tag = 2
        img.isUserInteractionEnabled = true
        return img
    }()
    
    
    lazy var piaoLabel : UILabel = {
        let label = UILabel.getLab(font: .boldFont(16), textColor: textColor, textAlignment: .left, text: "票券")
        label.isUserInteractionEnabled = true
        label.tag = 2
        return label
    }()
    
    lazy var piaoRightImg : UIImageView = {
        let img = UIImageView.init(image: UIImage.init(named: "形状结合-1"))
        img.isUserInteractionEnabled = true
        img.tag = 2
        return img
    }()
    
    
    //转账=1  票券=2
    @objc func transferAccountsOrTicket(tag : Int){
        FZMLog(tag)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let modules = APP.shared().modules
        if modules.count > 0 {
            modules.forEach { item in
                if case .wallet = item.name {
                    if let _ = item.endPoints.first {
//                        WalletServerUrl = url
                        showWallet = true
                    }
                }
            }
        }
        
//        self.backgroundColor = showWallet ? .init(hexString: "#EBAE44") : Color_Theme
        self.backgroundColor = Color_Theme
        
        self.setSubViews()
        
//        self.detailLabel.text = showWallet ? "扫二维码向我转账、加我好友" : "扫二维码加我好友"
        self.detailLabel.text = "扫二维码加我好友"
        
        self.setData()
        
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: { [weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.transferAccountsOrTicket(tag: 1)
        }).disposed(by: bag)

        self.transImg.addGestureRecognizer(tap)
        self.transLabel.addGestureRecognizer(tap)
        self.transRightImg.addGestureRecognizer(tap)
        
        let tap1 = UITapGestureRecognizer.init()
        tap1.rx.event.subscribe(onNext: { [weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.transferAccountsOrTicket(tag: 2)
        }).disposed(by: bag)
        self.piaoImg.addGestureRecognizer(tap1)
        self.piaoLabel.addGestureRecognizer(tap1)
        self.piaoRightImg.addGestureRecognizer(tap1)
        
        self.addLoginObserver()
    }
    private func addLoginObserver() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(setData), name: FZM_Notify_UserLogin, object: LoginUser.shared())
    }
    
    @objc private func setData() {
        let address = LoginUser.shared().address
        self.addressLabel.attributedText = address.jointImage(image: #imageLiteral(resourceName: "blackcopy"))
        
        let qrCode = ShareURL + address
        self.qrImgView.image = QRCodeGenerator.setupQRCodeImage(qrCode, image: #imageLiteral(resourceName: "logo_120"))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSubViews(){
        self.addSubview(self.titleLabel)
        self.addSubview(self.detailLabel)
        self.addSubview(self.addressLabel)
        self.addSubview(self.qrBackView)
        self.qrBackView.addSubview(self.qrImgView)
        self.addSubview(self.transBackView)
//        self.transBackView.isHidden = !showWallet
        self.transBackView.isHidden = true
        self.transBackView.addSubview(self.transImg)
        self.transBackView.addSubview(self.transLabel)
        self.transBackView.addSubview(self.transRightImg)
        self.transBackView.addSubview(self.lineView)
        self.transBackView.addSubview(self.piaoImg)
        self.transBackView.addSubview(self.piaoLabel)
        self.transBackView.addSubview(self.piaoRightImg)
        
        self.titleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.top.equalTo(self).offset(13 + k_StatusBarHeight)
        }
        
        self.detailLabel.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(23)
        }
        
        self.qrBackView.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.size.equalTo(CGSize(width: 200 , height: 200))
            make.top.equalTo(self.detailLabel.snp.bottom).offset(12)
        }
        
        self.qrImgView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 170 , height: 170))
        }
        
        
        self.addressLabel.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.top.equalTo(self.qrBackView.snp.bottom).offset(15)
        }
        
        self.transBackView.snp.makeConstraints { make in
            make.top.equalTo(self.addressLabel.snp.bottom).offset(30)
            make.left.equalTo(35)
            make.right.equalTo(-35)
            make.height.equalTo(100)
        }
        
        self.transImg.snp.makeConstraints { make in
            make.left.top.equalTo(15)
            make.width.height.equalTo(20)
        }
        
        self.transLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.transImg)
            make.left.equalTo(self.transImg.snp.right).offset(10)
            make.height.equalTo(40)
            make.width.equalTo(300)
        }
        
        self.transRightImg.snp.makeConstraints { make in
            make.right.equalTo(-15)
            make.centerY.equalTo(self.transImg)
            make.width.equalTo(4)
            make.height.equalTo(20)
        }
        
        self.lineView.snp.makeConstraints { make in
            make.left.right.equalTo(0)
            make.top.equalTo(50)
            make.height.equalTo(0.5)
        }
        
        self.piaoImg.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.bottom.equalTo(-15)
            make.width.height.equalTo(20)
        }
        
        self.piaoLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.piaoImg)
            make.left.equalTo(self.piaoImg.snp.right).offset(10)
            make.height.equalTo(40)
            make.width.equalTo(300)
        }
        
        self.piaoRightImg.snp.makeConstraints { make in
            make.right.equalTo(-15)
            make.centerY.equalTo(self.piaoImg)
            make.width.equalTo(4)
            make.height.equalTo(20)
        }
        
        
    }
    
}
