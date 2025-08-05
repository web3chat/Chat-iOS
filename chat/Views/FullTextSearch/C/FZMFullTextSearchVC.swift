//
//  FZMFullTextSearchVC.swift
//  IMSDK
//
//  Created by 陈健 on 2019/9/20.
//

import UIKit
import SnapKit
import KeychainAccess
import sqlcipher
import SwifterSwift

enum FZMFullTextSearchType: Equatable {
    case friend
    case group
    case chatRecord(specificId: String?) // specificId, 指定搜索某个会话的聊天记录
    case all
    var titit: String {
        switch self {
        case .friend:
            return "联系人"
        case .group:
            return "群聊"
        case .chatRecord:
            return "聊天记录"
        case .all:
            return ""
        }
    }
}

class FZMFullTextSearchVC: UIViewController, ViewControllerProtocol {
    
    private var searchType: FZMFullTextSearchType
    private var limitCount = 3
    private let friendArrayForSearch: [User]
    private let groupArrayForSearch: [Group]
    private let refreshQueue = DispatchQueue.init(label: "FZMFullTextSearchVCRefreshQueue")
    private var dataSource = [[IMFullTextSearchVM]]()
    private var searchString: String?
    
    private let SearchHistoryUserDefaultsKey = "SearchHistoryUserDefaultsKey"
    
    private lazy var searchHistoryView: FZMFullTextSearchHistoryView = {
        let v = FZMFullTextSearchHistoryView.init()
        v.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight)
        v.clearAllHistoryBlock = {[weak v, weak self] in
            v?.isHidden = true
            self?.clearAllSearchHistories()
        }
        v.deleteHistoryBlock = {[weak self] (title) in
            self?.deleteSearchHistory(searchString: title)
        }
        v.selectedHistoryBlock = {[weak self] (title) in
            self?.searchInput.text = title
            self?.search(title)
        }
        return v
    }()
    
    private var searchHistories = [String]() {
        didSet {
            searchHistoryView.histories = searchHistories
            if searchHistories.isEmpty {
                searchHistoryView.isHidden = true
            }
        }
    }
    
    private lazy var searchTableView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_FAFBFC
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 50
        view.register(FZMFullTextSearchCell.self, forCellReuseIdentifier: "FZMFullTextSearchCell")
        view.separatorColor = Color_E6EAEE
        view.keyboardDismissMode = .onDrag
        view.showsVerticalScrollIndicator = false
        return view
    }()
    
    private lazy var headerView : UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 50))
        return view
    }()
    
    private lazy var noDataView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight))
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
    
    private lazy var cancelBtn : UIButton = {
        let btn = UIButton()
        btn.setAttributedTitle(NSAttributedString(string: "取消", attributes: [.foregroundColor:Color_Theme,.font:UIFont.regularFont(16)]), for: .normal)
        return btn
    }()
    
    private lazy var searchBlockView : UIView = {
        let view = UIView()
        view.layer.backgroundColor = Color_F1F4F6.cgColor
        view.layer.cornerRadius = 20
        view.tintColor = Color_8A97A5
        let imageV = UIImageView(image: #imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysTemplate))
        view.addSubview(imageV)
        imageV.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 17, height: 18))
        })
        view.addSubview(searchInput)
        searchInput.snp.makeConstraints({ (m) in
            m.top.bottom.right.equalToSuperview()
            m.left.equalTo(imageV.snp.right).offset(10)
        })
        return view
    }()
    
    private lazy var searchInput : UITextField = {
        let input = UITextField()
        input.tintColor = Color_Theme
        input.textAlignment = .left
        input.font = UIFont.regularFont(16)
        input.textColor = Color_24374E
        input.clearButtonMode = .whileEditing
        input.attributedPlaceholder = NSAttributedString(string: self.getSearchPlaceholder(with: self.searchType), attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.regularFont(16)])
        input.returnKeyType = .search
        input.addTarget(self, action: #selector(textFiledEditChanged(_:)), for: .editingChanged)
        input.delegate = self
        return input
    }()
    
    let disposeBag = DisposeBag.init()

    init(searchType: FZMFullTextSearchType = .all, limitCount: Int = 3, isHideHistory: Bool = false) {
        self.searchType = searchType
        
        self.groupArrayForSearch = GroupManager.shared().groups
        
        self.friendArrayForSearch = UserManager.shared().friends
        super.init(nibName: nil, bundle: nil)
        
        self.limitCount = limitCount
        self.searchHistoryView.isHidden = isHideHistory
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xls_isNavigationBarHidden = true
        
        self.createUI()
        
        if let searchHistoriesCache = FZM_UserDefaults.getUserObject(forKey: SearchHistoryUserDefaultsKey) as? [String], !searchHistoriesCache.isEmpty {
            self.searchHistories = searchHistoriesCache
            searchHistoryView.isHidden = !dataSource.isEmpty
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.searchString == nil {
            searchInput.becomeFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global().async {
            let count = (Int((try? Keychain.init().getString(CHAT33PRO_USER_SHOW_WALLET_KEY)) ?? "0") ?? 0)
            if count < 20 {
                try? Keychain.init().set("0", key: (CHAT33PRO_USER_SHOW_WALLET_KEY))
            }
        }
    }
    
    private func createUI() {
        self.view.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview()
            m.width.equalTo(65)
            m.height.equalTo(40)
            m.top.equalToSuperview().offset(k_StatusBarHeight + 5)
        }
        self.view.addSubview(searchBlockView)
        searchBlockView.snp.makeConstraints { (m) in
            m.top.bottom.equalTo(cancelBtn)
            m.right.equalTo(cancelBtn.snp.left)
            m.left.equalToSuperview().offset(15)
        }
        self.view.addSubview(searchTableView)
        searchTableView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(searchBlockView.snp.bottom).offset(5)
        }
        
        cancelBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.popBack()
        }.disposed(by: disposeBag)
        
        searchTableView.addSubview(searchHistoryView)
    }
    
    private func popBack() {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func getSearchPlaceholder(with searchType: FZMFullTextSearchType) -> String {
        switch searchType {
        case .friend:
            return "搜索联系人"
        case .group:
            return "搜索群聊"
        case .chatRecord:
            return "搜索聊天记录"
        case .all:
            return "搜索联系人、群、聊天记录"
        }
    }
    
}

