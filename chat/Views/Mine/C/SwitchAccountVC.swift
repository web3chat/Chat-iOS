//
//  SwitchAccountVC.swift
//  chat
//
//  Created by Cursor on 2026/4/7.
//

import UIKit
import SnapKit
import Kingfisher

private struct SwitchAccountItem {
    var address: String
    var avatarurl: String
    var name: String
    var phone: String
    var encryptedRemembercode: String
    var encryptedPassword: String
}

private final class SwitchAccountCell: UITableViewCell {

    private let bgContainerView = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    private let loginStatusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = Color_F6F7F8
        contentView.backgroundColor = Color_F6F7F8

        bgContainerView.backgroundColor = .white
        bgContainerView.layer.cornerRadius = 6
        bgContainerView.layer.masksToBounds = true
        contentView.addSubview(bgContainerView)
        bgContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
        }

        avatarImageView.layer.cornerRadius = 20
        avatarImageView.layer.masksToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        bgContainerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 40, height: 40))
        }

        loginStatusLabel.font = .systemFont(ofSize: 12)
        loginStatusLabel.textAlignment = .right
        bgContainerView.addSubview(loginStatusLabel)
        loginStatusLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
        }

        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = Color_24374E
        nameLabel.numberOfLines = 1
        bgContainerView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(12)
            make.top.equalToSuperview().offset(14)
            make.right.lessThanOrEqualTo(loginStatusLabel.snp.left).offset(-8)
        }

        phoneLabel.font = .systemFont(ofSize: 13)
        phoneLabel.textColor = Color_8A97A5
        bgContainerView.addSubview(phoneLabel)
        phoneLabel.snp.makeConstraints { make in
            make.left.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
            make.right.equalToSuperview().offset(-12)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    func configure(with item: SwitchAccountItem, currentAddress: String) {
        if let url = URL(string: item.avatarurl), !item.avatarurl.isEmpty {
            avatarImageView.kf.setImage(with: url, placeholder: UIImage(named: "avatar_persion"))
        } else {
            avatarImageView.image = UIImage(named: "avatar_persion")
        }

        let nameText = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let addressText = item.address.trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = nameText.isEmpty ? Self.maskedAddress(addressText) : (nameText == addressText ? Self.maskedAddress(addressText) : nameText)

        let phoneText = item.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondaryText = phoneText.isEmpty ? Self.maskedAddress(addressText) : Self.maskedPhone(phoneText)
        phoneLabel.text = secondaryText
        phoneLabel.isHidden = secondaryText.isEmpty

        let isCurrent = item.address == currentAddress
        loginStatusLabel.text = isCurrent ? L("已登录") : L("未登录")
        loginStatusLabel.textColor = isCurrent ? Color_Theme : Color_8A97A5
    }

    private static func maskedPhone(_ phone: String) -> String {
        let text = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 7 else { return text }
        return "\(text.prefix(3))****\(text.suffix(4))"
    }

    private static func maskedAddress(_ address: String) -> String {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 16 else { return text }
        return "\(text.prefix(8))****\(text.suffix(8))"
    }
}

final class SwitchAccountVC: UIViewController, ViewControllerProtocol {

