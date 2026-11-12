//
//  ChoiceContactCardVC.swift
//  chat
//
//  Created by 郑晨 on 2025/3/20.
//

import UIKit

//typealias SelectContactBlock = ([FZMContactViewModel])->()

@objc public class ChoiceContactCardVC: UIViewController  {

    @objc var seletedBlock :((ContactViewModel)->())?
    private var friendArrayForSearch = [User]()
    private var selectArr = [ContactViewModel]()
    private var memberArrayForSearch = [GroupMember]()
    private var group: Group?
    
    private lazy var groupListView: FZMGroupContactListView = {
        let view = FZMGroupContactListView(with: L("群聊"), showSelect: false)
        view.selectGroupBlock = { [weak self] (contact) in
            self?.deal(contact: contact)
        }
        return view
    }()
    private var groupsDataSource: [(serverUrl: String, value: [(title: String, value: [ContactViewModel])])] = [] {
        didSet {
            self.reloadGroupCollcetView()
        }
    }
    public var contactCardType:Int = 1
    public var groupId:Int = 0
    /// true：好友 + 群聊合并成**一张列表**（转发图片用，不必先选「好友/群聊」再选人）
    public var showsFriendAndGroup = false

    // MARK: - 多选（转发到多个会话）

    /// true：点行勾选/取消，右上角「发送(N)」确认后回调 `selectedBlock`
    public var allowsMultipleSelection = false
    /// 多选确认回调（单选仍走 `seletedBlock`）
    /// ⚠️ 不能用 `public`：`ContactViewModel` 是 internal，public 属性不能暴露 internal 类型
    var selectedBlock: (([ContactViewModel]) -> Void)?

    private lazy var multiConfirmItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: L("发送"), style: .done, target: self,
                                   action: #selector(confirmMultiSelection))
        item.isEnabled = false
        return item
    }()

    /// 当前勾选的会话（按列表顺序）
    private var selectedContacts: [ContactViewModel] {
        return mergedSections.flatMap { $0.contacts }.filter { $0.isSelected }
    }

    @objc private func confirmMultiSelection() {
        let chosen = self.selectedContacts
        guard !chosen.isEmpty else { return }
        self.selectedBlock?(chosen)
        self.dismiss(animated: true)
    }

    private func refreshMultiConfirmItem() {
        let count = self.selectedContacts.count
        self.multiConfirmItem.title = count > 0 ? "\(L("发送"))(\(count))" : L("发送")
        self.multiConfirmItem.isEnabled = count > 0
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.view.backgroundColor =  UIColor(hex: 0xFAFBFC)
        self.navigationController?.navigationBar.tintColor = UIColor(hex: 0x32B2F7)
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: Color_Theme]
        self.navigationController?.navigationBar.shadowImage = UIImage.imageWithColor(with: UIColor(hex: 0xFAFBFC), size: CGSize(width: k_ScreenWidth, height: 1))
        self.navigationController?.navigationBar.setBackgroundImage(UIImage.imageWithColor(with: UIColor(hex: 0xFAFBFC), size: CGSize(width: k_ScreenWidth, height: 1)), for: .default)
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            // 「发送」按钮的文字颜色显式定死：未选 ＝ 浅灰，已选 ＝ 主题蓝。
            // 不写的话禁用态由系统决定，看起来像「灰得不对 / 一直是灰的」
            // （用户 2026-11-05：分享多选时发送按钮颜色不对）。
            naba.doneButtonAppearance.normal.titleTextAttributes =
                [.foregroundColor: UIColor(hex: 0x32B2F7)]
            naba.doneButtonAppearance.disabled.titleTextAttributes =
                [.foregroundColor: UIColor(hex: 0xBFC8D2)]
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backgroundColor =  UIColor(hex: 0xFAFBFC)
            naba.shadowColor = UIColor.lightGray
            
            naba.titleTextAttributes = [.foregroundColor:Color_Theme,.font:UIFont.systemFont(ofSize: 18)]
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
       
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: L("取消"), style: .plain, target: self, action: #selector(dismissPage))
        if showsFriendAndGroup {
            self.navigationItem.title = L("选择会话")
            createFriendAndGroupUI()
            if allowsMultipleSelection {
                self.navigationItem.rightBarButtonItem = self.multiConfirmItem
            }
        }else if contactCardType == 1{
            self.navigationItem.title =  L("选择好友")
            self.createFriendUI()
        }else if contactCardType == 2{
            self.navigationItem.title =  L("选择群聊")
            self.createGroupUI()
        }else{
            self.navigationItem.title =  L("选择好友")
            self.createGroupFriendUI()
        }
        
    }
    
    @objc private func dismissPage() {
        // ⚠️ 本页有两种来源：
        //   · 被 push 进来（栈里还有别的页）⇒ pop 返回；
        //   · 被 present 出来（转发选人页：present 了一个 `FZMNavigationController`，
        //     本页是它的根 VC；发名片也是 present）⇒ 这时 `popViewController` 什么都不做，
        //     表现就是「点取消没反应」。present 场景要 dismiss 整个导航。
        if let nav = self.navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            (self.navigationController ?? self).dismiss(animated: true)
        }
    }
    
    private func createFriendUI() {
        
        let view1 = FZMFriendContactListView(with: L("选择好友"), .no)
        
        view1.selectBlock = {[weak self] (model) in
            self?.deal(contact: model)
        }
        self.friendArrayForSearch = UserManager.shared().friends
        let friendDataSource = UserManager.shared().divideUser(self.friendArrayForSearch)
        view1.originDataSource = friendDataSource
        let view = FZMScrollPageView(frame: CGRect(x: 0, y: 14, width: k_ScreenWidth, height: k_ScreenHeight-k_StatusNavigationBarHeight), dataViews: [view1])
        self.view.addSubview(view)
        
    }
    
    private func createGroupFriendUI(){
        let view1 = FZMFriendContactListView(with: L("选择群友"), .no)
        
        view1.selectBlock = {[weak self] (model) in
            self?.deal(contact: model)
        }
        
        self.group = GroupManager.shared().getDBGroup(by: groupId)
        
        let members = GroupManager.shared().getDBGroupMembers(with: groupId)
//        if members.count == 0 {
//            self.getMemberListRequest(groupId: groupId)
//        }
//        let memberlist = members.filter { $0.memberId != LoginUser.shared().address }
//        self.memberArrayForSearch = memberlist

        let memberDataSource = UserManager.shared().divideGroupMember(members)
        view1.originDataSource = memberDataSource
        let view = FZMScrollPageView(frame: CGRect(x: 0, y: 14, width: k_ScreenWidth, height: k_ScreenHeight-k_StatusNavigationBarHeight), dataViews: [view1])
        self.view.addSubview(view)
    }
    
    private func createGroupUI(){
        
        let view = FZMScrollPageView(frame: CGRect(x: 0, y: 14, width: k_ScreenWidth, height: k_ScreenHeight-k_StatusNavigationBarHeight), dataViews: [self.groupListView])
        self.divideGroups(contactsArr: GroupManager.shared().loadDBGroups())
        self.view.addSubview(view)
       
    }
    
    private func reloadGroupCollcetView() {
        
        var dataSource = [(title: String, value: [ContactViewModel])]()
        
        guard self.groupsDataSource.count > 0 else {
            DispatchQueue.main.async {
               
                self.groupListView.dataSource = dataSource
            }
            return
        }
        
        dataSource = self.groupsDataSource.first!.value
        DispatchQueue.main.async {
            self.groupListView.dataSource = dataSource
        }
    }
    
    private func divideGroups(contactsArr: [Group]) {
        DispatchQueue.global().async {
            let divideContacts = UserManager.shared().divideGroup(contactsArr)
            self.groupsDataSource = divideContacts
            
        }
    }
    private func deal(contact: ContactViewModel?) {
        
        if (self.seletedBlock != nil) {
            self.seletedBlock!(contact!)
            self.dismiss(animated: true)
        }
        
//        if let contactViewModel = contact {
//            self.navigationController?.dismiss(animated: true, completion: {
//                self.seletedBlock?(contactViewModel)
//            })
//            
//        }
    }
    
    
    // MARK: - 好友 + 群聊合并列表

    private lazy var mergedTableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = UIColor(hex: 0xFAFBFC)
        view.separatorStyle = .none
        view.rowHeight = 60
        // ⚠️ 必须注册：`dequeueReusableCell(withClass:for:)` 不会自动注册，
        // 取不到 cell 会直接 fatalError（点「转发图片」闪退就是这个）
        view.register(ContactsCell.self, forCellReuseIdentifier: "ContactsCell")
        view.dataSource = self
        view.delegate = self
        return view
    }()

    /// 合并列表的分组：好友 / 群聊
    private var mergedSections = [(title: String, contacts: [ContactViewModel])]()

    private func createFriendAndGroupUI() {
        let friends = UserManager.shared().divideUser(UserManager.shared().friends).flatMap { $0.value }
        let groups = UserManager.shared().divideGroup(GroupManager.shared().loadDBGroups())
            .flatMap { $0.value }
            .flatMap { $0.value }

        mergedSections = []
        if !friends.isEmpty { mergedSections.append((L("好友"), friends)) }
        if !groups.isEmpty { mergedSections.append((L("群聊"), groups)) }

        self.view.addSubview(mergedTableView)
        mergedTableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        mergedTableView.reloadData()
    }
}

