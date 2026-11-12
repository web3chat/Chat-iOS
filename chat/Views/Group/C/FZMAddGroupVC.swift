//
//  FZMAddGroupVC.swift
//  chat
//
//  Created by liyaqin on 2021/10/9.
//

import Foundation
import UIKit
import SwiftUI
import SnapKit

class FZMAddGroupVC: UIViewController, ViewControllerProtocol {
    
    private let disposeBag = DisposeBag.init()
    
    private let groupId : Int// 群id
    private let inviterId : String//邀请人id
    private var inviterIsManager = false// 邀请人是否是群主/管理员
    private var hasApplied = false// 是否已提交入群申请（需要审批的群）
    private var groupDetailInfo: Group?{
        didSet{
            DispatchQueue.main.async {
                self.refreshView()
            }
        }
    }
    
    lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(17), textColor: Color_24374E, textAlignment: .left, text: "")
        lab.numberOfLines = 0
        lab.minimumScaleFactor = 0.5
        return lab
    }()
    
    lazy var numberLab : UILabel = {
        return UILabel.getLab(font: UIFont.mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")
    }()
    
//    lazy var memberslab : UILabel = {
//        return UILabel.getLab(font: UIFont.boldFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")
//    }()
    
    lazy var addGroupBtn : UIButton = {
        let btn = UIButton.getNormalBtn(with: L("进入群聊"), backgroundColor: Color_Theme)
        btn.layer.cornerRadius = 20
        return btn
    }()
    
    init(with groupId:Int, inviterId:String){
        self.groupId = groupId
        self.inviterId = inviterId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.createUI()
        self.title = L("详细资料")
        self.getGroupPubInfoRequest(groupId: self.groupId)
    }
    
    private func createUI() {
        self.view.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(20)
            m.size.equalTo(50)
        }
        
        self.view.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(15)
            m.top.equalTo(headerImageView)
            m.right.equalToSuperview().offset(-15)
            m.height.greaterThanOrEqualTo(20)
        }
        nameLab.numberOfLines = 2
        
        self.view.addSubview(numberLab)
        numberLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(15)
            m.top.equalTo(nameLab.snp.bottom).offset(5)
            m.right.equalToSuperview().offset(-15)
            m.height.greaterThanOrEqualTo(20)
        }
        
