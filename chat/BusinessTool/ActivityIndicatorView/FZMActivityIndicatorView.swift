//
//  FZMActivityIndicatorView.swift
//  IMSDK
//
//  Created by 陈健 on 2019/7/31.
//

import UIKit
import SnapKit

class FZMActivityIndicatorView: UIView {
    
    private lazy var activityIndicatorView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView.init(style: .gray)
        v.startAnimating()
        v.color = Color_24374E
        return v
    }()
    
    private lazy var titleLab: UILabel = {
        let v = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .center, text: nil)
        return v
    }()
    
    init(frame: CGRect, title: String) {
        super.init(frame: frame)
        self.titleLab.text = title
        self.addSubview(self.titleLab)
        self.titleLab.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.centerX.equalToSuperview().offset(13)
        }
        
        self.addSubview(self.activityIndicatorView)
        self.activityIndicatorView.snp.makeConstraints { (m) in
            m.centerY.equalTo(self.titleLab)
            m.right.equalTo(self.titleLab.snp.left).offset(-6)
        }
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
