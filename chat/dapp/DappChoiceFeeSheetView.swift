//
//  DappChoiceFeeSheetView.swift
//  chat
//
//  Swift 版矿工费选择（对齐 PWChoiceFeeSheetView：最快 / 标准 / 经济 / 自定义）。
//

import UIKit
import SnapKit
import BigInt

/// 用户确认后的 Gas / 单价，用于写回 `eth_sendTransaction` 参数字典（值为 hex quantity 字符串）。
struct DappFeeSelectionResult {
    let gasLimit: BigUInt
    let uses1559: Bool
    let legacyGasPriceWei: BigUInt?
    let maxFeePerGasWei: BigUInt?
    let maxPriorityFeeWei: BigUInt?

    func overridesForTransactionDict() -> [String: Any] {
        var o: [String: Any] = [:]
        let gh = Self.hexQuantity(gasLimit)
        o["gas"] = gh
        o["gasLimit"] = gh
        if uses1559 {
            o["maxFeePerGas"] = Self.hexQuantity(maxFeePerGasWei ?? 0)
            o["maxPriorityFeePerGas"] = Self.hexQuantity(maxPriorityFeeWei ?? 0)
        } else {
            o["gasPrice"] = Self.hexQuantity(legacyGasPriceWei ?? 0)
        }
        return o
    }

    private static func hexQuantity(_ v: BigUInt) -> String {
        if v == 0 { return "0x0" }
        return "0x" + String(v, radix: 16)
    }
}

// MARK: - UI

/// 底部矿工费选择面板。
final class DappChoiceFeeSheetView: UIView {
    private let preview: DAppEthSendFeePreview
    private let chainSymbol: String
    private let onConfirm: (DappFeeSelectionResult) -> Void

    private let dimView = UIView()
    private let panel = UIView()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let confirmBtn = UIButton(type: .custom)

    private var selectedIndex: Int = 1
    private var optionViews: [UIView] = []

    private let gasLimitField = UITextField()
    private let legacyPriceField = UITextField()
    private let maxFeeField = UITextField()
    private let priorityField = UITextField()
    private let customContainer = UIStackView()

    private weak var hostVC: UIViewController?

    private static let titleC = UIColor(red: 51 / 255, green: 54 / 255, blue: 73 / 255, alpha: 1)
    private static let subC = UIColor(red: 138 / 255, green: 151 / 255, blue: 165 / 255, alpha: 1)

