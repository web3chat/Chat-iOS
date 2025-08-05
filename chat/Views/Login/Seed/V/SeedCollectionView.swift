//
//  SeedCollectionView.swift
//  chat
//
//  Created by 陈健 on 2021/1/6.
//

import UIKit
import SwifterSwift

class SeedCollectionView: UICollectionView {
    
    let isChinese: Bool
    let isGroup: Bool
    private let alwaysSelected: Bool
    
    var selectBlock: ((Int) -> ())?
    
    init(isChinese: Bool, isGroup: Bool, alwaysSelected: Bool) {
        self.isChinese = isChinese
        self.isGroup = isGroup
        self.alwaysSelected = alwaysSelected
        
        let layout = SeedCollectionViewLayout.init()
        super.init(frame: .zero, collectionViewLayout: layout)
        self.register(cellWithClass: SeedCollectionViewCell.self)
        self.backgroundColor = .clear
        self.delegate = self
        self.dataSource = self
        self.allowsMultipleSelection = true
        self.isScrollEnabled = false
        self.isPrefetchingEnabled = false
    }
    
    var seed = [String]() { didSet { self.reloadData() } }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension SeedCollectionView: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.seed.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SeedCollectionViewCell.self, for: indexPath)
        guard indexPath.row < self.seed.count else {
            return cell
        }
        cell.configure(text: self.seed[indexPath.row])
        if self.alwaysSelected {
            cell.setSelectStatus(true)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectBlock?(indexPath.row)
    }

    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        guard !self.alwaysSelected else { return true }
        guard let cell = collectionView.cellForItem(at: indexPath) as? SeedCollectionViewCell  else {
            return true
        }
        return !cell.isSelected
    }
    
}

