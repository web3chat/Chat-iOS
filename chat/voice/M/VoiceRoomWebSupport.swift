//
//  VoiceRoomWebSupport.swift
//  chat
//
//  语音房 H5 在 **WebView 容器**里需要的公共能力：媒体配置 / 钱包地址桥 / 麦克风 / 音频会话 /
//  自签证书放行 / 自动登录。
//
//  宿主 = `DAppBrowserViewController`（`chat/dapp/DAppBrowser.swift`）。
//  App 内**所有**语音房链接都走 DApp 浏览器，所以这些能力直接挂在它上面，
//  不再单独维护第二个浏览器容器（`InAppBrowserVC` 已删除）。
//
//  为什么抽成独立类型而不是直接写进 DAppBrowser：
//   · 音频会话需要「记住进房前的 category」这类**实例状态**；
//   · 这块与 Web3（`window.ethereum` / 签名 / 交易）完全无关，混在一起会让 DAppBrowser 更难读。
//
//  ⚠️ iOS 上跑 WebRTC 必须同时满足（本仓库原先两样都没有）：
//   ① `allowsInlineMediaPlayback = true` + `mediaTypesRequiringUserActionForPlayback = []`
//   ② 宿主实现 `WKUIDelegate` 的 `webView(_:requestMediaCapturePermissionFor:…)` 并返回 `.grant`
//  ⚠️ 自签证书：`NSAllowsArbitraryLoads`（ATS）**不管证书链校验**，必须自己在
//    `WKNavigationDelegate` 的挑战回调里放行（DApp 浏览器的那条回调由
//    `WKWebViewJavascriptBridge` 转发，见其 `.m:129`）。
//

import AVFoundation
import UIKit
import WebKit

final class VoiceRoomWebSupport: NSObject {

    /// JS 桥通道名（页面侧 `window.webkit.messageHandlers.h5Wallet.postMessage(...)`）
    static let walletHandlerName = "h5Wallet"
    /// 页面 console / JS 报错上报（排查 WebRTC 连接问题用，只记 `warn` / `error`）
    static let consoleHandlerName = "voiceConsole"

    /// 宿主 WebView（回填地址用；弱引用避免与 `WKUserContentController` 的强引用形成环）
    private weak var webView: WKWebView?
    /// 宿主控制器（麦克风被拒时弹引导用）
    private weak var host: UIViewController?

    /// 是否已经请求过麦克风（每次进入只请求一次）
    private var didRequestMicrophone = false
    /// 是否已经挂上音频会话观察者（幂等）
    private var didObserveAudioSession = false
    /// 是否已经成功触发过一次页面登录（成功就不再重试）
    private var didTriggerWalletLogin = false
    /// 是否已经主动挂断（离开页面时调 `hangUp()`，幂等）
    private var didHangUp = false
    /// 是否已经提示过「当前网络建不起语音连接」（一次通话只提示一次）
    private var didShowPeerConnectionHint = false

    /// 页面里点了「挂断」时的回调 —— 宿主用它销毁整个通话界面（真的挂断，不留悬浮框）
    var onCallEnded: (() -> Void)?

    /// 页面**顶栏实测高度**（pt）。原生靠它把「缩小 / 返回」按钮放到顶栏下面，不再压字。
    /// 取不到（没上报 / 上报 0）时宿主用默认值兜底。
    var onHeaderHeightMeasured: ((CGFloat) -> Void)?

    /// 扬声器看门狗
    ///
    /// ⚠️ 为什么需要它：WebKit 真正把会话配成 `.playAndRecord` 是在**用户点「加入房间」之后**，
    ///    而 `.playAndRecord` 默认输出是**听筒** —— 走的是**通话音量**档，上限远低于媒体音量。
    ///    症状就是「有声音，但特别小，得把系统音量推很高」。
    /// ⚠️ 为什么不能只靠几次固定延迟：用户可能在页面上待很久才点加入房间，那几次全落空。
    ///    所以用有上限的轮询兜住（2s × 120 次 ≈ 4 分钟）。
    /// ⚠️⚠️ **别拿本进程的 `category` / `currentRoute` 当判据**（2026-10-13 真机日志的教训）：
    ///    iOS 上 WebKit 是在 **WebContent 进程**里配置自己的音频会话 —— 我们这边读到的一直是
    ///    `SoloAmbient` + `outputs=[Speaker]`。所以「category 必须是 .playAndRecord」「输出必须是
    ///    .builtInReceiver」这类判断全是**错的口径**，会把所有调用挡掉（日志里 `overrideOutputAudioPort`
    ///    一次都没执行过）。实际听筒 / 扬声器由 WebContent 那个会话决定。
    private var speakerWatchTimer: Timer?
    private var speakerWatchTicks = 0
    /// 页面是否已经请求过麦克风（`getUserMedia`）——**通话真正开始**的信号
    /// ⚠️ 在它之前顶扬声器没有意义（会话还没进通话态），所以拿它当开关。
    private var didSeeMediaCaptureRequest = false
    /// 是否已经**接管本进程的音频会话**（`setCategory` + `setActive`）。
    /// ⚠️ 只在纯 `overrideOutputAudioPort` 被系统拒绝（OSStatus **-50** / paramErr）时才做一次 ——
    ///    本进程会话是 `SoloAmbient` 时系统不认「输出覆盖」；配成 `.playAndRecord` 才认。
    /// ⚠️ options 带 `.mixWithOthers`：**不掐掉 WebKit（WebContent 进程）那边正在放的声音**。
    ///    如果实测出现「完全没声音 / 对方听不到我」，把下面那个开关改成 false 即可回滚。
    private var didConfigureOwnAudioSession = false
    /// 一键回滚开关（false = 永不接管本进程会话，只做纯 override）
    private static let ownsAudioSessionWhenOverrideFails = true
    /// 请求顶扬声器的次数（只用于日志降噪）
    private var overrideSpeakerAttempts = 0
    /// 上一次打印过的会话状态（只有**变化**时才打，避免 0.5s 一条刷屏）
    private var lastAudioRouteState = ""

