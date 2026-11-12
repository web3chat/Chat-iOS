//
//  SecurityVC.swift
//  chat
//
//  Created by fzm on 2021/1/27.
//

import UIKit

@objc class SecurityVC: UIViewController, ViewControllerProtocol {
    
    @IBOutlet private weak var exportSeedBgView: UIView!
    /// 导出第二段密钥分片（整段：按钮+说明）；无绑定手机号时高度为 0 并隐藏
    @IBOutlet private weak var exportShardSectionView: UIView!
    @IBOutlet private weak var exportShardSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var phoneEmailBgView: UIView!
    
//    @IBOutlet private weak var phoneLab: UILabel!
//    @IBOutlet private weak var emialLab: UILabel!
    @IBOutlet private weak var chatPasswordLab: UILabel!
    @IBOutlet private weak var exportSeedBtn: UIButton!
    @IBOutlet private weak var exportSeedHintLabel: UILabel!
    @IBOutlet private weak var exportShardBtn: UIButton!
    @IBOutlet private weak var exportShardHintLabel: UILabel!
    @IBOutlet private weak var chatPasswordTitleBtn: UIButton!
    
    // 账号绑定
    @IBOutlet private weak var bindPhoneValueLab: UILabel!
    @IBOutlet private weak var bindWechatValueLab: UILabel!
    @IBOutlet private weak var bindXiaohongshuValueLab: UILabel!
    @IBOutlet private weak var bindDouyinValueLab: UILabel!
    @IBOutlet private weak var bindPhoneBtn: UIButton!
    @IBOutlet private weak var bindWechatBtn: UIButton!
    @IBOutlet private weak var bindXiaohongshuBtn: UIButton!
    @IBOutlet private weak var bindDouyinBtn: UIButton!
    
    private var bindPhone: String?
    private var bindEmail: String?
    
