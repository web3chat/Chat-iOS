//
//  FriendsVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/26.
//

import UIKit
import SnapKit
import RxSwift
import SwiftyJSON
import SwifterSwift

class FriendListVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private var friendsDataSource = [(title: String, value: [ContactViewModel])]()
    
    private var groupsDataSource: [(serverUrl: String, value: [(title: String, value: [ContactViewModel])])] = [] {
        didSet {
            self.reloadGroupCollcetView()
        }
    }
    
    private var curGroupServerUrl: String = ""
    
    private var isShowFriendList = true// 私聊/群聊
    
    private var isInSelect = false// 是否为点击顶部按钮切换视图
    
    
    // ***** 团队视图相关 *****
    // 团队头像
    private lazy var teamImageView: UIImageView = {
        let imageView = UIImageView.init(image: #imageLiteral(resourceName: "icon_team"))
        return imageView
    }()
    // 团队名
    private lazy var teamNameLab: UILabel = {
        let lab = UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
        return lab
    }()
    // 团队号
    private lazy var teamIDLab: UILabel = {
        let lab = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        return lab
    }()
    // 团队管理按钮
    private lazy var managerBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("管理", for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .boldFont(14)
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: { [weak self] in
            guard let strongSelf = self else { return }
            // 点击了团队管理视图
            FZMUIMediator.shared().pushVC(.goTeamH5WebVC(type: .managerTeam, completeBlock: { [weak self] in
                guard let strongSelf = self else { return }
                // 解散/退出团队
                LoginUser.shared().quitTeam()
                // 重置视图位置
                strongSelf.resetViewsFrame()
            }))
        }).disposed(by: bag)
        btn.isHidden = true
        return btn
    }()
    //团队视图
    private lazy var teamView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 120))
        view.backgroundColor = .white
        view.layer.cornerRadius = 5
        view.isHidden = true
        
        view.addSubview(teamImageView)
        teamImageView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(10)
            m.size.equalTo(50)
        }
        
        view.addSubview(teamNameLab)
        teamNameLab.snp.makeConstraints { (m) in
            m.left.equalTo(teamImageView.snp.right).offset(10)
            m.top.equalToSuperview().offset(13)
            m.right.equalToSuperview().offset(-60)
        }
        
        view.addSubview(teamIDLab)
        teamIDLab.snp.makeConstraints { (m) in
            m.top.equalTo(teamNameLab.snp.bottom).offset(8)
            m.left.equalTo(teamImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-60)
        }
        
        view.addSubview(managerBtn)
        managerBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 60, height: 44))
            m.top.equalToSuperview().offset(3)
            m.right.equalToSuperview()
        }
        
        let conV = UIView.init()
        view.addSubview(conV)
        conV.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(50)
        }
        
        let image = #imageLiteral(resourceName: "icon_team_small").withRenderingMode(.alwaysTemplate)
        let smallTeamImageView = UIImageView.init(image: image)
        smallTeamImageView.tintColor = Color_Theme
        conV.addSubview(smallTeamImageView)
        smallTeamImageView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(39)
            m.centerY.equalToSuperview()
            m.size.equalTo(26)
        }
        
        let lab = UILabel.getLab(font: .regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "组织架构")
        conV.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalTo(smallTeamImageView.snp.right).offset(10)
            m.centerY.equalToSuperview()
        }
        
        let moreImageView = UIImageView.init(image: #imageLiteral(resourceName: "cell_right_dot"))
        conV.addSubview(moreImageView)
        moreImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        conV.isUserInteractionEnabled = true
        let teamTap = UITapGestureRecognizer()
        teamTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            // 跳转到组织架构H5页面
            FZMUIMediator.shared().pushVC(.goTeamH5WebVC(type: .teamMemberList, completeBlock: { [weak self] in
                guard let strongSelf = self else { return }
                // 退出团队
                LoginUser.shared().quitTeam()
                // 重置视图位置
                strongSelf.resetViewsFrame()
            }))
        }.disposed(by: bag)
        conV.addGestureRecognizer(teamTap)
        
        return view
    }()
    
    
    // ****
    
    lazy var friendHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "好友", showType: .contact)
        view.show(true)
        
        let friendTap = UITapGestureRecognizer()
        friendTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.showListViewAction(0)
        }.disposed(by: bag)
        view.addGestureRecognizer(friendTap)
        return view
    }()
    
    lazy var groupHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "群聊", showType: .contact)
        
        let groupTap = UITapGestureRecognizer()
        groupTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.showListViewAction(1)
        }.disposed(by: bag)
        view.addGestureRecognizer(groupTap)
        return view
    }()
    
    private lazy var blackListBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("黑名单", for: .normal)
        btn.setTitleColor(Color_8A97A5, for: .normal)
        btn.contentHorizontalAlignment = .right
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: { [weak self] in
            guard let strongSelf = self else { return }
            let vc = BlackListVC.init()
            vc.hidesBottomBarWhenPushed = true
            strongSelf.navigationController?.pushViewController(vc)
        }).disposed(by: bag)
        return btn
    }()
    
    // 列表顶部的好友、群聊、黑名单视图
    private lazy var topView: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_FFFFFF
        
        v.addSubview(friendHeader)
        friendHeader.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize.init(width: 55, height: 50))
            m.centerY.equalToSuperview()
        })
        v.addSubview(groupHeader)
        groupHeader.snp.makeConstraints({ (m) in
            m.left.equalTo(friendHeader.snp.right)
            m.size.equalTo(CGSize.init(width: 55, height: 50))
            m.centerY.equalToSuperview()
        })
        
        v.addSubview(blackListBtn)
        blackListBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize.init(width: 55, height: 50))
            m.centerY.equalToSuperview()
        }
        return v
    }()
    
    // 列表顶部视图
    private lazy var headerView: UIView = {
        let v = UIView()
        v.backgroundColor = Color_F6F7F8
        v.addSubview(self.topView)
        self.topView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        return v
    }()
    
    private lazy var friendListView: FZMFriendContactListView = {
        let view = FZMFriendContactListView(with: "好友", .no)
        view.selectBlock = { [weak self] (contact) in
            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: contact.sessionIDStr, source: .normal))
        }
        return view
    }()
    
    private lazy var groupListView: FZMGroupContactListView = {
        let view = FZMGroupContactListView(with: "群聊", showSelect: false)
        view.selectGroupBlock = { [weak self] (contact) in
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(contact.sessionIDStr), locationMsg: nil, backToRootVC: true, selectedRootVCIndex: 1))
        }
        return view
    }()
    
    // 服务器视图
    lazy var groupCollectionView : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        // 设置 Item 的排列方式
        layout.scrollDirection = .horizontal
        // 设置 Item 的四周边距
        layout.sectionInset = UIEdgeInsets.init(top: 0, left: 15, bottom: 0, right: 15)
        // 设置同一竖中上下相邻的两个 Item 之间的间距
        layout.minimumLineSpacing = 10
        // 设置同一行中相邻的两个 Item 之间的间距
        layout.minimumInteritemSpacing = 10
        // 设置 Item 的 Size
        layout.itemSize = CGSize(width: 130, height: 80)
        
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor.clear
        view.showsHorizontalScrollIndicator = false
        view.register(GroupInfoCell.self, forCellWithReuseIdentifier: "GroupInfoCell")
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    private lazy var baseScrollView: UIScrollView = {
        let view = UIScrollView.init(frame: CGRect.init(x: 0, y: 50, width: k_ScreenWidth, height: k_ScreenHeight - k_StatusNavigationBarHeight - 50 - k_TabBarHeight))
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.isPagingEnabled = true
        view.isDirectionalLockEnabled = true
        view.delegate = self
        view.backgroundColor = .white
        view.contentSize = CGSize.init(width: 2*k_ScreenWidth, height: k_ScreenHeight - k_StatusNavigationBarHeight - 50 - k_TabBarHeight)
        return view
    }()
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = Color_F6F7F8
        
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .left, text: "通讯录")
        navView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 100, height: 44))
        }
        
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
        
        // 刷新视图
        resetViewsFrame()
        
        // 刷新我的员工信息和企业信息
        LoginUser.shared().refreshMyStaffInfoAndTeamInfo()
        
        // 获取本地好友和群数据
        self.loadDBFriendsAndGroups()
    }
    
    // 获取本地好友和群数据
    private func loadDBFriendsAndGroups() {
        
        self.divideFriends(contactsArr: UserManager.shared().loadDBFriends())
        
        self.divideGroups(contactsArr: GroupManager.shared().loadDBGroups())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupviews()
        
        self.bindData()
        
        // 在/解散/退出团队通知
        FZM_NotificationCenter.addObserver(self, selector: #selector(isInOrDisbandOrQuitTeamAction), name: FZM_Notify_InTeamStatusChanged, object: nil)
    }
    
    // 加入/退出/解散团队需刷新UI
    @objc private func isInOrDisbandOrQuitTeamAction(_ notification: Notification) {
//        let isInTeam = notification.object as? Bool
        // 刷新视图
        resetViewsFrame()
    }
    
    private func setupviews() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_isNavigationBarHidden = true
        
        self.view.addSubviews(self.navBarView)
        self.navBarView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(k_StatusNavigationBarHeight)
        }
        
        self.view.addSubview(self.teamView)
        teamView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(navBarView.snp.bottom)
            make.height.equalTo(120)
        }
        
        self.view.addSubview(self.headerView)
        headerView.snp.makeConstraints { (m) in
            m.top.equalTo(navBarView.snp.bottom)
            m.left.right.equalToSuperview()
            m.height.equalTo(50)
        }
        
        DispatchQueue.main.async {
            self.topView.roundCorners([.topLeft, .topRight], radius: 25)
        }
        
        self.view.addSubview(self.baseScrollView)
        
        let viewHeight = k_ScreenHeight - k_StatusNavigationBarHeight - 50 - k_TabBarHeight
        
        baseScrollView.frame = CGRect.init(x: 0, y: 50 + k_StatusNavigationBarHeight, width: k_ScreenWidth, height: viewHeight)
        
        baseScrollView.addSubview(friendListView)
        friendListView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: viewHeight)
        friendListView.tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: {[weak self] in
            guard let strongSelf = self else { return }
            UserManager.shared().getNetFriends { (json) in
                strongSelf.friendListView.tableView.mj_header?.endRefreshing()
            } failureBlock: { (error) in
                strongSelf.friendListView.tableView.mj_header?.endRefreshing()
            }
        })
        
        baseScrollView.addSubview(groupCollectionView)
        groupCollectionView.frame = CGRect.init(x: k_ScreenWidth, y: 0, width: k_ScreenWidth, height: 80)
        
        baseScrollView.addSubview(groupListView)
        groupListView.frame = CGRect.init(x: k_ScreenWidth, y: groupCollectionView.height, width: k_ScreenWidth, height: viewHeight - groupCollectionView.height)
        groupListView.tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: {[weak self] in
            guard let strongSelf = self else { return }
            let serverUrls = LoginUser.shared().chatServerGroups.compactMap({ $0.value }).withoutDuplicates()
            serverUrls.forEach { (chatServerUrl) in
                GroupManager.shared().getNetGroups(serverUrl: chatServerUrl) { (json) in
                    strongSelf.groupListView.tableView.mj_header?.endRefreshing()
                } failureBlock: { (error) in
                    strongSelf.groupListView.tableView.mj_header?.endRefreshing()
                }
            }
        })
        
        baseScrollView.contentSize = CGSize.init(width: 2*k_ScreenWidth, height: viewHeight)
        baseScrollView.setContentOffset(CGPoint.init(x: isShowFriendList ? 0 : k_ScreenWidth, y: 0), animated: true)
    }
    
    // 重置视图位置
    private func resetViewsFrame() {
        var topHeight: CGFloat = 50 + k_StatusNavigationBarHeight
        if let _ = LoginUser.shared().myStaffInfo {
            teamView.isHidden = false
            
            headerView.snp.updateConstraints { make in
                make.top.equalTo(navBarView.snp.bottom).offset(135)
            }
            topHeight += 135
        } else {
            teamView.isHidden = true
            
            headerView.snp.updateConstraints { make in
                make.top.equalTo(navBarView.snp.bottom)
            }
        }
        
        let viewHeight = k_ScreenHeight - topHeight - k_TabBarHeight
        
        baseScrollView.frame = CGRect.init(x: baseScrollView.frame.origin.x, y: topHeight, width: baseScrollView.frame.size.width, height: viewHeight)
        
        friendListView.frame = CGRect.init(x: friendListView.frame.origin.x, y: friendListView.frame.origin.y, width: friendListView.frame.size.width, height: viewHeight)
        
        groupListView.frame = CGRect.init(x: groupListView.frame.origin.x, y: groupListView.frame.origin.y, width: groupListView.frame.size.width, height: viewHeight - 80)
        
        baseScrollView.contentSize = CGSize.init(width: 2*k_ScreenWidth, height: viewHeight)
        baseScrollView.setContentOffset(CGPoint.init(x: isShowFriendList ? 0 : k_ScreenWidth, y: 0), animated: true)
    }
    
    private func bindData() {
        // 好友数据
        UserManager.shared().friendsSubject.subscribe(onNext: {[weak self] (friends) in
            guard let strongSelf = self else { return }
            strongSelf.divideFriends(contactsArr: friends)
        }).disposed(by: bag)
        
        // 群聊数据
        GroupManager.shared().groupsSubject.subscribe(onNext: {[weak self] (groups) in
            guard let strongSelf = self else { return }
            strongSelf.divideGroups(contactsArr: groups)
        }).disposed(by: bag)
        
        // 自己聊天服务器地址变化订阅
        LoginUser.shared().chatServerGroupsSubject.subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            // 获取当前发送消息的聊天服务器地址
            strongSelf.reloadGroupCollcetView()
        }).disposed(by: self.bag)
        
        // 订阅聊天服务器连接状态
        MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
            guard let strongSelf = self else { return }
            guard case .next((let url, _)) = event else { return }
            
            for i in 0..<strongSelf.groupsDataSource.count {
                let serverUrl = strongSelf.groupsDataSource[i].serverUrl
                if url == MultipleSocketManager.shared().transformUrl(serverUrl) {
                    DispatchQueue.main.async {
                        strongSelf.groupCollectionView.reloadItems(at: [IndexPath.init(row: i, section: 0)])
                    }
                }
            }
        }.disposed(by: self.bag)
        
        // 我的员工信息订阅
        LoginUser.shared().staffInfoSubject.subscribe(onNext: {[weak self] (staffInfo) in
            guard let strongSelf = self else { return }
            if let info = staffInfo {
                strongSelf.teamNameLab.text = info.entName// 企业名
                strongSelf.teamIDLab.text = "团队号 \(info.entId)"
                
                // role 0：团队负责人；1：超级管理员；2:客户管理员；3：普通人员
                strongSelf.managerBtn.isHidden = info.role == 3
            }
            // 重置视图位置
            strongSelf.resetViewsFrame()
            
        }).disposed(by: self.bag)
        
        // 我的企业信息订阅
        LoginUser.shared().companyInfoSubject.subscribe(onNext: {[weak self] (companyInfo) in
            guard let strongSelf = self, let info = companyInfo else { return }
            
            strongSelf.teamImageView.kf.setImage(with: URL.init(string: info.avatar), placeholder: #imageLiteral(resourceName: "icon_team"))
            
        }).disposed(by: self.bag)
    }
    
    private func reloadGroupCollcetView() {
        
        var dataSource = [(title: String, value: [ContactViewModel])]()
        
        guard self.groupsDataSource.count > 0 else {
            DispatchQueue.main.async {
                self.groupCollectionView.reloadData()
                self.groupListView.dataSource = dataSource
            }
            return
        }
        
        if !curGroupServerUrl.isBlank {
            for i in 0..<self.groupsDataSource.count {
                if self.groupsDataSource[i].serverUrl == curGroupServerUrl {
                    dataSource = self.groupsDataSource[i].value
                }
            }
        } else {
            curGroupServerUrl = self.groupsDataSource.first!.serverUrl
            
            dataSource = self.groupsDataSource.first!.value
        }
        
        DispatchQueue.main.async {
            self.groupListView.dataSource = dataSource
            
            self.groupCollectionView.reloadData()
        }
    }
    
    private func divideFriends(contactsArr: [User]) {
        DispatchQueue.global().async {
            let divideContacts = UserManager.shared().divideUser(contactsArr)
            
            DispatchQueue.main.async {
                self.friendsDataSource = divideContacts
                self.friendListView.originDataSource = self.friendsDataSource
            }
        }
    }
    
    private func divideGroups(contactsArr: [Group]) {
        DispatchQueue.global().async {
            let divideContacts = UserManager.shared().divideGroup(contactsArr)
            self.groupsDataSource = divideContacts
        }
    }
    
    func showListViewAction(_ index: Int, isScroll: Bool = false) {
        self.friendHeader.show(index == 0 ? true : false)
        self.groupHeader.show(index == 0 ? false : true)
        isShowFriendList = index == 0
        if !isScroll {
            self.isInSelect = true
            self.baseScrollView.setContentOffset(CGPoint(x: index*Int(k_ScreenWidth), y: 0), animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                self.isInSelect = false
            })
        }
    }
}

extension FriendListVC: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.dealWithScroll()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.dealWithScroll()
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.dealWithScroll()
    }
    
    private func dealWithScroll() {
        if !isInSelect {
            let index = Int((self.baseScrollView.contentOffset.x + self.baseScrollView.frame.width/2) / self.baseScrollView.frame.width)
            self.showListViewAction(index, isScroll: true)
        }
    }
}

extension FriendListVC: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return groupsDataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: GroupInfoCell.self, for: indexPath)
        cell.arrowView.isHidden = true
        guard indexPath.row < groupsDataSource.count else {
            return cell
        }
        let model = groupsDataSource[indexPath.row]
        var isSelect = false
        if model.serverUrl == curGroupServerUrl {
            isSelect = true
        }
        cell.configure(with: model.serverUrl, isSelected: isSelect)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard self.groupsDataSource.count > indexPath.row else {
            return
        }
        
        let model = self.groupsDataSource[indexPath.row]
        curGroupServerUrl = model.serverUrl
        self.reloadGroupCollcetView()
    }
}
