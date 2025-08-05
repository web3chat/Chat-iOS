//
//  SecurityVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/27.
//

import UIKit

@objc class SecurityVC: UIViewController, ViewControllerProtocol {
    
    @IBOutlet private weak var exportSeedBgView: UIView!
    @IBOutlet private weak var phoneEmailBgView: UIView!
    
    @IBOutlet private weak var phoneLab: UILabel!
    @IBOutlet private weak var emialLab: UILabel!
    @IBOutlet private weak var chatPasswordLab: UILabel!
    
    private var bindPhone: String?
    private var bindEmail: String?
    
    private var decryptSeedPwd: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "安全管理"
        
        self.setBgColor()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupViews()
    }
    
    private func setBgColor() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8
    }
    
    private func setupViews() {
        
        let loginUser = LoginUser.shared()
        self.phoneLab.text = loginUser.bindSeedPhone.isEmpty ? "去绑定" : loginUser.bindSeedPhone
        self.emialLab.text = loginUser.bindSeedEmail.isEmpty ? "去绑定" : loginUser.bindSeedEmail
        self.chatPasswordLab.text = loginUser.encryptedSeed.isEmpty ? "设置密码" : "修改密码"
    }
    
    @IBAction func exportBtnTouch(_ sender: UIButton) {
        guard !LoginUser.shared().encryptedSeed.isEmpty else {
            self.showSetChatPassword(completion: showDecryptedSeed)
            return
        }
        
        let alert = InputAlertView.init()
        alert.title = "请输入密聊密码"
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: "请输入密码", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        
        alert.confirmBlock = { [weak self] (password) in
            guard let strongSelf = self else { return }
            strongSelf.decryptSeedPwd = password
            strongSelf.showDecryptedSeed()
        }
        alert.show()
    }
    
    // 显示助记词
    private func showDecryptedSeed() {
       
        let encSeed = LoginUser.shared().encryptedSeed
        guard !encSeed.isBlank else {
            self.showToast("助记词为空")
            return
        }
        guard let decryptedSeed = SeedManager.decrypt(encSeed: encSeed, pwd: self.decryptSeedPwd) else {
            self.showToast("密码错误")
            return
        }
        self.showExport(seed: decryptedSeed)
    }
    
    
    @objc func getSeed(_ pwd:String) -> String{
        self.decryptSeedPwd = pwd
        let logiuser = LoginUser.shared()
        guard !logiuser.encryptedSeed.isEmpty else {
            self.showToast("未设置密聊密码")
            return "未设置密聊密码"
        }
        
        let encSeed = LoginUser.shared().encryptedSeed
        
        guard !encSeed.isBlank else {
            self.showToast("助记词为空")
            return "助记词为空"
        }
        guard let decryptedSeed = SeedManager.decrypt(encSeed: encSeed, pwd: self.decryptSeedPwd) else {
            self.showToast("密码错误")
            return "密码错误"
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
    
    @IBAction func phoneBtnTouch(_ sender: UIButton) {
        guard !LoginUser.shared().encryptedSeed.isEmpty else {
            self.showSetChatPassword { [weak self] in
                // 密码密码设置成功
                guard let strongSelf = self else { return }
                strongSelf.setupViews()
                strongSelf.goBindSeedVC(kind: .phone)
            }
            return
        }
        guard LoginUser.shared().bindSeedPhone.isEmpty else {
            return
        }
        goBindSeedVC(kind: .phone)
    }
    

    @IBAction func emialBtnTouch(_ sender: UIButton) {
        guard !LoginUser.shared().encryptedSeed.isEmpty else {
            showSetChatPassword { [weak self] in
                // 密码密码设置成功
                guard let strongSelf = self else { return }
                strongSelf.setupViews()
                strongSelf.goBindSeedVC(kind: .emial)
            }
            return
        }
        guard LoginUser.shared().bindSeedEmail.isEmpty else {
            return
        }
        goBindSeedVC(kind: .emial)
    }
    
    @IBAction func chatPasswordBtnTouch(_ sender: UIButton) {
        if LoginUser.shared().encryptedSeed.isEmpty {
            self.goSetChatPwdVC()
        } else {
            let alert = InputAlertView.init()
            alert.title = "请输入密聊密码"
            alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: "请输入密码", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
            alert.isSecureTextEntry = true
            
            alert.confirmBlock = { [weak self] (password) in
                let encSeed = LoginUser.shared().encryptedSeed
//                guard let decryptedSeed = SeedManager.decrypt(encSeed: encSeed, pwd: password) else {
                guard SeedManager.decrypt(encSeed: encSeed, pwd: password) != nil else {
                    self?.showToast("密码错误")
                    return
                }
                self?.goSetChatPwdVC()
            }
            alert.show()
        }
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
        alert.title = "请设置密聊密码"
        alert.textFieldAttributedPlaceholder = NSAttributedString.init(string: "8-16位数字、字母或符号组合", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_8A97A5])
        alert.isSecureTextEntry = true
        
        alert.confirmBlock = { [weak self] (password) in
            guard password.isValidPassword else {
                self?.showToast("密码不满足条件, 请重新设置密码")
                return
            }
            let seed = LoginUser.shared().seed
            guard let encryptedSeed = SeedManager.encrypt(seed: seed, pwd: password) else {
                self?.showToast("密码不满足条件, 请重新设置密码")
                return
            }
            LoginUser.shared().encryptedSeed = encryptedSeed
            LoginUser.shared().save()
            self?.showToast("密码密码设置成功")
            self?.decryptSeedPwd = password
            completion?()
        }
        alert.show()
    }
    
    func showExport(seed: String) {
        let devidedSeedBef = seed.isIncludeChinese ? seed.replacingOccurrences(of: " ", with: "").enumerated().compactMap { $0.offset % 3 == 0 ? " " + String($0.element) : String($0.element)
        }.joined() : seed
        let devidedSeed = devidedSeedBef.trimmingCharacters(in: CharacterSet.whitespaces)
        let alert = InfoAlertView.init()
        alert.attributedTitle = NSAttributedString.init(string: "导出助记词", attributes: [.font : UIFont.boldSystemFont(ofSize: 20), .foregroundColor : Color_24374E])
        alert.confirmBtnTitle = "复制"
        let att1 = NSMutableAttributedString.init(string: "请务必抄下助记词并存放至安全的地方，若助记词丢失，重装或换设备登录时将无法查看历史加密消息！并无法重置密聊密码！若助记词被他人获取，将可能获取你的信息！\n\n", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_DD5F5F])
        let att2 = NSAttributedString.init(string: devidedSeed, attributes: [.font : UIFont.boldSystemFont(ofSize: 16), .foregroundColor : Color_24374E])
        att1.append(att2)
        alert.attributedInfo = att1
        alert.confirmBlock = { [weak self] in
            UIPasteboard.general.string = devidedSeed
            self?.showToast("助记词已复制")
        }
        alert.show()
    }
}
