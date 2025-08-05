//
//  FZMGroupCtrlMemberVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/1.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

enum FZMGroupCtrlMemberVCShowType{
    case delete//移除
    case whiteMap//白名单
    case blackMap//黑名单
}

class FZMGroupCtrlMemberVC: FZMGroupMemberListVC {
    
    private let showType : FZMGroupCtrlMemberVCShowType
    
    private let disposeBag = DisposeBag.init()
    
    lazy var selectView : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets.init(top: 0, left: 15, bottom: 0, right: 15)
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.itemSize = CGSize(width: 35, height: 35)
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor.clear
        view.showsHorizontalScrollIndicator = false
        view.register(FZMGroupUserCell.self, forCellWithReuseIdentifier: "FZMGroupUserCell")
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
//    private var selectArr = [IMGroupUserInfoModel]()
    private var selectArr = [Group]()
    
    private lazy var numberLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_32B2F7, textAlignment: .center, text: nil)
    }()
    
    lazy var confirmBtn : UIButton = {
        var text = ""
        switch showType {
        case .delete:
            text = "确认删除"
        default:
            text = "确定"
        }
        let btn = UIButton.getNormalBtn(with: text)
        return btn
    }()
    
    lazy var selectAllImgView : UIImageView = {
        let view = UIImageView(image: #imageLiteral(resourceName: "tool_disselect"))
        view.isUserInteractionEnabled = true
        view.enlargeClickEdge(.init(top: 20, left: 20, bottom: 20, right: 20))
        return view
    }()
    lazy var selectAllTitleView : UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_8A97A5, textAlignment: .center, text: "全选")
        lab.isUserInteractionEnabled = true
        lab.enlargeClickEdge(.init(top: 20, left: 20, bottom: 20, right: 20))
        return lab
    }()
    
//    private let group : IMGroupDetailInfoModel
    private let group : Group
    
    var reloadBlock : NormalBlock?
    lazy var memberListView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_FAFBFC
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 50
        view.register(FZMGroupMemberCell.self, forCellReuseIdentifier: "FZMGroupMemberCell")
        view.separatorColor = Color_F1F4F6
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.keyboardDismissMode = .onDrag
        return view
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
        cancelBtn.setTitle("完成", for: .normal)
        cancelBtn.setTitleColor(Color_32B2F7, for: .normal)
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
        input.tintColor = Color_32B2F7
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
    
    var memberList = [FZMGroupMemberListSection]()
    var dealtList = [FZMGroupMemberListSection]()
//    var originList = [IMGroupUserInfoModel]()
    var originList = [Group]()
    private var searchString: String?
    
