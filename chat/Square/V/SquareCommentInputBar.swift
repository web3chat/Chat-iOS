//
//  SquareCommentInputBar.swift
//  chat
//
//  广场详情页底部评论输入条（评论关闭时禁用并展示占位文案）
//

import Foundation
import UIKit
import SnapKit

final class SquareCommentInputBar: UIView {

    /// 点击发送（内容已去掉首尾空白）
    var onSend: ((String) -> Void)?

    /// 是否正在发送（发送中禁止重复点击）
    var isSending = false {
        didSet {
            updateSendButton()
        }
    }

    private var placeholder = L("说点什么...")
    /// 评论是否开放（关闭后输入框不可编辑、发送按钮隐藏）
    private var commentsEnabled = true
    /// 输入区高度（随内容长高，最多约 4 行）
    private var inputHeight: CGFloat = SquareCommentInputBar.minInputHeight
    private static let minInputHeight: CGFloat = 34
    private static let maxInputHeight: CGFloat = 90
    /// 输入框上下的内边距（顶部到细线、底部到键盘）
    private static let verticalInset: CGFloat = 8
    private var containerHeightConstraint: SnapKit.Constraint?

    // MARK: - 键盘跟随（inputAccessoryView 方案）
    //
    // 输入条不再自己监听键盘做 `UIView.animate` —— 实测通知驱动的跟随动画无论怎么
    // 对齐时长/曲线/行程，键盘块的上沿都会从输入条下面露出来，就是用户看到的那条细线
    // （关闭跟随时线消失、恢复跟随时线复现，已实锤线来自跟随动画）。
    // 现在把整条输入条交给系统：设成输入框的 `inputAccessoryView`，键盘弹起时系统
    // 把它直接挂在键盘顶上、和键盘同一个动画 —— 像素级同步，物理上不可能再错位。
    //
    // 收起时输入条跟着键盘滑出屏幕；键盘完全收起（keyboardDidHide）后摘下来，
    // 由外层通过 `onKeyboardHidden` 放回页面底部占位条的位置。

    /// 输入条纯内容高度（细线 + 输入框 + 上下内边距，不含底部安全区垫块）
    private static let contentHeight: CGFloat = minInputHeight + verticalInset * 2
    /// 输入条常驻页面底部时的总高度（含安全区垫块），外层占位条按它对齐
    static var restHeight: CGFloat {
        return contentHeight + k_SafeBottomInset
    }

