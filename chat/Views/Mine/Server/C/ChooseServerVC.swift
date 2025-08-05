//
//  ChooseServerVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/27.
//

import UIKit
import SnapKit
import RxSwift

class ChooseServerVC: UIViewController, ViewControllerProtocol {
    
    var groupServer: Server?// 群聊点击添加聊天服务器
    
    var chatServerBlcok: (([(title: String, value: [Server])])->())?
    
    private lazy var chatServerData: [(title: String, value: [Server])] = [] {
        didSet {
            self.chatServerListVC.dataSource = chatServerData
            self.setAlreadyOfficialChatServers()
            self.chatServerBlcok?(chatServerData)
        }
    }
    
    private lazy var chainServerData: [(title: String, value: [Server])] = [] {
        didSet {
            self.chainServerListVC.dataSource = chainServerData
            self.setAlreadySelectedChainServer()
        }
    }
    
    private lazy var chatServerListVC: ServerListVC = {
        let vc = ServerListVC.init()
        vc.title = "聊天服务器"
        vc.listType = .chatServer
        
        if !LoginUser.shared().isLogin {
            vc.headerView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 100)
            vc.headerLab.text = "1.新用户需选择或添加一台服务器为默认服务器，用于接收好友聊天消息； \n2.若为已注册账户，原默认服务器不变，可前往[我的]-[服务器]页面切换。"
        } else {
            vc.isHiddenSelectedImgView = true
        }
        
        vc.refreshChatServers = {[weak self] (servers) in
            guard let strongSelf = self else { return }
            strongSelf.chatServerData = servers
        }
        
        vc.selectedBlock = {[weak self] (indexPath) in
            guard let strongSelf = self else { return }
            guard indexPath.section < strongSelf.chatServerData.count,
                  indexPath.row < strongSelf.chatServerData[indexPath.section].value.count else { return }
            
            let server = strongSelf.chatServerData[indexPath.section].value[indexPath.row]
            FZMLog("选择\(server)")
            
            if !LoginUser.shared().isLogin {
                IMChatServerInUse = server
            }
//            else {
//                // 进入编辑服务器页面
//                strongSelf.setChatServer(type: .edit(server))
//            }
        }
        
