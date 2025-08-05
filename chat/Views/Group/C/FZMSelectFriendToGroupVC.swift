//
//  FZMSelectFriendToGroupVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/18.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import SwifterSwift
import Kingfisher
import RxCocoa

enum FZMSelectFriendGroupShowStyle {
    case allFriend // 显示所有好友 --- (创建群)
    case allMember(Int) // 显示所有群成员(groupId) ---（删除群成员）
    case exclude(Int)// 排除项(groupId) --- （邀请新群成员）
}

class FZMSelectFriendToGroupVC: UIViewController, ViewControllerProtocol {
    
    private let disposeBag = DisposeBag.init()
    
    private let showType : FZMSelectFriendGroupShowStyle
    
    private var selectArr = [ContactViewModel]()// 选中
    
    private var friendArrayForSearch = [User]()
    private var memberArrayForSearch = [GroupMember]()
    private var memberArrayForSearchNew = [GroupMember]()
    
    private var excludeUsers = [String]()// 已有的群成员memberId（邀请新群成员时排除已有成员）
    var reloadBlock : NormalBlock?
    
    var defaultSelectId = "" {
        didSet {
            self.listView.defaultSelectId = self.defaultSelectId
        }
    }
        
    var chatServerUrl: String?
    
    private var group: Group?
    
//    var isSelectedFriends = false
    var commitBlock: (([ContactViewModel]) -> ())?
    var cancelBlock: (() -> ())?

    lazy var selectView : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets.init(top: 0, left: 15, bottom: 0, right: 15)
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.itemSize = CGSize(width: 35, height: 35)
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor.clear
        view.showsHorizontalScrollIndicator = false
        view.register(FZMGroupUserCell.self, forCellWithReuseIdentifier: "FZMGroupUserCell")
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    private lazy var numberLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_Theme, textAlignment: .center, text: nil)
    }()
    
