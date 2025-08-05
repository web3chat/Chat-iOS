//
//  MessageCollectionView.swift
//  chat
//
//  Created by 陈健 on 2020/12/21.
//

import UIKit

class MessageCollectionView: UICollectionView {
    
    weak var messageDataSource: MessageDataSource?
    weak var messageLayoutDataSource: MessageLayoutDataSource?
    weak var messagesDisplayDelegate: MessagesDisplayDelegate?
    weak var messageCellDelegate: MessageCellDelegate?
    
    convenience init() {
        self.init(frame: .zero, collectionViewLayout: MessageCollectionViewLayout.init())
    }
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.backgroundColor = .white
        self.registerCells()
        self.setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func registerCells() {
        self.register(viewClass: MessageCollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        self.register(viewClass: MessageCollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter)
        
        self.register(TextMessageCell.self)
        self.register(MediaMessageCell.self)
        self.register(AudioMessageCell.self)
        self.register(FileMessageCell.self)
        self.register(TransferMessageCell.self)
        self.register(ContactCardMessageCell.self)
        self.register(SystemMessageCell.self)
    }
    
    private func setupGestureRecognizers() {
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(handleTapGesture(_:)))
        tap.delaysTouchesBegan = true
        self.addGestureRecognizer(tap)
        
        let longPress = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPressGesture(_:)))
        longPress.delaysTouchesBegan = true
        self.addGestureRecognizer(longPress)
    }
    
    @objc private func handleTapGesture(_ gesture: UIGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let touchLocation = gesture.location(in: self)
        guard let indexPath = self.indexPathForItem(at: touchLocation) else { return }
        let cell = self.cellForItem(at: indexPath) as? HandleGesture
        cell?.handleTapGesture(gesture)
    }
    
    @objc private func handleLongPressGesture(_ longPressGesture: UILongPressGestureRecognizer) {
        guard longPressGesture.state == .began else { return }
        let touchLocation = longPressGesture.location(in: self)
        guard let indexPath = self.indexPathForItem(at: touchLocation) else { return }
        let cell = self.cellForItem(at: indexPath) as? HandleGesture
        cell?.handleLongPressGesture(longPressGesture)
    }
    
    func reloadDataAndKeepOffset() {
        setContentOffset(contentOffset, animated: false)
        let beforeContentSize = self.contentSize
        self.reloadData()
        layoutIfNeeded()
        let afterContentSize = self.contentSize
        
        let newOffset = CGPoint.init(
            x: self.contentOffset.x + (afterContentSize.width - beforeContentSize.width),
            y: self.contentOffset.y + (afterContentSize.height - beforeContentSize.height))
        self.setContentOffset(newOffset, animated: false)
    }
    
    // 滚动到最新一条消息（底部）
    func scrollToLastItem(at pos: UICollectionView.ScrollPosition = .bottom, animated: Bool = true) {
        guard self.numberOfSections > 0 else { return }
        let lastSection = self.numberOfSections - 1
        let lastItemIndex = self.numberOfItems(inSection: lastSection) - 1
        guard lastItemIndex >= 0 else { return }
        let indexPath = IndexPath.init(row: lastItemIndex, section: lastSection)
        self.scrollToItem(at: indexPath, at: pos, animated: animated)
    }
    
    // 滚动到指定一条消息 如：最新未读26条数据则传入specifiedIndex = 26
    func scrollToSpecifiedItem(at specifiedIndex: Int, pos: UICollectionView.ScrollPosition = .top, animated: Bool = true) {
        guard specifiedIndex > 0, self.numberOfSections > specifiedIndex else {
            self.scrollToFirstItem()
            return
        }
        let specifiedSection = self.numberOfSections - specifiedIndex
        let indexPath = IndexPath.init(row: 0, section: specifiedSection)
        self.scrollToItem(at: indexPath, at: pos, animated: animated)
    }
    
    // 滚动到第一条未读消息 at topSection: Int, 
    func scrollToFirstItem(pos: UICollectionView.ScrollPosition = .top, animated: Bool = true) {
        guard self.numberOfSections > 0 else { return }
        let indexPath = IndexPath.init(row: 0, section: 0)
        self.scrollToItem(at: indexPath, at: pos, animated: animated)
    }
    
}

extension MessageCollectionView {
    func register<T: UICollectionViewCell>(_ cellClass: T.Type) {
        self.register(cellClass, forCellWithReuseIdentifier: String.init(describing: T.self))
    }
    
    func dequeueReusableCell<T: UICollectionViewCell>(_ cellClass: T.Type, for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withReuseIdentifier: String(describing: T.self), for: indexPath) as? T else {
            fatalError("Couldn't find UICollectionViewCell for \(String(describing: T.self)), make sure the cell is registered with collection view")
        }
        return cell
    }
    
    func register<T: UICollectionReusableView>(viewClass: T.Type, forSupplementaryViewOfKind kind: String) {
        self.register(viewClass, forSupplementaryViewOfKind: kind, withReuseIdentifier: String.init(describing: T.self))
    }
    
    func dequeueReusableSupplementaryView<T: UICollectionReusableView>(ofKind: String, for indexPath: IndexPath) -> T {
        guard  let view = self.dequeueReusableSupplementaryView(ofKind: ofKind, withReuseIdentifier: String.init(describing: T.self), for: indexPath) as? T else {
            fatalError("Couldn't find UICollectionReusableView for \(String(describing: T.self)), make sure the cell is registered with collection view")
        }
        return view
    }
    
}
