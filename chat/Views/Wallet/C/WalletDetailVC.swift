//
//  WalletDetailVC.swift
//  chat
//
//  Created by fzm on 2022/1/21.
//

import Foundation

class WalletDetailVC : UIViewController,ViewControllerProtocol{
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = UIColor.init(hexString: "#EBAE44")
        
        
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: "ABC")
        navView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 100, height: 44))
        }
        
        
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "nav_back"), for: .normal)
        btn.addTarget(self, action: #selector(clickBackAction), for: .touchUpInside)
        btn.contentHorizontalAlignment = .left
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        navView.addSubview(btn)
        btn.snp.makeConstraints { make in
            make.size.equalTo(44)
            make.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(10)
        }
        
        
        let rightView = CustomBarView.init()
        rightView.setHiddenViews(index: 1)
        rightView.setHiddenViews(index: 2)
        navView.addSubview(rightView)
        rightView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview()
            make.size.equalTo(CGSize.init(width: 108, height: 44))
        }
        
        return navView
    }()
    
    
    private lazy var headerView : UIView = {
        let view = WalletDetailHeadView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 215))
        view.skBlock = { [weak self] in
            self?.goSKVC()
        }
        return view
    }()
    
    
    private lazy var tableView: UITableView = {
        let v = UITableView.init(frame: .zero, style: .plain)
        v.register(WalletDetailCell.self, forCellReuseIdentifier: "WalletDetailCell")
        v.backgroundColor = Color_F6F7F8
        v.contentInsetAdjustmentBehavior = .never
        v.separatorStyle = .none
        v.delegate = self
        v.dataSource = self
        v.keyboardDismissMode = .onDrag
        v.showsVerticalScrollIndicator = false
        v.tableHeaderView = self.headerView
        return v
    }()
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavBackgroundColor()
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
        self.title = "我的票券";
        self.initView()
    }
    
    
    private func initView(){
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_isNavigationBarHidden = true
        self.view.addSubviews(self.navBarView)
        self.view.addSubview(self.tableView)
        self.navBarView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(k_StatusNavigationBarHeight)
        }
        tableView.snp.makeConstraints { (m) in
            m.top.equalTo(navBarView.snp.bottom)
            m.bottom.left.right.equalToSuperview()
        }
    }
    
    @objc func clickBackAction(){
        self.navigationController?.popViewController(animated: true)
    }
    
    ///跳转收款页面
    func goSKVC(){
        let vc = WalletCollectionQRCodeVC.init()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc)
    }
    
    
}

extension WalletDetailVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 95
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = WalletDeatilSectionView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 95))
        return view
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: WalletDetailCell.self)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}


