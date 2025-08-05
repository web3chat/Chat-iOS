//
//  WallwtHeadView.swift
//  chat
//
//  Created by fzm on 2022/1/21.
//

import Foundation
import UIKit


class WalletHeadView : UIView {
    
    private let bag = DisposeBag.init()
    
    lazy var topBackView : UIView = {
        let backView = UIView.init(frame: CGRect.init(x: 15, y: 0, width: k_ScreenWidth - 30, height: 65))
        backView.backgroundColor = UIColor.init(hexString: "#FCF0D3")
        backView.layer.cornerRadius = 6
        backView.layer.masksToBounds = true
        
        let lab1 = UILabel.getLab(font: .regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "红包账户有余额,")
        backView.addSubview(lab1)
        lab1.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(10)
        }
        
        let lab2 = UILabel.getLab(font: .regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "可提取至商品券！")
        backView.addSubview(lab2)
        lab2.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview().offset(-10)
        }
        
        let btn = UIButton.init(type: .custom)
        btn.setTitle("一键提取", for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.setBackgroundColor(color: UIColor.init(hexString: "#EBAE44")!, state: .normal)
        btn.titleLabel?.font = .boldFont(14)
        btn.layer.cornerRadius = 15
        btn.layer.masksToBounds = true
        backView.addSubview(btn)
        btn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-10)
            make.size.equalTo(CGSize.init(width: 100, height: 30))
        }
        return backView
    }()
    
    
    lazy var spqView : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "商品券", showType: .contact)
        view.show(true)
        
        let friendTap = UITapGestureRecognizer()
        friendTap.rx.event.subscribe { [weak self] (_) in
//            guard let strongSelf = self else { return }
//            strongSelf.showListViewAction(0)
        }.disposed(by: bag)
        view.addGestureRecognizer(friendTap)
        return view
    }()
    
    lazy var nftView : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "NFT", showType: .contact)
        
        let groupTap = UITapGestureRecognizer()
        groupTap.rx.event.subscribe { [weak self] (_) in
//            guard let strongSelf = self else { return }
//            strongSelf.showListViewAction(1)
        }.disposed(by: bag)
        view.addGestureRecognizer(groupTap)
        return view
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 125))
        self.backgroundColor = Color_EBAE44
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        
        self.addSubview(topBackView)
        self.addSubview(spqView)
        self.addSubview(nftView)
        spqView.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize.init(width: 55, height: 50))
            m.top.equalTo(topBackView.snp.bottom).offset(5)
        })
        nftView.snp.makeConstraints({ (m) in
            m.left.equalTo(spqView.snp.right).offset(15)
            m.size.equalTo(CGSize.init(width: 55, height: 50))
            m.top.equalTo(topBackView.snp.bottom).offset(5)
        })
        
        
    }
    
}