    private var decryptSeedPwd: String = ""
    private var languageObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L("安全管理")
        applyLocalizedStrings()
        languageObserver = NotificationCenter.default.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyLocalizedStrings()
        }
        
        self.setBgColor()
        self.queryServerBindStatus()
    }
    
    deinit {
        if let o = languageObserver { NotificationCenter.default.removeObserver(o) }
    }
    
    private func applyLocalizedStrings() {
        exportSeedBtn.setTitle(L("导出助记词"), for: .normal)
        exportSeedHintLabel.text = L("助记词用于加密聊天消息以及聊天文件，更换设备登录时需导入同一助记词才可查看历史加密消息，请及时导出助记词保存至安全的地方！")
        exportShardBtn.setTitle(L("导出第二段密钥分片"), for: .normal)
        exportShardHintLabel.text = L("第二段密钥分片保存在本机，与服务器保存的第一段配合可恢复助记词；换机前请导出并妥善保管，请勿截图。")
        chatPasswordTitleBtn.setTitle(L("密聊密码"), for: .normal)
        chatPasswordLab.text = L("修改密码")
        // 绑定入口按钮标题
        bindPhoneBtn.setTitle(L("绑定手机号"), for: .normal)
        bindWechatBtn.setTitle(L("绑定微信号"), for: .normal)
        bindXiaohongshuBtn.setTitle(L("绑定小红书号"), for: .normal)
        bindDouyinBtn.setTitle(L("绑定抖音号"), for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupViews()
        // 每次进入页面时查询服务端最新绑定状态
        self.queryServerBindStatus()
    }
    
    private func setBgColor() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8
    }
    
    private func setupViews() {
        
        let loginUser = LoginUser.shared()
//        self.phoneLab.text = loginUser.bindSeedPhone.isEmpty ? "去绑定" : loginUser.bindSeedPhone
//        self.emialLab.text = loginUser.bindSeedEmail.isEmpty ? "去绑定" : loginUser.bindSeedEmail
        self.chatPasswordLab.text = L("修改密码") //loginUser.encryptedSeed.isEmpty ? "设置密码" : "修改密码"
        
        let phone = loginUser.bindSeedPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBindPhone = !phone.isEmpty
        exportShardSectionView.isHidden = !hasBindPhone
        exportShardSectionHeightConstraint.constant = hasBindPhone ? 130 : 0
        
        // 刷新账号绑定状态
        refreshBindAccountRows()
    }
    
    @IBAction func exportShardBtnTouch(_ sender: UIButton) {
        // 已开启面容/指纹时直接验证通过，否则弹密聊密码输入框
        ChatPasswordGate.requestVerifiedPassword(title: L("请输入密聊密码"), cancelled: nil) { [weak self] password in
            guard let strongSelf = self else { return }
            strongSelf.decryptSeedPwd = password
            strongSelf.showExportedShard()
        }
    }
    
    /// 校验密聊密码后，从钥匙串按绑定手机号读取 s2 并展示（与导出助记词流程一致）
    private func showExportedShard() {
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        guard GoFunction.checkPassword(self.decryptSeedPwd, hash: wallet?.wallet_password) else {
            self.showToast(L("密码错误"))
            return
        }
        let phone = LoginUser.shared().bindSeedPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else {
            self.showToast(L("未绑定手机号，无法导出密钥分片"))
            return
        }
        guard let s2 = SeedManager.mnemonicShardS2(forPhone: phone), !s2.isEmpty else {
            self.showToast(L("未找到密钥分片"))
            return
        }
        showExportShard(s2: s2)
    }
    
    @IBAction func exportBtnTouch(_ sender: UIButton) {
//        guard !LoginUser.shared().encryptedSeed.isEmpty else {
//            self.showSetChatPassword(completion: showDecryptedSeed)
//            return
//        }
        
        // 已开启面容/指纹时直接验证通过，否则弹密聊密码输入框
        ChatPasswordGate.requestVerifiedPassword(title: L("请输入密聊密码"), cancelled: nil) { [weak self] password in
            guard let strongSelf = self else { return }
            strongSelf.decryptSeedPwd = password
            strongSelf.showDecryptedSeed()
        }
    }
    
    // 显示助记词
    private func showDecryptedSeed() {
       
        
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        
        if GoFunction.checkPassword(self.decryptSeedPwd, hash: wallet?.wallet_password) {
            let decryptedSeed = GoFunction.deckey(wallet?.wallet_remembercode, password: self.decryptSeedPwd)
            self.showExport(seed: decryptedSeed!)
        }else{
            self.showToast(L("密码错误"))
            return
        }
        
//        let encSeed = LoginUser.shared().encryptedSeed
//        guard !encSeed.isBlank else {
//            self.showToast(L("助记词为空"))
//            return
//        }
//        guard let decryptedSeed = SeedManager.decrypt(encSeed: encSeed, pwd: self.decryptSeedPwd) else {
//            self.showToast(L("密码错误"))
//            return
//        }
        
    }
    
    
    @objc func getSeed(_ pwd:String) -> String{
        self.decryptSeedPwd = pwd
        let logiuser = LoginUser.shared()
        guard !logiuser.encryptedSeed.isEmpty else {
            self.showToast(L("未设置密聊密码"))
            return L("未设置密聊密码")
        }
        
        let encSeed = LoginUser.shared().encryptedSeed
        
        guard !encSeed.isBlank else {
            self.showToast(L("助记词为空"))
            return L("助记词为空")
        }
        guard let decryptedSeed = SeedManager.decrypt(encSeed: encSeed, pwd: self.decryptSeedPwd) else {
            self.showToast(L("密码错误"))
            return L("密码错误")
        }
        let devidedSeedBef = decryptedSeed.isIncludeChinese ? decryptedSeed.replacingOccurrences(of: " ", with: "").enumerated().compactMap { $0.offset % 1 == 0 ? " " + String($0.element) : String($0.element)
        }.joined() : decryptedSeed
        let devidedSeed = devidedSeedBef.trimmingCharacters(in: CharacterSet.whitespaces)
        return devidedSeed
    }
    
    
    private func goBindSeedVC(kind: BindSeedVC.Kind) {
        let vc = BindSeedVC.init(kind: kind)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc)
    }
    
