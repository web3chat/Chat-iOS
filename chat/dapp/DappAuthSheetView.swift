//
//  DappAuthSheetView.swift
//  chat
//
//  Swift 版 DApp 授权确认弹层（对齐 ObjC `DappAlertSheetView`：展示站点 / 链接 / 钱包 / 链 / 操作明细 + 密码）。
//

import UIKit
import SnapKit
import BigInt

// MARK: - 手续费预览（与 `DAppWeb3Bridge.previewEthSendFee` 共用）

/// `eth_sendTransaction` 预估手续费（授权页 + 矿工费面板）。
struct DAppEthSendFeePreview {
    let gasLimit: BigUInt
    let feeWei: BigUInt
    let uses1559: Bool
    let rpcGasPriceWei: BigUInt
    let legacyGasPriceWei: BigUInt?
    let maxFeePerGasWei: BigUInt?
    let maxPriorityFeeWei: BigUInt?
}

// MARK: - 展示数据

/// 供密码授权弹窗展示的明细（由 EIP-1193 `method` + `params` 组装）。
struct DappAuthSheetPayload {
    let sheetTitle: String
    let rpcMethod: String
    let detailRows: [(label: String, value: String)]
    /// `eth_sendTransaction` 且 `value > 0` 时，弹窗顶部突出展示的转账数额（不含币种符号）。
    let highlightedAmount: String?
    /// 高危提示（例如这笔调用其实是在授权 / 转移资产），非空时在明细顶部红字展示
    let warning: String?

    /// `feePreview` 仅 `eth_sendTransaction` 且预估成功时展示「手续费」行。
    static func build(
        method: String,
        params: [Any]?,
        pageURL: String,
        walletAddress: String,
        chainIdHex: String,
        feePreview: DAppEthSendFeePreview? = nil
    ) -> DappAuthSheetPayload {
        let host = URL(string: pageURL)?.host ?? pageURL
        var rows: [(String, String)] = []
        rows.append((L("站点"), host))
        rows.append((L("页面链接"), truncate(pageURL, limit: 512)))
        rows.append((L("钱包地址"), walletAddress.isEmpty ? L("—") : walletAddress))
        rows.append((L("当前链 ID"), chainIdHexToDecimalDisplay(chainIdHex)))

        var title: String
        var highlightedAmount: String?
        var warning: String?
        switch method {
        case "personal_sign":
            title = L("消息签名")
            if let p = params, let msg = p.first as? String {
                rows.append((L("签名内容"), truncate(msg, limit: 2000)))
            }
        case "eth_sign":
            title = L("原始数据签名")
            if let p = params, p.count >= 2, let dataHex = p[1] as? String {
                rows.append((L("签名数据(hex)"), truncate(dataHex, limit: 2000)))
            }
        case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
            title = L("结构化签名")
            if let typed = EIP712TypedData.parse(params: params) {
                rows.append((L("签名类型"), typed.primaryType))
                if let name = typed.domainName, !name.isEmpty {
                    rows.append((L("签名域"), name))
                }
                if let contract = typed.verifyingContract, !contract.isEmpty {
                    rows.append((L("验证合约"), contract))
                }
                for row in typed.displayRows() {
                    rows.append((row.label, row.value))
                }
                if typed.isAssetAuthorization {
                    title = L("签名授权动用你的资产")
                    warning = L("这次签名会授权对方动用你的资产，请确认对方地址可信。")
                }
            } else {
                rows.append((L("签名内容"), truncate(Self.rawTypedDataText(params), limit: 4000)))
            }
        case "eth_sendTransaction":
            title = L("发送交易")
            if let dict = params?.first as? [String: Any] {
                if let from = dict["from"] as? String { rows.append((L("发起地址(From)"), from)) }
                if let to = dict["to"] as? String { rows.append((L("接收地址(To)"), to)) }
                if let v = dict["value"] as? String {
                    let dec = weiHexToDecimal18(v)
                    if let wei = parseBigUIntHex(v), wei > 0 {
                        highlightedAmount = dec
                    } else {
                        rows.append((L("数额(主链币)"), dec))
                    }
                }
                if let data = dict["data"] as? String, data != "0x" && data != "0x0" {
                    rows.append((L("交易数据(Data)"), truncate(data, limit: 2000)))
                    // 这笔调用可能不是转账，而是 approve / setApprovalForAll / permit：
                    // 一次确认就永久交出资产扣款权，必须把 spender / 额度解出来单独提示。
                    if let call = decodeSensitiveCall(data) {
                        title = call.title
                        warning = call.warning
                        rows.append(contentsOf: call.rows)
                    }
                }
                if let fp = feePreview {
                    rows.append((L("手续费(预估)"), weiToDecimalDividingBy1e18(fp.feeWei)))
                }
                if let nonce = dict["nonce"] as? String {
                    rows.append((L("Nonce"), nonce))
                }
            }
        default:
            title = L("钱包授权")
        }

        return DappAuthSheetPayload(
            sheetTitle: title,
            rpcMethod: method,
            detailRows: rows,
            highlightedAmount: highlightedAmount,
            warning: warning
        )
    }

