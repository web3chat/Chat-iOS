//
//  MineVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/4.
//

import UIKit
import SnapKit
import Kingfisher
import SwifterSwift

class MineVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private var dataSource:[[(logo: String, leftText: String, rightText: String, selector: Selector)]] = []
    
    private lazy var avatarImageView: UIImageView = {
        let v = UIImageView.init()
        v.image = #imageLiteral(resourceName: "avatar_persion")
        v.layer.masksToBounds = true
        v.layer.cornerRadius = 5
        v.isUserInteractionEnabled = true
        
        let headImgTap = UITapGestureRecognizer()
        headImgTap.rx.event.subscribe {[weak self] (_) in
            let vc = FZMEditHeadImageVC(with: .me)
            vc.hidesBottomBarWhenPushed = true
            self?.navigationController?.pushViewController(vc)
        }.disposed(by: bag)
        v.addGestureRecognizer(headImgTap)
        
        return v
    }()
    
    private lazy var qrImageView = UIImageView.init()
    
    private lazy var qrBgView: UIView = {
        let v = UIView.init()
        v.backgroundColor = .white
        v.layer.masksToBounds = true
        v.layer.cornerRadius = 5
        v.isUserInteractionEnabled = true
        
        let tap = UITapGestureRecognizer()
        tap.rx.event.subscribe {[weak self] (_) in
            self?.goQRCodeVC()
        }.disposed(by: bag)
        v.addGestureRecognizer(tap)
        
        v.addSubview(self.qrImageView)
        self.qrImageView.snp.makeConstraints { m in
            m.size.equalTo(CGSize.init(width: 70, height: 70))
            m.centerX.equalToSuperview()
            m.centerY.equalToSuperview()
        }
        
        return v
    }()
    
    private lazy var nicknameLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: "有一只鱼有一只")
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        lab.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let self = self else { return }
            let vc = EditNicknameVC.init()
            vc.editType = .nickname
            vc.placeholder = LoginUser.shared().nickName?.value
            vc.hidesBottomBarWhenPushed = true
            vc.compeletionBlcok = {[weak self] (nickName) in
                self?.editNickName(nickName)
            }
            self.navigationController?.pushViewController(vc)
        }).disposed(by: self.bag)
        return lab
    }()
    
    private func editNickName(_ nickName: String) {
//        guard nickName.count > 0, nickName != LoginUser.shared().nickName?.value else { return }
        guard nickName != LoginUser.shared().nickName?.value else { return }
        self.view.endEditing(true)
        self.view.showActivity()
        User.updateUserNickname(targetAddress: LoginUser.shared().address, nickname: nickName) { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            LoginUser.shared().nickName?.value = nickName
            LoginUser.shared().save()
            
            let nickname = nickName.isBlank == true ? "请设置昵称" : nickName
            strongSelf.nicknameLab.attributedText = nickname.jointImage(image: #imageLiteral(resourceName: "me_edit"))
            
            strongSelf.showToast("昵称修改成功，请耐心等待，稍后查看结果...")
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    private lazy var uidLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: LoginUser.shared().address)
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        lab.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { (ges) in
            guard ges.state == .ended else { return }
            guard !LoginUser.shared().address.isEmpty else { return }
            UIPasteboard.general.string = LoginUser.shared().address
            self.showToast("地址已复制")
        }).disposed(by: self.bag)
        return lab
    }()
    
    private lazy var headerView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 200))
        v.backgroundColor = Color_F6F7F8
        
        v.addSubview(self.avatarImageView)
        self.avatarImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 120, height: 120))
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(12)
        }
        
        v.addSubview(self.qrBgView)
        self.qrBgView.snp.makeConstraints { m in
            m.size.equalTo(CGSize.init(width: 80, height: 80))
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(30)
        }
        
        v.addSubview(self.nicknameLab)
        self.nicknameLab.snp.makeConstraints { (m) in
            m.top.equalTo(self.avatarImageView.snp.bottom).offset(7)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        v.addSubview(self.uidLab)
        self.uidLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(self.nicknameLab.snp.bottom).offset(5)
        }
        
        return v
    }()
    
    lazy var footerView : UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 55))
        let logoutBtn = UIButton(type: .custom)
        logoutBtn.backgroundColor = Color_FFFFFF
        logoutBtn.layer.cornerRadius = 20
        logoutBtn.setAttributedTitle(NSAttributedString(string: "退出账号", attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.systemFont(ofSize: 16)]), for: .normal)
        
        view.addSubview(logoutBtn)
        logoutBtn.snp.makeConstraints({ (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth-30, height: 40))
        })
        logoutBtn.rx.controlEvent(.touchUpInside).subscribe({[weak self] (_) in
            let alertController = UIAlertController.init(title: "提示", message: "确定退出登录", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            let okAction = UIAlertAction.init(title: "确定", style: .destructive, handler: { (_) in
                // 登出
                LoginUser.shared().logout()
                
                APP.shared().reloadView()
            })
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            self?.present(alertController, animated: true, completion: nil)
        }).disposed(by: bag)
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let v = UITableView.init(frame: .zero, style: .plain)
        v.register(nibWithCellClass: AccoutCell.self)
        v.backgroundColor = Color_F6F7F8
        v.contentInsetAdjustmentBehavior = .never
        v.separatorStyle = .none
        v.delegate = self
        v.dataSource = self
        v.keyboardDismissMode = .onDrag
//        v.rowHeight = 75
        v.showsVerticalScrollIndicator = false
        v.tableHeaderView = self.headerView
        v.tableFooterView = footerView
        return v
    }()
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = Color_F6F7F8
        
        let rightView = CustomBarView.init()
        navView.addSubview(rightView)
        rightView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview()
            make.size.equalTo(CGSize.init(width: 108, height: 44))
        }
        
        return navView
    }()
    
    //MARK: -
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavBackgroundColor()
        
        self.setData()
        
        // 获取我的信息
        self.refreshMyInfoRequest()
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor = Color_F6F7F8
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initView()
    }
    
    // 获取我的信息
    private func refreshMyInfoRequest() {
        LoginUser.shared().refreshUserInfo(successBlock: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.setData()
        }, failureBlock: nil)
    }
    
    private func initView() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_isNavigationBarHidden = true
