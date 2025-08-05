//
//  WalletDetailHeadView.swift
//  chat
//
//  Created by fzm on 2022/1/21.
//

import Foundation
import UIKit

class WalletDetailHeadView : UIView {
    
    var skBlock: (()->())?

    
    private let bag = DisposeBag.init()
    
    lazy var smallBackView : UIView = {
        let view = UIView.init()
        view.backgroundColor = Color_EBAE44
        let radius: CGFloat = 20
        let corner: UIRectCorner = [.bottomLeft, .bottomRight]
        let rect = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 90)
        let path: UIBezierPath = UIBezierPath(roundedRect: rect, byRoundingCorners: corner, cornerRadii: CGSize(width: radius, height: radius))
        let maskLayer: CAShapeLayer = CAShapeLayer()
        maskLayer.frame = rect;
        maskLayer.path = path.cgPath
        view.layer.mask = maskLayer
        return view
    }()
    
    lazy var backView : UIImageView = {
        let view = UIImageView.init()
        view.image = UIImage.init(named: "wallet_white_bg")
        view.isUserInteractionEnabled = true
        return view
    }()
    
    lazy var titleLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_24374E
        label.font = UIFont.systemFont(ofSize: 16)
        label.text = "ABC"
        return label
    }()
    
    lazy var detailLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_24374E
        label.font = UIFont.systemFont(ofSize: 30)
        label.text = "64.00"
        return label
    }()
    
    lazy var qrcodeImgView : UIImageView = {
        let img = UIImageView.init()
        return img
    }()
    
    lazy var addressLabel : UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: UIColor.init(hexString: "#8A97A5"), textAlignment: .center, text: "")
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
    
    
    lazy var zzBtn : UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("转账", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.backgroundColor = UIColor.init(hexString: "#24374E")
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        return btn
    }()
    
    lazy var skBtn : UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("收款", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.backgroundColor = UIColor.init(hexString: "#EBAE44")
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.layer.cornerRadius = 20
        btn.addTarget(self, action: #selector(clickServer), for: .touchUpInside)
        btn.layer.masksToBounds = true
        return btn
    }()
    
    lazy var hzBtn : UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("划转至商城", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.backgroundColor = UIColor.init(hexString: "#32B2F7")
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        return btn
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 215))
        self.backgroundColor = Color_F6F7F8
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.addSubview(self.smallBackView)
        self.addSubview(self.backView)
        self.backView.addSubview(self.titleLabel)
        self.backView.addSubview(self.detailLabel)
        self.backView.addSubview(self.addressLabel)
        self.backView.addSubview(self.qrcodeImgView)
        self.addSubview(self.zzBtn)
        self.addSubview(self.skBtn)
        self.addSubview(self.hzBtn)
        let address = LoginUser.shared().address
        self.addressLabel.attributedText = address.jointImage(image: #imageLiteral(resourceName: "blackcopy"))
        
        self.smallBackView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(90)
        }
        
        self.backView.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(130)
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(15)
        }
        
        self.detailLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(10)
        }
        
        self.qrcodeImgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.width.height.equalTo(70)
        }
        
        self.addressLabel.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.left.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-15)
        }
        
        let width = (k_ScreenWidth - 40) / 3
        self.zzBtn.snp.makeConstraints { make in
            make.top.equalTo(self.backView.snp.bottom).offset(15)
            make.width.equalTo(width)
            make.height.equalTo(40)
            make.left.equalToSuperview().offset(15)
        }
        
        self.skBtn.snp.makeConstraints { make in
            make.top.equalTo(self.backView.snp.bottom).offset(15)
            make.width.equalTo(width)
            make.height.equalTo(40)
            make.left.equalTo(self.zzBtn.snp.right).offset(5)
        }
        
        self.hzBtn.snp.makeConstraints { make in
            make.top.equalTo(self.backView.snp.bottom).offset(15)
            make.width.equalTo(width)
            make.height.equalTo(40)
            make.left.equalTo(self.skBtn.snp.right).offset(5)
        }
    }
    
    @objc private func clickServer() {
        self.skBlock?()
    }
    
    
}
