//
//  FZMGroupDetailInfoVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/29.
//  Copyright © 2018年 吴文拼. All rights reserved.
//  群详情页面
//

import UIKit
import SnapKit
import SwiftUI
import SwifterSwift

class FZMGroupDetailInfoVC: UIViewController, ViewControllerProtocol {
    
    private let groupId : Int
    var sendvcBlock : StringBlock?
    
    private var groupDetailInfo: Group?{
        didSet{
            DispatchQueue.main.async {
                self.refreshView()
            }
        }
    }
    
    private let disposeBag = DisposeBag.init()
    
    private var statusType: SocketConnectStatus = .unConnected {
        didSet {
            // 绿 Color_62DEAD 灰 Color_8A97A5  红 Color_DD5F5F
            switch statusType {
            case .unConnected:// 未连接
                self.serverStatusImageView.backgroundColor = Color_8A97A5
            case .connected:// 已连接
                self.serverStatusImageView.backgroundColor = Color_62DEAD
            case .disConnected:// 断开连接
                self.serverStatusImageView.backgroundColor = Color_DD5F5F
            }
        }
    }
    
    private lazy var scrollView : UIScrollView = {
        let view = UIScrollView(frame: CGRect.zero)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.contentSize = CGSize(width: k_ScreenWidth, height: k_ScreenHeight)
        view.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 40, right: 0)
        view.addSubview(contentView)
        contentView.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight)
        return view
    }()
    
    private lazy var contentView : UIView = {
        let view = UIView()
        view.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(10)
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 50, height: 50))
        }
        view.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.top.equalTo(headerImageView.snp.top)
            m.left.equalTo(headerImageView.snp.right).offset(15)
            m.right.lessThanOrEqualToSuperview().offset(-20)
            m.height.greaterThanOrEqualTo(20)
        }
        view.addSubview(desLab)
        desLab.snp.makeConstraints { (m) in
            m.top.equalTo(nameLab.snp.bottom).offset(5)
            m.left.equalTo(nameLab.snp.left)
            m.height.greaterThanOrEqualTo(20)
        }
        view.addSubview(publicNameLab)
        publicNameLab.snp.makeConstraints { (m) in
            m.top.equalTo(desLab.snp.bottom).offset(5)
            m.left.equalTo(nameLab.snp.left)
            m.right.lessThanOrEqualToSuperview().offset(-20)
            m.height.greaterThanOrEqualTo(20)
        }
        
        view.addSubview(memberBlockView)
        memberBlockView.snp.makeConstraints({ (m) in
            m.top.equalTo(publicNameLab.snp.bottom).offset(15)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(210)
        })
        
        view.addSubview(infoBlockView)
        infoBlockView.snp.makeConstraints({ (m) in
            m.top.equalTo(memberBlockView.snp.bottom).offset(15)
            m.left.right.equalTo(memberBlockView)
            m.height.equalTo(50)
        })
        
        view.addSubview(ctrlBlockView)
        ctrlBlockView.snp.makeConstraints({ (m) in
            m.top.equalTo(infoBlockView.snp.bottom).offset(15)
            m.left.right.equalTo(memberBlockView)
            m.height.equalTo(200)
        })
        
        view.addSubview(serverInfoView)
        serverInfoView.snp.makeConstraints { (m) in
            m.top.equalTo(ctrlBlockView.snp.bottom).offset(15)
            m.left.right.equalTo(memberBlockView)
            m.height.equalTo(120)
        }
        
        view.addSubview(configureView)
        configureView.snp.makeConstraints({ (m) in
            m.top.equalTo(serverInfoView.snp.bottom).offset(15)
            m.left.right.equalTo(memberBlockView)
            m.height.equalTo(200)
        })
        
        view.addSubview(bottomBtn)
        bottomBtn.snp.makeConstraints({ (m) in
            m.top.equalTo(configureView.snp.bottom).offset(15)
            m.left.right.equalTo(memberBlockView)
            m.height.equalTo(40)
        })
        
        view.addSubview(bottomLab)
        bottomLab.snp.makeConstraints({ (m) in
            m.top.equalTo(configureView.snp.bottom).offset(15)
            m.left.right.equalTo(memberBlockView)
        })
        
        return view
    }()
    
    // 头像
    private lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "group_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.isUserInteractionEnabled = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    // 群名
    private lazy var nameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(17), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        return lab
    }()
    
    // 群号
    private lazy var desLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()
    
    // 公开群名
    private lazy var publicNameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        return lab
    }()
    
    // 所有群成员视图
    private lazy var memberBlockView : UIView = {
        let view = UIView()
        view.makeOriginalShdowShow()
        let titleView = self.getOnlineView(title: "群成员", rightView: memberNumberLab, true, false)
        view.addSubview(titleView)
        titleView.snp.makeConstraints({ (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(50)
        })
        view.addSubview(memberView)
        memberView.snp.makeConstraints({ (m) in
            m.top.equalTo(titleView.snp.bottom).offset(10)
            m.left.right.equalToSuperview()
            m.bottom.equalToSuperview().offset(-17)
        })
        return view
    }()
    
    // 群成员数量
    private lazy var memberNumberLab : UILabel = {
        return self.getNormalLab()
    }()
    
    // 群成员独立视图
    private lazy var memberView: FZMGroupMembersView = {
        let view = FZMGroupMembersView.init()
        view.selectedBlock = { [weak self] (item) in
            guard let strongSelf = self else { return }
            strongSelf.clickMembersViewItem(item)
        }
        return view
    }()
    
    // 群成员数据源
    private var memberList = [FZMGroupDetailUserViewModel]()
    
    // 我在本群的昵称视图
    private lazy var infoBlockView : UIView = {
        let view = UIView()
        view.makeOriginalShdowShow()
        let nameView = self.getOnlineView(title: "我在本群的昵称", rightView: nickNameLab, true, false)
        view.addSubview(nameView)
        nameView.snp.makeConstraints({ (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(50)
        })
        return view
    }()
    
    // 我在本群的昵称lab
    private lazy var nickNameLab : UILabel = {
        let lab = self.getNormalLab()
        lab.numberOfLines = 2
        lab.minimumScaleFactor = 0.7
        lab.adjustsFontSizeToFitWidth = true
        return lab
    }()
    
    // 查找聊天记录等视图
    private lazy var ctrlBlockView : UIView = {
        let view = UIView()
        view.makeOriginalShdowShow()
        
        view.addSubview(chatRecordView)
        chatRecordView.snp.makeConstraints({ (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(50)
        })
        view.addSubview(fileView)
        fileView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(chatRecordView.snp.bottom)
            m.height.equalTo(50)
        })
        let disView = self.getOnlineView(title: "消息免打扰", rightView: muteNotiSwitch, false, true)
        view.addSubview(disView)
        disView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(fileView.snp.bottom)
            m.height.equalTo(50)
        })
        let stickView = self.getOnlineView(title: "置顶聊天", rightView: onTopSwitch, false, false)
        view.addSubview(stickView)
        stickView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(disView.snp.bottom)
            m.height.equalTo(50)
        })