//    init(with gid: IMGroupDetailInfoModel, ctrlType: FZMGroupCtrlMemberVCShowType) {
    init(with gid: Group, ctrlType: FZMGroupCtrlMemberVCShowType) {
        group = gid
        showType = ctrlType
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        switch showType {
        case .delete:
            self.navigationItem.title = "删除成员"
        case .whiteMap:
            self.navigationItem.title = "发言名单"
        case .blackMap:
            self.navigationItem.title = "禁言名单"
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "tool_search"), style: .plain, target: self, action: #selector(showSearchView))
        
        self.createUI()
        self.refreshData()
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
        
        if self.memberList != self.dealtList {
            self.memberList = self.dealtList
            self.memberListView.reloadData()
        }
//        memberListView.sc_indexViewDataSource = memberList.compactMap({ (section) -> String? in
//            return section.titleKey.count > 1 ? " " : section.titleKey
//        })
        
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
//        self.memberListView.sc_indexViewDataSource = nil
        self.tapControl.isHidden = false
        self.noDataView.isHidden = true
        UIView.animate(withDuration: 0.3) {
            self.searchBlockView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight)
            self.tapControl.alpha = 1
        }
    }
    
    private func createUI() {
        self.view.addSubview(selectView)
        selectView.snp.makeConstraints { (m) in
            m.left.equalToSuperview()
            m.top.equalToSuperview().offset(8)
            m.height.equalTo(35)
            m.right.equalToSuperview().offset(-60)
        }
        self.view.addSubview(numberLab)
        numberLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview()
            m.left.equalTo(selectView.snp.right)
            m.top.bottom.equalTo(selectView)
        }
        let view = UIView()
        view.makeOriginalShdowShow()
        self.view.addSubview(view)
        view.snp.makeConstraints { (m) in
            m.bottom.left.right.equalTo(self.safeArea)
            m.height.equalTo(70)
        }
        view.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.height.equalTo(40)
            m.right.equalToSuperview().offset(-15)
            if case .delete = self.showType {
                m.left.equalToSuperview().offset(15)
            }else {
                m.left.equalToSuperview().offset(145)
            }
        }
        if case .delete = self.showType {
            
        }else {
            view.addSubview(selectAllImgView)
            selectAllImgView.snp.makeConstraints { (m) in
                m.centerY.equalToSuperview()
                m.left.equalToSuperview().offset(15)
                m.size.equalTo(CGSize(width: 15, height: 15))
            }
            view.addSubview(selectAllTitleView)
            selectAllTitleView.snp.makeConstraints { (m) in
                m.centerY.equalToSuperview()
                m.left.equalTo(self.selectAllImgView.snp.right).offset(10)
                m.size.equalTo(CGSize(width: 35, height: 23))
            }
            let tap = UITapGestureRecognizer()
            tap.rx.event.subscribe {[weak self] (_) in
                self?.selectAllClick()
            }.disposed(by: disposeBag)
            selectAllImgView.addGestureRecognizer(tap)
            let tap2 = UITapGestureRecognizer()
            tap2.rx.event.subscribe {[weak self] (_) in
                self?.selectAllClick()
                }.disposed(by: disposeBag)
            selectAllTitleView.addGestureRecognizer(tap2)
        }
        self.view.addSubview(memberListView)
        memberListView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.bottom.equalTo(view.snp.top)
            m.top.equalToSuperview().offset(50)
        }
        
        confirmBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.commitInfo()
        }.disposed(by: disposeBag)
        
        self.view.addSubview(tapControl)
        tapControl.snp.makeConstraints({ (m) in
            m.left.equalTo(self.view)
            m.top.equalTo(self.view)
            m.height.equalTo(k_ScreenHeight)
            m.width.equalTo(k_ScreenWidth)
        })
        self.view.addSubview(noDataView)
        noDataView.snp.makeConstraints({ (m) in
            m.edges.equalTo(tapControl)
        })
    }
    
    func selectAllClick() {
        let count = memberList.reduce(0) {
            return $0 + $1.memberArr.count
        }
        if selectArr.count == count {
            selectArr.removeAll()
            self.memberListView.reloadData()
            self.selectView.reloadData()
            self.numberLab.text = self.selectArr.count > 0 ? "\(self.selectArr.count)" : ""
        }else {
            selectArr.removeAll()
            memberList.forEach { (section) in
                section.memberArr.forEach({ (model) in
                    self.selectArr.append(model)
                })
            }
            self.memberListView.reloadData()
            self.selectView.reloadData()
            self.numberLab.text = self.selectArr.count > 0 ? "\(self.selectArr.count)" : ""
        }
        self.refreshSelectShow()
    }
    
    private func refreshSelectShow() {
        let count = memberList.reduce(0) {
            return $0 + $1.memberArr.count
        }
        if selectArr.count == count {
            selectAllImgView.image = #imageLiteral(resourceName: "tool_select")
            selectAllTitleView.textColor = Color_32B2F7
        }else {
            selectAllImgView.image = #imageLiteral(resourceName: "tool_disselect")
            selectAllTitleView.textColor = Color_8A97A5
        }
    }
    
    private func refreshData() {
        self.showProgress(with: nil)
//        IMConversationManager.shared().getGroupMemberList(groupId: group.groupId) { (list, response) in
//            self.hideProgress()
//            guard response.success else {
//                self.showToast(with: response.message)
//                return
//            }
//            self.deal(with: list)
//        }
    }
    