//        self.xls_navigationBarTintColor = Color_F6F7F8// 设置导航栏元素颜色
        self.tableView.backgroundColor = Color_F6F7F8
        
        self.view.addSubviews(self.navBarView)
        self.navBarView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(k_StatusNavigationBarHeight)
        }
        
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.top.equalTo(navBarView.snp.bottom)
            m.bottom.left.right.equalToSuperview()
        }
        
        if APP.shared().showUpdateViewFlg {
            self.dataSource = [
                [("mine_logo_server","服务器", "", #selector(goServer)),
                 ("mine_logo_share","分享邀请", "APP下载",#selector(goQRCodeVC)),
                 ("mine_logo_security","安全管理", "",#selector(goSecurity)),
                 ("mine_logo_setting","设置中心", "", #selector(goSetting)),
                 ("mine_logo_customer","用户反馈", "", #selector(goCustomerVC)),
                 ("mine_logo_updating","检测更新", "V\(k_APPVersion)", #selector(goUpdating))]]
        } else {
            self.dataSource = [
                [("mine_logo_server","服务器", "", #selector(goServer)),
                 ("mine_logo_share","分享邀请", "APP下载",#selector(goQRCodeVC)),
                 ("mine_logo_security","安全管理", "",#selector(goSecurity)),
                 ("mine_logo_setting","设置中心", "", #selector(goSetting)),
                 ("mine_logo_customer","用户反馈", "", #selector(goCustomerVC)),]]
        }
    }
    
    private func setData() {
        let user = LoginUser.shared()
        
        let name = user.nickName?.value ?? ""
        let nickname = name.isBlank == true ? "请设置昵称" : name
        self.nicknameLab.attributedText = nickname.jointImage(image: #imageLiteral(resourceName: "me_edit"))
        
        let address = user.address
        self.uidLab.attributedText = address.jointImage(image: #imageLiteral(resourceName: "icon_copy"))
        
        let height = Int(self.uidLab.frame.maxY) + 20 > 200 ? Int(self.uidLab.frame.maxY) + 20 : 200
        self.headerView.frame = CGRect.init(x: 0, y: 0, width: Int(k_ScreenWidth), height: height)
        
        self.tableView.reloadData()
        
        self.avatarImageView.kf.setImage(with: URL.init(string: user.avatarUrl), placeholder: #imageLiteral(resourceName: "avatar_persion"))
        
        let qrCode = ShareURL + user.address
        self.qrImageView.image = QRCodeGenerator.setupQRCodeImage(qrCode, image: #imageLiteral(resourceName: "logo_60"))
    }
}

extension MineVC {
    /// 服务器
    @objc func goServer() {
        FZMUIMediator.shared().pushVC(.goServer)
    }
    
    /// 安全管理
    @objc private func goSecurity() {
        let vc = SecurityVC.init()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc)
    }
    
    /// 设置中心
    @objc private func goSetting() {
        let vc = SettingVC.init()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc)
    }
    
    /// 检测更新
    @objc private func goUpdating() {
        self.updateApp()
    }
    
    // 请求版本检测接口
    func updateApp() {
        self.showProgress()
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !currentVersion.isEmpty else { return }
        let versionCode = Int(currentVersion.replacingOccurrences(of: ".", with: ""))!
        Provider.request(SystemAPI.update(versionCode: versionCode), successBlock: { [weak self] (json) in
            guard let self = self else { return }
            self.hideProgress()
            let version: VersionCheck? = VersionCheck.init(json: json)
            guard version != nil else { return }
            APP.shared().version = version
            APP.shared().showUpdateViewFlg = version!.versionCode < versionCode
            if APP.shared().showUpdateViewFlg {
                FZM_UserDefaults.set(APP.shared().showUpdateViewFlg, forKey: CHAT33PRO_SHOW_UPDATE_KEY)
            }
            
            guard version!.versionCode > versionCode else {
                self.showToast("当前已是最新版本")
                return
            }
            
            let updateView = UpdateAppView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight), versionCheck: version!)
            
            UIApplication.shared.keyWindow?.addSubview(updateView)
            
        }) { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            FZMLog("检测是否有更新 error : \(error)")
            strongSelf.showToast(error.localizedDescription)
        }
    }
    
    /// 我的二维码/分享邀请
    @objc private func goQRCodeVC() {
        FZMUIMediator.shared().pushVC(.goQRCodeShow(type: .me))
    }
    
    @objc private func goCustomerVC(){
        FZMUIMediator.shared().pushVC(.goQRCodeShow(type: .customer))
    }
}

extension MineVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 10
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return section == 0 ? nil : UIView.init()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: AccoutCell.self)
        guard dataSource.count > indexPath.section else {
            return cell
        }
        let sectionData = dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else {
            return cell
        }
        let model = sectionData[indexPath.row]
        cell.set(logo: model.logo,leftText: model.leftText, rightText: model.rightText)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard dataSource.count > indexPath.section else {
            return
        }
        let sectionData = dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else {
            return
        }
        let model = sectionData[indexPath.row]
        self.perform(model.selector)
    }
}
