//
//  FZMFileListView.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/21.
//

import Foundation
import RxSwift
import MJRefresh
import SnapKit
import MediaPlayer

class FZMFileListView: FZMScrollPageItemBaseView {
    
    private let disposeBag = DisposeBag()
    var isSelect = false
    var selectBlock: ((FZMMessageBaseVM, FZMFileListCell)->())?
    var senderLabBlock: ((FZMMessageBaseVM)->())?
    var searchText = "" {//wjhTODO 搜索未完成
        didSet {
            self.startId = ""
//            self.fileMessagArr.removeAll()
            self.fileListVMArr.removeAll()
            self.loadData()
        }
    }
//    private var curTapMsg: Message?// 当前点击的message
//    private var curTapCell: FZMFileListCell?// 当前点击的message
    private var startId = ""
    private let session: Session
    
//    var fileMessagArr = [Message]()
    var fileListVMArr = [FZMMessageBaseVM]() {
        didSet {
            self.refresh()
            
            DispatchQueue.main.async {
                self.noDataCover.isHidden = !self.fileListVMArr.isEmpty
            }
        }
    }
    
    private var chatServerUrl: String = ""// 群详情页传入群聊服务器地址
    
    private lazy var tableView: UITableView = {
        let v = UITableView.init(frame: CGRect.zero, style: .plain)
        v.keyboardDismissMode = .onDrag
        v.backgroundColor = .white
        v.rowHeight = 80
        v.register(FZMFileListCell.self, forCellReuseIdentifier: "FZMFileListCell")
        v.separatorColor = Color_F1F4F6
        v.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: {[weak self] in
            self?.loadData(more: true)
        })
        v.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat(k_SafeBottomInset)))
        if #available(iOS 11.0, *) {
            v.contentInsetAdjustmentBehavior = .never
        }
        v.delegate = self
        v.dataSource = self
        v.addSubview(noDataCover)
        noDataCover.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview().offset(-k_StatusNavigationBarHeight - 20)
            m.centerX.equalToSuperview()
        })
        return v
    }()
    lazy var noDataCover: UIImageView = {
        let v = UIImageView()
        v.image = #imageLiteral(resourceName: "nodata_search_file")
        v.contentMode = .scaleAspectFit
        v.isHidden = true
        let lab = UILabel.getLab(font: UIFont.mediumFont(14), textColor: Color_8A97A5, textAlignment: .center, text: "暂无文件")
        v.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(v.snp.bottom).offset(20)
        })
        return v
    }()
    
    init(with pageTitle: String, session: Session) {
        self.session = session
        super.init(with: pageTitle)
        self.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        if let info = GroupManager.shared().getDBGroup(by: session.id.idValue.intEncoded), let serverUrl = info.chatServerUrl {
            self.chatServerUrl = serverUrl
        }
        
        self.loadData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refresh() {
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.tableView.reloadData()
            }
        }
    }
    
    func edgeInset(_ edge: Bool) {
        self.tableView.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: edge ? 70 : 0 , right: 0)
    }
    
    // 从数据库获取消息数据
    private func getHistoryFileMsgs(from msgId: String, count: Int = 20, searchString: String? = nil) -> [Message] {
        if let searchString = searchString, !searchString.isBlank {
            let msgInDB = ChatManager.shared().searchSpecifiedMsg(searchString: searchString, sessionId: self.session.id.idValue, typeArr: [5])
            let newMsgs = self.getMsgsUsers(msgs: msgInDB)
            return newMsgs
        } else {
            let msgInDB = ChatManager.shared().getSpecifiedDBMsgs(typeArr: [5], session: self.session, msgId: msgId, count: count)
            let newMsgs = self.getMsgsUsers(msgs: msgInDB)
            return newMsgs
        }
    }
    
    private func getMsgsUsers(msgs: [Message]) -> [Message] {
        var messages: [Message] = []
        
        let myGroup = DispatchGroup.init()
        
        for i in 0..<msgs.count {
            var msg = msgs[i]
            if !msg.isOutgoing {
                // 获取用户信息
                myGroup.enter()
                UserManager.shared().getUser(by: msg.fromId) { (user) in
                    msg.user = user
                    myGroup.leave()
                }
                
                // 如果是群聊则获取群成员信息
                if !self.session.isPrivateChat, !chatServerUrl.isBlank {
                    myGroup.enter()
                    GroupManager.shared().getMember(by: self.session.id.idValue.intEncoded, memberId: msg.fromId, serverUrl: chatServerUrl) { (member) in
                        msg.member = member
                        myGroup.leave()
                    }
                }
                
                messages.append(msg)
                
            } else {
                messages.append(msg)
            }
        }
        
        myGroup.notify(queue: .main) {
            FZMLog("遍历结束")
        }
        
        return messages
    }
    
    func loadData(more:Bool = false) {
        if !more {
            self.showProgress()
        }
        
        self.startId = self.fileListVMArr.last?.message.msgId ?? ""
        
        // 目前只能搜文件名
        DispatchQueue.global().async {
            let msgsInDB = self.getHistoryFileMsgs(from: self.startId, searchString: self.searchText)
            self.fileListVMArr += msgsInDB.compactMap{ FZMMessageBaseVM.init(with: $0) }
            DispatchQueue.main.async {
                self.hideProgress()
                self.tableView.mj_footer?.endRefreshing()
                self.tableView.mj_footer?.isHidden = msgsInDB.count == 0
                
                self.tableView.reloadData()
            }
        }
    }
}

extension FZMFileListView: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.fileListVMArr.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: FZMFileListCell.self)
        let index = indexPath.row
        guard fileListVMArr.count > index else {
            return cell
        }
        let model = fileListVMArr[index]
        
        cell.configure(with: model, isShowSelect: self.isSelect)
//        cell.senderLabBlock = self.senderLabBlock
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = indexPath.row
        guard fileListVMArr.count > index else {
            return
        }
        let model = fileListVMArr[index]
        let cell = tableView.cellForRow(at: indexPath) as! FZMFileListCell
        self.selectBlock?(model, cell)
    }
}
