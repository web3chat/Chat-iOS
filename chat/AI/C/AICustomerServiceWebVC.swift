//
//  AICustomerServiceWebVC.swift
//  chat
//
//  AI 客服 H5 容器（WKWebView）。由 `AICustomerLauncher.push(...)` **push 进导航栈**打开。
//
//  ★ 顶栏交接（对接文档 §11）：App 内**不显示原生导航栏**，改由我方页面当顶栏
//  （左返回 / 中标题 / 右会话历史），与页面是一对一的：
//    ① 注入 `window.__tanxinHost = { name: 'tanxin-ios', back: ... }`（页面脚本之前）
//    ② 接住页面返回键：`__tanxinHost.back()` / `csAuth{action:'back'}` → 与原生返回同一函数
//    ③ 本页 `xls_isNavigationBarHidden = true` → 全局拦截器把导航栏隐藏（§11 的要求）
//  三个信号必须同时生效：只做①不做③会出现两条顶栏（§11.5-6）。
//
//  ★ 宿主对象已统一为《谈信 App × H5 通用对接说明》的 `window.__tanxinHost`
//  （`TanxinHostBridge`）：返回 / 分享 / 分享到广场 / 保存图片（含分片）全部走同一套实现，
//  老的 `__csHost` 已删除（AI 前端已确认改读 `__tanxinHost`）。
//
//  对接文档 §4：采用 **方式 A「惰性提供者」**（文档明确："App 请优先用方式 A"）。
//  · 页面脚本之前只注入 `window.__csAuthProvider`（读地址 / 按需登录）与 `window.__tanxinHost`（宿主能力）；
//  · 页面自己有本地会话（localStorage）且地址没变时**根本不会调 `getAuth()`**
//    ⇒ 反复进出 0 配额（§4.4），页面刷新会话走 `/api/auth/refresh-livekit` 也不计入限流；
//  · 只有页面确实需要登录时（无本地会话 / 换了账户）才被调一次，这时**现取一份新鲜凭证**。
//
//  ⚠️ 为什么不再用"进入前注入 `__csAuthPayload`"（旧实现，已废弃）：
//  那条路为了躲「每地址 5 次/分钟」限流，在 App 侧缓存了 **24h** 的凭证；
//  而服务端签发的 token 有效期**短于 24h** ⇒ 页面会拿到一份**已经过期的 token** 当作自己的会话，
//  表现就是「AI 那边报 token 失效、用不了」。惰性方式下 App 只在页面开口时给一次**新鲜**凭证，
//  从根上不会再拿过期凭证污染页面的会话。
//  · 一次性迁移：`purgeLegacyPageSessionIfNeeded()`（清掉旧版本留在本站 localStorage 里的过期会话）。
//  ★ **两条登录路线并存**：
//    ① 静默登录（`__csAuthProvider`，文档推荐）；② 页面登录页的「连接钱包」——
//       为此注入了标准 EIP-1193 `window.ethereum`（`AIWalletBridge`，见 setupViews）。
//       早期版本刻意不注入，结果那个按钮点了没反应，拿不到凭证的账号（新账号）永远卡在那里。
//
//  ★ 必须使用**持久化存储**（WKWebViewConfiguration 默认即持久化，绝不要改成 .nonPersistent()）。
//

import UIKit
import WebKit

final class AICustomerServiceWebVC: UIViewController, ViewControllerProtocol {

    /// 页面脚本之前注入的惰性提供者（对接文档 §4.1）。
    private static let providerJS = """
    (function () {
      if (window.__csAuthProvider) { return; }
      window.__csAuthProvider = {
        getAddress: function () {
          return new Promise(function (resolve) {
            window.__csAuthAddress = function (a) { resolve(a || ''); };
            try { window.webkit.messageHandlers.\(AICustomerConfig.scriptHandlerName).postMessage({ action: 'getAddress' }); }
            catch (e) { resolve(''); }
          });
        },
        getAuth: function () {
          return new Promise(function (resolve) {
            window.__csAuthResolve = function (payload) { resolve(payload || null); };
            try { window.webkit.messageHandlers.\(AICustomerConfig.scriptHandlerName).postMessage({ action: 'getAuth' }); }
            catch (e) { resolve(null); }
          });
        }
      };
    })();
    """

