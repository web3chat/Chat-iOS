//
//  FZMGroupMemberCell.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/30.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import Kingfisher

class FZMGroupMemberCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    private var member : GroupMember?
    private var serverUrl: String?
    private let disposeBag = DisposeBag()
    
    var showType = true
    
    var showRightDelete = false {
        didSet{
            deleteBtn.isHidden = !showRightDelete
        }
    }
    
    var showSelect = false {
        didSet{
            if showSelect {
                selectBtn.isHidden = false
                headerImageView.snp.updateConstraints { (m) in
                    m.left.equalToSuperview().offset(45)
                }
            }else {
                selectBtn.isHidden = true
                headerImageView.snp.updateConstraints { (m) in
                    m.left.equalToSuperview().offset(15)
                }
            }
        }
    }
    
    var isSelect = false {
        didSet{
            selectBtn.image = isSelect ? #imageLiteral(resourceName: "tool_select").withRenderingMode(.alwaysTemplate) : #imageLiteral(resourceName: "tool_disselect").withRenderingMode(.alwaysTemplate)
        }
    }
    
    var deleteBlock: NormalBlock?
    var cleanBlock: NormalBlock?
    
    lazy var selectBtn : UIImageView = {
        let btn = UIImageView(image: #imageLiteral(resourceName: "tool_disselect").withRenderingMode(.alwaysTemplate))
        btn.tintColor = Color_Theme
        btn.isHidden = true
        return btn
    }()
   
    lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()
    
    lazy var desLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()
    
    lazy var typeLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: UIColor.white, textAlignment: .center, text: nil)
        lab.layer.cornerRadius = 4
        lab.clipsToBounds = true
        return lab
    }()
    
    lazy var deleteBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "tool_delete"), for: .normal)
        btn.enlargeClickEdge(20, 20, 20, 20)
        btn.isHidden = true
        return btn
    }()
    
    lazy var clearBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 15
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.setAttributedTitle(NSAttributedString(string: "解除", attributes: [.foregroundColor:Color_Theme,.font:UIFont.regularFont(14)]), for: .normal)
        btn.isHidden = true
        return btn
    }()
    
    var searchString: String?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = UIColor.clear
        self.contentView.addSubview(selectBtn)
        selectBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 15, height: 15))
        }
        self.contentView.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 35, height: 35))
        }
        self.contentView.addSubview(typeLab)
        typeLab.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalTo(headerImageView.snp.right).offset(15)
            m.size.equalTo(CGSize(width: 45, height: 20))
        }
        self.contentView.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-20)
            m.height.equalTo(23)
        }
        self.contentView.addSubview(desLab)
        desLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.top.equalTo(nameLab.snp.bottom).offset(3)
            m.bottom.equalToSuperview().offset(-5)
            m.height.equalTo(17)
        }
        self.contentView.addSubview(deleteBtn)
        deleteBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize(width: 15, height: 15))
        }
        deleteBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.deleteBlock?()
        }.disposed(by: disposeBag)
        
        self.contentView.addSubview(clearBtn)
        clearBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-40)
            m.size.equalTo(CGSize(width: 50, height: 30))
        }
        clearBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.clearBannedMember()
        }.disposed(by: disposeBag)
    }
    
    private func clearBannedMember() {
        guard let member = self.member, let serverUrl = self.serverUrl else { return }
        GroupManager.shared().updateMemberMuteTime(serverUrl: serverUrl, groupId: member.groupId, muteTime: 0, memberIds: [member.memberId]) { _ in
            self.cleanBlock?()
            self.clearBannedInfo()
        } failureBlock: { (error) in
            self.showToast("设置失败 \(error)")
        }
    }
    
    func configure(with member: ContactViewModel, showBannedGroup: Group? = nil) {
        self.member = member.groupMember!
        self.nameLab.attributedText = nil
        self.desLab.attributedText = nil
        self.nameLab.text = ""
        self.desLab.text = ""
        self.desLab.snp.updateConstraints { (m) in
            m.height.equalTo(5)
        }
        nameLab.snp.updateConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(10)
        }
        typeLab.isHidden = true
        
        if showType {
            if member.groupMember!.memberType == 2 {
                typeLab.isHidden = false
                typeLab.backgroundColor = Color_Theme_Light
                typeLab.textColor = Color_Theme
                typeLab.text = "群主"
                nameLab.snp.updateConstraints { (m) in
                    m.left.equalTo(headerImageView.snp.right).offset(70)
                }
            }else if member.groupMember!.memberType == 1 {
                typeLab.isHidden = false
                typeLab.backgroundColor = UIColor.init(hexString: "#EFA019", transparency: 0.1)!
                typeLab.textColor = UIColor.init(hexString: "#EFA019")!
                typeLab.text = "管理员"
                nameLab.snp.updateConstraints { (m) in
                    m.left.equalTo(headerImageView.snp.right).offset(70)
                }
            }
        }
        
        if let group = showBannedGroup {
            FZMAnimationTool.removeCountdown(with: desLab)
            self.clearBtn.isHidden = true
            self.desLab.snp.updateConstraints { (m) in
                m.height.equalTo(5)
            }
            self.desLab.text = ""
            let (isBanned, distance) = GroupManager.shared().handleBannedInfo(user: member.groupMember!, group: group)
            if isBanned && distance > 0 {
                self.desLab.snp.updateConstraints { (m) in
                    m.height.equalTo(17)
                }
                self.popAnimation(time: Double(distance))
                self.clearBtn.isHidden = false
            }
        }
        var avatar = member.avatar
        if member.sessionIDStr == LoginUser.shared().address {
            avatar = LoginUser.shared().avatarUrl
        }
        self.headerImageView.kf.setImage(with: URL.init(string: avatar), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))

        if self.searchString != nil {
            self.dealSearchString(data: member.groupMember!, name: member.name)
        } else {
            self.nameLab.text = member.name
            self.desLab.text = ""
        }
    }
    
    private func clearBannedInfo() {
        FZMAnimationTool.removeCountdown(with: desLab)
        self.clearBtn.isHidden = true
        self.desLab.snp.updateConstraints { (m) in
            m.height.equalTo(5)
        }
        desLab.text = ""
//        self.member?.deadline = Date.timestamp
    }
    
    private func popAnimation(time:Double){
        if time < k_OnedaySeconds {
            let formatter = DateFormatter.getDataformatter()
            formatter.dateFormat = "HH:mm:ss"
            FZMAnimationTool.countdown(with: desLab, fromValue: time, toValue: 0, block: { [weak self] (useTime) in
                let time = useTime - 8 * 3600
                let date = Date.init(timeIntervalSince1970: TimeInterval(time))
                self?.desLab.text = "已禁言 " + formatter.string(from: date)
            },finishBlock: {[weak self] in
                self?.clearBannedInfo()
            })
        }else{
            self.desLab.text = "永远禁言"
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}

extension FZMGroupMemberCell {
    
    private func dealSearchString(data: GroupMember, name: String) {
        if let searchString = self.searchString {
            if name.lowercased().contains(searchString.lowercased()) {
                let attStr = NSMutableAttributedString.init(string: name, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor : Color_24374E])
                attStr.addAttributes([NSAttributedString.Key.foregroundColor : Color_Theme], range:(name.lowercased() as NSString).range(of: searchString.lowercased()))
                self.nameLab.attributedText = attStr
            } else {
                self.nameLab.text = name
                var desString = ""
                let memberName = data.memberName ?? data.memberId
                if let user = data.user, let alias = user.alias, alias.lowercased().contains(searchString.lowercased()) {
                    desString = "昵称: " + alias
                } else if memberName.contains(searchString) {
                    desString = "群昵称: " + memberName
                }
//                if data.nickname.lowercased().contains(searchString.lowercased()) {
//                    desString = "昵称: " + data.nickname
//                } else if data.groupNickname.contains(searchString) {
//                    desString = "群昵称: " + data.groupNickname
//                }
                guard desString != "" else { return }
                self.desLab.snp.updateConstraints { (m) in
                    m.height.equalTo(15)
                }
                let attStr = NSMutableAttributedString.init(string: desString, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 12), NSAttributedString.Key.foregroundColor : Color_24374E])
                attStr.addAttributes([NSAttributedString.Key.foregroundColor : Color_Theme], range:(desString.lowercased() as NSString).range(of: searchString.lowercased()))
                self.desLab.attributedText = attStr
            }
        }
    }
}

