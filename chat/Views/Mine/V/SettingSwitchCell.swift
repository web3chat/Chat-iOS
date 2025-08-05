//
//  SettingSwitchCell.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/15.
//

import UIKit
import SnapKit

class SettingSwitchCell: UITableViewCell {
    
    private lazy var leftLabel: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 1
        return lab
    }()
    
    private lazy var rightSwitch: UISwitch = {
        let btn = UISwitch()
        btn.onTintColor = Color_Theme
        btn.addTarget(self, action: #selector(switchChange(switchBtn:)), for: .valueChanged)
        return btn
    }()
    
    private lazy var lineView: UIImageView = {
        let view = UIImageView.init()
        view.backgroundColor = Color_E6EAEE
        view.isHidden = true
        return view
    }()
    
    var switchChangeBlock: ((Bool)->())?
    
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
        
        self.contentView.addSubview(rightSwitch)
        rightSwitch.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(lineView)
        lineView.snp.makeConstraints { (m) in
            m.height.equalTo(0.5)
            m.bottom.equalToSuperview()
            m.left.right.equalToSuperview()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.leftLabel.text = nil
        self.leftLabel.attributedText = nil
        self.rightSwitch.isOn = false
        DispatchQueue.main.async {
            self.roundCorners([.topLeft,.topRight,.bottomLeft,.bottomRight], radius: 0)
        }
    }
    
    func configure(with model:SettingCellModel) {
        guard let model = model as? SettingSwitchCellModel else {
            return
        }
        
        if let attri = model.leftAttributedString {
            self.leftLabel.attributedText = attri
        } else {
            self.leftLabel.text = model.leftString
        }
        
        self.rightSwitch.isOn = model.isSwitchOn 
        
        self.lineView.isHidden = !(model.isShowLine ?? false)
        
        self.switchChangeBlock = model.switchChangeBlock
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @objc private func switchChange(switchBtn: UISwitch) {
        self.switchChangeBlock?(switchBtn.isOn)
    }
}
