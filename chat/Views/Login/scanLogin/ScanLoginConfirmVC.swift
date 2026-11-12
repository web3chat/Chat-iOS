//
//  ScanLoginConfirmVC.swift
//  chat
//
//  扫码登录（PC 网页版）确认页
//  流程：扫码 → 本页展示会话信息 → 用户确认 → 密聊密码二次验证 → 加密私钥并提交（文档 §4 接入步骤）
//

import UIKit
import SnapKit

final class ScanLoginConfirmVC: UIViewController, ViewControllerProtocol {

    // MARK: - 输入
    private let payload: ScanLoginQRPayload

    // MARK: - 状态
    /// 剩余有效期（秒），以扫码时刻起算
    private var remainingSeconds: Int
    private var countdownTimer: Timer?
    private var isExpired = false
    private var isProcessing = false
    /// 已经出结果（成功 / 会话失效）→ 页面即将关闭，避免重复操作
    private var isFinished = false

    // MARK: - 视图

    private lazy var iconImageView: UIImageView = {
        let v = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        v.image = UIImage(systemName: "laptopcomputer.and.iphone", withConfiguration: config)?
            .withTintColor(Color_Theme, renderingMode: .alwaysOriginal)
        v.contentMode = .scaleAspectFit
        return v
    }()

    private lazy var headlineLabel: UILabel = {
        return UILabel.getLab(font: .boldSystemFont(ofSize: 18),
                              textColor: Color_24374E,
                              textAlignment: .center,
                              text: L("电脑端请求登录网页版"))
    }()

