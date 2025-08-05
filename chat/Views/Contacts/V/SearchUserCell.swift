//
//  SearchUserCell.swift
//  chat
//
//  Created by 陈健 on 2021/1/14.
//

import UIKit
import SnapKit

class SearchUserCell: UITableViewCell {

    lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: UIImage.init(named: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: nil)
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
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.height.equalTo(23)
        }
    }
    
    func configure(with data: (name: String, avatar: String)) {
        self.nameLab.text = data.name
        self.headerImageView.kf.setImage(with: URL.init(string: data.avatar), placeholder: UIImage.init(named: "friend_chat_avatar"))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
