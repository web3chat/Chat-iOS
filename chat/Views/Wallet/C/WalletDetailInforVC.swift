//
//  WalletDetailInforVC.swift
//  chat
//
//  Created by fzm on 2022/1/26.
//

import Foundation
import UIKit

class WalletDetailInforVC : UIViewController,ViewControllerProtocol{
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = Color_F9F9F9
        
        
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: "交易详情")
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
        self.title = "交易详情";
        self.view.backgroundColor = Color_F9F9F9
        self.initView()
    }
    
    func initView(){
        
    }
    
    @objc func clickBackAction(){
        self.navigationController?.popViewController(animated: true)
    }
    
}
