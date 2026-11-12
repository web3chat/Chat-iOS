//
//  ChooseAccountVC.swift
//  chat
//
//  Created by fzm on 2021/1/5.
//

import UIKit
import SwifterSwift

class ChooseAccountVC: UIViewController, ViewControllerProtocol {
    
    /// 从「账号切换」页点击「添加其他账号」进入时为 `true`；新账号写入 `LoginUser` 前若仍有旧会话则先 `logout`（与列表内切换账号一致）。在成功路径或返回切换页时会被清空。
    static var isAddingAccountFromSwitchAccountPage = false
    
    /// 在新账号 `login` 之前调用：仅在「添加其他账号」流程内生效一次；若当前已登录则先退出旧账号。
    static func logoutCurrentSessionIfNeededBeforeNewAccountLogin() {
        guard isAddingAccountFromSwitchAccountPage else { return }
        defer { isAddingAccountFromSwitchAccountPage = false }
        if LoginUser.shared().isLogin {
            LoginUser.shared().logout()
        }
    }
    
    var isAgree = false
    
    @IBOutlet weak var agreeBtn: UIButton?
    @IBOutlet weak var agreementView: UIView?
    @IBOutlet weak var chooseBtn: UIButton!
    @IBOutlet weak var agreementBtn: UIButton?
    @IBOutlet weak var bgImageview: UIImageView!
    @IBOutlet weak var mnemonicAccountTitleLabel: UILabel!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var importAccountButton: UIButton!
    @IBOutlet weak var phoneLoginTitleLabel: UILabel!
    @IBOutlet weak var phoneLoginSubLabel: UILabel!
    @IBOutlet weak var agreePrefixLabel: UILabel!
    @IBOutlet weak var agreementLinkBtn: UIButton!
    
    private var languageObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.chooseBtn.setTitleColor(Color_Theme, for: .normal)
        self.bgImageview.backgroundColor = Color_Theme
        phoneLoginSubLabel.isHidden = true// 隐藏"找回助记词登录"副标题
        applyLocalizedStrings()
        languageObserver = NotificationCenter.default.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyLocalizedStrings()
        }
        
        // 从中心化服务器获取默认的聊天服务器地址和区块链节点地址
        getOfficialServerRequest(type: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 作为根界面时全屏无导航栏；从「账号切换」等 push 进入时需显示导航栏以便返回
        let stacked = (navigationController?.viewControllers.count ?? 0) > 1
        xls_isNavigationBarHidden = !stacked
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 从「添加其他账号」返回切换页（未完成登录）时取消标记，避免误伤后续流程
        if isMovingFromParent {
            ChooseAccountVC.isAddingAccountFromSwitchAccountPage = false
        }
    }
    
    deinit {
        if let o = languageObserver { NotificationCenter.default.removeObserver(o) }
    }
    
    private func applyLocalizedStrings() {
        chooseBtn.setTitle(L("选择服务器"), for: .normal)
        mnemonicAccountTitleLabel.text = L("助记词账户")
        createAccountButton.setTitle(L("创建账户"), for: .normal)
        importAccountButton.setTitle(L("导入账户"), for: .normal)
        phoneLoginTitleLabel.text = L("手机号")
        phoneLoginSubLabel.text = L("找回助记词登录")
        agreePrefixLabel.text = L("我已阅读并同意")
        agreementLinkBtn.setTitle(L("《谈信用户服务协议》"), for: .normal)
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
                strongSelf.createAccountBtnTap(UIButton.init(type: .custom))
            case 2:
                strongSelf.importAccountBtnTap(UIButton.init(type: .custom))
            case 3:
                strongSelf.phoneLoginTap(UITapGestureRecognizer.init())
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
    
    // 选择服务器
    @IBAction func chooseServerBtnTap(_ sender: UIButton) {
        let vc = ChooseServerVC.init()
        self.navigationController?.pushViewController(vc)
    }
    
    // 创建账户
    @IBAction func createAccountBtnTap(_ sender: UIButton) {
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
    @IBAction func importAccountBtnTap(_ sender: UIButton) {
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
    
    // 登录
    @IBAction func phoneLoginTap(_ sender: UITapGestureRecognizer) {
        guard let _ = IMChatServerInUse, let _ = BlockchainServerInUse else {
            self.getOfficialServerRequest(type: 3)
            return
        }
        
//        guard isAgree else {
//            self.showErrorToast()
//            return
//        }
        let vc = LoginViewController.init()
        self.navigationController?.pushViewController(vc)
    }
    
    private func showErrorToast() {
        self.showToast(L("请先阅读并勾选协议再登录"))
        self.agreementView?.shake()
    }
    
    // 协议
    @IBAction func protocolBtnTap(_ sender: UIButton) {
        let vc = WebViewVC.init(with: USER_SERVER_AGREEMENT_URL)
        self.navigationController?.pushViewController(vc)
//        self.present(vc, animated: true, completion: nil)
    }
    
    // 同意按钮
    @IBAction func agreeProtocolBtnTap(_ sender: UIButton) {
        isAgree = !isAgree
        sender.isSelected = isAgree
    }
}
