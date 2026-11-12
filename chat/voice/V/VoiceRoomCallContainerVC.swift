//
//  VoiceRoomCallContainerVC.swift
//  chat
//
//  语音 / 视频通话的承载界面：**全屏 ↔ 悬浮框**。
//  GitHub Copilot 生成
//

import SnapKit
import UIKit

// MARK: - 穿透式根视图

/// 通话界面的根视图。
///
/// 悬浮框模式下调 `interactiveFrame`，**只有小框范围内接收触摸**，框外的触摸
/// 由 `hitTest` 返回 nil ⇒ 交给窗口里下面的 App 视图 ⇒ 用户能一边通话一边继续用 App。
/// 这是用「模态」做悬浮窗的关键（否则一个全屏模态会把整个 App 挡住）。
final class VoiceRoomCallRootView: UIView {

    /// nil = 整屏都要接收触摸（全屏模式）
    var interactiveFrame: CGRect?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let frame = interactiveFrame else {
            return super.point(inside: point, with: event)
        }
        return frame.contains(point)
    }
}

// MARK: - 通话容器

/// 通话容器：一个**挂在窗口上的全屏透明界面**，里面装 DApp 浏览器（通话页面本身就是它）。
///
/// 产品要求（2026-09-30）与实现对应：
/// | 要求 | 实现 |
/// |---|---|
/// | 不显示导航栏、没有返回按钮、不能侧滑返回 | 通话界面**不进导航栈**，直接挂在 key window 上 ⇒ 导航栏 / 返回按钮 / 侧滑手势天然都不存在 |
/// | 顶部一个「缩放」按钮 | 自绘的 `zoomButton`；**纵向位置按页面自报的顶栏高度动态算**（否则会压住房间号 / 昵称） |
/// | 点缩放 → 页面缩小成悬浮框，浮在 App 上，**App 还能继续用** | `setBubble(true)`：`callArea` 缩成方块 + 根视图 `point(inside:)` 在方块外返回 false ⇒ 触摸真的穿给 App（⚠️ 不能用模态，模态外面那层 containerView 会把触摸吃掉）|
/// | 悬浮框可拖动 / 点一下回全屏 | 方块 `bubbleView` 上的 pan / tap |
/// | 悬浮框样式 | 蓝色**圆形**（`Color_Theme`，圆角 = 边长一半）+「语音中 / 视频中」，照 `AICustomerFloatView` 的风格；文字自己换行（多语言）|
/// | 同一时刻只允许一个通话 | `present` 里判：同房间 ⇒ 恢复全屏；不同房间 ⇒ 提示「先挂断当前的语音或视频聊天再进行操作」|
/// | 后台也能聊 | `Info.plist` 的 `UIBackgroundModes` 加 `audio`；全程不主动改音频会话（见 `VoiceRoomWebSupport`）|
/// | 只有点「挂断」才是真的挂断 | 挂断信号来自页面内的挂断按钮（`VoiceRoomWebSupport` 监听到点击后回调），收到就 `finish()` ⇒ 界面和页面一起销毁，**不留悬浮框** |
/// | 页面加载失败 | 顶部按钮变「返回」，点它退出（见 `applyTopButton`）|
///
/// ⚠️ 悬浮框只在 **App 内**浮着。想浮在别的 App 之上，iOS 只允许「画中画 + AVPlayerLayer」，
///    WKWebView 做不到 —— 这是系统限制，不是实现取舍。
final class VoiceRoomCallContainerVC: UIViewController {

    // MARK: 常量

    /// 悬浮框：蓝色**圆形** + 「语音中 / 视频中」（照 `AICustomerFloatView` 的风格）
    /// ⚠️ 做成**圆形**（用户 2026-09-30 反馈：长条不好看，正方形也改成圆形）；文字自己换行，
    ///    多语言变长也不会把框撑成异形。
    /// ⚠️ 圆形靠**圆角 = 边长一半**（`bubbleSide / 2`）实现；想换回圆角方框只改这一行。
    private static let bubbleSide: CGFloat = 50
    private static let bubbleMargin: CGFloat = 12
    private static let bubbleCornerRadius: CGFloat = bubbleSide / 2
    /// 文字距方块边缘的留白
    private static let bubbleTextInset: CGFloat = 4

