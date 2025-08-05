//
//  FZMVideoListView.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/28.
//

import Foundation
import RxSwift
import MJRefresh
import SnapKit
import UIKit

class FZMVideoListView: FZMScrollPageItemBaseView {
    private var dataSource = [[FZMMessageBaseVM]]()
    var isSelect = false
    var selectBlock: ((FZMMessageBaseVM,UIImageView)->())?
    
    private var startId = ""
    private let session: Session
    
//    var videoAndImageMessageArr = [Message]()
    var videoListVMArr = [FZMMessageBaseVM]() {
        didSet {
            self.dataSource.removeAll()
            Array.init(Set.init(videoListVMArr.compactMap {$0.time})).sorted{$0 > $1}.forEach { (date) in
                self.dataSource.append(videoListVMArr.filter{$0.time == date})
            }
            self.refresh()
            DispatchQueue.main.async {
                self.noDataCover.isHidden = !self.dataSource.isEmpty
            }
        }
    }
    
    private lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout.init()
        layout.itemSize = CGSize.init(width: (k_ScreenWidth - 2 * 5) / 4 , height: (k_ScreenWidth - 2 * 5) / 4)
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        layout.sectionInset = .zero
        layout.headerReferenceSize = CGSize.init(width: 200, height: 30)
//        layout.footerReferenceSize = CGSize.init(width: k_ScreenWidth, height: k_SafeBottomInset)
        return layout
    }()
    
    private lazy var collectionView: UICollectionView = {
//        let layout = UICollectionViewFlowLayout.init()
//        layout.itemSize = CGSize.init(width: (k_ScreenWidth - 2 * 5) / 4 , height: (k_ScreenWidth - 2 * 5) / 4)
//        layout.minimumLineSpacing = 2
//        layout.minimumInteritemSpacing = 2
//        layout.headerReferenceSize = CGSize.init(width: 200, height: 30)
//        layout.footerReferenceSize = CGSize.init(width: k_ScreenWidth, height: k_SafeBottomInset)
//        let v = UICollectionView.init(frame: CGRect.zero, collectionViewLayout: layout)
        let v = UICollectionView.init(frame: CGRect.zero, collectionViewLayout: self.collectionViewLayout)
        v.backgroundColor = .white
        v.register(FZMVideoListCell.self, forCellWithReuseIdentifier: "FZMVideoListCell")
        v.register(FZMVideoListHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "FZMVideoListHeaderView")
//        v.register(FZMVideoListFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "FZMVideoListFooterView")
        if #available(iOS 11.0, *) {
            v.contentInsetAdjustmentBehavior = .never
        }
        v.delegate = self
        v.dataSource = self
        v.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: {[weak self] in
            self?.loadData()
        })
        v.addSubview(noDataCover)
        noDataCover.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview().offset(-k_StatusNavigationBarHeight - 20)
            m.centerX.equalToSuperview()
        })
        return v
    }()
    
    lazy var noDataCover: UIImageView = {
        let v = UIImageView()
        v.image = #imageLiteral(resourceName: "nodata_search_media")
        v.contentMode = .scaleAspectFit
        v.isHidden = true
        let lab = UILabel.getLab(font: UIFont.mediumFont(14), textColor: Color_8A97A5, textAlignment: .center, text: "暂无图片/视频")
        v.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(v.snp.bottom).offset(20)
        })
        return v
    }()
    
    init(with pageTitle: String, session: Session) {
        self.session = session
        super.init(with: pageTitle)
        self.addSubview(collectionView)
        collectionView.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(2)
            m.right.equalToSuperview().offset(-2)
        }
        
        self.loadData()
    }
    
    // 从数据库获取消息数据
    private func getHistoryMediaMsgs(from msgId: String = "", count: Int = 20) -> [Message] {
        let msgInDB = ChatManager.shared().getSpecifiedDBMsgs(typeArr: [3,4], session: self.session, msgId: msgId, count: count)
        return msgInDB
    }
    
    func loadData(more:Bool = false) {
        if !more {
            self.showProgress()
        }
        defer {
            self.hideProgress()
        }
        
//        self.startId = self.videoAndImageMessageArr.last?.msgId ?? ""
        self.startId = self.videoListVMArr.last?.message.msgId ?? ""
        
        DispatchQueue.global().async {
            let msgsInDB = self.getHistoryMediaMsgs(from: self.startId, count: 20)
            self.processMsgs(msgs: msgsInDB, startId: self.startId)
        }
    }
    
    func processMsgs(msgs: [Message],startId: String) {
        self.startId = startId
//        self.videoAndImageMessageArr += msgs
        self.videoListVMArr += msgs.compactMap{ FZMMessageBaseVM.init(with: $0)}
        DispatchQueue.main.async {
            self.collectionView.mj_footer?.endRefreshing()
            if msgs.count < 20 {
                self.collectionView.mj_footer?.isHidden = true
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refresh() {
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.collectionView.reloadData()
            }
        }
    }
    
    func edgeInset(_ edge: Bool) {
        self.collectionView.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: edge ? 70 : 0 , right: 0)
    }
}

extension FZMVideoListView: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !self.isSelect else {return}
        self.selectBlock?(self.dataSource[indexPath.section][indexPath.row],(collectionView.cellForItem(at: indexPath) as! FZMVideoListCell).contentImageView)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FZMVideoListCell", for: indexPath) as! FZMVideoListCell
        let vm = self.dataSource[indexPath.section][indexPath.row]
        
        cell.configure(with: vm, isShowSelect: self.isSelect)
        
        cell.selectBlock = {[weak self] (vm,imageview) in
//            guard let strongSelf = self, !strongSelf.isSelect else {return }
            guard let strongSelf = self else {return }
            strongSelf.selectBlock?(vm,imageview)
        }
        
        
//        let sectionCount = self.dataSource.count
//        let vmCount = self.dataSource[indexPath.section].count
//        if sectionCount > 0, sectionCount == indexPath.section + 1, indexPath.row + 1 == vmCount {
//            self.collectionViewLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: k_SafeBottomInset, right: 0)
//        } else {
//            self.collectionViewLayout.sectionInset = .zero
//        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FZMVideoListHeaderView", for: indexPath) as! FZMVideoListHeaderView
            header.label.text = self.dataSource[indexPath.section].first?.time
            return header
        }
//        else if kind == UICollectionView.elementKindSectionFooter {
//            let sectionCount = self.dataSource.count
//            if sectionCount > 0, sectionCount == indexPath.section + 1 {
//                self.collectionViewLayout.footerReferenceSize = CGSize.init(width: k_ScreenWidth, height: k_SafeBottomInset)
//            } else {
//                self.collectionViewLayout.footerReferenceSize = .zero
//            }
//            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FZMVideoListFooterView", for: indexPath) as! FZMVideoListFooterView
//            return footer
//        }
        return UICollectionReusableView.init()
    }
}

class FZMVideoListHeaderView: UICollectionReusableView {
    let label = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.addSubview(label)
        label.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//class FZMVideoListFooterView: UICollectionReusableView {
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        self.backgroundColor = .clear
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}
