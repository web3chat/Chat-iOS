//
//  SetChatPwdVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/29.
//

import UIKit

class SetChatPwdVC: UIViewController, ViewControllerProtocol {
    
    @IBOutlet private weak var pwdBgView: UIView!
    @IBOutlet private weak var pwdAgainBgView: UIView!
    @IBOutlet private weak var pwdTextField: UITextField!
    @IBOutlet private weak var pwdAgainTextField: UITextField!
    @IBOutlet private weak var okBtn: UIButton!
    
    private let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "设置密聊密码"
        
        self.setupViews()
        self.bindData()
    }
    
    private func setupViews() {
        
        
        self.pwdTextField.attributedPlaceholder = NSAttributedString.init(string: "请输入密码", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        self.pwdAgainTextField.attributedPlaceholder = NSAttributedString.init(string: "请再次输入密码", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: Color_8A97A5])
        
    }
    
    private func bindData() {
        let pwdTextFieldOkBtn = self.pwdTextField.addToolBar(with: "确定", target: self, sel: #selector(okBtnTouch(_:)))
        let pwdAgainTextFieldOkBtn = self.pwdAgainTextField.addToolBar(with: "确定", target: self, sel: #selector(okBtnTouch(_:)))

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
            self.showToast("两次密码不一致")
            return
        }
        
        let seed = LoginUser.shared().seed
        guard let encryptedSeed = SeedManager.encrypt(seed: seed, pwd: pwd) else {
            self.showToast("密码不满足条件, 请重新设置密码")
            return
        }
        self.view.showActivity()
        Provider.request(BackupAPI.editMnemonic(mnemonic: encryptedSeed)) { (_) in
            self.view.hideActivity()
            LoginUser.shared().encryptedSeed = encryptedSeed
            LoginUser.shared().save()
            self.showToast("密码设置成功")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.navigationController?.popViewController()
            }
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.view.show(error)
        }
    }
    

}
