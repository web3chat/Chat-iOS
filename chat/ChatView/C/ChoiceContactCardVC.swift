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
        let view = FZMGroupContactListView(with: "群聊", showSelect: false)
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
            naba.backgroundColor =  UIColor(hex: 0xFAFBFC)
            naba.shadowColor = UIColor.lightGray
            
            naba.titleTextAttributes = [.foregroundColor:Color_Theme,.font:UIFont.systemFont(ofSize: 18)]
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
       
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissPage))
        if contactCardType == 1{
            self.navigationItem.title =  "选择好友"
            self.createFriendUI()
        }else if contactCardType == 2{
            self.navigationItem.title =  "选择群聊"
            self.createGroupUI()
        }else{
            self.navigationItem.title =  "选择好友"
            self.createGroupFriendUI()
        }
        
    }
    
    @objc private func dismissPage() {

        self.navigationController?.popViewController(animated: true)
    }
    
    private func createFriendUI() {
        
        let view1 = FZMFriendContactListView(with: "选择好友", .no)
        
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
        let view1 = FZMFriendContactListView(with: "选择群友", .no)
        
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
    
    
    
}