// MARK: - 好友 + 群聊合并列表（只给 showsFriendAndGroup 用）

extension ChoiceContactCardVC: UITableViewDataSource, UITableViewDelegate {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return mergedSections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < mergedSections.count else { return 0 }
        return mergedSections[section].contacts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: ContactsCell.self, for: indexPath)
        guard indexPath.section < mergedSections.count,
              indexPath.row < mergedSections[indexPath.section].contacts.count else { return cell }
        let contact = mergedSections[indexPath.section].contacts[indexPath.row]
        // 多选模式下按 isSelected 显示勾选状态，单选保持原样
        // ⚠️ 必须先 showSelect()：`ContactsCell.selectBtn` 默认 hidden，
        //    只设 selectStyle 的话勾选状态写进去了但按钮一直不显示
        //    （用户 2026-11-05：「选择了会话但是看不见已经选择了这一条」）。
        cell.showSelect(self.allowsMultipleSelection)
        cell.selectStyle = (allowsMultipleSelection && contact.isSelected) ? .select : .disSelect
        cell.configure(with: contact)
        return cell
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < mergedSections.count else { return nil }
        let header = UIView()
        header.backgroundColor = UIColor(hex: 0xFAFBFC)
        let lab = UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .left,
                                 text: mergedSections[section].title)
        header.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview().offset(-6)
        }
        return header
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < mergedSections.count,
              indexPath.row < mergedSections[indexPath.section].contacts.count else { return }
        let contact = mergedSections[indexPath.section].contacts[indexPath.row]

        // 多选：只切换勾选，不关页面
        if allowsMultipleSelection {
            contact.isSelected.toggle()
            tableView.reloadRows(at: [indexPath], with: .none)
            self.refreshMultiConfirmItem()
            return
        }

        deal(contact: contact)
    }
}
