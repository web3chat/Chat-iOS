//
//  FZMGroupNotifyCell.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/29.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

class FZMGroupNotifyCell: UITableViewCell {
    
    lazy var senderNameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
    }()
    
    lazy var timeLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .right, text: nil)
    }()
    
    lazy var contentLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = UIColor.clear
        let backView = UIView()
        backView.makeOriginalShdowShow()
        self.contentView.addSubview(backView)
        backView.addSubview(timeLab)
        timeLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(5)
            m.height.equalTo(20)
        }
        backView.addSubview(senderNameLab)
        senderNameLab.snp.makeConstraints { (m) in
            m.centerY.equalTo(timeLab)
            m.left.equalToSuperview().offset(15)
            m.right.equalTo(timeLab.snp.left).offset(-10)
        }
        
        backView.addSubview(contentLab)
        contentLab.snp.makeConstraints { (m) in
            m.top.equalTo(senderNameLab.snp.bottom).offset(14)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        backView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview().inset(UIEdgeInsets(top: 7.5, left: 15, bottom: 7.5, right: 15))
            m.height.equalTo(contentLab).offset(63)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    func configure(with data: IMGroupNotifyModel) {
//        senderNameLab.text = data.senderName
//        contentLab.text = data.content
//        timeLab.text = String.showTimeString(with: data.datetime)
//    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
