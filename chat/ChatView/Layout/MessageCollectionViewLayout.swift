//
//  MessageCollectionViewLayout.swift
//  chat
//
//  Created by 陈健 on 2020/12/21.
//

import UIKit

class MessageCollectionViewLayout: UICollectionViewFlowLayout {
    
    override class var layoutAttributesClass: AnyClass {
        return MessageCollectionViewLayoutAttributes.self
    }
    
    var messageCollecitonView: MessageCollectionView {
        return self.collectionView as! MessageCollectionView
    }
    
    var messageDataSource: MessageDataSource {
        return self.messageCollecitonView.messageDataSource!
    }
    
    var messageLayoutDataSource: MessageLayoutDataSource {
        return self.messageCollecitonView.messageLayoutDataSource!
    }
    
    var itemWidth: CGFloat {
        guard let collectionView = self.collectionView else { return 0 }
        return collectionView.frame.width - self.sectionInset.left - self.sectionInset.right
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributesArray = super.layoutAttributesForElements(in: rect) as? [MessageCollectionViewLayoutAttributes] else {
            return nil
        }
        
        for attributes in attributesArray where attributes.representedElementCategory == .cell {
            let cellSizeCalculator = self.cellSizeCalculatorForItem(at: attributes.indexPath)
            cellSizeCalculator.configure(attributes: attributes)
        }
        return attributesArray
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) as? MessageCollectionViewLayoutAttributes else {
            return nil
        }
        if attributes.representedElementCategory == .cell {
            let cellSizeCalculator = self.cellSizeCalculatorForItem(at: attributes.indexPath)
            cellSizeCalculator.configure(attributes: attributes)
        }
        return attributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return self.collectionView?.bounds.width != newBounds.width
    }
    
    open override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        guard let flowLayoutContext = context as? UICollectionViewFlowLayoutInvalidationContext else { return context }
        flowLayoutContext.invalidateFlowLayoutDelegateMetrics = shouldInvalidateLayout(forBoundsChange: newBounds)
        return flowLayoutContext
    }
    
    
    lazy var textMessageSizeCalculator = TextMessageSizeCalculator(layout: self)
    lazy var attributedTextMessageSizeCalculator = TextMessageSizeCalculator(layout: self)
    lazy var photoMessageSizeCalculator = MediaMessageSizeCalculator(layout: self)
    lazy var videoMessageSizeCalculator = MediaMessageSizeCalculator(layout: self)
    lazy var audioMessageSizeCalculator = AudioMessageSizeCalculator(layout: self)
    lazy var fileMessageSizeCalculator = FileMessageSizeCalculator(layout: self)
    lazy var transferMeessageSizeCalculator = TransferMeessageSizeCalculator(layout: self)
    lazy var contactCardMessageSizeCalculator = ContactCardMessageSizeCalculator(layout: self)
    lazy var systemMessageSizeCalculator = SystemMessageSizeCalculator(layout: self)
    override init() {
        super.init()
        self.setupView()
        self.setupObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        FZM_NotificationCenter.removeObserver(self)
    }
    
    private func setupView() {
        self.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    
    private func setupObserver() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(handleOrientationChange(_:)), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
    @objc
    private func handleOrientationChange(_ notification: Notification) {
        self.invalidateLayout()
    }
    
    func cellSizeCalculatorForItem(at indexPath: IndexPath) -> CellSizeCalculator {
        let message = self.messageDataSource.messageCollectionView(self.messageCollecitonView, messageForItemAt: indexPath)
        switch message.kind {
        case .system:
            return self.systemMessageSizeCalculator
        case .text:
            return self.textMessageSizeCalculator
        case .attributedText:
            return self.attributedTextMessageSizeCalculator
        case .video:
            return self.videoMessageSizeCalculator
        case .photo:
            return self.photoMessageSizeCalculator
        case .audio:
            return self.audioMessageSizeCalculator
        case .file:
            return self.fileMessageSizeCalculator
        case .transfer:
            return self.transferMeessageSizeCalculator
//            return self.audioMessageSizeCalculator//wjhTODO
//        case .card:
//            return self.textMessageSizeCalculator
        case .notification:
            return self.textMessageSizeCalculator
        case .forward:
            return self.textMessageSizeCalculator
        case .RTCCall(_):
            return self.textMessageSizeCalculator
        case .collect(_):
            return self.textMessageSizeCalculator
        case .redPacket(_):
            return self.textMessageSizeCalculator
        case .contactCard(_):
            return self.contactCardMessageSizeCalculator
        case .UNRECOGNIZED:
            return self.textMessageSizeCalculator
        }
    }
    
    func sizeForItem(at indexPath: IndexPath) -> CGSize {
        let calculator = self.cellSizeCalculatorForItem(at: indexPath)
        return calculator.sizeForItem(at: indexPath)
    }
}