    // MARK: - 链接判定

    /// 是否语音房链接。
    ///
    /// 判定依据 = 查询参数里**同时**有非空的 `room` 和合法的 `mode`（`voice` / `video`）；
    /// 房间链接形态：`https://host/?room=abc234&pin=8866&mode=voice#/`。
    /// ⚠️ **不能只看 `room`**：别的业务链接（外部 H5 / DApp）也可能带 `room` 参数，
    ///    只看 `room` 会把普通链接误判成语音房，装进通话容器（平白多一个「缩放」按钮）。
    /// 不用 host 白名单 —— 站点域名会换（内网 IP ↔ 正式域名），参数是更稳的特征。
    static func isVoiceRoomLink(_ url: URL) -> Bool {
        // 参数解析收敛在 `VoiceRoomService`（与 `roomCode(of:)` / `mode(of:)` 同一套口径）
        VoiceRoomService.isRoomLink(url)
    }

    /// 当前钱包 0x 地址；非法 / 未登录时返回空串。
    /// 校验与 `AICustomerSigner.currentAddress()` 一致：42 字符 + `0x` 前缀。
    static func currentWalletAddress() -> String {
        let raw = RedPacketWalletDataSource.shared.getCurrentWalletAddress()?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (raw.count == 42 && raw.lowercased().hasPrefix("0x")) ? raw : ""
    }