    /// 页面脚本之前注入的**宿主标记 + 原生能力**（《谈信 App × H5 通用对接说明》§1 / §3 / §4 / §5）。
    ///
    /// 由 `TanxinHostBridge` 统一提供：`name: 'tanxin-ios'` / `back` / `share` / `shareSquare` /
    /// `saveImage`（+ 分片三件套）/ `actions`。页面**只探测方法在不在**（`typeof`），
    /// 所以必须在页面脚本之前挂上 —— 挂晚了这一次进去分享面板里就少那一项（要重进才出现）。
    private let tanxinBridge = TanxinHostBridge()

    /// `window.ethereum`（EIP-1193）：页面登录页的「连接钱包」入口走的就是这条标准通道。
    ///
    /// 🔴 早期版本**刻意不注入**它（只想走 `__csAuthProvider` 的静默登录），结果那个按钮
    ///    点了没有任何反应 —— 拿不到凭证的账号（新账号最典型）就永远卡在「链接钱包」
    ///    （用户 2026-11-04 要求这条路必须能走）。两条路现在**并存**：
    ///    页面优先用 `__csAuthProvider` 就直接静默登录；回退到自己的登录页时用 `window.ethereum` 也能连上。
    private let walletBridge = AIWalletBridge()

    private let scriptHandler = AICustomerScriptHandler()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var progressObservation: NSKeyValueObservation?
    private var webView: WKWebView?
    /// 正在进行的 `getAuth()` 任务。
    ///
    /// ★ §3.6：`getAuth()` 可能**在任何时刻被再次调用**（聊天中途 401 自愈），所以：
    ///   · **不能丢**（丢掉会让页面的 Promise 永远等不到结果）；
    ///   · 但要**串行** —— 新的调用先等上一次结束，否则会同时打两遍 nonce/login，撞「每地址 5 次/分钟」。
    private var inFlightAuth: Task<Void, Never>?
    /// 本次进入是否已经成功签发过凭证（用来区分「首次进入」与「聊天中途自愈」）
    private var hasIssuedAuth = false
    /// 是否已经做过「进入时预备私钥」的尝试（每次进页只试一次，不重复弹密码框）
    private var didPreparePrivateKey = false
    /// 上次进入 AI 客服时使用的登录地址（用于切账号后清掉页面 localStorage 会话）
    private static let lastAuthAddressKey = "AICustomerServiceLastAuthAddress"
    /// 过渡提示的延迟显示任务
    private var loadingWorkItem: DispatchWorkItem?
    /// 进度条的「假进度」下限
    ///
    /// 只用 `estimatedProgress` 不行：静默登录阶段它恒为 0，慢网下又长期卡在 0.1 ——
    /// 2pt 的进度条在 10% 时只有零点几 pt 宽，等于看不见（用户反馈"只看到正在进入客服、看不到进度条"）。
    /// 所以入场后自己缓慢爬一个下限值，**谁大用谁**（真实进度追上就跟着真实走）。
    private var progressFloor: Float = 0
    private var progressTimer: Timer?
    /// 进度条"代际"：每次开始加载 +1，用来防止「上一轮的延迟隐藏」误关掉新一轮的进度条
    private var progressGeneration = 0

    private lazy var failureView: UIView = {
        let container = UIView()
        container.backgroundColor = .white
        container.isHidden = true

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.regularFont(14)
        label.textColor = Color_8A97A5
        label.text = L("AI 客服页面加载失败，请重试")
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let retryButton = UIButton(type: .custom)
        retryButton.setTitle(L("重试"), for: .normal)
        retryButton.setTitleColor(Color_Theme, for: .normal)
        retryButton.titleLabel?.font = UIFont.regularFont(16)
        retryButton.layer.borderColor = Color_Theme.cgColor
        retryButton.layer.borderWidth = 1
        retryButton.layer.cornerRadius = 18
        retryButton.addTarget(self, action: #selector(retryTap), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(retryButton)

        // ★ 已去掉 App 原生导航栏（对接文档 §11），所以失败页必须自带退出路径，
        //   否则断网时用户会卡在这一页（§11.5-5 的同类场景）
        let closeButton = UIButton(type: .custom)
        closeButton.setTitle(L("返回"), for: .normal)
        closeButton.setTitleColor(Color_8A97A5, for: .normal)
        closeButton.titleLabel?.font = UIFont.regularFont(16)
        closeButton.layer.borderColor = Color_8A97A5.cgColor
        closeButton.layer.borderWidth = 1
        closeButton.layer.cornerRadius = 18
        closeButton.addTarget(self, action: #selector(closeTap), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(closeButton)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -34),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),

            retryButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: 58),
            retryButton.widthAnchor.constraint(equalToConstant: 96),
            retryButton.heightAnchor.constraint(equalToConstant: 36),

            closeButton.centerYAnchor.constraint(equalTo: retryButton.centerYAnchor),
            closeButton.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: -58),
            closeButton.widthAnchor.constraint(equalToConstant: 96),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        return container
    }()

