
//
//  CreateSeedVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/5.
//

import UIKit

@objc class CreateSeedVC: UIViewController, ViewControllerProtocol {
    private let bag = DisposeBag.init()
    var topLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 30), textColor:UIColor.white, textAlignment: .left, text: "备份助记词")
        return lab
    }()
    
    var tipTopLab:UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor:UIColor.init(hexString: "#8E92A3"), textAlignment: .left, text: "请务必妥善保存助记词，确定之后将进行校验")
        return lab
    }()
    
    var midView:UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.init(hexString: "#333649")
        view.layer.borderColor = UIColor.init(hexString: "#ffffff")?.cgColor
        view.layer.borderWidth = 0.5
        view.layer.cornerRadius = 3
        view.clipsToBounds = true
        return view
    }()
    
    var seedLab:UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 18), textColor: .white, textAlignment: .center, text: "床前明 月光疑 是地上 霜举头 望明月")
        lab.numberOfLines = 0
        
        return lab
    }()
    
    
    var bottomView: UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.init(hexString: "#2b292f")
        return view
    }()
    
    var bottomTipLab:UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 13), textColor: .white, textAlignment: .left, text: "提示：请勿截图！如果有人获取你的助记词将直接获取你的资产！请抄写下助记词并存放在安全的地方，我们会再下一屏进行校验。")
        lab.numberOfLines = 0
        
        return lab
    }()
    
    lazy var changeBtn:UIButton = {
        let btn = UIButton.init()
        btn.setTitle("更换助记词", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.layer.borderColor = UIColor.init(hexString: "#ffffff")?.cgColor
        btn.layer.cornerRadius = 6
        btn.layer.borderWidth = 0.5
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(changeSeedBtnTouch), for: .touchUpInside)
       
        return btn
    }()
    
    lazy var backupBtn:UIButton = {
        let btn = UIButton.init()
        btn.setTitle("开始备份", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.backgroundColor = UIColor.init(hexString: "#7a90ff")
        btn.layer.cornerRadius = 6
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(backupBtnToucn), for: .touchUpInside)
       
        return btn
 
    }()
    
   
    
    
    private lazy var backBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage.init(named: "nav_back")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = .white
        btn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.navigationController?.popViewController(animated: true)
        }).disposed(by: self.bag)
        return btn
    }()
    
//    private lazy var indecatorView: UIView = {
//        let v = UIView.init()
//        v.backgroundColor = Color_Theme
//        return v
//    }()
    
    private lazy var seed: String? = nil { didSet { self.seedLab.text = seed } }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.xls_isNavigationBarHidden = true
        
        self.setupViews()
        
       
        self.setSeed(isChinese: false)
    }
    
    func setupViews(){
        self.view.backgroundColor = UIColor.init(hexString: "#333649")
        
        self.view.addSubview(self.backBtn)
        self.backBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 11, height: 20))
            m.left.equalToSuperview().offset(16)
            m.top.equalTo(self.view.safeAreaTop).offset(12)
        }
        
        self.view.addSubviews(self.topLab,self.tipTopLab,self.midView,self.seedLab,self.bottomView)
        topLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(backBtn).offset(20)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(110)
        }
        tipTopLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(topLab.snp.bottom).offset(30)
        }
        
        midView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(tipTopLab.snp.bottom).offset(20)
            make.height.equalTo(120)
        }
        seedLab.snp.makeConstraints { make in
            make.left.equalTo(midView).offset(15)
            make.right.equalTo(midView).offset(-15)
            make.top.bottom.equalTo(midView)
        }
        bottomView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(midView.snp.bottom).offset(70)
        }
        
        self.bottomView.addSubviews(self.bottomTipLab,self.changeBtn,self.backupBtn)
        let rect = self.bottomTipLab.text?.boundingRect(with: CGSize(width: k_ScreenWidth - 30, height: CGFloat(MAXFLOAT)),
                                                       options: .usesLineFragmentOrigin,
                                                        attributes: [.font:UIFont.systemFont(ofSize: 13)],
                                                       context: nil)
        bottomTipLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(rect!.size.height + 5)
            make.top.equalTo(self.bottomView.snp.top).offset(35);
        }
        let width = (k_ScreenWidth - 60) / 2
        let bottomSpace = -60;
        
        changeBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.width.equalTo(width)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(bottomSpace);
        }
       
        backupBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.width.equalTo(width)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(bottomSpace);
        }
        
    }
    
    private func getSeed(isChinese: Bool) -> String? {
        if isChinese {
            return SeedManager.createSeed(isChinses: true)?.components(separatedBy: " ").enumerated().makeIterator().map({ $0.offset % 3 == 0 ? " \($0.element)" : $0.element }).joined()
        } else {
            return SeedManager.createSeed(isChinses: isChinese)
        }
    }
    
    private func setSeed(isChinese: Bool) {
        let seed = SeedManager.createSeed(isChinses: isChinese)
        self.seed = seed
        if isChinese {
            self.seedLab.text = seed?.components(separatedBy: " ").enumerated().makeIterator().map({ $0.offset % 3 == 0 ? " \($0.element)" : $0.element }).joined()
        } else {
            self.seedLab.text = seed
        }
    }
    
    @objc private func changeSeedBtnTouch() {
        self.setSeed(isChinese: false)
    }
    
    
    @objc private func backupBtnToucn() {
        guard let seed = self.seed else { return }
        let vc = BackupSeedVC.init(seed: seed, isChinese: false)
        self.navigationController?.pushViewController(vc)
    }