    /// 顶部「缩放 / 返回」按钮的尺寸与位置
    ///
    /// ⚠️ 纵向位置靠**页面自报的顶栏高度**（`browser.onVoiceRoomHeaderHeightMeasured`）**动态**算：
    ///    页面顶栏左边是房间号、右边是昵称，按钮落在顶栏范围里就会压字（用户反馈过）。
    ///    页面还没报上来时用 `fallbackHeaderHeight` 兜底。
    /// ⚠️ 横向靠**左**：用户要求「放到房间名下方」⇒ 与房间号同一列、顶栏下方。
    private static let buttonSize: CGFloat = 32
    private static let buttonLeft: CGFloat = 12
    private static let buttonGapBelowHeader: CGFloat = 8
    private static let fallbackHeaderHeight: CGFloat = 44

    /// 当前展示中的通话界面。
    /// ⚠️ **强引用**：界面不再是 present 出来的，没别人 retain 它。
    /// ⚠️ 同一时刻只允许一个（换房间要先挂断，见 `present`）。
    private static var current: VoiceRoomCallContainerVC?

    // MARK: 状态

    private let browser: DAppBrowserViewController
    private let rootView = VoiceRoomCallRootView()
    /// 承载浏览器视图的区域：全屏 = 整个屏幕；悬浮框 = 方块那么小
    private let callArea = UIView()
    /// 悬浮框本体（蓝色方块 + 文案），盖在 `callArea` 上面；还兼任拖动 / 点击的手势载体
    private let bubbleView = UIView()
    private let bubbleLabel = UILabel()
    private let zoomButton = UIButton(type: .custom)

    private var isBubble = false
    private var bubbleFrame: CGRect = .zero
    private var didTearDown = false
    /// 页面是否加载失败（失败时顶部按钮从「缩放」变成「返回」）
    private var isLoadFailed = false
    /// 页面自报的顶栏高度（0 = 还没报到）
    private var headerHeight: CGFloat = 0

    /// 房间号（判「点的是不是当前这一间」用）
    private var roomCode: String? { VoiceRoomService.roomCode(of: browser.initialURL) }

    // MARK: 初始化

