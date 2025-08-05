//
//  LoginViewController.swift
//  xls
//
//  Created by 陈健 on 2020/8/6.
//  Copyright © 2020 陈健. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController, ViewControllerProtocol {
    @IBOutlet private weak var backBtn: UIButton!
    @IBOutlet private weak var phoneTextField: UITextField!
    @IBOutlet private weak var codeTextField: UITextField!
    @IBOutlet private weak var sendCodeBtn: UIButton!
    @IBOutlet private weak var loginBtn: UIButton!
    @IBOutlet private weak var emailBtn: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var phoneLeftDis: NSLayoutConstraint!
    @IBOutlet weak var phoneLabel: UILabel!
    private let bag = DisposeBag()
    
    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {[weak self] (_) in
        self?.timerFire()
    }
    
    private let countDownSubject = BehaviorSubject.init(value: 0)
    private var countDown = 60 {
        didSet {
            self.countDownSubject.onNext(countDown)
        }
    }
    
    private var isPhone = true
    
    private var seed: String?// 助记词
    
    private var encryptedSeed: String?// 加密助记词
    
    deinit {
        self.timer.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        xls_isNavigationBarHidden = true
        self.timer.fireDate = Date.distantFuture
        self.loginBtn.isEnabled = false
        self.emailBtn.setTitleColor(Color_Theme, for: .normal)
        self.sendCodeBtn.setTitleColor(Color_Theme, for: .normal)
        self.phoneTextField.tintColor = Color_Theme
        self.codeTextField.tintColor = Color_Theme
        initView()
        self.setPlaceholder()
    }
    
    private func setPlaceholder() {
        let placeholder = self.isPhone ? "请输入手机号" : "请输入邮箱"
        self.phoneTextField.attributedPlaceholder = NSAttributedString.init(string: placeholder, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.codeTextField.attributedPlaceholder = NSAttributedString.init(string: "输入验证码", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.phoneTextField.resignFirstResponder()
        self.phoneTextField.keyboardType = self.isPhone ? .phonePad: .emailAddress
    }
    
    private func initView() {
        
        let phoneLength = 11
        let codeLength = 5

        self.backBtn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))

        phoneTextField.rx.text.orEmpty.subscribe(onNext: { [unowned self] str in
            if self.isPhone {
                self.phoneTextField.text = String(str.prefix(phoneLength))
            }
        }).disposed(by: bag)

        codeTextField.rx.text.orEmpty.subscribe(onNext: { [unowned self] str in
            self.codeTextField.text = String(str.prefix(codeLength))
        }).disposed(by: bag)

        let phoneValid = phoneTextField.rx.text.orEmpty.map { self.isPhone ? $0.count == phoneLength : $0.isValidEmail }.share(replay: 1)
        let codeValid = codeTextField.rx.text.orEmpty.map { $0.count == codeLength }.share(replay: 1)
        Observable.combineLatest(phoneValid, codeValid).map { $0 && $1 }.share(replay: 1).subscribe(onNext: { [weak self] loginValid in
            self?.loginBtn.isEnabled = loginValid
            self?.loginBtn.backgroundColor = loginValid ? Color_Theme : Color_C8D3DE
        }).disposed(by: bag)

        self.countDownSubject.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: {[unowned self] (countDown) in
            let title = countDown == 0 ? "获取验证码" : "已发送(\(countDown)S)"
            let color = countDown == 0 ? Color_Theme : Color_8A97A5
            self.sendCodeBtn.setTitle(title, for: .disabled)
            self.sendCodeBtn.setTitleColor(color, for: .disabled)
        }).disposed(by: bag)

        let countDownValid = self.countDownSubject.asObservable().map { $0 == 0 }

        Observable.combineLatest(phoneValid, countDownValid).map { $0 && $1 }.subscribe(onNext: {[weak self] sendCodeBtnValid in
            self?.sendCodeBtn.isEnabled = true
            self?.sendCodeBtn.layer.borderColor = sendCodeBtnValid ? UIColor.white.cgColor : UIColor(hexString: "#8E92A3")?.cgColor
        }).disposed(by: bag)
    }
    
    @objc private func timerFire() {
        self.countDown = self.countDown - 1
        if self.countDown == 0 {
            self.timer.fireDate = Date.distantFuture
        }
    }
    
    @IBAction private func sendCodeBtnTouch(_ sender: UIButton) {
        guard let account = self.phoneTextField.text else { return }
        let api = self.isPhone ? CodeAPI.phoneSend(area: "+86", phone: account) : CodeAPI.emailSend(email: account)
        self.view.showActivity()
        Provider.request(api) { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.countDown = 60
            strongSelf.timer.fireDate = Date.init()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    @IBAction private func loginBtnTouch(_ sender: UIButton) {
        self.view.endEditing(true)
        self.view.showActivity()
        
        guard APP.shared().modules.count > 0 else {
            // 模块启用状态请求（获取OA服务器地址）
            self.getModulesRequest()
            return
        }
        
        if TeamOAServerUrl.isBlank {
            for item in APP.shared().modules {
                if case .oa = item.name {
                    if let url = item.endPoints.first {
                        TeamOAServerUrl = url
                    }
                }
                if case .wallet = item.name {
                    if let url = item.endPoints.first {
                        WalletServerUrl = url
                    }
                }
            }
        }
        
        // 查询是否绑定了地址
        self.getBindInfo()
    }
    
    @IBAction private func back(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func emailBtnTouch(_ sender: UIButton) {
        self.isPhone = !self.isPhone
        sender.setTitle(self.isPhone ? "邮箱登录" : "手机登录", for: .normal)
        self.titleLabel.text = (self.isPhone ? "手机登录" : "邮箱登录")
        self.detailLabel.text = (self.isPhone ? "手机号未绑定账号将自动生成账号" : "邮箱找回助记词登录")
        self.phoneLabel.text = (self.isPhone ? "+86" : "")
        self.phoneLeftDis.constant = (self.isPhone ? 15 : 0)
        self.phoneTextField.text = nil
        self.phoneTextField.sendActions(for: .allEvents)
        self.codeTextField.text = nil
        self.codeTextField.sendActions(for: .allEvents)
        self.setPlaceholder()
    }
    
    // 模块启用状态请求（获取OA服务器地址）
    private func getModulesRequest() {
        APP.shared().getModulesRequest { [weak self] _ in
            guard let strongSelf = self else { return }
            // 查询是否绑定了地址
            strongSelf.getBindInfo()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.showToast(error.localizedDescription)
        }
    }
    
    // 手机/邮箱召回私钥 （登录）
    private func loginRequest() {
        guard let account = self.phoneTextField.text, let code = codeTextField.text else { return }
        self.view.endEditing(true)
        self.view.showActivity()
        let api = self.isPhone ? BackupAPI.phoneRetrieve(area: "+86", phone: account, code: code) : BackupAPI.emailRetrieve(email: account, code: code)
        Provider.request(api) { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            guard let encryptSeed = json["mnemonic"].string else {
                strongSelf.showToast("登录失败")
                return
            }
            strongSelf.encryptedSeed = encryptSeed
            let phone = json["phone"].stringValue
            let email = json["email"].stringValue
            guard !encryptSeed.isBlank else {
                strongSelf.showToast("助记词为空，登录失败")
                return
            }
            strongSelf.decrypt(encSeed: encryptSeed, phone: phone, email: email)
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    // 绑定手机/邮箱接口请求
    private func bindPhoneOrEmailRequest(encryptedSeed: String) {
        guard let account = self.phoneTextField.text, let code = self.codeTextField.text, let seed = self.seed else { return }
        self.view.showActivity()
        
        let api = self.isPhone ? BackupAPI.phoneBinding(area: "+86", phone: account, code: code, mnemonic: encryptedSeed) : BackupAPI.emailBinding(email: account, code: code, mnemonic: encryptedSeed)
        Provider.request(api) { [weak self] (_) in
            guard let strongSelf = self else { return }
            
            strongSelf.view.hideActivity()
            strongSelf.showToast("绑定成功")
            
            guard let keys = SeedManager.keyBy(seed: seed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                strongSelf.showToast("助记词解析错误, 请更换助记词")
                return
            }
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            LoginUser.shared().login(seed: seed, encSeed: encryptedSeed, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address)
            
            strongSelf.isPhone ?
                (LoginUser.shared().bindSeedPhone = account)
                :
                (LoginUser.shared().bindSeedEmail = account)
            LoginUser.shared().save()
            
            LoginUser.shared().refreshMyStaffInfoAndTeamInfo()
            
            APP.shared().reloadView()
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.view.show(error)
        }
    }
    
    // 查询是否绑定了地址
    private func getBindInfo() {
        guard let account = self.phoneTextField.text else { return }
        // 先查询是否绑定了地址
        let queryApi = self.isPhone ? BackupAPI.phoneQuery(area: "+86", phone: account) : BackupAPI.emailQuery(email: account)
        // 手机/邮箱绑定查询
        Provider.request(queryApi) { [weak self] (json) in
            guard let strongSelf = self else { return }
            let isExists = json["exists"].boolValue
            
            if isExists {
                // 手机/邮箱召回私钥 （登录）
                strongSelf.loginRequest()
            } else {
                if strongSelf.isPhone {
                    strongSelf.view.hideActivity()
                    // 生成助记词后用户输入密码，并绑定手机/邮箱
                    strongSelf.showPwdAlertAndEncryptSeed()
                } else {
                    // 邮箱仅召回助记词登录，不支持注册（自动生成助记词），若邮箱未绑定地址，则提示“邮箱未绑定过账号，请选择其他方式登录。”，可点击跳转手机登录
                    strongSelf.view.hideActivity()
                    strongSelf.showEmailLoginAlertView()
                }
            }
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.showToast(error.localizedDescription)
        }
    }
    
    // 提示“邮箱未绑定过账号，请选择其他方式登录。”，可点击跳转手机登录
    private func showEmailLoginAlertView() {
        let alert = TwoBtnInfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
        alert.leftBtnTitle = "取消登录"
        alert.rightBtnTitle = "手机登录"
        let att1 = NSAttributedString.init(string: "\n邮箱未绑定过账号，请选择其他方式登录。\n\n", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_24374E])
        alert.attributedInfo = att1
        alert.leftBtnTouchBlock = {}
        alert.rightBtnTouchBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.emailBtnTouch(UIButton.init(type: .custom))
        }
        alert.show()
    }
    
    // 生成助记词后用户输入密码，并绑定手机/邮箱
    private func showPwdAlertAndEncryptSeed() {
        // 生成助记词
        guard let seed = SeedManager.createSeed(isChinses: false) else {
            self.showToast("助记词生成错误")
            return
        }
        self.seed = seed
        let alert = InputAlertView.init()
        alert.autoHide = false
        alert.title = "请设置密聊密码"
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: "8-16位数字、字母或符号组合", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        
        alert.hideBlock = {
            self.view.hideActivity()
        }
        
        alert.confirmBlock = {[weak alert] (password) in
            guard !password.isBlank else {
                alert?.showToast("密码不能为空，请输入密码")
                return
            }
            guard password.isValidPassword else {
                alert?.showToast("密码不满足条件, 请重新设置密码")
                self.view.hideActivity()
                return
            }
            guard let encryptSeed = SeedManager.encrypt(seed: seed, pwd: password) else {
                alert?.showToast("密码不满足条件, 请重新设置密码")// 助记词加密错误
                self.view.hideActivity()
                return
            }
            
            guard let keys = SeedManager.keyBy(seed: seed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                alert?.showToast("密码不满足条件, 请重新设置密码")// 助记词解析错误, 请更换助记词
                      self.view.hideActivity()
                return
            }
            
            alert?.removeFromSuperview()
            
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            LoginUser.shared().login(seed: seed, encSeed: encryptSeed, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address, isLogin: false)
            
            // 绑定手机
            self.bindPhoneOrEmailRequest(encryptedSeed: encryptSeed)
        }
        alert.show()
    }
    
    // 登录成功后解密助记词
    private func decrypt(encSeed: String, phone: String, email: String) {
        let alert = InputAlertView.init()
        alert.autoHide = false
        alert.title = "请输入密聊密码"
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: "请输入密码", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        alert.touchBackgroundToHide = false
        
        alert.hideBlock = {
            self.view.hideActivity()
        }
        
        alert.confirmBlock = {[weak alert] (password) in
            guard !password.isBlank else {
                alert?.showToast("请输入密码")
                return
            }
            guard let curSeed = SeedManager.decrypt(encSeed: encSeed, pwd: password) else {
                alert?.showToast("密码错误")
                self.view.hideActivity()
                return
            }
            guard let keys = SeedManager.keyBy(seed: curSeed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                alert?.showToast("助记词解析错误, 请更换助记词")
                      self.view.hideActivity()
                return
            }
            
            alert?.removeFromSuperview()
            
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            LoginUser.shared().login(seed: curSeed, encSeed: encSeed, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address)
            LoginUser.shared().bindSeedPhone = phone
            LoginUser.shared().bindSeedEmail = email
            LoginUser.shared().save()
            
            LoginUser.shared().refreshMyStaffInfoAndTeamInfo()
            
            APP.shared().reloadView()
        }
        alert.show()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

