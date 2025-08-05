//
//  ContactListView.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/10.
//

import Foundation
import SnapKit
import SectionIndexView
import UIKit
import SwifterSwift

class FZMContactListView: FZMScrollPageItemBaseView {
    
    let disposeBag = DisposeBag()
    let lock = NSLock()
    var selectBlock : ((ContactViewModel)->())?
    
    var dataSource = [(title: String, value: [ContactViewModel])]() {
        didSet {
            DispatchQueue.main.async {
                self.reloadData()
            }
        }
    }
    
    var isScrollEnabled: Bool = true
    
    lazy var tableView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 50
        view.register(ContactsCell.self, forCellReuseIdentifier: "ContactsCell")
        view.separatorColor = Color_F1F4F6
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.keyboardDismissMode = .onDrag
        view.tag = 1888888
        return view
    }()
    
    override init(with pageTitle: String) {
        super.init(with: pageTitle)
        self.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reloadData() {
    }
}

extension FZMContactListView: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.dataSource.count else { return 0 }
        return dataSource[section].value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: ContactsCell.self, for: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

// MARK: - 
enum FZMSelectFriendViewShowType {
    case no //不显示可选
    case all(Bool) //所有都可选 (Bool: 页面无数据视图是否显示邀请好友按钮flg)
    case exclude([String]) //排除一部分
}

// 好友列表、黑名单列表；  群：创建群选择好友列表、添加、删除好友列表
class FZMFriendContactListView: FZMContactListView {
    
    var selectType : FZMSelectFriendViewShowType = .no
    
    var defaultSelectId: String = ""
    
    private var isBlackList = false
    