extension FZMFullTextSearchVC {
    private func insertSearchHistory(searchString: String) {
        guard !searchString.isEmpty else { return }
//        self.searchHistories.remove(at: searchString)
        self.deleteSearchHistories(with: searchString)
        self.searchHistories.insert(searchString, at: 0)
        if self.searchHistories.count > 10 {
            self.searchHistories.removeLast()
        }
        FZM_UserDefaults.setUserValue(self.searchHistories, forKey: SearchHistoryUserDefaultsKey)

    }
    
    private func deleteSearchHistory(searchString: String) {
//        self.searchHistories.remove(at: searchString)
        self.deleteSearchHistories(with: searchString)
        FZM_UserDefaults.setUserValue(self.searchHistories, forKey: SearchHistoryUserDefaultsKey)
    }
    
    private func clearAllSearchHistories() {
        self.searchHistories.removeAll()
        FZM_UserDefaults.setUserValue(self.searchHistories, forKey: SearchHistoryUserDefaultsKey)
    }
    
    private func deleteSearchHistories(with searchString: String) {
        guard self.searchHistories.count > 0 else { return }
        
        if self.searchHistories.contains(searchString), let index = self.searchHistories.firstIndex(of: searchString) {
            
            self.searchHistories.remove(at: index)
        }
    }
}

extension FZMFullTextSearchVC {
    
    @objc private func textFiledEditChanged(_ textField: UITextField) {
        let pasteStr = UIPasteboard.general.string
        if pasteStr == textField.text {
            //如果文本框的文字和粘贴板里相同就设置光标位置
            let newPosition = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
        }
//        textField.limitText(with: 30)
        if textField.markedTextRange == nil ||
            textField.markedTextRange?.isEmpty ?? false {
            if let text = textField.text {
                self.search(text)
            }
        }
    }
    
