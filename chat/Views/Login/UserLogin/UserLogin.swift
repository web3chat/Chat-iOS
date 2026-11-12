//
//  UserLogin.swift
//  chat
//
//  Created by 郑晨 on 2025/11/10.
//

import Foundation
import Kingfisher

private struct UserLoginAccount {
    var address: String
    var avatarurl: String
    var name: String
    var phone: String
    var encryptedRemembercode: String
    var encryptedPassword: String
}

// MARK: - 账号选择 Cell
private final class UserLoginAccountCell: UITableViewCell {
    
    private let cardView = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    
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
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // 白色卡片
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 8
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 1)
        cardView.layer.shadowOpacity = 0.06
        cardView.layer.shadowRadius = 4
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }
        
        // 头像
        avatarImageView.layer.cornerRadius = 22
        avatarImageView.layer.masksToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        cardView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 44, height: 44))
        }
        
        // 选中勾
        checkmarkImageView.image = UIImage(named: "choose_pro_sel")
        checkmarkImageView.isHidden = true
        cardView.addSubview(checkmarkImageView)
        checkmarkImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 20))
        }
        
        // 昵称
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = Color_24374E
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(12)
            make.top.equalToSuperview().offset(14)
            make.right.lessThanOrEqualTo(checkmarkImageView.snp.left).offset(-8)
        }
        
        // 副标题（手机号或地址）
        subLabel.font = .systemFont(ofSize: 13)
        subLabel.textColor = Color_8A97A5
        cardView.addSubview(subLabel)
        subLabel.snp.makeConstraints { make in
            make.left.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.right.equalToSuperview().offset(-12)
        }
    }
    
    func configure(with account: UserLoginAccount, isSelected: Bool) {
        if let url = URL(string: account.avatarurl), !account.avatarurl.isEmpty {
            avatarImageView.kf.setImage(with: url, placeholder: UIImage(named: "avatar_persion"))
        } else {
            avatarImageView.image = UIImage(named: "avatar_persion")
        }
        
        let displayName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = displayName.isEmpty ? account.address.shortAddress : displayName
        
        let phoneText = account.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phoneText.isEmpty {
            subLabel.text = maskedPhone(phoneText)
        } else {
            subLabel.text = account.address.shortAddress
        }
        
        checkmarkImageView.isHidden = !isSelected
        cardView.layer.borderWidth = isSelected ? 1.5 : 0
        cardView.layer.borderColor = isSelected ? Color_Theme.cgColor : UIColor.clear.cgColor
    }
    
    private func maskedPhone(_ phone: String) -> String {
        let text = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 7 else { return text }
        return "\(text.prefix(3))****\(text.suffix(4))"
    }
}

@objc class UserLoginVC: UIViewController, ViewControllerProtocol, UITextFieldDelegate {
    
    private let bag = DisposeBag.init()
    @objc var pwd: String = "1111111111"

    private var accountList: [UserLoginAccount] = []
    private var selectedAccount: UserLoginAccount?
    
