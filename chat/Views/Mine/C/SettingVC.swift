//
//  SettingVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/15.
//

import UIKit
import SnapKit
import SwifterSwift

class SettingVC: UIViewController, ViewControllerProtocol {
    
    private lazy var headerView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth - 30, height: 15))
        view.backgroundColor = Color_F6F7F8
        return view
    }()
    
    private lazy var listview: UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.separatorStyle = .none
        view.estimatedRowHeight = 50
//        view.estimatedSectionHeaderHeight = 15
        view.register(SettingTextCell.self, forCellReuseIdentifier: "SettingTextCell")
        view.register(SettingSwitchCell.self, forCellReuseIdentifier: "SettingSwitchCell")
        view.tableHeaderView = headerView
        
        return view
    }()
    
    private lazy var offlineNoti: SettingSwitchCellModel = {
        let model = SettingSwitchCellModel.init()
        model.leftString = "离线通知"
        model.isShowLine = true
        model.switchChangeBlock = { [weak self] isSwitchOn in
            self?.offlineNotiChanged(isOn: isSwitchOn)
        }
        
        return model
    }()
    
    private lazy var muteNoti: SettingSwitchCellModel = {
        let model = SettingSwitchCellModel.init()
        model.leftString = "勿扰模式"
        model.switchChangeBlock = { [weak self] isSwitchOn in
            self?.muteNotiChanged(isOn: isSwitchOn)
        }
        
        return model
    }()
    
    private lazy var dataSource: [[SettingCellModel]] = {
//        let arr = [[offlineNoti, muteNoti]]
        let arr = [[offlineNoti]]
        return arr
    }()
    
    private var unRegisterRemoteNotifi = false// 关闭消息推送
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "设置中心"
        
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
//        self.xls_isNavigationBarHidden = false
        
        self.view.addSubview(self.listview)
        listview.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        // 读取本地存储的友盟推送关闭flg
        let flg = FZM_UserDefaults.bool(forKey: CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY)
        if flg {
            self.unRegisterRemoteNotifi = true
        } else {
            self.unRegisterRemoteNotifi = false
        }
        
        self.offlineNoti.isSwitchOn = !self.unRegisterRemoteNotifi
        
        listview.reloadData()
    }
    
    private func offlineNotiChanged( isOn: Bool ) {
        if isOn {
            self.showToast("离线通知开启")
            AppDelegate.shared().umRegisterForRemoteNotifi()
            self.unRegisterRemoteNotifi = false
        } else {
            self.showToast("离线通知关闭")
            AppDelegate.shared().umUnregisterForRemoteNotifi()
            self.unRegisterRemoteNotifi = true
        }
        FZM_UserDefaults.set(self.unRegisterRemoteNotifi, forKey: CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY)
    }
    
    private func muteNotiChanged( isOn: Bool) {
        if isOn {
            self.showToast("勿扰模式开启")
        } else {
            self.showToast("勿扰模式关闭")
        }
    }
}

extension SettingVC: UITableViewDelegate, UITableViewDataSource {
//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 15))
////        view.backgroundColor = self.listview.backgroundColor
//        view.backgroundColor = UIColor.red
//
//        return view
//    }
//
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return section == 0 ? 15 : 0
//    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 50 : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let isSwitchCell = indexPath.section == 0 ? true : false
        
        var cell = UITableViewCell.init()
        
        guard dataSource.count > indexPath.section else {
            return cell
        }
        let sectionData = dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else {
            return cell
        }
        let model = sectionData[indexPath.row]
        
        if isSwitchCell {
            let switchCell = tableView.dequeueReusableCell(withClass: SettingSwitchCell.self, for: indexPath)
            guard let model = model as? SettingSwitchCellModel else {
                return switchCell
            }
            switchCell.configure(with: model)
            
            cell = switchCell
        } else {
            let textCell = tableView.dequeueReusableCell(withClass: SettingTextCell.self, for: indexPath)
            guard let model = model as? SettingTextCellModel else {
                return textCell
            }
            textCell.configure(with: model)
            
            cell = textCell
        }
        
        if indexPath.section == 0 && indexPath.row == 0 {
            DispatchQueue.main.async {
                cell.roundCorners([.topLeft, .topRight], radius: 5)
            }
        }
        if indexPath.section == 0 && indexPath.row == 1 {
            DispatchQueue.main.async {
                cell.roundCorners([.bottomLeft, .bottomRight], radius: 5)
            }
        }
        
        return cell
    }
}
