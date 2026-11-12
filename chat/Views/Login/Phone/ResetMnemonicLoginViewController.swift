//
//  ResetMnemonicLoginViewController.swift
//  chat
//
//  重置助记词登录：手机号 + 验证码 + 登录（重置分片）
//

import SnapKit
import UIKit

class ResetMnemonicLoginViewController: UIViewController, ViewControllerProtocol {

    var prefilledPhone: String?
    @objc var seedStr: NSString = "111"

    private let bag = DisposeBag()
    private lazy var timer: Timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (_) in
        self?.timerFire()
    }
    private let countDownSubject = BehaviorSubject.init(value: 0)
    /// 0 表示可再次获取验证码；与 BehaviorSubject 初值一致，发送成功置 60 会触发 didSet 并刷新 UI
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
        l.text = L("重置助记词登录")
        return l
    }()

    private lazy var detailLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14)
        l.textColor = Color_8A97A5
        l.numberOfLines = 0
        l.text = L("重置助记词说明")
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
        view.addSubview(loginBtn)
        loginBtn.snp.makeConstraints { m in
            m.left.right.equalTo(phoneContainer)
            m.top.equalTo(codeContainer.snp.bottom).offset(30)
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
        Observable.combineLatest(phoneValid, codeValid).map { $0 && $1 }.subscribe(onNext: { [weak self] ok in
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
        Observable.combineLatest(phoneValid, countDownValid).map { $0 && $1 }.subscribe(onNext: { [weak self] sendOk in
            self?.sendCodeBtn.isEnabled = sendOk
            self?.sendCodeBtn.layer.borderColor = sendOk ? UIColor.white.cgColor : UIColor(hexString: "#8E92A3")?.cgColor
        }).disposed(by: bag)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func sendCodeTapped() {
        guard let account = phoneTextField.text, account.count == 11 else { return }
        view.showActivity()
        let api = S1BackUpAPI.s1phoneSend(phone: account, purpose: "reset")
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
        guard let account = phoneTextField.text, let code = codeTextField.text else { return }
        guard let seed = SeedManager.createSeed(isChinses: false) else {
            showToast(L("助记词生成错误"))
            return
        }
        let alert = InputAlertView.init()
        alert.autoHide = false
        alert.title = L("请设置密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString(
            string: L("8-16位数字、字母或符号组合"),
            attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_8A97A5]
        )
        alert.isSecureTextEntry = true
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
            guard let spliteKey = SeedManager.spliteMnemonic(seed: seed) else {
                self.showToast(L("分片生成失败"))
                return
            }
            let s1 = spliteKey.shareKey1
            let s2 = spliteKey.shareKey2
            _ = SeedManager.saveMnemonicShardS2(s2, forPhone: account)
            self.view.showActivity()
            let api = S1BackUpAPI.resetShard(phone: account, code: code, chataddress: address, shard_key: s1)
            Provider.request(api) { [weak self] _ in
                guard let self = self else { return }
                self.view.hideActivity()
                let encrypasswd = GoFunction.passwordhash(password)
                let encryMnemonic = GoFunction.enckey(seed, password: password)
                _ = SeedManager.saveChatLoginSecrets(forPhone: account, encPasswordHex: encrypasswd!, encMnemonicHex: encryMnemonic!)
                ChooseAccountVC.logoutCurrentSessionIfNeededBeforeNewAccountLogin()
                LoginUser.shared().login(seed: seed,encSeed: encryMnemonic!, priKey: keys.priKey.finalKey, pubKey: keys.pubKey.finalKey, address: address,encPasswd: encrypasswd!)
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
                // 创建钱包
                let precoin = PreCoin()
                self.seedStr = seed as NSString
                precoin.add(intoW: seed, passwd: password)
                // 提示备份s2
                self.presentShardBackupFlow(s1: s1, s2: s2)
                
            } failureBlock: { [weak self] error in
                guard let self = self else { return }
                self.view.hideActivity()
                self.view.show(error)
            }
        }
        alert.show()
    }

    private func timerFire() {
        countDown -= 1
        if countDown == 0 {
            timer.fireDate = Date.distantFuture
        }
    }

//    /// 重置分片登录成功后，询问是否通过短信将分片秘钥发送至本机手机号（走 getShardBySms，与 LoginViewController 一致）
//    private func scheduleSendS2ShardPrompt(phone: String) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
//            let alert = TwoBtnInfoAlertView.init()
//            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Color_8A97A5])
//            alert.leftBtnTitle = "暂不"
//            alert.rightBtnTitle = "去发送"
//            let att1 = NSAttributedString.init(string: "\n是否将分片秘钥以短信形式发送到本机手机号？便于在新设备上配合本地分片登录。\n\n", attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_24374E])
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

    /// 重置登录成功后，引导备份并校验第二段分片（原短信发送弹框已停用，见下方注释）
    private func presentShardBackupFlow(s1: String, s2: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let vc = ShardBackupDisplayViewController()
            vc.s1 = s1
            vc.s2 = s2
            let nav = FZMNavigationController(rootViewController: vc)
            UIViewController.current()?.present(nav, animated: true, completion: nil)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
