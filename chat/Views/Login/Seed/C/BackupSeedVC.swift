//
//  BackupSeedVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/6.
//

import UIKit
import SnapKit

@objc class BackupSeedVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
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
    
    private lazy var topLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 14), textColor: UIColor.init(hexString: "#8E92A3"), textAlignment: .center, text: "验证您备份的助记词")
        return lab
    }()
    
    private lazy var bottomLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 13), textColor: UIColor.white, textAlignment: .left, text: "请按照正确的顺序点击每个单词")
        return lab
    }()
    
    lazy var topSeedView: SeedCollectionView = {
        let v = SeedCollectionView.init(isChinese: self.isChinese, isGroup: self.isChinese, alwaysSelected: true)
        v.selectBlock = {[weak self] (index) in
            guard let self = self else { return }
            let text = self.backupSeed[index]
            self.backupSeed.remove(at: index)
            guard let indexInSeed = self.disorderSeed.enumerated().makeIterator().filter({ $0.element == text }).first?.offset else { return }
            self.bottomSeedView.deselectItem(at: IndexPath.init(row: indexInSeed, section: 0), animated: false)
        }
        return v
    }()
    
    lazy var bottomSeedView: SeedCollectionView = {
        let v = SeedCollectionView.init(isChinese: self.isChinese, isGroup: false, alwaysSelected: false)
        v.selectBlock = {[weak self] (index) in
            guard let self = self else { return }
            let text = self.disorderSeed[index]
            self.backupSeed.append(text)
        }
        return v
    }()
    
    lazy var okBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("确定", for: .normal)
        btn.layer.cornerRadius = 6
        btn.backgroundColor = UIColor.init(hexString: "#5D6377")
        btn.addTarget(self, action: #selector(okBtnTouch), for: .touchUpInside)
        btn.isEnabled = false
        return btn
    }()
    
   @objc let seed: String
    private let disorderSeed: [String]
    private let isChinese: Bool
    
    
    private var backupSeed = [String]() {
        didSet {
            self.topSeedView.seed = backupSeed
            self.setOkBtnStatus()
        }
    }
    
    init(seed: String, isChinese: Bool) {
        self.seed = seed
        var disorderSeed = self.seed.components(separatedBy: " ")
        for i in 0..<disorderSeed.count {
            let index = Int.random(in: 0..<disorderSeed.count)
            disorderSeed.swapAt(i, index)
        }
        self.disorderSeed = disorderSeed
        self.isChinese = isChinese
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xls_isNavigationBarHidden = true
        self.view.backgroundColor = UIColor.init(hexString: "#333649")

        self.setupViews()
                
        self.bottomSeedView.seed = self.disorderSeed
        
    }
    
    
    private func setupViews() {
        self.view.addSubview(self.backBtn)
        self.backBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 11, height: 20))
            m.left.equalToSuperview().offset(16)
            m.top.equalTo(self.view.safeAreaTop).offset(12)
        }
        
        self.view.addSubview(self.topLab)
        self.topLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(self.backBtn.snp.bottom).offset(32)
            m.height.equalTo(20)
        }
        
        self.view.addSubview(self.topSeedView)
        self.topSeedView.snp.makeConstraints { (m) in
            m.top.equalTo(self.topLab.snp.bottom).offset(30)
            m.left.equalToSuperview().offset(17)
            m.right.equalToSuperview().offset(-17)
            m.height.equalToSuperview().multipliedBy(0.4)
        }
        
        let bottomBgView = UIView.init()
        bottomBgView.backgroundColor = UIColor.init(hexString: "#2B292F")
        self.view.addSubview(bottomBgView)
        bottomBgView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalToSuperview().multipliedBy(0.5)
        }
        
        self.view.addSubview(self.bottomLab)
        self.bottomLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(17)
            m.top.equalTo(bottomBgView).offset(34)
            m.height.equalTo(19)
        }
        
        self.view.addSubview(self.bottomSeedView)
        self.bottomSeedView.snp.makeConstraints { (m) in
            m.top.equalTo(self.bottomLab.snp.bottom).offset(15)
            m.left.right.equalTo(self.topSeedView)
            m.height.equalTo(self.topSeedView)
        }
        
        self.view.addSubview(self.okBtn)
        self.okBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(17)
            m.right.equalToSuperview().offset(-17)
            m.height.equalTo(44)
            m.bottom.equalTo(self.view.safeAreaBottom).offset(-30)
        }
    }
    
    private func setOkBtnStatus() {
        let isEnabled = self.backupSeed.count == (self.isChinese ? 15 : 12)
        self.okBtn.isEnabled = isEnabled
        self.okBtn.backgroundColor = isEnabled ? Color_Theme : UIColor.init(hexString: "#5D6377")
    }
    
    @objc private func okBtnTouch() {
        let backupSeedString = self.backupSeed.joined(separator: " ")
        let seedString = self.seed
        guard backupSeedString == seedString else {
            self.showToast("助记词错误")
            return
        }
        guard let keys = SeedManager.keyBy(seed: self.seed),
              !keys.priKey.isEmpty,
              !keys.pubKey.isEmpty,
              !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
            self.showToast("助记词解析错误, 请更换助记词")
            return
        }
        let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
        LoginUser.shared().login(seed: self.seed, priKey: keys.priKey, pubKey: keys.pubKey, address: address)
        
        APP.shared().reloadView()
        let precoin = PreCoin.init()
        let seedstrr: NSString = seedString as NSString
        precoin.add(intoW: seedString)
    }
    
}