    var noDataView = FZMNoDataView(image: #imageLiteral(resourceName: "nodata_contact_friend"), imageSize: CGSize(width: 250, height: 200), desText: "暂无好友", btnTitle: "邀请好友", clickBlock: {
        FZMUIMediator.shared().pushVC(.goQRCodeShow(type: .me))
    })
    
    //从上层传入的
    var selectArr = [ContactViewModel]()// 选中
    
    var originDataSource = [(title: String, value: [ContactViewModel])]() {// 用户初始源数据
        didSet {
            self.dataSource = self.originDataSource
        }
    }
    
    var searchString: String? = nil
    
    // 列表底部显示文本 - *个好友
    private lazy var countLab: UILabel = {
        let lab = UILabel.init()
        lab.textAlignment = .center
        lab.textColor = Color_8A97A5
        lab.font = .systemFont(ofSize: 14)
        lab.text = "0个好友"
        
        return lab
    }()
    
    private lazy var footerView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 50))
        v.backgroundColor = .white
        
        v.addSubview(self.countLab)
        self.countLab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        return v
    }()
    
    convenience init(with pageTitle: String , _ selectType: FZMSelectFriendViewShowType) {
        self.init(with: pageTitle)
        self.selectType = selectType
        switch self.selectType {
        case .no:
            self.noDataView.hideBottomBtn = false
        case .all(let showBtnFlg):
            self.noDataView.hideBottomBtn = !showBtnFlg
        default:
            self.noDataView.hideBottomBtn = true
        }
    }
    
    init(with pageTitle: String, isBlacklist: Bool = false) {
        super.init(with: pageTitle)
        
        self.isBlackList = isBlacklist
        
        self.addSubview(self.noDataView)
        self.noDataView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth, height: 285))
        }
        self.noDataView.isHidden = true
        if isBlacklist {
            self.selectType = .no
            self.noDataView.desLab.text = "暂无黑名单"
            self.noDataView.hideBottomBtn = true
        }
    }
    
    func reloadTableViewForSearch(dataSource:  [(title: String, value: [ContactViewModel])]? = nil, searchString: String? = nil) {
        DispatchQueue.main.async {
            self.lock.lock()
            if let d = dataSource {
                self.dataSource = d
            } else {
                self.dataSource = self.originDataSource
            }
            
            //将搜索选中的告知datasource
            if self.selectArr.count > 0 {
                self.dataSource.forEach { (item) in
                    let users = item.value
                    users.forEach { mode in
                        mode.isSelected = false
                        self.selectArr.forEach { (nextItem) in
                            if nextItem.sessionIDStr ==  mode.sessionIDStr {
                                mode.isSelected = true
                            }
                        }
                    }
                }
            } else {
                self.dataSource.forEach { (item) in
                    let user = item.value
                    user.forEach { mode in
                        mode.isSelected = false
                    }
                }
            }
            
            self.searchString = searchString
            
            self.reloadData()
            
            self.lock.unlock()
        }
    }
    
    override func reloadData() {
        if self.dataSource.isEmpty {
            self.noDataView.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noDataView.isHidden = true
            self.tableView.isHidden = false
        }
        
        var friendsCount = 0
        self.dataSource.forEach { (item) in
            friendsCount += item.value.count
        }
        
        DispatchQueue.main.async {
            let str = self.isBlackList ? "黑名单成员" : "好友"
            self.countLab.text = "\(friendsCount)个\(str)"
            self.tableView.tableFooterView = friendsCount == 0 ? UIView.init(frame: CGRect.zero) : self.footerView
            
            let items = self.dataSource.compactMap { $0.title }.compactMap { (title) -> SectionIndexViewItem? in
                let item = SectionIndexViewItemView.init()
                item.title = title
                item.indicator = SectionIndexViewItemIndicator.init(title: title)
                return item
            }
            self.tableView.sectionIndexView(items: items)
            
            self.tableView.reloadData()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.dataSource.count else { return nil }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text: "       " + self.dataSource[section].title)
        lab.backgroundColor = Color_FFFFFF
        return lab
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.dataSource.count else { return 0 }
        return dataSource[section].value.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: ContactsCell.self, for: indexPath)
        guard indexPath.section < self.dataSource.count,
              indexPath.row < self.dataSource[indexPath.section].value.count else {
                  return cell
              }
        let model = dataSource[indexPath.section].value[indexPath.row]
        model.searchString = self.searchString
        if model.sessionIDStr == self.defaultSelectId {
            model.isSelected = true
            selectBlock?(model)
            self.defaultSelectId = ""
        }
        cell.configure(with: model)
        
        switch selectType {
        case .all:
            cell.showSelect()
            cell.selectStyle = model.isSelected ? .select : .disSelect
        case .exclude(let users):
            cell.showSelect()
            if users.contains(model.sessionIDStr) {
                cell.selectStyle = .cantSelect
            } else {
                cell.selectStyle = model.isSelected ? .select : .disSelect
            }
        default: break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.dataSource.count,
              indexPath.row < self.dataSource[indexPath.section].value.count else {
                  return
              }
        let model = dataSource[indexPath.section].value[indexPath.row]
        switch selectType {
        case .all:
            // 选中状态
            model.isSelected = !model.isSelected
            selectBlock?(model)
            
            DispatchQueue.main.async {
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        case .exclude(let users):
            if !users.contains(model.sessionIDStr) {
                model.isSelected = !model.isSelected
                selectBlock?(model)
                
                DispatchQueue.main.async {
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
            }
        default:
            selectBlock?(model)
        }
    }
}



// 群列表
class FZMGroupContactListView: FZMContactListView {
    var showSelect = false
    var selectGroupBlock : ((ContactViewModel)->())?
    
    var noDataView = FZMNoDataView(image: #imageLiteral(resourceName: "nodata_contact_group"), imageSize: CGSize(width: 250, height: 200), desText: "暂无群聊", btnTitle: "创建群聊", clickBlock: {
        FZMUIMediator.shared().pushVC(.goChooseServerToCreateGroup)
    })
    
    // 列表底部显示文本 - *个群聊
    private lazy var countLab: UILabel = {
        let lab = UILabel.init()
        lab.textAlignment = .center
        lab.textColor = Color_8A97A5
        lab.font = .systemFont(ofSize: 14)
        lab.text = "0个群聊"
        
        return lab
    }()
    
    private lazy var footerView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 50))
        v.backgroundColor = .white
        
        v.addSubview(self.countLab)
        self.countLab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        return v
    }()
    
    convenience init(with pageTitle: String , showSelect: Bool = false) {
        self.init(with: pageTitle)
        self.showSelect = showSelect
        
        self.addSubview(self.noDataView)
        self.noDataView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth, height: 285))
        }
        self.noDataView.isHidden = true
        self.noDataView.hideBottomBtn = showSelect
    }
    
    override init(with pageTitle: String) {
        super.init(with: pageTitle)
    }
    
    override func reloadData() {
        if self.dataSource.isEmpty {
            self.noDataView.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noDataView.isHidden = true
            self.tableView.isHidden = false
        }
        
        var groupsCount = 0
        self.dataSource.forEach { (item) in
            groupsCount += item.value.count
        }
        
        DispatchQueue.main.async {
            self.countLab.text = "\(groupsCount)个群聊"
            self.tableView.tableFooterView = groupsCount == 0 ? UIView.init(frame: CGRect.zero) : self.footerView
            
            let items = self.dataSource.compactMap { $0.title }.compactMap { (title) -> SectionIndexViewItem? in
                let item = SectionIndexViewItemView.init()
                item.title = title
                item.indicator = SectionIndexViewItemIndicator.init(title: title)
                return item
            }
            self.tableView.sectionIndexView(items: items)
            
            self.tableView.reloadData()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.dataSource.count else { return nil }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text: "       " + self.dataSource[section].title)
        lab.backgroundColor = Color_FFFFFF
        return lab
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.dataSource.count else { return 0 }
        return dataSource[section].value.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: ContactsCell.self, for: indexPath)
        guard indexPath.section < self.dataSource.count,
              indexPath.row < self.dataSource[indexPath.section].value.count else {
                  return cell
              }
        let model = dataSource[indexPath.section].value[indexPath.row]
        cell.configure(with: model)
        
        if showSelect {
            cell.showSelect()
            cell.selectStyle = model.isSelected ? .select : .disSelect
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.dataSource.count,
              indexPath.row < self.dataSource[indexPath.section].value.count else {
                  return
              }
        let model = dataSource[indexPath.section].value[indexPath.row]
        if showSelect {
            // 选中状态
            model.isSelected = !model.isSelected
            selectBlock?(model)
            
            DispatchQueue.main.async {
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        } else {
            selectGroupBlock?(model)
        }
    }
}


