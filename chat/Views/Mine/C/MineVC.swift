//
//  MineVC.swift
//  chat
//
//  Created by fzm on 2021/1/4.
//

import UIKit
import SnapKit
import Kingfisher
import SwifterSwift

class MineVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private var dataSource:[[(logo: String, leftText: String, rightText: String, selector: Selector)]] = []
    
    private var languageChangeObserver: NSObjectProtocol?
    
    deinit {
        if let observer = languageChangeObserver {
            FZM_NotificationCenter.removeObserver(observer)
        }
    }
    
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
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: L("设置昵称"))
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
            _ = PWDataBaseManager.shared().updateUserInfoName(withAddress: LoginUser.shared().address, name: nickName)
            
            let nickname = nickName.isBlank == true ? L("设置昵称") : nickName
            strongSelf.nicknameLab.attributedText = nickname.jointImage(image: #imageLiteral(resourceName: "me_edit"))
            
            strongSelf.showToast(L("昵称修改成功，请耐心等待，稍后查看结果..."))
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    /// 与切换账号列表副标题一致：优先链上/绑定手机号，否则为地址脱敏
    private func resolvedPhoneForMineHeader() -> String? {
        let user = LoginUser.shared()
        let fromProfile = user.phone?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromProfile.isEmpty { return fromProfile }
        let bind = user.bindSeedPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bind.isEmpty { return bind }
        return nil
    }
    
    private func maskedSubtitleUnderNickname() -> String {
        let addressText = LoginUser.shared().address.trimmingCharacters(in: .whitespacesAndNewlines)
        if let phone = resolvedPhoneForMineHeader() {
            return MineVC.maskedPhoneDisplay(phone)
        }
        return MineVC.maskedAddressDisplay(addressText)
    }
    
    /// 与 `SwitchAccountCell.maskedPhone` 一致
    private static func maskedPhoneDisplay(_ phone: String) -> String {
        let text = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 7 else { return text }
        return "\(text.prefix(3))****\(text.suffix(4))"
    }
    
    /// 与 `SwitchAccountCell.maskedAddress` 一致
    private static func maskedAddressDisplay(_ address: String) -> String {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 16 else { return text }
        return "\(text.prefix(8))****\(text.suffix(8))"
    }
    
    private lazy var uidLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: "")
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        lab.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard ges.state == .ended else { return }
            guard let self = self else { return }
            let user = LoginUser.shared()
            if let phone = self.resolvedPhoneForMineHeader(), !phone.isEmpty {
                UIPasteboard.general.string = phone
                self.showToast(L("手机号已复制"))
                return
            }
            guard !user.address.isEmpty else { return }
            UIPasteboard.general.string = user.address
            self.showToast(L("地址已复制"))
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
    
    private lazy var switchAccountBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Color_FFFFFF
        btn.layer.cornerRadius = 20
        btn.setAttributedTitle(NSAttributedString(string: L("切换账号"), attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.systemFont(ofSize: 16)]), for: .normal)
        return btn
    }()
    
    private lazy var logoutBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Color_FFFFFF
        btn.layer.cornerRadius = 20
        btn.setAttributedTitle(NSAttributedString(string: L("退出账号"), attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.systemFont(ofSize: 16)]), for: .normal)
        return btn
    }()
    
    lazy var footerView : UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 105))
        
        view.addSubview(self.switchAccountBtn)
        view.addSubview(self.logoutBtn)
        switchAccountBtn.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth-30, height: 40))
        })
        logoutBtn.snp.makeConstraints({ (m) in
            m.top.equalTo(switchAccountBtn.snp.bottom).offset(10)
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth-30, height: 40))
        })
        switchAccountBtn.rx.controlEvent(.touchUpInside).subscribe({[weak self] (_) in
            self?.goSwitchAccount()
        }).disposed(by: bag)
        logoutBtn.rx.controlEvent(.touchUpInside).subscribe({[weak self] (_) in
            let alertController = UIAlertController.init(title: L("提示"), message: L("确定退出登录"), preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: L("取消"), style: .cancel, handler: nil)
            let okAction = UIAlertAction.init(title: L("确定"), style: .destructive, handler: { (_) in
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
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backgroundColor = Color_F6F7F8
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initView()
        
        // 语言切换后刷新 cell 与底部按钮文案
        languageChangeObserver = FZM_NotificationCenter.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] (_) in
            guard let self = self else { return }
            self.reloadDataSource()
            self.reloadFooterButtons()
            self.tableView.reloadData()
        }
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
        
        self.reloadDataSource()
    }
    
    // 重建底部按钮文案（语言切换后调用）
    private func reloadFooterButtons() {
        switchAccountBtn.setAttributedTitle(NSAttributedString(string: L("切换账号"), attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.systemFont(ofSize: 16)]), for: .normal)
        logoutBtn.setAttributedTitle(NSAttributedString(string: L("退出账号"), attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.systemFont(ofSize: 16)]), for: .normal)
    }
    
    // 重建 cell 数据源（语言切换后需重新取 L() 文案）
    private func reloadDataSource() {
        if APP.shared().showUpdateViewFlg {
            self.dataSource = [
                [("mine_logo_server", L("服务器"), "", #selector(goServer)),
                 ("mine_logo_share", L("分享邀请"), L("应用下载"),#selector(goShareInvite)),
                 ("mine_logo_security", L("安全管理"), "",#selector(goSecurity)),
                 ("mine_logo_setting", L("设置中心"), "", #selector(goSetting)),
                 ("mine_logo_updating", L("检测更新"), "V\(k_APPVersion)", #selector(goUpdating))]]
        } else {
            self.dataSource = [
                [("mine_logo_server", L("服务器"), "", #selector(goServer)),
                 ("mine_logo_share", L("分享邀请"), L("应用下载"),#selector(goShareInvite)),
                 ("mine_logo_security", L("安全管理"), "",#selector(goSecurity)),
                 ("mine_logo_setting", L("设置中心"), "", #selector(goSetting)),]]
        }
    }
    
    private func setData() {
        let user = LoginUser.shared()
        
        let name = user.nickName?.value ?? ""
        let nickname = name.isBlank == true ? L("设置昵称") : name
        self.nicknameLab.attributedText = nickname.jointImage(image: #imageLiteral(resourceName: "me_edit"))
        
        let subtitle = maskedSubtitleUnderNickname()
        self.uidLab.attributedText = subtitle.jointImage(image: #imageLiteral(resourceName: "icon_copy"))
        
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

    /// 账号切换
    @objc private func goSwitchAccount() {
        let vc = SwitchAccountVC()
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
        // 版本号含非数字时 Int() 返回 nil，强解包会崩；解析失败就收起菊花并跳过版本检测
        guard let versionCode = Int(currentVersion.replacingOccurrences(of: ".", with: "")) else {
            FZMLog("版本号无法解析，跳过更新检测：\(currentVersion)")
            self.hideProgress()
            return
        }
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
                self.showToast(L("当前已是最新版本"))
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
    
    /// 分享邀请（TestFlight 下载链接 / 二维码，不再进入「我的二维码」页面）
    @objc private func goShareInvite() {
        let vc = ShareInviteVC()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc)
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
