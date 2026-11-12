//
//  FZMRedBagCoinCell.swift
//  IMSDK
//
//  Created by fzm on 2019/3/13.
//

import UIKit

class FZMRedBagCoinCell: UITableViewCell {

    lazy var logoImg: UIImageView = {
       let v = UIImageView.init()
        v.image = UIImage(named: "chat_file_excel")
        v.contentMode = .scaleAspectFit
        v.backgroundColor = RP.goldLight.withAlphaComponent(0.6)
        v.layer.cornerRadius = 40 * 0.5
        v.layer.masksToBounds = true
        v.layer.borderWidth = 0.5
        v.layer.borderColor = RP.gold.withAlphaComponent(0.6).cgColor
        return v
    }()
    
    lazy var nameLab: UILabel = {
        let v = UILabel.getLab(font: UIFont.mediumFont(16), textColor: RP.ink, textAlignment: .left, text: "")
        return v
    }()
    
    lazy var balanceLab: UILabel = {
        let v = UILabel.getLab(font: UIFont.regularFont(13), textColor: RP.inkSoft, textAlignment: .left, text: "")
        return v
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = RP.cream
        contentView.backgroundColor = RP.cream
        // 点选时闪一层淡金（原来用系统灰底，与红金体系不搭）
        let selectedBg = UIView()
        selectedBg.backgroundColor = RP.goldLight.withAlphaComponent(0.5)
        self.selectedBackgroundView = selectedBg
        self.createView()
    }
    
    private func createView() {
        self.addSubview(logoImg)
        logoImg.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.width.height.equalTo(40)
        }
        self.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.top.equalTo(logoImg).offset(-3)
            m.left.equalTo(logoImg.snp.right).offset(15)
            m.right.lessThanOrEqualToSuperview().offset(-15)
        }
        
        self.addSubview(balanceLab)
        balanceLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(logoImg).offset(3)
            m.left.equalTo(nameLab)
            m.right.lessThanOrEqualToSuperview().offset(-15)
        }
    }
    
    func configure(with m: FZMRedBagCoinCellModel) {
        nameLab.text = m.coinNameAndNickname
        balanceLab.text = "\(m.amount.roundTo(places: m.decimalPlaces))"
        if m.coinName.uppercased() == "PMM" {
            logoImg.image = UIImage(named: "PMM")
        } else {
            logoImg.loadNetworkImage(with: m.icon, placeImage: nil)
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
