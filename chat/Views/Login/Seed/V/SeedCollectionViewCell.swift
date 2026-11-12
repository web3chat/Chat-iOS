//
//  SeedCollectionViewCell.swift
//  chat
//
//  Created by fzm on 2021/1/6.
//

import UIKit

class SeedCollectionViewCell: UICollectionViewCell {
    
    private lazy var bgView: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_Theme
        v.layer.cornerRadius = 3
        v.layer.masksToBounds = true
        v.layer.borderColor = Color_Theme.cgColor
        v.layer.borderWidth = 1
        return v
    }()
    
    private lazy var label: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 18), textColor: UIColor.init(hexString: "#ffffff"), textAlignment: .center, text: nil)
        return lab
    }()
        
    override var isSelected: Bool {
        didSet {
            self.setSelectStatus(isSelected)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    func configure(text: String) {
        self.label.text = text
    }
    
    private func setupViews() {
        self.contentView.addSubview(self.bgView)
        self.bgView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        self.bgView.addSubview(self.label)
        self.label.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
    
    func setSelectStatus(_ isSelected: Bool) {
        if isSelected {
            self.bgView.backgroundColor = .white
            self.bgView.layer.borderColor = UIColor.init(hexString: "#333333")?.cgColor
            self.label.textColor = UIColor.init(hexString: "#8E92A3")
        } else {
            self.bgView.backgroundColor = Color_Theme
            self.bgView.layer.borderColor = Color_Theme.cgColor
            self.label.textColor = .white
        }
    }
    
}