    /// 键盘弹起回调（带键盘高度，外层用它修正评论滚动的可见区）
    var onKeyboardShown: ((CGFloat) -> Void)?
    /// 键盘完全收起、输入条已从键盘上摘下来后的回调（外层把输入条放回页面底部）
    var onKeyboardHidden: (() -> Void)?
    /// 输入内容变化回调（键盘输入条同步文本给页面展示条用）
    var onTextChanged: ((String) -> Void)?
    /// 展示条被点击时转发的焦点请求（页面展示条 → 键盘输入条）
    var onRequestFocus: (() -> Void)?
    /// 键盘专用输入条在“不在键盘上”时的宿主视图（透明、屏幕外挂在那里，保证在 window 中）
    weak var restHostView: UIView?
    /// 展示条上的「发送」被点击时转发给外层（展示条自己没有编辑内容，内容在键盘输入条里）
    var onSendRequested: (() -> Void)?
    /// 只作展示（页面底部常驻的那条）：不参与编辑、不挂键盘，点击把焦点转给键盘输入条。
    /// 页面展示条永远待在页面里 —— 键盘上的那条是另一个专用实例，
    /// 因此彻底不存在「把输入条从键盘上抢回页面」这回事（之前输入条跑到左上角的根源）。
    var isDisplayOnly = false {
        didSet {
            textView.isUserInteractionEnabled = !isDisplayOnly
            // 焦点手势只挂在输入框容器上（不挂在整条上）——否则点「发送」会同时触发弹键盘
            if isDisplayOnly {
                containerView.addGestureRecognizer(displayTap)
            } else {
                containerView.removeGestureRecognizer(displayTap)
            }
        }
    }
    private lazy var displayTap: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(displayTapAction))
    }()
    /// 项目已有的键盘模块（只用来拿键盘高度和「完全收起」时机，不做任何跟随动画）
    private lazy var keyboardObserver = KeyboardObserver()
    /// 当前键盘高度（0 = 收起）
    private(set) var keyboardHeight: CGFloat = 0

    /// 底部安全区垫块（白色）：输入条常驻页面底部时占满「安全区」高度；
    /// 挂到键盘上时高度收成 0（不能挡住键盘候选栏）。
    private lazy var bottomSafeStrip: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        return view
    }()
    private var bottomSafeStripHeightConstraint: SnapKit.Constraint?

    /// 输入条当前应有高度（输入区高度 + 上下内边距 + 垫块）
    var preferredHeight: CGFloat {
        return inputHeight + SquareCommentInputBar.verticalInset * 2 + currentStripHeight
    }

    /// 挂到键盘上时系统按固有尺寸放 accessoryView
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
    }

    /// 输入条当前是不是挂在键盘上（作为 textView 的 accessoryView）
    private var isAttachedToKeyboard: Bool {
        return textView.inputAccessoryView === self
    }

    /// 输入条是否正挂在键盘上（外层用它判断要不要把输入条抢回页面）
    var isOnKeyboard: Bool {
        return isAttachedToKeyboard
    }

    /// 底部垫块当前该多高：挂键盘上 0，常驻页面时安全区高度
    private var currentStripHeight: CGFloat {
        return isAttachedToKeyboard ? 0 : k_SafeBottomInset
    }

    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 17
        view.clipsToBounds = true
        return view
    }()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.font = .regularFont(14)
        view.textColor = Color_24374E
        view.backgroundColor = .clear
        view.tintColor = Color_Theme
        view.returnKeyType = .send
        view.delegate = self
        view.textContainerInset = UIEdgeInsets.init(top: 8, left: 4, bottom: 8, right: 4)
        // 输入框不需要滚动条（横向的会显示成输入框底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.addSubview(placeHolderLab)
        placeHolderLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(9)
            m.top.equalToSuperview().offset(8)
            m.right.equalToSuperview().offset(-9)
        }
        return view
    }()

    private lazy var placeHolderLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: placeholder)
    }()

    private lazy var sendBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("发送"), for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.titleLabel?.font = .mediumFont(14)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 17
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(sendTap), for: .touchUpInside)
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = Color_FFFFFF
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // 输入条与 textView 互持（accessoryView）成环，兜底断环
        textView.inputAccessoryView = nil
        scrollIndicatorHider.stopNow()
    }

    private func setupViews() {
        // 输入条顶部细线：它是输入条的顶边，跟着输入条一起动，不会和表格内容错位
        let lineView = UIView()
        lineView.backgroundColor = Color_E6EAEE
        self.addSubview(lineView)
        self.addSubview(containerView)
        containerView.addSubview(textView)
        self.addSubview(sendBtn)

        lineView.snp.makeConstraints { (m) in
            m.left.right.top.equalToSuperview()
            m.height.equalTo(0.5)
        }

        self.addSubview(bottomSafeStrip)
        bottomSafeStrip.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            bottomSafeStripHeightConstraint = m.height.equalTo(self.currentStripHeight).constraint
        }

        containerView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalTo(sendBtn.snp.left).offset(-10)
            m.top.equalToSuperview().offset(SquareCommentInputBar.verticalInset)
            containerHeightConstraint = m.height.equalTo(SquareCommentInputBar.minInputHeight).constraint
            m.bottom.equalTo(bottomSafeStrip.snp.top).offset(-SquareCommentInputBar.verticalInset)
        }

        textView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }

        sendBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(containerView)
            m.width.equalTo(60)
            m.height.equalTo(34)
        }

        updateSendButton()

        // 编辑期间抹掉系统键盘里的滚动条细线（还在编辑就别停，防止快速重聚焦被停掉）
        scrollIndicatorHider.isStillEditing = { [weak self] in
            self?.textView.isFirstResponder ?? false
        }
    }

    // MARK: - 对外

    /// 当前输入内容（已去首尾空白）
    var trimmedText: String {
        return textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 清空输入
    func clear() {
        textView.text = ""
        placeHolderLab.isHidden = false
        updateInputHeight()
        updateSendButton()
    }

    /// 自动聚焦输入框：先把整条输入条交给键盘（accessoryView），再弹键盘 ——
    /// 系统把输入条挂在键盘顶上、和键盘同一个动画，像素级同步。
    func becomeInputFirstResponder() {
        if isDisplayOnly {
            // 展示条不参与编辑：把焦点转给键盘输入条
            onRequestFocus?()
            return
        }
        // 兜底：必须待在 window 里才能成为第一响应者。键盘收起后输入条会被系统摘掉父视图，
        // 这里自动把它挂回宿主（透明 + 屏幕外，不可见；不能用 isHidden —— 隐藏视图不能成为第一响应者）
        if self.window == nil, let host = restHostView {
            self.alpha = 0
            host.addSubview(self)
            self.frame = CGRect(x: 0, y: -300,
                                width: host.bounds.width,
                                height: preferredHeight)
        }
        attachToKeyboard()
        textView.becomeFirstResponder()
    }

    /// 把输入条设成 textView 的 accessoryView：
    /// 键盘弹起时系统自动把输入条从当前父视图摘走、挂到键盘顶上。
    /// 挂之前先收起底部垫块（键盘上不能挡候选栏）、改用自动布局高度（accessory 按它定高）。
    private func attachToKeyboard() {
        guard !isAttachedToKeyboard else { return }
        // 垫块收 0（不挡候选栏）、高度收成纯内容高度。
        // ⚠️ 这里不设 alpha=1、也不调位置：输入条此刻可能还在系统键盘容器里被摆在 (0,0)，
        //    一亮就会在左上角闪一个「残影」。显示时机统一放到 textViewDidBeginEditing（已在键盘上）。
        bottomSafeStripHeightConstraint?.update(offset: 0)
        self.frame = CGRect(x: self.frame.minX,
                            y: self.frame.minY,
                            width: self.frame.width,
                            height: preferredHeight)
        self.layoutIfNeeded()
        self.invalidateIntrinsicContentSize()
        textView.inputAccessoryView = self
    }

    /// 键盘完全收起后把输入条从键盘上摘下来（恢复垫块与常驻高度）。
    /// 摘下来后输入条的父视图会变空，由外层 `onKeyboardHidden` 放回页面底部。
    private func detachFromKeyboard() {
        textView.inputAccessoryView = nil
        bottomSafeStripHeightConstraint?.update(offset: k_SafeBottomInset)
        self.layoutIfNeeded()
        // frame（含垫块高度）由外层 alignToBottom 恢复
    }

    /// 页面上时：底边对齐所在视图底边、宽度铺满、高度按当前内容。
    /// frame 完全由这里决定，不依赖自动布局引擎 ——
    /// 引擎对「只有自约束、没有定位约束」的视图会算出零尺寸/错位 frame（就是刚才的显示错乱）。
    func alignToBottom(of view: UIView) {
        let target = CGRect(x: 0,
                            y: view.bounds.height - preferredHeight,
                            width: view.bounds.width,
                            height: preferredHeight)
        guard self.frame != target else { return }
        self.frame = target
        self.layoutIfNeeded()
    }

    /// 自身高度变化时刷新：挂键盘上让系统重排 accessory；页面上底边不动向上长/缩
    private func refreshSelfHeight() {
        if isAttachedToKeyboard {
            self.invalidateIntrinsicContentSize()
            return
        }
        guard let superview = self.superview else { return }
        let height = preferredHeight
        if abs(self.frame.height - height) > 0.5 {
            self.frame = CGRect(x: self.frame.minX,
                                y: self.frame.maxY - height,
                                width: self.frame.width,
                                height: height)
        }
        self.layoutIfNeeded()
    }

    /// 键盘是否已经弹起（键盘高度没变化时不会走 `onKeyboardShown`，外层拿它做兼容）
    var isKeyboardVisible: Bool {
        return keyboardHeight > 0
    }

    /// 挂到页面底部（页面展示条用）：只 addSubview，位置由外层对齐；不监听键盘。
    /// 展示条永远待在页面里，不会被系统摘走 —— 键盘上的那条是另一个专用实例。
    func bindTo(view: UIView) {
        view.addSubview(self)
        // 立即对齐一次，避免首个布局周期里输入条还是零尺寸 frame
        alignToBottom(of: view)
        if !isDisplayOnly {
            observeKeyboard()
        }
    }

    /// 键盘专用输入条初始化：不进页面可视区域，只在键盘上出现。
    /// 垫块常收（不挡候选栏）、透明 + 放在屏幕外（防残影）。
    /// ⚠️ 不能用 `isHidden = true`：隐藏视图不能成为第一响应者，键盘会弹不出来。
    func prepareForKeyboardUse() {
        bottomSafeStripHeightConstraint?.update(offset: 0)
        self.alpha = 0
        self.frame = CGRect(x: 0, y: -300,
                            width: UIScreen.main.bounds.width,
                            height: preferredHeight)
        self.layoutIfNeeded()
        observeKeyboard()
    }

    /// 展示条同步键盘输入条的文本
    func display(text: String?) {
        textView.text = text ?? ""
        placeHolderLab.isHidden = !textView.text.isEmpty
        updateInputHeight()
        updateSendButton()
    }

    private func observeKeyboard() {
        let changed: (KeyboardNotification) -> Void = { [weak self] notification in
            guard let self = self else { return }
            let frame = notification.endFrame
            // 键盘整块滑出屏幕 = 已经收起。有的收起路径（拖动收起等）不一定给 didHide，
            // 这里一并处理 —— 否则输入条会被永远留在键盘上、回不到页面里。
            if frame.height <= 0 || frame.minY >= UIScreen.main.bounds.height - 0.5 {
                self.handleKeyboardHidden()
                return
            }
            let height = frame.height
            guard abs(height - self.keyboardHeight) > 0.5 else { return }
            self.keyboardHeight = height
            // 键盘起来了：此刻输入条已经在键盘顶上，可以显示（早于这个时机点亮会在左上角闪残影）
            if self.isAttachedToKeyboard {
                self.alpha = 1
            }
            self.onKeyboardShown?(height)
        }
        keyboardObserver.callbacks[.willShow] = changed
        keyboardObserver.callbacks[.willChangeFrame] = changed
        // 键盘已经升到位：确保输入条可见（这一刻它肯定已经贴在键盘顶上，不会闪到左上角）
        keyboardObserver.callbacks[.didShow] = { [weak self] _ in
            guard let self = self, self.isAttachedToKeyboard else { return }
            self.alpha = 1
        }
        keyboardObserver.callbacks[.didHide] = { [weak self] _ in
            self?.handleKeyboardHidden()
        }
    }

    /// 键盘收起：把输入条从键盘上摘下来（幂等，可重复调用）
    private func handleKeyboardHidden() {
        guard isAttachedToKeyboard || keyboardHeight > 0 else { return }
        keyboardHeight = 0
        detachFromKeyboard()
        // 键盘输入条只在键盘上出现：摘下来后透明，杜绝任何「残影」
        self.alpha = 0
        onKeyboardHidden?()
    }

    // MARK: - 抹掉系统键盘里的那条滚动条
    //
    // 键盘上方 / 页面顶部会一闪而过的那条黑细线，是系统画出来的滚动指示器
    // （私有类 `_UIScrollViewScrollIndicator`）。它不在我们的视图树里，公开 API 改不了它的样式，
    // 只能运行时把它设成透明（只改 alpha，不动系统结构；匹配不到时什么都不做，不会崩）。
    // 具体实现在文件末尾的 `SquareSystemScrollIndicatorHider`（详情页输入条与发帖页输入框共用）。
    // ⚠️ 属于操作系统私有视图：iOS 版本变化后可能失效；想要彻底去掉这段行为，
    //    删掉 `textViewDidBeginEditing` / `textViewDidEndEditing` 里的两行调用即可。

    private let scrollIndicatorHider = SquareSystemScrollIndicatorHider()
    /// 回复某人：在输入框插入「@昵称 」并聚焦（接口无层级回复字段，用文字 @ 表达回复对象）
    func appendMention(name: String) {
        guard textView.isEditable, !name.isEmpty else { return }

        let mention = "@\(name) "
        var current = textView.text ?? ""
        // 已在回复某人时替换旧的 @ 前缀，避免叠多个 @
        if current.hasPrefix("@"), let spaceIndex = current.firstIndex(of: " ") {
            current = String(current[current.index(after: spaceIndex)...])
        }
        textView.text = mention + current
        placeHolderLab.isHidden = true
        updateInputHeight()
        updateSendButton()
        becomeInputFirstResponder()

        let end = textView.endOfDocument
        textView.selectedTextRange = textView.textRange(from: end, to: end)
    }

    func resignInputFirstResponder() {
        textView.resignFirstResponder()
    }

    /// 评论关闭时禁用输入（占位文案改为「评论已关闭」）
    func setCommentsEnabled(_ enabled: Bool) {
        commentsEnabled = enabled
        textView.isEditable = enabled
        textView.isUserInteractionEnabled = enabled && !isDisplayOnly
        sendBtn.isHidden = !enabled
        placeholder = enabled ? L("说点什么...") : L("评论已关闭")
        placeHolderLab.text = placeholder
        placeHolderLab.isHidden = enabled ? !trimmedText.isEmpty : false
        if !enabled {
            resignInputFirstResponder()
        }
        updateSendButton()
    }

    // MARK: - 私有

    private func updateSendButton() {
        let valid = !trimmedText.isEmpty && !isSending && textView.isEditable
        sendBtn.isEnabled = valid
        sendBtn.backgroundColor = valid ? Color_Theme : Color_CCD1E0
    }

    /// 输入框随内容长高（超过上限后内部滚动），便于看到自己打了什么
    private func updateInputHeight() {
        let width = max(textView.bounds.width - 8, 1)
        let fitting = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let target = min(max(SquareCommentInputBar.minInputHeight, ceil(fitting) + 2), SquareCommentInputBar.maxInputHeight)
        guard abs(target - inputHeight) > 0.5 else { return }

        inputHeight = target
        textView.isScrollEnabled = target >= SquareCommentInputBar.maxInputHeight
        containerHeightConstraint?.update(offset: target)
        // 输入条总高度同步（页面上底边不动向上长；挂键盘上更新固有尺寸让系统重排 accessory）
        refreshSelfHeight()
        self.setNeedsLayout()
        self.superview?.layoutIfNeeded()
    }

    @objc private func sendTap() {
        if isDisplayOnly {
            // 展示条里没有真正的编辑内容：把发送请求转给外层（用键盘输入条的内容发）
            onSendRequested?()
            return
        }
        let text = trimmedText
        guard !text.isEmpty, !isSending else { return }
        onSend?(text)
    }

    @objc private func displayTapAction() {
        onRequestFocus?()
    }
}

