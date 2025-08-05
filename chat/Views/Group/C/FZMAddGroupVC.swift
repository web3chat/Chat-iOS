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
        let btn = UIButton.getNormalBtn(with: "进入群聊", backgroundColor: Color_Theme)
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
        self.title = "详细资料"
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
            print("进入群聊")
            if let group = GroupManager.shared().getDBGroup(by: strongSelf.groupId) {
                if group.isInGroup {
                    //去群聊页面
                    FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(group.address), locationMsg: nil))
                } else {
                    // 申请加入群聊
                    strongSelf.joinGroupRequest()
                }
            } else {
                if let groupinfo = strongSelf.groupDetailInfo {
                    if let personId = groupinfo.person?.memberId,personId.count > 0 {
                        // 在群，进入群聊页面
                        FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(groupinfo.address), locationMsg: nil))
                    } else {
                        // 群公共信息内没有个人信息-没有加入此群
                        self?.joinGroupRequest()
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
        numberLab.text = "群号 " + info.markId!
        
//        // 群成员数量
//        memberslab.text = "共\(info.memberNum)人"
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
                
        } failureBlock: { (error) in
            self.showToast(error.localizedDescription)
        }
        
    }
    
    private func getGroupInfo() {
        GroupManager.shared().getGroupInfo(serverUrl: self.groupDetailInfo?.chatServerUrl ?? "", groupId: self.groupId) { [weak self] (group) in
            //直接进去群聊界面
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.group(strongSelf.groupDetailInfo!.address), locationMsg: nil))
            }
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.showToast("查询群信息失败")
        }
    }
}