    /// 进入时的过渡提示（静默登录 + 页面加载期间显示），避免"点了一下没反应"
    private lazy var loadingView: UIView = {
        let container = UIView()
        container.backgroundColor = .white
        container.isHidden = true

        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = Color_8A97A5
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(indicator)

        let label = UILabel()
        label.font = UIFont.regularFont(14)
        label.textColor = Color_8A97A5
        label.text = L("正在进入客服...")
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 10),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
        return container
    }()

    deinit {
        progressObservation?.invalidate()
        progressObservation = nil
        progressTimer?.invalidate()
        progressTimer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // ★ 对接文档 §11：App 内**不要原生顶栏**，顶栏交给我方页面（返回 / 标题 / 会话历史）。
        //   全局拦截器 `ViewControllerIntercepter` 会在 viewWillAppear 里根据这个标记隐藏导航栏。
        //   配套：注入 `__tanxinHost`（见 setupViews）+ 接住页面返回键（见 `handleBack()`）。
        xls_isNavigationBarHidden = true

        view.backgroundColor = .white
        setupViews()
        prepareAndLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        preparePrivateKeyIfNeeded()
    }

    // MARK: - 返回（页面顶栏的返回键 → 这里）

    /// 页面顶栏「返回」的落地实现（对接文档 §11.3）。
    ///
    /// 与 App 原生返回**走同一个函数** —— `canGoBack ? goBack() : pop`：
    /// 页面内跳转过（有 Web 历史）就先退历史，否则退出客服页。
    private func handleBack() {
        if let webView = webView, webView.canGoBack {
            webView.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - 视图

    private func setupViews() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = .clear
        progressView.progressTintColor = Color_Theme
        view.addSubview(progressView)

        // WKWebViewConfiguration() 默认使用持久化 data store —— 页面靠它保持本地会话，不要改
        let configuration = WKWebViewConfiguration()
        let userContentController = configuration.userContentController
        userContentController.add(scriptHandler, name: AICustomerConfig.scriptHandlerName)

        // ★ 对接文档 §4.1：本模块的**主路径**（也是文档推荐的唯一方式）——
        //   页面自己有本地会话时只调 `getAddress()`（纯本地读）；需要登录时才调 `getAuth()`。
        //   注意：本初始化器**没有** contentWorld 参数，但 WebKit 头文件（WKUserScript.h:62）明确写明
        //   `Calling this method is the same as calling ... with a contentWorld value of WKContentWorld.pageWorld`
        //   ⇒ 脚本跑在**页面世界**（不是 defaultClient 隔离世界），页面的 React bundle 看得到这些全局量。
        //   注意：forMainFrameOnly: false —— 页面若把客服组件放在 iframe 里，只注入主框架的话
        //   iframe 里 `window.__csAuthProvider` 就是 undefined。脚本自带幂等保护，重复注入无副作用。
        userContentController.addUserScript(WKUserScript(source: Self.providerJS,
                                                        injectionTime: .atDocumentStart,
                                                        forMainFrameOnly: false))

        // ★ 宿主对象（《谈信 App × H5 通用对接说明》）：告诉页面「现在在谈信 App 里」→
        //   页面把顶栏切成 左「返回」/ 中标题 / 右「会话历史」，并藏掉抽屉底部的用户信息与「退出登录」；
        //   同时提供 share / shareSquare / saveImage（含分片）/ back。
        //   推送用 forMainFrameOnly: false —— 页面若把客服组件放在 iframe 里，只注入主框架的话
        //   iframe 里 `window.__tanxinHost` 就是 undefined（脚本自带幂等保护，重复注入无副作用）。
        tanxinBridge.host = self
        tanxinBridge.shareHeader = AICustomerShareStyle.header
        tanxinBridge.onBack = { [weak self] in self?.handleBack() }
        userContentController.add(tanxinBridge, name: TanxinHostConfig.handlerName)
        userContentController.addUserScript(TanxinHostScript.userScript(forMainFrameOnly: false))

        // ★ `window.ethereum`（EIP-1193）：页面登录页的「连接钱包」按钮。
        //   必须在**页面脚本之前**注入（`atDocumentStart`）：wagmi / ethers 在模块初始化时就探测
        //   `window.ethereum`，注入晚了本次进入会一直显示「未检测到钱包」。
        //   `forMainFrameOnly: false` 与上面两个保持一致（页面组件可能在 iframe 里）。
        userContentController.add(walletBridge, name: AIWalletBridge.handlerName)
        userContentController.addUserScript(WKUserScript(source: AIWalletBridge.providerScript,
                                                        injectionTime: .atDocumentStart,
                                                        forMainFrameOnly: false))
        scriptHandler.delegate = self

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(webView)

        failureView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(failureView)

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)

        // ★ 进度条与 WebView 顶部重叠，且要盖在 `failureView` / `loadingView` 之上，
        //   否则「正在进入客服...」那张白色遮罩一显示就把 2pt 的进度条整个盖住 ——
        //   慢网下就变成"只看到提示文字、看不到进度条"。
        //   （`bringSubviewToFront` 必须写在**所有**遮罩层 addSubview 之后，提前调用无效。）
        view.bringSubviewToFront(progressView)

        NSLayoutConstraint.activate([
            // ★ 无原生导航栏（对接文档 §11）：WebView 从状态栏下方一直铺到底，
            //   页面自己那条顶栏就落在状态栏正下方 —— 不用传 topInset（§11.4：iOS 不需要）。
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 进度条浮在页面顶栏最上方 2pt：不参与布局，否则会永久留出一条空隙
            progressView.topAnchor.constraint(equalTo: webView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            failureView.topAnchor.constraint(equalTo: webView.topAnchor),
            failureView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            failureView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            failureView.bottomAnchor.constraint(equalTo: webView.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: webView.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
        ])

        self.webView = webView
        self.walletBridge.webView = webView
        observeProgress(of: webView)
    }

    private func observeProgress(of webView: WKWebView) {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let progress = Float(webView.estimatedProgress)
                if progress >= 1 {
                    self.finishProgressBar()
                } else {
                    self.updateProgressBar(with: progress)
                }
            }
        }
    }

    // MARK: - 顶部进度条

    /// 进入页面时立刻让进度条可见并开始缓慢爬升（静默登录阶段没有真实进度可汇报）。
    /// 幂等：重复调用不会把已经爬上去的下限重置回去（跳转/刷新时会再进一次）。
    private func startProgressBar() {
        progressTimer?.invalidate()
        progressGeneration += 1
        progressFloor = max(progressFloor, 0.06)
        progressView.isHidden = false
        progressView.setProgress(progressFloor, animated: false)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 爬到 0.9 就停住等结果（剩下的交给真实进度）
            guard self.progressFloor < 0.9 else {
                self.stopProgressBar()
                return
            }
            // 越接近 0.9 爬得越慢，给真实进度留出空间
            self.progressFloor = min(0.9, self.progressFloor + (0.9 - self.progressFloor) * 0.06)
            self.updateProgressBar(with: Float(self.webView?.estimatedProgress ?? 0))
        }
        timer.tolerance = 0.1
        progressTimer = timer
    }

    private func stopProgressBar() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// 真实进度与假进度下限取大者显示
    private func updateProgressBar(with realProgress: Float) {
        progressView.isHidden = false
        progressView.setProgress(max(realProgress, progressFloor), animated: true)
    }

    /// 加载完成：补满 → 稍后隐藏 → 复位（下次刷新/进入重新爬）
    private func finishProgressBar() {
        stopProgressBar()
        progressView.isHidden = false
        progressView.setProgress(1, animated: true)
        // 延迟隐藏期间可能又开始了新的加载（页面里的 iframe / 跳转），那时不要把进度条关掉
        let generation = progressGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.progressGeneration == generation else { return }
            self.progressView.isHidden = true
            self.progressView.progress = 0
            self.progressFloor = 0
        }
    }

    private func loadPage() {
        failureView.isHidden = true
        webView?.load(URLRequest(url: AICustomerConfig.siteURL))
    }

    // MARK: - 进入页面（方式 A：不预登录，由页面按需索取）

    /// 直接打开页面 —— **不做**任何预登录。
    ///
    /// 页面自己判断"要不要登录"（§4.1 表格）：有本地会话且地址没变就只读一次地址（0 配额）；
    /// 确实需要登录时才通过 `__csAuthProvider.getAuth()` 找我们**现取**一份凭证。
    private func prepareAndLoad() {
        // 页面加载期间给个过渡提示（慢网下很有用）
        startProgressBar()
        showLoading(true)
        purgeLegacyPageSessionIfNeeded()
        purgePageSessionIfAccountChanged()
        loadPage()
    }

    // MARK: - 私钥预备（首次进入弹一次密码，之后与红包共用内存缓存）

    /// 进入客服时就把私钥备好：**第一次进入弹一次密码**，拿到后写进内存缓存，
    /// 本次启动内再进客服 / 开红包都**不再弹密码**（`WalletPrivateKeyStore`，按地址分键）。
    ///
    /// - 只在**没有缓存**时弹；用户取消则**静默**（等他真的需要登录时会再弹一次）。
    /// - 不阻塞页面加载：页面先渲染，私钥要等到 `getAuth()` 签名时才真正用上。
    /// - 放在 `viewDidAppear`（不是 `viewDidLoad`）：密码框需要宿主已在窗口里。
    private func preparePrivateKeyIfNeeded() {
        guard !didPreparePrivateKey else { return }
        didPreparePrivateKey = true
        // 本版本起私钥不缓存：每次真正签名都会重新认证。这里不再预热，
        // 避免进页面弹一次、`getAuth()` 时又弹一次。
        FZMLog("AI 客服：私钥不再预热（每次签名时认证）")
    }

    // MARK: - 一次性迁移：清掉旧版本留下的「过期会话」

    /// 旧实现（方式 B）把 App 侧 **24h 缓存**的凭证注入给页面，而服务端 token 更短命 ⇒
    /// 页面会把一份**过期 token** 当成自己的本地会话存下来（localStorage），此后一直报「token 失效」。
    ///
    /// 这里在页面脚本之前注入一段清场脚本（且只跑一次）：清掉**本站**的 localStorage，
    /// 页面没有本地会话 → 会主动调 `getAuth()` 拿一份新鲜凭证 → 自愈。
    /// 用 `localStorage.clear()` 而不是删某个键名：**不依赖页面的存储键叫什么**（只影响本站）。
    private func purgeLegacyPageSessionIfNeeded() {
        guard AICustomerStore.needsLegacyPageSessionPurge else { return }
        // 顺手清掉旧版本存在 App 侧的凭证缓存（新版本不再读写，避免以后被误用）
        AICustomerStore.purgeLegacyCredentialCache()

        let script = "try { window.localStorage.clear(); } catch (e) {}"
        webView?.configuration.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        FZMLog("AI 客服：一次性迁移 —— 清除本站 localStorage 里的旧会话（含可能已过期的 token）")
    }

    /// 切账号后清掉页面会话。
    ///
    /// AI 页面把登录凭证存在本站 `localStorage`（`cs_auth`）；如果地址判断没及时更新，
    /// 页面会继续用上一个账号的 token，表现就是「切了账号，AI 还是第一个账户」。
    /// 这里记录上次进入时的登录地址，地址一变就在页面脚本前 `localStorage.clear()`，
    /// 强制页面重新走 `getAuth()`（届时用新账号地址现签）。
    private func purgePageSessionIfAccountChanged() {
        // 用登录账号地址做 key：它一定随切账号变化，且不依赖钱包币种是否已补完。
        let current = LoginUser.shared().address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !current.isEmpty else { return }

        let last = UserDefaults.standard.string(forKey: Self.lastAuthAddressKey)?.lowercased()
        guard last != current else { return }

        let script = "try { window.localStorage.clear(); window.sessionStorage.clear(); } catch (e) {}"
        webView?.configuration.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        UserDefaults.standard.set(current, forKey: Self.lastAuthAddressKey)
        FZMLog("AI 客服：账号已切换（\(last ?? "无") → \(current)），清除本站 localStorage 会话")
    }

    /// 过渡提示：页面加载完成前盖在 WebView 上；延迟 0.25s 再显示，避免缓存命中时闪一下。
    private func showLoading(_ show: Bool) {
        loadingWorkItem?.cancel()
        loadingWorkItem = nil
        guard show else {
            loadingView.isHidden = true
            return
        }
        let item = DispatchWorkItem { [weak self] in
            self?.loadingView.isHidden = false
        }
        loadingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    // MARK: - 动作

    /// 失败页「返回」：无原生导航栏后，页面没加载出来时的唯一退出路径
    @objc private func closeTap() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func retryTap() {
        loadPage()
    }

    /// 加载失败：不阻断、不白屏 —— 只在主框架确实没出来时给一个重试入口（对接文档 §7）
    private func handleLoadFailure(_ error: Error) {
        stopProgressBar()
        progressView.isHidden = true
        progressView.progress = 0
        progressFloor = 0
        showLoading(false)
        failureView.isHidden = false
        FZMLog("AI 客服页面加载失败：\(error.localizedDescription)")
    }

    // MARK: - 联调诊断

    /// 一次把页面侧的全部约定键与 App 侧的自检结果打出来，用来一次定位根因。
    ///
    /// 【为什么要打印这么多】页面停在登录页 / 报「token 失效」只说明"本场会话没拿到可用凭证"，成因有多种：
    ///   ① provider 没注入；② 注入了但页面没走这条路；③ `getAuth()` 返回了 null（登录失败降级）；
    ///   ④ 页面自己的本地会话已失效（旧版本注入过期凭证的后遗症，见 `purgeLegacyPageSessionIfNeeded`）。
    /// 其中 `payload` 现在**应该是 `undefined`** —— 本模块已改为惰性方式 A，不再预注入凭证。
    ///   特别提醒：点击页面上的「连接钱包」报「未检测到钱包」**不能**证明 provider 没注入 ——
    ///   我们本来就只注入 `__csAuthProvider`、不注入 `window.ethereum`，所以那条报错是本模块的预期状态。
    private func logDiagnosis() {
        // App 侧：地址链路全貌（1x 地址 → 0x 地址 → 提交给客服）
        FZMLog("AI 客服地址链路：\(AICustomerSigner.addressChainDescription())")

        // 页面侧：按前端同学给的检查清单逐项取值（不打印任何 token / 签名）
        let script = """
        (function () {
          try {
            var handlers = [];
            try { handlers = Object.keys((window.webkit && window.webkit.messageHandlers) || {}); } catch (e) {}
            var hasLocalSession = 'unavailable';
            try { hasLocalSession = !!window.localStorage.getItem('cs_auth'); } catch (e) { hasLocalSession = 'blocked'; }
            return JSON.stringify({
              provider: typeof window.__csAuthProvider,
              providerGetAddress: !!(window.__csAuthProvider && window.__csAuthProvider.getAddress),
              providerGetAuth: !!(window.__csAuthProvider && window.__csAuthProvider.getAuth),
              payload: typeof window.__csAuthPayload,
              ethereum: typeof window.ethereum,
              ethereumIsTanxinWallet: !!(window.ethereum && window.ethereum.isTanxinWallet),
              alpha: typeof window.alpha,
              dsBridge: typeof window.dsBridge,
              messageHandlers: handlers,
              hasLocalSession: hasLocalSession,
              topFrame: (window.top === window.self),
              href: String(window.location.href)
            });
          } catch (e) { return 'diagnosis-error:' + e; }
        })();
        """
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                FZMLog("AI 客服页面诊断失败：\(error.localizedDescription)")
            } else {
                FZMLog("AI 客服页面诊断：\(result ?? "nil")")
            }
        }
    }

    /// 日志脱敏：地址只留前 6 后 4（实现收敛到 `AICustomerSigner`，避免两份逻辑漂移）
    private static func masked(_ address: String) -> String {
        AICustomerSigner.maskedAddress(address)
    }

    // MARK: - 页面 → 宿主

    /// 页面请求凭证（对接文档 §3.1 的 `getAuth()`）。
    ///
    /// ★★ §3.6（2026-09-24 新增）：本方法**可能在任何时刻被再次调用** —— 除了进入页面，
    ///   页面在聊天中途吃到 401（登录态过期 / 被撤销 / 账号数据被重置）也会再调一次，用于**无感自愈**。
    ///   因此实现必须满足四条：
    ///   ① **每次都当场新签** —— 不做任何凭证缓存（交回旧 token ⇒ 页面判定「重登无效」并停手）；
    ///   ② **静默** —— 自愈路径不弹密码框、不阻塞页面（靠 `allowPasswordPrompt`）；
    ///   ③ **15 秒内一定给结果** —— 网络预算在 `AICustomerAPI.obtainCredentials` 里控制；
    ///   ④ **并发不丢** —— 串在上一次之后（见 `inFlightAuth`）。
    ///   失败一律如实回 `null`（页面会记一条结论并停手，至少 60 秒后再试，不会把限流打光）。
    private func handleGetAuth() {
        let previous = inFlightAuth
        let isSelfHealing = hasIssuedAuth
        FZMLog("AI 客服：页面请求凭证（\(isSelfHealing ? "登录态自愈" : "首次进入")）")

        let task = Task { @MainActor in
            // 串行：等上一次登录收尾（可能是进入时那一次）
            _ = await previous?.value
            // 本版本私钥不缓存：每次 `getAuth` 都重新认证（人脸/指纹或密码）。
            // 自愈路径也允许弹认证，否则 token 过期后永远无法重新登录。
            let payload = await self.makeAuthPayload(allowPasswordPrompt: true)
            if payload != nil { self.hasIssuedAuth = true }
            if let payload = payload {
                self.evaluate("window.__csAuthResolve(\(self.jsLiteral(payload)));")
            } else {
                // 失败回 null：页面会回退到自己的登录页 / 记一条结论并停手（对接文档 §3.6 / §7）
                self.evaluate("window.__csAuthResolve(null);")
            }
        }
        inFlightAuth = task
    }

    /// 跑「取原文 → 静默签名 → 提交登录」三步；任何失败都返回 nil。
    ///
    /// ★ **每次都现取，不做任何缓存** —— 页面只在真正需要时才调到这里（§3.1 / §3.6），
    ///   拿到的必然是新蛜 token；把缓存过的 token 塞给页面，一旦过期就会变成"token 失效"。
    /// - Parameter allowPasswordPrompt: 允许弹密码框取私钥吗？
    ///   **自愈路径传 `false`**（§3.6 要求静默）；首次进入允许（正常情况下进入时已经预备好了，不会真的弹）。
    private func makeAuthPayload(allowPasswordPrompt: Bool) async -> [String: Any]? {
        do {
            let credentials = try await AICustomerAPI.obtainCredentials(allowPasswordPrompt: allowPasswordPrompt)
            // tab_id 必传且非空（对接文档 §3.3）
            return ["auth": credentials.raw, "tab_id": AICustomerStore.tabID]
        } catch let error as AICustomerServiceError {
            // 用户主动取消密码输入：不是失败，不响用户（页面会回退到自己的登录页）
            if case .cancelled = error {
                FZMLog("AI 客服静默登录：用户取消了密码输入，回 null")
            } else {
                FZMLog("AI 客服静默登录失败：\(error.displayDescription)")
                // 拿不到 0x 地址 ⇒ 页面只能退回自己的登录页（「连接钱包」也连不上，因为根本没有地址）
                // ⇒ 不给提示的话用户就是「卡在链接钱包」什么都不发生。
                if case .walletAddressUnavailable = error {
                    self.showToast(L("当前账号没有可用的链上（0x）钱包地址，暂时无法进入 AI 客服"))
                }
            }
            return nil
        } catch {
            FZMLog("AI 客服静默登录失败：\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 分享 / 保存图片

    /// 分享（谈信 / 广场）与保存图片（单发 / 分片）的统一实现在 `TanxinHostBridge`
    /// （`window.__tanxinHost` 的同一套能力，AI 客服与 DApp 浏览器共用）。
    /// 这里只保留薄封装，供老的 `csAuth` 通道兜底调用 —— 线上旧页面包若还在走 `csAuth`，
    /// 行为与新通道完全一致（载荷兼容 `summary` 与 `content`）。

    private func evaluate(_ javaScript: String) {
        webView?.evaluateJavaScript(javaScript, completionHandler: nil)
    }

    /// 生成 JS 字面量（借 JSON 序列化做转义，避免手拼字符串）
    private func jsLiteral(_ value: Any) -> String {
        if let string = value as? String {
            guard let data = try? JSONSerialization.data(withJSONObject: [string], options: []),
                  let arrayLiteral = String(data: data, encoding: .utf8) else { return "\"\"" }
            // ["x"] → "x"（保留引号）
            return String(arrayLiteral.dropFirst().dropLast())
        }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: []),
              let literal = String(data: data, encoding: .utf8) else { return "null" }
        return literal
    }
}

// MARK: - 桥：页面消息

extension AICustomerServiceWebVC: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == AICustomerConfig.scriptHandlerName,
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        // 只接受客服域名（含同源 iframe）；跨域 iframe 不得拿 token / 触发登录 / 调分享。
        guard let allowedHost = AICustomerConfig.siteURL.host?.lowercased(),
              !allowedHost.isEmpty,
              message.frameInfo.securityOrigin.host.lowercased() == allowedHost else {
            FZMLog("AI 客服桥：拒绝跨域调用 origin=\(message.frameInfo.securityOrigin.host)")
            return
        }

        FZMLog("AI 客服桥收到：\(action)（主框架=\(message.frameInfo.isMainFrame)，host=\(message.frameInfo.securityOrigin.host)）")

        // ★ 分享 / 保存图片：**直接分发，不走 `switch` 的 case 匹配** ——
        //   每个动作各自直接调用处理方法（载荷在方法内自己解析），
        //   避免「落到隔壁 case / 参数传错」这类只能靠日志才能查出来的问题。
        //   实现统一在 `TanxinHostBridge`（与 DApp 浏览器共用同一套）。
        if action == "shareToSquare" {
            tanxinBridge.handleShareToSquare(rawPayload: body["payload"])
            return
        }
        if action == "share" {
            tanxinBridge.handleShareToChat(rawPayload: body["payload"])
            return
        }
        // ★ 保存图片：老页面走单发；新页面（`__tanxinHost`）还会走分片三件套
        if action == "saveImage" {
            tanxinBridge.handleSaveImage(rawPayload: body["payload"])
            return
        }
        if action == "saveImageBegin" {
            tanxinBridge.handleSaveImageBegin(rawPayload: body["payload"])
            return
        }
        if action == "saveImageChunk" {
            tanxinBridge.handleSaveImageChunk(rawPayload: body["payload"])
            return
        }
        if action == "saveImageEnd" {
            tanxinBridge.handleSaveImageEnd()
            return
        }

        switch action {
        case "getAddress":
            // 纯本地读取，立刻回填（对接文档 §4.1：3 秒内返回；绝不在这里发 HTTP / 触发登录）
            let address = AICustomerSigner.currentAddress() ?? ""
            FZMLog("AI 客服桥：getAddress 回填 \(AICustomerServiceWebVC.masked(address))")
            evaluate("window.__csAuthAddress(\(jsLiteral(address)));")
        case "getAuth":
            handleGetAuth()
        case "back":
            // 对接文档 §11.3 通道 3：页面顶栏的返回键 → 与 App 原生返回同一结果
            handleBack()
        default:
            break
        }
    }
}

