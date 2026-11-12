//
//  SendS2ToPhoneViewController.swift
//  chat
//
//  通过 getShardBySms 将服务端分片秘钥以短信形式发到本机手机号（需验证码）
//

import SnapKit
import UIKit

class SendS2ToPhoneViewController: UIViewController, ViewControllerProtocol {

    /// 接收短信的手机号（与登录手机号一致）
    var phone: String = ""

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
        l.text = L("第一段分片短信发送")
        return l
    }()

    private lazy var detailLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14)
        l.textColor = Color_8A97A5
        l.numberOfLines = 0
        l.text = L("验证码将发送至该手机号，验证通过后系统将把分片秘钥以短信形式发到该号码，便于新设备登录。")
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
        t.isUserInteractionEnabled = false
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

    private lazy var submitBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        b.setTitle(L("发送分片至手机"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = Color_C8D3DE
        b.layer.cornerRadius = 20
        b.layer.masksToBounds = true
        b.isEnabled = false
        b.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
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
        phoneTextField.text = phone
        bindRx()
        codeTextField.attributedPlaceholder = NSAttributedString(
            string: L("输入验证码"),
            attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: Color_8A97A5]
        )
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
        view.addSubview(submitBtn)
        submitBtn.snp.makeConstraints { m in
            m.left.right.equalTo(phoneContainer)
            m.top.equalTo(codeContainer.snp.bottom).offset(30)
            m.height.equalTo(40)
        }
    }

    private func bindRx() {
        let codeLength = 6
        codeTextField.rx.text.orEmpty.subscribe(onNext: { [weak self] str in
            guard let self = self else { return }
            self.codeTextField.text = String(str.prefix(codeLength))
        }).disposed(by: bag)
        let codeValid = codeTextField.rx.text.orEmpty.map { $0.count == codeLength }.share(replay: 1)
        codeValid.subscribe(onNext: { [weak self] ok in
            self?.submitBtn.isEnabled = ok
            self?.submitBtn.backgroundColor = ok ? Color_Theme : Color_C8D3DE
        }).disposed(by: bag)
        countDownSubject.asObservable().observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] cd in
            let title = cd == 0 ? L("获取验证码") : String(format: L("已发送(%d)S"), cd)
            let color = cd == 0 ? Color_Theme : Color_8A97A5
            self?.sendCodeBtn.setTitle(title, for: .disabled)
            self?.sendCodeBtn.setTitleColor(color, for: .disabled)
        }).disposed(by: bag)
        let countDownValid = countDownSubject.asObservable().map { $0 == 0 }
        let phoneReady = Observable.just(phone.count == 11).share(replay: 1)
        Observable.combineLatest(phoneReady, countDownValid).map { $0 && $1 }
            .subscribe(onNext: { [weak self] sendOk in
                self?.sendCodeBtn.isEnabled = sendOk
                self?.sendCodeBtn.layer.borderColor = sendOk ? UIColor.white.cgColor : UIColor(hexString: "#8E92A3")?.cgColor
            }).disposed(by: bag)
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    @objc private func sendCodeTapped() {
        guard phone.count == 11 else { return }
        view.showActivity()
        let api = S1BackUpAPI.s1phoneSend(phone: phone, purpose: "get")
        Provider.request(api) { [weak self] _ in
            guard let self = self else { return }
            self.view.hideActivity()
            self.countDown = 60
            self.timer.fireDate = Date()
            self.codeTextField.becomeFirstResponder()
        } failureBlock: { [weak self] error in
            guard let self = self else { return }
            self.view.hideActivity()
            self.view.showToast(L("验证码获取过于频繁，请稍后再试"))
        }
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        guard let code = codeTextField.text, code.count == 6 else { return }
        view.showActivity()
        let api = S1BackUpAPI.getShardBySms(phone: phone, code: code)
        Provider.request(api) { [weak self] _ in
            guard let self = self else { return }
            self.view.hideActivity()
            self.showToast(L("短信发送成功,请耐心等待"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.dismiss(animated: true)
            }
        } failureBlock: { [weak self] error in
            guard let self = self else { return }
            self.view.hideActivity()
            self.view.show(error)
        }
    }

    private func timerFire() {
        countDown -= 1
        if countDown == 0 {
            timer.fireDate = Date.distantFuture
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