//    @IBAction func phoneBtnTouch(_ sender: UIButton) {
//        guard !LoginUser.shared().encryptedSeed.isEmpty else {
//            self.showSetChatPassword { [weak self] in
//                // 密码密码设置成功
//                guard let strongSelf = self else { return }
//                strongSelf.setupViews()
//                strongSelf.goBindSeedVC(kind: .phone)
//            }
//            return
//        }
//        guard LoginUser.shared().bindSeedPhone.isEmpty else {
//            return
//        }
//        goBindSeedVC(kind: .phone)
//    }
//    
//
//    @IBAction func emialBtnTouch(_ sender: UIButton) {
//        guard !LoginUser.shared().encryptedSeed.isEmpty else {
//            showSetChatPassword { [weak self] in
//                // 密码密码设置成功
//                guard let strongSelf = self else { return }
//                strongSelf.setupViews()
//                strongSelf.goBindSeedVC(kind: .emial)
//            }
//            return
//        }
//        guard LoginUser.shared().bindSeedEmail.isEmpty else {
//            return
//        }
//        goBindSeedVC(kind: .emial)
//    }
    
    @IBAction func chatPasswordBtnTouch(_ sender: UIButton) {
//        if LoginUser.shared().encryptedSeed.isEmpty {
//            self.goSetChatPwdVC()
//        } else {
            // 已开启面容/指纹时直接验证通过，否则弹密聊密码输入框
            ChatPasswordGate.requestVerifiedPassword(title: L("请输入密聊密码"), cancelled: nil) { [weak self] (password) in
                
                let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
                
                if GoFunction.checkPassword(password, hash: wallet?.wallet_password) {
                    let vc = SetChatPwdVC.init()
                    vc.oldPwd = password
                    self?.navigationController?.pushViewController(vc)
                }else{
                    self?.showToast(L("密码错误"))
                    return
                }
            }
//        }
    }
    
    private func goSetChatPwdVC() {
        let vc = SetChatPwdVC.init()
        self.navigationController?.pushViewController(vc)
    }
    
}


extension SecurityVC {
    
    // 设置密聊密码
    func showSetChatPassword(completion: (()->())?) {
        let alert = InputAlertView.init()
        alert.title = L("请设置密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: L("8-16位数字、字母或符号组合"), attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        
        alert.confirmBlock = { [weak self] (password) in
            guard password.isValidPassword else {
                self?.showToast(L("密码不满足条件, 请重新设置密码"))
                return
            }
            let seed = LoginUser.shared().seed
            guard let encryptedSeed = SeedManager.encrypt(seed: seed, pwd: password) else {
                self?.showToast(L("密码不满足条件, 请重新设置密码"))
                return
            }
            LoginUser.shared().encryptedSeed = encryptedSeed
            LoginUser.shared().save()
            self?.showToast(L("密码设置成功"))
            self?.decryptSeedPwd = password
            completion?()
        }
        alert.show()
    }
    
    /// 风险提示文案：**保证与后面的助记词/分片之间空一行**。
    ///
    /// ⚠️ 提示语 key 本身带结尾的 `\n\n`，但**译文不一定保留它**（机翻经常丢/挪），
    /// 一丢就会变成「……获取你的信息！word1 word2 …」挤在同一行（用户反馈：中文正常，其它语言不换行）。
    /// 所以这里在代码层先把结尾换行去掉、再统一补一个空行，不依赖译文。
    private func warningText(_ key: String) -> String {
        var text = L(key)
        while text.hasSuffix("\n") { text.removeLast() }
        return text + "\n\n"
    }

    func showExport(seed: String) {
        let devidedSeedBef = seed.isIncludeChinese ? seed.replacingOccurrences(of: " ", with: "").enumerated().compactMap { $0.offset % 3 == 0 ? " " + String($0.element) : String($0.element)
        }.joined() : seed
        let devidedSeed = devidedSeedBef.trimmingCharacters(in: CharacterSet.whitespaces)
        let alert = InfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: L("导出助记词"), attributes: [.font : UIFont.boldSystemFont(ofSize: 20), .foregroundColor : Color_24374E])
        alert.confirmBtnTitle = L("复制")
        let att1 = NSMutableAttributedString.init(string: warningText("请务必抄下助记词并存放至安全的地方，若助记词丢失，重装或换设备登录时将无法查看历史加密消息！并无法重置密聊密码！若助记词被他人获取，将可能获取你的信息！\n\n"), attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_DD5F5F])
        let att2 = NSAttributedString.init(string: devidedSeed, attributes: [.font : UIFont.boldSystemFont(ofSize: 16), .foregroundColor : Color_24374E])
        att1.append(att2)
        alert.attributedInfo = att1
        alert.confirmBlock = { [weak self] in
            SecurityVC.copySecretToPasteboard(devidedSeed)
            self?.showToast(L("助记词已复制"))
        }
        alert.show()
    }
    
    /// 把助记词 / 分片写进系统剪贴板：**60 秒后自动失效**。
    ///
    /// 剪贴板是全局共享的（别的 App 也能读，App 退出后依然在），明文不能长期留着，
    /// 所以用 `setItems(options: .expirationDate:)` 而不是直接赋值 `UIPasteboard.general.string`。
    static func copySecretToPasteboard(_ text: String) {
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: text]],
                                      options: [.expirationDate: Date().addingTimeInterval(60)])
    }
    
    /// 展示 s2，UI 与 `showExport(seed:)` 一致（标题与风险提示文案针对分片）
    private func showExportShard(s2: String) {
        let alert = InfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: L("导出第二段密钥分片"), attributes: [.font : UIFont.boldSystemFont(ofSize: 20), .foregroundColor : Color_24374E])
        alert.confirmBtnTitle = L("复制")
        let att1 = NSMutableAttributedString.init(string: warningText("请务必抄下密钥分片并存放至安全的地方，若密钥分片丢失，换设备时将无法与第一段配合恢复助记词！若密钥分片被他人获取，将可能危及账号安全！\n\n"), attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_DD5F5F])
        let att2 = NSAttributedString.init(string: s2, attributes: [.font : UIFont.boldSystemFont(ofSize: 16), .foregroundColor : Color_24374E])
        att1.append(att2)
        alert.attributedInfo = att1
        alert.confirmBlock = { [weak self] in
            SecurityVC.copySecretToPasteboard(s2)
            self?.showToast(L("密钥分片已复制"))
        }
        alert.show()
    }
}

