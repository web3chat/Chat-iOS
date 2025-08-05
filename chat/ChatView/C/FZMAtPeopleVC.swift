//
//  FZMAtPeopleVC.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/9.
//

import Foundation
import RxSwift
import SnapKit

class FZMAtPeopleVC: FZMGroupMemberListVC {
    private let disposeBag = DisposeBag.init()
    
    private lazy var allNumberLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: "所有人(\(group.memberNum))")
        return lab
    }()
    
    // @所有人 视图
    override var headerView: UIView {
        get {
//            if let persion = group.person, persion.memberType == 0 {// 普通群成员不能 @所有人
//                return UIView.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
//            }
            let v = UIView.init(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 50))
            let imV = UIImageView(image: #imageLiteral(resourceName: "at_all_prople"))
            imV.layer.cornerRadius = 5
            imV.clipsToBounds = true
            imV.contentMode = .scaleAspectFill
            imV.isUserInteractionEnabled = true
            v.addSubview(imV)
            imV.snp.makeConstraints { (m) in
                m.centerY.equalToSuperview()
                m.left.equalToSuperview().offset(15)
                m.size.equalTo(CGSize(width: 35, height: 35))
            }
            v.addSubview(allNumberLab)
            allNumberLab.snp.makeConstraints { (m) in
                m.centerY.equalToSuperview()
                m.left.equalTo(imV.snp.right).offset(11)
            }
            let tap = UITapGestureRecognizer.init()
            tap.rx.event.subscribe({[weak self] (_) in
                self?.select(uid: "ALL", name: "所有人")
            }).disposed(by: disposeBag)
            v.addGestureRecognizer(tap)
            return v
        }
        set {}
    }
    
    var selectedBlock: ((String, String) -> ())?
    var cancelBlock: (() -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "选择成员"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelClick))
        self.navigationItem.rightBarButtonItems?.remove(at: 0)
    }
    
    override func deal(with list: [GroupMember]) {
        self.allNumberLab.text = "所有人(\(list.count))"
        
        self.view.showProgress()
        DispatchQueue.global().async {
            let list = list.filter({ return $0.memberId != LoginUser.shared().address})// 排除自己
            
            self.dealtList = UserManager.shared().normalGroupMember(list)
            self.memberList = self.dealtList
            
            DispatchQueue.main.async {
                self.view.hideProgress()
                
                self.reloadData()
            }
        }
    }
    
    @objc private func cancelClick() {
        self.dismiss(animated: true, completion: nil)
        self.cancelBlock?()
    }
    
    private func select(uid: String, name: String) {
        guard !uid.isEmpty && !name.isEmpty else { return }
        self.dismiss(animated: true, completion: nil)
        self.selectedBlock?(uid, name)
    }
}

extension FZMAtPeopleVC {
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.memberList.count else { return nil }
        let model = self.memberList[section]
        var title = ""
        if !self.isSearch{
            title = section == 0 ? "群主、管理员" : "\(model.title)"
        }else{
            title = "\(model.title)"
        }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text: "       " + title)
        lab.backgroundColor = Color_FFFFFF
        return lab
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.memberList.count,
              indexPath.row < self.memberList[indexPath.section].value.count else {
            return
        }
        let model = memberList[indexPath.section].value[indexPath.row]
        let name = model.groupMember?.atName ?? model.sessionIDStr
        self.select(uid: model.sessionIDStr, name: name)
    }
}
