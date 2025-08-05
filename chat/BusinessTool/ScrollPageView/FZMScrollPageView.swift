//
//  FZMScrollPageView.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/26.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

class FZMScrollPageView: UIView {

    var currentIndex = 0 {
        didSet{
            if currentIndex != oldValue {
                selectBlock?(currentIndex)
            }
        }
    }
    var selectBlock : IntBlock?
    private var isInSelect = false
    private var param : FZMSegementParam
    private var dataViews = [FZMScrollPageItemBaseView]()
    private lazy var header : FZMSegementHeader = {
        let header = FZMSegementHeader(with: CGRect(x: 0, y: 0, width: self.frame.width, height: self.param.headerHeight), param: self.param, data: nil)
        header.didSelectedIndexBlock = {[weak self] (index) in
            guard let strongSelf = self else { return }
            strongSelf.currentIndex = index
            self?.isInSelect = true
            strongSelf.scrollView.setContentOffset(CGPoint(x: strongSelf.frame.width * CGFloat(index), y: 0), animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                self?.isInSelect = false
            })
        }
        header.backgroundColor = .clear
        return header
    }()
    private lazy var scrollView : UIScrollView = {
        let view = UIScrollView()
        view.frame = CGRect(x: 0, y: self.param.headerHeight, width: self.frame.width, height: self.frame.height - self.param.headerHeight)
        view.isPagingEnabled = true
        view.isDirectionalLockEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.delegate = self
//        view.isScrollEnabled = false
        return view
    }()
    
    private lazy var contentView : UIView = {
        return UIView()
    }()
    
    init(frame: CGRect, dataViews: [FZMScrollPageItemBaseView] , param: FZMSegementParam=FZMSegementParam()) {
        self.param = param
        self.dataViews = dataViews
        super.init(frame: frame)
        self.addSubview(header)
        let headerWidth : CGFloat = self.param.itemWidth * CGFloat(dataViews.count) + self.param.spacing * CGFloat(dataViews.count - 1) + self.param.marginSpacing * 2
        if headerWidth < self.frame.width {
            self.header.frame = CGRect(x: (self.frame.width - headerWidth)/2, y: 0, width: headerWidth, height: self.param.headerHeight)
        }
        self.addSubview(scrollView)
        scrollView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(header.snp.bottom)
        }
        scrollView.addSubview(contentView)
        var titles = [String]()
        for (index,item) in self.dataViews.enumerated() {
            item.index = index
            self.header.refreshUnreadCount(with: index, unreadCount: item.unreadCount)
            item.unreadBlock = {[weak self] (viewIndex,unreadCount) in
                self?.refreshUnreadCount(index: viewIndex, count: unreadCount)
            }
            contentView.addSubview(item)
            item.snp.makeConstraints { (m) in
                m.top.bottom.equalToSuperview()
                m.left.equalToSuperview().offset(CGFloat(index) * self.frame.width)
                m.width.equalTo(self.frame.width)
            }
            titles.append(item.title)
        }
        contentView.frame = CGRect(x: 0, y: 0, width: self.frame.width * CGFloat(self.dataViews.count), height: self.frame.height - self.param.headerHeight)
        scrollView.contentSize = CGSize(width: self.frame.width * CGFloat(self.dataViews.count), height: 0)
        header.updateDataArr(data: titles)
    }
    
    
    private var unreadMap = [Int:Int]()
    func refreshUnreadCount(index: Int, count: Int) {
        self.header.refreshUnreadCount(with: index, unreadCount: count)
        unreadMap[index] = count
        var unreadCount = 0
        unreadMap.values.forEach { (badge) in
            unreadCount += badge
        }
//        FZMUIMediator.shared().setApplicationIconBadgeNumber(unreadCount)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FZMScrollPageView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.dealWithScroll()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.dealWithScroll()
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.dealWithScroll()
    }
    
    private func dealWithScroll() {
        if !isInSelect {
            let index = Int((self.scrollView.contentOffset.x + self.scrollView.frame.width/2) / self.scrollView.frame.width)
            guard let view = self.dataViews[safe: index] else { return }
            view.didAppear()
            header.setSelectIndex(with: index)
            currentIndex = index
        }
    }
    
    func select(with index: Int) {
        self.scrollView.setContentOffset(CGPoint(x: CGFloat(k_ScreenWidth * CGFloat(index)), y: 0), animated: true)
    }
}

class FZMScrollPageItemBaseView: UIView {
    let bag = DisposeBag()
    var title = ""
    var unreadCount = 0 {
        didSet{
            unreadBlock?(index,unreadCount)
        }
    }
    
    var unreadBlock: ((Int,Int)->())? {
        didSet{
            unreadBlock?(index,unreadCount)
        }
    }
    
    var index = 0
    
    init(with pageTitle: String) {
        self.title = pageTitle
        super.init(frame: CGRect.zero)
        self.rx.observe(CGRect.self, "frame").subscribe {[weak self] (_) in
            self?.setNeedsUpdateConstraints()
            self?.layoutIfNeeded()
        }.disposed(by: bag)
    }
    
    func didAppear() {}
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