    private lazy var tableView:UITableView = {
        let v = UITableView.init(frame: .zero, style: .grouped)
        v.backgroundColor = Color_FAFBFC
        v.contentInsetAdjustmentBehavior = .never
        v.separatorStyle = .none
        v.delegate = self
        v.dataSource = self
        v.keyboardDismissMode = .onDrag
        v.showsVerticalScrollIndicator = false
        v.register(UserLoginAccountCell.self, forCellReuseIdentifier: "UserLoginAccountCell")
        v.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 8))
        return v
    }()
    
    /// 半透明遮罩，点击可关闭账号列表
    private lazy var overlayView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        v.isHidden = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissAccountList))
        v.addGestureRecognizer(tap)
        return v
    }()
    
    
    private lazy var avatarImageView: UIImageView = {
        let v = UIImageView.init()
        v.image = #imageLiteral(resourceName: "avatar_persion")
        v.layer.masksToBounds = true
        v.layer.cornerRadius = 40
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor(hexString: "#E8ECF0")?.cgColor
        v.isUserInteractionEnabled = true
        
        let headImgTap = UITapGestureRecognizer()
        headImgTap.rx.event.subscribe {[weak self] (_) in
            self?.showChoiceAccount()
        }.disposed(by: bag)
        v.addGestureRecognizer(headImgTap)
        
        return v
    }()
    
    private lazy var nickNameLab: UILabel = {
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 18), textColor: UIColor.init(hexString: "#333649"), textAlignment: .center, text: "")
        lab.isUserInteractionEnabled = true
        let nickNamelabTap = UITapGestureRecognizer()
        nickNamelabTap.rx.event.subscribe{ [weak self] (_) in
            self?.showChoiceAccount()
        }.disposed(by: bag)
        lab.addGestureRecognizer(nickNamelabTap)
        return lab
    }()
    
    private lazy var accountHintLabel: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .center, text: L("点击头像或昵称切换账号"))
        return lab
    }()
    
    private lazy var pwdText:CommonTextField = {
        let pwdText = CommonTextField()
        pwdText.textColor = Color_24374E
        pwdText.placeholder = L("请输入密聊密码");
        pwdText.keyboardType = UIKeyboardType.asciiCapable;
        pwdText.isSecureTextEntry = true;
        pwdText.delegate = self;
        pwdText.tag = 100;
        return pwdText
    }()
    
    lazy var okBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("登录"), for: .normal)
        btn.layer.cornerRadius = 6
        btn.backgroundColor = Color_Theme
        btn.addTarget(self, action: #selector(okBtnTouch), for: .touchUpInside)
       
        return btn
    }()
    
    lazy var changeBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("切换登录方式"), for: .normal)
        btn.layer.cornerRadius = 6
        btn.titleLabel?.font = .systemFont(ofSize: 12)
        btn.setTitleColor(Color_Theme, for: .normal)