//        view.addSubview(feedbackView)
//        feedbackView.snp.makeConstraints({ (m) in
//            m.bottom.left.right.equalToSuperview()
//            m.height.equalTo(50)
//        })
        return view
    }()
    
    private lazy var chatRecordView: UIView = {
        self.getOnlineView(title: "查找聊天记录", rightView: UIView.init(), true, true)
    }()
    
    private lazy var fileView: UIView = {
        self.getOnlineView(title: "群文件", rightView: UIView.init(), true, true)
    }()
    
//    private lazy var feedbackView: UIView = {
//        self.getOnlineView(title: "举报该群聊", rightView: UIView.init(), true, true)
//    }()
    
    // 消息免打扰
    private lazy var muteNotiSwitch : UISwitch = {
        let v = UISwitch()
        v.onTintColor = Color_Theme
        v.addTarget(self, action: #selector(muteNotiSwitchChange(_:)), for: .valueChanged)
        return v
    }()
    
    // 置顶聊天
    private lazy var onTopSwitch : UISwitch = {
        let v = UISwitch()
        v.onTintColor = Color_Theme
        v.addTarget(self, action: #selector(onTopSwitchChange(_:)), for: .valueChanged)
        return v
    }()
    
    // 我在本群的昵称lab
    private lazy var groupTypeLab : UILabel = {
        return self.getNormalLab()
    }()
    
    // 归属服务器视图
    private lazy var serverInfoView : UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.makeOriginalShdowShow()
        
        // 群类型视图
        let groupTypeView = self.getOnlineView(title: "群类型", rightView: groupTypeLab, false, true)
        view.addSubview(groupTypeView)
        groupTypeView.snp.makeConstraints({ (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(50)
        })
        
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.text = "企业服务器"
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
            m.top.equalToSuperview().offset(50)
        }
        
        view.addSubview(self.serverNameLab)
        self.serverNameLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(12 + 50)
            m.left.equalTo(lab.snp.right).offset(10)
            m.right.equalToSuperview().offset(-39)
        }
        
        view.addSubview(self.serverUrlLab)
        self.serverUrlLab.snp.makeConstraints { (m) in
            m.left.equalTo(lab.snp.right).offset(10)
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview().offset(-12)
        }
        
        view.addSubview(self.serverStatusImageView)
        self.serverStatusImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 10, height: 10))
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(20 + 50)
        }
        return view
    }()
    // 服务器名称
    private lazy var serverNameLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    // 服务器地址
    private lazy var serverUrlLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    // 服务器连接状态
    private lazy var serverStatusImageView: UIImageView = {
        let imageView = UIImageView.init(frame: CGRect.init(x: 0, y: 0, width: 10, height: 10))
        imageView.layer.cornerRadius = 5
        imageView.backgroundColor = Color_8A97A5
//        imageView.isHidden = true
        return imageView
    }()
    
    
    
    // 管理员设置等视图
    private lazy var configureView : UIView = {
        let view = UIView()
        view.makeOriginalShdowShow()
        
        view.addSubview(managerView)
        managerView.snp.makeConstraints({ (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(50)
        })
        
        view.addSubview(transferView)
        transferView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(managerView.snp.bottom)
            m.height.equalTo(50)
        })
        
        view.addSubview(addGroupView)
        addGroupView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(transferView.snp.bottom)
            m.height.equalTo(50)
        })
        
        view.addSubview(addFriendView)
        addFriendView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(addGroupView.snp.bottom)
            m.height.equalTo(50)
        })
        
        view.addSubview(chatLimitView)
        chatLimitView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(addFriendView.snp.bottom)
            m.height.equalTo(50)
        })
        
        view.addSubview(chatLimitListView)
        chatLimitListView.snp.makeConstraints({ (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(chatLimitView.snp.bottom)
            m.height.equalTo(50)
        })
        return view
    }()
    private lazy var managerView : UIView = {
        return self.getOnlineView(title: "管理员设置", rightView: managerSetLab, true, true)
    }()
    private lazy var transferView : UIView = {
        return self.getOnlineView(title: "转让群主", rightView: transferLab, true, true)
    }()
    private lazy var addGroupView : UIView = {
        return self.getOnlineView(title: "加群限制", rightView: addGroupLab, true, true)
    }()
    private lazy var addFriendView : UIView = {
        return self.getOnlineView(title: "加好友限制", rightView: addFriendLab, true, true)
    }()
    private lazy var chatLimitView : UIView = {
        return self.getOnlineView(title: "全员禁言", rightView: chatLimitSwitch, false, false)
    }()
    private lazy var chatLimitListView : UIView = {
        return self.getOnlineView(title: "禁言名单", rightView: chatLimitLab, true, false)
    }()
    // 管理员
    private lazy var managerSetLab : UILabel = {
        return self.getNormalLab()
    }()
    // 群主昵称
    private lazy var transferLab : UILabel = {
        let lab = self.getNormalLab()
        lab.numberOfLines = 2
        lab.minimumScaleFactor = 0.7
        lab.adjustsFontSizeToFitWidth = true
        return lab
    }()
    // 加群限制右侧文字-无需审批
    private lazy var addGroupLab : UILabel = {
        return self.getNormalLab()
    }()
    // 加好友限制右侧文字
    private lazy var addFriendLab : UILabel = {
        return self.getNormalLab()
    }()
    // 全员禁言右侧switch
    private lazy var chatLimitSwitch : UISwitch = {
        let v = UISwitch()
        v.onTintColor = Color_Theme
        return v
    }()
    // 禁言名单右侧文字
    private lazy var chatLimitLab : UILabel = {
        return self.getNormalLab()
    }()
    
    private lazy var bottomBtn : UIButton = {
        let btn = UIButton.getNormalBtn(with: "退出群聊", backgroundColor: Color_FAFBFC)
        return btn
    }()
    
    private lazy var bottomLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .left, text: "全员群/部门群只能通过退出组织/部门才能退出群聊，退出组织/部门将自动退出对应群！")
        lab.numberOfLines = 0
        lab.isHidden = true
        return lab
    }()
    
    private func getOnlineView(title: String, rightView: UIView, _ showMore: Bool = true, _ showBottomLine: Bool = true) -> UIView {
        let view = UIView()
        view.clipsToBounds = true
        let titleLab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: title)
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
        }
        titleLab.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.addSubview(rightView)
        rightView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalTo(titleLab.snp.right).offset(10)
            m.right.equalToSuperview().offset(showMore ? -24 : -15)
        }
        if showMore {
            let imV = UIImageView(image: #imageLiteral(resourceName: "me_more"))
            view.addSubview(imV)
            imV.snp.makeConstraints { (m) in
                m.centerY.equalToSuperview()
                m.right.equalToSuperview().offset(-15)
                m.size.equalTo(CGSize(width: 3, height: 15))
            }
        }
        if showBottomLine {
            let lineV = UIView.getNormalLineView()
            view.addSubview(lineV)
            lineV.snp.makeConstraints { (m) in
                m.bottom.left.right.equalToSuperview()
                m.height.equalTo(0.5)
            }
        }
        return view
    }
    private func getNormalLab() -> UILabel {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.isUserInteractionEnabled = true
        lab.enlargeClickEdge(UIEdgeInsets.init(top: 5, left: 30, bottom: 5, right: 30))
        return lab
    }
    
    // MARK: -
    init(with groupId: Int) {
        self.groupId = groupId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNavBackgroundColor()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if groupId > 0 {
            self.getDBGroupDetailInfo()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.title = "群聊详情"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "icon_qrcode").withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(qrCodeClick))
        self.navigationItem.rightBarButtonItem?.tintColor = Color_24374E
        
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_F6F7F8
        
        self.createUI()
        self.makeActions()
        
        // 刷新页面数据
        self.reloadViewData()
        
        // 设置归属服务器信息
        self.setServerInfo()
        
        // 群信息变化通知
        FZM_NotificationCenter.addObserver(self, selector: #selector(refreshDetailInfo), name: FZM_Notify_GroupDetailInfoChanged, object: nil)
    }
    
    /// 群信息有更新
    ///  --- 加群 退群 更新加群权限 更新群加好友权限 更新群禁言 更新群成员（管理权限变化） 更新禁言列表 更新群名 更新群头像
    @objc private func refreshDetailInfo(notification: NSNotification) {
        // 判断有更新的是否是当前群
        guard let groupId = notification.object as? Int, groupId == self.groupId else {
            return
        }
        
        DispatchQueue.main.async {
            // 刷新页面数据
            self.reloadViewData()
        }
    }
    
    /// 刷新页面数据
    private func reloadViewData() {
        // 从本地数据库获取群信息数据
        self.getDBGroupDetailInfo()
        
        // 接口获取群信息
        self.getGroupDetailInfoRequest()
    }
    
    /// 设置归属服务器信息
    private func setServerInfo() {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        
        let servers = LoginUser.shared().chatServerGroups.compactMap { (serverGroup) -> UserChatServerGroup? in
            if serverGroup.value == serverUrl {
                return serverGroup
            } else {
                return nil
            }
        }
        guard servers.count > 0, let server = servers.first else { return }
        
        self.serverUrlLab.text = serverUrl.shortUrlStr
        self.serverNameLab.text = server.name
        
        self.statusType = (MultipleSocketManager.shared().getSingleSocketConnectStatus(serverUrl))
        
        // 订阅聊天服务器连接状态
        self.subscribeServerStatus()
    }
    
    /// 订阅聊天服务器连接状态
    private func subscribeServerStatus() {
        MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
            guard let strongSelf = self, case .next((let url, let isAvailable)) = event, let info = strongSelf.groupDetailInfo, let serverUrl = info.chatServerUrl, serverUrl == url.absoluteString else { return }
            
            DispatchQueue.main.async {
                strongSelf.statusType = isAvailable ? .connected : .disConnected
            }
        }.disposed(by: self.disposeBag)
    }
    
    /// 从本地数据库获取群信息数据
    private func getDBGroupDetailInfo() {
        guard let info = GroupManager.shared().getDBGroup(by: groupId) else { return }
        self.groupDetailInfo = info
//        FZMLog("groupDetailInfo --- \(info)")
    }
    
    private func createUI() {
        self.view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        bottomBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            guard let strongSelf = self, let info = strongSelf.groupDetailInfo else { return }
            
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.leftBtnTitle = "取消"
            alert.rightBtnTitle = "确定"
            let alias = info.contactsName
            var str = "确定解散 \(alias) 群吗?"
            if info.owner.memberId != LoginUser.shared().address {
                str = "确定退出 \(alias) 群吗?"
            }
            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
            attStr.addAttributes([NSAttributedString.Key.foregroundColor: Color_Theme], range:(str as NSString).range(of: alias as String))
            alert.attributedInfo = attStr
            alert.leftBtnTouchBlock = {}
            alert.rightBtnTouchBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if info.owner.memberId == LoginUser.shared().address {
                    // 解散群
                    strongSelf.dibandGroupAction()
                } else {
                    // 退群
                    strongSelf.exitGroupAction()
                }
            }
            alert.show()
            
        }.disposed(by: disposeBag)
    }
    
    
    /// 刷新页面
    private func refreshView() {
        guard let info = groupDetailInfo else { return }
        
        // 群头像
        headerImageView.kf.setImage(with: URL.init(string: info.avatarURLStr), placeholder: #imageLiteral(resourceName: "group_chat_avatar"))
        
        // 群名称
        nameLab.attributedText = nil
        nameLab.text = nil
        if info.person?.memberType == 1 || info.person?.memberType == 2 {
            nameLab.attributedText = info.contactsName.jointImage(image: #imageLiteral(resourceName: "me_edit"))
        } else {
            nameLab.text = info.contactsName
        }
        
        // 群号
        let markId = info.markId ?? ""
        desLab.text = "群号 " + markId
        
        // 公开群名
        let pubName = info.publicName
        let name = info.name
        publicNameLab.text = nil
//        if !pubName.isBlank, pubName != name {
        if !name.isBlank, !pubName.isBlank {// 当前群名显示的是加密群名
            publicNameLab.isHidden = false
            publicNameLab.text = "公开群名：" + pubName
            publicNameLab.snp.updateConstraints { (m) in
                m.height.greaterThanOrEqualTo(20)
            }
        } else {
            publicNameLab.isHidden = true
            publicNameLab.snp.updateConstraints { (m) in
                m.height.greaterThanOrEqualTo(0)
            }
        }
        
        // 群成员数量
        memberNumberLab.text = "共\(info.memberNum)人"
        
        // 我在本群的昵称
        nickNameLab.text = info.person?.memberName
        
        // 消息免打扰
        muteNotiSwitch.isOn = info.isMuteNotification
        
        // 置顶聊天
        onTopSwitch.isOn = info.isOnTop
        
        // 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
        var groupTypeStr = ""
        switch info.groupType {
        case 0:
            groupTypeStr = "普通群"
        case 1:
            groupTypeStr = "全员群"
        case 2:
            groupTypeStr = "部门群"
        default:
            groupTypeStr = ""
        }
        groupTypeLab.text = groupTypeStr
        
        
        // 管理员数量
        managerSetLab.text = "共\(String(info.adminNum ?? 0))人"
        
        // 转让群主（群主昵称）
        transferLab.text = info.owner.contactsName
        
        // 加群限制
        addGroupLab.text = info.joinType == 0 ? "无需审批" : "禁止加群"
        
        // 加好友限制
        addFriendLab.text = info.friendType == 0 ? "可加好友" : "禁止加好友"
        
        // 全员禁言
        chatLimitSwitch.isOn = info.muteType == 1 ? true : false// 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
        
        // 禁言名单
        chatLimitLab.text = "\(info.muteNum)名成员禁言"
        
        // 底部解散/退出群聊按钮
        if info.groupType == 0 {
            bottomBtn.isHidden = false
            bottomLab.isHidden = true
            if info.owner.memberId == LoginUser.shared().address {
                bottomBtn.setAttributedTitle(NSAttributedString(string: "解散群聊", attributes: [.foregroundColor: Color_DD5F5F,.font:UIFont.regularFont(16)]), for: .normal)
            }else{
                bottomBtn.setAttributedTitle(NSAttributedString(string: "退出群聊", attributes: [.foregroundColor: Color_8A97A5,.font:UIFont.regularFont(16)]), for: .normal)
            }
        } else {
            bottomBtn.isHidden = true
            bottomLab.isHidden = false
        }
        
        // 部分群成员视图数据处理
        let allMembers = info.members?.compactMap { (user) -> FZMGroupDetailUserViewModel in
            return FZMGroupDetailUserViewModel(with: user)
        }
        if var allMembers = allMembers {
            allMembers = allMembers.withoutDuplicates(keyPath: \.memberId)
            memberList = []
            if info.joinType == 1 {
                if info.person?.memberType == 1 || info.person?.memberType == 2 {
                    memberList = allMembers.count > 8 ? Array(allMembers[0...7]) : allMembers
                    memberList.append(FZMGroupDetailUserViewModel(with: .invite))
                    memberList.append(FZMGroupDetailUserViewModel(with: .remove))
                }else {
                    memberList = allMembers.count > 10 ? Array(allMembers[0...9]) : allMembers
                }
            }else {
                if info.person?.memberType == 1 || info.person?.memberType == 2 {
                    memberList = allMembers.count > 8 ? Array(allMembers[0...7]) : allMembers
                    memberList.append(FZMGroupDetailUserViewModel(with: .invite))
                    memberList.append(FZMGroupDetailUserViewModel(with: .remove))
                }else {
                    memberList = allMembers.count > 9 ? Array(allMembers[0...8]) : allMembers
                    memberList.append(FZMGroupDetailUserViewModel(with: .invite))
                }
            }
        }
        memberView.sourceData = memberList
        
        let memberHeight : CGFloat = memberList.count > 5 ? 220 : 143
        memberBlockView.snp.updateConstraints { (m) in
            m.height.equalTo(memberHeight)
        }
        
        var configureHeight : CGFloat = 0
        configureView.isHidden = true
        
        if info.person?.memberType == 2 {
            configureView.isHidden = false
//            let attStr = NSMutableAttributedString(string: info.contactsName)
//            attStr.append(NSAttributedString(string: "\(FZMIconFont.editPencil.rawValue)", attributes: [.foregroundColor: Color_8A97A5, .font: UIFont.iconfont(ofSize: 12)]))
            nameLab.attributedText = info.contactsName.jointImage(image: #imageLiteral(resourceName: "me_edit"))
            configureHeight = 300
            managerView.snp.updateConstraints { (m) in
                m.height.equalTo(50)
            }
            transferView.snp.updateConstraints { (m) in
                m.height.equalTo(50)
            }
        }else if info.person?.memberType == 1 {
            configureView.isHidden = false
//            let attStr = NSMutableAttributedString(string: info.contactsName)
//            attStr.append(NSAttributedString(string: "\(FZMIconFont.editPencil.rawValue)", attributes: [.foregroundColor: Color_8A97A5, .font: UIFont.iconfont(ofSize: 12)]))
            nameLab.attributedText = info.contactsName.jointImage(image: #imageLiteral(resourceName: "me_edit"))
            configureHeight = 200
            managerView.snp.updateConstraints { (m) in
                m.height.equalTo(0)
            }
            transferView.snp.updateConstraints { (m) in
                m.height.equalTo(0)
            }
        }
        configureView.snp.updateConstraints { (m) in
            m.height.equalTo(configureHeight)
        }
        
        var height = self.bottomBtn.frame.maxY
        if info.groupType != 0 {
            let text = bottomLab.text ?? ""
            let labHeight = text.getContentHeight(font: .systemFont(ofSize: 16), width: k_ScreenWidth - 30)
            height = configureView.frame.maxY + 15 + labHeight
        }
        height += 30
        contentView.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: height)
        scrollView.contentSize = CGSize(width: k_ScreenWidth, height: height)
    }
}

//MARK: 响应事件
extension FZMGroupDetailInfoVC {
    @objc private func clickMembersViewItem(_ item: FZMGroupDetailUserViewModel) {
        let addBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            // 邀请新群成员
            guard let group = strongSelf.groupDetailInfo else { return }
            if let _ = LoginUser.shared().myStaffInfo {// 在团队内进入选择好友/组织架构成员页面
                var excludeUserIds: [String] = [LoginUser.shared().address]
                if LoginUser.shared().address != group.owner.memberId {
                    excludeUserIds.append(group.owner.memberId)
                }
                group.members?.forEach({ (member) in
                    if !excludeUserIds.contains(member.memberId) {
                        excludeUserIds.append(member.memberId)
                    }
                })
                
                if group.groupType == 0 {
                    FZMUIMediator.shared().pushVC(.goChooseMemberSourceVC(type: .addNewMember(strongSelf.groupId.string, excludeUserIds), completeBlock: { [weak self] (users) in
                        guard let strongSelf = self else { return }
                        // 邀请新群员接口请求
                        strongSelf.inviteNewMembersRequest(users: users)
                    }))
                } else {
                    let vc = TeamH5WebViewVC.init(with: .addGroupMember(groupId: String(group.id)))
                    
                    vc.excludeUsers = excludeUserIds// 传入需排除的群成员
                    
                    vc.selectUsersBlock = { (userIds) in
                        // 邀请新群员接口请求
                        strongSelf.inviteNewMembersRequest(users: userIds)
                    }
                    vc.hidesBottomBarWhenPushed = true
                    strongSelf.navigationController?.pushViewController(vc)
                }
            } else {
                FZMUIMediator.shared().pushVC(.selectFriend(type: .exclude(group.id), chatServerUrl: "", completeBlock: { [weak self] in
                    guard let strongSelf = self else { return }
                    // 刷新页面数据
                    strongSelf.reloadViewData()
                }))
            }
        }
        let deleteBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            // 删除群成员
            guard let group = strongSelf.groupDetailInfo else { return }
            FZMUIMediator.shared().pushVC(.selectFriend(type: .allMember(group.id), chatServerUrl: "", completeBlock: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.reloadViewData()
            }))
//            let vc = FZMGroupCtrlMemberVC(with: group, ctrlType: .delete)
//            vc.reloadBlock = {[weak self] in
//                self?.reloadViewData()
//            }
//            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        switch item.type {
        case .person:
//            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: item.memberId, source: .group(groupId: self.groupId)))
            
            let vc = FriendInfoVC.init(with: item.memberId, source: .group(groupId: self.groupId))
            vc.sendredBlock = {[] (note) in
                print("note is \(note)")
                if self.sendvcBlock != nil {
                    self.sendvcBlock!(note)
                }
                
            }
            vc.hidesBottomBarWhenPushed = true
            DispatchQueue.main.async {
                UIViewController.current()?.navigationController?.pushViewController(vc)
            }

        case .invite:
            addBlock()
        case .remove:
            deleteBlock()
        }
    }
    
    // 群二维码点击
    @objc func qrCodeClick() {
        guard let info = self.groupDetailInfo else { return }
        FZMUIMediator.shared().pushVC(.goQRCodeShow(type: .group(info)))
    }
    
    // 消息免打扰点击
    @objc private func muteNotiSwitchChange(_ sender: UISwitch) {
        guard let _ = self.groupDetailInfo else { return }
        self.muteNotiSwitch.isOn = sender.isOn
        self.groupDetailInfo?.isMuteNotification = sender.isOn
        // 更新本地群信息
        GroupManager.shared().updateDBGroupMuteNotifacation(groupId: self.groupId, isMuteNoti: sender.isOn)
        
        // 发送详情信息更新通知
        FZM_NotificationCenter.post(name: FZM_Notify_SessionInfoChanged, object: self.groupId.string)
    }
    
    // 置顶聊天点击
    @objc private func onTopSwitchChange(_ sender: UISwitch) {
        guard let _ = self.groupDetailInfo else { return }
        self.onTopSwitch.isOn = sender.isOn
        self.groupDetailInfo?.isOnTop = sender.isOn
        // 更新本地群信息
        GroupManager.shared().updateDBGroupIsOnTop(groupId: self.groupId, isOnTop: sender.isOn)
        
        // 发送详情信息更新通知
        FZM_NotificationCenter.post(name: FZM_Notify_SessionInfoChanged, object: self.groupId.string)
    }
    
    private func makeActions() {
        // 群昵称点击
        let nameTap = UITapGestureRecognizer()
        nameTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self, let info = strongSelf.groupDetailInfo else { return }
            guard info.person?.memberType == 1 || info.person?.memberType == 2 else { return }
            let vc = FZMGroupEditNameVC(with: info, info.contactsName)
            vc.completeBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reloadViewData()
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
        }.disposed(by: disposeBag)
        nameLab.addGestureRecognizer(nameTap)
        
        // 群头像点击
        let headTap = UITapGestureRecognizer()
        headTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self, let info = strongSelf.groupDetailInfo else { return }
            
            if info.person?.memberType == 1 || info.person?.memberType == 2 {
                let vc = FZMEditHeadImageVC(with: .group(groupId:strongSelf.groupId), oldAvatar: info.avatarURLStr)
                strongSelf.navigationController?.pushViewController(vc)
            }else {
                // 查看大图
                let vc = FZMEditHeadImageVC(with: .showGroupAvatar, oldAvatar: info.avatarURLStr)
                strongSelf.navigationController?.pushViewController(vc)
            }
        }.disposed(by: disposeBag)
        headerImageView.addGestureRecognizer(headTap)
        
        // 管理员设置点击
        let managerTap = UITapGestureRecognizer()
        managerTap.rx.event.subscribe { [weak self] (_) in
            // 跳转管理员设置页面
            guard let strongSelf = self, let info = strongSelf.groupDetailInfo else { return }
            let vc = FZMGroupManagerSetVC(with: info)
            vc.changeBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reloadViewData()
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
        }.disposed(by: disposeBag)