        // 进入编辑服务器页面
        vc.moreTapBlock = {[weak self] (indexPath) in
            FZMLog("more\(indexPath)")
            guard let strongSelf = self else { return }
            guard indexPath.section < strongSelf.chatServerData.count,
                  indexPath.row < strongSelf.chatServerData[indexPath.section].value.count else { return }
            if !LoginUser.shared().isLogin && indexPath.section == 0 {
                return
            }
            let server = strongSelf.chatServerData[indexPath.section].value[indexPath.row]
            strongSelf.setChatServer(type: .edit(server))
        }
        return vc
    }()
    
    private lazy var chainServerListVC: ServerListVC = {
        let vc = ServerListVC.init()
        vc.title = "区块链节点"
        vc.listType = .chainServer
        if !LoginUser.shared().isLogin {
            vc.headerView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 82)
            vc.headerLab.text = "1.需选择或添加一台服务器为默认区块链节点，用于上传和获取账户信息。\n2.可前往[我的]-[服务器]页面切换。"
        }
        vc.selectedBlock = {[weak self] (indexPath) in
            guard let self = self else { return }
            guard indexPath.section < self.chainServerData.count,
                  indexPath.row < self.chainServerData[indexPath.section].value.count else { return }
            let server = self.chainServerData[indexPath.section].value[indexPath.row]
            FZMLog("选择\(server)")
            self.setBlockchainServer(server)
        }
        vc.moreTapBlock = {[weak self] (indexPath) in
            FZMLog("more\(indexPath)")
            guard let self = self, indexPath.section >= 1 else { return }
            guard indexPath.section < self.chainServerData.count,
                  indexPath.row < self.chainServerData[indexPath.section].value.count else { return }
            let server = self.chainServerData[indexPath.section].value[indexPath.row]
            
            // 判断是否是团队区块链节点，团队的节点不可编辑
            if let teaminfo = LoginUser.shared().myCompanyInfo, teaminfo.id == server.id {
                self.showToast("团队区块链节点不可编辑！")
                return
            }
            
            self.setChainServer(type: .edit(server))
        }
        return vc
    }()
    
    private lazy var pagingVC: PagingVC = {
        return PagingVC.init(vcs: [chatServerListVC, chainServerListVC])
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "选择服务器"
        
        self.setBgColor()
        self.setupViews()
        
        self.loadData()
        self.getOfficialServerRequest()
        
        // 添加群聊聊天服务器
        if let server = groupServer {
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.leftBtnTitle = "取消"
            alert.rightBtnTitle = "确定"
            let str = "是否去添加 \(server.value) 聊天服务器?"
            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
            attStr.addAttributes([NSAttributedString.Key.foregroundColor: Color_Theme], range:(str as NSString).range(of: server.value as String))
            alert.attributedInfo = attStr
            alert.leftBtnTouchBlock = {}
            alert.rightBtnTouchBlock = {
                self.setChatServer(type: .add(server))
            }
            alert.show()
        }
    }
    
    private func setBgColor() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8
    }
    
    private func setupViews() {
        
        let addBtn = UIBarButtonItem(image: UIImage.init(named: "icon_add")?.withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(addServerBtnClick))
        addBtn.tintColor = Color_24374E
        self.navigationItem.rightBarButtonItem = addBtn
        
        self.addChild(self.pagingVC)
        self.view.addSubview(self.pagingVC.view)
        self.pagingVC.view.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(10)
            m.left.right.bottom.equalToSuperview()
        }
    }
    
    private func loadData() {
        
        if LoginUser.shared().isLogin {// 登录数据源
            let loginChatServer = LoginUser.shared().chatServerGroups.compactMap {
                Server.init(name: $0.name, value: $0.value, id: $0.id)
            }
            let loginChatData = [("接收聊天消息的服务器", loginChatServer)]
            self.chatServerData = loginChatData
        } else {// 未登录数据源
            var chatData = [("官方提供接收聊天消息的服务器", OfficialChatServers ?? [Server]())]
            if let myChatServer = UserDefaultsDB.chatServerList, !myChatServer.isEmpty {
                chatData.append(("自己添加的服务器", myChatServer))
            }
            self.chatServerData = chatData
        }
        
        self.chatServerListVC.reloadTableviewData()
        
        self.setChainServerData()
    }
    
    // 获取官方IMServer和区块链节点
    private func getOfficialServerRequest() {
        guard OfficialChatServers == nil || OfficialBlockchainServers == nil else {
            return
        }
        self.view.showActivity()
        APP.shared().getOfficialServerRequest { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.loadData()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideActivity()
            strongSelf.view.show(error)
        }
    }
    
    private func setChainServerData() {
        var chainData = [("官方提供上传/获取账户信息的区块链节点", OfficialBlockchainServers ?? [Server]())]
        if let myChainServer = UserDefaultsDB.chainServerList, !myChainServer.isEmpty {
            chainData.append(("自己添加的区块链节点", myChainServer))
        }
        if let teamBlockhainServer = TeamBlockchainServer, let teamName = LoginUser.shared().myCompanyInfo?.name {
            chainData.append(("\(teamName)的区块链节点", [teamBlockhainServer]))
        }
        self.chainServerData = chainData
    }
    
    private func setAlreadyOfficialChatServers() {
        guard !self.chatServerListVC.isHiddenSelectedImgView else { return }
        self.chatServerData.enumerated().makeIterator().forEach { (item) in
            item.element.value.enumerated().makeIterator().forEach { (valueItem) in
                if (valueItem.element.id == IMChatServerInUse?.id) {
                    let indexPath = IndexPath.init(row: valueItem.offset, section: item.offset)
                    self.chatServerListVC.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
    // 设置当前使用的区块链节点
    private func setBlockchainServer(_ server: Server) {
        // 设置当前使用的区块链节点
        BlockchainServerInUse = server
        // 刷新列表显示当前选择区块链节点
        self.setAlreadySelectedChainServer()
    }
    
    // 刷新列表显示当前选择区块链节点
    private func setAlreadySelectedChainServer() {
        guard !self.chainServerListVC.isHiddenSelectedImgView else { return }
        self.chainServerData.enumerated().makeIterator().forEach { (item) in
            item.element.value.enumerated().makeIterator().forEach { (valueItem) in
                if (valueItem.element.id == BlockchainServerInUse?.id) {
                    let indexPath = IndexPath.init(row: valueItem.offset, section: item.offset)
                    self.chainServerListVC.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
    @objc private func addServerBtnClick() {
        let view = FZMMenuView(with: [FZMMenuItem(title: "添加聊天服务器", block: {
            self.setChatServer(type: .addNewIMServer)
        }),FZMMenuItem(title: "添加区块链节点",  block: {
            self.setChainServer(type: .addNewBlockchain)
        })])
        view.show(in: CGPoint(x: k_ScreenWidth-15, y: k_StatusNavigationBarHeight))
    }
    
    private func setChatServer(type: SetServerVC.SetType) {
        let vc = SetServerVC.init(type: type)
        vc.dataSource = OfficialChatServers ?? [Server]() + (UserDefaultsDB.chatServerList ?? [Server]())
        self.navigationController?.pushViewController(vc)
        vc.saveBlock = {[weak self] (server) in
            guard let strongSelf = self else { return }
            
            FZMLog(server)
            
            if LoginUser.shared().isLogin {
                strongSelf.view.showActivity()
                var alreadyAddChatServer = strongSelf.chatServerData.first?.value ?? []
                if let index = alreadyAddChatServer.enumerated().filter({ $0.element.id == server.id }).first?.offset {
                    // is edit
                    alreadyAddChatServer.remove(at: index)
                    LoginUser.shared().updateServerGroup(server: server) { [weak self] (_) in
                        guard let strongSelf = self else { return }
                        strongSelf.view.hideActivity()
                        strongSelf.showToast("修改服务器分组中，请耐心等待，稍后查看结果...")
                        let newServers = alreadyAddChatServer + [server]
                        strongSelf.chatServerData = [("接收聊天消息的服务器", newServers)]
                    } failureBlock: { [weak self] (error) in
                        guard let strongSelf = self else { return }
                        strongSelf.view.hideActivity()
                        strongSelf.view.show(error)
                    }
                } else {
                    // is add
                    LoginUser.shared().addServerGroup(server: UserChatServerGroup.init(id: "0", name: server.name, value: server.value)) { [weak self] (_) in
                        guard let strongSelf = self else { return }
                        strongSelf.view.hideActivity()
                        strongSelf.showToast("添加服务器分组成功，请耐心等待，稍后查看结果...")
                        let newServers = alreadyAddChatServer + [server]
                        strongSelf.chatServerData = [("接收聊天消息的服务器", newServers)]
                    } failureBlock: { [weak self] (error) in
                        guard let strongSelf = self else { return }
                        strongSelf.view.hideActivity()
                        strongSelf.view.show(error)
                    }
                }
            } else {
                
                // 不等接口返回直接保存本地？？
                var chatServerList = UserDefaultsDB.chatServerList ?? [Server]()
                chatServerList.append(server)
                UserDefaultsDB.chatServerList = chatServerList
                
                var chatServerData = strongSelf.chatServerData
                var alreadyAddChatServer = chatServerData.count > 1 ? (chatServerData.last?.value ?? []) : []
                if let index = alreadyAddChatServer.enumerated().filter({ $0.element.id == server.id }).first?.offset {
                    // is edit
                    alreadyAddChatServer.remove(at: index)
                }
                let newServers = alreadyAddChatServer + [server]
                if chatServerData.count > 1 {
                    chatServerData.removeLast()
                }
                chatServerData.append(contentsOf: [("自己添加的服务器", newServers)])
                strongSelf.chatServerData = chatServerData
            }
        }
        
        vc.deleteBlock = {[weak self] (server) in
            guard let self = self else { return }
            if LoginUser.shared().isLogin {
                guard var chatServerList = self.chatServerData.first?.value else {
                    return
                }
                guard chatServerList.count > 1 else {
                    self.showToast("必须保留一个聊天服务器")
                    return
                }
                guard let index = chatServerList.enumerated().filter({ $0.element.id == server.id }).first?.offset else { return }
                self.view.showActivity()
                LoginUser.shared().deleteServerGroup(server: server) { (json) in
                    self.view.hideActivity()
                    self.showToast("删除服务器分组成功，请耐心等待，稍后查看结果...")
                    chatServerList.remove(at: index)
                    self.chatServerData = [("接收聊天消息的服务器", chatServerList)]
                } failureBlock: { (error) in
                    self.view.hideActivity()
                    self.view.show(error)
                }
            } else {
                var chatServerList = UserDefaultsDB.chatServerList ?? [Server]()
                guard let index = chatServerList.enumerated().filter({ $0.element.id == server.id }).first?.offset else { return }
                chatServerList.remove(at: index)
                UserDefaultsDB.chatServerList = chatServerList
                var chatServerData = self.chatServerData
                guard chatServerData.count > 1 else { return }
                chatServerData.removeLast()
                if !chatServerList.isEmpty {
                    chatServerData.append(("自己添加的服务器", chatServerList))
                }
                self.chatServerData = chatServerData
            }
        }
    }
    
    private func setChainServer(type: SetServerVC.SetType) {
        let vc = SetServerVC.init(type: type)
        self.navigationController?.pushViewController(vc)
        vc.saveBlock = {[weak self] (server) in
            guard let strongSelf = self else { return }
            var chainServerList = UserDefaultsDB.chainServerList ?? []
            
            if let index = chainServerList.enumerated().filter({ $0.element.id == server.id }).first?.offset {
                // is edit
                chainServerList.remove(at: index)
                
                if server.id == BlockchainServerInUse?.id {
                    //edit server is current selected server
                    // 设置当前使用的区块链节点
                    strongSelf.setBlockchainServer(server)
                }
            }
            
            chainServerList.append(server)
            UserDefaultsDB.chainServerList = chainServerList
            
            strongSelf.setChainServerData()
        }
        vc.deleteBlock = {[weak self] (server) in
            guard let self = self else { return }
            var chainServerList = UserDefaultsDB.chainServerList ?? []
            
            guard let index = chainServerList.enumerated().filter({ $0.element.id == server.id }).first?.offset else { return }
            
            if server.id == BlockchainServerInUse?.id,
               let server = self.chainServerData.first?.value.first {
                //delete server is current selected server
                // 设置当前使用的区块链节点
                self.setBlockchainServer(server)
            }
            
            chainServerList.remove(at: index)
            UserDefaultsDB.chainServerList = chainServerList
            
            var chainServerData = self.chainServerData
            guard chainServerData.count > 1 else { return }
            chainServerData.removeLast()
            if !chainServerList.isEmpty {
                chainServerData.append(("自己添加的区块链节点", chainServerList))
            }
            self.chainServerData = chainServerData
        }
    }
}
