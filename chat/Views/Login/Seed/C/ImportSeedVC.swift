//
//  ImportSeedVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/5.
//

import UIKit
import SnapKit
import Foundation

@objc class ImportSeedVC: UIViewController, ViewControllerProtocol {
    
    @objc var seed: NSString = "111"
    
    private lazy var placeholderLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 18), textColor: Color_8A97A5, textAlignment: .left, text: "请输入助记词，用空格分隔")
        return lab
    }()
    
   @objc lazy var seedTextView: UITextView = {
        let tv = UITextView.init()
        tv.textColor = Color_24374E
        tv.font = .mediumFont(18)
        tv.backgroundColor = .clear
        tv.tintColor = Color_Theme
        return tv
    }()
    
    private lazy var topView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 6
        view.layer.masksToBounds = true
        
        view.addSubview(seedTextView)
        seedTextView.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(15)
            make.right.bottom.equalToSuperview().offset(-15)
        }
        
        view.addSubview(placeholderLab)
        placeholderLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(23)
        }
        
        return view
    }()
    
    private lazy var briefLab: UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_Theme, textAlignment: .center, text: "支持导入所有遵循BIP标准生成的助记词")
    }()
    
    private lazy var importBtn: UIButton = {
        let btn = UIButton.getNormalBtn(with: "开始导入", backgroundColor: Color_Theme)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.addTarget(self, action: #selector(importBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    private let bag = DisposeBag.init()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setNavBackgroundColor()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "导入助记词"
        
        self.xls_isNavigationBarHidden = false
        
        self.setupViews()
        
        self.setRx()
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor = .white
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    private func setupViews() {
        self.view.backgroundColor = .white
        
        self.view.addSubview(self.topView)
        topView.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(110)
        }
        
        self.view.addSubview(self.briefLab)
        briefLab.snp.makeConstraints { make in
            make.top.equalTo(topView.snp.bottom).offset(15)
            make.centerX.equalToSuperview()
        }
        
        self.view.addSubview(importBtn)
        importBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(briefLab.snp.bottom).offset(50)
            make.height.equalTo(44)
        }
    }
    
    func setRx() {
        self.seedTextView.rx.text.orEmpty.subscribe(onNext: {[weak self] (text) in
            self?.placeholderLab.isHidden = !text.isEmpty
            self?.importBtn.isEnabled = !text.isEmpty
            self?.importBtn.backgroundColor = text.isEmpty ? Color_CCD1E0 : Color_Theme
        }).disposed(by: self.bag)
    }
    
    
    @objc private func importBtnTouch() {
        // 皱筛北 喜易络 车串戈 离纤宴 付倒抹
        self.view.endEditing(true)
        guard let seed = self.seedTextView.text else { return }
        let devidedSeedBef = seed.isIncludeChinese ? seed.replacingOccurrences(of: " ", with: "").enumerated().compactMap { $0.offset % 1 == 0 ? " " + String($0.element) : String($0.element)
        }.joined() : seed
        let devidedSeed = devidedSeedBef.trimmingCharacters(in: CharacterSet.whitespaces)
        
        guard let keys = SeedManager.keyBy(seed: devidedSeed),
              !keys.priKey.isEmpty,
              !keys.pubKey.isEmpty,
              !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                  self.showToast("助记词错误")
                  return
              }
        let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
        LoginUser.shared().login(seed: seed, priKey: keys.priKey, pubKey: keys.pubKey, address: address)
     
        // 离线通知开启
        AppDelegate.shared().umRegisterForRemoteNotifi()
        APP.shared().reloadView()
       
        let precoin = PreCoin.init()
        self.seed = devidedSeed as NSString
        precoin.add(intoW: devidedSeed)
    }
    
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
