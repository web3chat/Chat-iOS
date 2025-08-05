//
//  FZMUnreadCountButton.swift
//  IMSDK
//
//  Created by 陈健 on 2019/1/23.
//

import UIKit

class FZMUnreadCountButton: UIButton {

    init(with image:UIImage?,frame:CGRect) {
        super.init(frame: frame)
        self.setBackgroundColor(color: Color_Auxiliary, state: .normal)
        self.setBackgroundColor(color: Color_Auxiliary, state: .highlighted)
        let imageView = UIImageView.init(frame: CGRect(x: 15, y: 15, width: 10, height: 10))
        imageView.image = image
        imageView.contentMode = UIView.ContentMode.scaleAspectFit
        self.addSubview(imageView)
        self.setTitleColor(Color_Theme, for: .normal)
        self.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        self.titleEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