extension SquareCommentInputBar: UITextViewDelegate {

    /// ⚠️ 关键时机：必须在输入框「成为第一响应者之前」把输入条设成 accessoryView，
    /// 系统弹键盘时才会把输入条一起带上。用户直接点输入框时不会走 `becomeInputFirstResponder`，
    /// 所以这个回调才是主路径（之前只有 `becomeInputFirstResponder` 里挂了，直接点就没挂上）。
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if isDisplayOnly {
            // 展示条不参与编辑：点击把焦点转给键盘输入条
            onRequestFocus?()
            return false
        }
        attachToKeyboard()
        return true
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        // 兜底：个别路径（系统自动聚焦等）没走 shouldBeginEditing 时再补一次（内部有幂等判断）
        attachToKeyboard()
        // ⚠️ 这里**不能**点亮输入条：此刻系统刚把它收进键盘容器、还没摆到键盘顶上，
        //    容器那一瞬时在 (0,0)，一亮就会在左上角闪一下（第二次弹键盘时最明显）。
        //    点亮的时机统一交给键盘通知（见 observeKeyboard / textViewDidChange）。
        // 编辑期间把系统键盘图层里那条滚动条（黑细线）抹成透明
        scrollIndicatorHider.start()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // 键盘收起动画期间系统还会把那条滚动条重建出来闪一下，多抹 1.2 秒再停
        scrollIndicatorHider.stop(grace: 1.2)
        // 注意：这里**不能**立刻把输入条从键盘上摘下来（会突然消失一下）。
        // 摘除统一放到键盘完全收起后（didHide / 离屏 willChangeFrame 触发 handleKeyboardHidden）——
        // 那时输入条已随键盘滑出屏幕，摘下来不可见，也不会留下残影。
    }

    func textViewDidChange(_ textView: UITextView) {
        placeHolderLab.isHidden = !textView.text.isEmpty
        if textView.text.count > SquareLimits.maxCommentLength {
            textView.limitText(with: SquareLimits.maxCommentLength)
        }
        // 兜底：能输入就说明键盘已经在屏幕上了，输入条肯定已贴键盘顶 —— 确保它可见
        if isAttachedToKeyboard, alpha < 1 {
            alpha = 1
        }
        updateInputHeight()
        updateSendButton()
        onTextChanged?(textView.text)
    }
}

