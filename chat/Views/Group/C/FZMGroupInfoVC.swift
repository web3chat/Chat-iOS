//
//  FZMGroupInfoVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/31.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

class FZMGroupInfoVC: FZMBaseViewController {

    let group : IMSearchInfoModel
    let type : FZMApplyEntrance
    
    private var inGroup = false
    
    lazy var identificationImageView: UIImageView = {
        let imgV = UIImageView(image: GetBundleImage("group_identification"))
        imgV.isUserInteractionEnabled = true
        imgV.contentMode = .scaleAspectFill
        imgV.isHidden = true
        return imgV
    }()
    lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.isUserInteractionEnabled = true
        imV.contentMode = .scaleAspectFill
        imV.addSubview(identificationImageView)
        identificationImageView.snp.makeConstraints({ (m) in
            m.size.equalTo(CGSize.init(width: 15, height: 15))
            m.bottom.right.equalToSuperview()
        })
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(17), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    lazy var desLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()
    
    private lazy var identificationInfoLab : UILabel = {
        let lab = UILabel.init()
        lab.textAlignment = .left
        lab.numberOfLines = 0
        lab.isUserInteractionEnabled = true
        return lab
    }()
    
    lazy var nickNameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()
    
    
    lazy var addBtn : UIButton = {
        let btn = UIButton.getNormalBtn(with: "申请入群")
        return btn
    }()
    
    
    init(with group: IMSearchInfoModel, type: FZMApplyEntrance) {
        self.group = group
        self.type = type
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.navigationItem.title = "群信息"
        self.createUI()
        self.setupActions()
        self.refreshView()
    }
    
    private func createUI() {
        self.view.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(10)
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 50, height: 50))
        }
        self.view.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.top.equalTo(headerImageView)
            m.left.equalTo(headerImageView.snp.right).offset(15)
            m.right.lessThanOrEqualToSuperview().offset(-20)
        }
        self.view.addSubview(desLab)
        desLab.snp.makeConstraints { (m) in
            m.top.equalTo(nameLab.snp.bottom).offset(5)
            m.left.equalTo(nameLab)
        }
        self.view.addSubview(nickNameLab)
        nickNameLab.snp.makeConstraints { (m) in
            m.top.equalTo(desLab.snp.bottom).offset(5)
            m.left.equalTo(desLab)
            m.height.equalTo(20)
        }
        self.view.addSubview(identificationInfoLab)
        identificationInfoLab.snp.makeConstraints { (m) in
            m.top.equalTo(nickNameLab.snp.bottom).offset(5)
            m.left.equalTo(nickNameLab)
            m.right.equalToSuperview().offset(-16)
        }
        self.view.addSubview(addBtn)
        addBtn.snp.makeConstraints { (m) in
            m.top.equalTo(identificationInfoLab.snp.bottom).offset(25)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(40)
        }
    }
    
    private func setupActions() {
        addBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            
            if IMSDK.shared().isEncyptChat &&
                strongSelf.group.isEncrypt &&
                ((IMLoginUser.shared().currentUser?.privateKey.isEmpty ?? true) ||  (IMLoginUser.shared().currentUser?.publicKey.isEmpty ?? true)) {
                let alert = FZMAlertView.init(attributedTitle: NSAttributedString.init(string:"提示"), attributedText: NSAttributedString.init(string: "你尚未设置密聊私钥，无法加密群聊发送消息，请先设置密聊私钥。", attributes: [NSAttributedString.Key.foregroundColor: Color_24374E]), btnTitle: "设置") {
                    FZMUIMediator.shared().pushVC(.goImportSeed(isHideBackBtn: false))
                }
                alert.show()
                return
            }
            if strongSelf.inGroup {
                FZMUIMediator.shared().pushVC(.goChat(chatId: strongSelf.group.uid, type: .group))
            }else {
                var useSource = [String : Any]()
                switch strongSelf.type {
                case .sweep:
                    useSource = ["sourceType": 2]
                case .group(let groupId):
                    useSource = ["sourceType": 4, "sourceId": groupId]
                case .share(let userId):
                    useSource = ["sourceType": 3, "sourceId": userId]
                case .search:
                    useSource = ["sourceType": 1]
                case .normal:
                    useSource = ["sourceType": 5]
                case .invite(let inviterId):
                    useSource = ["sourceType": 4, "sourceId": inviterId]
                case .phoneContact:
                    useSource = ["sourceType": 6]
                }
                if strongSelf.group.needConfirm {
                    FZMUIMediator.shared().pushVC(.inputAddAuthInfo(type: .group(groupId: strongSelf.group.uid, source: useSource), completeBlock: {
                        strongSelf.showToast(with: "验证申请已提交")
                        strongSelf.addBtn.isHidden = true
                    }))
                }else {
                    strongSelf.showProgress(with: "正在申请")
                    IMConversationManager.shared().applyJoinGroup(groupId: strongSelf.group.uid, source: useSource, completionBlock: { (response) in
                        strongSelf.hideProgress()
                        guard response.success else {
                            strongSelf.showToast(with: response.message)
                            return
                        }
                        FZNEncryptKeyManager.shared().updataGroupKey(groupId: strongSelf.group.uid)
                        strongSelf.showToast(with: "添加成功")
                        strongSelf.addBtn.isHidden = true
                        
                    })
                }
            }
        }.disposed(by: disposeBag)
        
        let headTap = UITapGestureRecognizer()
        headTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            FZMUIMediator.shared().showImage(view: strongSelf.headerImageView, url: strongSelf.group.avatar)
            }.disposed(by: disposeBag)
        headerImageView.addGestureRecognizer(headTap)
    }
    
    private func refreshView() {
        nameLab.text = group.name
        desLab.text = "群号 \(group.showId)"
        nickNameLab.text = "群成员 \(group.memberNumber)人"

        headerImageView.loadNetworkImage(with: group.avatar.getDownloadUrlString(width: 50), placeImage: GetBundleImage("chat_group_head"))
        if group.identification == true {
            self.identificationImageView.isHidden = false
            let att = NSMutableAttributedString.init(string: "\(IMSDK.shared().shareTitle ?? "")认证： \(group.identificationInfo)", attributes: [NSAttributedString.Key.font : UIFont.regularFont(14),NSAttributedString.Key.foregroundColor : Color_8A97A5])
            att.yy_lineSpacing = 4
            self.identificationInfoLab.attributedText = att
        } else {
            self.identificationImageView.isHidden = true
            self.identificationInfoLab.snp.remakeConstraints { (m) in
                m.top.equalTo(self.nickNameLab.snp.bottom).offset(0)
                m.left.equalTo(self.nickNameLab)
                m.right.equalToSuperview().offset(-16)
                m.height.equalTo(0)
            }
        }

        self.showProgress()
        HttpConnect.shared().isInGroup(groupId: group.uid) { (isInGroup, response) in
            self.hideProgress()
            guard let isInGroup = isInGroup, response.success else {
                self.showToast(with: response.message)
                return
            }
            if isInGroup {
                self.addBtn.setAttributedTitle(NSAttributedString(string: "进入群聊", attributes: [.foregroundColor:UIColor.white,.font:UIFont.regularFont(16)]), for: .normal)
                self.inGroup = true
            }else {
                self.addBtn.isHidden = !self.group.canAdd
            }
        }
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
