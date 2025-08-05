//
//  SessionColletionView.swift
//  chat
//
//  Created by 陈健 on 2021/1/11.
//

import UIKit

class SessionColletionView: UICollectionView {
    
    convenience init() {
        let layout = UICollectionViewFlowLayout.init()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        self.init(frame: .zero, collectionViewLayout: layout)
    }
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.alwaysBounceVertical = true
        self.backgroundColor = Color_FFFFFF
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
    }
}
