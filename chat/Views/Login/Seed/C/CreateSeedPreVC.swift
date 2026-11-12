//
//  CreateSeedPreVC.swift
//  chat
//
//  Created by 郑晨 on 2025/7/17.
//
import UIKit
@objc class CreateSeedPreVC: UIViewController, ViewControllerProtocol, UITextFieldDelegate {
    
    private let bag = DisposeBag.init()
    @objc var pwd: String = "1111111111"
    
    var topLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 18), textColor:Color_24374E, textAlignment: .center, text: L("创建钱包"))
        return lab
    }()
    
    private lazy var promptPwdLab: UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: L("设置密聊密码 8-16位数字、字母组合"))
    }()
    
    private lazy var pwdText:CommonTextField = {
        let pwdText = CommonTextField()
        pwdText.textColor = Color_24374E
        pwdText.placeholder = L("请设置密聊密码");
        pwdText.keyboardType = UIKeyboardType.asciiCapable;
        pwdText.isSecureTextEntry = true;
        pwdText.delegate = self;
        pwdText.tag = 100;
        return pwdText
    }()
    
    private lazy var pwdAgainText:CommonTextField = {
        let pwdAgainText = CommonTextField()
        pwdAgainText.textColor = Color_24374E
        pwdAgainText.placeholder = L("请确认密聊密码");
        pwdAgainText.keyboardType = UIKeyboardType.asciiCapable;
        pwdAgainText.isSecureTextEntry = true;
        pwdAgainText.delegate = self;
        return pwdAgainText
    }()
    
    private lazy var tipLab:UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 13), textColor: Color_DD5F5F, textAlignment: .right, text: L("请输入8～16位数字、字母组合"))
    }()
    
    private lazy var pwdtipLab:UILabel = {
        return UILabel.getLab(font: .systemFont(ofSize: 13), textColor: Color_DD5F5F, textAlignment: .right, text: L("两次密码不相同"))
    }()
    
    
    private lazy var importBtn: UIButton = {
        let btn = UIButton.getNormalBtn(with: L("下一步"), backgroundColor: Color_Theme)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.addTarget(self, action: #selector(importBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.xls_isNavigationBarHidden = true
        
        self.setupViews()
        self.observeKeyboard()
    }
    
    // MARK: - 键盘
    //
    // 底部「下一步」跟着键盘上移，保证输入密码时按钮在键盘上方
    // （写法与 `SquareCreatePostVC` 的发送按钮一致）。
    private lazy var keyboardObserver = KeyboardObserver()
    private var keyboardHeight: CGFloat = 0
    
    private func observeKeyboard() {
        let follow: (KeyboardNotification) -> Void = { [weak self] notification in
            guard let self = self else { return }
            let height = notification.endFrame.height
            guard height > 0, abs(height - self.keyboardHeight) > 0.5 else { return }
            self.keyboardHeight = height
            self.updateImportBtnBottom(notification)
        }
        keyboardObserver.callbacks[.willShow] = follow
        keyboardObserver.callbacks[.willChangeFrame] = follow
        keyboardObserver.callbacks[.willHide] = { [weak self] notification in
            guard let self = self, self.keyboardHeight > 0 else { return }
            self.keyboardHeight = 0
            self.updateImportBtnBottom(notification)
        }
    }
    
    /// 按钮离屏幕底部的距离 = 键盘高度 + 20（键盘收起时是安全区 + 20）
    private func updateImportBtnBottom(_ notification: KeyboardNotification? = nil) {
        let base = max(keyboardHeight, self.view.safeAreaInsets.bottom)
        self.importBtn.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(-(base + 20))
        }
        guard let notification = notification else { return }
        UIView.animate(withDuration: notification.timeInterval,
                       delay: 0,
                       options: [notification.animationOptions, .allowAnimatedContent, .beginFromCurrentState],
                       animations: { [weak self] in
                           self?.view.layoutIfNeeded()
                       },
                       completion: nil)
    }
    
    private lazy var backBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage.init(named: "nav_back")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_24374E
        btn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.navigationController?.popViewController(animated: true)
        }).disposed(by: self.bag)
        return btn
    }()
    
    private func setupViews() {
        self.view.backgroundColor = .white
        
        
        self.view.addSubview(self.backBtn)
        self.backBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 11, height: 20))
            m.left.equalToSuperview().offset(16)
            m.top.equalTo(self.view.safeAreaTop).offset(12)
        }
        
        
        self.view.addSubview(self.topLab)
        topLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(backBtn)
            make.right.equalToSuperview().offset(-15)
        }
        
        
        self.view.addSubview(self.pwdText)
        pwdText.snp.makeConstraints { make in
            make.top.equalTo(backBtn.snp.bottom).offset(50)
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(50)
        }
        
        self.view.addSubview(self.promptPwdLab)
        promptPwdLab.isHidden = true
        promptPwdLab.snp.makeConstraints { make in
            make.top.equalTo(backBtn.snp.bottom).offset(40)
            make.height.equalTo(20)
            make.left.equalTo(pwdText)
        }
        self.view.addSubview(self.pwdAgainText)
        pwdAgainText.snp.makeConstraints { make in
            make.top.equalTo(pwdText.snp.bottom).offset(32)
            make.left.right.equalTo(pwdText)
            make.height.equalTo(50)
        }
        self.view.addSubview(self.tipLab)
        tipLab.isHidden = true
        tipLab.snp.makeConstraints { make in
            make.top.equalTo(pwdText.snp.bottom).offset(5)
            make.right.equalTo(pwdText.snp.right)
            make.height.equalTo(13)
        }

        self.view.addSubview(self.pwdtipLab)
        pwdtipLab.isHidden = true
        pwdtipLab.snp.makeConstraints { make in
            make.top.equalTo(pwdAgainText.snp.bottom).offset(5)
            make.right.equalTo(pwdAgainText.snp.right)
            make.height.equalTo(13)
        }
        
        self.view.addSubview(importBtn)
        importBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview().offset(-k_SafeBottomInset - 20)
            make.height.equalTo(44)
        }
    }
    
    @objc private func importBtnTouch() {
        self.view.endEditing(true)
       
        pwd = self.pwdText.text ?? ""
        
        if pwd.isRightPassword() {
            self.tipLab.isHidden = true
            
        }else{
            self.tipLab.isHidden = false
            return
        }
        
        if pwdText.text != pwdAgainText.text {
            self.pwdtipLab.isHidden = false
            return
        }
        
        let vc = CreateSeedVC.init()
        vc.pwd = pwd
        self.navigationController?.pushViewController(vc)
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.tag == 100 {
            promptPwdLab.isHidden = false
        }
        guard let textF = textField as? CommonTextField else { return }
        textF.lineColor = Color_24374E
        textF.setNeedsDisplay()
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == 100 {
            promptPwdLab.isHidden = true
        }
        guard let textF = textField as? CommonTextField else { return }
        textF.lineColor = Color_8A97A5
        textF.setNeedsDisplay()
    }
}
