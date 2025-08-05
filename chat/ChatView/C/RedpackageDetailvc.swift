//
//  RedpackageDetailvc.swift
//  chat
//
//  Created by 郑晨 on 2025/6/6.
//

//

import Foundation
import UIKit
import SwiftUI
import SnapKit

class RedpackageDetailvc: UIViewController ,ViewControllerProtocol {
    
  
    private let detail : String//邀请人id
   
    // 红包用户
    lazy var nameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(17), textColor: Color_FFFFFF, textAlignment: .left, text: "")
        lab.numberOfLines = 0
        lab.minimumScaleFactor = 0.5
        return lab
    }()
    lazy var titleLab : UILabel = {
        return UILabel.getLab(font: UIFont.boldFont(24), textColor: Color_FFFFFF, textAlignment: .center, text: "恭喜发财 大吉大利！")
    }()
    // 时间
    lazy var timeLab : UILabel = {
        return UILabel.getLab(font: UIFont.mediumFont(14), textColor: Color_FFFFFF, textAlignment: .left, text: "")
    }()
    //
    lazy var balanceLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(17), textColor: Color_FFFFFF, textAlignment: .right, text: "")
        lab.numberOfLines = 0
        lab.minimumScaleFactor = 0.5
        return lab
    }()

    init(with detail:String){
        self.detail = detail
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.createUI()
        self.title = "红包领取详情"
        self.view.backgroundColor = Color_DD5F5F
        
    }
    
    private func createUI() {
       
        let redArr = self.detail.split(separator: ",").map(String.init)
        if redArr.count > 0 {
            let addr = redArr[0]
            let time = redArr[2]
            let balance = redArr[1]
            nameLab.text = addr.shortAddress
            timeLab.text = time
            balanceLab.text = balance
        }
        
        self.view.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(20)
            m.right.equalToSuperview().offset(-15)
            m.height.greaterThanOrEqualTo(50)
        }
        
        self.view.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(titleLab.snp.bottom).offset(30)
            m.right.equalToSuperview().offset(-105)
            m.height.greaterThanOrEqualTo(20)
        }
        nameLab.numberOfLines = 2
        
        self.view.addSubview(balanceLab)
        balanceLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(nameLab)
            m.height.greaterThanOrEqualTo(20)
        }
        
        self.view.addSubview(timeLab)
        timeLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(nameLab.snp.bottom).offset(5)
            m.right.equalToSuperview().offset(-15)
            m.height.greaterThanOrEqualTo(20)
        }
       
    }
    
}


