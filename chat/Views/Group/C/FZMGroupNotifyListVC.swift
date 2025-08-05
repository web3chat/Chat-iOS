//
//  FZMGroupNotifyListVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/29.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import MJRefresh

class FZMGroupNotifyListVC: FZMBaseViewController {
    
    private let group : IMGroupDetailInfoModel
    private var startId : String?
    private lazy var listView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_FAFBFC
        view.delegate = self
        view.dataSource = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.separatorStyle = .none
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.mj_footer = MJRefreshBackNormalFooter(refreshingBlock: {[weak self] in
            self?.loadMore()
        })
        view.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: ScreenWidth, height: CGFloat(BottomOffset)))
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.rowHeight = UITableView.automaticDimension
        view.register(FZMGroupNotifyCell.self, forCellReuseIdentifier: "FZMGroupNotifyCell")
        
        return view
    }()
    
    private var notifyList = [IMGroupNotifyModel]()
    
    init(with group: IMGroupDetailInfoModel) {
        self.group = group
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.navigationItem.title = "群公告"
        self.view.addSubview(listView)
        listView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        self.loadMore()
        
        if group.isMaster || group.isManager {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "tool_more"), style: .plain, target: self, action: #selector(addBtnClick))
        }
    }
    
    @objc func addBtnClick() {
        let vc = FZMReleaseNotifyVC(with: group)
        vc.releaseBlock = {[weak self] in
            self?.group.notifyNum += 1
            self?.refreshView()
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func refreshView() {
        self.notifyList.removeAll()
        self.listView.reloadData()
        self.startId = nil
        self.loadMore()
    }
    
    private func loadMore() {
        HttpConnect.shared().groupGetNotifyList(groupId: group.groupId, startId: self.startId) { (list, nextId, response) in
            self.listView.mj_footer.endRefreshing()
            guard response.success else {
                self.showToast(with: response.message)
                return
            }
            self.notifyList += list
            if self.startId == nil, let model = list.first {
                self.group.notifyList.insert(model, at: 0)
            }
            self.listView.reloadData()
            self.startId = nextId
            if let next = Int(nextId), next > 0 {
                self.listView.mj_footer.isHidden = false
            }else {
                self.listView.mj_footer.isHidden = true
            }
        }
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension FZMGroupNotifyListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifyList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FZMGroupNotifyCell", for: indexPath) as! FZMGroupNotifyCell
        let model = notifyList[indexPath.row]
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if group.isManager || group.isMaster {
            return .delete
        }
        return .none
    }
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "删除"
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let model = notifyList[indexPath.row]
            self.showProgress()
            IMConversationManager.shared().revokeMessage(msgId: model.msgId, channelType: .group) { (response) in
                self.hideProgress()
                guard response.success else {
                    self.showToast(with: response.message)
                    return
                }
                self.notifyList.remove(at: model)
                tableView.deleteRows(at: [indexPath], with: .fade)
                self.group.notifyNum -= 1
                self.group.notifyList = self.notifyList
            }
        }
    }
}