//        btn.backgroundColor = UIColor.init(hexString: "#5D6377")
        btn.addTarget(self, action: #selector(changeBtnTouch), for: .touchUpInside)
        
        return btn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xls_isNavigationBarHidden = true
        self.view.backgroundColor = UIColor.white

        self.setupViews()
        
        // 从数据库查询登录过的账户数据
        self.reloadAccounts()
        
        // 从中心化服务器获取默认的聊天服务器地址和区块链节点地址
        getOfficialServerRequest(type: 0)
        
    }
    
    /// 从数据库查询所有登录过的账户数据（与切换账号页面使用同一数据源）
    private func reloadAccounts() {
        guard let dbList = PWDataBaseManager.shared().queryAllUserInfoData() as? [[String: Any]] else {
            accountList = []
            return
        }
        
        accountList = dbList.compactMap { data -> UserLoginAccount? in
            let address = (data["address"] as? String) ?? ""
            if address.isEmpty { return nil }
            return UserLoginAccount(address: address,
                                    avatarurl: (data["avatarurl"] as? String) ?? "",
                                    name: (data["name"] as? String) ?? "",
                                    phone: (data["phone"] as? String) ?? "",
                                    encryptedRemembercode: (data["encryptedRemembercode"] as? String) ?? "",
                                    encryptedPassword: (data["encryptedPassword"] as? String) ?? "")
        }
        
        // 保持当前选中状态：无选中时优先上次登录的账号，其次默认第一个
        if let current = selectedAccount,
           let stillExists = accountList.first(where: { $0.address == current.address }) {
            selectAccount(stillExists)
        } else if selectedAccount == nil {
            let lastAddress = UserDefaults.standard.string(forKey: LoginUser.lastLoginAddressKey)
            if let lastAddr = lastAddress,
               let lastAccount = accountList.first(where: { $0.address == lastAddr }) {
                selectAccount(lastAccount)
            } else if let firstAccount = accountList.first {
                selectAccount(firstAccount)
            }
        }
        
        tableView.reloadData()
    }
    
    /// 选中某个账户，更新头像和昵称
    private func selectAccount(_ account: UserLoginAccount) {
        selectedAccount = account
        if let url = URL(string: account.avatarurl), !account.avatarurl.isEmpty {
            avatarImageView.kf.setImage(with: url, placeholder: #imageLiteral(resourceName: "avatar_persion"))
        } else {
            avatarImageView.image = #imageLiteral(resourceName: "avatar_persion")
        }
        let displayName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        nickNameLab.text = displayName.isEmpty ? account.address.shortAddress : displayName
    }
    
    private var getOfficialServerSuccessFlg = false// 获取服务器地址成功标志
    
    /// 从中心化服务器获取默认的IM服务器地址和区块链节点地址
    /// - Parameter type: 回调成功后执行方法 0: 不执行 1:创建账户 2:导入账户 3:登录
    private func getOfficialServerRequest(type: Int) {
        guard !getOfficialServerSuccessFlg else {
            return
        }
        // 未配置服务器地址时不发起发现请求，避免登录页弹出网络错误；创建/导入钱包可直接进入
        guard !BackupURL.isBlank else {
            return
        }
//        self.view.showActivity()
        APP.shared().getOfficialServerRequest { [weak self] (json) in
            guard let strongSelf = self else { return }
//            strongSelf.view.hideActivity()
            
            strongSelf.getOfficialServerSuccessFlg = true
            
            // 设置默认IM服务器和区块链节点服务器
            strongSelf.setupDefaultServer()
            
            switch type {
            case 1:
                strongSelf.createAccount()
            case 2:
                strongSelf.importAccount()
            case 3:
                strongSelf.phoneLoginTap()
            default: break
            }
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
//            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    // 设置默认IM服务器和区块链节点服务器
    private func setupDefaultServer() {
        if let server = OfficialBlockchainServers?.first {
            BlockchainServerInUse = server
        }
        
        if let server = OfficialChatServers?.first {
            IMChatServerInUse = server
        }
    }
    
    func setupViews(){
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubviews(self.avatarImageView,self.nickNameLab,self.accountHintLabel,self.pwdText,self.okBtn,self.changeBtn,self.overlayView,self.tableView)
        self.tableView.isHidden = true
        

        self.avatarImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 80, height: 80))
            m.centerX.equalToSuperview()
            m.top.equalTo(self.view.safeAreaTop).offset(88)
        }
        
        self.nickNameLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(self.avatarImageView.snp.bottom).offset(16)
            m.height.equalTo(30)
        }
        
        self.accountHintLabel.snp.makeConstraints { (m) in
            m.left.right.equalTo(self.nickNameLab)
            m.top.equalTo(self.nickNameLab.snp.bottom).offset(6)
            m.height.equalTo(18)
        }
        
        self.tableView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.accountHintLabel.snp.bottom).offset(8)
            m.height.equalTo(240)
        }
        
        self.overlayView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.pwdText.snp.makeConstraints { (m) in
            m.top.equalTo(self.accountHintLabel.snp.bottom).offset(50)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(50)
        }
        
        self.okBtn.snp.makeConstraints { (m) in
            m.top.equalTo(self.pwdText.snp.bottom).offset(44)
            m.left.right.equalTo(self.pwdText)
            m.height.equalTo(44)
        }
        self.changeBtn.snp.makeConstraints { (m) in
            m.top.equalTo(self.okBtn.snp.bottom).offset(5)
            m.right.equalTo(self.okBtn)
            m.height.equalTo(20)
            m.width.equalTo(100)
        }
    }
    
    @objc private func showChoiceAccount(){
        reloadAccounts()
        view.endEditing(true)
        self.tableView.isHidden = false
        self.overlayView.isHidden = false
    }
    
    @objc private func dismissAccountList() {
        self.tableView.isHidden = true
        self.overlayView.isHidden = true
    }
    
    @objc private func changeBtnTouch() {
        let vc = ChooseAccountVC(nibName: "ChooseAccountVC", bundle: nil)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // 创建账户
     func createAccount() {
        // 配置了服务器时，聊天仍依赖服务器地址；未配置（空服务器）时直接进入创建流程
        if hasConfiguredServerAddress {
            guard let _ = IMChatServerInUse, let _ = BlockchainServerInUse else {
                self.showToast(L("获取服务器中，请稍后再试"))
                self.getOfficialServerRequest(type: 1)
                return
            }
        }
        let vc = CreateSeedPreVC.init()
        self.navigationController?.pushViewController(vc)
    }
    
    // 导入账户
     func importAccount() {
        // 配置了服务器时，聊天仍依赖服务器地址；未配置（空服务器）时直接进入导入流程
        if hasConfiguredServerAddress {
            guard let _ = IMChatServerInUse, let _ = BlockchainServerInUse else {
                self.showToast(L("获取服务器中，请稍后再试"))
                self.getOfficialServerRequest(type: 2)
                return
            }
        }
        let vc = ImportSeedVC.init()
        self.navigationController?.pushViewController(vc)
    }
    
    func phoneLogin() {
        guard let _ = IMChatServerInUse, let _ = BlockchainServerInUse else {
            self.showToast(L("获取服务器中，请稍后再试"))
            self.getOfficialServerRequest(type: 3)
            return
        }
        let vc = LoginViewController.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func phoneLoginTap(){
        
    }
    

    @objc private func okBtnTouch() {
        
        guard let account = selectedAccount else {
            self.showToast(L("未选择账号"))
            return
        }
        
        guard let text = self.pwdText.text, !text.isEmpty else {
            self.showToast(L("请输入密聊密码"))
            return
        }
        
        guard !account.encryptedPassword.isEmpty else {
            self.showToast(L("账号数据不完整"))
            return
        }
        
        if GoFunction.checkPassword(text, hash: account.encryptedPassword) {
            // 解密/加密失败时不能强解包：否则密码正确但数据异常会直接闪退
            guard let seed = GoFunction.deckey(account.encryptedRemembercode, password: text),
                  let keys = SeedManager.keyBy(seed: seed),
                  !keys.priKey.isEmpty,
                  !keys.pubKey.isEmpty,
                  !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty,
                  let encrypasswd = GoFunction.passwordhash(text),
                  let encryMnemonic = GoFunction.enckey(seed, password: text) else {
                self.showToast(L("助记词解析错误, 请更换助记词"))
                return
            }
            let address = EncryptManager.publicKeyToAddress(publicKey: keys.pubKey)
            if !account.phone.isEmpty {
                LoginUser.shared().bindSeedPhone = account.phone
            }
            // 注：`login(seed:...)` 内部已统一记录「上次登录地址」(LoginUser.lastLoginAddressKey)，
            //     退出登录后回到本页面时会优先选中本次登录的账号，此处无需重复写入。
            LoginUser.shared().login(seed: seed, encSeed: encryMnemonic, priKey: keys.priKey, pubKey: keys.pubKey, address: address, encPasswd: encrypasswd)
            
            APP.shared().reloadView()
            let precoin = PreCoin.init()
            precoin.add(intoW: seed, passwd: text)
        }else{
            self.showToast(L("密码错误"))
        }
        
    }
    
}

extension UserLoginVC:UITableViewDelegate,UITableViewDataSource  {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accountList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserLoginAccountCell", for: indexPath) as! UserLoginAccountCell
        let account = accountList[indexPath.row]
        let isSelected = account.address == selectedAccount?.address
        cell.configure(with: account, isSelected: isSelected)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = .clear
        let label = UILabel()
        label.text = L("选择账号")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = Color_8A97A5
        header.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-4)
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let account = accountList[indexPath.row]
        selectAccount(account)
        self.tableView.reloadData()
        dismissAccountList()
    }
}