// MARK: - 系统键盘滚动条细线清理（运行时规避，私有视图，iOS 版本变化后可能失效）
//
// 那条「跟着键盘一起出现、一秒左右才消失」的黑细线，就是系统画出来的滚动指示器
// `_UIScrollViewScrollIndicator`。**只设 alpha 会被系统每帧重写回去**（滚动条自带
// 「显示→淡出」驱动），所以细线总会显示完整的一秒左右 —— 这就是之前怎么抹都没用的原因。
// 现在的做法是**治本**：
// ① 键盘/文本特效 window 里所有 UIScrollView 直接把 `shows*ScrollIndicator` 关掉
//    （公开 API），滚动条根本不会弹出来；
// ② 已经弹出来的 `_UIScrollViewScrollIndicator` 设 `isHidden = true`（比 alpha 硬，
//    不会被每帧重写的 alpha 盖掉），并把它的宿主 scrollView 开关也关掉防重建。
// 编辑期间 0.05s 扫一次全部 window；收起键盘后分几拍（0.3s / 0.7s / 1.2s）再扫。
// ⚠️ 只作用于编辑期间；想要彻底去掉这段行为，删掉 begin/endEditing 里的两行调用即可。
final class SquareSystemScrollIndicatorHider {

    /// 由使用方提供「是否还在编辑」的判定；编辑结束后到 grace 结束前又聚焦了，就不要停
    var isStillEditing: (() -> Bool)?

