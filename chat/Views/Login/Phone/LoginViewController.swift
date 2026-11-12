//
//  LoginViewController.swift
//  xls
//
//  Created by fzm on 2020/8/6.
//  Copyright © 2020 fzm. All rights reserved.
//

import UIKit
import SnapKit

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
    private var isExist:Bool = false
    @objc var seedStr: NSString = "111"
    @objc var pwd: NSString = "1111111111"
    private let bag = DisposeBag()
    
    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {[weak self] (_) in
        self?.timerFire()
    }
    
    private let countDownSubject = BehaviorSubject.init(value: 0)
    /// 0 表示可再次获取验证码；与 BehaviorSubject 初值一致，发送成功时置为 60 会触发 didSet 并刷新 UI
    private var countDown = 0 {
        didSet {
            self.countDownSubject.onNext(countDown)
        }
    }
    
    private var isPhone = true
    
    private var seed: String?// 助记词
    
    private var encryptedSeed: String?// 加密助记词
    
    /// 解密助记词时连续输错密聊密码的次数，每次进入 `decrypt` 会清零
    private var decryptWrongPasswordAttempts = 0
    private var languageObserver: NSObjectProtocol?
    
    deinit {
        self.timer.invalidate()
        if let o = languageObserver { NotificationCenter.default.removeObserver(o) }
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
        // detailLabel 支持多行换行(英文文案较长),宽度约束到 safeArea 两侧
        detailLabel.numberOfLines = 0
        detailLabel.snp.makeConstraints { (m) in
            m.trailing.equalTo(self.view.safeAreaLayoutGuide).offset(-20)
        }
        applyLocalizedStrings()
        languageObserver = NotificationCenter.default.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyLocalizedStrings()
            self?.setPlaceholder()
            guard let self = self else { return }
            if self.countDown > 0 {
                self.sendCodeBtn.setTitle(String(format: L("已发送(%d)S"), self.countDown), for: .disabled)
            }
        }
    }
    
    private func applyLocalizedStrings() {
        loginBtn.setTitle(L("登录"), for: .normal)
        sendCodeBtn.setTitle(L("获取验证码"), for: .normal)
        emailBtn.setTitle(self.isPhone ? L("邮箱登录") : L("手机登录"), for: .normal)
        titleLabel.text = self.isPhone ? L("手机登录") : L("邮箱登录")
        detailLabel.text = self.isPhone ? L("手机号未绑定账号将自动生成账号") : L("邮箱找回助记词登录")
    }
    
    private func setPlaceholder() {
        let placeholder = self.isPhone ? L("请输入手机号") : L("请输入邮箱")
        self.phoneTextField.attributedPlaceholder = NSAttributedString.init(string: placeholder, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.codeTextField.attributedPlaceholder = NSAttributedString.init(string: L("输入验证码"), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.phoneTextField.resignFirstResponder()
        self.phoneTextField.keyboardType = self.isPhone ? .phonePad: .emailAddress
    }
    
    private func initView() {
        
        let phoneLength = 11
        let codeLength = 6
       
        self.backBtn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))

        phoneTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            if self.isPhone {
                self.phoneTextField.text = String(str.prefix(phoneLength))
            }
        }).disposed(by: bag)

        codeTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            self.codeTextField.text = String(str.prefix(codeLength))
        }).disposed(by: bag)

        let phoneValid = phoneTextField.rx.text.orEmpty.map { self.isPhone ? $0.count == phoneLength : $0.isValidEmail }.share(replay: 1)
        let codeValid = codeTextField.rx.text.orEmpty.map { $0.count == codeLength }.share(replay: 1)
        Observable.combineLatest(phoneValid, codeValid).map { $0 && $1 }.share(replay: 1).subscribe(onNext: { [weak self] loginValid in
            self?.loginBtn.isEnabled = loginValid
            self?.loginBtn.backgroundColor = loginValid ? Color_Theme : Color_C8D3DE
        }).disposed(by: bag)

        self.countDownSubject.asObservable().observe(on: MainScheduler.instance).subscribe(onNext: {[weak self] (countDown) in
            guard let self = self else { return }
            let title = countDown == 0 ? L("获取验证码") : String(format: L("已发送(%d)S"), countDown)
            let color = countDown == 0 ? Color_Theme : Color_8A97A5
            self.sendCodeBtn.setTitle(title, for: .disabled)
            self.sendCodeBtn.setTitleColor(color, for: .disabled)
        }).disposed(by: bag)

        let countDownValid = self.countDownSubject.asObservable().map { $0 == 0 }

        Observable.combineLatest(phoneValid, countDownValid).map { $0 && $1 }.subscribe(onNext: {[weak self] sendCodeBtnValid in
            self?.sendCodeBtn.isEnabled = sendCodeBtnValid
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
        
        self.getBindInfo()
       
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
        
        // 登录
        self.login()
    }
    
   
    
    @IBAction private func back(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func emailBtnTouch(_ sender: UIButton) {
        self.isPhone = !self.isPhone
        sender.setTitle(self.isPhone ? L("邮箱登录") : L("手机登录"), for: .normal)
        self.titleLabel.text = (self.isPhone ? L("手机登录") : L("邮箱登录"))
        self.detailLabel.text = (self.isPhone ? L("手机号未绑定账号将自动生成账号") : L("邮箱找回助记词登录"))
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
    
//    // 手机/邮箱召回私钥 （登录）
//    private func loginRequest() {
//        guard let account = self.phoneTextField.text, let code = codeTextField.text else { return }
//        self.view.endEditing(true)
//        self.view.showActivity()
//        
////        let api = S1BackUpAPI.storeShard(phone: account, code: code, chataddress: "", shard_key: "")
//        
//        let api = self.isPhone ? BackupAPI.phoneRetrieve(area: "+86", phone: account, code: code) : BackupAPI.emailRetrieve(email: account, code: code)
//        Provider.request(api) { [weak self] (json) in
//            guard let strongSelf = self else { return }
//            strongSelf.view.hideActivity()
//            guard let encryptSeed = json["mnemonic"].string else {
//                strongSelf.showToast("登录失败")
//                return
//            }
//            strongSelf.encryptedSeed = encryptSeed
//            let phone = json["phone"].stringValue
//            guard !encryptSeed.isBlank else {
//                strongSelf.showToast("助记词为空，登录失败")
//                return
//            }
//            let account = phone.isEmpty ? (strongSelf.phoneTextField.text ?? "") : phone
//            strongSelf.decrypt(encryptSeed: encryptSeed, account: account)
//        } failureBlock: { [weak self] (error) in
//            guard let strongSelf = self else { return }
//            strongSelf.view.hideActivity()
//            strongSelf.view.show(error)
//        }
//    }
    
    // 绑定手机/邮箱接口请求
//    private func bindPhoneOrEmailRequest(encryptSeed: String) {
//        guard let account = self.phoneTextField.text, let code = self.codeTextField.text, let seed = self.seed else { return }
//        self.view.showActivity()
//        
//        let api = self.isPhone ? BackupAPI.phoneBinding(area: "+86", phone: account, code: code, mnemonic: encryptSeed) : BackupAPI.emailBinding(email: account, code: code, mnemonic: encryptSeed)
//        Provider.request(api) { [weak self] (_) in
//            guard let strongSelf = self else { return }
//            
//            strongSelf.view.hideActivity()
//            strongSelf.showToast("绑定成功")
//            
//            guard let keys = SeedManager.keyBy(seed: seed),
//                  !keys.priKey.isEmpty,
//                  !keys.pubKey.isEmpty,
//                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
//                strongSelf.showToast("助记词解析错误, 请更换助记词")
//                return
//            }
//            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
//            LoginUser.shared().login(seed: seed, encSeed: encryptSeed, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address)
//            LoginUser.shared().bindSeedPhone = account
//            LoginUser.shared().save()
//            
//            APP.shared().reloadView()
//        } failureBlock: { (error) in
//            self.view.hideActivity()
//            self.view.show(error)
//        }
//    }
    
    // 点击验证码的时候查询是否绑定了地址，如果没有绑定，那就是第一次登录。如果存在那就要获取存在客户端的s1字段，与本地存着的s2合成助记词
    private func getBindInfo() {
        guard let phone = self.phoneTextField.text else {return}
        let api = S1BackUpAPI.checkShardExists(phone: phone)
        Provider.request(api){[weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.isExist = json["exists"].boolValue
            strongSelf.view.hideActivity()
            if strongSelf.isExist {
                // 如果存在，发送获取分片秘钥验证码
                strongSelf.getShard(account: phone)
            }else{
                // 获取存储分片秘钥（首次备份）验证码
                strongSelf.getCode(account: phone)
            }
        }failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            let err = error as NSError
            if err.code == -1 {
                strongSelf.isExist = false
                // 获取存储分片秘钥（首次备份）验证码
                strongSelf.getCode(account: phone)
            }else{
                strongSelf.showError(err)
            }
        }

//        guard let account = self.phoneTextField.text else { return }
//        // 先查询是否绑定了地址
//        let queryApi = self.isPhone ? BackupAPI.phoneQuery(area: "+86", phone: account) : BackupAPI.emailQuery(email: account)
//        // 手机/邮箱绑定查询
//        Provider.request(queryApi) { [weak self] (json) in
//            guard let strongSelf = self else { return }
//            let isExists = json["exists"].boolValue
//            
//            if isExists {
//                // 手机/邮箱召回私钥 （登录）
//                strongSelf.loginRequest()
//            } else {
//                if strongSelf.isPhone {
//                    strongSelf.view.hideActivity()
//                    // 生成助记词后用户输入密码，并绑定手机/邮箱
//                    strongSelf.showPwdAlertAndEncryptSeed()
//                } else {
//                    // 邮箱仅召回助记词登录，不支持注册（自动生成助记词），若邮箱未绑定地址，则提示“邮箱未绑定过账号，请选择其他方式登录。”，可点击跳转手机登录
//                    strongSelf.view.hideActivity()
//                    strongSelf.showEmailLoginAlertView()
//                }
//            }
//            
//        } failureBlock: { [weak self] (error) in
//            guard let strongSelf = self else { return }
//            strongSelf.view.hideActivity()
//            strongSelf.showToast(error.localizedDescription)
//        }
    }
    
    private func getCode(account:String){
        let api = S1BackUpAPI.s1phoneSend(phone: account, purpose: "backup")  //self.isPhone ?  CodeAPI.phoneSend(area: "+86", phone: account) : CodeAPI.emailSend(email: account)
        self.view.showActivity()
        Provider.request(api) { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.countDown = 60
            strongSelf.timer.fireDate = Date.init()
            strongSelf.codeTextField.becomeFirstResponder()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.showToast(L("验证码获取过于频繁，请稍后再试"))
        }
    }
    
    private func getShard(account:String){
        let api = S1BackUpAPI.s1phoneSend(phone: account, purpose: "get")  //self.isPhone ?  CodeAPI.phoneSend(area: "+86", phone: account) : CodeAPI.emailSend(email: account)
        self.view.showActivity()
        Provider.request(api) { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.countDown = 60
            strongSelf.timer.fireDate = Date.init()
            strongSelf.codeTextField.becomeFirstResponder()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.showToast(L("验证码获取过于频繁，请稍后再试"))
        }
    }
    
    private func login(){
        guard let phone = self.phoneTextField.text else {return}
        guard let code = self.codeTextField.text else {return}
        if self.isExist {
            // 如果是已经存储的账号，那需要s1+s2合成助记词
            self.getshard(phone: phone, code: code)
        }else {
            // 如果不是，自动生成助记词，然后将助记词分成s1+s2，s2存储在本地，s1发送给后端,
            self.showPwdAlertAndEncryptSeed(account: phone, code: code)
        }
    }
    
    /// 新手机无本地 S2，或密聊密码连续输错 3 次：选择「重置助记词」或「用 S2 秘钥登录」
    /// - Parameter isWrongPasswordThreeTimes: 为 true 时展示密聊密码输错提示；为 false 时保持新手机登录原提示
    private func showNewDeviceVerifyAlert(phone: String, isWrongPasswordThreeTimes: Bool = false) {
        let alert = TwoBtnInfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: L("提示"), attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Color_8A97A5])
        alert.leftBtnTitle = L("重置助记词")
        alert.rightBtnTitle = L("用密钥分片登录")
        let infoText: String
        if isWrongPasswordThreeTimes {
            infoText = L("\n密聊密码输错3次，建议选择其他登录方式。\n\n")
        } else {
            infoText = L("\n该账号在新手机中登录，请选择验证方式。\n\n")
        }
        let att1 = NSAttributedString.init(string: infoText, attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_24374E])
        alert.attributedInfo = att1
        alert.leftBtnTouchBlock = { [weak self] in
            guard let self = self else { return }
            let vc = ResetMnemonicLoginViewController()
            vc.prefilledPhone = phone
            self.navigationController?.pushViewController(vc, animated: true)
        }
        alert.rightBtnTouchBlock = { [weak self] in
            guard let self = self else { return }
            let vc = S2LoginViewController()
            vc.prefilledPhone = phone
            self.navigationController?.pushViewController(vc, animated: true)
        }
        alert.show()
    }
    
    // 提示“邮箱未绑定过账号，请选择其他方式登录。”，可点击跳转手机登录
    private func showEmailLoginAlertView() {
        let alert = TwoBtnInfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: L("提示"), attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
        alert.leftBtnTitle = L("取消登录")
        alert.rightBtnTitle = L("手机登录")
        let att1 = NSAttributedString.init(string: L("\n邮箱未绑定过账号，请选择其他方式登录。\n\n"), attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_24374E])
        alert.attributedInfo = att1
        alert.leftBtnTouchBlock = {}
        alert.rightBtnTouchBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.emailBtnTouch(UIButton.init(type: .custom))
        }
        alert.show()
    }
    
    private func getshard(phone:String,code:String){
        let api = S1BackUpAPI.getShard(phone: phone, code: code)
        self.view.showActivity()
        Provider.request(api) { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
//            let s1 = json["result"] == 0 ? json["shard_key"] : ""
            
            // 这是在本手机登录的情况下
            let s1 = json["shard_key"].stringValue
            
            let s2 = SeedManager.mnemonicShardS2(forPhone: phone)
           
            if let s2 = s2 {
                guard let seed = SeedManager.recoverMnemonic(s1: s1, s2: s2) else {
                    strongSelf.showToast(L("恢复助记词失败"))
                    return
                }
                strongSelf.decrypt(encryptSeed: seed, account: phone)
                
            } else {
                // 没在本手机登录过的时候本地 s2 不存在：弹框选择重置助记词或用 S2 登录
                strongSelf.showNewDeviceVerifyAlert(phone: phone)
            }
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.showToast(L("验证码过期，请重新获取"))
            
        }
        
    }
    
    /// 首次备份登录成功后，引导备份并校验第二段分片（原短信发送弹框已停用，见下方注释）
    private func presentShardBackupFlow(s1: String, s2: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let vc = ShardBackupDisplayViewController()
            vc.s1 = s1
            vc.s2 = s2
            let nav = FZMNavigationController(rootViewController: vc)
            UIViewController.current()?.present(nav, animated: true, completion: nil)
        }
    }

