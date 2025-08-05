//
//  FZMGroupChooseMemberSourceVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/10/8.
//  群操作 - 选择好友/组织架构成员加入群聊

import Foundation
import RxSwift
import SnapKit
import SwifterSwift
import Starscream

enum FZMGroupChooseMemberType {
    case createGroup
    case addNewMember(String, [String])// 需要排除的用户地址数据源（已在群的成员地址）
}

class FZMGroupChooseMemberSourceVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    var chooseType: FZMGroupChooseMemberType
    
    let curServer: Server?
    
//    var excludeUsers: [String]?// 需要排除的用户地址数据源（已在群的成员地址）
    
    var selectMembersBlock: StringArrayBlock?// 选择加入群聊的成员block
    
    // 从好友列表选择成员视图
    private lazy var friendView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth - 30, height: 60))
        view.backgroundColor = .white
        view.layer.cornerRadius = 5
        
        let imageView = UIImageView.init(image: #imageLiteral(resourceName: "icon_select_friend"))
        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize.init(width: 35, height: 35))
        }
        
        let lab = UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: "从好友列表选择成员")
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalTo(imageView.snp.right).offset(5)
            m.centerY.equalToSuperview()
        }
        
        let imageViewMore = UIImageView.init(image: #imageLiteral(resourceName: "cell_right_dot"))
        view.addSubview(imageViewMore)
        imageViewMore.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        view.isUserInteractionEnabled = true
        let teamTap = UITapGestureRecognizer()
        teamTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            var dbGroupId: Int = 0
            var chatserverUrl = ""
            // 从好友列表选择成员
            var type: FZMSelectFriendGroupShowStyle = .allFriend
            switch strongSelf.chooseType {
            case .createGroup:
                type = .allFriend
                chatserverUrl = strongSelf.curServer?.value ?? ""
            case .addNewMember(let groupId, _):
                dbGroupId = groupId.intEncoded
                type = .exclude(dbGroupId)
                chatserverUrl = GroupManager.shared().getDBGroup(by: dbGroupId)?.chatServerUrl ?? ""
            }
            guard !chatserverUrl.isBlank else {
                return
            }
            FZMUIMediator.shared().pushVC(.selectFriend(type: type, chatServerUrl: chatserverUrl, completeBlock: nil))
        }.disposed(by: bag)
        view.addGestureRecognizer(teamTap)
        
        return view
    }()
    
    // 从组织架构选择成员视图
    private lazy var teamView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth - 30, height: 60))
        view.backgroundColor = .white
        view.layer.cornerRadius = 5
        
        let imageView = UIImageView.init(image: #imageLiteral(resourceName: "icon_team"))
        view.addSubview(imageView)
        imageView.layer.cornerRadius = 17.5
        imageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize.init(width: 35, height: 35))
        }
        
        let lab = UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: "从组织架构选择成员")
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalTo(imageView.snp.right).offset(5)
            m.centerY.equalToSuperview()
        }
        
        let imageViewMore = UIImageView.init(image: #imageLiteral(resourceName: "cell_right_dot"))
        view.addSubview(imageViewMore)
        imageViewMore.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        view.isUserInteractionEnabled = true
        let teamTap = UITapGestureRecognizer()
        teamTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            // 从组织架构选择成员
            var type: TeamViewType = .createGroup
            var users: [String] = []
            switch strongSelf.chooseType {
            case .createGroup:
                type = .createGroup
            case .addNewMember(let groupId, let excludeUsers):
                type = .addGroupMember(groupId: groupId)
                users = excludeUsers
            }
            
//            FZMUIMediator.shared().pushVC(.goTeamH5WebVC(type: .teamMemberList, completeBlock: { [weak self] in
//                guard let strongSelf = self else { return }
//                // 退出团队
//                LoginUser.shared().quitTeam()
//                // 重置视图位置
//                strongSelf.resetViewsFrame()
//            }))
//        }.disposed(by: bag)
//
            
            let vc = TeamH5WebViewVC.init(with: type)
            
            vc.excludeUsers = users// 传入需排除的群成员
            
            vc.selectUsersBlock = { (userIds) in
                switch strongSelf.chooseType {
                case .createGroup:
                    // 创建群聊
                    strongSelf.createGroup(userIds: userIds)
                case .addNewMember:
                    // 添加新群成员
                    strongSelf.selectMembersBlock?(userIds)
                }
            }
            vc.hidesBottomBarWhenPushed = true
            strongSelf.navigationController?.pushViewController(vc)
        }.disposed(by: bag)
        view.addGestureRecognizer(teamTap)
        
        return view
    }()
    
    init(with type: FZMGroupChooseMemberType, server: Server? = nil) {
        chooseType = type
        curServer = server
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var titleStr = ""
        switch chooseType {
        case .addNewMember(_,_):
            titleStr = "添加新成员"
        case .createGroup:
            titleStr = "创建群聊"
        }
        self.title = titleStr
        
        self.setupviews()
        
//        self.bindData()
    }
    
    private func setupviews() {
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "选择群聊成员")
        self.view.addSubview(lab)
        lab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.height.equalTo(50)
        }
        
        self.view.addSubview(friendView)
        friendView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalToSuperview().offset(50)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(60)
        }
        
        self.view.addSubview(teamView)
        teamView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(friendView.snp.bottom).offset(10)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(60)
        }
    }
    
    // 创建团队群聊
    private func createGroup(userIds: [String]) {
        guard let server = curServer else {
            return
        }
        self.showProgress()
        var groupName = LoginUser.shared().address.shortAddress
        if let nickname = LoginUser.shared().nickName?.value, !nickname.isBlank {
            groupName = nickname
        }
        groupName = groupName + "创建的群聊"
        
        // 创建群聊请求
        GroupManager.shared().createGroup(serverUrl: server.value, name: groupName, introduce: "", avatarUrl: "", memberIds: userIds) { [weak self] (group) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(group.address)))
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("创建群失败")
        }
    }
    
}
