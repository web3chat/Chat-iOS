//
//  WalletDeatilSectionView.swift
//  chat
//
//  Created by fzm on 2022/1/24.
//

import Foundation
import UIKit

class WalletDeatilSectionView : UIView {
    
    private let bag = DisposeBag.init()
    
    lazy var smallBackView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.white
        let radius: CGFloat = 20
        let corner: UIRectCorner = [.topLeft, .topRight]
        let rect = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 95)
        let path: UIBezierPath = UIBezierPath(roundedRect: rect, byRoundingCorners: corner, cornerRadii: CGSize(width: radius, height: radius))
        let maskLayer: CAShapeLayer = CAShapeLayer()
        maskLayer.frame = rect;
        maskLayer.path = path.cgPath
        view.layer.mask = maskLayer
        return view
    }()
    
    lazy var logoImg : UIImageView = {
        let img = UIImageView.init(image: UIImage.init(named: "交易记录"))
        return img
    }()
    
    lazy var detailLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#333333")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "交易记录"
        return label
    }()
    
    lazy var lineView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.init(hexString: "#E6EAEE")
        return view
    }()
    
    
    lazy var allHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "全部")
        view.show(true)
        return view
    }()
    
    lazy var zzHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "转账")
        return view
    }()
    
    lazy var skHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "收款")
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.init(hexString: "#F6F7F8")
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        
        self.addSubview(self.smallBackView)
        self.addSubview(self.logoImg)
        self.addSubview(self.detailLabel)
        self.addSubview(self.lineView)
        self.addSubview(self.allHeader)
        self.addSubview(self.zzHeader)
        self.addSubview(self.skHeader)
        
        self.smallBackView.snp.makeConstraints { make in
            make.right.left.top.bottom.equalToSuperview()
        }
        
        self.logoImg.snp.makeConstraints { make in
            make.left.equalTo(19)
            make.top.equalTo(17)
            make.width.equalTo(14)
            make.height.equalTo(16)
        }
        
        self.detailLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.logoImg)
            make.left.equalTo(self.logoImg.snp.right).offset(8)
        }
        
        self.lineView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview().offset(49.5)
            make.height.equalTo(0.5)
        }
        
        self.allHeader.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(self.lineView.snp.bottom).offset(10)
            make.width.equalTo(70)
            make.height.equalTo(35)
        }
        
        
        self.zzHeader.snp.makeConstraints { make in
            make.left.equalTo(self.allHeader.snp.right).offset(5)
            make.top.equalTo(self.lineView.snp.bottom).offset(10)
            make.width.equalTo(70)
            make.height.equalTo(35)
        }
        
        self.skHeader.snp.makeConstraints { make in
            make.left.equalTo(self.zzHeader.snp.right).offset(5)
            make.top.equalTo(self.lineView.snp.bottom).offset(10)
            make.width.equalTo(70)
            make.height.equalTo(35)
        }
        
        
    }
    
    
}