    /// `eth_sendTransaction` 的 data 是否在做「授权 / 转移资产」类调用。
    /// 这些调用本身**不是转账**，但一次确认就可能永久交出资产扣款权。
    struct SensitiveCall {
        let title: String
        let warning: String
        let rows: [(String, String)]
    }

    static func decodeSensitiveCall(_ data: String) -> SensitiveCall? {
        let body = (data.hasPrefix("0x") || data.hasPrefix("0X")) ? String(data.dropFirst(2)) : data
        guard body.count >= 8 else { return nil }
        let selector = String(body.prefix(8)).lowercased()
        var args: [String] = []
        var cursor = body.index(body.startIndex, offsetBy: 8)
        while body.distance(from: cursor, to: body.endIndex) >= 64 {
            let end = body.index(cursor, offsetBy: 64)
            args.append(String(body[cursor..<end]))
            cursor = end
        }
        func address(_ index: Int) -> String? {
            guard index < args.count else { return nil }
            return "0x" + String(args[index].suffix(40))
        }
        func uint(_ index: Int) -> BigUInt? {
            guard index < args.count else { return nil }
            return BigUInt(args[index], radix: 16)
        }
        func amountText(_ value: BigUInt?) -> String {
            guard let value else { return "—" }
            if value == BigUInt(2).power(256) - 1 { return L("无限（可随时转走全部余额）") }
            return String(value, radix: 10) + " " + L("（代币最小单位）")
        }

        switch selector {
        case "095ea7b3", "39509351":
            // approve(address,uint256) / increaseAllowance(address,uint256)
            return SensitiveCall(
                title: L("授权动用你的资产"),
                warning: L("这笔调用是「授权」：确认后该地址可以不经你同意直接转走你的代币。"),
                rows: [(L("授权给(Spender)"), address(0) ?? "—"),
                       (L("授权数量"), amountText(uint(1)))])
        case "a22cb465":
            // setApprovalForAll(address,bool)
            let approved = (uint(0) ?? 0) != 0
            return SensitiveCall(
                title: L("授权动用你的 NFT"),
                warning: L("这笔调用是「全部授权」：确认后该地址可以转走你这一整个 NFT 集合里的任意一枚。"),
                rows: [(L("操作方(Operator)"), address(0) ?? "—"),
                       (L("状态"), approved ? L("允许") : L("撤销"))])
        case "d505accf":
            // permit(owner,spender,value,deadline,v,r,s) — EIP-2612
            return SensitiveCall(
                title: L("签名授权动用你的资产"),
                warning: L("这笔调用是「permit」：用一次签名完成授权，确认后该地址可以不经你同意转走你的代币。"),
                rows: [(L("授权给(Spender)"), address(1) ?? "—"),
                       (L("授权数量"), amountText(uint(2)))])
        case "a9059cbb":
            // transfer(address,uint256)：ERC20 直接转账
            return SensitiveCall(
                title: L("转移你的资产"),
                warning: L("这笔调用会直接把这笔资产转走，请确认「到」地址是否可信。"),
                rows: [(L("到(To)"), address(0) ?? "—"),
                       (L("数量"), amountText(uint(1)))])
        case "23b872dd", "42842e0e", "f242432a":
            // transferFrom / safeTransferFrom（ERC721 / ERC1155）
            return SensitiveCall(
                title: L("转移你的资产"),
                warning: L("这笔调用会直接把这笔资产转走，请确认「到」地址是否可信。"),
                rows: [(L("从(From)"), address(0) ?? "—"),
                       (L("到(To)"), address(1) ?? "—")])
        default:
            return nil
        }
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        let idx = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<idx]) + "…"
    }

    /// `eth_signTypedData*` 解析失败时，把原始 JSON 直接展示出来（便于用户/客服排查，不要静默成空白）。
    private static func rawTypedDataText(_ params: [Any]?) -> String {
        guard let params else { return "—" }
        for item in params {
            if let text = item as? String,
               text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                return text
            }
            if let dict = item as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return "—"
    }

    private static func chainIdHexToDecimalDisplay(_ hex: String) -> String {
        guard let n = parseBigUIntHex(hex) else { return hex }
        return decimalString(n)
    }

    private static func weiHexToDecimal18(_ hex: String) -> String {
        guard let wei = parseBigUIntHex(hex) else { return hex }
        return weiToDecimalDividingBy1e18(wei)
    }

    private static func parseBigUIntHex(_ hex: String) -> BigUInt? {
        let t = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let strip = t.hasPrefix("0x") || t.hasPrefix("0X") ? String(t.dropFirst(2)) : t
        guard !strip.isEmpty else { return nil }
        return BigUInt(strip, radix: 16)
    }

    private static func decimalString(_ n: BigUInt) -> String {
        String(n, radix: 10)
    }

    private static func weiToDecimalDividingBy1e18(_ wei: BigUInt) -> String {
        let oneE18 = BigUInt(10).power(18)
        if wei == 0 { return "0" }
        let intPart = wei / oneE18
        let frac = wei % oneE18
        if frac == 0 {
            return decimalString(intPart)
        }
        var fracDigits = String(frac, radix: 10)
        if fracDigits.count < 18 {
            fracDigits = String(repeating: "0", count: 18 - fracDigits.count) + fracDigits
        }
        while fracDigits.last == "0", !fracDigits.isEmpty {
            fracDigits.removeLast()
        }
        if fracDigits.isEmpty {
            return decimalString(intPart)
        }
        return "\(decimalString(intPart)).\(fracDigits)"
    }
}

