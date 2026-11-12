//
//  CustomBarView.swift
//  chat
//
//  Created by 王俊豪 on 2021/7/2.
//

import UIKit

class CustomBarView: UIView {
    
    private lazy var searchBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 26, height: 44)
        btn.setImage(#imageLiteral(resourceName: "tool_search"), for: .normal)
        btn.addTarget(self, action: #selector(web3Click), for: .touchUpInside)
        btn.enlargeClickEdge(.init(top: 0, left: 10, bottom: 0, right: 10))
        return btn
    }()
    
    private lazy var addBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect.init(x: 41, y: 0, width: 26, height: 44)
        btn.setImage(#imageLiteral(resourceName: "icon_add"), for: .normal)
        btn.addTarget(self, action: #selector(addBtnClick), for: .touchUpInside)
        btn.enlargeClickEdge(.init(top: 0, left: 10, bottom: 0, right: 10))
        return btn
    }()
    
    private lazy var sweepBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect.init(x: 82, y: 0, width: 26, height: 44)
        btn.setImage(#imageLiteral(resourceName: "tool_sweep_icon"), for: .normal)
        btn.addTarget(self, action: #selector(sweepItemClick), for: .touchUpInside)
        btn.enlargeClickEdge(.init(top: 0, left: 10, bottom: 0, right: 10))
        return btn
    }()
    
    
    init() {
        super.init(frame: CGRect.init(x: 0, y: 0, width: 108, height: 44))
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupViews() {
//        self.addSubview(searchBtn)
        self.addSubview(addBtn)
        self.addSubview(sweepBtn)
    }
    
    ///隐藏  搜索1  加号2  扫一扫3
    func setHiddenViews(index : Int){
        if index == 1{
            searchBtn.isHidden = true
        }else if index == 2 {
            addBtn.isHidden = true
        }else if (index == 3){
            sweepBtn.isHidden = true
        }else{
            searchBtn.isHidden = false
            addBtn.isHidden = false
            sweepBtn.isHidden = false
        }
    }
    
    
    /// 跳转到web3浏览器
    @objc private func web3Click(){
        FZMUIMediator.shared().pushVC(.gotoWeb3VC)
    }
    
    
    /// 跳转搜索页 搜联系人 聊天记录
    @objc private func searchBtnClick() {
        FZMUIMediator.shared().pushVC(.goFullTextSearch())
        
        //wjhTEST
//        let message     = "secret message"
//        let key         = "key890123456"
//        let ivString     = "abcdefghijklmnop"   // 16 bytes for AES128
//
//        let messageData = message.data(using:String.Encoding.utf8)!
//        let keyData     = key.data(using: .utf8)!
//        let ivData      = ivString.data(using: .utf8)!
//
//        let encryptedData = messageData.aesEncrypt( keyData:keyData, ivData:ivData, operation:kCCEncrypt)
//        let decryptedData = encryptedData.aesEncrypt( keyData:keyData, ivData:ivData, operation:kCCDecrypt)
//        let decrypted     = String(bytes:decryptedData, encoding:String.Encoding.utf8)!
//        FZMLog("decrypted \(decrypted)")
//
//        guard let keyData = EncryptManager.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: LoginUser.shared().publicKey) else { return }
//
//        let encData = messageData.aesEncrypt(keyData: keyData)
//        let decData = encData.aesDecrypt(keyData: keyData)
//        let decStr = String(bytes: decData, encoding: .utf8)
//        FZMLog("decStr \(decStr ?? "")")
    }
    
    /// +按钮点击
    @objc private func addBtnClick() {
        let menuViewArr = [FZMImageMenuItem(title: L("扫一扫"), image: #imageLiteral(resourceName: "tool_sweep").withRenderingMode(.alwaysTemplate), size: CGSize(width: 26, height: 26), block: {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.sweepItemClick()
        }),FZMImageMenuItem(title: L("搜索聊天记录"), image: #imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysTemplate), size: CGSize(width: 26, height: 26), block: {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.searchBtnClick()
        }),FZMImageMenuItem(title: L("添加朋友/群"), image: #imageLiteral(resourceName: "tool_add_friend"), size: CGSize(width: 26, height: 26), block: {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.addFriendBtnClick()
        }),FZMImageMenuItem(title: L("创建群聊"), image: #imageLiteral(resourceName: "tool_create_group"), size: CGSize(width: 26, height: 26), block: {
            FZMUIMediator.shared().pushVC(.goChooseServerToCreateGroup)
        }),FZMImageMenuItem(title: L("我的码"), image: #imageLiteral(resourceName: "tool_qrcode").withRenderingMode(.alwaysTemplate), size: CGSize(width: 26, height: 26), block: {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.goQRCodeVC()
        })]
        