//    /// 首次备份登录成功后，询问是否通过短信将分片秘钥发送至本机手机号（走 getShardBySms）
//    private func scheduleSendS1ShardPrompt(phone: String) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
//            let alert = TwoBtnInfoAlertView.init()
//            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Color_8A97A5])
//            alert.leftBtnTitle = "暂不"
//            alert.rightBtnTitle = "去发送"
//            let att1 = NSAttributedString.init(string: "\n是否将第一段分片秘钥以短信形式发送到本机手机号？\n\n", attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_24374E])
//            alert.attributedInfo = att1
//            alert.leftBtnTouchBlock = {}
//            alert.rightBtnTouchBlock = {
//                let vc = SendS2ToPhoneViewController()
//                vc.phone = phone
//                let nav = FZMNavigationController(rootViewController: vc)
//                UIViewController.current()?.present(nav, animated: true, completion: nil)
//            }
//            alert.show()
//        }
//    }
    
    private func scheduleSendS2ShardPrompt(phone: String) {
        
    }
//    private func sche

    // 生成助记词后用户输入密码
    private func showPwdAlertAndEncryptSeed(account:String,code:String) {
        // 生成助记词
        guard let seed = SeedManager.createSeed(isChinses: false) else {
            self.showToast(L("助记词生成错误"))
            return
        }
        self.seed = seed
        let alert = InputAlertView.init()
        alert.autoHide = false
        alert.title = L("请设置密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: L("8-16位数字、字母或符号组合"), attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        
        alert.hideBlock = {
            self.view.hideActivity()
        }
        
        alert.confirmBlock = {[weak alert] (password) in
            guard !password.isBlank else {
                alert?.showToast(L("密码不能为空，请输入密码"))
                return
            }
            guard password.isValidPassword else {
                alert?.showToast(L("密码不满足条件, 请重新设置密码"))
                self.view.hideActivity()
                return
            }
            
            guard let keys = SeedManager.keyBy(seed: seed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                alert?.showToast(L("密码不满足条件, 请重新设置密码"))// 助记词解析错误, 请更换助记词
                      self.view.hideActivity()
                return
            }
            
            alert?.removeFromSuperview()
            
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            let spliteKey = SeedManager.spliteMnemonic(seed: seed)
            let s1 = spliteKey?.shareKey1
            let s2 = spliteKey?.shareKey2 // 需要缓存
            if let s2 = s2, let phoneKey = self.phoneTextField.text {
                _ = SeedManager.saveMnemonicShardS2(s2, forPhone: phoneKey)
            }
            self.view.showActivity()
            let api = S1BackUpAPI.storeShard(phone: account, code: code, chataddress: address, shard_key: s1!)
            Provider.request(api) { [weak self] (json) in
                guard let strongSelf = self else { return }
                strongSelf.view.hideActivity()
                // 把加密之后的密码和助记词存到钥匙串里，之后登录的时候用
                let encrypasswd = GoFunction.passwordhash(password)
                let encryMnemonic = GoFunction.enckey(seed, password: password)
                _ = SeedManager.saveChatLoginSecrets(forPhone: account, encPasswordHex: encrypasswd!, encMnemonicHex: encryMnemonic!)
                // 登录逻辑
                ChooseAccountVC.logoutCurrentSessionIfNeededBeforeNewAccountLogin()
                LoginUser.shared().bindSeedPhone = account
                LoginUser.shared().login(seed: seed, encSeed: encryMnemonic!, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address, encPasswd: encrypasswd!)
                LoginUser.shared().save()

                // 手机号登录成功，自动绑定到聊天地址
                let bindApi = S1BackUpAPI.bindAccount(phone: account, wechat_id: "", xiaohongshu_id: "", douyin_id: "", chataddress: address)
                Provider.request(bindApi, successBlock: { _ in
                    FZMLog("手机号自动绑定成功")
                }, failureBlock: { error in
                    FZMLog("手机号自动绑定失败: \(error.localizedDescription)")
                })

                APP.shared().reloadView()
                // 创建钱包
                let precoin = PreCoin.init()
                strongSelf.seedStr = seed as NSString
                precoin.add(intoW: seed, passwd: password as String)
                if let shard1 = s1, let shard2 = s2 {
                    strongSelf.presentShardBackupFlow(s1: shard1, s2: shard2)
                }
            } failureBlock: { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.view.hideActivity()
                strongSelf.view.show(error)
            }
            
            
           
            
            // 绑定手机
//            self.bindPhoneOrEmailRequest(encryptSeed: encryptSeed)
        }
        alert.show()
    }
    
    // 登录成功后解密助记词
    private func decrypt(encryptSeed: String, account: String) {
        decryptWrongPasswordAttempts = 0
        let alert = InputAlertView.init()
        alert.autoHide = false
        alert.title = L("请输入密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: L("请输入密码"), attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        alert.touchBackgroundToHide = false
        
        alert.hideBlock = {
            self.view.hideActivity()
        }
        
        alert.confirmBlock = {[weak alert] (password) in
            guard !password.isBlank else {
                alert?.showToast(L("请输入密码"))
                return
            }
            var seed = ""
            let encryPasswd = SeedManager.chatLoginEncPassword(forPhone: account)
            if  GoFunction.checkPassword(password, hash: encryPasswd!){
                self.decryptWrongPasswordAttempts = 0
                let encryRem = SeedManager.chatLoginEncMnemonic(forPhone: account)
                seed = GoFunction.deckey(encryRem, password: password)
            }else{
                self.decryptWrongPasswordAttempts += 1
                if self.decryptWrongPasswordAttempts >= 3 {
                    alert?.removeFromSuperview()
                    self.view.hideActivity()
                    self.showNewDeviceVerifyAlert(phone: account, isWrongPasswordThreeTimes: true)
                    self.decryptWrongPasswordAttempts = 0
                    return
                }
                alert?.showToast(L("密码错误"))
                return
            }
            
            guard let keys = SeedManager.keyBy(seed: seed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                alert?.showToast(L("助记词解析错误, 请更换助记词"))
                
                self.view.hideActivity()
                return
            }
            
            alert?.removeFromSuperview()
            
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            let encrypasswd = GoFunction.passwordhash(password)
            let encryMnemonic = GoFunction.enckey(seed, password: password)
            ChooseAccountVC.logoutCurrentSessionIfNeededBeforeNewAccountLogin()
            LoginUser.shared().login(seed: seed, encSeed: encryMnemonic!, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address,encPasswd: encrypasswd!)
            LoginUser.shared().bindSeedPhone = account
            LoginUser.shared().save()

            // 手机号登录成功，自动绑定到聊天地址
            let bindApi = S1BackUpAPI.bindAccount(phone: account, wechat_id: "", xiaohongshu_id: "", douyin_id: "", chataddress: address)
            Provider.request(bindApi, successBlock: { _ in
                FZMLog("手机号自动绑定成功")
            }, failureBlock: { error in
                FZMLog("手机号自动绑定失败: \(error.localizedDescription)")
            })

            APP.shared().reloadView()
            let precoin = PreCoin.init()
            self.seedStr = seed as NSString
            precoin.add(intoW: seed, passwd: password as String)
        }
        alert.show()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

