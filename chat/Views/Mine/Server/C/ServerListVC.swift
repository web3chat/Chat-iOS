//
//  ServerListVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/27.
//

import UIKit
import SnapKit
import MJRefresh
import Starscream
import SwifterSwift

enum ServerListType {
    case chatServer
    case chainServer
}

class ServerListVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private var disposeBag: DisposeBag?
    
    private var pingManager: PingManager?
    
    private var chatServerRefreshSuccessFlg = false
    
    var dataSource: [(title: String, value: [Server])] = [] {
        didSet {
            // 获取聊天服务器状态
            self.bindConnectStatusData()
            
            // 判断 数据源 是否包含 本地保存的当前正在使用的服务器
            self.judgeDataSourceIsIncludeInUse()
            
            self.tableView.reloadData()
        }
    }
    
    // 判断 数据源 是否包含 本地保存的当前正在使用的服务器，不包含则设置第一条数据为当前使用的服务器
    private func judgeDataSourceIsIncludeInUse() {
        guard !LoginUser.shared().isLogin else {
            return
        }
        var serverIdInUse: String?
        var isContainsInUseServer = false// 当前数据源是否包含之前选择的服务器
        if self.listType == .chainServer {// 本地保存的节点
            if BlockchainServerInUse == nil {
                if let server = self.dataSource.first?.value.first {
                    BlockchainServerInUse = server
                }
                return
            } else {
                serverIdInUse = BlockchainServerInUse?.id
            }
        } else {
            if IMChatServerInUse == nil {
                if let server = self.dataSource.first?.value.first {
                    IMChatServerInUse = server
                }
                return
            } else {
                serverIdInUse = IMChatServerInUse?.id
            }
        }
        
        self.dataSource.forEach { (item) in
            let servers = item.value
            servers.forEach { (server) in
                if server.id == serverIdInUse {
                    isContainsInUseServer = true
                    return
                }
            }
            if isContainsInUseServer {
                return
            }
        }
        
        if !isContainsInUseServer {
            if self.listType == .chainServer {
                BlockchainServerInUse = self.dataSource.first?.value.first
            } else {
                IMChatServerInUse = self.dataSource.first?.value.first
            }
        }
    }
    
    private var hasShowSelectedServerId = ""// 已显示勾选的ServerId
    
    // 当前选择的服务器index
    private var curSelectedIndexPath: IndexPath?
    
    var listType: ServerListType = .chatServer
    
    var iscreateGroup = false // 创建群聊进入 选择服务器后再选择好友进群
    
    var showManageBtnFlg = false// 是否显示右上角管理flg（好友详情页选择服务器进入）
    
    private var serverDataSource = [(url: URL, status: Bool)]()// 聊天服务器连接状态存储
    
    var isHiddenSelectedImgView: Bool = false
    
    var selectedBlock: ((IndexPath)->())?
    
    var moreTapBlock: ((IndexPath)->())?
    
    var refreshChatServers: (([(title: String, value: [Server])])->())?
    
    var pingResultBlock: BoolBlock?
    
    var pingDataSource: [String]?
    
    var pingCount = 0
    
    lazy var  headerLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_Theme, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    lazy var headerView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 0, height: 0))
        
        let bgv = UIView.init()
        bgv.backgroundColor = Color_Auxiliary
        bgv.layer.cornerRadius = 5
        bgv.clipsToBounds = true
        v.addSubview(bgv)
        bgv.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.bottom.equalToSuperview().offset(-5)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        bgv.addSubview(headerLab)
        headerLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(10)
            m.bottom.equalToSuperview().offset(-10)
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
        }
        return v
    }()
    
    lazy var tableView: UITableView = {
        let v = UITableView.init(frame: .zero, style: .plain)
        v.register(nibWithCellClass: ServerListCell.self)
        v.backgroundColor = Color_F6F7F8
        v.contentInsetAdjustmentBehavior = .never
        v.separatorStyle = .none
        v.delegate = self
        v.dataSource = self
        v.keyboardDismissMode = .onDrag
        v.rowHeight = 95
        v.showsVerticalScrollIndicator = false
        v.tableHeaderView = self.headerView
        v.mj_header = MJRefreshNormalHeader.init(refreshingBlock: {[weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.listType == .chatServer {
                strongSelf.getMyChatServerListRequest()
            } else {
                strongSelf.refreshBlockchainStatus()
            }
        })
        return v
    }()
            
    init() {
        super.init(nibName: nil, bundle: nil)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setBgColor()
        self.setupViews()
        
        // 网络连接状态监听
        APP.shared().hasNetworkSubject.subscribe(onNext: { [weak self] (hasNetwork) in
            guard let strongSelf = self else { return }
            
            if strongSelf.listType == .chatServer {
                if hasNetwork {
                    if strongSelf.chatServerRefreshSuccessFlg {
                        return
                    }
                    // 获取我的聊天服务器地址列表请求
                    strongSelf.getMyChatServerListRequest()
                } else {
                    var tempData = [(url: URL, status: Bool)]()
                    strongSelf.serverDataSource.forEach { (url, status) in
                        tempData += [(url, false)]
                    }
                    strongSelf.serverDataSource = tempData
                    strongSelf.reloadTableviewData()
                }
            } else {
                // 测试服需要开VPN，网络状态变化（联网）后马上去ping会失败，正式服应该不会
//                if hasNetwork {
//                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
//                        strongSelf.refreshBlockchainStatus()
//                    }
//                } else {
                    strongSelf.refreshBlockchainStatus()
//                }
            }
        }).disposed(by: bag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNavBackgroundColor()
        
        if LoginUser.shared().isLogin && listType == .chatServer && !chatServerRefreshSuccessFlg {
            self.tableView.mj_header?.beginRefreshing()
        }
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
    
    private func setBgColor() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8
    }
    
    func setupViews() {
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(8)
            m.left.right.bottom.equalToSuperview()
        }
        
        if showManageBtnFlg {
            let manageBtn = UIBarButtonItem.init(title: "管理", style: .plain, target: self, action: #selector(manageBtnClickAction))
            manageBtn.tintColor = Color_Theme
            self.navigationItem.rightBarButtonItem = manageBtn
        }
    }
    
    // 刷新区块链节点连接状态
    private func refreshBlockchainStatus() {
        startPingAction()
    }
    
    // 获取我的聊天服务器地址列表请求
    private func getMyChatServerListRequest() {
        guard LoginUser.shared().isLogin else {
            if self.tableView.mj_header?.isRefreshing == true {
                self.tableView.mj_header?.endRefreshing()
            }
            
            // 刷新服务器连接状态
            self.startPingAction()
            return
        }
        self.showProgress()
        
        LoginUser.shared().getMyServerGroup { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.chatServerRefreshSuccessFlg = true
            if strongSelf.tableView.mj_header?.isRefreshing == true {
                strongSelf.tableView.mj_header?.endRefreshing()
            }
            let chatServerGroups = LoginUser.shared().chatServerGroups
            let servers = chatServerGroups.compactMap {
                Server.init(userchatServerGroup: $0)
            }
            strongSelf.dataSource = [("接收聊天消息的服务器", servers)]
            strongSelf.refreshChatServers?(strongSelf.dataSource)
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            if strongSelf.tableView.mj_header?.isRefreshing == true {
                strongSelf.tableView.mj_header?.endRefreshing()
            }
            strongSelf.view.show(error)
        }
    }
    
    /// 跳转到服务器编辑页面
    @objc private func manageBtnClickAction() {
        let vc = ChooseServerVC.init()
        vc.chatServerBlcok = { [weak self] chatServerData in
            // 更新页面数据
            self?.dataSource = chatServerData
            
        }
        self.navigationController?.pushViewController(vc)
    }
    
    func reloadTableviewData() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // 获取聊天服务器状态
    private func bindConnectStatusData() {
        if LoginUser.shared().isLogin {// IMServer登录时获取websocket连接状态
            if self.listType == .chatServer {
                if let alreadyAddURL = MultipleSocketManager.shared().getAllSocketConnectStatus() {
                    self.serverDataSource = alreadyAddURL
                }
                
                self.disposeBag = nil
                self.disposeBag = DisposeBag.init()
                
                MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
                    guard let strongSelf = self else { return }
                    guard case .next((let url, let isAvailable)) = event else { return }
                    for i in 0..<strongSelf.serverDataSource.count {
                        if strongSelf.serverDataSource[i].url == url && strongSelf.serverDataSource[i].status != isAvailable {
                            strongSelf.serverDataSource[i].status = isAvailable
                        }
                    }
                    
                    if strongSelf.dataSource.count > 0 {
                        strongSelf.reloadTableviewData()
                    }
                }.disposed(by: self.disposeBag!)
            } else {
                // 节点连接状态使用ping获取
                self.startPingAction()
            }
        } else {
            self.startPingAction()
        }
    }
    
    // 节点连接状态和未登录时的IMServer用ping来获取服务器状态
    private func startPingAction() {
        guard self.dataSource.count > 0, APP.shared().hasNetwork else {
            if self.tableView.mj_header?.isRefreshing == true {
                self.tableView.mj_header?.endRefreshing()
            }
            serverDataSource.removeAll()
            reloadTableviewData()
            return
        }
        self.dataSource.forEach { (item) in
            let servers = item.value
            servers.forEach { (server) in
                let url = server.value
                if let arr = pingDataSource, !arr.contains(url) {
                    pingDataSource?.append(url)
                } else {
                    pingDataSource = [url]
                }
            }
        }
        
        pingCount = 0
        pingAction()
    }
    
    // ping服务器是否可用
    private func pingAction() {
        guard let ipArray = self.pingDataSource, ipArray.count > 0, pingCount < ipArray.count else {
            // ping任务结束
            pingCount = 0
            
            if listType == .chainServer {
                if self.tableView.mj_header?.isRefreshing == true {
                    self.tableView.mj_header?.endRefreshing()
                }
            }
            return
        }
        let ip = ipArray[pingCount].shortUrlStr
        
//        if pingManager == nil {
        pingManager = PingManager.init()
//        }
        
        let ping = Ping()
        ping.delegate = self
        ping.host = ip
        pingManager?.add(ping)
        pingManager?.setup {
            $0.timeout = 1
            $0.pingPeriod = 1
            $0.startPing()
        }
    }
}

