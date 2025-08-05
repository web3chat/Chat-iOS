//
//  MessageVC.swift
//  chat
//
//  Created by 陈健 on 2020/12/21.
//

import UIKit
import SnapKit

class MessageVC: UIViewController, ViewControllerProtocol {
    
    let moreItemBarHeight: CGFloat = 100 + k_SafeBottomInset + 100
    
    lazy var collectionView: MessageCollectionView = {
        let v = MessageCollectionView.init()
        v.backgroundColor = self.view.backgroundColor
        v.contentInsetAdjustmentBehavior = .never
        v.alwaysBounceVertical = true
        v.delegate = self
        v.dataSource = self
        return v
    }()
    
    lazy var inputBarView: ChatInputBarView = {
        let v = ChatInputBarView.init()
        // 点击右侧更多按钮
        v.clickMoreBtnBlock = {[weak self] in
            guard let self = self else { return }
            if self.inputBarView.showMore {// 显示更多视图
                self.view.endEditing(true)
                self.showMoreItem()
            } else {// 切换回输入框
                self.showTextView(isClickMoreBtn: true)
            }
            
        }
        // 点击左侧语音按钮
        v.clickVoiceBtnBlock = {[weak self] in
            guard let self = self else { return }
            if self.inputBarView.showVoice {// 显示语音视图
                self.view.endEditing(false)
                self.showVoiceView()
            } else {// 切换回输入框
                self.showTextView()
            }
            
        }
        // 点左侧语音/键盘按钮
        v.showVoiceBlock = {[weak self] in
            guard let self = self else { return }
            //TODO
//            if self.inputBarView.showVoice {// 显示语音视图
//                self.view.endEditing(false)
//                self.showVoiceView()
//            }
        }
        // 键盘收回隐藏事件
        v.hideKeyboardBlock = {[weak self] in
            guard let self = self else { return }
            self.hideKeyboardAction()
        }
        return v
    }()
    
    // 底部更多视图
    lazy var moreBarView : FZMMoreItemBar = {
        let view = FZMMoreItemBar.init()
        return view
    }()
    
    // 底部添加聊天服务器视图
    lazy var addServerView: AddServerView = {
        let view = AddServerView.init()
        view.isHidden = true
        return view
    }()
    
    var collectionViewBottomInset: CGFloat = 0 {
        didSet {
            collectionView.contentInset.bottom = collectionViewBottomInset
            collectionView.scrollIndicatorInsets.bottom = collectionViewBottomInset - 40
        }
    }
    
    let hideKeyboardGesture = UIPanGestureRecognizer.init()
    
    override var shouldAutorotate: Bool {
        return false
    }
    
//    override func setNavBackgroundColor() {
//        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
//            let naba = UINavigationBarAppearance.init()
//            naba.configureWithOpaqueBackground()
//            naba.backgroundColor = Color_F6F7F8
//            naba.shadowColor = UIColor.lightGray
//            self.navigationController?.navigationBar.standardAppearance = naba
//            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
//        }
//    }
    
    deinit {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        
        self.setupSubviews()
        
        self.handleInputBarViewSpaceToBottom()
        
        self.addHideKeyboardGesture()
    }
    
    private func setupSubviews() {
        self.view.addSubview(self.collectionView)
        self.collectionView.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.leading.equalTo(self.safeAreaLeading)
            m.trailing.equalTo(self.safeAreaTrailing)
            m.bottom.equalToSuperview()
        }
        
        self.inputBarView.bindTo(view: self.view)
        
        self.moreBarView.bindTo(view: self.view)
        
        self.addServerView.bindTo(view: self.view)
        self.addServerView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.height.equalTo(80)
            m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
        }
        
        self.moreBarView.snp.makeConstraints { (m) in
            m.right.left.equalToSuperview()
            m.height.equalTo(100 + k_SafeBottomInset + 100)
            m.bottom.equalToSuperview().offset(self.moreItemBarHeight)
        }
        
        self.collectionViewBottomInset = self.inputBarView.height + k_SafeBottomInset
    }
}

extension MessageVC {
    