    /// 当前用户的**显示名**：昵称优先，没有昵称时回落到**短地址**（企业用户则优先企业姓名）。
    ///
    /// 直接用全 App 统一的 `LoginUser.contactsName`（它内部就是这个回落顺序），
    /// 与邀请文案 `VoiceRoomService.inviteText` 同一套口径 ⇒
    /// 「消息里看到的名字」和「进房后房间里的名字」不会不一致。
    ///
    /// 用途：进房链接上的 `name` 查询参数（H5 的参与者名，见 `VoiceRoomService.link(_:addingName:)`）。
    static func currentDisplayName() -> String {
        LoginUser.shared().contactsName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 配置（必须在 `WKWebView(frame:configuration:)` **之前**调用）

    /// 打开音视频能力 + 注入 `window.H5Wallet`
    func configure(_ configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        FZMLog("语音房：已启用媒体能力（allowsInlineMediaPlayback + 无需手势播放 + H5Wallet 桥）")

        let controller = configuration.userContentController
        // `WKUserContentController` 会**强引用** handler —— 这里注册的是本对象（由宿主 VC 持有），
        // 本对象只弱引用 webView，不会形成环。
        controller.add(self, name: Self.walletHandlerName)
        controller.add(self, name: Self.consoleHandlerName)
        // 页面 console.warn/error + 未捕获异常上报：LiveKit 的 ICE / PC 连接失败只打在 console 里，
        // 没有这层捕获时「could not establish pc connection」在 App 侧完全看不到细节。
        controller.addUserScript(WKUserScript(
            source: Self.consoleCaptureJS(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false))
        // `forMainFrameOnly: false`：H5 若把房间组件放在 iframe 里，只注入主框架会取不到
        controller.addUserScript(WKUserScript(
            source: Self.walletBridgeJS(address: Self.currentWalletAddress()),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false))
        // 页面自带的「挂断」按钮监听（只注入主框架：通话 UI 就在主框架里）
        controller.addUserScript(WKUserScript(
            source: Self.callEndedWatcherJS(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))
        // 页面顶栏高度上报（同样是主框架）
        controller.addUserScript(WKUserScript(
            source: Self.headerHeightWatcherJS(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true))
    }

    /// WebView 建好后绑定引用（只存弱引用）
    func attach(to webView: WKWebView, host: UIViewController) {
        self.webView = webView
        self.host = host
    }

    // MARK: - 生命周期

    /// 进房：请求麦克风权限 + 挂上音频会话观察者。
    ///
    /// ⚠️⚠️ **刻意不主动 `setCategory` / `setActive`**（早先那样写过，正是「进房完全没声音」的元凶）：
    ///    WKWebView 里的 WebRTC 由 **WebKit 自己配置 `AVAudioSession`**（会切成 `.playAndRecord`）。
    ///    App 抢先 `setActive(true)` 会把会话占成自己的配置，WebKit 的音频单元随后起不来
    ///    ⇒ 页面一切正常、参与者也在，但**一点声音都没有**。
    ///    所以这里只做两件事：① 要麦克风权限；② 等 WebKit 配好会话后，**只改输出路由**。
    /// ⚠️ `.playAndRecord` 的默认输出是**听筒**，不 `overrideOutputAudioPort(.speaker)` 会「像打电话 / 声音极小」。
    func prepareMedia() {
        requestMicrophoneIfNeeded()
        observeAudioSession()
        // WebKit 真正 activate 会话晚于页面出现（在点「加入房间」之后）⇒ 用看门狗兜住
        startSpeakerWatch()
        moveOutputToSpeakerIfNeeded()
    }

    private func requestMicrophoneIfNeeded() {
        guard !didRequestMicrophone else { return }
        didRequestMicrophone = true
        WebMediaPermission.requestMicrophone(granted: {
            FZMLog("语音房：麦克风权限已授权")
        }, denied: { [weak self] in
            FZMLog("语音房：麦克风权限被拒绝")
            WebMediaPermission.showDeniedGuide(from: self?.host)
        })
    }

    private func observeAudioSession() {
        guard !didObserveAudioSession else { return }
        didObserveAudioSession = true
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification, object: session)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }

    /// 扬声器看门狗：**语音 / 视频两种模式都是「进来就外放」**（与模式无关，这里只改输出路由）。
    ///
    /// 节奏：**前 20 秒 0.5 秒一次**（WebKit 配会话 + 用户点「加入房间」基本都在这段时间里，
    /// 越早顶到越像「默认外放」），之后 2 秒一次，最多撑到 ~4 分钟。
    /// **一旦确认到扬声器（连续 3 次，且此前真的见过听筒）就自停** —— 这样之后用户想手动切回听筒 / 蓝牙就不会被我们抢回去。
    /// `handleAudioRouteChange` 里还会额外**立即**顶一次（不等下一个 tick）。
    /// 重复调用只会重置计数，不会叠加定时器。
    private func startSpeakerWatch() {
        speakerWatchTicks = 0
        guard speakerWatchTimer == nil else { return }
        scheduleSpeakerWatchTick()
    }

    /// 用**一次性定时器 + 重新排期**而不是固定间隔的重复定时器，才能「先快后慢」。
    private func scheduleSpeakerWatchTick() {
        speakerWatchTimer?.invalidate()
        let interval: TimeInterval = speakerWatchTicks < 40 ? 0.5 : 2.0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.speakerWatchTicks += 1
            self.moveOutputToSpeakerIfNeeded()
            // ⚠️ 上面这一步如果确认到扬声器，会**自己把看门狗停掉** —— 此时绝不能再排期，
            //    否则表又活了：既会一直白轮询，还会把用户手动切回听筒的选择每 2 秒抢回去。
            guard self.speakerWatchTimer != nil else { return }
            // ~20s 快速段 + 之后 2s 一段 ≈ 20 分钟；任何路由变化都会重开窗口，出房时直接停表
            if self.speakerWatchTicks >= 600 {
                self.stopSpeakerWatch()
            } else {
                self.scheduleSpeakerWatchTick()
            }
        }
        timer.tolerance = interval * 0.25
        speakerWatchTimer = timer
    }

    private func stopSpeakerWatch() {
        speakerWatchTimer?.invalidate()
        speakerWatchTimer = nil
    }

    /// 把输出顶到扬声器（通话开始后调用，幂等）。
    ///
    /// ⚠️⚠️ **不要用本进程的 `session.category` / `currentRoute` 做前置判断**（2026-10-13 真机日志教训）：
    ///    WebKit 是在 **WebContent 进程**里配自己的音频会话，我们这边永远是 `SoloAmbient` +
    ///    `outputs=[Speaker]` ⇒「必须是 .playAndRecord」「必须是 .builtInReceiver」这两条 guard
    ///    会把调用**全部挡掉**（日志里根本没有 override 的结果行）。听筒/扬声器实际由 WebContent 决定。
    /// ⚠️ 为什么反复顶是安全的：`overrideOutputAudioPort(.speaker)` 只影响「内置听筒 ↔ 扬声器」这一个选择，
    ///    当前输出是耳机 / 蓝牙时系统**不会采信** ⇒ 不会把戴耳机的用户强制外放（API 语义如此）。
    /// ⚠️ 唯一可靠的「真的切过去了」信号是 `routeChangeNotification` 的 `reason == .override`
    ///    （见 `handleAudioRouteChange`）—— 本进程的 `currentRoute` 读数不可信。
    private func moveOutputToSpeakerIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        let state = "category=\(session.category.rawValue) mode=\(session.mode.rawValue) outputs=["
            + session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",") + "]"
        // 只在**变化**时打：早先每 0.5s 一条，真机日志被刷屏（本次排查的教训）
        if state != lastAudioRouteState {
            lastAudioRouteState = state
            FZMLog("语音房：音频会话 \(state)")
        }

        // 页面还没要麦克风 ⇒ 通话还没开始，顶也没用，先不吵系统
        guard didSeeMediaCaptureRequest else { return }

        overrideSpeakerAttempts += 1
        do {
            try session.overrideOutputAudioPort(.speaker)
            if overrideSpeakerAttempts <= 3 || overrideSpeakerAttempts % 60 == 0 {
                FZMLog("语音房：已请求输出切到扬声器（第 \(overrideSpeakerAttempts) 次）")
            }
        } catch {
            if overrideSpeakerAttempts <= 3 || overrideSpeakerAttempts % 60 == 0 {
                FZMLog("语音房：请求切扬声器失败 \(error.localizedDescription)")
            }
            // OSStatus -50（paramErr）：本进程会话不是 `.playAndRecord`，系统**直接拒绝**输出覆盖
            // （2026-10-13 真机日志：category=SoloAmbient 时就是这么拒的，且拒绝发生在
            //   `页面请求媒体权限` 之后 ⇒ 说明 WebKit 那边的会话确实起来了，但跟我们不是一个会话）。
            // ⇒ 唯一剩下的路：把**本进程**会话也配成「通话 + 默认外放」，再顶一次。
            configureOwnAudioSessionIfNeeded()
        }
    }