//        managerSetLab.addGestureRecognizer(managerTap)
        managerView.addGestureRecognizer(managerTap)
        
        // 转让群主
        let transferTap = UITapGestureRecognizer()
        transferTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            guard let info = self?.groupDetailInfo else { return }
            let vc = FZMGroupAddManagerVC(with: info, type: .owner)
            vc.reloadBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reloadViewData()
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
            
            /**
             guard let strongSelf = self, let info = strongSelf.groupDetailInfo else { return }
             
             let alert = TwoBtnInfoAlertView.init()
             alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
             alert.leftBtnTitle = "取消"
             alert.rightBtnTitle = "确定"
             let alias = info.owner.contactsName
             let str = "确定转让群主给 \(alias) 吗?"
             let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
             attStr.addAttributes([NSAttributedString.Key.foregroundColor: Color_Theme], range:(str as NSString).range(of: alias as String))
             alert.attributedInfo = attStr
             alert.leftBtnTouchBlock = {}
             alert.rightBtnTouchBlock = {
                 if info.owner.memberId == LoginUser.shared().address {
                     // 解散群
                     strongSelf.dibandGroupAction()
                 } else {
                     // 退群
                     strongSelf.exitGroupAction()
                 }
             }
             alert.show()
             */
            
        }.disposed(by: disposeBag)
        transferLab.addGestureRecognizer(transferTap)
        
        // 加群限制
        let groupTap = UITapGestureRecognizer()
        groupTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            
            guard let groupInfo = strongSelf.groupDetailInfo, groupInfo.groupType == 0 else {
                // 全员群/部门群不能修改群类型
                return
            }
            
            FZMBottomSelectView.show(with: "加群限制", arr: [
                                        FZMBottomOption(title: "无需审批", titleColor: Color_24374E, content: "加群无需群主或管理员同意", contentColor: Color_8A97A5, block: {
                                            strongSelf.updateJoinType(joinType: 0)
                                        }),FZMBottomOption(title: "禁止加群", titleColor: Color_24374E, content: "除群主或管理员邀请外不允许任何人加群", contentColor: Color_8A97A5, block: {
                                            strongSelf.updateJoinType(joinType: 1)
                                        })])
        }.disposed(by: disposeBag)
        addGroupLab.addGestureRecognizer(groupTap)
        
        // 加好友限制
        let friendTap = UITapGestureRecognizer()
        friendTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            FZMBottomSelectView.show(with: "加好友限制", arr: [
                                        FZMBottomOption(title: "群内可加好友", block: {
                                            strongSelf.updateFriendType(friendType: 0)
                                        }),FZMBottomOption(title: "群内禁止加好友", block: {
                                            strongSelf.updateFriendType(friendType: 1)
                                        })])
        }.disposed(by: disposeBag)
        addFriendLab.addGestureRecognizer(friendTap)
        
        // 禁言设置
        let chatLimitTap = UITapGestureRecognizer()
        chatLimitTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self, let serverUrl = strongSelf.groupDetailInfo?.chatServerUrl else{ return }
            let list = BannedListVC.init(with: strongSelf.groupId, serverUrl: serverUrl)
            strongSelf.navigationController?.pushViewController(list, animated: true)
        }.disposed(by: disposeBag)
        chatLimitLab.addGestureRecognizer(chatLimitTap)
        
        // 我在本群的昵称
        let nicknameTap = UITapGestureRecognizer()
        nicknameTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self, let info = strongSelf.groupDetailInfo, let nickname = info.person?.memberName else { return }
            let vc = FZMGroupEditNameVC(with: info, nickname, true)
            vc.completeBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reloadViewData()
            }
            strongSelf.navigationController?.pushViewController(vc, animated: true)
        }.disposed(by: disposeBag)
        nickNameLab.addGestureRecognizer(nicknameTap)
        
        // 群成员列表
        let memberListTap = UITapGestureRecognizer()
        memberListTap.rx.event.subscribe {[weak self] (_) in
            guard let info = self?.groupDetailInfo else { return }
            let vc = FZMGroupMemberListVC(with: info,fromTag:0)
            self?.navigationController?.pushViewController(vc, animated: true)
        }.disposed(by: disposeBag)
        memberNumberLab.addGestureRecognizer(memberListTap)
        
        // 群文件
        let fileTap = UITapGestureRecognizer.init()
        fileTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self else {return}
            strongSelf.showToast("群文件")
            let vc = FZMFileViewController.init(session: Session.init(id: SessionID.group(String(strongSelf.groupId))))
            strongSelf.navigationController?.pushViewController(vc)
