//
//  FZMRedBagRecordVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/13.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

class FZMRedBagRecordVC: FZMBaseViewController {
    
    private var showReceive = true
    
    lazy var topView: UIView = {
        let v = UIView.init()
        v.backgroundColor = UIColor(hex: 0xE14D5C)
        let backBtn = UIButton.init()
        backBtn.setImage(UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate), for: .normal)
        backBtn.tintColor = UIColor.white
        backBtn.enlargeClickEdge(10, 10, 10, 10)
        backBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.navigationController?.popViewController(animated: true)
        }).disposed(by: disposeBag)
        v.addSubview(backBtn)
        backBtn.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview().offset(-17)
            m.height.equalTo(17)
            m.width.equalTo(10)
        })
        
        let segment = UISegmentedControl.init(items: ["收到红包","发出红包"])
        v.addSubview(segment)
        segment.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.centerY.equalTo(backBtn)
            m.height.equalTo(35)
            m.width.equalTo(200)
        })
        segment.setTitleTextAttributes([NSAttributedString.Key.font:UIFont.boldFont(17),
                                        NSAttributedString.Key.foregroundColor: UIColor.init(hex: 0xFBDA30) as Any], for: .normal)
        segment.setTitleTextAttributes([NSAttributedString.Key.font:UIFont.boldFont(17),
                                        NSAttributedString.Key.foregroundColor: UIColor.init(hex: 0xE14D5C) as Any], for: .selected)
        segment.selectedSegmentIndex = 0
        if #available(iOS 13, *) {
            segment.setBackgroundImage(UIImage.imageWithColor(with: UIColor.init(hex: 0xFBDA30), size: CGSize.init(width: 100, height: 35)), for: .selected, barMetrics: .default)
            segment.setBackgroundImage(UIImage.imageWithColor(with: UIColor.clear, size: CGSize.init(width: 100, height: 35)), for: .normal, barMetrics: .default)
        } else {
            segment.tintColor = UIColor.init(hex: 0xFBDA30)
        }
        
        segment.layer.cornerRadius = 35 * 0.5
        segment.layer.masksToBounds = true
        segment.layer.borderColor = UIColor.init(hex: 0xFBDA30).cgColor
        segment.layer.borderWidth = 1
        
        segment.rx.controlEvent(UIControl.Event.valueChanged).subscribe(onNext: {[weak self] () in
           self?.changeType()
        }).disposed(by: disposeBag)
        
        return v
    }()

    let receiveTableView = FZMRedBagRecordView.init(with:.receive)
    
    
    let sendTableView = FZMRedBagRecordView.init(with: .send)
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.navBarColor = UIColor.init(hex: 0xE14D5C)
        self.view.backgroundColor = UIColor.init(hex: 0xf1ecec)
        self.createUI()
    }
    
    func createUI() -> Void {
        
        self.view.addSubview(topView)
        topView.snp.makeConstraints { (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(k_StatusNavigationBarHeight - 64 + 74)
        }
        
        self.sendTableView.didFilterDateBlock = {[weak self] (coinId, date, isAllYear) in
            self?.receiveTableView.didFilterDate(coinId: coinId, date: date, isAllYear: isAllYear)
        }
        
        self.view.addSubview(self.sendTableView)
        sendTableView.snp.makeConstraints { (m) in
            m.top.equalTo(topView.snp.bottom)
            m.bottom.left.right.equalToSuperview()
        }
        
        self.receiveTableView.didFilterDateBlock = {[weak self] (coinId, date, isAllYear) in
            self?.sendTableView.didFilterDate(coinId: coinId, date: date, isAllYear: isAllYear)
        }
        
        self.view.addSubview(self.receiveTableView)
        receiveTableView.snp.makeConstraints { (m) in
            m.top.equalTo(topView.snp.bottom)
            m.bottom.left.right.equalToSuperview()
        }
        
    }
   
    @objc func changeType(){
        showReceive = !showReceive
        if showReceive {
            self.view.bringSubviewToFront(self.receiveTableView)
        } else {
            self.view.bringSubviewToFront(self.sendTableView)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}



