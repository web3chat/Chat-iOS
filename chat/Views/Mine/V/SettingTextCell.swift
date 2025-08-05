//
//  SettingTextCell.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/15.
//

import UIKit
import SnapKit

class SettingTextCell: UITableViewCell {
    
    private lazy var leftLabel: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text:nil)
        lab.numberOfLines = 1
        return lab
    }()
    
    private lazy var rightLabel: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    private lazy var moreImgV: UIImageView = {
        let moreImgV = UIImageView.init(image: UIImage(named: "cell_right_dot"))
        return moreImgV
    }()
    
    private lazy var lineView: UIImageView = {
        let view = UIImageView.init()
        view.backgroundColor = Color_E6EAEE
        view.isHidden = true
        return view
    }()
    
    private var selectedBlock: (()->())?
    
    override func prepareForReuse() {
        self.leftLabel.text = nil
        self.leftLabel.attributedText = nil
        self.rightLabel.text = nil
        self.rightLabel.attributedText = nil
        DispatchQueue.main.async {
            self.roundCorners([.topLeft,.topRight,.bottomLeft,.bottomRight], radius: 0)
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.contentView.backgroundColor = Color_FFFFFF
        self.contentView.addSubview(leftLabel)
        leftLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(moreImgV)
        moreImgV.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
        }
        
        self.contentView.addSubview(rightLabel)
        rightLabel.snp.makeConstraints { (m) in
            m.right.equalTo(moreImgV).offset(-5)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(lineView)
        lineView.snp.makeConstraints { (m) in
            m.height.equalTo(0.5)
            m.bottom.equalToSuperview()
            m.left.right.equalToSuperview()
        }
    }
    
    func configure(with model: SettingCellModel) {
        guard let model = model as? SettingTextCellModel else {
            return
        }
        
        if let attri = model.leftAttributedString {
            self.leftLabel.attributedText = attri
        } else {
            self.leftLabel.text = model.leftString
        }
        
        if let attri = model.rightAttributedString {
            self.rightLabel.attributedText = attri
        } else {
            self.rightLabel.text = model.rightString
        }
        
        self.lineView.isHidden = !(model.isShowLine ?? false)
        
        self.selectedBlock = model.selectedBlock
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