//            let vc = FZMFileViewController.init(conversationType: .group, conversationID: strongSelf.groupId )
//            vc.title = "群文件"
//            strongSelf.navigationController?.pushViewController(vc, animated: true)
        }.disposed(by: disposeBag)
        fileView.addGestureRecognizer(fileTap)
        
        // 查找聊天记录
        let chatRecordTap = UITapGestureRecognizer.init()
        chatRecordTap.rx.event.subscribe { [weak self] (_) in
            guard let strongSelf = self, let info = strongSelf.groupDetailInfo else { return }
            FZMUIMediator.shared().pushVC(.goFullTextSearch(searchType: .chatRecord(specificId: info.address), limitCount: NSInteger.max, isHideHistory: true))
        }.disposed(by: disposeBag)
        chatRecordView.addGestureRecognizer(chatRecordTap)
        
//        let feedbackTap = UITapGestureRecognizer.init()
//        feedbackTap.rx.event.subscribe { [weak self] (_) in
//            guard let strongSelf = self else {return}
//            let vc = FZMWebViewController.init()
//            vc.url = FeedbackUrl
//            strongSelf.navigationController?.pushViewController(vc, animated: true)
//            }.disposed(by: disposeBag)
//        feedbackView.addGestureRecognizer(feedbackTap)
        