//        if let _ = LoginUser.shared().myStaffInfo {
//            menuViewArr = menuViewArr + [FZMImageMenuItem(title: "OKR", image: #imageLiteral(resourceName: "tool_okr"), size: CGSize(width: 26, height: 26), block: {[weak self] in
//                guard let strongSelf = self else { return }
//                strongSelf.goToOKR()
//            })]
//        } else {
//            menuViewArr = menuViewArr + [FZMImageMenuItem(title: "创建团队", image: #imageLiteral(resourceName: "tool_creat_team"), size: CGSize(width: 26, height: 26), block: {[weak self] in
//                guard let strongSelf = self else { return }
//                strongSelf.createTeam()
//            })]
//        }
        
        let view = FZMImageMenuView(with: menuViewArr)
        view.show(in: CGPoint(x: k_ScreenWidth-15, y: k_StatusNavigationBarHeight))
    }
    
    /// 扫一扫
    @objc private func sweepItemClick() {
        DispatchQueue.main.async {
            let vc = QRCodeReaderVC.init()
            vc.readBlock = { [weak self] (qrcodeStr) in
                // 分发逻辑抽到 QRCodeResultHandler（大图长按「识别图中二维码」也走同一套）
                if QRCodeResultHandler.handle(qrcodeStr, from: UIViewController.current(), onTeamJoined: { [weak self] in
                    self?.checkBindTeamRequest()
                }) {
                    return
                }
                // 不认识的二维码：把内容原样展示出来
                let alertView = UIAlertController.init(title: L("扫描结果"), message: qrcodeStr, preferredStyle: .alert)
                let alert = UIAlertAction.init(title: L("确定"), style: .destructive) { _ in
                    FZMLog("扫一扫结果弹窗显示点击确定按钮")
                }
                alertView.addAction(alert)
                DispatchQueue.main.async {
                    UIViewController.current()?.present(alertView, animated: true, completion: nil)
                }
            }
            UIViewController.current()?.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
    
    // 跳转到H5网页
    private func goH5WebVC(_ type: TeamViewType) {
        
        FZMUIMediator.shared().pushVC(.goTeamH5WebVC(type: type, completeBlock: { [weak self] in
            guard let strongSelf = self else { return }
            // 创建/加入团队成功，刷新我的员工和企业信息
            strongSelf.checkBindTeamRequest()
        }))
    }
    
    // 查询是否绑定了团队(获取员工信息)
    private func checkBindTeamRequest() {
        guard LoginUser.shared().isLogin else {
            return
        }
        self.showProgress()
        
        // 合并获取员工信息和企业信息 (获取IM服务器地址、区块链服务器地址、OA服务器地址)
        TeamManager.shared().getStaffInfo(address: LoginUser.shared().address) { [weak self] (staffinfo) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            
            // 重新加载页面
            APP.shared().showToast(L("团队创建成功"))
        } failureBlock: { [weak self] (errorStr) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast(errorStr)
        }
    }
    
    /// 跳转搜索用户页 添加朋友/群
    @objc private func addFriendBtnClick() {
        let vc = SearchUserVC.init()
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
    
    /// 我的二维码
    @objc private func goQRCodeVC() {
        FZMUIMediator.shared().pushVC(.goQRCodeShow(type: .me))
    }
    
    /// 创建团队
    @objc private func createTeam() {
        self.goH5WebVC(.createTeam)
    }
    
    /// OKR-H5页面
    @objc private func goToOKR() {
        let vc = OKRH5WebViewVC.init()
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
}
