//
//  SeedCollectionViewLayout.swift
//  chat
//
//  Created by 陈健 on 2021/1/6.
//

import UIKit

class SeedCollectionViewLayout: UICollectionViewLayout {
    
    private let chineseSeedSize = CGSize.init(width: 40, height: 40)
    
    private var attributesArr = [UICollectionViewLayoutAttributes]()
    
    private var seedCollectionView: SeedCollectionView {
        return self.collectionView as! SeedCollectionView
    }
    
    override var collectionViewContentSize: CGSize {
        return CGSize.init(width: self.seedCollectionView.bounds.width, height: 500)
    }
    
    override func prepare() {
        self.prepareLayoutAttributes()
    }
    
    override class var layoutAttributesClass: AnyClass {
        return UICollectionViewLayoutAttributes.self
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return self.attributesArr
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.row < self.attributesArr.count else {
            return nil
        }
        return self.attributesArr[indexPath.row]
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        self.attributesArr.removeAll()
    }
    
    private func prepareLayoutAttributes() {
        let seed = self.seedCollectionView.seed
        guard !seed.isEmpty else { return }

        let collectionViewWidth = self.seedCollectionView.bounds.width
        var attArray = [UICollectionViewLayoutAttributes]()
        let lineSpacing = CGFloat.init(15)
        
        for i in 0..<seed.count {
            let size = self.getSize(text: seed[i])
            let att = UICollectionViewLayoutAttributes.init(forCellWith: IndexPath.init(row: i, section: 0))
            att.size = size
            var origin = CGPoint.init(x: 0, y: 0)
            let interitemSpacing = self.interitemSpacing(index: i)
            if i == 0 {
                 origin = CGPoint.init(x: 0, y: 0)
            } else {
                let previousAttFrame = attArray[i - 1].frame
                let couldInCurrentLine = (collectionViewWidth - previousAttFrame.maxX - interitemSpacing) >= size.width
                origin = couldInCurrentLine ?
                    CGPoint.init(x: previousAttFrame.maxX + interitemSpacing, y: previousAttFrame.minY)
                                            :
                    CGPoint.init(x: 0, y: previousAttFrame.maxY + lineSpacing)
            }
            att.frame = CGRect.init(origin: origin, size: size)
            attArray.append(att)
        }
        self.attributesArr = attArray
    }
        
    private func interitemSpacing(index: Int) -> CGFloat {
        guard index != 0 else { return 0 }
        guard self.seedCollectionView.isChinese else { return 15 }
        guard self.seedCollectionView.isGroup else {
            return (self.seedCollectionView.bounds.width - (self.chineseSeedSize.width * 6)) / 5
        }
        
        let space = (self.seedCollectionView.bounds.width - (self.chineseSeedSize.width * 6)) / (4 + 2.3)
        if index % 3 == 0 && (index / 3) % 2 == 1 {
            return floor(space * 2.3)
        }
        return floor(space)
    }
    
    private func getSize(text: String) -> CGSize {
        guard !self.seedCollectionView.isChinese else { return self.chineseSeedSize }
        let height = CGFloat.init(34)
        let attributedText = NSAttributedString.init(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18)])
        let constraintBox = CGSize.init(width: CGFloat.greatestFiniteMagnitude, height: height)
        let rect = attributedText.boundingRect(with: constraintBox, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).integral
        return CGSize.init(width: rect.size.width + 20, height: height)
    }
}
