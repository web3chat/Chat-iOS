//
//  BindSeedVC.swift
//  chat
//
//  Created by fzm on 2021/1/29.
//

import UIKit

class BindSeedVC: UIViewController,ViewControllerProtocol {
    
    @IBOutlet private weak var accountBgView: UIView!
    @IBOutlet private weak var codeBgView: UIView!
    @IBOutlet private weak var infoLab: UILabel!
    @IBOutlet private weak var accountTextField: UITextField!
    @IBOutlet private weak var codeTextField: UITextField!
    @IBOutlet private weak var sendCodeBtn: UIButton!
    @IBOutlet private weak var okBtn: UIButton!
    
    
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
    
    enum Kind {
        case phone
        case emial
    }
    
    let kind: Kind
    
    private var languageObserver: NSObjectProtocol?
    
    init(kind: Kind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let o = languageObserver { NotificationCenter.default.removeObserver(o) }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.applyLocalizedStaticStrings()
        self.bindData()
        languageObserver = NotificationCenter.default.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.applyLocalizedStaticStrings()
            let t = self.countDown == 0 ? L("获取验证码") : String(format: L("已发送(%d)S"), self.countDown)
            self.sendCodeBtn.setTitle(t, for: .disabled)
        }
    }
    
    private func applyLocalizedStaticStrings() {
        self.title = self.kind == .phone ? L("绑定手机") : L("绑定邮箱")
        self.infoLab.text = self.kind == .phone ? L("绑定手机后可用手机登录") : L("绑定邮箱后可用邮箱登录")
        let placeholder = self.kind == .phone ? L("请输入手机号") : L("请输入邮箱")
        self.accountTextField.attributedPlaceholder = NSAttributedString.init(string: placeholder, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.codeTextField.attributedPlaceholder = NSAttributedString.init(string: L("请输入验证码"), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.okBtn.setTitle(L("确定"), for: .normal)
        self.sendCodeBtn.setTitle(L("获取验证码"), for: .normal)
    }
    
    private func bindData() {
        let accountTextFieldOkBtn = self.accountTextField.addToolBar(with: L("确定"), target: self, sel: #selector(okBtnTouch(_:)))
        let codeTextFieldOkBtn = self.codeTextField.addToolBar(with: L("确定"), target: self, sel: #selector(okBtnTouch(_:)))
        
        
        let phoneLength = 11
        let codeLength = 6
        
        accountTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            if self.kind == .phone {
                self.accountTextField.text = String(str.prefix(phoneLength))
            }
        }).disposed(by: bag)
        
        codeTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            self.codeTextField.text = String(str.prefix(codeLength))
        }).disposed(by: bag)
        
        let phoneValid = accountTextField.rx.text.orEmpty.map { self.kind == .phone ? $0.count == phoneLength : $0.isValidEmail }.share(replay: 1)
        let codeValid = codeTextField.rx.text.orEmpty.map { $0.count == codeLength }.share(replay: 1)
        Observable.combineLatest(phoneValid, codeValid).map { $0 && $1 }.share(replay: 1).subscribe(onNext: { [weak self] isValid in
            accountTextFieldOkBtn.isEnabled = isValid
            codeTextFieldOkBtn.isEnabled = isValid
            self?.okBtn.isEnabled = isValid
            self?.okBtn.backgroundColor = isValid ? Color_Theme : Color_CCD1E0
            accountTextFieldOkBtn.backgroundColor = isValid ? Color_Theme : Color_CCD1E0
            codeTextFieldOkBtn.backgroundColor = isValid ? Color_Theme : Color_CCD1E0
        }).disposed(by: bag)
        
        self.countDownSubject.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: {[weak self] (countDown) in
            guard let self = self else { return }
            let title = countDown == 0 ? L("获取验证码") : String(format: L("已发送(%d)S"), countDown)
            self.sendCodeBtn.setTitle(title, for: .disabled)
        }).disposed(by: bag)
        
        let countDownValid = self.countDownSubject.asObservable().map { $0 == 0 }
        
        Observable.combineLatest(phoneValid, countDownValid).map { $0 && $1 }.subscribe(onNext: {[weak self] (sendCodeBtnValid) in
            self?.sendCodeBtn.isEnabled = sendCodeBtnValid
        }).disposed(by: bag)
    }
    
    @objc private func timerFire() {
        self.countDown = self.countDown - 1
        if self.countDown == 0 {
            self.timer.fireDate = Date.distantFuture
        }
    }
    
    @IBAction private func sendCodeBtnTouch(_ sender: UIButton) {
        self.view.endEditing(true)
        self.sendCode()
    }
    
    private func sendCode() {
        guard let account = self.accountTextField.text else { return }
        let api = self.kind == .phone ? CodeAPI.phoneSend(area: "+86", phone: account) : CodeAPI.emailSend(email: account)
        Provider.request(api) { (_) in
            self.view.hideActivity()
            self.countDown = 60
            self.timer.fireDate = Date.init()
        } failureBlock: { (error) in
            self.view.show(error)
        }
    }
    
    private func showAlert() {
        let alert = TwoBtnInfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: L("提示"), attributes: [.font : UIFont.regularFont(14), .foregroundColor : Color_8A97A5])
        alert.leftBtnTitle = L("取消")
        alert.rightBtnTitle = L("解除并绑定")
        let prefix = L("手机号/邮箱已绑定过其他助记词账户，是否解除原绑定并重新绑定本地助记词账户？\n")
        let suffix = L("若原账号有资产，将无法通过手机号找回，有丢失的风险，请谨慎解绑！")
        let prefixAttr = [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.regularFont(16)]
        let suffixAttr = [NSAttributedString.Key.foregroundColor: Color_DD5F5F, NSAttributedString.Key.font: UIFont.boldFont(16)]
        let attString = NSMutableAttributedString(string: prefix + suffix)
        attString.addAttributes(prefixAttr, range: NSRange.init(location: 0, length: prefix.count))
        attString.addAttributes(suffixAttr, range: NSRange.init(location: prefix.count, length: suffix.count))
        alert.attributedInfo = attString
        alert.leftBtnTouchBlock = {
            
        }
        alert.rightBtnTouchBlock = { [weak self] in
//            self?.sendCode()
            self?.bindRequest()
        }
        alert.show()
    }
    
    @IBAction @objc func okBtnTouch(_ sender: UIButton) {
        self.view.endEditing(true)
        //先判断是否绑定过邮箱或者手机号
        self.checkRequest()
    }
    
    func bindRequest(){
        guard let account = self.accountTextField.text,
              let code = self.codeTextField.text  else { return }
        
        let encryptedSeed = LoginUser.shared().encryptedSeed
        guard !encryptedSeed.isEmpty else { return }
        self.view.showActivity()
        let api = self.kind == .phone ? BackupAPI.phoneBinding(area: "+86", phone: account, code: code, mnemonic: encryptedSeed) : BackupAPI.emailBinding(email: account, code: code, mnemonic: encryptedSeed)
        Provider.request(api) { (_) in
            self.view.hideActivity()
            APP.shared().showToast(L("绑定成功"))
            self.kind == .phone ?
            (LoginUser.shared().bindSeedPhone = account)
            :
            (LoginUser.shared().bindSeedEmail = account)
            LoginUser.shared().save()
            self.navigationController?.popViewController()
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.view.show(error)
        }
    }
    
    func checkRequest(){
        guard let account = self.accountTextField.text  else { return }
        
        let queryApi = self.kind == .phone ? BackupAPI.phoneQuery(area: "+86", phone: account) : BackupAPI.emailQuery(email: account)
        self.view.showActivity()
        Provider.request(queryApi) { (json) in
            let isExists = json["exists"].boolValue
            if isExists  {
                self.view.hideActivity()
                self.showAlert()
            } else {
                //绑定
                self.bindRequest()
            }
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.view.show(error)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
