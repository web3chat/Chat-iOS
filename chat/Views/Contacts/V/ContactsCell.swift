//
//  ContactsCell.swift
//  chat
//
//  Created by 陈健 on 2021/1/25.
//

import UIKit
import SnapKit

enum FZMContactSelectStyle {
    case select
    case disSelect
    case cantSelect
}

class ContactsCell: UITableViewCell {
    
    lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()
    
    // 群类型
    private lazy var typeLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_Theme, textAlignment: .center, text: "")
        lab.layer.cornerRadius = 4
        lab.layer.masksToBounds = true
        lab.backgroundColor = Color_Theme_Light
        lab.textAlignment = .center
        lab.numberOfLines = 1
        lab.isHidden = true
        return lab
    }()
    
    lazy var desLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()
    
    lazy var selectBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "tool_disselect").withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_Theme
        btn.isHidden = true
        return btn
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.nameLab.text = nil
        self.typeLab.isHidden = true
        nameLab.snp.updateConstraints { (m) in
            m.width.equalTo(k_ScreenWidth - 75)
        }
        self.headerImageView.image = #imageLiteral(resourceName: "friend_chat_avatar")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = Color_FFFFFF
        
        self.contentView.addSubview(selectBtn)
        selectBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize(width: 15, height: 45))
            m.left.equalToSuperview()
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalTo(selectBtn.snp.right)
            m.size.equalTo(CGSize(width: 35, height: 35))
        }
        self.contentView.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(10)
            m.width.equalTo(k_ScreenWidth - 75)
            m.centerY.equalToSuperview()
            m.height.equalTo(23)
        }
        self.contentView.addSubview(typeLab)
        typeLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.right).offset(5)
            m.centerY.equalToSuperview()
            m.width.equalTo(34)
            m.height.equalTo(18)
        }
        self.contentView.addSubview(desLab)
        desLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.top.equalTo(nameLab.snp.bottom).offset(3)
            m.bottom.equalToSuperview().offset(-5)
            m.height.equalTo(17)
        }
    }
    
    var selectStyle : FZMContactSelectStyle = .disSelect {
        didSet{
            switch selectStyle {
            case .select:
                selectBtn.setImage(#imageLiteral(resourceName: "tool_select").withRenderingMode(.alwaysTemplate), for: .normal)
            case .disSelect:
                selectBtn.setImage(#imageLiteral(resourceName: "tool_disselect").withRenderingMode(.alwaysTemplate), for: .normal)
            case .cantSelect:
                selectBtn.setImage(#imageLiteral(resourceName: "tool_cantselect"), for: .normal)
            }
        }
    }
    
    func showSelect(_ showSelectBtn: Bool = true) {
        selectBtn.isHidden = !showSelectBtn
        selectBtn.snp.updateConstraints { (m) in
            m.size.equalTo(CGSize(width: showSelectBtn ? 45 : 15, height: 45))
        }
    }
    
    func configure(with contactModel: ContactViewModel) {
        self.nameLab.text = nil
        self.nameLab.attributedText = nil
        self.desLab.text = nil
        self.desLab.attributedText = nil
        
        self.headerImageView.kf.setImage(with: URL.init(string: contactModel.avatar), placeholder: contactModel.type == .person ? #imageLiteral(resourceName: "friend_chat_avatar") : #imageLiteral(resourceName: "group_chat_avatar"))
        
        let nameStr = contactModel.name
        self.nameLab.text = nameStr
        // 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
        if contactModel.type == .group, let group = contactModel.group, group.groupType != 0 {
            let typeStr = group.groupType == 1 ? "全员" : "部门"
            self.typeLab.text = typeStr
            self.typeLab.isHidden = false
            
            var nameWidth = nameStr.getContentWidth(font: .systemFont(ofSize: 16), height: 23) + 2// (+2): 计算有偏差，实际显示可能会显示不全，需再加宽一点
            
            let maxWidht = k_ScreenWidth - 75
            
            var rightWidth: CGFloat = 0
            let typeWidth = typeStr.getContentWidth(font: .systemFont(ofSize: 12), height: 18) + 10
            rightWidth = typeWidth > 0 ? 5 + typeWidth + 5 + 10 : 5 + 10
            
            let totalWidth = min(nameWidth + rightWidth, maxWidht)
            nameWidth = totalWidth - rightWidth
            
            nameLab.snp.updateConstraints { (m) in
                m.width.equalTo(nameWidth)
            }
            typeLab.snp.updateConstraints { make in
                make.width.equalTo(typeWidth)
            }
        }
        
        self.desLab.snp.updateConstraints { (m) in
            m.height.equalTo(5)
        }
        
        if contactModel.searchString != nil {
            self.dealSearchString(data: contactModel)
        }
    }
    
    private func dealSearchString(data: ContactViewModel) {
        if let searchString = data.searchString, let user = data.user {
            let name = data.name
            if name.lowercased().contains(searchString.lowercased()) {
                let attStr = NSMutableAttributedString.init(string: name, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor : Color_24374E])
                attStr.addAttributes([NSAttributedString.Key.foregroundColor : Color_Theme], range:(name.lowercased() as NSString).range(of: searchString.lowercased()))
                self.nameLab.attributedText = attStr
            } else {
                self.nameLab.text = name
                var desString = ""
                if user.contactsName.lowercased().contains(searchString.lowercased()) {
                    desString = "昵称: " + user.contactsName
                }
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//
//        self.selectBtn.isSelected = selected
//    }
    
}
