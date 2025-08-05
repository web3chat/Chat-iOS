//
//  BannedAlertView.swift
//  chat
//
//  Created by liyaqin on 2021/10/29.
//

import Foundation
import UIKit
import sqlcipher

class BannedAlertView : UIView {
    private let groupId : Int
    private let userId : String
    private var group: Group?
    private var userInfo : GroupMember?
    var selectIndex = 0
    var completeBlock : (()->())?
    var cancelBlock : (()->())?
    
    lazy var conterView : UIView = {
        let v = UIView()
        v.backgroundColor = Color_FFFFFF
        v.clipsToBounds = true
        v.layer.cornerRadius = 5
        
        let cancelBtn = UIButton(type: .custom)
        cancelBtn.setAttributedTitle(NSAttributedString(string: "取消", attributes: [.font:UIFont.mediumFont(16),.foregroundColor:Color_Theme]), for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelClick), for: .touchUpInside)
        v.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints({ (m) in
            m.bottom.left.equalToSuperview()
            m.right.equalTo(v.snp.centerX)
            m.height.equalTo(50)
        })
        let confirmBtn = UIButton(type: .custom)
        confirmBtn.setAttributedTitle(NSAttributedString(string: "确定", attributes: [.font:UIFont.mediumFont(16),.foregroundColor:Color_Theme]), for: .normal)
        confirmBtn.addTarget(self, action: #selector(confirmClick), for: .touchUpInside)
        v.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints({ (m) in
            m.bottom.right.equalToSuperview()
            m.left.equalTo(v.snp.centerX)
            m.height.equalTo(50)
        })
        let bottomLine = UIView.getNormalLineView()
        v.addSubview(bottomLine)
        bottomLine.snp.makeConstraints({ (m) in
            m.top.equalTo(confirmBtn)
            m.left.right.equalToSuperview()
            m.height.equalTo(1)
        })
        let centerLine = UIView.getNormalLineView()
        v.addSubview(centerLine)
        centerLine.snp.makeConstraints({ (m) in
            m.top.bottom.equalTo(confirmBtn)
            m.centerX.equalToSuperview()
            m.width.equalTo(1)
        })
        
        v.addSubview(timeView)
        timeView.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.bottom.equalTo(bottomLine.snp.top).offset(-30)
            m.size.equalTo(CGSize(width: 260, height: 110))
        })
        
        v.addSubview(timeTitleView)
        timeTitleView.snp.makeConstraints({ (m) in
            m.bottom.equalTo(timeView.snp.top).offset(-15)
            m.left.right.equalToSuperview()
        })
        v.addSubview(titleView)
        titleView.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(30)
            m.left.equalToSuperview().offset(24)
            m.right.equalToSuperview().offset(-24)
        })
        v.addSubview(cancelCtrlBtn)
        cancelCtrlBtn.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(81)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(50)
        })
        cancelCtrlBtn.isHidden = true
        
        return v
    }()
    
    lazy var timeView : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: 80, height: 50)
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.isScrollEnabled = false
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = UIColor.clear
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "TimeViewCell")
        return view
    }()
    
    lazy var timeTitleView : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_24374E, textAlignment: .center, text: nil)
        return lab
    }()

    lazy var titleView : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .center, text: nil)
        lab.numberOfLines = 0
        return lab
    }()

    lazy var cancelCtrlBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 5
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_8A97A5.cgColor
        btn.setTitleColor(Color_24374E, for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(16)
        btn.addTarget(self, action: #selector(cancelCtrlUser), for: .touchUpInside)
        return btn
    }()
    
    let timeArr : [[String:Any]] = [["title":"永远","number": Int(k_OnedaySeconds) * 30],["title":"24小时","number":Int(k_OnedaySeconds)],["title":"10小时","number":36000],["title":"2小时","number":7200],["title":"30分钟","number":1800],["title":"10分钟","number":600],]
    
    init(with userId: String, groupId: Int){
        self.groupId = groupId
        self.group = GroupManager.shared().getDBGroup(by: groupId)
        self.userId = userId
        super.init(frame: k_ScreenBounds)
        self.backgroundColor = UIColor.init(white: 0, alpha: 0.5)
        self.addSubview(conterView)
        conterView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.width.equalTo(300)
            m.height.equalTo(310)
        }
        
        self.getUserInfo(with: userId, groupId: groupId)
    }
    
    
    
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BannedAlertView {
    func show() {
        UIApplication.shared.keyWindow?.addSubview(self)
    }
    
    @objc func cancelClick() {
        self.hide()
    }
    
    @objc func confirmClick(){
        let dic = timeArr[selectIndex]
        var number = dic["number"] as! Int * 1000
        if selectIndex == 0 {
            number = k_ForverBannedTime
        }
        
        guard let serverUrl = self.group?.chatServerUrl else { return }
        self.showProgress(with: nil)
        GroupManager.shared().updateMemberMuteTime(serverUrl: serverUrl, groupId: groupId, muteTime: number, memberIds: [self.userId]) { _ in
            self.hideProgress()
            self.showToast("设置成功")
            self.completeBlock?()
            self.hide()
        } failureBlock: { (error) in
            self.hideProgress()
            self.showToast(error.localizedDescription)
        }
    }
    
    @objc func cancelCtrlUser(){
        guard let serverUrl = self.group?.chatServerUrl else { return }
        self.showProgress(with: nil)
        GroupManager.shared().updateMemberMuteTime(serverUrl: serverUrl, groupId: groupId, muteTime: 0, memberIds: [self.userId]) { _ in
            self.hideProgress()
            self.showToast("设置成功")
            self.cancelBlock?()
            self.hide()
        } failureBlock: { (error) in
            self.hideProgress()
            self.showToast(error.localizedDescription)
        }
        
    }
    
    private func getUserInfo(with userId : String, groupId: Int) {
        guard let serverUrl = self.group?.chatServerUrl else {
            return
        }
        
        GroupManager.shared().getGroupMemberInfo(serverUrl: serverUrl, groupId: groupId, memberId: userId) {[weak self] member in
            guard let strongSelf = self else { return }
            strongSelf.userInfo = member
            strongSelf.reloadView()
        } failureBlock: { error in
            self.showToast(error.localizedDescription)
        }

    }
    
    func reloadView() {
        guard let userInfo = self.userInfo else { return }
        if userInfo.memberMuteTime > Date.timestamp {
            conterView.snp.updateConstraints { (m) in
                m.height.equalTo(370)
            }
            let distance = (userInfo.memberMuteTime - Date.timestamp)
            self.popAnimation(time: Double(distance)/1000,name: userInfo.contactsName)
            timeTitleView.text = "更改禁言时间"
            cancelCtrlBtn.isHidden = false
            cancelCtrlBtn.setTitle("取消禁言", for: .normal)
        }else{
            let attrStr = NSMutableAttributedString(string: "确定将 ")
            attrStr.append(NSAttributedString(string: userInfo.contactsName, attributes: [.foregroundColor:Color_Theme]))
            attrStr.append(NSAttributedString(string:" 禁言吗？"))
            titleView.attributedText = attrStr
            
            timeTitleView.text = "选择禁言时间"
        }
        
    }
    
    
    private func popAnimation(time:Double,name:String){
        if time < k_OnedaySeconds {
            let formatter = DateFormatter.getDataformatter()
            formatter.dateFormat = "HH:mm:ss"
            let attrStr = NSMutableAttributedString(string: name, attributes: [.foregroundColor:Color_Theme])
            attrStr.append(NSAttributedString(string: "禁言"))
            FZMAnimationTool.countdown(with: titleView, fromValue: time, toValue: 0, block: { [weak self] (useTime) in
                let time = useTime - 8 * 3600
                let date = Date.init(timeIntervalSince1970: TimeInterval(time))
                let mutAttStr = attrStr.mutableCopy() as! NSMutableAttributedString
                mutAttStr.append(NSAttributedString(string: formatter.string(from: date)))
                self?.titleView.attributedText = mutAttStr
                },finishBlock: {[weak self] in
                    self?.hide()
            })
        }else{
            let attrStr = NSMutableAttributedString(string: name, attributes: [.foregroundColor:Color_Theme])
            attrStr.append(NSAttributedString(string: "永远禁言"))
            self.titleView.attributedText = attrStr
        }
    }
    
    func hide() {
        self.removeFromSuperview()
    }
    
}


extension BannedAlertView:UICollectionViewDelegate,UICollectionViewDataSource{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return timeArr.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TimeViewCell", for: indexPath)
        cell.contentView.layer.cornerRadius = 10
        cell.contentView.layer.borderColor = Color_24374E.cgColor
        cell.contentView.layer.borderWidth = 1
        cell.contentView.backgroundColor = UIColor.clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        guard indexPath.item < timeArr.count else {
            return cell
        }
        let dic = timeArr[indexPath.item]
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .center, text: dic["title"] as? String)
        cell.contentView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        if selectIndex == indexPath.item {
            lab.textColor = UIColor.white
            cell.contentView.backgroundColor = Color_Theme
            cell.contentView.layer.borderColor = Color_Theme.cgColor
        }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectIndex = indexPath.item
        collectionView.reloadData()
    }
}
