//
//  S2LoginViewController.swift
//  chat
//
//  验证码 + getShard 获取 S1，与用户输入的 S2 恢复助记词并登录
//

import SnapKit
import SwiftyJSON
import UIKit

class S2LoginViewController: UIViewController, ViewControllerProtocol {

    /// 从上一页带入的手机号（可选）
    var prefilledPhone: String?

    @objc var seedStr: NSString = "111"

    private let bag = DisposeBag()
    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (_) in
        self?.timerFire()
    }
    private let countDownSubject = BehaviorSubject.init(value: 0)
    private var countDown = 0 {
        didSet { self.countDownSubject.onNext(countDown) }
    }

    private lazy var backBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.setImage(UIImage(named: "nav_back"), for: .normal)
        b.tintColor = .white
        b.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return b
    }()

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.boldSystemFont(ofSize: 30)
        l.textColor = Color_24374E
        l.text = L("密钥分片登录")
        return l
    }()

    private lazy var detailLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14)
        l.textColor = Color_8A97A5
        l.numberOfLines = 0
        l.text = L("获取验证码后，输入短信验证码与密钥分片完成登录")
        return l
    }()

    private lazy var phoneContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.9647, green: 0.9686, blue: 0.9725, alpha: 1)
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        v.semanticContentAttribute = .forceLeftToRight
        return v
    }()

    private lazy var phonePrefixLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 18)
        l.textColor = Color_24374E
        l.text = "+86"
        l.textAlignment = .left
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }()

    private lazy var phoneTextField: UITextField = {
        let t = UITextField()
        t.font = UIFont.systemFont(ofSize: 18)
        t.textColor = Color_24374E
        t.tintColor = Color_Theme
        t.textAlignment = .left
        t.semanticContentAttribute = .forceLeftToRight
        t.setContentHuggingPriority(.defaultLow, for: .horizontal)
        t.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        t.keyboardType = .phonePad
        t.clearButtonMode = .whileEditing
        return t
    }()

    private lazy var codeContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.9647, green: 0.9686, blue: 0.9725, alpha: 1)
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        return v
    }()

    private lazy var codeTextField: UITextField = {
        let t = UITextField()
        t.font = UIFont.systemFont(ofSize: 18)
        t.textColor = Color_24374E
        t.tintColor = Color_Theme
        t.keyboardType = .numberPad
        t.clearButtonMode = .whileEditing
        return t
    }()

    private lazy var sendCodeBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        b.setTitle(L("获取验证码"), for: .normal)
        b.setTitleColor(Color_Theme, for: .normal)
        b.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        return b
    }()

    private lazy var s2Container: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.9647, green: 0.9686, blue: 0.9725, alpha: 1)
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        return v
    }()

    private lazy var s2TextField: UITextField = {
        let t = UITextField()
        t.font = UIFont.systemFont(ofSize: 18)
        t.textColor = Color_24374E
        t.tintColor = Color_Theme
        t.autocapitalizationType = .none
        t.autocorrectionType = .no
        t.clearButtonMode = .whileEditing
        return t
    }()

    private lazy var loginBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        b.setTitle(L("登录"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = Color_C8D3DE
        b.layer.cornerRadius = 20
        b.layer.masksToBounds = true
        b.isEnabled = false
        b.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return b
    }()

    deinit {
        timer.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        xls_isNavigationBarHidden = true
        view.backgroundColor = .white
        timer.fireDate = Date.distantFuture
        setupLayout()
        bindRx()
        phoneTextField.attributedPlaceholder = NSAttributedString(
            string: L("请输入手机号"),
            attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: Color_8A97A5]
        )
        codeTextField.attributedPlaceholder = NSAttributedString(
            string: L("输入验证码"),
            attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: Color_8A97A5]
        )
        s2TextField.attributedPlaceholder = NSAttributedString(
            string: L("请输入密钥分片"),
            attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: Color_8A97A5]
        )
        if let p = prefilledPhone, !p.isEmpty {
            phoneTextField.text = p
            phoneTextField.sendActions(for: .allEvents)
        }
        backBtn.enlargeClickEdge(UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
    }

    private func setupLayout() {
        view.addSubview(backBtn)
        backBtn.snp.makeConstraints { m in
            m.left.equalTo(view.safeAreaLayoutGuide).offset(18)
            m.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            m.width.equalTo(11)
            m.height.equalTo(20)
        }
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { m in
            m.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            m.top.equalTo(view.safeAreaLayoutGuide).offset(84)
        }
        view.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { m in
            m.left.equalTo(titleLabel)
            m.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            m.top.equalTo(titleLabel.snp.bottom).offset(5)
        }
        view.addSubview(phoneContainer)
        phoneContainer.snp.makeConstraints { m in
            m.left.right.equalTo(view.safeAreaLayoutGuide).inset(20)
            m.top.equalTo(detailLabel.snp.bottom).offset(25)
            m.height.equalTo(50)
        }
        phoneContainer.addSubview(phonePrefixLabel)
        phonePrefixLabel.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(16)
            m.centerY.equalToSuperview()
            m.width.equalTo(40)
        }
        phoneContainer.addSubview(phoneTextField)
        phoneTextField.snp.makeConstraints { m in
            m.left.equalTo(phonePrefixLabel.snp.right).offset(10)
            m.right.equalToSuperview().offset(-12)
            m.top.bottom.equalToSuperview()
        }
        view.addSubview(codeContainer)
        codeContainer.snp.makeConstraints { m in
            m.left.right.equalTo(phoneContainer)
            m.top.equalTo(phoneContainer.snp.bottom).offset(15)
            m.height.equalTo(50)
        }
        codeContainer.addSubview(codeTextField)
        codeTextField.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.width.equalTo(200)
        }
        codeContainer.addSubview(sendCodeBtn)
        sendCodeBtn.snp.makeConstraints { m in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.width.equalTo(100)
        }
        view.addSubview(s2Container)
        s2Container.snp.makeConstraints { m in
            m.left.right.equalTo(phoneContainer)
            m.top.equalTo(codeContainer.snp.bottom).offset(15)
            m.height.equalTo(50)
        }
        s2Container.addSubview(s2TextField)
        s2TextField.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.bottom.equalToSuperview()
        }
        view.addSubview(loginBtn)
        loginBtn.snp.makeConstraints { m in
            m.left.right.equalTo(s2Container)
            m.top.equalTo(s2Container.snp.bottom).offset(30)
            m.height.equalTo(40)
        }
    }

    private func bindRx() {
        let phoneLength = 11
        let codeLength = 6
        phoneTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            self.phoneTextField.text = String(str.prefix(phoneLength))
        }).disposed(by: bag)
        codeTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            self.codeTextField.text = String(str.prefix(codeLength))
        }).disposed(by: bag)
        let phoneValid = phoneTextField.rx.text.orEmpty.map { $0.count == phoneLength }.share(replay: 1)
        let codeValid = codeTextField.rx.text.orEmpty.map { $0.count == codeLength }.share(replay: 1)
        let s2Valid = s2TextField.rx.text.orEmpty.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.share(replay: 1)
        Observable.combineLatest(phoneValid, codeValid, s2Valid).map { $0 && $1 && $2 }
            .subscribe(onNext: { [weak self] ok in
                self?.loginBtn.isEnabled = ok
                self?.loginBtn.backgroundColor = ok ? Color_Theme : Color_C8D3DE
            }).disposed(by: bag)
        countDownSubject.asObservable().observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] cd in
            guard let self = self else { return }
            let title = cd == 0 ? L("获取验证码") : String(format: L("已发送(%d)S"), cd)
            let color = cd == 0 ? Color_Theme : Color_8A97A5
            self.sendCodeBtn.setTitle(title, for: .disabled)
            self.sendCodeBtn.setTitleColor(color, for: .disabled)
        }).disposed(by: bag)
        let countDownValid = countDownSubject.asObservable().map { $0 == 0 }
        Observable.combineLatest(phoneValid, countDownValid).map { $0 && $1 }
            .subscribe(onNext: { [weak self] sendOk in
                self?.sendCodeBtn.isEnabled = sendOk
                self?.sendCodeBtn.layer.borderColor = sendOk ? UIColor.white.cgColor : UIColor(hexString: "#8E92A3")?.cgColor
            }).disposed(by: bag)
    }

    @objc private func sendCodeTapped() {
        guard let account = phoneTextField.text, account.count == 11 else { return }
        view.showActivity()
        let api = S1BackUpAPI.s1phoneSend(phone: account, purpose: "get")
        Provider.request(api) { [weak self] _ in
            guard let self = self else { return }
            self.view.hideActivity()
            self.countDown = 60
            self.timer.fireDate = Date()
            self.codeTextField.becomeFirstResponder()
        } failureBlock: { [weak self] error in
            guard let self = self else { return }
            self.view.hideActivity()
            self.view.showToast(L("获取验证码过于频繁，请稍后再试"))
        }
    }

   
    @objc private func loginTapped() {
        view.endEditing(true)
        guard let phone = phoneTextField.text, phone.count == 11,
              let code = codeTextField.text, code.count == 6 else { return }
        let s2 = s2TextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s2.isEmpty else { return }

        view.showActivity()
        let api = S1BackUpAPI.getShard(phone: phone, code: code)
        Provider.request(api) { [weak self] json in
            guard let self = self else { return }
            self.view.hideActivity()
            let s1 = json["shard_key"].stringValue
        
            guard let seed = SeedManager.recoverMnemonic(s1: s1, s2: s2) else {
                self.showToast(L("密钥分片无效，无法恢复助记词"))
                return
            }
            guard let keys = SeedManager.keyBy(seed: seed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty else {
                self.showToast(L("助记词解析错误"))
                return
            }
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            _ = SeedManager.saveMnemonicShardS2(s2, forPhone: phone)

            self.presentPasswordAndCompleteLogin(seed: seed, keys: keys, address: address, phone: phone)
        } failureBlock: { [weak self] error in
            guard let self = self else { return }
            self.view.hideActivity()
            self.view.showToast(L("验证码过期，请重新获取"))
        }
    }

    private func presentPasswordAndCompleteLogin(seed: String, keys: (priKey: String, pubKey: String), address: String, phone: String) {
        let alert = InputAlertView.init()
        alert.autoHide = false
        alert.title = L("请设置密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString(
            string: L("8-16位数字、字母或符号组合"),
            attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_8A97A5]
        )
        alert.isSecureTextEntry = true
        alert.touchBackgroundToHide = false
        alert.hideBlock = { [weak self] in
            self?.view.hideActivity()
        }
        alert.confirmBlock = { [weak alert, weak self] password in
            guard let self = self else { return }
            guard !password.isBlank else {
                alert?.showToast(L("密码不能为空，请输入密码"))
                return
            }
            guard password.isValidPassword else {
                alert?.showToast(L("密码不满足条件, 请重新设置密码"))
                self.view.hideActivity()
                return
            }
           
            alert?.removeFromSuperview()
            self.view.showActivity()
            let encrypasswd = GoFunction.passwordhash(password)
            let encryMnemonic = GoFunction.enckey(seed, password: password)
            _ = SeedManager.saveChatLoginSecrets(forPhone: phone, encPasswordHex: encrypasswd!, encMnemonicHex: encryMnemonic!)
            ChooseAccountVC.logoutCurrentSessionIfNeededBeforeNewAccountLogin()
            LoginUser.shared().login(seed: seed,encSeed: encryMnemonic!, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address,encPasswd: encrypasswd!)
            LoginUser.shared().bindSeedPhone = phone
            LoginUser.shared().save()
            
            // 手机号登录成功，自动绑定到聊天地址
            let bindApi = S1BackUpAPI.bindAccount(phone: phone, wechat_id: "", xiaohongshu_id: "", douyin_id: "", chataddress: address)
            Provider.request(bindApi, successBlock: { _ in
                FZMLog("手机号自动绑定成功")
            }, failureBlock: { error in
                FZMLog("手机号自动绑定失败: \(error.localizedDescription)")
            })
            
            self.view.hideActivity()
            APP.shared().reloadView()
            let precoin = PreCoin.init()
            self.seedStr = seed as NSString
            precoin.add(intoW: seed, passwd: password as String)
        }
        alert.show()
    }

    private func timerFire() {
        countDown -= 1
        if countDown == 0 {
            timer.fireDate = Date.distantFuture
        }
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
