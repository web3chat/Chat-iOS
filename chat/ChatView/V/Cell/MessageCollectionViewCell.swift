//
//  MessageCollectionViewCell.swift
//  chat
//
//  Created by 陈健 on 2020/12/21.
//

import UIKit

class MessageCollectionViewCell: UICollectionViewCell, HandleGesture {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func handleTapGesture(_ gesture: UIGestureRecognizer) { }
    func handleLongPressGesture(_ longPressGesture: UILongPressGestureRecognizer) {}
    
}

