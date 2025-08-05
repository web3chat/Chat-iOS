//
//  FZMGroupMemberListView.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/30.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import SectionIndexView
import SwifterSwift

class FZMGroupMemberListVC: UIViewController, ViewControllerProtocol {
    
    private let disposeBag = DisposeBag.init()

    var group : Group
    var fromTag : Int
    var isSearch = false
    
    var memberList = [(title: String, value:[ContactViewModel])]() {// 列表显示数据源（所有成员以及搜索结果成员）
        didSet {
        }
    }
    var dealtList = [(title: String, value:[ContactViewModel])]()// 分组后群成员数据源
    var originList = [GroupMember]() {// 群成员数据源
        didSet {
            deal(with: originList)
        }
    }
    
    private var searchString: String?
    
    var reloadBlock : NormalBlock?
    var sendBlock : StringBlock?
    
    lazy var headerView : UIView = {
        let view = UIView()
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints({ (m) in
            m.edges.equalToSuperview().inset(UIEdgeInsets(top: 11, left: 15, bottom: 11, right: 15))
        })
        view.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 46)
        return view
    }()
    
    lazy var titleLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(17), textColor: Color_24374E, textAlignment: .left, text: group.contactsName + "(\(group.memberNum))")
        return lab
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
        cancelBtn.setTitle("取消", for: .normal)
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
        input.attributedPlaceholder = NSAttributedString(string: "搜索群成员", attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.regularFont(16)])
        input.returnKeyType = .search
        input.addTarget(self, action: #selector(textFiledEditChanged(_:)), for: .editingChanged)
        return input
    }()
    
    lazy var tapControl: UIControl = {
        let v = UIControl.init()
        v.isHidden = true
        v.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
        v.isHidden = true
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
    
    lazy var memberListView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = .white
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = headerView
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 50
        view.register(FZMGroupMemberCell.self, forCellReuseIdentifier: "FZMGroupMemberCell")
        view.separatorColor = .white
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.keyboardDismissMode = .onDrag
        return view
    }()
    
    //MARK: -
    init(with group: Group , fromTag:Int) {
        self.group = group
        self.fromTag = fromTag
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        self.navigationItem.title = "群成员"
        if fromTag == 1{ // 专属红包过来的
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "tool_search"), style: .plain, target: self, action: #selector(showSearchView))
        }else {
            self.navigationItem.rightBarButtonItems = [
                UIBarButtonItem(image: #imageLiteral(resourceName: "tool_more"), style: .plain, target: self, action: #selector(moreClick)),
                UIBarButtonItem(image: #imageLiteral(resourceName: "tool_search"), style: .plain, target: self, action: #selector(showSearchView))]
        }
        
        self.createUI()
        self.refreshData()
        
        if let list = self.group.members {
            self.originList = list
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.hideSearchView()
    }
    
    @objc func hideSearchView() {
        self.searchInput.text = nil
        self.searchString = nil
        self.noDataView.isHidden = true
        self.searchInput.resignFirstResponder()
        self.isSearch = false
        
        if self.memberList.count != self.dealtList.count {
            self.memberList = self.dealtList
        }
        self.reloadData()
        
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
    
    @objc func moreClick() {
        let addBlock = {
            // 邀请新群成员
            FZMUIMediator.shared().pushVC(.selectFriend(type: .exclude(self.group.id), chatServerUrl: "", completeBlock: {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.refreshData()
                strongSelf.reloadBlock?()
            }))
        }
        let managerBlock = {
            let vc = FZMGroupManagerSetVC(with: self.group)
            vc.changeBlock = {[weak self] in
                self?.refreshData()
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
        let deleteBlock = {
            // 删除群成员
            FZMUIMediator.shared().pushVC(.selectFriend(type: .allMember(self.group.id), chatServerUrl: "", completeBlock: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.refreshData()
            }))
//            let vc = FZMGroupCtrlMemberVC(with: self.group, ctrlType: .delete)
//            vc.reloadBlock = {[weak self] in
//                self?.refreshData()
//                self?.reloadBlock?()
//            }
//            self.navigationController?.pushViewController(vc, animated: true)
        }
        if let person = group.person, person.memberType == 2 {
            let view = FZMMenuView(with: [FZMMenuItem(title: "添加新成员", block: {
                addBlock()
            }),FZMMenuItem(title: "删除成员", block: {
                deleteBlock()
            }),FZMMenuItem(title: "设置管理员", block: {
                managerBlock()
            })])
            view.show(in: CGPoint(x: k_ScreenWidth-15, y: k_StatusNavigationBarHeight))
        }else if let person = group.person, person.memberType == 1 {
            let view = FZMMenuView(with: [FZMMenuItem(title: "添加新成员", block: {
                addBlock()
            }),FZMMenuItem(title: "删除成员", block: {
                deleteBlock()
            })])
            view.show(in: CGPoint(x: k_ScreenWidth-15, y: k_StatusNavigationBarHeight))
        }else {
            addBlock()
        }
    }
    
    private func createUI() {
        self.view.addSubview(memberListView)
        memberListView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.view.addSubview(tapControl)
        tapControl.snp.makeConstraints({ (m) in
            m.left.equalTo(view)
            m.top.equalTo(view)
            m.height.equalTo(k_ScreenHeight)
            m.width.equalTo(k_ScreenWidth)
        })
        self.view.addSubview(noDataView)
        noDataView.snp.makeConstraints({ (m) in
            m.edges.equalTo(tapControl)
        })
    }
    
    // 刷新群成员列表
    func refreshData() {
        // 获取本地数据
        if let dbGroup = GroupManager.shared().getDBGroup(by: self.group.id) {
            self.group = dbGroup
            
            if let list = self.group.members {
                self.originList = list
            }
        }
        
        guard let serverUrl = group.chatServerUrl else {
            refreshMembersUserInfoRequest()
            return
        }
        self.showProgress(with: nil)
        // 获取群成员列表请求
        GroupManager.shared().getGroupMemberList(serverUrl: serverUrl, groupId: group.id) { [weak self] (members) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.originList = members
            strongSelf.refreshMembersUserInfoRequest()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("获取群成员列表失败")
            strongSelf.refreshMembersUserInfoRequest()
        }
    }
    
    private var count: Int = 0 {
        didSet {
            if count == self.originList.count {
                DispatchQueue.main.async {
                    self.refreshUserInfoSuccess = true
                    self.memberListView.reloadData()
                }
            }
        }
    }
    
    private var refreshUserInfoSuccess = false
    
    // 刷新所有群成员的用户信息
    private func refreshMembersUserInfoRequest() {
        guard !refreshUserInfoSuccess else {
            return
        }
        originList.forEach { (member) in
            UserManager.shared().getNetUser(targetAddress: member.memberId) { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.count += 1
            } failureBlock: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.count += 1
            }
        }
    }
    
    func deal(with list: [GroupMember]) {
        self.view.showProgress()
        DispatchQueue.global().async {
            self.dealtList = UserManager.shared().normalGroupMember(list)
            self.memberList = self.dealtList
            
            DispatchQueue.main.async {
                self.view.hideProgress()
                
                self.reloadData()
            }
        }
    }
    
    // 群成员数据处理转为列表可用数据
    func sortGroupManagers(_ members: [GroupMember]) -> [ContactViewModel] {
        // 用户角色，2=群主，1=管理员，0=群员，10=退群
        let allManagers = members.filter { $0.memberType == 1 }.sorted { $0.contactsName < $1.contactsName }
        let dealManagers = allManagers.compactMap { ContactViewModel.init(with: $0) }
        return dealManagers
    }
    
    func reloadData() {
        let items = self.memberList.compactMap { ($0.title) }.compactMap { (title) -> SectionIndexViewItem? in
            let item = SectionIndexViewItemView.init()
            item.title = title
            item.indicator = SectionIndexViewItemIndicator.init(title: title)
            return item
        }
        self.memberListView.sectionIndexView(items: items)
        self.memberListView.reloadData()
    }
}

extension FZMGroupMemberListVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.memberList.count else { return nil }
        let model = self.memberList[section]
        let array = model.value
        var title = ""
        if !self.isSearch{
            title = section == 0 ? "群主、管理员(\(array.count)人)" : "\(model.title)(\(array.count)人)"
        }else{
            title = "\(model.title)(\(array.count)人)"
        }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text: "       " + title)
        lab.backgroundColor = Color_FFFFFF
        return lab
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return memberList.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.memberList.count else { return 0 }
        return memberList[section].value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: FZMGroupMemberCell.self, for: indexPath)
        guard indexPath.section < self.memberList.count,
              indexPath.row < self.memberList[indexPath.section].value.count else {
            return cell
        }
        let model = memberList[indexPath.section].value[indexPath.row]
        cell.searchString = searchString
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.memberList.count,
              indexPath.row < self.memberList[indexPath.section].value.count else {
            return
        }
        let model = memberList[indexPath.section].value[indexPath.row]
//        FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: model.sessionIDStr, source: .group(groupId: self.group.id)))
        let vc = FriendInfoVC.init(with: model.sessionIDStr, source: .group(groupId: self.group.id))
        vc.sendredBlock = {[] (note) in
            print("note is \(note)")
            
            if self.sendBlock != nil {
//                vc.navigationController?.popViewController()
                self.sendBlock!(note)
            }
            
        }
        vc.hidesBottomBarWhenPushed = true
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.pushViewController(vc)
        }
    }
}

extension FZMGroupMemberListVC {

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
            self.searchString = nil
            self.memberList = self.dealtList
            return
        }
        
        let lowercasedTest = text.lowercased()
        let searchList = self.originList.filter {$0.user?.stafInfo != nil && $0.user!.stafInfo!.name.lowercased().contains(lowercasedTest) || $0.user?.nickname != nil && $0.user!.nickname!.lowercased().contains(lowercasedTest) || $0.user?.alias != nil && $0.user!.alias!.lowercased().contains(lowercasedTest) || $0.memberName != nil && $0.memberName!.lowercased().contains(lowercasedTest) || $0.memberId.contains(lowercasedTest) }

        if searchList.count == 0  {
            self.tapControl.isHidden = true
            self.noDataView.isHidden = false
        } else {
            self.tapControl.isHidden = true
            self.noDataView.isHidden = true
            self.searchString = text
            self.memberList = UserManager.shared().divideGroupMember(searchList)
            self.isSearch = true
            self.memberListView.reloadData()
        }
    }
}