//        muteNotiSwitch.rx.controlEvent(.valueChanged).subscribe {[weak self] (_) in
//            guard let strongSelf = self, var info = strongSelf.groupDetailInfo else { return }
//            strongSelf.muteNotiSwitch.isOn = !strongSelf.muteNotiSwitch.isOn
//            info.isMuteNotification = strongSelf.muteNotiSwitch.isOn
//            // 更新本地群信息
//            GroupManager.shared().updateDBGroupMuteNotifacation(group: strongSelf.groupId, isMuteNoti: info.isMuteNotification)
//
//            // 发送详情信息更新通知
//            FZM_NotificationCenter.post(name: FZM_Notify_SessionInfoChanged, object: nil)
//
//        }.disposed(by: disposeBag)
//
//        onTopSwitch.rx.controlEvent(.valueChanged).subscribe {[weak self] (_) in
//            guard let strongSelf = self, let _ = strongSelf.groupDetailInfo else { return }
//            strongSelf.onTopSwitch.isOn = !strongSelf.onTopSwitch.isOn
//            strongSelf.groupDetailInfo!.isOnTop = strongSelf.onTopSwitch.isOn
//            // 更新本地群信息
//            GroupManager.shared().updateDBGroupIsOnTop(group: strongSelf.groupId, isOnTop: strongSelf.groupDetailInfo!.isMuteNotification)
//
//            // 发送详情信息更新通知
//            FZM_NotificationCenter.post(name: FZM_Notify_SessionInfoChanged, object: nil)
//        }.disposed(by: disposeBag)
        
        // 全员禁言开关
        chatLimitSwitch.rx.controlEvent(.valueChanged).subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.setMuteTypeRequest(muteType: strongSelf.chatLimitSwitch.isOn ? 1 : 0)
        }.disposed(by: disposeBag)
    }
}