//    lazy var confirmBtn : UIButton = {
//        let btn = UIButton.getNormalBtn(with: "邀请")
//        return btn
//    }()
    
    lazy var encryptGroup : UIButton = {
        var title = "跳过"
        if case .exclude = showType {
            title = "邀请"
        } else if case .allMember = showType {
            title = "移除"
        }
        let btn = UIButton.getNormalBtn(with: title)
        btn.isEnabled = true
        if case .allMember = showType {
            btn.isEnabled = false
        }
        return btn
    }()
    
    lazy var bottomView: UIView = {
        let view = UIView()
        view.makeOriginalShdowShow()
        view.backgroundColor = Color_FFFFFF
        view.addSubview(encryptGroup)
        encryptGroup.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: (k_ScreenWidth - 30) , height: 40))
            m.left.equalToSuperview().offset(15)
        }
        return view
    }()
    
    lazy var listView : FZMFriendContactListView = {
        let type : FZMSelectFriendViewShowType
        switch showType {
        case .allFriend:
            type = .all(true)
        case .allMember:
            type = .all(false)// 不显示邀请好友按钮
        case .exclude:
            type = .exclude(excludeUsers)
        }
        let view = FZMFriendContactListView(with: "", type)
        view.defaultSelectId = self.defaultSelectId
        view.selectBlock = {[weak self] (model) in
            self?.deal(contact: model)
        }
        return view
    }()
    
    lazy var searchBlockView : UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: -100, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        view.backgroundColor = Color_FAFBFC
        
        let circleView = UIView.init()
        circleView.layer.backgroundColor = Color_F1F4F6.cgColor
        circleView.layer.cornerRadius = 20
        circleView.tintColor = Color_8A97A5
        view.addSubview(circleView)
        circleView.snp.makeConstraints({ (m) in
            m.height.equalTo(40)
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
            m.right.equalToSuperview().offset(-65)
        })
        
        let cancelBtn = UIButton.init(type: .custom)
        cancelBtn.enlargeClickEdge(10, 10, 10, 15)
        cancelBtn.setTitle("完成", for: .normal)
        cancelBtn.setTitleColor(Color_Theme, for: .normal)
        cancelBtn.titleLabel?.font = UIFont.boldFont(16)
        cancelBtn.addTarget(self, action: #selector(hideSearchView), for: .touchUpInside)
        view.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints({ (m) in
            m.centerY.equalTo(circleView)
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize(width: 40, height: 25))
        })
        
        let imageV = UIImageView(image: #imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysTemplate))
        circleView.addSubview(imageV)
        imageV.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(5)
            m.size.equalTo(CGSize(width: 17, height: 18))
        })
        circleView.addSubview(searchInput)
        searchInput.snp.makeConstraints({ (m) in
            m.top.bottom.right.equalToSuperview()
            m.left.equalTo(imageV.snp.right).offset(10)
        })
        return view
    }()
    
    lazy var searchInput : UITextField = {
        let input = UITextField.init()
        input.tintColor = Color_Theme
        input.textAlignment = .left
        input.font = UIFont.regularFont(16)
        input.textColor = Color_24374E
        input.attributedPlaceholder = NSAttributedString(string: "搜索好友", attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.regularFont(16)])
        input.returnKeyType = .search
        input.addTarget(self, action: #selector(textFiledEditChanged(_:)), for: .editingChanged)
        return input
    }()
    
    lazy var tapControl: UIControl = {
        let v = UIControl.init()
        v.isHidden = true
        v.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
        v.addTarget(self, action: #selector(hideSearchView), for: .touchUpInside)
        return v
    }()
    
    lazy var noDataView: UIView = {
        let v = UIView.init()
        v.isHidden = true
        v.backgroundColor = Color_FAFBFC
        var imgView = FZMNoDataView(image: #imageLiteral(resourceName: "nodata_search"), imageSize: CGSize(width: 250, height: 200), desText: "没有匹配的对象", btnTitle: nil, clickBlock: nil)
        v.addSubview(imgView)
        imgView.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(65)
            m.left.right.equalToSuperview()
            m.bottom.equalToSuperview()
        })
        return v
    }()
    
    // MARK: -
    init(with type: FZMSelectFriendGroupShowStyle) {
        showType = type
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setNavItems()
        
        self.createUI()
        
        switch showType {
        case .exclude(let groupId):
            self.navigationItem.title = "选择好友"
            // 除已在本群的所有好友
            self.group = GroupManager.shared().getDBGroup(by: groupId)
            
            self.friendArrayForSearch = UserManager.shared().friends
            let friendDataSource = UserManager.shared().divideUser(self.friendArrayForSearch)
            
            let members = GroupManager.shared().getDBGroupMembers(with: groupId)
            if members.count == 0 {
                self.getMemberListRequest(groupId: groupId)
            }
            members.forEach { (member) in
                self.excludeUsers.append(member.memberId)
            }
            self.listView.selectType = .exclude(self.excludeUsers)
            
            self.listView.originDataSource = friendDataSource
            
        case .allFriend:
            self.navigationItem.title =  "创建群聊"
            // 所有好友列表
            self.friendArrayForSearch = UserManager.shared().friends
            let friendDataSource = UserManager.shared().divideUser(self.friendArrayForSearch)
            self.listView.originDataSource = friendDataSource
            
        case .allMember(let groupId):
            self.navigationItem.title = "选择好友"
            
            self.group = GroupManager.shared().getDBGroup(by: groupId)
            
            let members = GroupManager.shared().getDBGroupMembers(with: groupId)
            if members.count == 0 {
                self.getMemberListRequest(groupId: groupId)
            }
            let memberlist = members.filter { $0.memberId != LoginUser.shared().address }
            self.memberArrayForSearch = memberlist
            
            self.memberArrayForSearch.forEach { model in
                if model.memberType == 2 || model.memberType == 1 {
                    self.memberArrayForSearch .removeAll(model)
                }
            }
            let memberDataSource = UserManager.shared().divideGroupMember(self.memberArrayForSearch)
            self.listView.originDataSource = memberDataSource
        }
    }
    
    private func setNavItems() {
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        
        let backBtn = UIButton.init(type: .custom)
        backBtn.frame = CGRect.init(x: 0, y: 0, width: 45, height: 44)
        backBtn.setTitle("取消", for: .normal)
        backBtn.setTitleColor(Color_Theme, for: .normal)
        backBtn.titleLabel?.font = .systemFont(ofSize: 16)
        backBtn.contentHorizontalAlignment = .left
        backBtn.addTarget(self, action: #selector(cancelBtnPress), for: .touchUpInside)
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
        v.addSubview(backBtn)
        let leftbarItem = UIBarButtonItem.init(customView: v)
        self.navigationItem.leftBarButtonItem = leftbarItem
        
        let moreButton = UIButton.init(type: .custom)
        moreButton.frame = CGRect.init(x: 0, y: 0, width: 45, height: 44)
        moreButton.setImage(#imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysTemplate), for: .normal)
        moreButton.tintColor = Color_24374E
        moreButton.contentHorizontalAlignment = .right
        moreButton.contentVerticalAlignment = .center
        moreButton.addTarget(self, action: #selector(showSearchView), for: .touchUpInside)
        let v2 = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
        v2.addSubview(moreButton)
        let rightbarItem = UIBarButtonItem.init(customView: v2)
        self.navigationItem.rightBarButtonItem = rightbarItem
        
        // 直接设置item会引起页面跳转进来时左右item位移
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelBtnPress))
//        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(showSearchView))
//        self.navigationItem.leftBarButtonItem?.setTitleTextAttributes([.foregroundColor:Color_Theme, .font:UIFont.boldFont(16)], for: .normal)
    }
    
    // 获取群成员列表请求
    private func getMemberListRequest(groupId: Int) {
        guard let serverUrl = self.group?.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().getGroupMemberList(serverUrl: serverUrl, groupId: groupId) { [weak self] (list) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            if case .exclude = strongSelf.showType {
                list.forEach { (member) in
                    strongSelf.excludeUsers.append(member.memberId)
                }
                strongSelf.listView.selectType = .exclude(strongSelf.excludeUsers)
                strongSelf.listView.reloadData()
            } else if case .allMember = strongSelf.showType {
                
                let memberlist = list.filter { $0.memberId != LoginUser.shared().address }
                strongSelf.memberArrayForSearch = memberlist
                let memberDataSource = UserManager.shared().divideGroupMember(strongSelf.memberArrayForSearch)
                
                strongSelf.listView.originDataSource = memberDataSource
            }
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("获取群成员列表失败")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.hideSearchView()
    }
    
    @objc func hideSearchView() {
        self.searchInput.text = nil
        self.noDataView.isHidden = true
        self.searchInput.resignFirstResponder()
        
        self.listView.selectArr = self.selectArr
        self.listView.reloadTableViewForSearch()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.searchBlockView.frame = CGRect.init(x: 0, y: -100, width: k_ScreenWidth, height: k_StatusNavigationBarHeight)
            self.tapControl.alpha = 0
        }) { (_) in
            self.searchBlockView.removeFromSuperview()
        }
    }
    
    @objc func showSearchView() {
        UIApplication.shared.keyWindow?.addSubview(self.searchBlockView)
        self.searchInput.becomeFirstResponder()
        self.tapControl.isHidden = false
        self.noDataView.isHidden = true
        UIView.animate(withDuration: 0.3) {
            self.searchBlockView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight)
            self.tapControl.alpha = 1
        }
    }
    
    @objc private func cancelBtnPress() {
        self.cancelBlock?()
        self.navigationController?.popViewController()
//        if let nav = self.navigationController {
//            nav.dismiss(animated: true)
//        }else {
//            self.dismiss(animated: true) {
//            }
//        }
    }
    
    private func dismissClick(completion: (() -> Void)?) {
        if let nav = self.navigationController {
            nav.dismiss(animated: true) {
                completion?()
            }
        }else {
            self.dismiss(animated: true) {
                completion?()
            }
        }
    }
    
    private func createUI() {
        self.view.addSubview(selectView)
        selectView.snp.makeConstraints { (m) in
            m.left.equalToSuperview()
            m.top.equalToSuperview().offset(8)
            m.height.equalTo(35)
            m.right.equalToSuperview().offset(-60)
        }
        self.view.addSubview(numberLab)
        numberLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview()
            m.left.equalTo(selectView.snp.right)
            m.top.bottom.equalTo(selectView)
        }
        
        self.view.addSubview(bottomView)
        bottomView.snp.makeConstraints { (m) in
            m.bottom.left.right.equalTo(self.safeArea)
            m.height.equalTo(70)
        }
        
        self.view.addSubview(listView)
        listView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.bottom.equalTo(self.safeArea).offset(-70)
            m.top.equalToSuperview().offset(50)
        }
        
        encryptGroup.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            if case .allMember = strongSelf.showType {
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
                strongSelf.commitBlock?(strongSelf.selectArr)
                // 删除群成员
                strongSelf.removeNewMembersRequest()
            } else if case .allFriend = strongSelf.showType {
                // 创建群聊
                strongSelf.createGroup()
            } else if case .exclude = strongSelf.showType {
                // 邀请新群员
                strongSelf.inviteNewMembersRequest()
            }
        }.disposed(by: disposeBag)
        
        self.view.addSubview(tapControl)
        tapControl.snp.makeConstraints({ (m) in
            m.left.equalTo(self.view)
            m.top.equalTo(self.view)
            m.height.equalTo(k_ScreenHeight)
            m.width.equalTo(k_ScreenWidth)
        })
        self.view.addSubview(noDataView)
        noDataView.snp.makeConstraints({ (m) in
            m.edges.equalTo(tapControl)
        })
    }
    
    private func deal(contact: ContactViewModel) {
        defer {
            self.numberLab.text = selectArr.count > 0 ? "\(selectArr.count)" : ""
        }
        if contact.isSelected {
            selectArr = selectArr.filter({ $0.sessionIDStr != contact.sessionIDStr }) + [contact]
//            selectArr.append(contact)
            DispatchQueue.main.async {
                self.selectView.reloadData()
            }
            
        }else {
            var currentModel = ContactViewModel.init()
            selectArr.forEach { model in
                if model.sessionIDStr == contact.sessionIDStr{
                    currentModel = model
                }
            }
            if let index = selectArr.firstIndex(of: currentModel) {
                selectView.performBatchUpdates {
                    selectArr.remove(at: index)
                    selectView.deleteItems(at: [IndexPath(item: index, section: 0)])
                } completion: { _ in

                }
            }
        }
        if case .allMember = showType {
            self.encryptGroup.setAttributedTitle(NSAttributedString(string: "移除", attributes: [.foregroundColor: UIColor.white,.font:UIFont.regularFont(16)]), for: .normal)
            self.encryptGroup.isEnabled = selectArr.count > 0
        } else if case .allFriend = showType {
            self.encryptGroup.setAttributedTitle(NSAttributedString(string: selectArr.count > 0 ? "创建" : "跳过", attributes: [.foregroundColor: UIColor.white,.font:UIFont.regularFont(16)]), for: .normal)
        } else if case .exclude = showType {
            self.encryptGroup.setAttributedTitle(NSAttributedString(string: "邀请", attributes: [.foregroundColor: UIColor.white,.font:UIFont.regularFont(16)]), for: .normal)
            self.encryptGroup.isEnabled = selectArr.count > 0
        }
    }
    
    //MARK: - 网络请求
    // 邀请新群员
    private func inviteNewMembersRequest() {
        guard let groupId = self.group?.id, let serverUrl = self.group?.chatServerUrl else {
            return
        }
        FZMLog("group --- \(groupId)  \(serverUrl)")
        var users = [String]()
        
        selectArr.forEach { (contact) in
            users.append(contact.sessionIDStr)
        }

        if users.isEmpty {
            self.showToast("请选择好友")
            return
        }
        FZMLog("users --- \(users)")
        self.showProgress()
        
        // 邀请新群成员请求
        GroupManager.shared().inviteGroupMembers(serverUrl: serverUrl, groupId: groupId, memberIds: users) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            APP.shared().showToast("邀请成功")
            strongSelf.reloadBlock?()
            strongSelf.navigationController?.popViewController()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("邀请失败")
        }
    }
    
    // 删除群成员
    private func removeNewMembersRequest() {
        guard let groupId = self.group?.id, let serverUrl = self.group?.chatServerUrl else {
            return
        }
        FZMLog("group --- \(groupId)  \(serverUrl)")
        var users = [String]()
        
        selectArr.forEach { (contact) in
            users.append(contact.sessionIDStr)
        }

        if users.isEmpty {
            self.showToast("请选择好友")
            return
        }
        FZMLog("users --- \(users)")
        self.showProgress()
        
        // 删除群成员请求
        GroupManager.shared().groupRemoveMembers(serverUrl: serverUrl, groupId: groupId, memberIds: users) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            APP.shared().showToast("移除成功")
            strongSelf.reloadBlock?()
            strongSelf.navigationController?.popViewController()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("移除失败")
        }
    }
    
    private var isCreateGroupRequesting = false
    
    // 创建群聊
    private func createGroup() {
        var groupName = LoginUser.shared().address.shortAddress
        if let nickname = LoginUser.shared().nickName?.value, !nickname.isBlank {
            groupName = nickname
        }
        groupName = groupName + "创建的群聊"
        
        var memberIds = [String]()
        memberIds = selectArr.compactMap { (item) -> String in
            return item.sessionIDStr
        }
        guard let serverUrl = self.chatServerUrl else {
            self.showToast("未选择创建群聊的服务器地址")
            return
        }
        if isCreateGroupRequesting {
            return
        }
        isCreateGroupRequesting = true
        self.showProgress()
        
        // 创建群聊请求
        GroupManager.shared().createGroup(serverUrl: serverUrl, name: groupName, introduce: "", avatarUrl: "", memberIds: memberIds) { [weak self] (group) in
            guard let strongSelf = self else { return }
            strongSelf.isCreateGroupRequesting = false
            strongSelf.hideProgress()
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(group.address)))
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.isCreateGroupRequesting = false
            strongSelf.hideProgress()
            strongSelf.showToast("创建群失败")
        }
    }
}