//        self.view.addSubview(memberslab)
//        memberslab.snp.makeConstraints { (m) in
//            m.left.equalTo(headerImageView.snp.right).offset(15)
//            m.top.equalTo(numberLab.snp.bottom).offset(5)
//            m.right.equalTo(self.view).offset(-15)
//        }
        
        self.view.addSubview(addGroupBtn)
        addGroupBtn.snp.makeConstraints { (m) in
//            m.top.equalTo(memberslab.snp.bottom).offset(30)
            m.top.equalTo(numberLab.snp.bottom).offset(30)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(40)
        }
        
        addGroupBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            if let group = GroupManager.shared().getDBGroup(by: strongSelf.groupId) {
                if group.isInGroup {
                    //去群聊页面
                    FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(group.address), locationMsg: nil))
                } else {
                    // 加群（是否需要审批由加群方式决定）
                    strongSelf.handleJoinAction()
                }
            } else {
                if let groupinfo = strongSelf.groupDetailInfo {
                    if let personId = groupinfo.person?.memberId,personId.count > 0 {
                        // 在群，进入群聊页面
                        FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(groupinfo.address), locationMsg: nil))
                    } else {
                        // 群公共信息内没有个人信息-没有加入此群
                        strongSelf.handleJoinAction()
                    }
                    
                }else{
                    // 没有群信息，再次获取
                    strongSelf.getGroupPubInfoRequest(groupId: strongSelf.groupId)
                }
            }
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
        var publicName = info.publicName
        if publicName.isBlank {
            publicName = String(info.id)
        }
        
        if info.isInGroup {
            nameLab.text = publicName
        }else{
            if info.person?.memberType == 1 || info.person?.memberType == 2 {
                nameLab.attributedText = publicName.jointImage(image: #imageLiteral(resourceName: "me_edit"))
            } else {
                nameLab.text = publicName
            }
        }
        // 群号
        numberLab.text = L("群号 ") + info.markId!
        
//        // 群成员数量
//        memberslab.text = "共\(info.memberNum)人"
        
        // 加群按钮状态（加入群聊 / 申请入群 / 禁止加群）
        self.refreshAddGroupBtn()
    }
    
    private func getGroupPubInfoRequest(groupId: Int) {
        LoginUser.shared().chatServerGroups.forEach { (chatServerItem) in
            GroupManager.shared().getGroupPubInfo(serverUrl: chatServerItem.value, groupId: groupId) {[weak self] (group) in
                guard let strongSelf = self else { return }
                strongSelf.groupDetailInfo = group
            } failureBlock: { (_) in
//            } failureBlock: { [weak self] (error) in
//                guard let strongSelf = self else { return }
//                strongSelf.showToast("获取群聊信息失败")
            }
        }
    }
    
    private func joinGroupRequest(){
        GroupManager.shared().joinGroup(serverUrl: self.groupDetailInfo?.chatServerUrl ?? "", groupId: self.groupId, inviterId: self.inviterId) {[weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.getGroupInfo()
                
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            let code = (error as NSError).code
            if code == -10029 {// 你已在本群中 → 直接进会话
                strongSelf.getGroupInfo()
                return
            }
            strongSelf.showToast(error.localizedDescription)
        }
        
    }
    
    private func getGroupInfo() {
        let serverUrl = self.groupDetailInfo?.chatServerUrl ?? ""
        let address = self.groupDetailInfo?.address ?? String(self.groupId)
        GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: self.groupId) { [weak self] (_) in
            //直接进去群聊界面
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                let sessionId = SessionID.group(strongSelf.groupDetailInfo?.address ?? address)
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: sessionId, locationMsg: nil))
            }
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.showToast(L("查询群信息失败"))
        }
    }
    
    // MARK: - 加群（加群方式 joinType：0=无需审批 1=禁止加群 2=需要审批）
    /// 刷新加群按钮状态
    private func refreshAddGroupBtn() {
        guard let info = self.groupDetailInfo else { return }
        
        // 邀请人是否是群主/管理员（决定禁止加群的群里能不能直接进）
        self.inviterIsManager = info.isManager(with: self.inviterId)
        
        var title = L("加入群聊")
        var enabled = true
        
        // 是否已在群：本地有群信息以本地为准（群公开信息里的 isInGroup 默认是 true，不可直接使用）
        var isInGroup = false
        if let dbGroup = GroupManager.shared().getDBGroup(by: self.groupId) {
            isInGroup = dbGroup.isInGroup
        } else {
            isInGroup = !(info.person?.memberId ?? "").isBlank
        }
        if isInGroup {
            title = L("进入群聊")
            self.hasApplied = false
        } else if self.hasApplied {
            title = L("已申请，等待审核")
            enabled = false
        } else {
            switch info.joinType {
            case 1:// 仅群主/管理员可邀请
                if !self.inviterIsManager {
                    title = L("仅管理员邀请")
                    enabled = false
                }
            case 2:// 群外用户需要申请，群主/管理员拉人直接进群
                if !self.inviterIsManager {
                    title = L("申请入群")
                }
            default:
                break
            }
        }
        
        self.addGroupBtn.isEnabled = enabled
        self.addGroupBtn.layer.backgroundColor = (enabled ? Color_Theme : Color_CCD1E0).cgColor
        self.addGroupBtn.setAttributedTitle(NSAttributedString(string: title, attributes: [.foregroundColor: UIColor.white, .font: UIFont.regularFont(16)]), for: .normal)
    }
    
    /// 加群按钮点击：按加群方式决定直接进群 / 提交申请 / 禁止加群
    private func handleJoinAction() {
        guard let info = self.groupDetailInfo else {
            // 群信息还没拿到，重新获取
            self.getGroupPubInfoRequest(groupId: self.groupId)
            return
        }
        
        switch info.joinType {
        case 1:// 仅群主/管理员可邀请
            guard self.inviterIsManager else {
                self.showToast(L("仅管理员邀请"))
                return
            }
        case 2:// 群外用户需要申请，群主/管理员拉人直接进群
            guard self.inviterIsManager else {
                self.createGroupApplyRequest()
                return
            }
        default:
            break
        }
        
        self.joinGroupRequest()
    }
    
    /// 提交入群申请（joinType == 2「入群需审核」）
    private func createGroupApplyRequest() {
        guard let info = self.groupDetailInfo, let serverUrl = info.chatServerUrl, !serverUrl.isBlank else {
            return
        }
        self.showProgress(with: L("正在申请"))
        GroupManager.shared().createGroupApply(serverUrl: serverUrl, groupId: self.groupId, applyNote: "") { [weak self] (json) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            FZMLog("提交入群申请成功 - \(json)")
            strongSelf.hasApplied = true
            strongSelf.showToast(L("已申请，等待审核"))
            strongSelf.refreshAddGroupBtn()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            let code = (error as NSError).code
            if code == -10029 {// 你已在本群中 → 直接进会话
                strongSelf.showToast(error.localizedDescription)
                strongSelf.getGroupInfo()
            } else {
                strongSelf.showToast(GroupManager.applyFailureMessage(error))
            }
        }
    }
}

