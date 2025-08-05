//
//  FZMRedBagCoinCell.swift
//  IMSDK
//
//  Created by 陈健 on 2019/3/13.
//

import UIKit

class FZMRedBagCoinCell: UITableViewCell {

    lazy var logoImg: UIImageView = {
       let v = UIImageView.init()
        v.image = UIImage(named: "chat_file_excel")
        v.contentMode = .scaleAspectFit
        v.layer.cornerRadius = 35 * 0.5
        v.layer.masksToBounds = true
        return v
    }()
    
    lazy var nameLab: UILabel = {
        let v = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "")
        return v
    }()
    
    lazy var balanceLab: UILabel = {
        let v = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")
        return v
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = Color_Theme
        self.createView()
    }
    
    private func createView() {
        self.addSubview(logoImg)
        logoImg.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.width.height.equalTo(35)
        }
        self.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.top.equalTo(logoImg).offset(-3)
            m.left.equalTo(logoImg.snp.right).offset(15)
        }
        
        self.addSubview(balanceLab)
        balanceLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(logoImg).offset(3)
            m.left.equalTo(nameLab)
        }
    }
    
    func configure(with m: FZMRedBagCoinCellModel) {
        nameLab.text = m.coinNameAndNickname
        balanceLab.text = "\(m.amount.roundTo(places: m.decimalPlaces))"
        logoImg.loadNetworkImage(with: m.icon, placeImage: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