    private var timer: Timer?

    /// 编辑开始：先抹一次，然后每 0.05s 反复抹（系统的滚动条是「显示 → 淡出」，会被反复重建）
    func start() {
        hideOnce()
        guard timer == nil else { return }
        let timer = Timer.init(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.hideOnce()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 编辑结束：键盘收起动画期间系统还会重建滚动条，分几拍多抹一会儿，最后一拍才停
    func stop(grace: TimeInterval = 1.2) {
        for delay in [0.3, 0.7, grace] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                guard self.isStillEditing?() != true else { return }
                self.hideOnce()
                if delay == grace {
                    self.timer?.invalidate()
                    self.timer = nil
                    // 把底栏 TabBar 阴影线 / 光标附件恢复原状，避免影响返回会话页后的外观
                    self.restoreSystemDecorations()
                }
            }
        }
    }

    /// 立刻停（页面销毁时用）
    func stopNow() {
        timer?.invalidate()
        timer = nil
        restoreSystemDecorations()
    }
    /// 把编辑期间隐藏的系统装饰视图（底栏 TabBar 阴影线 / 光标附件）恢复可见
    private func restoreSystemDecorations() {
        for window in allWindows() {
            SquareSystemScrollIndicatorHider.restoreSystemDecorations(in: window)
        }
    }