    // 显示更多视图
    private func showMoreItem() {
        self.inputBarView.showMore = true
        self.inputBarView.voiceBtn.setImage(#imageLiteral(resourceName: "inputBar_voice").withRenderingMode(.alwaysTemplate), for: .normal)
        self.inputBarView.textContenView.isHidden = false
        self.inputBarView.recordVoiceBtn.isHidden = true
        self.inputBarView.inputTextView.textView.resignFirstResponder()
        
        self.view.updateConstraints(with: 0.3) {
            
            self.inputBarView.textContenView.snp.updateConstraints { (m) in
                m.top.equalToSuperview().offset(self.inputBarView.textContenViewInsetCurrent.top)
                m.bottom.equalToSuperview().offset(-self.inputBarView.textContenViewInsetCurrent.bottom)
            }
            
            self.inputBarView.inputTextViewHeightConstraint?.update(offset: self.inputBarView.inputTextView.intrinsicContentSize.height)
            
            self.inputBarView.snp.updateConstraints { m in
                m.bottom.equalToSuperview().offset(-self.moreItemBarHeight)
            }
            
            self.moreBarView.snp.updateConstraints { (m) in
                m.bottom.equalToSuperview()
            }
        }
        
        let space = self.inputBarView.height + moreItemBarHeight
        self.setCollectionViewBottom(space)
    }
    
    // 显示语音视图
    private func showVoiceView() {
        self.inputBarView.voiceBtn.setImage(#imageLiteral(resourceName: "inputBar_text").withRenderingMode(.alwaysTemplate), for: .normal)
        self.inputBarView.textContenView.isHidden = true
        self.inputBarView.recordVoiceBtn.isHidden = false
        self.inputBarView.inputTextView.textView.resignFirstResponder()
        
        self.view.updateConstraints(with: 0.3) {
            self.inputBarView.textContenView.snp.updateConstraints { (m) in
                m.top.equalToSuperview().offset(self.inputBarView.textContenViewInsetDefault.top)
                m.bottom.equalToSuperview().offset(-self.inputBarView.textContenViewInsetDefault.bottom)
            }
            
            self.inputBarView.inputTextViewHeightConstraint?.update(offset: self.inputBarView.textViewHeightDefault)
            
            self.inputBarView.snp.updateConstraints { m in
                m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
            }
            
            self.moreBarView.snp.updateConstraints { (m) in
                m.bottom.equalToSuperview().offset(self.moreItemBarHeight)
            }
        }
        
        let space = self.inputBarView.height + k_SafeBottomInset
        self.setCollectionViewBottom(space)
    }
    
    //显示回输入框
    private func showTextView(isClickMoreBtn:Bool = false) {
        self.inputBarView.voiceBtn.setImage(#imageLiteral(resourceName: "inputBar_voice").withRenderingMode(.alwaysTemplate), for: .normal)
        self.inputBarView.textContenView.isHidden = false
        self.inputBarView.recordVoiceBtn.isHidden = true
//        self.inputBarView.inputTextView.textView.becomeFirstResponder()
        
        self.view.updateConstraints(with: 0.3) {
            self.inputBarView.textContenView.snp.updateConstraints { (m) in
                m.top.equalToSuperview().offset(self.inputBarView.textContenViewInsetCurrent.top)
                m.bottom.equalToSuperview().offset(-self.inputBarView.textContenViewInsetCurrent.bottom)
            }
            
            self.inputBarView.inputTextViewHeightConstraint?.update(offset: self.inputBarView.inputTextView.intrinsicContentSize.height)
            
            self.moreBarView.snp.updateConstraints { (m) in
                m.bottom.equalToSuperview().offset(self.moreItemBarHeight)
            }
            
//            self.inputBarView.inputTextView.textView.becomeFirstResponder()
        }
        
        let space = isClickMoreBtn ? self.inputBarView.height + self.moreItemBarHeight : self.inputBarView.height + k_SafeBottomInset
        self.setCollectionViewBottom(space)
        
        self.inputBarView.inputTextView.textView.becomeFirstResponder()
    }
    
    // 键盘收回隐藏事件处理（点击更多按钮/滚动消息列表触发）
    private func hideKeyboardAction(hideMoreView: Bool = false) {
        var space = self.inputBarView.height + k_SafeBottomInset
        
        if hideMoreView {// 需隐藏更多视图
            self.inputBarView.showMore = false
            self.view.updateConstraints(with: 0.3) {
                
                self.inputBarView.textContenView.snp.updateConstraints { (m) in
                    m.top.equalToSuperview().offset(self.inputBarView.textContenViewInsetCurrent.top)
                    m.bottom.equalToSuperview().offset(-self.inputBarView.textContenViewInsetCurrent.bottom)
                }
                
                self.inputBarView.snp.updateConstraints { m in
                    m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
                }
                
                self.moreBarView.snp.updateConstraints { (m) in
                    m.bottom.equalToSuperview().offset(self.moreItemBarHeight)
                }
            }
            space = self.inputBarView.height + k_SafeBottomInset
        } else {
            if self.inputBarView.showMore {
                self.view.updateConstraints(with: 0.3) {
                    
                    self.inputBarView.textContenView.snp.updateConstraints { (m) in
                        m.top.equalToSuperview().offset(self.inputBarView.textContenViewInsetCurrent.top)
                        m.bottom.equalToSuperview().offset(-self.inputBarView.textContenViewInsetCurrent.bottom)
                    }
                    
                    self.inputBarView.snp.updateConstraints { m in
                        m.bottom.equalToSuperview().offset(-self.moreItemBarHeight)
                    }
                    
                    self.moreBarView.snp.updateConstraints { (m) in
                        m.bottom.equalToSuperview()
                    }
                }
                space = self.inputBarView.height + self.moreItemBarHeight
            } else {
                self.view.updateConstraints(with: 0.3) {
                    
                    self.inputBarView.textContenView.snp.updateConstraints { (m) in
                        m.top.equalToSuperview().offset(self.inputBarView.textContenViewInsetCurrent.top)
                        m.bottom.equalToSuperview().offset(-self.inputBarView.textContenViewInsetCurrent.bottom)
                    }
                    
                    self.inputBarView.snp.updateConstraints { m in
                        m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
                    }
                    
                    self.moreBarView.snp.updateConstraints { (m) in
                        m.bottom.equalToSuperview().offset(self.moreItemBarHeight)
                    }
                }
                space = self.inputBarView.height + k_SafeBottomInset
            }
        }
        
        self.setCollectionViewBottom(space)
    }
    
    // 聊天列表添加手势以隐藏键盘
    private func addHideKeyboardGesture() {
        self.hideKeyboardGesture.delegate = self
        self.collectionView.addGestureRecognizer(self.hideKeyboardGesture)
    }
    
    // 输入框高度变化
    private func handleInputBarViewSpaceToBottom()  {
        self.inputBarView.changeSpaceToBottom = {[weak self] (space) in
            guard let self = self else { return }
            self.setCollectionViewBottom(space)
        }
    }
    
    // 设置聊天列表bottom
    private func setCollectionViewBottom(_ space: CGFloat) {
        guard self.collectionViewBottomInset != space else { return }
        self.collectionViewBottomInset = space
        self.collectionView.scrollToLastItem()
    }
}

extension MessageVC: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == self.hideKeyboardGesture else { return false }
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let velocity = panGesture.velocity(in: self.collectionView)
        if abs(velocity.y) > abs(velocity.x) {
            self.inputBarView.inputTextView.textView.resignFirstResponder()
            self.hideKeyboardAction(hideMoreView: true)
        }
        return false
    }
}

// MARK: - UICollectionViewDataSource
extension MessageVC: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let collectionView = collectionView as! MessageCollectionView
        return collectionView.messageDataSource?.numberOfSections(in: collectionView) ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let collectionView = collectionView as! MessageCollectionView
        return collectionView.messageDataSource?.messageCollectionView(collectionView, numberOfItemsInSection: section) ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let collectionView = collectionView as? MessageCollectionView else {
            return UICollectionViewCell.init()
        }
        guard let messageDataSource = collectionView.messageDataSource else {
            return UICollectionViewCell.init()
        }
        let message = messageDataSource.messageCollectionView(collectionView, messageForItemAt: indexPath)
        
//        // 暂时只支持文字消息类型
//        let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
//        cell.configure(with: message, at: indexPath, and: collectionView)
//        return cell
        