    private func search(_ text: String) {
        if text.isEmpty {
            self.noDataView.removeFromSuperview()
        } else if noDataView.superview == nil {
            self.searchTableView.addSubview(self.noDataView)
        }
        self.noDataView.isHidden = true
        self.searchHistoryView.isHidden = !text.isEmpty
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if text == self.searchInput.text, !text.isEmpty {
                self.insertSearchHistory(searchString: text)
            }
        }
        self.refreshSearchTableView(searchString: text.isEmpty ? nil : text)
    }
    
    private func refreshSearchTableView(searchString: String?) {
        self.refreshQueue.async {
            self.dataSource.removeAll()
            if let searchString = searchString, !searchString.isEmpty {
                if let friendSearchModelList = self.searchFriend(searchString) {
                     self.dataSource.append(friendSearchModelList)
                }
                if let groupSearchModelList = self.searchGroup(searchString) {
                    self.dataSource.append(groupSearchModelList)
                }
                if let chatRecordSearchModelList = self.searchChatRecord(searchString) {
                    self.dataSource.append(chatRecordSearchModelList)
                }
            }
            DispatchQueue.main.sync {
                self.searchString = searchString
                self.searchTableView.reloadData()
            }
        }
    }
    
    // 搜索联系人（好友）
    private func searchFriend(_ text: String) -> [IMFullTextSearchVM]? {
        guard self.searchType == .all || self.searchType == .friend else { return nil }
        let friendSearchModelList = self.friendArrayForSearch.filter { ($0.alias ?? "").lowercased().contains(text.lowercased()) || ($0.nickname ?? "").lowercased().contains(text.lowercased()) || $0.address.lowercased().contains(text.lowercased()) }.compactMap { return IMFullTextSearchVM.init(friend: $0) }
        return friendSearchModelList.isEmpty ? nil : friendSearchModelList
    }
    
    // 搜索群
    private func searchGroup(_ text: String) -> [IMFullTextSearchVM]? {
        guard self.searchType == .all || self.searchType == .group else { return nil }
        let groupSearchModelList = self.groupArrayForSearch.filter { ($0.name).lowercased().contains(text.lowercased()) || $0.address.lowercased().contains(text.lowercased()) }.compactMap { return IMFullTextSearchVM.init(group: $0)
        }
        return groupSearchModelList.isEmpty ? nil : groupSearchModelList
        
    }
    
    // 搜索聊天记录
    private func searchChatRecord(_ text: String) -> [IMFullTextSearchVM]? {
        guard self.searchType != .friend && self.searchType != .group else { return nil }
        var specificId: String? = nil
        if case let FZMFullTextSearchType.chatRecord(sId) = self.searchType {
            specificId = sId
        }
        var chatRecordSearchModelList: [IMFullTextSearchVM]
        let msgs = ChatManager.shared().searchMsg(searchString: text, sessionId: specificId)
        if specificId == nil {
            let divideMsgs = Array.init(msgs.reduce(into: Dictionary<String,[Message]>.init(), { (into, msg) in
                let key = msg.sessionId.idValue + "key" + String.init(msg.channelType.rawValue)
                if into[key] == nil {
                    var arr = Array<Message>.init()
                    arr.append(msg)
                    into[key] = arr
                } else {
                    into[key]?.append(msg)
                }
            }).values)
            chatRecordSearchModelList = divideMsgs.compactMap { IMFullTextSearchVM.init(msgs: $0) }.sorted(by: >)
        } else {
            chatRecordSearchModelList = msgs.compactMap{ IMFullTextSearchVM.init(msgs: [$0], isDetailList: true) }
        }
        return chatRecordSearchModelList.isEmpty ? nil : chatRecordSearchModelList
    }
}

extension FZMFullTextSearchVC: UITextFieldDelegate {
    //连按20搜索按钮开启钱包
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        if !IMSDK.shared().showWallet, textField.text == "" {
//            DispatchQueue.global().async {
//                let count = (Int((try? Keychain.init().getString(CHAT33PRO_USER_SHOW_WALLET_KEY)) ?? "0") ?? 0) + 1
//                try? Keychain.init().set("\(count)", key: CHAT33PRO_USER_SHOW_WALLET_KEY)
//                if count > 20 {
//                    DispatchQueue.main.async {
//                        exit(0)
//                    }
//                }
//            }
//        }
        return true
    }
}

