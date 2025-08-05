//
//  FZMSegementHeader.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/25.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import SwifterSwift

class FZMSegementHeader: UIView {

    private var unreadMap = [Int:Int]()
    private lazy var collectionView : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets.init(top: 0, left: self.param.marginSpacing, bottom: 0, right: self.param.marginSpacing)
        layout.minimumLineSpacing = self.param.spacing
        layout.itemSize = CGSize(width: self.param.itemWidth, height: self.frame.height)
        let view = UICollectionView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height), collectionViewLayout: layout)
        view.backgroundColor = UIColor.clear
        view.showsHorizontalScrollIndicator = false
        view.register(FZMSegementCell.self, forCellWithReuseIdentifier: "FZMSegementCell")
        view.dataSource = self
        view.delegate = self
        return view
    }()
    private lazy var selectBackView : UIView = {
        let view = UIView(frame: CGRect(x: self.param.marginSpacing + CGFloat(selectedIndex)*self.param.itemWidth, y: (self.frame.height - self.param.selectedBackHeight)/2, width: self.param.itemWidth, height: self.param.selectedBackHeight))
        view.backgroundColor = self.param.selectedBackColor
        view.layer.cornerRadius = self.param.selectedBackHeight/2
        view.clipsToBounds = true
        view.isHidden = !self.param.showSelectedBackView
        return view
    }()
    private var dataArr = [String]()
    private var param : FZMSegementParam
    var selectedIndex : Int = 0 {
        didSet{
            selectBackView.frame = CGRect(x: self.param.marginSpacing + CGFloat(selectedIndex)*self.param.itemWidth, y: (self.frame.height - self.param.selectedBackHeight)/2, width: self.param.itemWidth, height: self.param.selectedBackHeight)
        }
    }
    var didSelectedIndexBlock : ((Int)->())?
    
    init(with frame: CGRect, param: FZMSegementParam?, data: [String]?) {
        self.param = param ?? FZMSegementParam()
        if let data = data {
            self.dataArr = data
        }
        super.init(frame: frame)
        self.clipsToBounds = true
        self.addSubview(self.selectBackView)
        self.addSubview(self.collectionView)
        self.backgroundColor = self.param.bgColor
    }
    
    func updateDataArr(data: [String]) {
        self.dataArr = data
        self.collectionView.reloadData()
    }
    
    func setSelectIndex(with index: Int) {
        self.selectedIndex = index
        self.collectionView.reloadData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension FZMSegementHeader : UICollectionViewDelegate,UICollectionViewDataSource{
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataArr.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: FZMSegementCell.self, for: indexPath)
        guard indexPath.item < self.dataArr.count else {
            return cell
        }
        cell.update(text: self.dataArr[indexPath.item], param: self.param)
        cell.didSelect(indexPath.item == self.selectedIndex)
        if let unreadCount = unreadMap[indexPath.item] {
            cell.showUnreadCount(unreadCount)
        }else {
            cell.showUnreadCount(0)
        }
        return cell
    }
    
    func refreshUnreadCount(with index: Int, unreadCount: Int) {
        unreadMap[index] = unreadCount
        guard let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? FZMSegementCell else { return }
        cell.showUnreadCount(unreadCount)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.select(with: indexPath.item)
    }
    
    func select(with index: Int) {
        self.selectedIndex = index
        self.collectionView.reloadData()
        didSelectedIndexBlock?(index)
    }
}

class FZMSegementParam: NSObject {
    var spacing : CGFloat = 0//中间间距
    var marginSpacing : CGFloat = (k_ScreenWidth - 300)/2//左右边缘间距
    var textSelectedColor = Color_Theme//UIColor(hex: 0x0D73AD)//选中的颜色
    var textColor = Color_8A97A5//正常的颜色
    var showSelectedBackView = true//显示选中背景
    var selectedBackColor = Color_Auxiliary//选中背景颜色
    var selectedBackHeight : CGFloat = 35//选中背景高度
    var lineWidth : CGFloat = 5//底部线宽
    var lineColor = UIColor(hex: 0x000000)//底部线颜色
    var font = UIFont.mediumFont(16)//字体大小
    var selectFont = UIFont.mediumFont(16)//选择字体大小
    var startIndex = 0//默认选择item
    var itemWidth : CGFloat = 100//宽度
    var itemHeight : CGFloat = 35//高度
    var bgColor = UIColor(hex: 0xFAFBFC)
    var headerHeight : CGFloat = 50
}

class FZMSegementCell: UICollectionViewCell{
    var param = FZMSegementParam()
    var textLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(15), textColor: UIColor.black, textAlignment: .center, text: nil)
    }()
    
    lazy var unreadLab : FZMUnreadLab = {
        return FZMUnreadLab(frame: CGRect.zero)
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(textLab)
        textLab.snp.makeConstraints { (m) in
            m.centerX.top.bottom.equalToSuperview()
        }
        self.contentView.addSubview(unreadLab)
        unreadLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(6)
            m.centerX.equalTo(textLab.snp.right).offset(3)
            m.size.equalTo(CGSize.zero)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(text: String, param: FZMSegementParam) {
        self.param = param
        self.textLab.text = text
        
    }
    
    func showUnreadCount(_ count: Int) {
        unreadLab.setUnreadCount(count)
    }
    
    func didSelect(_ selected: Bool){
        self.textLab.textColor = selected ? self.param.textSelectedColor : self.param.textColor
        self.textLab.font = selected ? self.param.selectFont : self.param.font
    }
    
}