        switch message.kind {
        case .text:
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .attributedText:
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .video:
            let cell = collectionView.dequeueReusableCell(MediaMessageCell.self, for: indexPath)
//            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .photo:
            let cell = collectionView.dequeueReusableCell(MediaMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .audio:
            let cell = collectionView.dequeueReusableCell(AudioMessageCell.self, for: indexPath)
//            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .system(_):
            let cell = collectionView.dequeueReusableCell(SystemMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .file(_):
            let cell = collectionView.dequeueReusableCell(FileMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .notification(_):
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .forward(_):
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .transfer:
            let cell = collectionView.dequeueReusableCell(TransferMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .RTCCall(_):
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .collect(_):
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .redPacket(_):
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .contactCard(_):
            let cell = collectionView.dequeueReusableCell(ContactCardMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        case .UNRECOGNIZED(_):
            let cell = collectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: collectionView)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let collectionView = collectionView as! MessageCollectionView
        let messagesDisplayDelegate = collectionView.messagesDisplayDelegate!
        return messagesDisplayDelegate.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension MessageVC: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? MessageCollectionViewLayout else { return .zero }
        return layout.sizeForItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let collectionView = collectionView as! MessageCollectionView
        guard let layoutDataSource = collectionView.messageLayoutDataSource else { return .zero}
        return layoutDataSource.collectionView(collectionView, insetForSectionAt: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let collectionView = collectionView as! MessageCollectionView
        guard let layoutDataSource = collectionView.messageLayoutDataSource else { return .zero}
        return layoutDataSource.headerViewSize(for: section, in: collectionView)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let collectionView = collectionView as! MessageCollectionView
        guard let layoutDataSource = collectionView.messageLayoutDataSource else { return .zero}
        return layoutDataSource.footerViewSize(for: section, in: collectionView)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//        let collectionView = collectionView as! MessageCollectionView
//        let messagesDisplayDelegate = collectionView.messagesDisplayDelegate!
//        return messagesDisplayDelegate.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
}


