//
//  ChooseAccountVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/5.
//

import UIKit
import SwifterSwift

class ChooseAccountVC: UIViewController, ViewControllerProtocol {
    
    var isAgree = false
    
    @IBOutlet weak var agreeBtn: UIButton!
    
    @IBOutlet weak var agreementView: UIView!
    
    @IBOutlet weak var chooseBtn: UIButton!
    
    @IBOutlet weak var agreementBtn: UIButton!
    
    @IBOutlet weak var btnImport: UIButton!
    
    @IBOutlet weak var bgImageview: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xls_isNavigationBarHidden = true
        
//        self.agreeBtn.enlargeClickEdge(30, 30, 30, 30)
        self.chooseBtn.setTitleColor(Color_Theme, for: .normal)
//        self.agreementBtn.setTitleColor(Color_Theme, for: .normal)
//        self.agreementBtn.setTitle("《\(APPNAME)用户服务协议》", for: .normal)
        self.btnImport.setBackgroundColor(color: Color_Theme, state: .normal)
        self.btnImport.setBackgroundColor(color: Color_Theme, state: .highlighted)
        self.bgImageview.backgroundColor = Color_Theme
        
        // 从中心化服务器获取默认的聊天服务器地址和区块链节点地址
        getOfficialServerRequest(type: 0)
    }
    
    private var getOfficialServerSuccessFlg = false// 获取服务器地址成功标志
    
    /// 从中心化服务器获取默认的IM服务器地址和区块链节点地址
    /// - Parameter type: 回调成功后执行方法 0: 不执行 1:创建账户 2:导入账户 3:登录
    private func getOfficialServerRequest(type: Int) {
        guard !getOfficialServerSuccessFlg else {
            return
        }
//        self.view.showActivity()
        APP.shared().getOfficialServerRequest { [weak self] (json) in
            guard let strongSelf = self else { return }
//            strongSelf.view.hideActivity()
            
            strongSelf.getOfficialServerSuccessFlg = true
            
            // 设置默认IM服务器和区块链节点服务器
            strongSelf.setupDefaultServer()
         //   1111
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
//        guard let _ = IMChatServerInUse, let _ = BlockchainServerInUse else {
//            self.getOfficialServerRequest(type: 1)
//            return
//        }
        
//        guard isAgree else {
//            self.showErrorToast()
//            return
//        }
        let vc = CreateSeedVC.init()
        self.navigationController?.pushViewController(vc)
    }
    
    // 导入账户
    @IBAction func importAccountBtnTap(_ sender: UIButton) {
//        guard let _ = IMChatServerInUse, let _ = BlockchainServerInUse else {
//            self.getOfficialServerRequest(type: 2)
//            return
//        }
        
//        guard isAgree else {
//            self.showErrorToast()
//            return
//        }
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
        self.showToast("请先阅读并勾选协议再登录")
        self.agreementView.shake()
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