    private init(browser: DAppBrowserViewController) {
        self.browser = browser
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: 入口 / 出口

    /// 打开通话界面（全屏）。
    ///
    /// ⚠️ **同一时刻只允许一个通话**：
    ///  · 点的就是**当前这一间** ⇒ 把悬浮框还原成全屏（不新开）；
    ///  · 点的是**另一间** ⇒ 提示「先挂断当前的语音或视频聊天再进行操作」，不开新的。
    @discardableResult
    static func present(browser: DAppBrowserViewController, from host: UIViewController?) -> Bool {
        let hostVC = host ?? UIViewController.current()

        if let current = current {
            let target = VoiceRoomService.roomCode(of: browser.initialURL)
            if let target = target, target == current.roomCode {
                FZMLog("语音房：点的就是当前房间，恢复全屏")
                current.setBubble(false)
                return true
            }
            hostVC?.showToast(L("先挂断当前的语音或视频聊天再进行操作"))
            return false
        }

        guard let window = hostVC?.view.window ?? UIApplication.shared.keyWindow else { return false }
        let container = VoiceRoomCallContainerVC(browser: browser)
        current = container
        container.attach(to: window)
        return true
    }

    /// 当前是否有通话界面在展示
    static var isShowing: Bool { current != nil }

    /// **真的挂断**：界面和页面一起销毁（不会留悬浮框）
    static func finish() {
        current?.tearDown()
    }

    // MARK: 挂到窗口 / 销毁

    /// 把界面挂到窗口上。
    ///
    /// ⚠️ 为什么**不用模态 present**：模态外面还有一层 `UIPresentationController` 的
    ///    `containerView`，它铺满整屏且**参与 hit-test** ⇒ 就算我们的根视图在方块外返回 false，
    ///    触摸也会被那层容器吃掉 ⇒ 用户缩小以后什么都点不了（2026-09-30 用户反馈）。
    ///    直接做成 window 的子视图没有这层，框外触摸才能真正穿给下面的 App。
    private func attach(to window: UIWindow) {
        loadViewIfNeeded()
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        // 没有父 VC，UIKit 不会自动发 appearance 回调 ⇒ 手动驱动一次
        beginAppearanceTransition(true, animated: false)
        endAppearanceTransition()
        // 再显式开一次媒体（幂等）：不依赖 appearance 有没有被驱动
        browser.startVoiceRoomMedia()
    }

    /// 真的收摊：页面断开 + 界面从窗口摘掉
    private func tearDown() {
        guard !didTearDown else { return }
        didTearDown = true

        // 让页面真的断开（麦克风 / 摄像头轨道 stop + LiveKit 断连 + 释放音频会话）
        browser.hangUpVoiceRoomCall()
        browser.willMove(toParent: nil)
        browser.view.removeFromSuperview()
        browser.removeFromParent()

        beginAppearanceTransition(false, animated: false)
        endAppearanceTransition()
        view.removeFromSuperview()

        if VoiceRoomCallContainerVC.current === self { VoiceRoomCallContainerVC.current = nil }
    }

    // MARK: 生命周期

    override func loadView() {
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // ⚠️ 根视图**必须透明**：悬浮框模式下整屏都在它上面，若给黑底就把整个 App 盖黑了。
        //    页面的黑底给 `callArea`（全屏时铺满，缩小时就是那个小框）。
        view.backgroundColor = .clear
        view.isOpaque = false

        callArea.backgroundColor = .black
        callArea.clipsToBounds = true
        view.addSubview(callArea)

        // 通话页面 = DApp 浏览器（音视频 / 钱包桥 / 自签证书能力都在它身上）
        addChild(browser)
        callArea.addSubview(browser.view)
        browser.view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        browser.didMove(toParent: self)

        // 悬浮框：蓝色圆形 + 「语音中 / 视频中」（照 `AICustomerFloatView` 的风格）。
        // ⚠️ 它盖在 `callArea` **上面**：页面本身还在跑（缩到圆圈那么大、被盖住看不见），
        //    这样 WebKit 不会因为「看不见」而节流，通话才不断。
        bubbleView.backgroundColor = Color_Theme
        bubbleView.layer.cornerRadius = Self.bubbleCornerRadius
        bubbleView.clipsToBounds = true
        bubbleView.isHidden = true
        bubbleView.accessibilityLabel = bubbleText()
        view.addSubview(bubbleView)

        bubbleLabel.text = bubbleText()
        bubbleLabel.textColor = .white
        bubbleLabel.font = UIFont.mediumFont(11)
        bubbleLabel.textAlignment = .center
        bubbleLabel.numberOfLines = 0
        bubbleView.addSubview(bubbleLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(bubbleTapped))
        bubbleView.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(bubblePanned(_:)))
        bubbleView.addGestureRecognizer(pan)
        // 拖动一旦真的识别出来，就不要再触发点击（避免「拖完顺手就回了全屏」）
        tap.require(toFail: pan)

        zoomButton.backgroundColor = UIColor(white: 0, alpha: 0.35)
        zoomButton.layer.cornerRadius = Self.buttonSize / 2
        zoomButton.clipsToBounds = true
        zoomButton.addTarget(self, action: #selector(topButtonTapped), for: .touchUpInside)
        view.addSubview(zoomButton)

        // 页面加载失败 ⇒ 按钮变「返回」（页面都没出来，缩小了也没用，得能退出去）
        browser.onVoiceRoomLoadFailureChanged = { [weak self] failed in
            self?.applyTopButton(loadFailed: failed)
        }
        applyTopButton(loadFailed: browser.isVoiceRoomLoadFailed)
        // 页面自报的顶栏高度 ⇒ 动态定位顶部按钮
        browser.onVoiceRoomHeaderHeightMeasured = { [weak self] height in
            self?.applyHeaderHeight(height)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ⚠️ 不依赖子 VC 的 `viewDidAppear` 转发：这里**显式**开媒体能力。
        //    `prepareMedia()` 本身幂等，和浏览器自己那次调用重复也没关系。
        browser.startVoiceRoomMedia()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyModeLayout()
    }

    // MARK: 布局

    private func applyModeLayout() {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        if isBubble {
            bubbleFrame = clamped(bubbleFrame, in: bounds)
            callArea.frame = bubbleFrame
            bubbleView.frame = bubbleFrame
            layoutBubbleLabel()
            // ⚠️⚠️ **必须跟着气泡一起更新**（拖动时每帧都会走到这里）。
            //    只更新 `setBubble` 里那一次的话：气泡被拖走之后就跑出了「可交互区」，
            //    点它 / 再拖它都被 `point(inside:)` 判成框外 ⇒ 触摸穿透给下面的 App ⇒
            //    气泡就「点不动了」（用户 2026-09-30 反馈的 bug）。
            rootView.interactiveFrame = bubbleFrame
        } else {
            callArea.frame = bounds
            bubbleView.frame = .zero
            rootView.interactiveFrame = nil
        }

        // 缩小时通话页也切成同样的圆角 ⇒ 和气泡**完全重合**，不会从圆边露出方角。
        callArea.layer.cornerRadius = isBubble ? Self.bubbleCornerRadius : 0
        zoomButton.frame = CGRect(x: Self.buttonLeft,
                                  y: headerBottom() + Self.buttonGapBelowHeader,
                                  width: Self.buttonSize,
                                  height: Self.buttonSize)
        zoomButton.isHidden = isBubble
    }

    /// 页面顶栏的底边。
    /// ⚠️ **动态**：优先用页面自报的高度（`applyHeaderHeight`），没报到才兜底。
    ///    页面顶栏左边是房间号、右边是昵称，按钮不能落在它里面。
    private func headerBottom() -> CGFloat {
        // `headerHeight` 已是屏幕坐标（见 `applyHeaderHeight`）；没收到上报时用兑底值。
        let fallback = pageCoordinateTopOffset + Self.fallbackHeaderHeight
        let bottom = headerHeight > 0 ? headerHeight : fallback
        return max(bottom, pageCoordinateTopOffset + 8)
    }

    /// 页面自报顶栏高度 ⇒ 重算按钮位置。
    ///
    /// ⚠️ 太矮的值直接丢掉：页面里很容易量到「安全区占位」那种空白容器（bottom 只有状态栏那么高），
    ///    用它会把按钮**顶进顶栏、压住房间号**（2026-09-30 录屏里就是这个现象）。
    ///    丢掉后走 `fallbackHeaderHeight` 兜底，位置反而稳。
    /// 页面坐标系 → 屏幕坐标系的偏移 = 安全区上沿（= 状态栏高度）。
    ///
    /// 依据（2026-10-13 抓 H5 `index.html` 确认）：页面**没有** `viewport-fit=cover`
    /// (`<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">`)
    /// ⇒ WebKit 会把**布局视口收进安全区** ⇒ 页面里 `getBoundingClientRect()` 的 y=0 落在「状态栏下沿」，
    ///    页面里 `env(safe-area-inset-top)` 恒为 0（所以页面自己不处理刘海）。
    /// ⇒ **页面报的“顶栏底边”要加上这个偏移才是屏幕坐标**。
    /// ⚠️ 如果将来 H5 给 viewport 加上 `viewport-fit=cover`，这里就不能再加（否则按钮会偏低一个状态栏）。
    private var pageCoordinateTopOffset: CGFloat {
        let inset = view.safeAreaInsets.top
        return inset > 0 ? inset : k_StatusBarHeight
    }

    private func applyHeaderHeight(_ height: CGFloat) {
        // ⚠️ 页面报的是「页面坐标」的底边（页面坐标系原点在状态栏下沿），先换算成屏幕坐标再夹取。
        let offset = pageCoordinateTopOffset
        let onScreen = offset + height
        let minimum = offset + 8      // 至少要落到安全区下沿（低于这个值多半不是顶栏）
        let maximum = offset + 120    // 再多就不像顶栏了，免得按钮被推到屏幕中间
        guard onScreen >= minimum, onScreen <= maximum, abs(onScreen - headerHeight) > 0.5 else { return }
        headerHeight = onScreen
        FZMLog("语音房：顶栏高度 页面 \(height) → 屏幕 \(onScreen)（安全区 \(offset)）")
        applyModeLayout()
    }

    /// 悬浮框文案：语音中 / 视频中（多语言下可能变长 ⇒ 换行 + 高度自适应）
    private func bubbleText() -> String {
        VoiceRoomService.mode(of: browser.initialURL) == .video ? L("视频中") : L("语音中")
    }

    /// 悬浮框默认位置：右下角上方，避开 TabBar / Home 指示条
    private func defaultBubbleFrame(in bounds: CGRect) -> CGRect {
        let side = Self.bubbleSide
        return CGRect(x: bounds.width - side - Self.bubbleMargin,
                      y: bounds.height - side - (k_SafeBottomInset + Self.bubbleMargin + 110),
                      width: side,
                      height: side)
    }

    /// 文案在方块里居中（`UILabel` 自己会把多行文字垂直居中）
    private func layoutBubbleLabel() {
        let inset = Self.bubbleTextInset
        bubbleLabel.frame = CGRect(x: inset,
                                   y: inset,
                                   width: max(1, bubbleFrame.width - inset * 2),
                                   height: max(1, bubbleFrame.height - inset * 2))
    }

    /// 拖出去要拉回来（只保证不超出屏幕，允许贴边）
    private func clamped(_ frame: CGRect, in bounds: CGRect) -> CGRect {
        var result = frame
        result.origin.x = min(max(result.origin.x, Self.bubbleMargin),
                              bounds.width - frame.width - Self.bubbleMargin)
        result.origin.y = min(max(result.origin.y, k_StatusBarHeight + Self.bubbleMargin),
                              bounds.height - frame.height - Self.bubbleMargin)
        return result
    }

    // MARK: 顶部按钮 / 全屏 ↔ 悬浮框

    /// 顶部按钮：页面正常时是「缩放」，**页面加载失败时是「返回」**（点它退出通话界面）
    @objc private func topButtonTapped() {
        if isLoadFailed {
            FZMLog("语音房：页面加载失败，点返回退出")
            VoiceRoomCallContainerVC.finish()
        } else {
            setBubble(true)
        }
    }

    /// 切换顶部按钮的图标与语义（`nav_back_white` 是项目现成的白色返回箭头）
    private func applyTopButton(loadFailed: Bool) {
        isLoadFailed = loadFailed
        let imageName = loadFailed ? "nav_back_white" : "voiceRoom_minimize"
        zoomButton.setImage(UIImage(named: imageName) ?? UIImage(named: "voiceRoom_minimize"), for: .normal)
        zoomButton.accessibilityLabel = loadFailed ? L("返回") : L("缩小")
    }

    @objc private func bubbleTapped() {
        setBubble(false)
    }

    @objc private func bubblePanned(_ gesture: UIPanGestureRecognizer) {
        guard isBubble else { return }
        let translation = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)
        bubbleFrame.origin.x += translation.x
        bubbleFrame.origin.y += translation.y
        applyModeLayout()
    }

    private func setBubble(_ bubble: Bool) {
        guard isBubble != bubble else { return }
        isBubble = bubble
        if bubble {
            // 首次进悬浮框才算默认位置；之后保留用户拖到的位置
            if bubbleFrame.isEmpty { bubbleFrame = defaultBubbleFrame(in: view.bounds) }
            bubbleLabel.text = bubbleText()
        }

        bubbleView.isHidden = !bubble
        // 悬浮框模式：页面不接受点击（手势都交给方块），否则拖不动、还会误触页面
        browser.view.isUserInteractionEnabled = !bubble
        // 可交互区（`rootView.interactiveFrame`）不在这里设 —— 它必须**始终等于当帧的 bubbleFrame**，
        // 统一由 `applyModeLayout()` 维护（拖动会在那里逐帧更新）
        UIView.animate(withDuration: 0.25) {
            self.applyModeLayout()
        }
    }

    // MARK: 销毁（实现见上面的 `tearDown()`）
}