    private lazy var subLabel: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 13),
                                 textColor: Color_8A97A5,
                                 textAlignment: .center,
                                 text: L("确认后将允许该设备使用你的账号登录谈信网页版"))
        lab.numberOfLines = 0
        return lab
    }()

    private lazy var deviceValueLabel: UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 14),
                              textColor: Color_24374E,
                              textAlignment: .right,
                              text: "")
    }()

    private lazy var validityValueLabel: UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 14),
                              textColor: Color_24374E,
                              textAlignment: .right,
                              text: "")
    }()

    private lazy var createdValueLabel: UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 14),
                              textColor: Color_24374E,
                              textAlignment: .right,
                              text: "")
    }()

    private lazy var infoCard: UIView = {
        let v = UIView()
        v.backgroundColor = Color_FFFFFF
        v.layer.cornerRadius = 8
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOffset = CGSize(width: 0, height: 1)
        v.layer.shadowOpacity = 0.06
        v.layer.shadowRadius = 4
        return v
    }()

    private lazy var infoStack: UIStackView = {
        let v = UIStackView()
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 0
        return v
    }()

    private lazy var tipsLabel: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 12),
                                 textColor: Color_8A97A5,
                                 textAlignment: .left,
                                 text: L("安全提示：确认后你的私钥将以密文方式发送给服务端，服务端无法解密。请确认是本人操作，不要在他人引导下扫码确认。"))
        lab.numberOfLines = 0
        return lab
    }()

    private lazy var confirmButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.setTitle(L("确认登录"), for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 22
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - 初始化

    init(payload: ScanLoginQRPayload) {
        self.payload = payload
        self.remainingSeconds = payload.expiresIn
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Color_FAFBFC
        xls_isNavigationBarHidden = false
        navigationItem.title = L("扫码登录网页版")
        setupNavBar()
        setupViews()
        applyPayloadContent()
        updateCountdownUI()
        startCountdown()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCountdown()
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            appearance.buttonAppearance.normal.backgroundImage = UIImage()
            appearance.buttonAppearance.highlighted.backgroundImage = UIImage()
            appearance.doneButtonAppearance.normal.backgroundImage = UIImage()
            appearance.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            appearance.backButtonAppearance.normal.backgroundImage = UIImage()
            appearance.backButtonAppearance.highlighted.backgroundImage = UIImage()
            appearance.backgroundColor = Color_FFFFFF
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
            appearance.titleTextAttributes = [.foregroundColor: Color_24374E]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance = appearance
        }
        let cancelItem = UIBarButtonItem(title: L("取消"),
                                        style: .plain,
                                        target: self,
                                        action: #selector(cancelTapped))
        cancelItem.tintColor = Color_24374E
        navigationItem.leftBarButtonItem = cancelItem
    }

    // MARK: - 界面

    private func setupViews() {
        view.addSubview(iconImageView)
        view.addSubview(headlineLabel)
        view.addSubview(subLabel)
        view.addSubview(infoCard)
        view.addSubview(tipsLabel)
        view.addSubview(confirmButton)

        infoCard.addSubview(infoStack)
        infoStack.addArrangedSubview(makeInfoRow(title: L("登录设备"), valueLabel: deviceValueLabel))
        infoStack.addArrangedSubview(makeSeparator())
        infoStack.addArrangedSubview(makeInfoRow(title: L("有效期"), valueLabel: validityValueLabel))
        // 二维码未带 creationAt 时不显示「发起时间」行
        if payload.createdAt != nil {
            infoStack.addArrangedSubview(makeSeparator())
            infoStack.addArrangedSubview(makeInfoRow(title: L("发起时间"), valueLabel: createdValueLabel))
        }

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(36)
            make.size.equalTo(CGSize(width: 48, height: 48))
        }

        headlineLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.top.equalTo(iconImageView.snp.bottom).offset(18)
        }

        subLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(30)
            make.right.equalToSuperview().offset(-30)
            make.top.equalTo(headlineLabel.snp.bottom).offset(8)
        }

        infoCard.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.top.equalTo(subLabel.snp.bottom).offset(26)
        }

        infoStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tipsLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(28)
            make.right.equalToSuperview().offset(-28)
            make.top.equalTo(infoCard.snp.bottom).offset(18)
        }

        confirmButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.top.equalTo(tipsLabel.snp.bottom).offset(28)
            make.height.equalTo(44)
        }
    }

    /// 信息卡里的一行：左标题 + 右内容
    private func makeInfoRow(title: String, valueLabel: UILabel) -> UIView {
        let row = UIView()
        let titleLabel = UILabel.getLab(font: .systemFont(ofSize: 13),
                                        textColor: Color_8A97A5,
                                        textAlignment: .left,
                                        text: title)
        row.addSubview(titleLabel)
        row.addSubview(valueLabel)

        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.left.greaterThanOrEqualTo(titleLabel.snp.right).offset(12)
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(46)
        }
        return row
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = Color_E6EAEE
        line.snp.makeConstraints { make in
            make.height.equalTo(0.5)
        }
        return line
    }

    private func applyPayloadContent() {
        // 二维码未带设备字段时回落到「电脑端」
        deviceValueLabel.text = payload.device ?? L("电脑端")

        if let createdAt = payload.createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            createdValueLabel.text = formatter.string(from: createdAt)
        }
    }

    // MARK: - 倒计时（服务端会话 TTL 5 分钟，见文档 §6）

    private func startCountdown() {
        stopCountdown()
        guard !isExpired else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func tick() {
        guard !isExpired else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            remainingSeconds = 0
            isExpired = true
            stopCountdown()
        }
        updateCountdownUI()
        if isExpired {
            showToast(L("二维码已过期，请重新扫码"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                self?.closePage()
            }
        }
    }

    private func updateCountdownUI() {
        if isExpired {
            validityValueLabel.text = L("二维码已过期，请重新扫码")
            validityValueLabel.textColor = Color_DD5F5F
            confirmButton.isEnabled = false
            confirmButton.alpha = 0.5
            return
        }

        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        validityValueLabel.text = String(format: "%02d:%02d", minutes, seconds)
        // 最后 30 秒用警示色提醒用户及时确认
        validityValueLabel.textColor = remainingSeconds <= 30 ? Color_DD5F5F : Color_24374E
    }

    // MARK: - 交互

    /// 二次验证（文档 §9：确认动作必须经过用户校验）—— 与转账 / 导出助记词一致，走密聊密码
    /// 已开启面容/指纹时直接通过，否则弹密聊密码输入框
    @objc private func confirmTapped() {
        guard !isProcessing, !isExpired, !isFinished else { return }
        
        ChatPasswordGate.requestVerifiedPassword(title: L("请输入密聊密码"), cancelled: nil) { [weak self] password in
            self?.verifyPassword(password)
        }
    }

    private func verifyPassword(_ password: String) {
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        guard GoFunction.checkPassword(password, hash: wallet?.wallet_password) else {
            showToast(L("密码错误"))
            return
        }
        submit()
    }

    private func submit() {
        guard !isProcessing, !isFinished else { return }
        guard !isExpired else {
            showToast(L("二维码已过期，请重新扫码"))
            closePage()
            return
        }
        isProcessing = true
        setConfirmButtonEnabled(false)
        showProgress()

        ScanLoginService.shared.confirm(payload) { [weak self] result in
            guard let self = self else { return }
            self.isProcessing = false
            self.hideProgress()

            switch result {
            case .success:
                self.isFinished = true
                self.stopCountdown()
                self.showToast(L("已确认，请在电脑上继续"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                    self?.closePage()
                }

            case .failure(let failure):
                self.showToast(failure.displayMessage)
                if failure.shouldClosePage {
                    // 会话失效 / 私钥不可用等：重试也没有意义，提示后自动关闭
                    self.isFinished = true
                    self.stopCountdown()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                        self?.closePage()
                    }
                } else {
                    // 401 / 网络 / 服务端错误：留在页面，允许用户重新确认（会重新生成签名）
                    self.setConfirmButtonEnabled(true)
                }
            }
        }
    }

    private func setConfirmButtonEnabled(_ enabled: Bool) {
        confirmButton.isEnabled = enabled && !isExpired
        confirmButton.alpha = confirmButton.isEnabled ? 1 : 0.5
    }

    @objc private func cancelTapped() {
        guard !isFinished else {
            closePage()
            return
        }
        // 确认请求已发出时不允许取消：否则 PC 端可能已登录成功，而用户以为取消了
        guard !isProcessing else {
            showToast(L("正在确认登录，请稍候"))
            return
        }
        isFinished = true
        stopCountdown()
        // 通知服务端作废会话（可选接口）：不等待结果，失败也不打扰用户
        ScanLoginService.shared.cancel(payload, completion: nil)
        closePage()
    }

    private func closePage() {
        navigationController?.dismiss(animated: true)
    }
}