// MARK: - 账号绑定
extension SecurityVC {
    
    /// 服务端返回的绑定信息
    private struct ServerBindInfo {
        var phone: String = ""
        var wechat: String = ""
        var xiaohongshu: String = ""
        var douyin: String = ""
    }
    private var serverBindInfo: ServerBindInfo {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.serverBindInfo) as? ServerBindInfo ?? ServerBindInfo() }
        set { objc_setAssociatedObject(self, &AssociatedKeys.serverBindInfo, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private struct AssociatedKeys {
        static var serverBindInfo: UInt8 = 0
    }
    
    /// 调用 queryAccounts 接口查询服务端绑定状态
    private func queryServerBindStatus() {
        let address = LoginUser.shared().address
        guard !address.isEmpty else { return }
        
        let api = S1BackUpAPI.queryAccounts(chataddress: address)
        Provider.request(api, successBlock: { [weak self] json in
            guard let self = self else { return }
            
            var info = ServerBindInfo()
            info.phone = json["phone"].stringValue
            info.wechat = json["wechat_id"].stringValue
            info.xiaohongshu = json["xiaohongshu_id"].stringValue
            info.douyin = json["douyin_id"].stringValue
            self.serverBindInfo = info
            
            if !info.phone.isEmpty { LoginUser.shared().bindPhone = info.phone }
            if !info.wechat.isEmpty { LoginUser.shared().bindWechat = info.wechat }
            if !info.xiaohongshu.isEmpty { LoginUser.shared().bindXiaohongshu = info.xiaohongshu }
            if !info.douyin.isEmpty { LoginUser.shared().bindDouyin = info.douyin }
            LoginUser.shared().save()
            
            DispatchQueue.main.async {
                self.refreshBindAccountRows()
            }
        }, failureBlock: { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshBindAccountRows()
            }
        })
    }
    
    private func refreshBindAccountRows() {
        let user = LoginUser.shared()
        
        let seedPhone = user.bindPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        bindPhoneValueLab?.text = !seedPhone.isEmpty ? L("已绑定") : L("去绑定")
        
        let localWechat = user.bindWechat.trimmingCharacters(in: .whitespacesAndNewlines)
        bindWechatValueLab?.text = !localWechat.isEmpty ? L("已绑定") : L("去绑定")

        let localXhs = user.bindXiaohongshu.trimmingCharacters(in: .whitespacesAndNewlines)
        bindXiaohongshuValueLab?.text = !localXhs.isEmpty ? L("已绑定") : L("去绑定")

        let localDouyin = user.bindDouyin.trimmingCharacters(in: .whitespacesAndNewlines)
        bindDouyinValueLab?.text = !localDouyin.isEmpty ? L("已绑定") : L("去绑定")
    }
    
    @IBAction private func bindPhoneTapped(_ sender: UIButton) {
        let user = LoginUser.shared()
        let server = serverBindInfo
        let serverPhone = server.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let seedPhone = user.bindPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundPhone = !serverPhone.isEmpty ? serverPhone :  seedPhone
        if !boundPhone.isEmpty {
            showBoundAccount(account: boundPhone, title: L("绑定手机号"))
        } else {
            showInputBindAlert(title: L("绑定手机号")) { [weak self] value in
                self?.callBindAccountAPI(phone: value, wechat: "", xiaohongshu: "", douyin: "")
            }
        }
    }
    
    @IBAction private func bindWechatTapped(_ sender: UIButton) {
        let user = LoginUser.shared()
        let server = serverBindInfo
        let wechat = !server.wechat.isEmpty ? server.wechat : user.bindWechat
        let boundWechat = wechat.trimmingCharacters(in: .whitespacesAndNewlines)
        if !boundWechat.isEmpty {
            showBoundAccount(account: boundWechat, title: L("绑定微信号"))
        } else {
            showInputBindAlert(title: L("绑定微信号")) { [weak self] value in
                self?.callBindAccountAPI(phone: "", wechat: value, xiaohongshu: "", douyin: "")
            }
        }
    }
    
    @IBAction private func bindXiaohongshuTapped(_ sender: UIButton) {
        let user = LoginUser.shared()
        let server = serverBindInfo
        let xhs = !server.xiaohongshu.isEmpty ? server.xiaohongshu : user.bindXiaohongshu
        let boundXhs = xhs.trimmingCharacters(in: .whitespacesAndNewlines)
        if !boundXhs.isEmpty {
            showBoundAccount(account: boundXhs, title: L("绑定小红书号"))
        } else {
            showInputBindAlert(title: L("绑定小红书号")) { [weak self] value in
                self?.callBindAccountAPI(phone: "", wechat: "", xiaohongshu: value, douyin: "")
            }
        }
    }
    
    @IBAction private func bindDouyinTapped(_ sender: UIButton) {
        let user = LoginUser.shared()
        let server = serverBindInfo
        let douyin = !server.douyin.isEmpty ? server.douyin : user.bindDouyin
        let boundDouyin = douyin.trimmingCharacters(in: .whitespacesAndNewlines)
        if !boundDouyin.isEmpty {
            showBoundAccount(account: boundDouyin, title: L("绑定抖音号"))
        } else {
            showInputBindAlert(title: L("绑定抖音号")) { [weak self] value in
                self?.callBindAccountAPI(phone: "", wechat: "", xiaohongshu: "", douyin: value)
            }
        }
    }
    
    /// 调用 bindAccount 接口
    private func callBindAccountAPI(phone: String, wechat: String, xiaohongshu: String, douyin: String) {
        let address = LoginUser.shared().address
        guard !address.isEmpty else {
            showToast(L("获取聊天地址失败"))
            return
        }
        
        showProgress(with: nil)
        let api = S1BackUpAPI.bindAccount(phone: phone, wechat_id: wechat, xiaohongshu_id: xiaohongshu, douyin_id: douyin, chataddress: address)
        Provider.request(api, successBlock: { [weak self] json in
            guard let self = self else { return }
            self.hideProgress()
            
            let user = LoginUser.shared()
            if !phone.isEmpty { user.bindPhone = phone }
            if !wechat.isEmpty { user.bindWechat = wechat }
            if !xiaohongshu.isEmpty { user.bindXiaohongshu = xiaohongshu }
            if !douyin.isEmpty { user.bindDouyin = douyin }
            user.save()
            
            self.queryServerBindStatus()
            
            DispatchQueue.main.async {
                self.showToast(L("绑定成功"))
            }
        }, failureBlock: { [weak self] error in
            self?.hideProgress()
            DispatchQueue.main.async {
                self?.showToast(error.localizedDescription)
            }
        })
    }
    
    private func showBoundAccount(account: String, title: String) {
        let alert = UIAlertController(title: title, message: account, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("复制"), style: .default) { _ in
            UIPasteboard.general.string = account
            APP.shared().showToast(L("已复制"))
        })
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel))
        present(alert, animated: true)
    }
    
    private func showInputBindAlert(title: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = L("请输入")
        }
        alert.addAction(UIAlertAction(title: L("确定"), style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            completion(text)
        })
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel))
        present(alert, animated: true)
    }
}
