//
//  FZMGroupEditNameVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/30.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import SwifterSwift

class FZMGroupEditNameVC: UIViewController, ViewControllerProtocol {

    let group : Group
    let oldName : String
    var oldPublicName: String?// 公开群名
    
    let editNickname : Bool // true:修改自己的群昵称 false:修改群名
    
    var completeBlock: NormalBlock?
    
    private let disposeBag = DisposeBag.init()
    
    lazy var remarkBlockView : UIView = {
        let view = UIView()
//        view.makeOriginalShdowShow()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        let titleLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: editNickname ? "群昵称" : "加密群名")
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(7)
            m.height.equalTo(23)
        })
        view.addSubview(remarkNumLab)
        remarkNumLab.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(7)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(17)
        })
        view.addSubview(remarkInput)
        remarkInput.snp.makeConstraints({ (m) in
            m.left.equalTo(titleLab)
            m.right.equalToSuperview()
            m.bottom.equalToSuperview()
            m.height.equalTo(40)
        })
        return view
    }()
    
    lazy var remarkBlockViewB : UIView = {
        let view = UIView()
//        view.makeOriginalShdowShow()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        let titleLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "公开群名")
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(7)
            m.height.equalTo(23)
        })
        view.addSubview(remarkNumLabB)
        remarkNumLabB.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(7)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(17)
        })
        view.addSubview(remarkInputB)
        remarkInputB.snp.makeConstraints({ (m) in
            m.left.equalTo(titleLab)
            m.right.equalToSuperview()
            m.bottom.equalToSuperview()
            m.height.equalTo(40)
        })
        
        return view
    }()
    
    lazy var remarkNumLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .right, text: "0/20")
        return lab
    }()
    
    lazy var remarkNumLabB : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .right, text: "0/20")
        return lab
    }()
    
    lazy var remarkInput : UITextField = {
        let input = UITextField()
        input.font = UIFont.regularFont(16)
        input.textColor = Color_24374E
        input.tintColor = Color_Theme
        input.attributedPlaceholder = NSAttributedString(string: editNickname ? "请输入你在本群的昵称" : "请输入群名", attributes: [.foregroundColor:Color_8A97A5])
        return input
    }()
    
    lazy var remarkInputB : UITextField = {
        let input = UITextField()
        input.font = UIFont.regularFont(16)
        input.textColor = Color_24374E
        input.tintColor = Color_Theme
        input.attributedPlaceholder = NSAttributedString(string: "请输入公开群名", attributes: [.foregroundColor:Color_8A97A5])
        return input
    }()
    
    lazy var confirmBtn : UIButton = {
        let btn = UIButton.getNormalBtn(with: "确定")
        return btn
    }()
    
    init(with group: Group, _ name: String, _ editUser: Bool = false) {
        self.group = group
        self.oldName = name
        if !editUser {
            self.oldPublicName = group.publicName
        }
        self.editNickname = editUser
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.title = editNickname ? "我在本群的昵称" : "修改群名"
        
        self.view.backgroundColor = .white
//        self.xls_navigationBarBackgroundColor = Color_F6F7F8
//        self.xls_navigationBarTintColor = Color_F6F7F8
        
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(popBack))
        
        self.createUI()
    }
    
    @objc private func popBack() {
        self.navigationController?.popViewController()
    }
    
    private func createUI() {
        self.view.addSubview(remarkBlockView)
        remarkBlockView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(15)
            m.width.equalTo(k_ScreenWidth - 30.0)
            m.height.equalTo(80)
        }
        if !editNickname {
            self.view.addSubview(remarkBlockViewB)
            remarkBlockViewB.snp.makeConstraints { (m) in
                m.centerX.equalToSuperview()
                m.top.equalTo(remarkBlockView.snp.bottom).offset(15)
                m.width.equalTo(k_ScreenWidth - 30.0)
                m.height.equalTo(80)
            }
            
            let titleLabB = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "加密群名仅群成员可见")
            self.view.addSubview(titleLabB)
            titleLabB.snp.makeConstraints { make in
                make.left.equalToSuperview().offset(15)
                make.top.equalTo(remarkInputB.snp.bottom).offset(15)
            }
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
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth - 30 , height: 40))
        }
        
        confirmBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.commitInfo()
            }.disposed(by: disposeBag)
        
        remarkInput.rx.text.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.remarkInput.limitText(with: 20)
            if let text = strongSelf.remarkInput.text, text.count > 0 {
                strongSelf.remarkNumLab.text = "\(text.count)/20"
            }else {
                strongSelf.remarkNumLab.text = "0/20"
            }
        }.disposed(by: disposeBag)
        remarkInput.text = oldName
        remarkNumLab.text = "\(oldName.count)/20"
        remarkInput.addToolBar(with: "确定", target: self, sel: #selector(FZMGroupEditNameVC.commitInfo))
        
        
        if !editNickname {
            remarkInputB.rx.text.subscribe {[weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.remarkInputB.limitText(with: 20)
                if let text = strongSelf.remarkInputB.text, text.count > 0 {
                    strongSelf.remarkNumLabB.text = "\(text.count)/20"
                }else {
                    strongSelf.remarkNumLabB.text = "0/20"
                }
            }.disposed(by: disposeBag)
            let oldPubname = oldPublicName ?? ""
            remarkInputB.text = oldPubname
            remarkNumLabB.text = "\(oldPubname.count)/20"
            remarkInputB.addToolBar(with: "确定", target: self, sel: #selector(FZMGroupEditNameVC.commitInfo))
        }
    }
    
    @objc private func commitInfo() {
        self.view.endEditing(true)
        guard let serverUrl = group.chatServerUrl else {
            self.showToast("群聊服务器地址为空")
            return
        }
        guard let name = remarkInput.text, !name.isBlank else {
            let msg = editNickname ? "请输入昵称" : "请输入加密群名"
            self.showToast(msg)
            return }
        
        if editNickname {
            self.showProgress()
            // 修改我在本群的昵称
            GroupManager.shared().updateGroupMemberName(serverUrl: serverUrl, groupId: group.id, memberName: name) { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.completeBlock?()
                strongSelf.popBack()
            } failureBlock: { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.showToast("修改群昵称失败")
            }
        }else {
            guard var pubName = remarkInputB.text, !pubName.isBlank else {
                self.showToast("请输入公开群名")
                return
            }
            // 加密群名
            guard let key = group.key else {
                self.showToast("群私钥缺失")
                return
            }
            var finalName = EncryptManager.encryptGroupName(name, key: key)
            guard !finalName.isBlank else {
                self.showToast("加密群名失败")
                return
            }
            if pubName == group.publicName, name == group.name {
                self.showToast("加密群名和公开群名没变哦~")
                return
            }
            if pubName == group.publicName {
                pubName = ""
            }
            if name == group.name {
                finalName = ""
            }
            
            self.showProgress()
            // 修改群名
            GroupManager.shared().updateGroupName(serverUrl: serverUrl, groupId: group.id, name: finalName, publicName: pubName) { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                
                strongSelf.completeBlock?()
                strongSelf.popBack()
            } failureBlock: { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.showToast("修改群名失败")
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

