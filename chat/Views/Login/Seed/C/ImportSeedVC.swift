//
//  ImportSeedVC.swift
//  chat
//
//  Created by fzm on 2021/1/5.
//

import UIKit
import SnapKit
import Foundation

@objc class ImportSeedVC: UIViewController, ViewControllerProtocol, UITextFieldDelegate {
    
    @objc var seed: NSString = "111"
    @objc var pwd: NSString = "1111111111"
    private lazy var placeholderLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 18), textColor: Color_8A97A5, textAlignment: .left, text: L("请输入助记词，用空格分隔"))
        lab.numberOfLines = 0
        return lab
    }()
    
   @objc lazy var seedTextView: UITextView = {
        let tv = UITextView.init()
        tv.textColor = Color_24374E
        tv.font = .mediumFont(18)
        tv.backgroundColor = .clear
        tv.keyboardType = .default
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
            make.right.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(23)
        }
        
        return view
    }()
    
    private lazy var briefLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_Theme, textAlignment: .center, text: L("支持导入所有遵循BIP标准生成的助记词"))
        lab.numberOfLines = 0
        return lab
    }()
    
    
    private lazy var promptPwdLab: UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: L("设置密聊密码 8-16位数字、字母组合"))
    }()
    
    private lazy var pwdText:CommonTextField = {
        let pwdText = CommonTextField()
        pwdText.textColor = Color_24374E
        pwdText.placeholder = L("请设置密聊密码");
        pwdText.keyboardType = .asciiCapable;
        pwdText.isSecureTextEntry = true;
        pwdText.delegate = self;
        pwdText.tag = 100;
        return pwdText
    }()
    
    private lazy var pwdAgainText:CommonTextField = {
        let pwdAgainText = CommonTextField()
        pwdAgainText.textColor = Color_24374E
        pwdAgainText.placeholder = L("请确认密聊密码");
        pwdAgainText.keyboardType = .asciiCapable;
        pwdAgainText.isSecureTextEntry = true;
        pwdAgainText.delegate = self;
        return pwdAgainText
    }()
    
    private lazy var tipLab:UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 13), textColor: Color_DD5F5F, textAlignment: .right, text: L("请输入8～16位数字、字母组合"))
    }()
    
    private lazy var pwdtipLab:UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 13), textColor: Color_DD5F5F, textAlignment: .right, text: L("两次密码不相同"))
    }()
    
    
    private lazy var importBtn: UIButton = {
        let btn = UIButton.getNormalBtn(with: L("开始导入"), backgroundColor: Color_Theme)
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
        
        self.title = L("导入助记词")
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name:Notification.Name("k_importwallet"), object: nil)
        self.xls_isNavigationBarHidden = false
        
        self.setupViews()
        
        self.setRx()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
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
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.centerX.equalToSuperview()
        }
        
        self.view.addSubview(self.pwdText)
        pwdText.snp.makeConstraints { make in
            make.top.equalTo(briefLab.snp.bottom).offset(50)
            make.left.right.equalTo(topView)
            make.height.equalTo(50)
        }
        
        self.view.addSubview(self.promptPwdLab)
        promptPwdLab.isHidden = true
        promptPwdLab.snp.makeConstraints { make in
            make.top.equalTo(briefLab.snp.bottom).offset(40)
            make.height.equalTo(20)
            make.left.equalTo(pwdText)
        }
       
        self.view.addSubview(self.pwdAgainText)
        pwdAgainText.snp.makeConstraints { make in
            make.top.equalTo(pwdText.snp.bottom).offset(32)
            make.left.right.equalTo(pwdText)
            make.height.equalTo(50)
        }
        self.view.addSubview(self.tipLab)
        tipLab.isHidden = true
        tipLab.snp.makeConstraints { make in
            make.top.equalTo(pwdText.snp.bottom).offset(5)
            make.right.equalTo(pwdText.snp.right)
            make.height.equalTo(13)
        }
        self.view.addSubview(self.pwdtipLab)
        pwdtipLab.isHidden = true
        pwdtipLab.snp.makeConstraints { make in
            make.top.equalTo(pwdAgainText.snp.bottom).offset(5)
            make.right.equalTo(pwdAgainText.snp.right)
            make.height.equalTo(13)
        }
        
        self.view.addSubview(importBtn)
        importBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(pwdAgainText.snp.bottom).offset(50)
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
    
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.tag == 100 {
            promptPwdLab.isHidden = false
        }
        guard let textF = textField as? CommonTextField else { return }
        textF.lineColor = Color_24374E
        textF.setNeedsDisplay()
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == 100 {
            promptPwdLab.isHidden = true
        }
        guard let textF = textField as? CommonTextField else { return }
        textF.lineColor = Color_8A97A5
        textF.setNeedsDisplay()
    }
    
    @objc private func importBtnTouch() {
        // 皱筛北 喜易络 车串戈 离纤宴 付倒抹
        self.view.endEditing(true)
        guard let seed = self.seedTextView.text else { return }
        pwd = (self.pwdText.text ?? "") as NSString
        
        if pwd.isRightPassword() {
            self.tipLab.isHidden = true
            
        }else{
            self.tipLab.isHidden = false
            return
        }
        
        if pwdText.text != pwdAgainText.text {
            self.pwdtipLab.isHidden = false
            return
        }
        
        let devidedSeedBef = seed.isIncludeChinese ? seed.replacingOccurrences(of: " ", with: "").enumerated().compactMap { $0.offset % 1 == 0 ? " " + String($0.element) : String($0.element)
        }.joined() : seed
        let devidedSeed = devidedSeedBef.trimmingCharacters(in: CharacterSet.whitespaces)
        
        guard let keys = SeedManager.keyBy(seed: devidedSeed),
              !keys.priKey.isEmpty,
              !keys.pubKey.isEmpty,
              !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                  self.showToast(L("助记词错误"))
                  return
              }
        let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
        let encrypasswd = GoFunction.passwordhash(pwd as String)
        // 与下方 precoin.add(intoW:) 使用同一套规范化助记词，避免加密串与本地钱包表不一致
        let encryMnemonic = GoFunction.enckey(devidedSeed, password: pwd as String)
        ChooseAccountVC.logoutCurrentSessionIfNeededBeforeNewAccountLogin()
        LoginUser.shared().login(seed: devidedSeed, encSeed: encryMnemonic!, priKey: keys.priKey, pubKey: keys.pubKey, address: address, encPasswd: encrypasswd!)
     
        // 推送注册由 login(seed:) → AppDelegate.syncPushRegistration() 统一处理（会看「离线通知」开关）
        self.showProgress()
       
        let precoin = PreCoin.init()
        self.seed = devidedSeed as NSString
        precoin.add(intoW: devidedSeed, passwd: pwd as String)
//        precoin.add(intoW: devidedSeed, passwd: pwd as String) {
//            self.hideProgress()
//            APP.shared().reloadView()
//        }
//        precoin.add(intoW: devidedSeed, passwd: pwd as String)
       
    }
    
    @objc func handleNotification(_ notificaton:Notification){
        self.hideProgress()
        APP.shared().reloadView()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