// MARK: - 网络请求
extension FZMGroupDetailInfoVC {
    // 获取群成员列表请求
    private func getGroupMemberListRequest() {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        GroupManager.shared().getGroupMemberList(serverUrl: serverUrl, groupId: groupId) { [weak self] (members) in
            guard let strongSelf = self else { return }
            
            strongSelf.groupDetailInfo?.members = members
            // 刷新页面
            strongSelf.refreshView()
        } failureBlock: { (error) in
//            guard let strongSelf = self else { return }
//            strongSelf.hideProgress()
//            strongSelf.showToast("获取群成员列表失败")
        }
    }
    
    // 邀请新群员
    private func inviteNewMembersRequest(users: [String]) {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        FZMLog("group --- \(groupId)  \(serverUrl)")
        self.showProgress()

        if users.isEmpty {
            self.showToast("请选择好友")
            return
        }
        FZMLog("users --- \(users)")
        
        // 邀请新群成员请求
        GroupManager.shared().inviteGroupMembers(serverUrl: serverUrl, groupId: groupId, memberIds: users) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            APP.shared().showToast("邀请成功")
            strongSelf.reloadViewData()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("邀请失败")
        }
    }
    
    /// 更新群禁言设置 muteType : 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    private func setMuteTypeRequest(muteType: Int) {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().updateMuteType(serverUrl: serverUrl, groupId: self.groupId, muteType: muteType) { [weak self] _ in
            guard let strongSelf = self, let _ = strongSelf.groupDetailInfo else { return }
            strongSelf.hideProgress()
            strongSelf.groupDetailInfo?.muteType = muteType
            strongSelf.chatLimitSwitch.isOn = muteType == 1 ? true : false
        } failureBlock: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("修改全员禁言状态失败")
        }
    }
    
    /// 更新群内加好友设置 friendType : 加好友限制， 0=群内可加好友，1=群内禁止加好友
    private func updateFriendType(friendType: Int) {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().updateFriendType(serverUrl: serverUrl, groupId: self.groupId, friendType: friendType) { [weak self] _ in
            guard let strongSelf = self, let _ = strongSelf.groupDetailInfo else { return }
            strongSelf.hideProgress()
            strongSelf.groupDetailInfo?.friendType = friendType
            // 加好友限制
            strongSelf.addFriendLab.text = info.friendType == 0 ? "可加好友" : "禁止加好友"
        } failureBlock: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("修改全员禁言状态失败")
        }
    }
    
    // 更新加群设置 joinType : 加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群
    private func updateJoinType(joinType: Int) {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().updateJoinType(serverUrl: serverUrl, groupId: self.groupId, joinType: joinType) { [weak self] _ in
            guard let strongSelf = self, let _ = strongSelf.groupDetailInfo else { return }
            strongSelf.hideProgress()
            strongSelf.groupDetailInfo?.friendType = joinType
            // 加群限制
            strongSelf.addGroupLab.text = info.joinType == 0 ? "无需审批" : "群主和管理员邀请加群"
        } failureBlock: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("修改全员禁言状态失败")
        }
    }
    
    // 转让群
    private func updateGroupOwner(memberId: String) {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().updateGroupOwner(serverUrl: serverUrl, groupId: self.groupId, memberId: memberId) { [weak self] _ in
            guard let strongSelf = self, let _ = strongSelf.groupDetailInfo else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("转让群成功")
            strongSelf.reloadViewData()
        } failureBlock: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("修改全员禁言状态失败")
        }
    }
    
    /// 接口获取群信息
    private func getGroupDetailInfoRequest() {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl else {
            return
        }
        self.showProgress(with: nil)
        GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: info.id) { [weak self] (group) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.groupDetailInfo = group
            
            // 获取群成员列表请求
            strongSelf.getGroupMemberListRequest()
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            
            let error = error as NSError
            strongSelf.showToast(error.localizedDescription)
        }
    }
    
    /// 解散群接口请求
    private func dibandGroupAction() {
        guard let info = self.groupDetailInfo, let chatServerUrl = info.chatServerUrl else { return }
        self.showProgress()
        GroupManager.shared().disbandGroup(serverUrl: chatServerUrl, groupId: info.id) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            APP.shared().showToast("您已成功解散该群聊!")
            
            strongSelf.navigationController?.popToRootViewController(animated: true)
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("请求失败，请稍后再试")
        }
    }

    /// 退群接口请求
    private func exitGroupAction() {
        guard let info = self.groupDetailInfo, let chatServerUrl = info.chatServerUrl else { return }
        self.showProgress()
        GroupManager.shared().exitGroup(serverUrl: chatServerUrl, groupId: info.id) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            APP.shared().showToast("您已成功退出该群聊!")
            
            strongSelf.navigationController?.popToRootViewController(animated: true)
            
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast("请求失败，请稍后再试")
        }
    }
}

enum FZMGroupDetailUserViewModelType {
    case person//用户
    case invite//邀请
    case remove//移除
}

class FZMGroupDetailUserViewModel : NSObject {
    var name = ""
    var avatar = ""
    var memberId = ""
    var groupId = 0
    var type : FZMGroupDetailUserViewModelType
    
    init(with member: GroupMember) {
        type = .person
        name = member.contactsName
        avatar = member.avatarURLStr
        memberId = member.memberId
        groupId = member.groupId
        super.init()
    }
    
    init(with type: FZMGroupDetailUserViewModelType) {
        self.type = type
        super.init()
    }
}


