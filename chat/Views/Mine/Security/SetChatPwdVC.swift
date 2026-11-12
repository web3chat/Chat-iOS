//
//  SetChatPwdVC.swift
//  chat
//
//  Created by fzm on 2021/1/29.
//

import UIKit

class SetChatPwdVC: UIViewController, ViewControllerProtocol {
    
    @IBOutlet private weak var pwdBgView: UIView!
    @IBOutlet private weak var pwdAgainBgView: UIView!
    @IBOutlet private weak var pwdTextField: UITextField!
    @IBOutlet private weak var pwdAgainTextField: UITextField!
    @IBOutlet private weak var okBtn: UIButton!
    @IBOutlet private weak var hintLabel: UILabel!
    
    private let bag = DisposeBag()
    @objc var oldPwd:String = "13"
    private var languageObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L("修改密聊密码")
        
        self.setupViews()
        self.bindData()
        applyLocalizedStrings()
        languageObserver = NotificationCenter.default.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyLocalizedStrings()
        }
    }
    
    deinit {
        if let o = languageObserver { NotificationCenter.default.removeObserver(o) }
    }
    
    private func applyLocalizedStrings() {
        hintLabel.text = L("8-16位数字、字母或符号组合")
        okBtn.setTitle(L("确定"), for: .normal)
    }
    
    private func setupViews() {
        
        
        self.pwdTextField.attributedPlaceholder = NSAttributedString.init(string: L("请输入密码"), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.pwdAgainTextField.attributedPlaceholder = NSAttributedString.init(string: L("请再次输入密码"), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        
    }
    
    private func bindData() {
        let pwdTextFieldOkBtn = self.pwdTextField.addToolBar(with: L("确定"), target: self, sel: #selector(okBtnTouch(_:)))
        let pwdAgainTextFieldOkBtn = self.pwdAgainTextField.addToolBar(with: L("确定"), target: self, sel: #selector(okBtnTouch(_:)))

        let pwdValid = pwdTextField.rx.text.orEmpty.map { !$0.isEmpty }.share(replay: 1)
        let pwdAgainValid = pwdAgainTextField.rx.text.orEmpty.map { !$0.isEmpty }.share(replay: 1)
        
        Observable.combineLatest(pwdValid, pwdAgainValid).map { $0 && $1 }.share(replay: 1).subscribe(onNext: { [weak self] isValid in
            pwdTextFieldOkBtn.isEnabled = isValid
            pwdAgainTextFieldOkBtn.isEnabled = isValid
            self?.okBtn.isEnabled = isValid
            self?.okBtn.backgroundColor = isValid ? Color_Theme : UIColor(hexString: "#C8D3DE")
            pwdTextFieldOkBtn.backgroundColor = isValid ? Color_Theme : UIColor(hexString: "#C8D3DE")
            pwdAgainTextFieldOkBtn.backgroundColor = isValid ? Color_Theme : UIColor(hexString: "#C8D3DE")
        }).disposed(by: bag)
    }

    @IBAction @objc func okBtnTouch(_ sender: UIButton) {
        self.view.endEditing(true)
        guard let pwd = self.pwdTextField.text,
              let pwdAgain = self.pwdAgainTextField.text,
              pwd == pwdAgain else {
            self.showToast(L("两次密码不一致"))
            return
        }
        
        // 已开启面容/指纹：改密前必须先通过人脸/指纹验证
        // 验证未通过 → 提示「修改不成功」，密码不改、绑定不动（保证提示与实际状态一致）
        if BiometricAuthManager.shared.isEnabled {
            BiometricAuthManager.shared.authenticate(reason: L("验证身份以修改密聊密码")) { [weak self] success in
                guard let self = self else { return }
                guard success else {
                    self.showToast(L("修改不成功"))
                    return
                }
                self.commitPasswordChange(pwd)
            }
            return
        }
        
        self.commitPasswordChange(pwd)
    }
    
    /// 真正执行改密（原有逻辑不变）；成功后自动「清旧绑定 + 用新密码重新绑定」
    private func commitPasswordChange(_ pwd: String) {
        guard let wallet = PWDataBaseManager.shared().queryWalletIsSelected() else {
            FZMLog("修改密聊密码失败：没有选中钱包")
            self.showToast(L("参数错误"))
            return
        }
        guard let encrypasswd = GoFunction.passwordhash(pwd) else {
            FZMLog("修改密聊密码失败：passwordhash 返回空")
            self.showToast(L("参数错误"))
            return
        }
        wallet.wallet_password = encrypasswd
        let rememberCode = GoFunction.deckey(wallet.wallet_remembercode, password: oldPwd)
        let newRememberCode = GoFunction.enckey(rememberCode, password: pwd)
        let phone = LoginUser.shared().bindSeedPhone
       
       
        if rememberCode?.count != 0,
           let newRememberCode = newRememberCode,
           !newRememberCode.isEmpty {
            wallet.wallet_remembercode = newRememberCode
            if PWDataBaseManager.shared().update(wallet) {
                wallet.wallet_issetpwd = 1
                if phone.count != 0 {
                    SeedManager.removeChatLoginSecrets(forPhone: phone)
                    SeedManager.saveChatLoginSecrets(forPhone: phone, encPasswordHex: encrypasswd, encMnemonicHex: newRememberCode)
                }
                LoginUser.shared().encryptedPasswd = encrypasswd
                LoginUser.shared().encryptedSeed = newRememberCode
                LoginUser.shared().save()
                _ = PWDataBaseManager.shared().updateUserInfoPassword(withAddress: LoginUser.shared().address, encryptedPassword: encrypasswd)
                // 人脸/指纹已在上一步验过：这里直接清掉旧绑定 + 用新密码重新绑定，
                // 用户无需再去设置里重新开启
                let rebound = self.rebindBiometric(withNewPassword: pwd)
                if rebound {
                    self.showToast(L("密码设置成功"))
                } else {
                    self.showToast(L("面容/指纹验证已失效，请重新开启并输入密聊密码"))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.navigationController?.popViewController()
                }
            }
                
        }
       
        
//        let seed = LoginUser.shared().seed
//        guard let encryptedSeed = SeedManager.encrypt(seed: seed, pwd: pwd) else {
//            self.showToast("密码不满足条件, 请重新设置密码")
//            return
//        }
//        self.view.showActivity()
//        Provider.request(BackupAPI.editMnemonic(mnemonic: encryptedSeed)) { (_) in
//            self.view.hideActivity()
//            LoginUser.shared().encryptedSeed = encryptedSeed
//            LoginUser.shared().save()
//            self.showToast(L("密码设置成功"))
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                self.navigationController?.popViewController()
//            }
//        } failureBlock: { (error) in
//            self.view.hideActivity()
//            self.view.show(error)
//        }
    }
    
    /// 清旧绑定 + 用新密码重新绑定当前账号（未开启面容/指纹时什么都不做）
    /// - Returns: true = 绑定可用（未开启、或已用新密码重新绑定成功）
    private func rebindBiometric(withNewPassword pwd: String) -> Bool {
        guard BiometricAuthManager.shared.isEnabled else { return true }
        BiometricAuthManager.shared.disable()
        return BiometricAuthManager.shared.enable(withPassword: pwd, boundAddress: LoginUser.shared().address)
    }
    
}