extension FZMSelectFriendToGroupVC {
    
    @objc func textFiledEditChanged(_ textField: UITextField) {
        if textField.markedTextRange == nil ||
            textField.markedTextRange?.isEmpty ?? false {
            if let text = textField.text {
                self.search(text)
            }
        }
    }
    
    private func search(_ text: String) {
        if text.isEmpty {
            self.noDataView.isHidden = true
            self.tapControl.isHidden = false
            self.listView.selectArr = self.selectArr
            self.listView.reloadTableViewForSearch()
            return
        }
        let lowercasedTest = text.lowercased()
        
        
        var section = [(title: String, value:[ContactViewModel])]()
        var isFriendSearch = true
        if case .allMember = showType {
            isFriendSearch = false
        }
        
        if isFriendSearch {
            let searchList = self.friendArrayForSearch.filter { $0.contactsName.lowercased().contains(lowercasedTest) || $0.contactsName.lowercased().contains(lowercasedTest) }.compactMap { ContactViewModel.init(with: $0) }.sorted { $0.name < $1.name }
            section = [(title: "", value: searchList)]
        } else {
            let searchList = self.memberArrayForSearch.filter { $0.user?.stafInfo != nil && $0.user!.stafInfo!.name.lowercased().contains(lowercasedTest) || $0.user?.nickname != nil && $0.user!.nickname!.lowercased().contains(lowercasedTest) || $0.user?.alias != nil && $0.user!.alias!.lowercased().contains(lowercasedTest) || $0.memberName != nil && $0.memberName!.lowercased().contains(lowercasedTest) || $0.memberId.contains(lowercasedTest) }.compactMap { ContactViewModel.init(with: $0) }.sorted { $0.name < $1.name }
            section = [(title: "", value: searchList)]
        }

        if section.count == 0  {
            self.tapControl.isHidden = true
            self.noDataView.isHidden = false
        } else {
            self.tapControl.isHidden = true
            self.noDataView.isHidden = true
            self.listView.selectArr = self.selectArr
            self.listView.reloadTableViewForSearch(dataSource: section, searchString: text)
        }
    }
}

extension FZMSelectFriendToGroupVC: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectArr.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: FZMGroupUserCell.self, for: indexPath)
        cell.nameLab.isHidden = true
        guard indexPath.row < selectArr.count else {
            return cell
        }
        let model = selectArr[indexPath.row]
//        UserManager.shared().getUser(by: model.sessionIDStr) { (user) in
//            guard let user = user else { return }
//            cell.headImageView.kf.setImage(with: URL.init(string: user.avatarURLStr), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
//        }
        cell.headImageView.kf.setImage(with: URL.init(string: model.avatar), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
        return cell
    }
}
