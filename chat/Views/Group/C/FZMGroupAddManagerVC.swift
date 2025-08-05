//
//  FZMGroupAddManagerVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/30.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

enum FZMGroupSetType {
    case manager //设置为管理员
    case owner //设置为群主
}

class FZMGroupAddManagerVC: FZMGroupMemberListVC {

    private let showType : FZMGroupSetType
    var addBlock : ((ContactViewModel)->())?
    
    init(with group: Group, type: FZMGroupSetType = .manager) {
        showType = type
        super.init(with: group,fromTag: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItems?.remove(at: 0)
        if showType == .owner {
            self.navigationItem.title = "转让群主"
        }else {
            self.navigationItem.title = "添加管理员"
        }
    }
    
    override func deal(with list: [GroupMember]) {
        self.view.showProgress()
        DispatchQueue.global().async {
            var list = list
            // 用户角色，2=群主，1=管理员，0=群员，10=退群
            if self.showType == .owner {
                list = list.filter { $0.memberType != 2 }
            }else {
                list = list.filter { $0.memberType == 0 }
            }
            
            self.dealtList = UserManager.shared().divideGroupMember(list)
            self.memberList = self.dealtList
            
            DispatchQueue.main.async {
                self.view.hideProgress()
                
                self.reloadData()
            }
        }
    }
}

extension FZMGroupAddManagerVC {
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.memberList.count else { return nil }
        let model = self.memberList[section]
        let array = model.value
        let title = "\(model.title)(\(array.count)人)"
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text: "       " + title)
        lab.backgroundColor = Color_FFFFFF
        return lab
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.memberList.count,
              indexPath.row < self.memberList[indexPath.section].value.count else {
            return
        }
        let member = memberList[indexPath.section].value[indexPath.row]
        let block = {
            guard let serverUrl = self.group.chatServerUrl else { return }
            self.showProgress(with: nil)
            
            if self.showType == .manager {
                // 设置管理员 用户角色 0=群员, 1=管理员
                GroupManager.shared().updateMemberType(serverUrl: serverUrl, groupId: self.group.id, memberId: member.sessionIDStr, memberType: 1) { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.hideProgress()
                    strongSelf.showToast("管理员设置成功")
                    DispatchQueue.main.async {
                        strongSelf.addBlock?(member)
                    }
                    strongSelf.navigationController?.popViewController()
                } failureBlock: { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.hideProgress()
                    strongSelf.showToast("管理员设置失败")
                }
            } else {
                // 转让群主
                GroupManager.shared().updateGroupOwner(serverUrl: serverUrl, groupId: self.group.id, memberId: member.sessionIDStr) { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.hideProgress()
                    strongSelf.showToast("转让群主设置成功")
                    
                    DispatchQueue.main.async {
                        strongSelf.reloadBlock?()
                    }
                    strongSelf.navigationController?.popViewController()
                } failureBlock: { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.hideProgress()
                    strongSelf.showToast("转让群主设置失败")
                }

            }
        }
        if showType == .manager {
            block()
        }else if showType == .owner {
            let alert = TwoBtnInfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.leftBtnTitle = "取消"
            alert.rightBtnTitle = "确定"
            let alias = member.name
            let str = "确定将群主转让给 \(alias) 吗?"
            let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
            attStr.addAttributes([NSAttributedString.Key.foregroundColor: Color_Theme], range:(str as NSString).range(of: alias as String))
            alert.attributedInfo = attStr
            alert.leftBtnTouchBlock = {}
            alert.rightBtnTouchBlock = {
                block()
            }
            alert.show()
        }
    }
}