//    private func deal(with list: [IMGroupUserInfoModel]) {
    private func deal(with list: [Group]) {
        self.view.showProgress()
        DispatchQueue.global().async {
            var sectionArr = [FZMGroupMemberListSection]()
            var sectionMap = [String:FZMGroupMemberListSection]()
//            list.forEach { (member) in
//                if member.memberLevel == .normal {
//                    let titleKey = member.showName.findFirstLetterFromString()
//                    if let section = sectionMap[titleKey] {
//                        section.memberArr.append(member)
//                    }else {
//                        let section = FZMGroupMemberListSection(titleKey: titleKey, user: member)
//                        sectionMap[titleKey] = section
//                        sectionArr.append(section)
//                    }
//                }
//                if self.group.isMaster, case .delete = self.showType {
//                    if member.memberLevel == .manager {
//                        let titleKey = "管理员"
//                        if let section = sectionMap[titleKey] {
//                            section.memberArr.append(member)
//                        }else {
//                            let section = FZMGroupMemberListSection(titleKey: titleKey, user: member)
//                            sectionMap[titleKey] = section
//                            sectionArr.append(section)
//                        }
//                    }
//                }
//                switch self.showType {
//                case .blackMap:
//                    if member.bannedType == .blackMap && member.memberLevel == .normal {
//                        self.selectArr.append(member)
//                    }
//                case .whiteMap:
//                    if member.bannedType == .whiteMap && member.memberLevel == .normal {
//                        self.selectArr.append(member)
//                    }
//                default: break
//                }
//            }
            sectionMap.forEach { (_,section) in
                section.memberArr.sort(by: <)
                self.originList = self.originList + section.memberArr
            }
            sectionArr.sort(by: <)
            self.dealtList = sectionArr
            self.memberList = sectionArr
            DispatchQueue.main.async {
                self.view.hideProgress()
                self.memberListView.reloadData()
                self.selectView.reloadData()
                self.numberLab.text = self.selectArr.count > 0 ? "\(self.selectArr.count)" : ""
                self.refreshSelectShow()
//                self.memberListView.sc_indexViewDataSource = self.memberList.compactMap({ (section) -> String? in
//                    return section.titleKey.count > 1 ? " " : section.titleKey
//                })
            }
        }
    }
    
    private func commitInfo() {
        var users = [String]()
        selectArr.forEach { (model) in
//            users.append(model.userId)
        }
        guard users.count > 0 else { return }
        if case .delete = showType {
            self.showProgress()
//            IMConversationManager.shared().kickOutGroupMember(groupId: group.groupId, users: users) { (response) in
//                self.hideProgress()
//                guard response.success else {
//                    self.showToast(with: response.message)
//                    return
//                }
//                self.selectArr.forEach { $0.delete() }
//                self.reloadBlock?()
//                self.popBack()
//            }
        }else if case .whiteMap = showType {
            self.showProgress()
//            IMConversationManager.shared().groupBannedSet(groupId: group.groupId, type: 3, users: users, deadline: Date.timestamp) { (response) in
//                self.hideProgress()
//                guard response.success else {
//                    self.showToast(with: response.message)
//                    return
//                }
//                self.reloadBlock?()
//                self.popBack()
//            }
        }else {
            var text = ""
            let firtModel = selectArr.first!
//            text = firtModel.showName
//            if users.count > 1 {
//                text = "\(text)等\(users.count)人"
//            }
//            let view = FZMCtrlUserAlertView(with: users, title: text, groupId: group.groupId)
//            view.completeBlock = {
//                self.reloadBlock?()
//                self.popBack()
//            }
//            view.show()
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

extension FZMGroupCtrlMemberVC: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectArr.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FZMGroupUserCell", for: indexPath) as! FZMGroupUserCell
        cell.nameLab.isHidden = true
        let model = selectArr[indexPath.item]
        cell.headImageView.kf.setImage(with: URL.init(string: ""), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
//        cell.headImageView.loadNetworkImage(with: model.avatar.getDownloadUrlString(width: 35), placeImage: #imageLiteral(resourceName: "friend_chat_avatar"))
        return cell
    }
}

extension FZMGroupCtrlMemberVC {
    
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
            self.memberListView.reloadData()
            return
        }
        let section = FZMGroupMemberListSection.init()
        section.titleKey = ""
        let lowercasedTest = text.lowercased()
//        let searchList = self.originList.filter {(!$0.friendRemark.isEmpty && $0.friendRemark.lowercased().contains(lowercasedTest)) || $0.nickname.lowercased().contains(lowercasedTest) || $0.groupNickname.lowercased().contains(lowercasedTest) }
//        searchList.forEach {section.memberArr.append($0)}
        if section.memberArr.isEmpty  {
            self.tapControl.isHidden = true
            self.noDataView.isHidden = false
        } else {
            self.tapControl.isHidden = true
            self.noDataView.isHidden = true
            self.searchString = text
            self.memberList = [section]
            self.memberListView.reloadData()
        }
    }
}

extension FZMGroupCtrlMemberVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let memberSection = memberList[section]
        let view = UIView()
        view.backgroundColor = Color_FAFBFC
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: memberSection.getTitle())
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.top.bottom.right.equalToSuperview()
            m.left.equalToSuperview().offset(20)
        }
        return view
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return memberList.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let memberSection = memberList[section]
        return memberSection.memberArr.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FZMGroupMemberCell", for: indexPath) as! FZMGroupMemberCell
        cell.showSelect = true
        let memberSection = memberList[indexPath.section]
        let member = memberSection.memberArr[indexPath.row]
//        if case .delete = showType {
//            cell.configure(with: member)
//        }else {
//            cell.configure(with: member, showBannedGroup: group)
//        }
//        cell.isSelect = selectArr.contains(member)
        cell.cleanBlock = {[weak self] in
            self?.reloadBlock?()
        }
        cell.searchString = searchString
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let memberSection = memberList[indexPath.section]
        let member = memberSection.memberArr[indexPath.row]
//        if selectArr.contains(member) {
//            selectArr = selectArr.filter({ (model) -> Bool in
//                return model !== member
//            })
//            tableView.reloadRows(at: [indexPath], with: .fade)
//            self.refreshSelectShow()
//        }else {
//            selectArr.append(member)
//            tableView.reloadRows(at: [indexPath], with: .fade)
//            self.refreshSelectShow()
//        }
        self.selectView.reloadData()
        self.numberLab.text = self.selectArr.count > 0 ? "\(self.selectArr.count)" : ""
    }
}

