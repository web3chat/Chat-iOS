//
//  TokenApproveListVC.swift
//  chat
//
//  Created by on 2024/6/4.
//

import UIKit
import SnapKit
import web3swift
import Web3Core
import BigInt

@objc class TokenApproveListVC: UIViewController {
    
    private let walletAddress: String
    private let rpcURL: String
    private var approvals: [TokenApprovalInfo] = []
    private var isLoading = true
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(ApproveCell.self, forCellReuseIdentifier: "ApproveCell")
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        tv.separatorStyle = .none
        tv.backgroundColor = Color_F6F7F8
        return tv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()
    
    private lazy var emptyLabel: UILabel = {
        let lab = UILabel()
        lab.text = L("暂无授权记录")
        lab.textColor = Color_8A97A5
        lab.font = UIFont.systemFont(ofSize: 14)
        lab.textAlignment = .center
        lab.isHidden = true
        return lab
    }()
    
    private lazy var progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.trackTintColor = Color_F6F7F8
        pv.progressTintColor = Color_Theme
        pv.isHidden = true
        return pv
    }()

    /// 页面底部：本次检查了哪些链的多少个代币（空列表时尤其重要）
    private lazy var scopeLabel: UILabel = {
        let lab = UILabel()
        lab.font = UIFont.systemFont(ofSize: 12)
        lab.textColor = Color_8A97A5
        lab.textAlignment = .center
        lab.numberOfLines = 2
        lab.isHidden = true
        return lab
    }()
    
    @objc init(walletAddress: String, rpcURL: String) {
        self.walletAddress = walletAddress
        self.rpcURL = rpcURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("授权管理")
        view.backgroundColor = Color_F6F7F8
        setupNavBar()
        setupUI()
        loadApprovals()
    }
    
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
            appearance.backgroundColor = .white
            appearance.shadowColor = .clear
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        let backItem = UIBarButtonItem(image: UIImage(named: "nav_back"),
                                       style: .plain,
                                       target: self,
                                       action: #selector(goBack))
        backItem.tintColor = UIColor(hexString: "#333649")
        navigationItem.leftBarButtonItem = backItem
    }
    
    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupUI() {
        view.addSubview(progressView)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        view.addSubview(loadingIndicator)
        view.addSubview(scopeLabel)
        
        progressView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(2)
        }
        
        scopeLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(scopeLabel.snp.top).offset(-8)
        }
        
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func loadApprovals() {
        isLoading = true
        loadingIndicator.startAnimating()
        progressView.isHidden = false
        progressView.progress = 0
        
        let coins = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID() as? [LocalCoin] ?? []
        self.scopeLabel.text = Self.scopeText(for: coins)
        
        TokenApproveService.shared.queryWalletApprovals(
            walletAddress: walletAddress,
            coinList: coins,
            progress: { [weak self] completed, total in
                self?.progressView.progress = Float(completed) / Float(max(total, 1))
            },
            completion: { [weak self] results in
                guard let self = self else { return }
                self.isLoading = false
                self.approvals = results
                self.loadingIndicator.stopAnimating()
                self.progressView.isHidden = true
                self.tableView.reloadData()
                self.emptyLabel.isHidden = !results.isEmpty
                self.scopeLabel.isHidden = !results.isEmpty
            }
        )
    }

    /// 「已检查 ETH 2 个 / BTY 11 个代币」——避免用户以为页面坏了
    private static func scopeText(for coins: [LocalCoin]) -> String {
        let counts = TokenApproveService.tokenCounts(in: coins)
        guard !counts.isEmpty else { return L("钱包里还没有合约代币，添加后才会显示授权") }
        let parts = counts.map { "\($0.chain.rawValue) \($0.count)" }
        return L("已检查代币") + "：" + parts.joined(separator: " · ")
    }
    
    private func showRevokeAlert(for approval: TokenApprovalInfo) {
        let sheet = RevokeConfirmSheet(
            approval: approval,
            walletAddress: walletAddress,
            rpcURL: approval.chain.rpcURLs.first ?? rpcURL,
            onConfirm: { [weak self] password, gasPrice, gasLimit in
                self?.performRevoke(approval: approval, password: password, gasPrice: gasPrice, gasLimit: gasLimit)
            },
            onCancel: {}
        )
        sheet.show(in: view, host: self)
    }
    
    private func performRevoke(approval: TokenApprovalInfo, password: String, gasPrice: String, gasLimit: String) {
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        guard GoFunction.checkPassword(password, hash: wallet?.wallet_password) else {
            showToast(L("密码错误"))
            return
        }
        
        showProgress(with: nil)
        Task {
            do {
                _ = try await TokenApproveService.shared.revokeApproval(
                    tokenAddress: approval.tokenAddress,
                    spenderAddress: approval.spender,
                    rpcURLs: approval.chain.rpcURLs,
                    password: password
                )
                await MainActor.run {
                    self.hideProgress()
                    self.showToast(L("取消授权成功"))
                    // 动态查找当前索引（列表可能因之前的删除而变化，避免用过期索引导致越界崩溃）
                    guard let currentIndex = self.approvals.firstIndex(where: {
                        $0.tokenAddress == approval.tokenAddress && $0.spender == approval.spender
                    }) else {
                        self.emptyLabel.isHidden = !self.approvals.isEmpty
                        self.tableView.reloadData()
                        return
                    }
                    self.approvals.remove(at: currentIndex)
                    self.tableView.deleteRows(at: [IndexPath(row: currentIndex, section: 0)], with: .automatic)
                    self.emptyLabel.isHidden = !self.approvals.isEmpty
                }
            } catch {
                await MainActor.run {
                    self.hideProgress()
                    self.showToast(L("取消授权失败：") + error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - UITableView
extension TokenApproveListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return approvals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ApproveCell", for: indexPath) as! ApproveCell
        let approval = approvals[indexPath.row]
        cell.configure(with: approval, onRevoke: { [weak self] in
            self?.showRevokeAlert(for: approval)
        })
        return cell
    }
}

// MARK: - Cell
class ApproveCell: UITableViewCell {
    
    private let tokenLabel = UILabel()
    private let spenderLabel = UILabel()
    private let amountLabel = UILabel()
    private let revokeBtn = UIButton(type: .system)
    private var onRevoke: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .white
        contentView.backgroundColor = .white
        
        tokenLabel.font = UIFont.boldSystemFont(ofSize: 15)
        tokenLabel.textColor = Color_24374E
        
        spenderLabel.font = UIFont.systemFont(ofSize: 12)
        spenderLabel.textColor = Color_8A97A5
        spenderLabel.numberOfLines = 0
        
        amountLabel.font = UIFont.systemFont(ofSize: 13)
        amountLabel.textColor = Color_8A97A5
        
        revokeBtn.setTitle(L("取消授权"), for: .normal)
        revokeBtn.setTitleColor(.white, for: .normal)
        revokeBtn.backgroundColor = Color_DD5F5F
        revokeBtn.layer.cornerRadius = 4
        revokeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
        revokeBtn.contentEdgeInsets = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        revokeBtn.addTarget(self, action: #selector(revokeTapped), for: .touchUpInside)
        revokeBtn.snp.makeConstraints { make in
            make.width.equalTo(60)
        }
        
        contentView.addSubview(tokenLabel)
        contentView.addSubview(spenderLabel)
        contentView.addSubview(amountLabel)
        contentView.addSubview(revokeBtn)
        
        tokenLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(15)
            make.right.equalTo(revokeBtn.snp.left).offset(-10)
        }
        
        spenderLabel.snp.makeConstraints { make in
            make.top.equalTo(tokenLabel.snp.bottom).offset(4)
            make.left.equalTo(tokenLabel)
            make.right.equalTo(tokenLabel)
        }
        
        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(spenderLabel.snp.bottom).offset(4)
            make.left.equalTo(tokenLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        revokeBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
        }
        
        // 底部分隔线
        let line = UIView()
        line.backgroundColor = Color_F6F7F8
        contentView.addSubview(line)
        line.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    func configure(with approval: TokenApprovalInfo, onRevoke: @escaping () -> Void) {
        self.onRevoke = onRevoke
        tokenLabel.text = approval.tokenSymbol
        spenderLabel.text = "\(L("授权给")) \(approval.spenderName)"
        amountLabel.text = "\(L("授权数量")): \(formatApprovalAmount(approval.allowance, decimals: approval.decimals))"
    }
    
    /// 格式化授权数量，超大值（接近 uint256 max）显示为"无限"
    private func formatApprovalAmount(_ amount: BigUInt, decimals: Int) -> String {
        let maxUint256 = BigUInt(2).power(256) - 1
        let threshold = maxUint256 / 2
        if amount > threshold {
            return L("无限")
        }
        return formatAmount(amount, decimals: decimals)
    }
    
    private func formatAmount(_ amount: BigUInt, decimals: Int) -> String {
        let base = BigUInt(10).power(decimals)
        let integer = amount / base
        let fraction = amount % base
        if fraction == 0 {
            return integer.description
        }
        var fracStr = String(fraction)
        while fracStr.count < decimals {
            fracStr = "0" + fracStr
        }
        while fracStr.hasSuffix("0") {
            fracStr.removeLast()
        }
        if fracStr.isEmpty {
            return integer.description
        }
        return "\(integer).\(fracStr)"
    }
    
    @objc private func revokeTapped() {
        onRevoke?()
    }
}
//
//  RevokeConfirmSheet.swift
//  chat
//
//  Created by on 2024/6/4.
//

import UIKit
import SnapKit
import BigInt
import web3swift
import Web3Core

/// 取消授权确认底部弹窗
final class RevokeConfirmSheet: UIView {
    
    private let approval: TokenApprovalInfo
    private let walletAddress: String
    private let rpcURL: String
    private let onConfirm: (String, String, String) -> Void  // password, gasPrice, gasLimit
    private let onCancel: () -> Void
    
    private let dimView = UIView()
    private let panel = UIView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let passwordField = UITextField()
    private let gasPriceField = UITextField()
    private let gasLimitField = UITextField()
    
    private var estimatedGasPrice: BigUInt = 0
    private var estimatedGasLimit: BigUInt = 21000
    private var isLoadingFee = false
    
    /// 根据授权所在链确定矿工费币种（不能再看 RPC 字符串了：ETH 用的是 publicnode，字符串里没有 eth 关键字）
    private var gasSymbol: String {
        approval.chain.gasSymbol
    }
    
    init(approval: TokenApprovalInfo,
         walletAddress: String,
         rpcURL: String,
         onConfirm: @escaping (String, String, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.approval = approval
        self.walletAddress = walletAddress
        self.rpcURL = rpcURL
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(frame: .zero)
        setupUI()
        estimateGas()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func show(in view: UIView, host: UIViewController) {
        frame = view.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(self)
        panel.snp.updateConstraints { make in
            make.height.lessThanOrEqualTo(view.bounds.height * 0.7)
        }
        layoutIfNeeded()
        panel.transform = CGAffineTransform(translationX: 0, y: panel.bounds.height + 40)
        dimView.alpha = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.dimView.alpha = 1
            self.panel.transform = .identity
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // 已开启面容/指纹：等弹层上来后自动验证并提交；未开启/验证失败则停留在此页让用户手输
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            ChatPasswordGate.fetchVerifiedPassword(reason: L("验证身份以取消授权")) { [weak self] password in
                guard let self = self, let password = password else { return }
                self.passwordField.text = password
                self.confirmTapped()
            }
        }
    }
    
    private func dismiss() {
        NotificationCenter.default.removeObserver(self)
        UIView.animate(withDuration: 0.25, animations: {
            self.dimView.alpha = 0
            self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height + 40)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
    
    // MARK: - UI
    private func setupUI() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dimView)
        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        panel.backgroundColor = .white
        panel.layer.cornerRadius = 16
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        addSubview(panel)
        panel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.lessThanOrEqualTo(500)
        }
        
        scrollView.showsVerticalScrollIndicator = false
        panel.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        stackView.axis = .vertical
        stackView.spacing = 0
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(panel)
        }
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = L("取消授权")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.textColor = UIColor(hexString: "#333649")
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(wrap(titleLabel, top: 20, bottom: 12))
        
        // Info rows
        addInfoRow(L("代币"), approval.tokenSymbol)
        addInfoRow(L("授权对象"), approval.spenderName)
        addInfoRow(L("合约地址"), approval.spender)
        addInfoRow(L("授权数量"), formatAmount(approval.allowance, decimals: approval.decimals))
        addInfoRow(L("钱包地址"), shortAddress(walletAddress))
        
        // Divider
        stackView.addArrangedSubview(line())
        
        // Gas title
        let gasTitle = UILabel()
        gasTitle.text = L("矿工费")
        gasTitle.font = UIFont.boldSystemFont(ofSize: 15)
        gasTitle.textColor = UIColor(hexString: "#333649")
        stackView.addArrangedSubview(wrap(gasTitle, top: 12, bottom: 4))
        
        // Gas Price row
        gasPriceField.borderStyle = .roundedRect
        gasPriceField.keyboardType = .decimalPad
        gasPriceField.placeholder = L("Gas Price (Gwei)")
        gasPriceField.font = UIFont.systemFont(ofSize: 14)
        let gpRow = labeledField(L("Gas Price"), gasPriceField)
        stackView.addArrangedSubview(gpRow)
        
        // Gas Limit row
        gasLimitField.borderStyle = .roundedRect
        gasLimitField.keyboardType = .numberPad
        gasLimitField.placeholder = L("Gas Limit")
        gasLimitField.font = UIFont.systemFont(ofSize: 14)
        let glRow = labeledField(L("Gas Limit"), gasLimitField)
        stackView.addArrangedSubview(glRow)
        
        // Estimated fee display
        let feeLabel = UILabel()
        feeLabel.font = UIFont.systemFont(ofSize: 12)
        feeLabel.textColor = UIColor(hexString: "#8A97A5")
        feeLabel.tag = 999
        stackView.addArrangedSubview(wrap(feeLabel, top: 2, bottom: 8))
        
        // Password
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.placeholder = L("请输入密聊密码")
        passwordField.font = UIFont.systemFont(ofSize: 14)
        let pwRow = labeledField(L("密码"), passwordField)
        stackView.addArrangedSubview(pwRow)
        
        // Buttons row
        let btnStack = UIStackView()
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually
        
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(L("取消"), for: .normal)
        cancelBtn.setTitleColor(UIColor(hexString: "#8A97A5"), for: .normal)
        cancelBtn.backgroundColor = UIColor(hexString: "#F6F7F8")
        cancelBtn.layer.cornerRadius = 8
        cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle(L("确认取消授权"), for: .normal)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.backgroundColor = UIColor(hexString: "#DD5F5F")
        confirmBtn.layer.cornerRadius = 8
        confirmBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        confirmBtn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        
        btnStack.addArrangedSubview(cancelBtn)
        btnStack.addArrangedSubview(confirmBtn)
        stackView.addArrangedSubview(wrap(btnStack, top: 16, bottom: 30))
    }
    
    private func wrap(_ v: UIView, top: CGFloat = 0, bottom: CGFloat = 0) -> UIView {
        let w = UIView()
        w.addSubview(v)
        v.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(top)
            make.bottom.equalToSuperview().offset(-bottom)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }
        return w
    }
    
    private func line() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(hexString: "#F0F0F0")
        v.snp.makeConstraints { $0.height.equalTo(0.5) }
        return wrap(v, top: 8, bottom: 0)
    }
    
    private func labeledField(_ label: String, _ field: UITextField) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        let lab = UILabel()
        lab.text = label
        lab.font = UIFont.systemFont(ofSize: 13)
        lab.textColor = UIColor(hexString: "#8A97A5")
        lab.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(lab)
        row.addArrangedSubview(field)
        return wrap(row, top: 4, bottom: 4)
    }
    
    private func addInfoRow(_ label: String, _ value: String) {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        let lab = UILabel()
        lab.text = label
        lab.font = UIFont.systemFont(ofSize: 13)
        lab.textColor = UIColor(hexString: "#8A97A5")
        lab.setContentHuggingPriority(.required, for: .horizontal)
        let val = UILabel()
        val.text = value
        val.font = UIFont.systemFont(ofSize: 11)
        val.textColor = UIColor(hexString: "#333649")
        val.textAlignment = .right
        val.numberOfLines = 0
        val.lineBreakMode = .byCharWrapping
        row.addArrangedSubview(lab)
        row.addArrangedSubview(val)
        stackView.addArrangedSubview(wrap(row, top: 2, bottom: 2))
    }
    
    private func shortAddress(_ addr: String) -> String {
        guard addr.count > 12 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
    
    private func formatAmount(_ amount: BigUInt, decimals: Int) -> String {
        let maxUint256 = BigUInt(2).power(256) - 1
        if amount > maxUint256 / 2 { return L("无限") }
        let base = BigUInt(10).power(decimals)
        let integer = amount / base
        let fraction = amount % base
        if fraction == 0 { return integer.description }
        var fracStr = String(fraction)
        while fracStr.count < decimals { fracStr = "0" + fracStr }
        while fracStr.hasSuffix("0") { fracStr.removeLast() }
        return fracStr.isEmpty ? integer.description : "\(integer).\(fracStr)"
    }
    
    // MARK: - Gas Estimation
    private func estimateGas() {
        isLoadingFee = true
        gasPriceField.text = L("估算中...")
        gasLimitField.text = "21000"
        
        Task {
            do {
                guard let url = URL(string: rpcURL) else { return }
                let web3 = try await Web3.new(url)
                let gasPrice = try await web3.eth.gasPrice()
                estimatedGasPrice = gasPrice
                
                let gwei = Double(gasPrice) / 1_000_000_000
                await MainActor.run {
                    gasPriceField.text = String(format: "%.2f", gwei)
                    updateFeeDisplay()
                }
            } catch {
                await MainActor.run {
                    gasPriceField.text = "5"
                    updateFeeDisplay()
                }
            }
            isLoadingFee = false
        }
    }
    
    private func updateFeeDisplay() {
        let gpStr = gasPriceField.text ?? "0"
        let glStr = gasLimitField.text ?? "21000"
        guard let gpGwei = Double(gpStr), let gl = Double(glStr) else { return }
        let feeEth = gpGwei * 1e-9 * gl
        if let label = stackView.viewWithTag(999) as? UILabel {
            label.text = "\(L("预估矿工费")): \(String(format: "%.8f", feeEth)) \(gasSymbol)"
        }
    }
    
    // MARK: - Actions
    @objc private func dimTapped() {
        endEditing(true)
    }
    
    @objc private func cancelTapped() {
        dismiss()
        onCancel()
    }
    
    @objc private func confirmTapped() {
        guard let password = passwordField.text, !password.isEmpty else {
            APP.shared().showToast(L("请输入密码"))
            return
        }
        let gasPrice = gasPriceField.text ?? "5"
        let gasLimit = gasLimitField.text ?? "21000"
        dismiss()
        onConfirm(password, gasPrice, gasLimit)
    }
    
    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let kbFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.panel.transform = CGAffineTransform(translationX: 0, y: -kbFrame.height)
        }
    }
    
    @objc private func keyboardWillHide(_ n: Notification) {
        let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.panel.transform = .identity
        }
    }
}
