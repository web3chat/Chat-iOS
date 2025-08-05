//
//  BlackListVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/3/25.
//

import UIKit
import SnapKit
import SectionIndexView

class BlackListVC: UIViewController,ViewControllerProtocol {
    
    private let disposeBag = DisposeBag.init()
    
    var dataSource = [(title: String, value:[ContactViewModel])]()
    
    lazy var blackListView: FZMFriendContactListView = {
        let view = FZMFriendContactListView(with: "", isBlacklist: true)
        view.selectBlock = { [weak self] (model) in
            guard let _ = self else { return }
            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: model.sessionIDStr, source: nil))
        }
        return view
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNavBackgroundColor()
        
        let shieldUsers = UserManager.shared().getDBShieldUsers()
        
        self.divideShieldUsers(shieldUsers)
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
        
        self.title = "黑名单"
        
        self.setupViews()
        
        // 获取黑名单列表请求
        self.refreshBlackList()
    }
    
    // 获取黑名单列表请求
    private func refreshBlackList() {
        UserManager.shared().getBlackList { [weak self] (shieldUsers) in
            guard let strongSelf = self else { return }
            strongSelf.divideShieldUsers(shieldUsers)
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.showToast("获取黑名单列表失败 \(error.localizedDescription)")
        }
    }
    
    private func setupViews() {
        self.view.addSubview(blackListView)
        blackListView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
    
    // 数据处理
    private func divideShieldUsers(_ users: [User]) {
        DispatchQueue.global().async {
            let divideContacts = UserManager.shared().divideUser(users)
            
            DispatchQueue.main.async {
                self.dataSource = divideContacts
                self.blackListView.originDataSource = self.dataSource
            }
        }
    }
}