// MARK: - 导航

extension AICustomerServiceWebVC: WKNavigationDelegate {

    /// 只允许客服站点留在 WebView 内；外链交给系统浏览器。
    ///
    /// 否则页面一旦导航到任意站点，注入的 `window.ethereum` / `csAuth` 桥仍然有效，
    /// 等于把钱包能力带到了攻击者页面。
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "https" else {
            decisionHandler(.cancel)
            if scheme == "http" {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }
        let allowedHost = AICustomerConfig.siteURL.host?.lowercased() ?? ""
        guard !allowedHost.isEmpty, url.host?.lowercased() == allowedHost else {
            FZMLog("AI 客服：外链转系统浏览器 \(url.host ?? "nil")")
            decisionHandler(.cancel)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 每次真实开始加载（含「⋮ → 刷新」）都重新开始爬动（`startProgressBar` 幂等，不会把进度倒退）
        startProgressBar()
        failureView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面已经加载过一轮，"清旧会话"的一次性迁移到此完成（下次不再清）
        AICustomerStore.needsLegacyPageSessionPurge = false
        finishProgressBar()
        failureView.isHidden = true
        showLoading(false)
        // 把「当前地址 / 链 id」同步进 `window.ethereum`（不抛事件）：
        // 页面若在加载时就判断「是否已连接」，拿到的才是真实状态
        walletBridge.syncInjectedState()
        logDiagnosis()
        // iframe 里的客服组件可能晚于主框架加载，隔一会儿再看一次
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.logDiagnosis()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }
}

// MARK: - 弱代理

/// `WKUserContentController` 会**强引用** handler，直接把 VC 传进去会与 WebView 形成循环引用，
/// 所以用一个弱代理转发（对接文档 §4.2 的注意点）。
private final class AICustomerScriptHandler: NSObject, WKScriptMessageHandler {

    weak var delegate: WKScriptMessageHandler?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