    private static func restoreSystemDecorations(in view: UIView) {
        let cls = NSStringFromClass(type(of: view))
        if cls.contains("BarBackgroundShadow") || cls.contains("CursorAccessory") {
            view.isHidden = false
            view.alpha = 1
        }
        for sub in view.subviews {
            restoreSystemDecorations(in: sub)
        }
    }

    /// 进程内所有 window：键盘 window 不一定挂在 scene 里，新老两个接口都取一遍再去重
    private func allWindows() -> [UIWindow] {
        var windows = [UIWindow]()
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windows.append(contentsOf: windowScene.windows)
        }
        for window in UIApplication.shared.windows where !windows.contains(where: { $0 === window }) {
            windows.append(window)
        }
        return windows
    }


    func hideOnce() {
        var found = [(window: String, count: Int)]()
        for window in allWindows() {
            let name = NSStringFromClass(type(of: window))
            // 系统图层（键盘/文本特效 window）的滚动条开关可以直接关掉（治本）；
            // App 自己的 window 只抹「已经出现的滚动条视图」，不动开关（避免影响其它页面的滚动条）
            let disableFlags = name.contains("Keyboard") || name.contains("TextEffects")
            let count = SquareSystemScrollIndicatorHider.cleanSystemDecorations(in: window, disableFlags: disableFlags)
            if count > 0 {
                found.append((name, count))
            }
        }
    }

    /// 递归处理「系统装饰线」，返回处理了几处：
    /// ① 把系统图层里所有 UIScrollView 的 `shows*ScrollIndicator` 关掉 —— 滚动条根本不弹出来（治本）；
    /// ② 已经存在 / 正在闪烁的 `_UIScrollViewScrollIndicator` 直接抹掉：只设 alpha 会被系统
    ///    每帧重写回去（这解释了为什么细线总是显示 ~1s 才消失），所以同时设 hidden、
    ///    并清掉它正在跑的淡入动画；再把宿主 scrollView 的滚动条开关也关掉，防止重建；
    /// ③ `_UIBarBackgroundShadowView` / `_UIBarBackgroundShadowContentImageView`：
    ///    底栏 TabBar 背景的阴影线（键盘弹/收时会短暂露出来）；
    /// ④ `_UICursorAccessoryView` / `_UICursorAccessoryHostView`：
    ///    光标附件（横向箭头条，里面带一根横向滚动条），键盘弹/收时也会闪一下。
    private static func cleanSystemDecorations(in view: UIView, disableFlags: Bool) -> Int {
        var count = 0
        if disableFlags, let scroll = view as? UIScrollView,
           scroll.showsHorizontalScrollIndicator || scroll.showsVerticalScrollIndicator {
            scroll.showsHorizontalScrollIndicator = false
            scroll.showsVerticalScrollIndicator = false
            count += 1
        }
        let cls = NSStringFromClass(type(of: view))
        let isIndicator = cls.contains("ScrollIndicator")
        let isBarShadow = cls.contains("BarBackgroundShadow")
        let isCursorAccessory = cls.contains("CursorAccessory")
        if isIndicator || isBarShadow || isCursorAccessory {
            // 只有「本来还看得见」的才算处理了一处 —— 否则 0.05s 的定时器会一直刷日志
            let wasVisible = !view.isHidden && view.alpha > 0.02
            if isIndicator {
                // 找到宿主 scrollView，把开关关掉，防止它把这根滚动条再闪出来
                var host: UIView? = view.superview
                while let v = host, !(v is UIScrollView) {
                    host = v.superview
                }
                if let scroll = host as? UIScrollView {
                    scroll.showsHorizontalScrollIndicator = false
                    scroll.showsVerticalScrollIndicator = false
                }
            }
            view.layer.removeAllAnimations()
            view.alpha = 0
            view.isHidden = true
            if wasVisible {
                count += 1
            }
        }
        for sub in view.subviews {
            count += cleanSystemDecorations(in: sub, disableFlags: disableFlags)
        }
        return count
    }
}