extension FZMFullTextSearchVC {
    private func getSecitonHeaderView(section: Int, title: String, isShowMore: Bool) -> UIView {
        let view = UIView()
        view.backgroundColor = Color_FAFBFC
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: title)
        if case let FZMFullTextSearchType.chatRecord(specificId) = self.searchType, let specificId = specificId {
            var sessionID: SessionID?
            let channelType = self.dataSource[section].first?.msgs.first?.channelType
            if channelType == .group {
                sessionID = SessionID.group(specificId)
            } else if channelType == .person {
                sessionID = SessionID.person(specificId)
            }
            if let sessionID = sessionID {
                let session = SessionManager.shared().getOrCreateSession(id: sessionID)
                lab.text = "\"\(session.sessionName)\"" + "的记录"
            } else {
                lab.text = "\"\(specificId)\"" + "的记录"
            }
        }
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
            m.height.equalTo(30)
        }
        if isShowMore {
            let btn = UIButton.init(type: .custom)
            btn.setTitle("查看更多", for: .normal)
            btn.setTitleColor(Color_Theme, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            btn.titleLabel?.textAlignment = .right
            btn.enlargeClickEdge(5, 0, 0, 25)
            let moreData = self.dataSource[section]
            btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
                self?.showMore(searchType: moreData[0].type, dataSource: [moreData])
                self?.view.endEditing(true)
            }).disposed(by: disposeBag)
            view.addSubview(btn)
            btn.snp.makeConstraints { (m) in
                m.centerY.equalTo(lab)
                m.height.equalTo(20)
                m.width.equalTo(70)
                m.right.equalToSuperview().offset(-25)
            }
            let imV = UIImageView(image: #imageLiteral(resourceName: "me_more"))
            view.addSubview(imV)
            imV.snp.makeConstraints { (m) in
                m.centerY.equalTo(btn)
                m.right.equalToSuperview().offset(-16)
                m.size.equalTo(CGSize(width: 4, height: 15))
            }
        }
        return view
    }
    
    /// 查看更多
    private func showMore(searchType: FZMFullTextSearchType, dataSource: [[IMFullTextSearchVM]]?) {
        let vc = FZMFullTextSearchVC.init(searchType: searchType)
        vc.dataSource = dataSource ?? [[IMFullTextSearchVM]]()
        vc.searchString = self.searchString
        vc.searchInput.text = searchString
        vc.searchHistoryView.isHidden = true
        vc.limitCount = NSInteger.max
        self.navigationController?.pushViewController(vc)
    }
}

extension FZMFullTextSearchVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.dataSource.count else { return nil}
        let title = self.dataSource[section].first?.type.titit ?? ""
        let isShowMore = self.dataSource[section].count > limitCount
        let v = self.getSecitonHeaderView(section: section, title: title, isShowMore: isShowMore)
        return v
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 15
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 15))
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        self.noDataView.isHidden = !self.dataSource.isEmpty
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.dataSource.count else { return 0 }
        let count = self.dataSource[section].count
        return count > self.limitCount ? self.limitCount : count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: FZMFullTextSearchCell.self, for: indexPath)
        if indexPath.section < self.dataSource.count,
            indexPath.row < self.dataSource[indexPath.section].count {
            let model = self.dataSource[indexPath.section][indexPath.row]
            cell.searchString = self.searchString
            cell.configure(with: model)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.dataSource.count,
            indexPath.row < self.dataSource[indexPath.section].count
        else { return }
        let model = self.dataSource[indexPath.section][indexPath.row]
        switch model.type {
        case .friend:
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.person(model.typeId)))
        case .group:
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(model.typeId)))
        case .chatRecord:
            if model.msgs.count == 1, let sessionId = model.msgs.first?.sessionId {
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: sessionId, locationMsg: (model.msgs.first?.msgId ?? "", self.searchString ?? "")))
                
            } else if let sessionId = model.msgs.first?.sessionId {
                self.showMore(searchType: .chatRecord(specificId: sessionId.idValue), dataSource: [model.msgs.compactMap({IMFullTextSearchVM.init(msgs: [$0], isDetailList: true)})])
            }
            break
        case .all:
            break
        }
    }
}
