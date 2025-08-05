//
//  BannedListVC.swift
//  chat
//
//  Created by liyaqin on 2021/11/3.
//

import Foundation
import SwiftyJSON
import SwifterSwift

class BannedListVC: UIViewController, ViewControllerProtocol {
    
    var groupId : Int// 群id
    var serverUrl : String
    
    var bannedList = [(title: String, value:[ContactViewModel])]() // 列表显示数据源
    var members = [GroupMember]()
    
    lazy var bannedListView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = .white
        view.dataSource = self
        view.delegate = self
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 50
        view.register(BannedMemberCell.self, forCellReuseIdentifier: "BannedMemberCell")
        view.separatorColor = .white
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.keyboardDismissMode = .onDrag
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "禁言名单"
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "全部解禁", style: .plain, target: self, action: #selector(rightBtnAction))
        self.navigationItem.rightBarButtonItem?.tintColor = Color_Theme
        
        self.createUI()
        self.refreshData()
    }
    
    init(with groupId:Int,serverUrl:String){
        self.groupId = groupId
        self.serverUrl = serverUrl
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BannedListVC {
    private func createUI() {
        self.view.addSubview(bannedListView)
        bannedListView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
    
    @objc func rightBtnAction() {
        guard bannedList.count > 0 else { return }
        
        let mebersId = members.compactMap { (member) -> String in
            return member.memberId
        }
        self.showProgress(with: nil)
        GroupManager.shared().updateMemberMuteTime(serverUrl: serverUrl, groupId: self.groupId, muteTime: 0, memberIds:mebersId) {[weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.bannedList.removeAll()
            strongSelf.bannedListView.reloadData()
        } failureBlock: { (error) in
            self.hideProgress()
            self.hideProgress()
            self.showToast(error.localizedDescription)
        }
    }
    func refreshData() {
        GroupManager.shared().getMemberMuteTime(serverUrl: self.serverUrl, groupId: self.groupId) { [weak self] (members) in
            guard let strongSelf = self else { return }
            strongSelf.deal(with: members)
        } failureBlock: { (error) in
            self.showToast(error.localizedDescription)
        }
    }
    
    func deal(with list: [GroupMember]) {
        self.view.showProgress()
        self.members = list
        DispatchQueue.global().async {
            self.bannedList = UserManager.shared().normalGroupMember(list)
            DispatchQueue.main.async {
                self.view.hideProgress()
                self.bannedListView.reloadData()
            }
        }
    }
    
    // 移除禁言
    private func deleteBanned(with indexPath: IndexPath,model:ContactViewModel) {
        self.showProgress(with: nil)
        let memberId = model.groupMember?.memberId
        GroupManager.shared().updateMemberMuteTime(serverUrl: serverUrl, groupId: self.groupId, muteTime: 0, memberIds: [memberId!]) {[weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            let memberId = model.groupMember?.memberId
            strongSelf.members = strongSelf.members.filter( {$0.memberId !=  memberId!})
            strongSelf.deal(with: strongSelf.members)
        } failureBlock: { (error) in
            self.hideProgress()
            self.showToast(error.localizedDescription)
        }
    }
}

extension BannedListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.bannedList.count else { return nil }
        let model = self.bannedList[section]
        let title = "\(model.title)"
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text: "       " + title)
        lab.backgroundColor = Color_FFFFFF
        return lab
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return bannedList.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.bannedList.count else { return 0 }
        return bannedList[section].value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: BannedMemberCell.self, for: indexPath)
        guard indexPath.section < self.bannedList.count,
              indexPath.row < self.bannedList[indexPath.section].value.count else {
            return cell
        }
        let model = bannedList[indexPath.section].value[indexPath.row]
        cell.configure(with: model)
        cell.deleteBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.deleteBanned(with: indexPath, model: model)
        }
        return cell
    }
}