extension ServerListVC: PingDelegate {
    func stop(_ ping: Ping) {
        
    }
    func ping(_ pinger: Ping, didFailWithError error: Error) {
        
    }
    func ping(_ pinger: Ping, didTimeoutWith result: PingResult) {
        pingResult(result)
    }
    func ping(_ pinger: Ping, didReceiveReplyWith result: PingResult) {
        pingResult(result)
    }
    func ping(_ pinger: Ping, didReceiveUnexpectedReplyWith result: PingResult) {
        pingResult(result)
    }
    func pingResult(_ result:PingResult){
        let resultFlg = result.pingStatus == .success ? true : false
        pingManager?.stopPing()
        guard let ipArr = pingDataSource, pingCount < ipArr.count else {
            FZMLog("ping guard return")
            return
        }
        
        let url = MultipleSocketManager.shared().transformUrl(ipArr[pingCount])
        self.serverDataSource = self.serverDataSource.filter({ $0.url != url })
        
        if resultFlg {
            FZMLog("Host:\(result.host ?? "") ttl:\(result.ttl) time:\(Int(result.time * 1000))")
            let pingResult = [(url, resultFlg)]
            
            self.serverDataSource += pingResult
        } else {
            FZMLog("Host:\(result.host ?? "") failed")
        }
        
        reloadTableviewData()
        
        pingCount += 1
        pingAction()
    }
}