// MARK: - 弹窗视图

/// 底部滑入式授权说明：第一页展示明细 +「下一步」，第二页输入密码 +「确定」。
final class DappAuthSheetView: UIView {
    private var payload: DappAuthSheetPayload
    private let completion: (String?, [String: Any]?) -> Void
    private weak var hostViewController: UIViewController?

    private let method: String
    private let pageURL: String
    private let walletAddress: String
    private let chainIdHex: String
    private let chainSymbol: String
    private var ethSendParams: [Any]?
    private var feePreview: DAppEthSendFeePreview?
    private let fetchFeePreview: (([String: Any]) async throws -> DAppEthSendFeePreview)?
    private var txOverrides: [String: Any] = [:]
    /// 人脸/指纹验证进行中（避免连点「下一步」重复触发）
    private var isBiometricAuthorizing = false

    private let dimView = UIView()
    private let panel = UIView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let step1Stack = UIStackView()
    private let step2Stack = UIStackView()
    private let passwordField = UITextField()
    private let headerLeftBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .custom)
    private let confirmBtn = UIButton(type: .custom)
    private let headerTitleLabel = UILabel()
    private let amountBox = UIView()
    private let amountCaptionLabel = UILabel()
    private let amountValueLabel = UILabel()

    private enum SheetStep {
        case detail
        case password
    }

    private var step: SheetStep = .detail

    private static let titleColor = UIColor(red: 51 / 255, green: 54 / 255, blue: 73 / 255, alpha: 1)
    private static let subColor = UIColor(red: 138 / 255, green: 151 / 255, blue: 165 / 255, alpha: 1)

    private let feeRowLabel = L("手续费(预估)")

    init(
        payload: DappAuthSheetPayload,
        method: String,
        pageURL: String,
        walletAddress: String,
        chainIdHex: String,
        ethSendParams: [Any]?,
        initialFeePreview: DAppEthSendFeePreview?,
        chainSymbol: String,
        fetchFeePreview: (([String: Any]) async throws -> DAppEthSendFeePreview)?,
        completion: @escaping (String?, [String: Any]?) -> Void
    ) {
        self.payload = payload
        self.method = method
        self.pageURL = pageURL
        self.walletAddress = walletAddress
        self.chainIdHex = chainIdHex
        self.ethSendParams = ethSendParams
        self.feePreview = initialFeePreview
        self.chainSymbol = chainSymbol
        self.fetchFeePreview = fetchFeePreview
        self.completion = completion
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(on hostView: UIView, hostController: UIViewController) {
        hostViewController = hostController
        frame = hostView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(self)

        panel.snp.updateConstraints { make in
            make.height.lessThanOrEqualTo(hostView.bounds.height * 0.78)
        }
        layoutIfNeeded()
        panel.transform = CGAffineTransform(translationX: 0, y: panel.bounds.height + 40)
        dimView.alpha = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.dimView.alpha = 1
            self.panel.transform = .identity
        }
        NotificationCenter.default.addObserver(self, selector: #selector(authKeyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authKeyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authKeyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    /// 键盘底部相对本视图的重叠高度（将 `panel.bottom` 上移相同数值，使白底面板贴在键盘上方）。
    private func keyboardOverlapFromBottom(_ notification: Notification) -> CGFloat {
        guard let info = notification.userInfo,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return 0 }
        if let local = info[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber, !local.boolValue {
            return 0
        }
        if endFrame.height < 12 { return 0 }
        let kbInSelf: CGRect
        if #available(iOS 13.0, *) {
            kbInSelf = convert(endFrame, from: UIScreen.main.coordinateSpace)
        } else {
            kbInSelf = convert(endFrame, from: nil)
        }
        let overlap = max(0, bounds.maxY - kbInSelf.minY)
        return overlap > 0 ? overlap + 12 : 0
    }

    private func authKeyboardApplyPanelInset(from notification: Notification) {
        guard step == .password else { return }
        guard let dur = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else { return }
        let inset = keyboardOverlapFromBottom(notification)
        UIView.animate(withDuration: dur) {
            self.panel.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(-inset)
            }
            self.layoutIfNeeded()
        }
    }

    @objc private func authKeyboardWillShow(_ notification: Notification) {
        authKeyboardApplyPanelInset(from: notification)
    }

    @objc private func authKeyboardWillChangeFrame(_ notification: Notification) {
        authKeyboardApplyPanelInset(from: notification)
    }

    @objc private func authKeyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo,
              let dur = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else { return }
        UIView.animate(withDuration: dur) {
            self.panel.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(0)
            }
            self.layoutIfNeeded()
        }
    }

    private func resetPanelBottomForKeyboard() {
        panel.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(0)
        }
        layoutIfNeeded()
    }

    private func dismissSheet(password: String?, overrides: [String: Any]?) {
        removeKeyboardObservers()
        passwordField.resignFirstResponder()
        resetPanelBottomForKeyboard()
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height + 40)
        } completion: { _ in
            self.removeFromSuperview()
            self.completion(password, overrides)
        }
    }

    private func setupUI() {
        backgroundColor = .clear

        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
        dimView.addGestureRecognizer(tap)
        addSubview(dimView)
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        panel.backgroundColor = .white
        panel.layer.cornerRadius = 12
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        addSubview(panel)
        panel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.lessThanOrEqualTo(UIScreen.main.bounds.height * 0.78)
        }

        headerTitleLabel.font = .boldSystemFont(ofSize: 17)
        headerTitleLabel.textColor = Self.titleColor
        headerTitleLabel.textAlignment = .center
        headerTitleLabel.numberOfLines = 2
        headerTitleLabel.text = payload.sheetTitle

        headerLeftBtn.setTitle(L("取消"), for: .normal)
        headerLeftBtn.setTitleColor(Self.subColor, for: .normal)
        headerLeftBtn.titleLabel?.font = .systemFont(ofSize: 16)
        headerLeftBtn.addTarget(self, action: #selector(headerLeftTapped), for: .touchUpInside)

        let headerBar = UIView()
        headerBar.addSubview(headerLeftBtn)
        headerBar.addSubview(headerTitleLabel)
        headerLeftBtn.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(52)
            make.height.equalTo(44)
        }
        headerTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.greaterThanOrEqualTo(headerLeftBtn.snp.right).offset(8)
            make.right.lessThanOrEqualToSuperview().offset(-16)
        }

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill

        reloadDetailRows()

        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.width.equalToSuperview()
        }

        nextBtn.setTitle(L("下一步"), for: .normal)
        nextBtn.setTitleColor(.white, for: .normal)
        nextBtn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        nextBtn.backgroundColor = Color_Theme
        nextBtn.layer.cornerRadius = 8
        nextBtn.clipsToBounds = true
        nextBtn.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        amountCaptionLabel.font = .systemFont(ofSize: 12)
        amountCaptionLabel.textColor = Self.subColor
        amountCaptionLabel.textAlignment = .center
        amountCaptionLabel.text = L("数额(主链币)")
        amountValueLabel.font = .boldSystemFont(ofSize: 26)
        amountValueLabel.textColor = Color_Theme
        amountValueLabel.textAlignment = .center
        amountValueLabel.numberOfLines = 1
        amountValueLabel.adjustsFontSizeToFitWidth = true
        amountValueLabel.minimumScaleFactor = 0.6
        amountBox.addSubview(amountCaptionLabel)
        amountBox.addSubview(amountValueLabel)
        amountCaptionLabel.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        amountValueLabel.snp.makeConstraints { make in
            make.top.equalTo(amountCaptionLabel.snp.bottom).offset(2)
            make.left.right.bottom.equalToSuperview()
        }

        step1Stack.axis = .vertical
        step1Stack.spacing = 14
        step1Stack.alignment = .fill
        step1Stack.addArrangedSubview(amountBox)
        step1Stack.addArrangedSubview(scrollView)
        step1Stack.addArrangedSubview(nextBtn)
        step1Stack.setCustomSpacing(12, after: amountBox)

        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.placeholder = L("请输入密聊密码")
        passwordField.font = .systemFont(ofSize: 16)

        confirmBtn.setTitle(L("确定"), for: .normal)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        confirmBtn.backgroundColor = Color_Theme
        confirmBtn.layer.cornerRadius = 8
        confirmBtn.clipsToBounds = true
        confirmBtn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        /// 吸收纵向剩余高度，使密码步与明细步共用同一 `stepBodyContainer` 时整体等高。
        let passwordStepBottomSpacer = UIView()
        passwordStepBottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        passwordStepBottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        step2Stack.axis = .vertical
        step2Stack.spacing = 0
        step2Stack.alignment = .fill
        step2Stack.isHidden = true
        step2Stack.addArrangedSubview(passwordField)
        step2Stack.addArrangedSubview(confirmBtn)
        step2Stack.addArrangedSubview(passwordStepBottomSpacer)
        step2Stack.setCustomSpacing(10, after: passwordField)

        let stepBodyContainer = UIView()
        stepBodyContainer.backgroundColor = .clear
        panel.addSubview(headerBar)
        panel.addSubview(stepBodyContainer)
        stepBodyContainer.addSubview(step1Stack)
        stepBodyContainer.addSubview(step2Stack)
        step1Stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        step2Stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        headerBar.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(50)
        }
        stepBodyContainer.snp.makeConstraints { make in
            make.top.equalTo(headerBar.snp.bottom).offset(4)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(panel.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        scrollView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(120)
            make.height.lessThanOrEqualTo(UIScreen.main.bounds.height * 0.42)
        }
        nextBtn.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        passwordField.snp.makeConstraints { make in
            make.height.equalTo(46)
        }
        confirmBtn.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }

    private func reloadDetailRows() {
        updateAmountDisplay()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let warning = payload.warning, !warning.isEmpty {
            stackView.addArrangedSubview(makeWarningView(warning))
        }
        for row in payload.detailRows {
            let isFee = (row.0 == feeRowLabel)
            let v = makeRow(label: row.0, value: row.1, isFeeRow: isFee)
            stackView.addArrangedSubview(v)
        }
    }

    /// 高危提示条（授权 / 转移资产类调用）
    private func makeWarningView(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = Color_DD5F5F.withAlphaComponent(0.12)
        container.layer.cornerRadius = 8
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = Color_DD5F5F
        label.numberOfLines = 0
        label.text = text
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
        return container
    }

    private func updateAmountDisplay() {
        guard let amount = payload.highlightedAmount else {
            amountBox.isHidden = true
            return
        }
        amountBox.isHidden = false
        amountValueLabel.text = chainSymbol.isEmpty ? amount : "\(amount) \(chainSymbol)"
    }

    private func rebuildPayloadFromCurrentParams() {
        payload = DappAuthSheetPayload.build(
            method: method,
            params: ethSendParams,
            pageURL: pageURL,
            walletAddress: walletAddress,
            chainIdHex: chainIdHex,
            feePreview: feePreview
        )
        headerTitleLabel.text = payload.sheetTitle
        reloadDetailRows()
    }

    private func makeRow(label: String, value: String, isFeeRow: Bool) -> UIView {
        let v = UIView()
        let title = UILabel()
        title.font = .systemFont(ofSize: 13)
        title.textColor = Self.subColor
        title.text = label
        title.numberOfLines = 1

        let body = UILabel()
        body.font = .systemFont(ofSize: 14)
        body.textColor = Self.titleColor
        body.text = value
        body.numberOfLines = 0

        v.addSubview(title)
        v.addSubview(body)

        title.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }

        if isFeeRow, feePreview != nil {
            body.textColor = Color_Theme
            body.snp.makeConstraints { make in
                make.top.equalTo(title.snp.bottom).offset(4)
                make.left.right.equalToSuperview()
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(feeRowTapped))
            v.addGestureRecognizer(tap)
            v.isUserInteractionEnabled = true
            let hint = UILabel()
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = Self.subColor
            hint.text = L("点击调整矿工费")
            v.addSubview(hint)
            hint.snp.makeConstraints { make in
                make.top.equalTo(body.snp.bottom).offset(2)
                make.left.right.bottom.equalToSuperview()
            }
        } else {
            body.snp.makeConstraints { make in
                make.top.equalTo(title.snp.bottom).offset(4)
                make.left.right.bottom.equalToSuperview()
            }
        }

        return v
    }

    @objc private func feeRowTapped() {
        guard let fp = feePreview,
              let host = hostViewController,
              let dict = ethSendParams?.first as? [String: Any] else { return }
        let sheet = DappChoiceFeeSheetView(preview: fp, chainSymbol: chainSymbol) { [weak self] result in
            guard let self else { return }
            var merged = dict
            let ov = result.overridesForTransactionDict()
            for (k, val) in ov {
                merged[k] = val
            }
            self.ethSendParams = [merged]
            self.txOverrides = ov
            Task { [weak self] in
                guard let self else { return }
                if let fetch = self.fetchFeePreview {
                    do {
                        let newP = try await fetch(merged)
                        await MainActor.run {
                            self.feePreview = newP
                            self.rebuildPayloadFromCurrentParams()
                        }
                    } catch {
                        await MainActor.run {
                            self.updateFeePreviewLocally(from: result)
                            self.rebuildPayloadFromCurrentParams()
                        }
                    }
                } else {
                    await MainActor.run {
                        self.updateFeePreviewLocally(from: result)
                        self.rebuildPayloadFromCurrentParams()
                    }
                }
            }
        }
        sheet.present(on: self, hostController: host)
    }

    /// RPC 刷新失败时用手选结果近似更新手续费展示。
    private func updateFeePreviewLocally(from result: DappFeeSelectionResult) {
        guard let prev = feePreview else { return }
        let gl = result.gasLimit
        let fee: BigUInt
        if result.uses1559 {
            fee = gl * (result.maxFeePerGasWei ?? 0)
        } else {
            fee = gl * (result.legacyGasPriceWei ?? 0)
        }
        feePreview = DAppEthSendFeePreview(
            gasLimit: gl,
            feeWei: fee,
            uses1559: result.uses1559,
            rpcGasPriceWei: prev.rpcGasPriceWei,
            legacyGasPriceWei: result.legacyGasPriceWei ?? prev.legacyGasPriceWei,
            maxFeePerGasWei: result.maxFeePerGasWei ?? prev.maxFeePerGasWei,
            maxPriorityFeeWei: result.maxPriorityFeeWei ?? prev.maxPriorityFeeWei
        )
    }

    /// 进入「密码输入」步骤。只会在「未开启面容/指纹」或「人脸验证未通过」时到达。
    private func goToPasswordStep() {
        step = .password
        step1Stack.isHidden = true
        step2Stack.isHidden = false
        headerLeftBtn.setTitle(L("返回"), for: .normal)
        setNeedsLayout()
        layoutIfNeeded()
        passwordField.text = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.superview != nil else { return }
            _ = self.passwordField.becomeFirstResponder()
        }
    }

    private func goToDetailStep() {
        step = .detail
        passwordField.resignFirstResponder()
        passwordField.text = nil
        step1Stack.isHidden = false
        step2Stack.isHidden = true
        headerLeftBtn.setTitle(L("取消"), for: .normal)
        resetPanelBottomForKeyboard()
    }

    @objc private func dimTapped() {
        switch step {
        case .password:
            // 仅收起键盘，关闭弹窗用左上角「返回」或「取消」（明细步蒙层仍可关闭）。
            passwordField.resignFirstResponder()
        case .detail:
            dismissSheet(password: nil, overrides: nil)
        }
    }

    @objc private func headerLeftTapped() {
        switch step {
        case .detail:
            dismissSheet(password: nil, overrides: nil)
        case .password:
            goToDetailStep()
        }
    }

    @objc private func nextTapped() {
        // 已开启面容/指纹：直接人脸验证，通过就直接签名/转账，不再弹密码输入框
        guard FZM_EnableBiometricUnlock, BiometricAuthManager.shared.bindState == .bound else {
            goToPasswordStep()
            return
        }
        guard !isBiometricAuthorizing else { return }
        isBiometricAuthorizing = true
        ChatPasswordGate.fetchVerifiedPassword(reason: L("验证身份以授权本次操作")) { [weak self] password in
            guard let self = self else { return }
            self.isBiometricAuthorizing = false
            // 验证期间弹层已被关闭（点取消/蒙层）则不再处理
            guard self.superview != nil else { return }
            if let password = password, !password.isEmpty {
                self.submitAuthorized(password: password)
            } else {
                // 用户取消验证 / 识别失败 / 绑定失效：回落密码输入步骤
                self.goToPasswordStep()
            }
        }
    }

    /// 授权通过（人脸验证 或 手输密码）：提交本次签名/转账。
    private func submitAuthorized(password: String) {
        let ov = txOverrides.isEmpty ? nil : txOverrides
        dismissSheet(password: password, overrides: ov)
    }

    @objc private func confirmTapped() {
        let pwd = passwordField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pwd.isEmpty else {
            presentAuthHint(L("请输入密聊密码"))
            return
        }
        submitAuthorized(password: pwd)
    }

    private func presentAuthHint(_ text: String) {
        hostViewController?.showCustomMessage(text, hideAfterDelay: 1.5)
    }
}
