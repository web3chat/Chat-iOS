//
//  AccoutCell.swift
//  xls
//
//  Created by 陈健 on 2020/8/12.
//  Copyright © 2020 陈健. All rights reserved.
//

import UIKit

class AccoutCell: UITableViewCell {

    @IBOutlet private weak var bgView: UIView!
    @IBOutlet private weak var leftLogo: UIImageView!
    @IBOutlet private weak var leftLab: UILabel!
    @IBOutlet private weak var righLab: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = Color_F6F7F8
        self.selectionStyle = .none
        
    }
    
    func set(logo: String, leftText: String, rightText: String) {
        self.leftLogo.image = UIImage.init(named: logo)
        self.leftLab.text = leftText
        self.righLab.text = rightText
    }
    
    

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