extension ServerListVC: UITableViewDelegate, UITableViewDataSource {
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].value.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 35
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = self.dataSource[section].title
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 35))
        v.backgroundColor = Color_F6F7F8
        let lab = UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: title)
        lab.frame = CGRect.init(x: 15, y: 0, width: k_ScreenWidth - 30, height: 35)
        v.addSubview(lab)
        return v
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: ServerListCell.self)
        
        guard dataSource.count > indexPath.section else {
            return cell
        }
        let sectionData = dataSource[indexPath.section].value
        guard sectionData.count > indexPath.row else {
            return cell
        }
        let model = sectionData[indexPath.row]
        cell.isHiddenSelectedImgView = self.isHiddenSelectedImgView
        let isConnected = self.isConnectServer(model)
//        FZMLog("isConnected \(isConnected)")
        cell.isConnected = isConnected
        cell.configure(data: model)
        
        var isSelected = false
        
        // 设置选中按钮
        if self.listType == .chainServer {// 节点列表
            if model.id == BlockchainServerInUse?.id, hasShowSelectedServerId.isBlank || hasShowSelectedServerId == model.id {
                isSelected = true
                hasShowSelectedServerId = model.id
                curSelectedIndexPath = indexPath
            }
        } else {// IMServer列表
            if hasShowSelectedServerId == model.id {
                isSelected = true
            } else if !LoginUser.shared().isLogin, model.id == IMChatServerInUse?.id, hasShowSelectedServerId != model.id {
                isSelected = true
                hasShowSelectedServerId = model.id
                curSelectedIndexPath = indexPath
            }
        }
        cell.selectedImgView.isHighlighted = isSelected
        
        var hiddenFlg = false
        // 官方默认区块链和团队区块链节点不可编辑
        if indexPath.section == 0, indexPath.row == 0 {
            hiddenFlg = true
        } else if self.listType == .chainServer, let teaminfo = LoginUser.shared().myCompanyInfo, teaminfo.id == model.id {
            hiddenFlg = true
        } else if self.listType == .chatServer, model.id == TeamIMChatServer?.id, model.value == TeamIMChatServer?.value {
            hiddenFlg = true
        }
        cell.moreImageView.isHidden = hiddenFlg
        cell.moreImageViewTapBlock = {[weak self] in
            self?.moreTapBlock?(indexPath)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard dataSource.count > indexPath.section else {
            return
        }
        let sectionData = dataSource[indexPath.section].value
        guard sectionData.count > indexPath.row else {
            return
        }
        let server = sectionData[indexPath.row]
        hasShowSelectedServerId = server.id
        
        if iscreateGroup {
            // 创建群聊-选择完群聊服务器
            if LoginUser.shared().isInTeam {
                // 跳转到选择好友/组织架构入口页面
                FZMUIMediator.shared().pushVC(.goChooseMemberSourceVC(type: .createGroup, server: server, completeBlock: nil))
            } else {
                // 跳转到选择好友列表页面
                FZMUIMediator.shared().pushVC(.selectFriend(type: .allFriend, chatServerUrl: server.value, completeBlock: nil))
            }
        } else {
            self.selectedBlock?(indexPath)
            
            // 设置选中按钮
            if let curIndex = curSelectedIndexPath, indexPath != curIndex {
                if self.listType == .chainServer {
                    let cell = self.tableView.cellForRow(at: curIndex) as! ServerListCell
                    cell.selectedImgView.isHighlighted = false
                    
                    let curCell = self.tableView.cellForRow(at: indexPath) as! ServerListCell
                    curCell.selectedImgView.isHighlighted = true
                    
                    curSelectedIndexPath = indexPath
                } else {
                    if !LoginUser.shared().isLogin {
                        let cell = self.tableView.cellForRow(at: curIndex) as! ServerListCell
                        cell.selectedImgView.isHighlighted = false
                        
                        let curCell = self.tableView.cellForRow(at: indexPath) as! ServerListCell
                        curCell.selectedImgView.isHighlighted = true
                        
                        curSelectedIndexPath = indexPath
                    }
                }
            }
        }
    }
    
    // 遍历所有存储的服务器数据，返回开启连接的服务器连接状态
    func isConnectServer(_ model: Server) -> Bool {
        if self.serverDataSource.count > 0 {
            for i in 0..<self.serverDataSource.count {
                if MultipleSocketManager.shared().transformUrl(model.value) == self.serverDataSource[i].url {
                    return self.serverDataSource[i].status
                }
            }
        }
        
        return false
    }
}
