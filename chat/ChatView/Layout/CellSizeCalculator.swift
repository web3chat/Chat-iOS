//
//  CellSizeCalculator.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import UIKit

class CellSizeCalculator {
    weak var layout: MessageCollectionViewLayout!

    func configure(attributes: MessageCollectionViewLayoutAttributes) { }
    
    func sizeForItem(at indexPath: IndexPath) -> CGSize {
        return .zero
    }
    
    init(layout: MessageCollectionViewLayout) {
        self.layout = layout
    }
}



