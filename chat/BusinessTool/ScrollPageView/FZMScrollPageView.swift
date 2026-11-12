//
//  FZMScrollPageView.swift
//  Chat33
//
//  Created by fzm on 2018/9/26.
//  Copyright © 2018年 fzm. All rights reserved.
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
    /// 分页容器：手势开始时问一次「这一下该不该由当前页自己处理」（见 `blocksPaging(for:)`）。
    /// 广场页（`SquareFeedPageView`）靠它把左右滑留给自己的筛选切换：
    /// 停在最右的「公众号」之前向左滑不给外层翻页，滑到边界后才交给本容器翻到「私聊」。
    private lazy var scrollView : FZMPagingLockScrollView = {
        let view = FZMPagingLockScrollView()
        view.frame = CGRect(x: 0, y: self.param.headerHeight, width: self.frame.width, height: self.frame.height - self.param.headerHeight)
        view.isPagingEnabled = true
        view.isDirectionalLockEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.delegate = self
        view.blocksPaging = { [weak self] velocity in
            return self?.blocksPaging(for: velocity) ?? false
        }
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
        guard !isInSelect else { return }
        let index = visiblePageIndex
        guard let view = self.dataViews[safe: index] else { return }
        view.didAppear()
        // ⚠️ 只在下标真的变化时才同步选中态：本方法在 scrollViewDidScroll 里**每帧**都会被调到，
        // 原来无条件调 setSelectIndex（内部 collectionView.reloadData + 隐式动画改 frame），
        // 一次滑动要白刷几十次，是翻页手感发涩的来源之一。
        guard index != currentIndex else { return }
        header.setSelectIndex(with: index)
        currentIndex = index
    }

    /// 当前停在的页码：按 contentOffset 实时算，不依赖 currentIndex 的更新时机（它在滚动回调里可能被跳过/滞后）
    private var visiblePageIndex: Int {
        let width = self.scrollView.frame.width
        guard width > 0, !self.dataViews.isEmpty else { return self.currentIndex }
        let raw = ((self.scrollView.contentOffset.x + width / 2) / width).rounded(.down)
        return min(max(Int(raw), 0), self.dataViews.count - 1)
    }

    /// 手势开始时判断这一下该不该由当前页自己处理（true = 外层不翻页）
    private func blocksPaging(for velocity: CGPoint) -> Bool {
        guard let page = self.dataViews[safe: self.visiblePageIndex], page.locksHorizontalPaging else { return false }
        // 纵向拖动（列表滚动）一律交给当前页
        guard abs(velocity.x) > abs(velocity.y) else { return true }
        return page.blocksHorizontalPaging(direction: velocity.x > 0 ? 1 : -1)
    }
    
    /// 切换到指定分段
    /// - Parameter animated: 默认带动画；传 false 立即跳转
    /// 说明：不用 `setContentOffset(animated:)`，它在布局被外部改动/动画进行中时会偶发不生效（点分段只见选中态变化、页面不切）；
    /// 这里自己用 UIView 动画驱动 contentOffset，并在动画结束后兜底校正一次。
    func select(with index: Int, animated: Bool = true) {
        guard index >= 0, index < dataViews.count else { return }
        let width = self.scrollView.bounds.width > 0 ? self.scrollView.bounds.width : self.frame.width
        guard width > 0 else { return }

        // 兜底：内容宽度不足时偏移会被夹住（表现同样是「点了不切页」）
        let expectWidth = width * CGFloat(dataViews.count)
        if self.scrollView.contentSize.width < expectWidth - 1 {
            self.scrollView.contentSize = CGSize(width: expectWidth, height: self.scrollView.contentSize.height)
        }

        let target = CGPoint(x: width * CGFloat(index), y: self.scrollView.contentOffset.y)
        guard animated else {
            self.scrollView.setContentOffset(target, animated: false)
            return
        }

        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]) {
            self.scrollView.contentOffset = target
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.dealWithScroll()
            // 被外部动画/布局打断时补齐
            if abs(self.scrollView.contentOffset.x - target.x) > 1 {
                self.scrollView.setContentOffset(target, animated: false)
                self.dealWithScroll()
            }
        }
    }
}

/// 外层分页 scroll view：手势开始时问一次「这一下该不该由当前页自己处理」。
/// 只在滚动结束后改 `isScrollEnabled` 会漏：手指抬起即停的拖动不会走 `didEndDecelerating`，
/// 那一次锁就没生效（能在广场页把整页拖到群聊）；而且 `isScrollEnabled == false` 会连
/// 「广场页滑到最右筛选项后还想翻到私聊」这种本该允许的翻页一起禁掉。
/// 现在改成按拖动方向实时判断，不再依赖滚动结束时机。
private final class FZMPagingLockScrollView: UIScrollView {

    /// 参数是手势速度；返回 true 表示这次拖动外层不参与（由当前页自己处理）
    var blocksPaging: ((CGPoint) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.panGestureRecognizer,
           self.blocksPaging?(self.panGestureRecognizer.velocity(in: self)) == true {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
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

    /// 该页是否自己处理横向滑动（true 时外层（广场 / 私聊 / 群聊）的翻页会被关掉）
    var locksHorizontalPaging: Bool { return false }

    /// 该页自己处理横滑时，指定方向的滑动是否仍由自己处理（返回 false = 让外层翻页）
    /// - Parameter direction: 1 = 手指向右（翻到上一段），-1 = 手指向左（翻到下一段）
    func blocksHorizontalPaging(direction: CGFloat) -> Bool {
        return locksHorizontalPaging
    }
    
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
