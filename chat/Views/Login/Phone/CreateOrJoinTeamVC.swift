//
//  CreateOrJoinTeamVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/13.
//

import Foundation
import SnapKit
import UIKit

class CreateOrJoinTeamVC: UIViewController, ViewControllerProtocol, UIGestureRecognizerDelegate {
    private let disposeBag = DisposeBag.init()
    
    var isLoginVCEnter = false
    
    private var isClickCreateTeamFlg = false// 点击加入/创建团队flg
    
    private lazy var joinView: UIView = {
        let view = UIView.init()
        view.backgroundColor = .white
        view.addShadow(ofColor: UIColor.init(hexString: "#24374E", transparency: 0.35)!, radius: 5, offset: .zero, opacity: 1)
        
        let label1 = UILabel.init()
        let str = "加入团队"
        let alias = "加入"
        let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.boldFont(16)])
        attStr.addAttributes([NSAttributedString.Key.foregroundColor: UIColor.init(hexString: "#F7B500")!], range:(str as NSString).range(of: alias as String))
        label1.attributedText = attStr
        view.addSubview(label1)
        label1.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(18)
            m.top.equalToSuperview().offset(20)
        }
        
        let label2 = UILabel()
        label2.font = .regularFont(14)
        label2.text = "你的团队已经在使用\(APPNAME)，可通过扫描团队二维码进入团队，与成员一起沟通协作，高效作业。"
        label2.numberOfLines = 0
        view.addSubview(label2)
        label2.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(18)
            m.top.equalTo(label1.snp.bottom).offset(10)
            m.right.equalToSuperview().offset(-67)
        }
        
        let arrowV = UIImageView.init(image: #imageLiteral(resourceName: "arrow_gray_right"))
        arrowV.contentMode = .scaleAspectFill
        view.addSubview(arrowV)
        arrowV.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-20)
            m.top.equalToSuperview().offset(69)
            m.size.equalTo(CGSize.init(width: 11.5, height: 19))
        }
        
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            self?.joinTeam()
        }).disposed(by: self.disposeBag)
        
        return view
    }()
    
    private lazy var createView: UIView = {
        let view = UIView.init()
        view.backgroundColor = .white
        view.addShadow(ofColor: UIColor.init(hexString: "#24374E", transparency: 0.35)!, radius: 5, offset: .zero, opacity: 1)
        
        let label1 = UILabel.init()
        let str = "创建团队"
        let alias = "创建"
        let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.boldFont(16)])
        attStr.addAttributes([NSAttributedString.Key.foregroundColor: UIColor.init(hexString: "#EB8282")!], range:(str as NSString).range(of: alias as String))
        label1.attributedText = attStr
        view.addSubview(label1)
        label1.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(18)
            m.top.equalToSuperview().offset(20)
        }
        
        let label2 = UILabel()
        label2.font = .regularFont(14)
        label2.text = "通过创建团队，你将直接称为团队或企业负责人，可添加成员，让整个团队一起享受高效的沟通协作吧。"
        label2.numberOfLines = 0
        view.addSubview(label2)
        label2.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(18)
            m.top.equalTo(label1.snp.bottom).offset(10)
            m.right.equalToSuperview().offset(-67)
        }
        
        let arrowV = UIImageView.init(image: #imageLiteral(resourceName: "arrow_gray_right"))
        arrowV.contentMode = .scaleAspectFill
        view.addSubview(arrowV)
        arrowV.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-20)
            m.top.equalToSuperview().offset(69)
            m.size.equalTo(CGSize.init(width: 11.5, height: 19))
        }
        
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            self?.createTeam()
        }).disposed(by: self.disposeBag)
        
        return view
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        // 查询是否绑定了团队(获取员工信息)
        checkBindTeamRequest()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupViews()
        
        if !isLoginVCEnter {
            self.checkBindTeamRequest()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func setupViews() {
        
        self.view.backgroundColor = Color_F6F7F8
        self.navigationController?.navigationBar.isHidden = true
        self.navigationController?.navigationBar.isTranslucent = false
        
        let view = UIView.init()
        view.backgroundColor = .white
        self.view.addSubview(view)
        view.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        let labTitle = UILabel.getLab(font: .regularFont(18), textColor: Color_24374E, textAlignment: .center, text: "加入或创建团队")
        view.addSubview(labTitle)
        labTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(k_SafeTopInset)
            make.centerX.equalToSuperview()
            make.height.equalTo(k_NavigationBarHeight)
        }
        
        let btnLogout = UIButton.init(type: .custom)
        btnLogout.titleLabel?.font = .mediumFont(16)
        btnLogout.setTitle("退出账号", for: .normal)
        btnLogout.setTitleColor(Color_Theme, for: .normal)
        btnLogout.addTarget(self, action: #selector(popBack), for: .touchUpInside)
        
        view.addSubview(btnLogout)
        btnLogout.snp.makeConstraints { (m) in
            m.left.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 100, height: 44))
            m.centerY.equalTo(labTitle)
        }
        
        let btnRefresh = UIButton.init(type: .custom)
        btnRefresh.titleLabel?.font = .mediumFont(16)
        btnRefresh.setTitle("刷新", for: .normal)
        btnRefresh.setTitleColor(Color_Theme, for: .normal)
        btnRefresh.addTarget(self, action: #selector(checkBindTeamRequest), for: .touchUpInside)
        
        view.addSubview(btnRefresh)
        btnRefresh.snp.makeConstraints { (m) in
            m.right.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 100, height: 44))
            m.centerY.equalTo(labTitle)
        }
        
        let imgView = UIImageView.init(image: #imageLiteral(resourceName: "icon_joinTeam"))
        imgView.contentMode = .scaleAspectFill
        view.addSubview(imgView)
        imgView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(labTitle.snp.bottom).offset(25)
        }
        
        view.addSubview(joinView)
        joinView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(22)
            m.right.equalToSuperview().offset(-22)
            m.top.equalTo(imgView.snp.bottom).offset(45)
            m.height.equalTo(138)
        }
        
        view.addSubview(createView)
        createView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(22)
            m.right.equalToSuperview().offset(-22)
            m.top.equalTo(joinView.snp.bottom).offset(20)
            m.height.equalTo(138)
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @objc private func popBack() {
        let alertController = UIAlertController.init(title: "提示", message: "确定退出登录", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        let okAction = UIAlertAction.init(title: "确定", style: .destructive, handler: { (_) in
            
            LoginUser.shared().logout()
            
            APP.shared().reloadView()
        })
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    // 加入团队
    @objc private func joinTeam() {
        isClickCreateTeamFlg = false
        // 扫描二维码
        let vc = QRCodeReaderVC.init()
        vc.readBlock = { (qrcodeStr) in
            if qrcodeStr.contains(TeamH5Url) {
                // 跳转到加入团队网页
                self.goH5WebVC(.joinTeam(url: qrcodeStr))
            } else {
                self.showToast("请扫描团队二维码!")
            }
        }
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
    
    // 创建团队
    @objc private func createTeam() {
        isClickCreateTeamFlg = true
        self.goH5WebVC(.createTeam)
    }
    
    // 跳转到H5网页
    private func goH5WebVC(_ type: TeamViewType) {
        
        let vc = TeamH5WebViewVC.init(with: type)
        vc.isCreateOrJoinTeamVCEnter = true
        vc.teamOperationBlock = { [weak self] in
            guard let strongSelf = self else { return }
            if !strongSelf.isClickCreateTeamFlg {
                // 创建团队成功，刷新我的员工和企业信息
                strongSelf.checkBindTeamRequest()
            }
        }
        self.navigationController?.pushViewController(vc)
    }
    
    // 查询是否绑定了团队(获取员工信息)
    @objc private func checkBindTeamRequest() {
        guard LoginUser.shared().isLogin else {
            return
        }
        self.showProgress()
        
        // 合并获取员工信息和企业信息 (获取IM服务器地址、区块链服务器地址、OA服务器地址)
        TeamManager.shared().getStaffInfo(address: LoginUser.shared().address) { [weak self] (staffinfo) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            
            // 重新加载页面
            APP.shared().showToast("团队创建成功")
        } failureBlock: { [weak self] (errorStr) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast(errorStr)
        }
    }
}

