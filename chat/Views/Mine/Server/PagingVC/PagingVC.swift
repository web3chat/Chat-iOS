//
//  PagingVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/27.
//

import UIKit
import Parchment

private class RoundedIndicatorView: PagingIndicatorView {
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        layer.cornerRadius = layoutAttributes.bounds.height / 2
        layer.masksToBounds = true
      }
}

class PagingVC: PagingViewController {
    
    convenience init(vcs: [UIViewController]) {
        var options = PagingOptions.init()
        
        options.menuBackgroundColor = Color_F6F7F8
        
        options.indicatorClass = RoundedIndicatorView.self
        
        options.indicatorOptions = .visible(height: 35, zIndex: -1, spacing: .zero, insets: .zero)
        options.indicatorColor = Color_Auxiliary
        
        options.menuItemSize = .fixed(width: 120, height: 35)
        options.menuItemLabelSpacing = 10
        options.menuHorizontalAlignment = .center
        options.borderOptions = .hidden
        
        options.textColor = Color_8A97A5
        options.selectedTextColor = Color_Theme
        options.font = UIFont.boldSystemFont(ofSize: 17)
        options.selectedFont = UIFont.boldSystemFont(ofSize: 17)
        self.init(options: options, viewControllers: vcs)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
