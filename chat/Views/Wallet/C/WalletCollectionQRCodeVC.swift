//
//  WalletCollectionQRCodeVC.swift
//  chat
//
//  Created by fzm on 2022/1/24.
//

import Foundation
import UIKit

class WalletCollectionQRCodeVC : UIViewController,ViewControllerProtocol{
    
    private lazy var backView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var titleLabel : UILabel = {
        let label = UILabel.init()
        label.text = "扫二维码向我转账"
        label.textColor = UIColor.init(hexString: "#929EAB")
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var qrImgView : UIImageView = {
        let img = UIImageView.init()
        return img
    }()
    
    private lazy var addressLabel : UILabel = {
        let label = UILabel.init()
        label.text = "cdvidiosvdiosapprghuvvnivvvdsnvjdvfcdvsdnvKD"
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var copyBtn : UIButton = {
        let btn = UIButton.init()
        btn.setTitle("复制地址", for: .normal)
        btn.setTitleColor(UIColor.init(hexString: "#EBAE44"), for: .normal)
        btn.backgroundColor = UIColor.init(hexString: "#FCF0D3")
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        return btn
    }()
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = UIColor.init(hexString: "#EBAE44")
        
        
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: "二维码收款")
        navView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 100, height: 44))
        }
        
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "nav_back"), for: .normal)
        btn.addTarget(self, action: #selector(clickBackAction), for: .touchUpInside)
        btn.contentHorizontalAlignment = .left
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        navView.addSubview(btn)
        btn.snp.makeConstraints { make in
            make.size.equalTo(44)
            make.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(10)
        }
        
        return navView
    }()
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavBackgroundColor()
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor = Color_F6F7F8
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "二维码收款";
        self.initView()
    }
    
    
    private func initView(){
        self.view.backgroundColor = Color_EBAE44
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_isNavigationBarHidden = true
        self.view.addSubviews(self.navBarView)
        self.navBarView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(k_StatusNavigationBarHeight)
        }
        
        self.view.addSubview(self.backView)
        self.backView.addSubview(self.titleLabel)
        self.backView.addSubview(self.qrImgView)
        self.backView.addSubview(self.addressLabel)
        self.backView.addSubview(self.copyBtn)
        
        self.backView.snp.makeConstraints { make in
            make.top.equalTo(self.navBarView.snp.bottom).offset(50)
            make.centerX.equalToSuperview()
            make.left.equalToSuperview().offset(20)
            make.height.equalTo(415)
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(30)
        }
        
        self.qrImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(80)
            make.width.height.equalTo(170)
        }
        
        self.addressLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.left.equalTo(35)
            make.top.equalTo(self.qrImgView.snp.bottom).offset(30)
        }
        
        self.copyBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.left.equalTo(85)
            make.top.equalTo(self.addressLabel.snp.bottom).offset(15)
            make.height.equalTo(40)
        }
        
    }
    
    @objc func clickBackAction(){
        self.navigationController?.popViewController(animated: true)
    }
}
