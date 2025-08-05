//
//  IMRedBagInfoVC.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/16.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class FZMRedBagInfoVC: FZMBaseViewController {
    
    private var packetId = ""
        
    private var packetModel : IMRedPacketModel? {
        didSet {
            guard let packet = self.packetModel else { return}
            userHeadImageView.loadNetworkImage(with: packet.senderAvatar, placeImage: UIImage(named: "open_bag_humanhead"))
            remarkLab.text = packet.remark
            if packet.revInfo.amount == 0 {
                if packet.status == .receiveAll  || packet.status == .opened {
                    totalLab.text = "红包已领完"
                    totalLab.textColor = UIColor.init(hex: 0xFFB7B7)
                }
                if packet.status == .past {
                    totalLab.text = "红包已过期"
                    totalLab.textColor = UIColor.init(hex: 0xFFB7B7)
                }
               
            } else {
                totalLab.text = "\(packet.revInfo.amount) " + "\(packet.coinName)"
                totalLab.textColor = UIColor.white
            }
            remainLab.text = "已领取\(packet.size - packet.remain)/\(packet.size)个，余\(packet.remain)个"
            sharedBtn.isHidden = true
            
//            IMContactManager.shared().requestUserModel(with: packet.senderId) { (user, _, _) in
//                guard let user = user else { return }
//                let text = "\(user.showName)的\(packet.coinName)红包 "
//                let str = NSMutableAttributedString.init(string: text, attributes: [NSAttributedString.Key.font: UIFont.boldFont(16), NSAttributedString.Key.foregroundColor:UIColor.white])
//
//                if packet.type == .luck {
//                    let ach = NSTextAttachment.init()
//                    ach.image = GetBundleImage("send_bag_many")
//                    ach.bounds = CGRect.init(x: 0, y: -4, width: 20, height: 20)
//                    let imgText = NSAttributedString.init(attachment: ach)
//                    str.insert(imgText, at: str.length)
//                }
//
//                self.accountLab.attributedText = str
//            }
        }
    }
    
    
    lazy var accountLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(16), textColor: UIColor.white, textAlignment: .center, text: "")
        lab.lineBreakMode = .byTruncatingMiddle
        return lab
    }()
    
    let remarkLab = UILabel.getLab(font: UIFont.boldFont(14), textColor: UIColor.init(hex: 0xFFC3C9), textAlignment: .center, text: "")
    
    let totalLab = UILabel.getLab(font: UIFont.boldFont(40), textColor: UIColor.white, textAlignment: .center, text: "")
    
    lazy var userHeadImageView : UIImageView = {
        let view = UIImageView.init(image: UIImage(named:"open_bag_humanhead"))
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        return view
    }()
    
    lazy var headerView : UIView = {
    
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 270))
        view.backgroundColor = UIColor(hex: 0xE14D5C)
        let headImV = UIImageView.init(image: UIImage(named:"open_bag_topbar"))
        headImV.backgroundColor = UIColor(hex: 0xFAFBFC)
        view.addSubview(headImV)
        headImV.snp.makeConstraints({ (m) in
            m.bottom.left.right.equalTo(view)
            m.height.equalTo(50)
        })
        view.addSubview(userHeadImageView)
        userHeadImageView.snp.makeConstraints({ (m) in
            m.top.equalTo(view)
            m.centerX.equalTo(view)
            m.size.equalTo(CGSize.init(width: 60, height: 60));
        })
        
        view.addSubview(accountLab)
        accountLab.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.top.equalTo(userHeadImageView.snp.bottom).offset(8)
            m.height.equalTo(17)
        })
        
        view.addSubview(remarkLab)
        remarkLab.snp.makeConstraints({ (m) in
            m.centerX.equalTo(view)
            m.top.equalTo(accountLab.snp.bottom).offset(10)
            m.height.equalTo(20)
        })
        
        view.addSubview(totalLab)
        totalLab.snp.makeConstraints({ (m) in
            m.centerX.equalTo(view)
            m.top.equalTo(remarkLab.snp.bottom).offset(30)
            m.height.equalTo(56)
        })
        let btn : UIButton = UIButton(type: UIButton.ButtonType.custom)
        btn.backgroundColor =  UIColor(hex: 0xE14D5C)
        btn.layer.cornerRadius = 3.0
        btn.clipsToBounds = true
        btn.setAttributedTitle(NSAttributedString.init(string: "查看资产", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(16)]), for: UIControl.State.normal)
        btn.addTarget(self, action: #selector(checkBalance), for: UIControl.Event.touchUpInside)
        view.addSubview(btn)
        btn.snp.makeConstraints({ (m) in
            m.centerX.equalTo(view)
            m.bottom.equalTo(view).offset(-20)
            m.size.equalTo(CGSize.init(width: 150, height: 40))
        })
        btn.isHidden = true
        
        return view
    }()
    
    let remainLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_24374E, textAlignment: NSTextAlignment.center, text: "")
    lazy var sharedBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("分享红包", for: .normal)
        btn.setTitleColor(UIColor.init(hex: 0xE14D5C), for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(14)
        btn.addTarget(self, action: #selector(shareBtnClick), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    lazy var sectionHeaderView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 40))
        view.backgroundColor = UIColor(hex: 0xFAFBFC)
        view.addSubview(remainLab)
        remainLab.snp.makeConstraints { (m) in
            m.centerY.equalTo(view)
            m.left.equalTo(view).offset(15)
        }
        view.addSubview(sharedBtn)
        sharedBtn.snp.makeConstraints({ (m) in
            m.centerY.equalTo(remainLab)
            m.right.equalTo(view).offset(-15)
            m.width.equalTo(70)
            m.height.equalTo(20)
        })
        return view
    }()
    
    private var dataArray = [IMRedPacketReceiveModel]()
    
    lazy var tableView : UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: UITableView.Style.plain)
        view.backgroundColor = UIColor(hex: 0xFAFBFC)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.rowHeight = 80
        view.tableHeaderView = headerView
        view.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat.leastNormalMagnitude))
        view.delegate = self
        view.dataSource = self
        view.bounces = false
        view.register(FZMRedBagReceiveCell.self, forCellReuseIdentifier: "FZMRedBagReceiveCell")
        
        return view
    }()
    private let isShowRecord: Bool
    init(with packetId : String, isShowRecord: Bool = true) {
        self.packetId = packetId
        self.isShowRecord = isShowRecord
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(hex: 0xFAFBFC)
        
//        self.navBarColor = UIColor(hex: 0xE14D5C)
//        self.navTintColor = UIColor.white
//        self.navTitleColor = UIColor.white
        
        self.createUI()

        self.getRedPacketInfo()
        
        self.getRedPacketReceiveDetail()
    }
    
    func getRedPacketInfo() {
        self.showProgress(with: nil)
//        HttpConnect.shared().getRedPacketInfo(packetId: self.packetId) { (packet, response) in
//            self.hideProgress()
//            guard response.success else{
//                self.showToast(with: response.message)
//                return
//            }
//            guard let packet = packet else {
//                return
//            }
//            self.packetModel = packet
//        }
    }
    
    func getRedPacketReceiveDetail() {
//        HttpConnect.shared().redPacketReceiveDetail(packetId: self.packetId) { (arr, response) in
//            guard response.success else{
//                self.showToast(with: response.message)
//                return
//            }
//            guard let array = arr else {return}
//            self.dataArray = array
//            self.tableView.reloadData()
//        }
    }
    
    
    @objc func pushToRecord() -> Void {
        //查看记录
        let vc = FZMRedBagRecordVC.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func checkBalance(){
        //查看资产
    }
    
    func createUI() -> Void {
        if isShowRecord {
            let btn = UIButton.init(type: .custom)
            btn.addTarget(self, action: #selector(pushToRecord), for: .touchUpInside)
            btn.setTitle("红包记录", for: .normal)
            btn.titleLabel?.font = UIFont.boldFont(14)
            btn.setTitleColor(UIColor.init(hex: 0xFFDF5F), for: .normal)
            let item = UIBarButtonItem.init(customView: btn)
            self.navigationItem.rightBarButtonItem = item
        }
        
        self.view.addSubview(self.tableView)
        tableView.snp.makeConstraints { (m) in
            m.top.left.right.equalToSuperview()
            m.bottom.equalToSuperview()
        }
    }
    
    @objc func shareBtnClick(){
//        let shareView = FZMShareAlertView.init()
//        UIApplication.shared.keyWindow?.addSubview(shareView)
//        shareView.shareBlock = {[weak self] (platment) in
//            if let packetUrl = self?.packetModel?.packetUrl, !packetUrl.isEmpty {
//                IMSDK.shared().shareDelegate?.shareRedBag(url: packetUrl, coinName: self?.packetModel?.coinName ?? "", platment: platment)
//            }
//        }
//        shareView.show()
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension FZMRedBagInfoVC : UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionHeaderView
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataArray.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : FZMRedBagReceiveCell = tableView.dequeueReusableCell(withIdentifier: "FZMRedBagReceiveCell", for: indexPath) as! FZMRedBagReceiveCell
        let receiveModel = self.dataArray[indexPath.row]
        cell.configureWithData(receive: receiveModel)
        return cell
    }
    
}