    private var accountList: [SwitchAccountItem] = []
    /// 监听 `k_importwallet`（PreCoin 补币完成）
    private var walletReadyObserver: NSObjectProtocol?
    private var didFinishSwitchAccount = false

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.separatorStyle = .none
        view.delegate = self
        view.dataSource = self
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.register(SwitchAccountCell.self, forCellReuseIdentifier: "SwitchAccountCell")
        return view
    }()

    private lazy var bottomActionContainer: UIView = {
        let v = UIView()
        v.backgroundColor = Color_F6F7F8
        return v
    }()

    private lazy var addOtherAccountButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L("添加其他账号"), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 8
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(addOtherAccountTapped), for: .touchUpInside)
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("已有的账号")
        view.backgroundColor = Color_F6F7F8
        xls_navigationBarBackgroundColor = Color_F6F7F8
        xls_navigationBarTintColor = Color_24374E

        view.addSubview(bottomActionContainer)
        bottomActionContainer.addSubview(addOtherAccountButton)

        bottomActionContainer.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }
        addOtherAccountButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalTo(bottomActionContainer.safeAreaLayoutGuide.snp.bottom).offset(-12)
            make.height.equalTo(48)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(bottomActionContainer.snp.top)
        }

        reloadAccounts()
    }

    @objc private func addOtherAccountTapped() {
        ChooseAccountVC.isAddingAccountFromSwitchAccountPage = true
        let vc = ChooseAccountVC(nibName: "ChooseAccountVC", bundle: nil)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAccounts()
    }

    private func reloadAccounts() {
        guard let dbList = PWDataBaseManager.shared().queryAllUserInfoData() as? [[String: Any]] else {
            accountList = []
            tableView.reloadData()
            return
        }

        var list = dbList.compactMap { data -> SwitchAccountItem? in
            let address = (data["address"] as? String) ?? ""
            if address.isEmpty { return nil }
            return SwitchAccountItem(address: address,
                                     avatarurl: (data["avatarurl"] as? String) ?? "",
                                     name: (data["name"] as? String) ?? "",
                                     phone: (data["phone"] as? String) ?? "",
                                     encryptedRemembercode: (data["encryptedRemembercode"] as? String) ?? "",
                                     encryptedPassword: (data["encryptedPassword"] as? String) ?? "")
        }

        list.sort { lhs, rhs in
            let currentAddress = LoginUser.shared().address
            if lhs.address == currentAddress { return true }
            if rhs.address == currentAddress { return false }
            let lhsName = lhs.name.isEmpty ? lhs.address : lhs.name
            let rhsName = rhs.name.isEmpty ? rhs.address : rhs.name
            return lhsName < rhsName
        }

        accountList = list
        tableView.reloadData()
    }

    private func handleSelect(account: SwitchAccountItem) {
        if account.address == LoginUser.shared().address {
            navigationController?.popViewController(animated: true)
            return
        }

        let alert = InputAlertView()
        alert.title = L("请输入密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString(string: L("请输入密码"), attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_8A97A5])
        alert.isSecureTextEntry = true
        alert.confirmBlock = { [weak self] password in
            self?.switchAccount(account: account, password: password)
        }
        alert.show()
    }

    private func switchAccount(account: SwitchAccountItem, password: String) {
        guard !account.encryptedRemembercode.isEmpty, !account.encryptedPassword.isEmpty else {
            showToast(L("账号数据不完整，请重新登录该账号"))
            return
        }

        guard GoFunction.checkPassword(password, hash: account.encryptedPassword) else {
            showToast(L("密码错误"))
            return
        }

        guard let seed = GoFunction.deckey(account.encryptedRemembercode, password: password), !seed.isEmpty else {
            showToast(L("助记词解析失败，请重新登录"))
            return
        }

        guard let keys = SeedManager.keyBy(seed: seed),
              !keys.priKey.isEmpty,
              !keys.pubKey.isEmpty else {
            showToast(L("账号解析失败，请重新登录"))
            return
        }

        let walletAddress = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
        guard !walletAddress.isEmpty else {
            showToast(L("地址解析失败，请重新登录"))
            return
        }

        if account.address != walletAddress {
            showToast(L("账号数据异常，请重新登录"))
            return
        }

        // 切换账号前先清理当前账号运行态数据，避免会话/数据库连接残留导致数据串号
        if LoginUser.shared().isLogin {
            LoginUser.shared().logout()
        }

        let phone = account.phone
        if phone.count != 0{
            LoginUser.shared().bindSeedPhone = phone
        }
        LoginUser.shared().login(seed: seed,
                                 encSeed: account.encryptedRemembercode,
                                 priKey: keys.priKey.finalKey,
                                 pubKey: keys.pubKey.finalKey,
                                 address: walletAddress,
                                 encPasswd: account.encryptedPassword)

        showProgress()

        // `PreCoin.add(intoW:)` 里「选中本账号的钱包」是同步的，但「补币」是异步的（建 HD 钱包 +
        // 逐币算地址写库）。原来这里紧接着 reloadView()，资产页会在新钱包还没有币的时候渲染出来，
        // 看上去就是「钱包没跟着切，要重进 app 才对」。这里改成等 `k_importwallet`
        // （与 ImportSeedVC 的做法一致，那个页面就是靠这条通知结束 loading 的）。
        observeWalletReadyThenReload()

        let precoin = PreCoin()
        precoin.add(intoW: seed,passwd: password)
    }

    /// 等 PreCoin 把钱包/币写完再重建首页；8s 内没等到也先重建（旧行为兜底）
    private func observeWalletReadyThenReload() {
        walletReadyObserver = NotificationCenter.default.addObserver(forName: Notification.Name("k_importwallet"),
                                                                   object: nil,
                                                                   queue: .main) { [weak self] _ in
            self?.finishSwitchAccount()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.finishSwitchAccount()
        }
    }

    private func finishSwitchAccount() {
        guard !didFinishSwitchAccount else { return }
        didFinishSwitchAccount = true

        if let observer = walletReadyObserver {
            NotificationCenter.default.removeObserver(observer)
            walletReadyObserver = nil
        }
        hideProgress()
        APP.shared().reloadView()
    }

    private func confirmDeleteAccount(_ account: SwitchAccountItem) {
        let alert = TwoBtnInfoAlertView()
        alert.title = L("提示")
        alert.info = L("确定要删除该账号吗？")
        alert.leftBtnTitle = L("取消")
        alert.rightBtnTitle = L("删除")
        alert.rightBtnTouchBlock = { [weak self] in
            self?.deleteAccount(account)
        }
        alert.show()
    }

    private func deleteAccount(_ account: SwitchAccountItem) {
        if account.address == LoginUser.shared().address {
            showToast(L("当前登录账号不可删除"))
            return
        }

        let success = PWDataBaseManager.shared().deleteUserInfo(withAddress: account.address)
        guard success else {
            showToast(L("删除失败，请稍后重试"))
            return
        }

        reloadAccounts()
        showToast(L("删除成功"))
    }
}

extension SwitchAccountVC: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accountList.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard accountList.indices.contains(indexPath.row) else { return 76 }
        let item = accountList[indexPath.row]
        let phoneText = item.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let addressText = item.address.trimmingCharacters(in: .whitespacesAndNewlines)
        return (phoneText.isEmpty && addressText.isEmpty) ? 76 : 92
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchAccountCell", for: indexPath) as? SwitchAccountCell else {
            return UITableViewCell()
        }
        guard accountList.indices.contains(indexPath.row) else {
            return cell
        }

        let item = accountList[indexPath.row]
        cell.configure(with: item, currentAddress: LoginUser.shared().address)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard accountList.indices.contains(indexPath.row) else { return }
        handleSelect(account: accountList[indexPath.row])
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard accountList.indices.contains(indexPath.row) else { return false }
        let item = accountList[indexPath.row]
        return item.address != LoginUser.shared().address
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return L("删除")
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        guard accountList.indices.contains(indexPath.row) else { return }

        let item = accountList[indexPath.row]
        if item.address == LoginUser.shared().address {
            showToast(L("当前登录账号不可删除"))
            return
        }
        tableView.setEditing(false, animated: true)
        confirmDeleteAccount(item)
    }
}