    /// 把**本进程**音频会话配成「通话 + 默认外放」，并顶到扬声器（只做一次，幂等）。
    ///
    /// ⚠️ 为什么要这么做：听筒 / 扬声器是由 **WebContent 进程**那个音频会话决定的，而我们能施加影响的
    ///    手段只有「让自己的会话也提要求」；纯 `overrideOutputAudioPort` 在 `SoloAmbient` 下报 -50。
    /// ⚠️ 为什么必须带 `.mixWithOthers`：不带的话，激活我们的会话会**掐掉**别人的声音 ——
    ///    2026-09-30 那次「进房完全没声音」就是这么来的。带上它就只是「并行提一个路由要求」。
    /// ⚠️ 一键回滚：把 `Self.ownsAudioSessionWhenOverrideFails` 改成 `false`。
    private func configureOwnAudioSessionIfNeeded() {
        guard Self.ownsAudioSessionWhenOverrideFails, !didConfigureOwnAudioSession else { return }
        didConfigureOwnAudioSession = true
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .videoChat,
                                    options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
            FZMLog("语音房：已接管本进程会话（playAndRecord + defaultToSpeaker + mixWithOthers）并把输出顶到扬声器")
        } catch {
            FZMLog("语音房：接管本进程会话失败 \(error.localizedDescription)")
        }
    }


    // MARK: - 挂断 / 出房

    /// `about:blank`：用它把当前文档顶掉，从而**主动挂断**
    private static let blankURL = URL(string: "about:blank")!

    /// 离开语音 / 视频房：**主动让页面挂断**，不等 WebView 被销毁。
    ///
    /// ⚠️ 只 `setActive(false)` 不够 —— 那只释放音频会话，页面里的 LiveKit 连接还活着：
    ///    对端会继续看到我们「在房间里」，麦克风 / 摄像头轨道也还开着。
    /// 做法：停掉加载 + 把文档导航到 `about:blank` ⇒ **当前文档立即被销毁** ⇒
    ///  · `getUserMedia` 的轨道自动 stop（麦克风 / 摄像头指示器马上灭）；
    ///  · LiveKit 的 WebSocket 断开 ⇒ 服务端**立刻**把这个参与者移出房间（不是等超时）。
    /// 语音 / 视频两种模式共用这一条路径。幂等，重复调用只生效一次。
    func hangUp() {
        guard !didHangUp else { return }
        didHangUp = true
        FZMLog("语音房：离开页面，主动挂断")
        webView?.stopLoading()
        webView?.load(URLRequest(url: Self.blankURL))
        deactivateAudioSession()
    }

    /// 出房：清掉我们的扬声器 override，并把会话还给系统。
    ///
    /// ⚠️ 这里**不改 category**（本来就是 WebKit 设的，不该我们改）；
    ///    `setActive(false, options: .notifyOthersOnDeactivation)` 不能省 ——
    ///    不释放的话别的 App（音乐 / 其他通话）会一直被压着。
    func deactivateAudioSession() {
        stopSpeakerWatch()
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        didObserveAudioSession = false

        // 下一通重新开始判定（清掉上一轮的状态）
        didSeeMediaCaptureRequest = false
        overrideSpeakerAttempts = 0
        lastAudioRouteState = ""

        // 上一通如果接管过会话，这里还原成 App 原本的 SoloAmbient（不留痕迹）
        if didConfigureOwnAudioSession {
            didConfigureOwnAudioSession = false
            try? AVAudioSession.sharedInstance().setCategory(.soloAmbient, options: [])
        }

        let session = AVAudioSession.sharedInstance()
        try? session.overrideOutputAudioPort(.none)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 页面加载完成：替用户点一次页面自己的「登录获取钱包地址」
    func didFinish(in webView: WKWebView) {
        // 已经主动挂断了（文档被顶成 about:blank），不用再去点登录按钮
        guard !didHangUp else { return }
        autoFillWalletAddress(in: webView)
    }

    // MARK: - 自签证书 / 媒体授权（供宿主转发）

    /// 自签证书放行：**只对配置的语音房 host**，其它 host 一律走系统默认校验。
    ///
    /// ⚠️ 绝不能对所有 host 无条件信任 —— 那等于关掉全 App 的证书校验。
    /// 正式证书上线后把 `VoiceRoomService.trustsSelfSignedCertificate` 改回 `false`。
    func handleChallenge(_ challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard VoiceRoomService.trustsSelfSignedCertificate,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trustHost = VoiceRoomService.siteURL?.host,
              trustHost.caseInsensitiveCompare(challenge.protectionSpace.host) == .orderedSame,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        FZMLog("语音房：放行自签证书 host=\(challenge.protectionSpace.host)（仅内网联调期）")
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    /// 页面调 `getUserMedia` 时系统会先问宿主 —— 不授权则 iOS 15+ 直接拒绝
    func handleMediaCapturePermission(type: WKMediaCaptureType,
                                      decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        FZMLog("语音房：页面请求媒体权限 type=\(type.rawValue)")
        // 页面要麦克风 ⇒ 通话真的开始了：从这里起才去顶扬声器，并重开一轮看门狗
        didSeeMediaCaptureRequest = true
        startSpeakerWatch()
        moveOutputToSpeakerIfNeeded()
        decisionHandler(.grant)
    }

    // MARK: - 自动登录

    /// H5 的「🔑 登录获取钱包地址」按钮**只响应点击 / 点「加入房间」**，挂载时不会自己取地址。
    ///
    /// ⚠️ 2026-10-13 复查 H5 bundle（`assets/index-*.js` 的 `JoinView`）发现：
    ///    「加入房间」内部就有 `if (!addr && (await y(), !addr)) return` —— **页面自己会调
    ///    `window.H5Wallet.getAddress()`**；而我们又是带 `room/pin/name` 进来自动加入的
    ///    ⇒ 页面通常**先一步自己拿到地址**，此时「登录获取钱包地址」按钮根本不存在。
    ///    所以老日志里那 4 条 `not-found` 是**误报**（不是失败）。
    /// 现在：找不到按钮时先看页面是不是已经有地址 / 已经进房间 ⇒ 直接判「无需自动登录」，不再重试。
    private func autoFillWalletAddress(in webView: WKWebView, attempt: Int = 1) {
        guard !didTriggerWalletLogin else { return }
        let script = """
        (function () {
          try {
            var buttons = document.querySelectorAll('button');
            for (var i = 0; i < buttons.length; i++) {
              var b = buttons[i];
              if ((b.textContent || '').indexOf('登录获取钱包地址') < 0) { continue; }
              if (b.disabled) { return 'disabled'; }
              b.click();
              return 'clicked';
            }
            // 没找到按钮：先确认页面是不是**已经自己拿到地址**（或已经进房间了）——
            // 页面加入房间时会自己调 H5Wallet.getAddress()，这时没有按钮是正常的。
            var text = (document.body && document.body.innerText) || '';
            if (/0x[0-9a-fA-F]{8,}/.test(text)) { return 'already'; }
            if ((location.hash || '').indexOf('/room') >= 0) { return 'in-room'; }
            return 'not-found';
          } catch (e) { return 'error:' + e; }
        })();
        """
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
            guard let self = self, let webView = webView else { return }
            let outcome = (result as? String) ?? "nil"
            FZMLog("语音房：自动登录第 \(attempt) 次 → \(outcome)")
            if outcome == "clicked" {
                self.didTriggerWalletLogin = true
                return
            }
            // 页面自己已经拿到地址（或已进房间）⇒ 不需要我们代点，也不再重试
            if outcome == "already" || outcome == "in-room" {
                self.didTriggerWalletLogin = true
                FZMLog("语音房：页面已自行拿到钱包地址（\(outcome)），不需要代点登录")
                return
            }
            // 页面（Vue）是异步挂载的，按钮可能还没渲染出来 —— 退几次再试
            guard outcome == "not-found", attempt < 4 else { return }
            let delays: [Double] = [0.4, 1.0, 2.0, 3.0]
            let delay = delays[min(attempt - 1, delays.count - 1)]
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.autoFillWalletAddress(in: webView, attempt: attempt + 1)
            }
        }
    }

    // MARK: - 音频中断 / 路由

    /// 来电 / 闹钟等中断：结束后重新检查输出路由（**不主动 setActive**，理由见 `prepareMedia` 的注释）
    @objc private func handleAudioInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        FZMLog("语音房：音频中断 \(type == .began ? "开始" : "结束")")
        guard type == .ended else { return }
        let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
            .map { AVAudioSession.InterruptionOptions(rawValue: $0) } ?? []
        guard options.contains(.shouldResume) else { return }
        moveOutputToSpeakerIfNeeded()
    }

    /// 媒体服务被重置（系统重启音频栈）：会话状态全丢，重新检查一次
    @objc private func handleMediaServicesReset(_ note: Notification) {
        FZMLog("语音房：媒体服务被重置")
        moveOutputToSpeakerIfNeeded()
    }

    /// 路由变化：**任何**变化都重新检查一次。
    ///
    /// 两类必须覆盖的：WebKit 配会话时会触发 `.categoryChange`、拔耳机是 `.oldDeviceUnavailable`
    /// —— 这两种之后输出都会落回**听筒**，得顶回扬声器。
    /// 是否真的切换由 `moveOutputToSpeakerIfNeeded` 的 guard 决定（耳机 / 蓝牙在场时不会抢）。
    @objc private func handleAudioRouteChange(_ note: Notification) {
        let rawReason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
        FZMLog("语音房：音频路由变化 reason=\(rawReason)")
        // reason == .override(4)：系统**采纳了**我们的扬声器请求 —— 这是唯一可靠的「顶成功了」信号
        // （本进程的 currentRoute 读数不可信，见 `moveOutputToSpeakerIfNeeded` 的注释）⇒ 目标达成，停表。
        if rawReason == AVAudioSession.RouteChangeReason.override.rawValue {
            FZMLog("语音房：系统已按请求切到扬声器")
            stopSpeakerWatch()
            return
        }
        // 会话刚发生变化（WebKit 配会话会触发 .categoryChange、拔耳机是 .oldDeviceUnavailable）
        // ⇒ 重开一轮看门狗窗口
        startSpeakerWatch()
        moveOutputToSpeakerIfNeeded()
    }

    // MARK: - 地址桥 JS

    /// 页面脚本之前注入的钱包地址桥。
    ///
    /// 约定来自 README「App 内嵌 WebView 接入规范」：
    /// `window.H5Wallet = { getAddress: () => Promise.resolve('0x用户钱包地址') }`
    /// —— 注意是**立即 resolve 的静态值**。
    ///
    /// ⚠️ 早期实现是「每次 `getAddress()` 都往原生 postMessage，用一个全局 resolver 回收结果」，
    /// 而 H5 会在**挂载时**和**点「加入房间」时**各调一次 → 后一次把前一次的 resolver 覆盖掉，
    /// 第一个 Promise **永远不会 resolve**（页面表现就是「地址一直空着、必须再点一次登录按钮」）。
    /// 现在：地址在**注入时**就带上（同步 resolve，天然无竞态）；
    /// 只有地址为空时才回落到 postMessage，并用**队列**收结果（重复调用不丢）。
    ///
    /// · `forMainFrameOnly: false` 见 `configure(_:)` 的注释；
    /// · 脚本自带幂等保护，重复注入无副作用；
    /// · **不额外注入 `window.ethereum`**：DApp 浏览器本来就注入了它（EIP-1193），
    ///   页面的次要分支会自动落到它上面，地址同源。
    private static func walletBridgeJS(address: String) -> String {
        let literal = jsStringLiteral(address)
        return """
        (function () {
          if (window.H5Wallet) { return; }
          var staticAddress = \(literal);
          window.H5Wallet = {
            getAddress: function () {
              if (staticAddress) { return Promise.resolve(staticAddress); }
              return new Promise(function (resolve) {
                window.__h5WalletResolvers = window.__h5WalletResolvers || [];
                window.__h5WalletResolvers.push(resolve);
                try {
                  window.webkit.messageHandlers.\(VoiceRoomWebSupport.walletHandlerName).postMessage({ action: 'getAddress' });
                } catch (e) {
                  window.__h5WalletResolvers = [];
                  resolve('');
                }
              });
            }
          };
        })();
        """
    }

    /// 上报页面**顶栏实测高度**给原生。
    ///
    /// 为什么要量：H5 顶栏左边是房间号、右边是昵称，原生那个「缩小 / 返回」按钮
    /// 放哪个上角都会压字（2026-09-30 用户反馈）。写死一个数字又经不起 H5 改版，所以实测。
    /// 量法：找**从顶部开始、横跨几乎整宽**、且高度不至于是一整页（<200）的元素，
    /// 取它们底边最大的那个。页面有安全区 padding 时 `getBoundingClientRect().bottom`
    /// 已经是含安全区的视口坐标，和原生视图坐标一致（CSS px = pt）。
    private static func headerHeightWatcherJS() -> String {
        """
        (function () {
          if (window.__h5HeaderWatcher) { return; }
          window.__h5HeaderWatcher = true;
          function measure() {
            var vw = window.innerWidth || 0;
            if (!vw) { return 0; }
            var best = 0;
            var nodes = document.querySelectorAll('*');
            for (var i = 0; i < nodes.length; i++) {
              var el = nodes[i];
              var r = el.getBoundingClientRect();
              if (r.height <= 20 || r.height > 200) { continue; }
              // 实测顶栏 top 约在状态栏下方十几 pt（页面自己留了安全区），所以上限放到 90
              if (r.top > 90 || r.width < vw * 0.9) { continue; }
              // ⚠️ 必须**有文字**：否则会量到「安全区占位 / 空白容器」（bottom 只有状态栏那么高），
              //    按钮会被顶进顶栏、压住房间号（2026-09-30 录屏里就是这个现象）
              if (!(el.textContent || '').trim()) { continue; }
              if (r.bottom > best) { best = r.bottom; }
            }
            return Math.round(best);
          }
          function report() {
            try {
              window.webkit.messageHandlers.\(Self.walletHandlerName).postMessage({ action: 'headerHeight', value: measure() });
            } catch (e) {}
          }
          [300, 1200, 3000, 6000].forEach(function (d) { setTimeout(report, d); });
          window.addEventListener('resize', report);
        })();
        """
    }

    /// 把 Swift 字符串安全地转成 JS 字符串字面量（保留两侧引号）
    private static func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let arrayLiteral = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(arrayLiteral.dropFirst().dropLast())
    }

    /// 监听**页面自带的「挂断」按钮**。
    ///
    /// ⚠️ 为什么要在页面上「偷听」而不是改 H5：H5 是另一侧维护的，**目前没有给原生任何桥**
    ///    （实测它的 bundle 里完全没用到 `window.webkit.*`），而且点「挂断」**不改 URL、不跳转**
    ///    （就地把 LiveKit 断开回到加入页）⇒ 原生没有任何别的信号可以依赖。
    /// 命中条件：`class` 含 `ctrl-btn` 且文案含「挂断」（通话页那个红色挂断按钮）。
    ///    用**事件委托 + 捕获阶段**，按钮什么时候渲染出来都能命中。
    /// 以后 H5 如果加正式桥（`{action:'hangup'}`），这个脚本可以直接删 ——
    ///    消息处理那边已经支持了同样的 action。
    private static func callEndedWatcherJS() -> String {
        """
        (function () {
          if (window.__h5CallEndWatcher) { return; }
          window.__h5CallEndWatcher = true;
          var reported = false;
          function report() {
            if (reported) { return; }
            reported = true;
            try {
              window.webkit.messageHandlers.\(Self.walletHandlerName).postMessage({ action: 'hangup' });
            } catch (e) {}
          }
          document.addEventListener('click', function (ev) {
            var node = ev.target;
            while (node && node !== document) {
              var cls = (node.className && node.className.toString()) || '';
              var text = (node.textContent || '').trim();
              if (cls.indexOf('ctrl-btn') >= 0 && text.indexOf('挂断') >= 0) { report(); return; }
              node = node.parentNode;
            }
          }, true);
        })();
        """
    }

    private func notifyPeerConnectionFailureIfNeeded() {
        guard !didShowPeerConnectionHint else { return }
        didShowPeerConnectionHint = true
        DispatchQueue.main.async {
            APP.shared().showToast(L("当前网络无法建立语音连接，请切换 Wi-Fi 后重试"))
        }
    }

    /// 捕获页面 `console.warn` / `console.error` / 未捕获异常，回传给原生打日志。
    ///
    /// 为什么需要：LiveKit 的 `could not establish pc connection` 只打在 console 里，
    /// 没有这一层时 App 侧完全看不到 ICE 候选、连接状态、TURN 失败等细节。
    static func consoleCaptureJS() -> String {
        """
        (function () {
          if (window.__voiceConsoleHooked) { return; }
          window.__voiceConsoleHooked = true;

          function send(level, args) {
            try {
              var parts = [];
              for (var i = 0; i < args.length; i++) {
                var a = args[i];
                if (a instanceof Error) { parts.push(a.message); }
                else if (typeof a === 'object') {
                  try { parts.push(JSON.stringify(a)); } catch (e) { parts.push(String(a)); }
                } else { parts.push(String(a)); }
              }
              var text = parts.join(' ');
              if (text.length > 600) { text = text.slice(0, 600); }
              window.webkit.messageHandlers.\(consoleHandlerName).postMessage({ level: level, text: text });
            } catch (e) {}
          }

          ['log', 'info', 'warn', 'error'].forEach(function (level) {
            var original = console[level];
            console[level] = function () {
              try {
                var joined = Array.prototype.join.call(arguments, ' ');
                var lower = (joined || '').toLowerCase();
                // log/info 太吵：只转发与「连接链路」相关的行（信令 URL、ICE 候选、TURN 等），
                // warn/error 一律转发。5G 与 Wi-Fi 的差异全靠这些行定位。
                var important = (level === 'warn' || level === 'error') ||
                  lower.indexOf('websocket') >= 0 ||
                  lower.indexOf('wss:') >= 0 ||
                  lower.indexOf('ws:') >= 0 ||
                  lower.indexOf('livekit') >= 0 ||
                  lower.indexOf('icecandidate') >= 0 ||
                  lower.indexOf('candidate') >= 0 ||
                  lower.indexOf('pc connection') >= 0 ||
                  lower.indexOf('turn:') >= 0 ||
                  lower.indexOf('stun:') >= 0 ||
                  lower.indexOf('signal') >= 0;
                if (important) { send(level, arguments); }
              } catch (e) {}
              try { original.apply(console, arguments); } catch (e) {}
            };
          });

          window.addEventListener('error', function (e) {
            send('error', [e && e.message ? e.message : 'script error']);
          }, true);

          window.addEventListener('unhandledrejection', function (e) {
            var reason = e && e.reason;
            send('error', ['unhandledrejection: ' + (reason && reason.message ? reason.message : reason)]);
          }, true);
        })();
        """
    }
}