    init(
        preview: DAppEthSendFeePreview,
        chainSymbol: String,
        onConfirm: @escaping (DappFeeSelectionResult) -> Void
    ) {
        self.preview = preview
        self.chainSymbol = chainSymbol
        self.onConfirm = onConfirm
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(on hostView: UIView, hostController: UIViewController) {
        hostVC = hostController
        frame = hostView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(self)
        layoutIfNeeded()
        panel.transform = CGAffineTransform(translationX: 0, y: panel.bounds.height + 80)
        dimView.alpha = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.dimView.alpha = 1
            self.panel.transform = .identity
        }
        NotificationCenter.default.addObserver(self, selector: #selector(kbShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func dismissPanel() {
        NotificationCenter.default.removeObserver(self)
        endEditing(true)
        transform = .identity
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height + 80)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    private func kbApplyOverlapShift(_ n: Notification) {
        guard let info = n.userInfo,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let dur = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else { return }
        if endFrame.height < 12 { return }
        let kbInSelf = convert(endFrame, from: nil)
        let overlap = max(0, bounds.maxY - kbInSelf.minY)
        let shift = overlap > 0 ? overlap + 20 : 0
        UIView.animate(withDuration: dur) {
            self.transform = shift > 0 ? CGAffineTransform(translationX: 0, y: -shift) : .identity
        }
    }

    @objc private func kbShow(_ n: Notification) {
        kbApplyOverlapShift(n)
    }

    @objc private func kbChangeFrame(_ n: Notification) {
        kbApplyOverlapShift(n)
    }

    @objc private func kbHide(_ n: Notification) {
        guard let info = n.userInfo,
              let dur = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else { return }
        UIView.animate(withDuration: dur) {
            self.transform = .identity
        }
    }

    private func setup() {
        backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTap)))
        addSubview(dimView)
        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }

        panel.backgroundColor = UIColor(red: 248 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
        panel.layer.cornerRadius = 12
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        addSubview(panel)
        panel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.lessThanOrEqualTo(UIScreen.main.bounds.height * 0.72)
        }

        let header = UIView()
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle(L("取消"), for: .normal)
        closeBtn.setTitleColor(Self.subC, for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 16)
        closeBtn.addTarget(self, action: #selector(dimTap), for: .touchUpInside)

        let titleLab = UILabel()
        titleLab.text = L("矿工费")
        titleLab.font = .boldSystemFont(ofSize: 17)
        titleLab.textColor = Self.titleC
        titleLab.textAlignment = .center

        header.addSubview(closeBtn)
        header.addSubview(titleLab)
        closeBtn.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.height.equalTo(44)
            make.width.greaterThanOrEqualTo(52)
        }
        titleLab.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.greaterThanOrEqualTo(closeBtn.snp.right).offset(8)
        }

        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill

        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.width.equalToSuperview()
        }

        buildOptions()

        confirmBtn.setTitle(L("确认"), for: .normal)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        confirmBtn.backgroundColor = Color_Theme
        confirmBtn.layer.cornerRadius = 8
        confirmBtn.clipsToBounds = true
        confirmBtn.addTarget(self, action: #selector(confirmTap), for: .touchUpInside)

        panel.addSubview(header)
        panel.addSubview(scrollView)
        panel.addSubview(confirmBtn)

        header.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(50)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(confirmBtn.snp.top).offset(-12)
            // 无最小高度时 ScrollView 在竖向约束链里可被压成 0，表现为只剩底部「确认」。
            make.height.greaterThanOrEqualTo(160).priority(.high)
            make.height.greaterThanOrEqualTo(80)
        }
        confirmBtn.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(panel.safeAreaLayoutGuide.snp.bottom).offset(-16)
            make.height.equalTo(48)
        }

        styleCustomFields()
    }

    private func styleCustomFields() {
        customContainer.axis = .vertical
        customContainer.spacing = 8
        customContainer.isHidden = true

        func placeholder(_ tf: UITextField, _ ph: String) {
            tf.borderStyle = .roundedRect
            tf.font = .systemFont(ofSize: 15)
            tf.keyboardType = .decimalPad
            tf.placeholder = ph
        }

        placeholder(gasLimitField, L("Gas Limit（数字）"))
        placeholder(legacyPriceField, L("Gas Price（Gwei）"))
        placeholder(maxFeeField, L("Max Fee（Gwei）"))
        placeholder(priorityField, L("Priority Fee（Gwei）"))

        maxFeeField.isHidden = !preview.uses1559
        priorityField.isHidden = !preview.uses1559
        legacyPriceField.isHidden = preview.uses1559

        customContainer.addArrangedSubview(gasLimitField)
        customContainer.addArrangedSubview(legacyPriceField)
        customContainer.addArrangedSubview(maxFeeField)
        customContainer.addArrangedSubview(priorityField)

        gasLimitField.snp.makeConstraints { $0.height.equalTo(44) }
        legacyPriceField.snp.makeConstraints { $0.height.equalTo(44) }
        maxFeeField.snp.makeConstraints { $0.height.equalTo(44) }
        priorityField.snp.makeConstraints { $0.height.equalTo(44) }
    }

    private func buildOptions() {
        let gl = preview.gasLimit
        let names = [L("最快"), L("标准"), L("经济"), L("自定义")]
        let multipliers: [(BigUInt, BigUInt)] = [(3, 1), (2, 1), (3, 2)] // num/den for 3x, 2x, 1.5x

        for i in 0 ..< 4 {
            let card = UIView()
            card.layer.cornerRadius = 8
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.clear.cgColor
            card.tag = i

            let title = UILabel()
            title.font = .systemFont(ofSize: 15, weight: .medium)
            title.textColor = Self.titleC
            title.text = names[i]

            let sub = UILabel()
            sub.font = .systemFont(ofSize: 13)
            sub.textColor = Self.subC
            sub.numberOfLines = 0

            if i < 3 {
                let feeWei: BigUInt
                let detail: String
                if preview.uses1559 {
                    let mf = preview.maxFeePerGasWei ?? 0
                    let mp = preview.maxPriorityFeeWei ?? 0
                    let mm = mf * multipliers[i].0 / multipliers[i].1
                    let pm = mp * multipliers[i].0 / multipliers[i].1
                    feeWei = gl * mm
                    detail = "\(Self.formatFeeEth(feeWei)) \(chainSymbol) · EIP-1559"
                    card.accessibilityHint = "\(mm)|\(pm)"
                } else {
                    let base = preview.legacyGasPriceWei ?? preview.rpcGasPriceWei
                    let gp = base * multipliers[i].0 / multipliers[i].1
                    feeWei = gl * gp
                    detail = "\(Self.formatFeeEth(feeWei)) \(chainSymbol) · \(Self.formatGwei(gp)) Gwei"
                    card.accessibilityHint = "\(gp)"
                }
                sub.text = detail
            } else {
                sub.text = L("手动输入 Gas 与单价")
            }

            card.addSubview(title)
            card.addSubview(sub)
            title.snp.makeConstraints { make in
                make.top.left.right.equalToSuperview().inset(12)
            }
            sub.snp.makeConstraints { make in
                make.top.equalTo(title.snp.bottom).offset(6)
                make.left.right.bottom.equalToSuperview().inset(12)
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(optionTap(_:)))
            card.addGestureRecognizer(tap)
            card.isUserInteractionEnabled = true

            stack.addArrangedSubview(card)
            card.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(i == 3 ? 52 : 72)
            }
            optionViews.append(card)
        }

        stack.addArrangedSubview(customContainer)

        selectedIndex = 1
        refreshSelectionVisual()
        fillCustomDefaultsFromSelection()
    }

    @objc private func optionTap(_ g: UITapGestureRecognizer) {
        guard let card = g.view else { return }
        selectedIndex = card.tag
        refreshSelectionVisual()
        fillCustomDefaultsFromSelection()
        customContainer.isHidden = selectedIndex != 3
    }

    private func refreshSelectionVisual() {
        for (i, v) in optionViews.enumerated() {
            let on = i == selectedIndex
            v.layer.borderColor = on ? Color_Theme.cgColor : UIColor(white: 0.9, alpha: 1).cgColor
            v.layer.borderWidth = on ? 1.5 : 1
            v.backgroundColor = on ? UIColor(red: 113 / 255, green: 144 / 255, blue: 1, alpha: 0.08) : .white
        }
    }

    private func fillCustomDefaultsFromSelection() {
        gasLimitField.text = String(preview.gasLimit, radix: 10)
        if preview.uses1559 {
            let mf = preview.maxFeePerGasWei ?? 0
            let mp = preview.maxPriorityFeeWei ?? 0
            let pairs: [(BigUInt, BigUInt)] = [(3, 1), (2, 1), (3, 2)]
            let m = selectedIndex < 3 ? mf * pairs[selectedIndex].0 / pairs[selectedIndex].1 : mf
            let p = selectedIndex < 3 ? mp * pairs[selectedIndex].0 / pairs[selectedIndex].1 : mp
            maxFeeField.text = Self.formatGweiString(m)
            priorityField.text = Self.formatGweiString(p)
        } else {
            let base = preview.legacyGasPriceWei ?? preview.rpcGasPriceWei
            let pairs: [(BigUInt, BigUInt)] = [(3, 1), (2, 1), (3, 2)]
            let gp = selectedIndex < 3 ? base * pairs[selectedIndex].0 / pairs[selectedIndex].1 : base
            legacyPriceField.text = Self.formatGweiString(gp)
        }
    }

    @objc private func dimTap() {
        dismissPanel()
    }

    @objc private func confirmTap() {
        let gl: BigUInt
        let uses1559 = preview.uses1559
        if selectedIndex == 3 {
            guard let gStr = gasLimitField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let gParsed = BigUInt(gStr, radix: 10), gParsed > 0 else {
                hostVC?.showCustomMessage(L("请输入有效的 Gas Limit"), hideAfterDelay: 1.5)
                return
            }
            gl = gParsed
            if uses1559 {
                guard let mf = Self.parseGweiField(maxFeeField.text),
                      let mp = Self.parseGweiField(priorityField.text) else {
                    hostVC?.showCustomMessage(L("请输入有效的 Gwei"), hideAfterDelay: 1.5)
                    return
                }
                let result = DappFeeSelectionResult(
                    gasLimit: gl,
                    uses1559: true,
                    legacyGasPriceWei: nil,
                    maxFeePerGasWei: mf,
                    maxPriorityFeeWei: mp
                )
                dismissPanel()
                onConfirm(result)
                return
            } else {
                guard let gp = Self.parseGweiField(legacyPriceField.text) else {
                    hostVC?.showCustomMessage(L("请输入有效的 Gas Price（Gwei）"), hideAfterDelay: 1.5)
                    return
                }
                let result = DappFeeSelectionResult(
                    gasLimit: gl,
                    uses1559: false,
                    legacyGasPriceWei: gp,
                    maxFeePerGasWei: nil,
                    maxPriorityFeeWei: nil
                )
                dismissPanel()
                onConfirm(result)
                return
            }
        }

        let pairs: [(BigUInt, BigUInt)] = [(3, 1), (2, 1), (3, 2)]
        gl = preview.gasLimit
        if uses1559 {
            let mf = preview.maxFeePerGasWei ?? 0
            let mp = preview.maxPriorityFeeWei ?? 0
            let mm = mf * pairs[selectedIndex].0 / pairs[selectedIndex].1
            let pm = mp * pairs[selectedIndex].0 / pairs[selectedIndex].1
            let result = DappFeeSelectionResult(
                gasLimit: gl,
                uses1559: true,
                legacyGasPriceWei: nil,
                maxFeePerGasWei: mm,
                maxPriorityFeeWei: pm
            )
            dismissPanel()
            onConfirm(result)
        } else {
            let base = preview.legacyGasPriceWei ?? preview.rpcGasPriceWei
            let gp = base * pairs[selectedIndex].0 / pairs[selectedIndex].1
            let result = DappFeeSelectionResult(
                gasLimit: gl,
                uses1559: false,
                legacyGasPriceWei: gp,
                maxFeePerGasWei: nil,
                maxPriorityFeeWei: nil
            )
            dismissPanel()
            onConfirm(result)
        }
    }

    private static func formatFeeEth(_ wei: BigUInt) -> String {
        DappFeeFormat.weiToDecimal18(wei)
    }

    /// Wei → Gwei 展示字符串（小数保留至多 4 位，去尾 0）。
    private static func formatGweiString(_ wei: BigUInt) -> String {
        let g = Decimal(string: String(wei, radix: 10)) ?? 0
        let div = Decimal(sign: .plus, exponent: -9, significand: 1)
        let x = g * div
        let ns = NSDecimalNumber(decimal: x)
        let s = ns.stringValue
        if s.contains(".") {
            var t = s
            while t.last == "0" { t.removeLast() }
            if t.last == "." { t.removeLast() }
            return t
        }
        return s
    }

    private static func formatGwei(_ wei: BigUInt) -> String {
        formatGweiString(wei)
    }

    private static func parseGweiField(_ text: String?) -> BigUInt? {
        let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty, let gwei = Double(t), gwei >= 0 else { return nil }
        let wei = gwei * 1_000_000_000
        if wei > Double(UInt64.max) { return nil }
        return BigUInt(UInt64(wei))
    }
}

// MARK: - 与授权页共享的 Wei→ether 字符串（避免依赖 DappAuthSheetPayload 私有方法）

private enum DappFeeFormat {
    static func weiToDecimal18(_ wei: BigUInt) -> String {
        let oneE18 = BigUInt(10).power(18)
        if wei == 0 { return "0" }
        let intPart = wei / oneE18
        let frac = wei % oneE18
        if frac == 0 {
            return String(intPart, radix: 10)
        }
        var fracDigits = String(frac, radix: 10)
        if fracDigits.count < 18 {
            fracDigits = String(repeating: "0", count: 18 - fracDigits.count) + fracDigits
        }
        while fracDigits.last == "0", !fracDigits.isEmpty {
            fracDigits.removeLast()
        }
        if fracDigits.isEmpty {
            return String(intPart, radix: 10)
        }
        return "\(String(intPart, radix: 10)).\(fracDigits)"
    }
}