//    private func setupViews() {
//        self.view.addSubview(self.indecatorView)
//        self.indecatorView.snp.remakeConstraints { (m) in
//            m.top.equalTo(self.backTitleLab.snp.bottom).offset(-5)
//            m.width.equalTo(self.backTitleLab.snp.width)
//            m.height.equalTo(4)
//            m.centerX.equalTo(self.backTitleLab)
//        }
//    }

//    func backBtnTouch(_ sender: UIButton) {
//        self.navigationController?.popViewController(animated: true)
//    }
    
//    @IBAction private func chineseBtnTouch(_ sender: UIButton) {
//        guard !sender.isSelected else { return }
//
//        self.setSeed(isChinese: true)
//
//        self.ChineseBtn.isSelected = true
//        self.EnglishBtn.isSelected = false
//        self.indecatorView.snp.remakeConstraints { (m) in
//            m.top.equalTo(self.ChineseBtn.snp.bottom).offset(-5)
//            m.width.equalTo(self.ChineseBtn.snp.width)
//            m.height.equalTo(4)
//            m.centerX.equalTo(self.ChineseBtn)
//        }
//        UIView.animate(withDuration: 0.3) {
//            self.view.layoutIfNeeded()
//        }
//
//    }
//
//
//    @IBAction private func englishBtnTouch(_ sender: UIButton) {
//        guard !sender.isSelected else { return }
//
//        self.setSeed(isChinese: false)
//
//        self.ChineseBtn.isSelected = false
//        self.EnglishBtn.isSelected = true
//        self.indecatorView.snp.remakeConstraints { (m) in
//            m.top.equalTo(self.EnglishBtn.snp.bottom).offset(-5)
//            m.width.equalTo(self.EnglishBtn.snp.width)
//            m.height.equalTo(4)
//            m.centerX.equalTo(self.EnglishBtn)
//        }
//        UIView.animate(withDuration: 0.3) {
//            self.view.layoutIfNeeded()
//        }
//    }
    
    
   
    
//    @IBAction func skipBackupTouch(_ sender: UIButton) {
//        guard let seed = self.seed else { return }
//        guard let keys = SeedManager.keyBy(seed: seed),
//              !keys.priKey.isEmpty,
//              !keys.pubKey.isEmpty,
//              !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
//            self.showToast("助记词解析错误, 请更换助记词")
//            return
//        }
//        let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
//        LoginUser.shared().login(seed: seed, priKey: keys.priKey, pubKey: keys.pubKey, address: address)
//
//        // 离线通知开启
//        AppDelegate.shared().umRegisterForRemoteNotifi()
//
//        APP.shared().reloadView()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            self.showBindAlert()
//        }
//    }
    
    private func showBindAlert() {
        let alert = TwoBtnInfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
        alert.leftBtnTitle = "绑定手机号"
        alert.rightBtnTitle = "绑定邮箱"
        let att1 = NSAttributedString.init(string: "\n您没有备份助记词，可通过绑定手机/邮箱和密聊密码加密上传至官方服务器，提供助记词找回服务。 为了您的账户安全，请务必自行备份或加密上传助记词，也可前往【安全管理】进行操作。\n\n", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_24374E])
        alert.attributedInfo = att1
        alert.leftBtnTouchBlock = {
            let vc = SecurityVC.init()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                vc.phoneBtnTouch(UIButton())
            }
            vc.hidesBottomBarWhenPushed = true
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
        alert.rightBtnTouchBlock = {
            let vc = SecurityVC.init()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                vc.emialBtnTouch(UIButton())
            }
            vc.hidesBottomBarWhenPushed = true
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
        alert.show()
    }
}
