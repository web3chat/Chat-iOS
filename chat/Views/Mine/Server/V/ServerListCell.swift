//
//  ServerListCell.swift
//  chat
//
//  Created by 陈健 on 2021/1/27.
//

import UIKit

class ServerListCell: UITableViewCell {

    @IBOutlet weak var bgView: UIView!
    @IBOutlet weak var selectedImgView: UIImageView!
    @IBOutlet private weak var nameLab: UILabel!
    @IBOutlet private weak var valueLab: UILabel!
    @IBOutlet private weak var selectedImageViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreImageView: UIImageView!
    @IBOutlet weak var statusImageView: UIImageView!
    
    var isHiddenSelectedImgView: Bool = false {
        didSet {
            self.selectedImageViewLeftConstraint.constant = isHiddenSelectedImgView ? -20.5 : 13
            self.selectedImgView.isHidden = isHiddenSelectedImgView
        }
    }
    
    var isConnected: Bool = false {
        didSet {
            self.statusImageView.backgroundColor = isConnected ? Color_62DEAD : Color_DD5F5F
        }
    }
    
    var moreImageViewTapBlock: (()->())?
        
    override func prepareForReuse() {
        super.prepareForReuse()
        self.selectedImgView.isHighlighted = false
        self.nameLab.text = nil
        self.valueLab.text = nil
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .clear
        self.selectionStyle = .none
        
        self.moreImageView.enlargeClickEdge(.init(top: 10, left: 20, bottom: 10, right: 10))
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(moreImageViewTap(_:)))
        self.moreImageView.addGestureRecognizer(tap)
        
        self.selectedImgView.tintColor = Color_Theme
        self.selectedImgView.image = #imageLiteral(resourceName: "cercle").withRenderingMode(.alwaysTemplate)
        self.selectedImgView.highlightedImage = #imageLiteral(resourceName: "cercle_sel.with").withRenderingMode(.alwaysTemplate)
    }

//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//        
//        self.selectedImgView.isHighlighted = selected
//    }
    
    func configure(data: Server) {
        self.nameLab.text = data.name
        self.valueLab.text = data.value
    }
    
    @objc private func moreImageViewTap(_ sender: UITapGestureRecognizer) {
        self.moreImageViewTapBlock?()
    }
}