// MARK: - 桥：页面消息

extension VoiceRoomWebSupport: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // 页面 console / JS 异常（诊断 WebRTC 用）
        if message.name == Self.consoleHandlerName {
            guard let body = message.body as? [String: Any] else { return }
            let level = (body["level"] as? String) ?? "log"
            let text = (body["text"] as? String) ?? ""
            guard !text.isEmpty else { return }
            FZMLog("语音房 console[\(level)] \(text)")
            // LiveKit 的「could not establish pc connection」= WebRTC 媒体通道（UDP/ICE）建不起来，
            // 多半是当前网络限制了 UDP（比如移动数据网）⇒ 给一次中文提示，别让用户卡在一段英文红条上。
            if text.lowercased().contains("could not establish") {
                notifyPeerConnectionFailureIfNeeded()
            }
            return
        }

        guard message.name == Self.walletHandlerName,
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "hangup":
            // 页面里点了「挂断」⇒ 交给宿主销毁通话界面（真的挂断，不留悬浮框）
            FZMLog("语音房：页面报告「挂断」")
            onCallEnded?()
        case "headerHeight":
            // 页面顶栏实测高度（数值合法才用；0 表示量不到，宿主持默认值）
            if let value = body["value"] as? Double {
                FZMLog("语音房：页面报告顶栏高度 \(value)")
                if value > 0 { onHeaderHeightMeasured?(CGFloat(value)) }
            }
        case "getAddress":
            // 纯本地读取，不发 HTTP、不弹密码
            let address = Self.currentWalletAddress()
            FZMLog("语音房桥：getAddress 回填 \(address.isEmpty ? "(空)" : "\(address.prefix(6))...\(address.suffix(4))")")
            // 用**队列**一次性回填：同一时刻多个 getAddress 都不会丢（早期单 resolver 版本会丢）
            webView?.evaluateJavaScript("""
            (function () {
              var queue = window.__h5WalletResolvers || [];
              window.__h5WalletResolvers = [];
              for (var i = 0; i < queue.length; i++) {
                try { queue[i](\(Self.jsStringLiteral(address))); } catch (e) {}
              }
            })();
            """, completionHandler: nil)
        default:
            break
        }
    }
}
