//
//  BannedMemberCell.swift
//  chat
//
//  Created by liyaqin on 2021/11/4.
//

import Foundation
class BannedMemberCell: UITableViewCell {
    
    private let disposeBag = DisposeBag()
    private var member : GroupMember?
    private var serverUrl: String?
    
    var deleteBlock: NormalBlock?
    
    lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "")
    }()
    
    lazy var timeLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: "")
    }()
    
    lazy var deleteBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "tool_delete"), for: .normal)
        btn.enlargeClickEdge(20, 20, 20, 20)
        return btn
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = UIColor.clear
        
        self.contentView.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 35, height: 35))
        }
        
        self.contentView.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-20)
            m.top.equalToSuperview().offset(5)
            m.height.equalTo(23)
        }
        
        self.contentView.addSubview(timeLab)
        timeLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-20)
            m.top.equalTo(nameLab.snp.bottom)
            m.height.equalTo(16)
        }
        
        self.contentView.addSubview(deleteBtn)
        deleteBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize(width: 20, height: 20))
        }
        deleteBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.deleteBlock?()
        }.disposed(by: disposeBag)
    }
    
    func configure(with member: ContactViewModel) {
        self.member = member.groupMember!
        self.headerImageView.kf.setImage(with: URL.init(string: member.avatar), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
        self.nameLab.text = member.name
        let time = member.groupMember?.memberMuteTime
        if time == 9223372036854775807 {
            self.timeLab.text = "永久禁言"
        }else{
            let dateTime = Date.timeStampToString(timeStamp: Double(time!))
            let formatter = DateFormatter.getDataformatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            self.timeLab.text = "已禁言至" + formatter.string(from: dateTime)
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
