//
//  FZMGroupManagerSetVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/30.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import SwifterSwift

class FZMGroupManagerSetVC: UIViewController, ViewControllerProtocol {
    
    private let group : Group
    
    let disposeBag = DisposeBag.init()
    
    var changeBlock : NormalBlock?
    lazy var memberListView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_FAFBFC
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = bottomView
        view.rowHeight = 50
        view.register(FZMGroupMemberCell.self, forCellReuseIdentifier: "FZMGroupMemberCell")
        view.separatorColor = Color_F1F4F6
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        return view
    }()
    
    lazy var bottomView : UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 50))
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_Theme, textAlignment: .center, text: "添加管理员")
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.centerX.equalToSuperview().offset(10)
            m.size.equalTo(CGSize(width: 86, height: 23))
        })
        lab.isUserInteractionEnabled = true
        let imageView = UIImageView(image: #imageLiteral(resourceName: "tool_more").withRenderingMode(.alwaysTemplate))
        imageView.tintColor = Color_Theme
        view.addSubview(imageView)
        imageView.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.right.equalTo(lab.snp.left).offset(-10)
            m.size.equalTo(CGSize(width: 17, height: 17))
        })
        imageView.isUserInteractionEnabled = true
        
        let addTap = UITapGestureRecognizer()
        addTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            let vc = FZMGroupAddManagerVC(with: strongSelf.group)
            vc.addBlock = { model in
                strongSelf.managerList.append(model)
                strongSelf.changeBlock?()
                strongSelf.memberListView.reloadData()
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
        }.disposed(by: disposeBag)
        view.addGestureRecognizer(addTap)
        
        return view
    }()
    
    var managerList = [ContactViewModel]() {
        didSet{
            bottomView.isHidden = managerList.count >= 10
            DispatchQueue.main.async {
                self.memberListView.reloadData()
            }
        }
    }
    
    init(with group: Group) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.navigationItem.title = "管理员设置"
        self.createUI()
        
        if let members = group.members {
            managerList = self.sortGroupManagers(members)
        }
        
        // 接口获取群信息
        self.getGroupDetailInfoRequest()
    }
    
    // 群成员数据处理转为列表可用数据
    private func sortGroupManagers(_ members: [GroupMember]) -> [ContactViewModel] {
        // 用户角色，2=群主，1=管理员，0=群员，10=退群
        let allManagers = members.filter { $0.memberType == 1 }.sorted { $0.contactsName < $1.contactsName }
        let dealManagers = allManagers.compactMap { ContactViewModel.init(with: $0) }
        return dealManagers
    }
    
    private func createUI() {
        self.view.addSubview(memberListView)
        memberListView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
    
    // 接口获取群信息
    private func getGroupDetailInfoRequest() {
        guard let serverUrl = group.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: group.id) { [weak self] (group) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.managerList = strongSelf.sortGroupManagers(group.members!)
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
        }
    }
}

extension FZMGroupManagerSetVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = Color_FAFBFC
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text:"管理员(\(managerList.count)/10)")
        if section == 0 {
            lab.text = "群主"
        }
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.top.bottom.right.equalToSuperview()
            m.left.equalToSuperview().offset(20)
        }
        return view
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return managerList.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: FZMGroupMemberCell.self, for: indexPath)
        cell.showType = false
        if indexPath.section == 0 {
            cell.configure(with: ContactViewModel.init(with: group.owner))
            cell.showRightDelete = false
        }else {
            guard managerList.count > indexPath.row else {
                return cell
            }
            cell.configure(with: managerList[indexPath.row])
            cell.showRightDelete = true
            cell.deleteBlock = { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.deleteManager(with: indexPath.row)
            }
        }
        
        return cell
    }
    
    // 移除管理员
    private func deleteManager(with index: Int) {
        guard let serverUrl = self.group.chatServerUrl, index < managerList.count else {
            return
        }
        self.showProgress(with: nil)
        let model = managerList[index]
        // 用户角色 0=群员, 1=管理员
        GroupManager.shared().updateMemberType(serverUrl: serverUrl, groupId: self.group.id, memberId: model.sessionIDStr, memberType: 0) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.changeBlock?()
            strongSelf.memberListView.performBatchUpdates {
                strongSelf.managerList.remove(at: index)
                strongSelf.memberListView.deleteRows(at: [IndexPath.init(row: index, section: 1)], with: .fade)
            } completion: { _ in
                
            }
            
        } failureBlock: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("管理员移除失败")
        }
    }
}
