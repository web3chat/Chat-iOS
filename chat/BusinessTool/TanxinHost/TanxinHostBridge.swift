//
//  TanxinHostBridge.swift
//  chat
//
//  H5 通用宿主对象 `window.__tanxinHost`（《谈信 App × H5 通用对接说明》，2026-10-20）。
//
//  设计要点（照文档逐条落实，改之前先把文档 §1 / §4 / §5 / §6 看一遍）：
//  · 全局键名逐字 `__tanxinHost`，`name` 固定 `'tanxin-ios'`；**所有 H5 项目共用这一个对象**，
//    不要再为不同项目另建注入对象（AI 客服页已从老的 `__csHost` 迁到它）。
//  · 在**页面脚本之前**（`.atDocumentStart`）注入；已存在对象时**只补方法，绝不整体覆盖**
//    （覆盖会丢页面自己或其它模块挂的能力）。
//  · 方法**同步、不返回 Promise、不抛异常**（try/catch 吞掉），异常不抛回页面。
//  · 页面只探测方法在不在（`typeof`）来决定是否显示入口 ⇒ 方法必须一进页面就挂好。
//  · iOS 只有 `postMessage` 一种传输，所以用 `actions` **自报**已实现的**可选**能力（§6）。
//
//  能力落地：
//  · `share` / `shareSquare` → 复用 App 既有能力：`MessageForwarder`（选择会话 + 发一条文本）、
//    `SquareCreatePostVC`（打开发帖页预填正文，由用户自己点发送）。**不是**卡片消息：
//    聊天协议里 `Card(6)` 是「客户端忽略」的类型，没有卡片体，新增成本与跨端风险都高（用户已定）。
//  · `saveImage` / `saveImageBegin|Chunk|End` → `TanxinHostImageSaver` 存系统相册。
//  · `back` → 由宿主决定（统一 `canGoBack ? goBack() : pop`）。
//  · `openChat(address)` → 按地址查联系人（`UserManager.getNetUser`）→ 打开 1:1 聊天；
//    查无此人 / 未登录用 App 自己的 toast 提示，不抛回页面（文档 §2）。
//

import UIKit
import WebKit

// MARK: - 配置

/// 宿主对象与桥通道的固定约定（文档 §1 / §5.3 逐字，别改名）。
enum TanxinHostConfig {

    /// 页面 → 宿主 的通道名：`window.webkit.messageHandlers.tanxinHost`。
    static let handlerName = "tanxinHost"

    /// 宿主标记：iOS 逐字 `'tanxin-ios'`（Android 是 `'tanxin-android'`）。
    static let platformName = "tanxin-ios"

    /// 已实现的**可选**能力（文档 §6）：iOS 只能靠它正向证明能力可用。
    static let reportedActions = ["openChat", "back", "share", "shareToSquare", "saveImage"]
}

// MARK: - 注入脚本

/// `window.__tanxinHost` 的注入脚本。
enum TanxinHostScript {

    /// 页面脚本之前注入（文档 §1：`WKUserScript(atDocumentStart)`；`onPageFinished` 太晚）。
    /// - Parameters:
    ///   - topInset: 页面需要让开安全区时传像素数；DApp 浏览器有原生导航栏、AI 页从安全区起铺，都不需要。
    ///   - forMainFrameOnly: 只给主框架时传 true；页面把能力入口放在 iframe 里时传 false。
    static func userScript(topInset: Int? = nil, forMainFrameOnly: Bool = true) -> WKUserScript {
        WKUserScript(source: source(topInset: topInset),
                     injectionTime: .atDocumentStart,
                     forMainFrameOnly: forMainFrameOnly)
    }

    static func source(topInset: Int? = nil) -> String {
        let actions = TanxinHostConfig.reportedActions.map { "\"\($0)\"" }.joined(separator: ",")
        let inset = topInset.map { "\($0)" } ?? "null"
        return """
        (function () {
          // 文档 §10：不要整体覆盖 —— 在已有对象上加方法（页面/其它项目已经挂上的键全部保留）
          var host = window.__tanxinHost || {};
          if (!host.name) { host.name = '\(TanxinHostConfig.platformName)'; }

          // 能力自报：与已有数组取并集，不覆盖页面自己写的项
          var declared = [\(actions)];
          var actions = Array.isArray(host.actions) ? host.actions : [];
          for (var i = 0; i < declared.length; i++) {
            if (actions.indexOf(declared[i]) < 0) { actions.push(declared[i]); }
          }
          host.actions = actions;

          var topInset = \(inset);
          if (topInset !== null) { host.topInset = topInset; }

          // 同步、不返回、不抛异常（文档 §1）
          var post = function (action, payload) {
            try {
              window.webkit.messageHandlers.\(TanxinHostConfig.handlerName).postMessage({
                action: action,
                payload: payload
              });
            } catch (e) {}
          };

          if (typeof host.back !== 'function') {
            host.back = function () { post('back', null); };
          }
          if (typeof host.openChat !== 'function') {
            host.openChat = function (address) {
              post('openChat', { address: address ? String(address) : '' });
            };
          }
          if (typeof host.share !== 'function') {
            host.share = function (payload) { post('share', payload); };
          }
          if (typeof host.shareSquare !== 'function') {
            host.shareSquare = function (payload) { post('shareToSquare', payload); };
          }
          if (typeof host.saveImage !== 'function') {
            host.saveImage = function (base64, filename) {
              post('saveImage', {
                filename: filename ? String(filename) : '',
                content: String(base64 || '')
              });
            };
          }
          if (typeof host.saveImageBegin !== 'function') {
            host.saveImageBegin = function (filename, totalBytes) {
              post('saveImageBegin', {
                filename: filename ? String(filename) : '',
                totalBytes: String(totalBytes || '')
              });
            };
          }
          if (typeof host.saveImageChunk !== 'function') {
            host.saveImageChunk = function (seq, base64Chunk) {
              post('saveImageChunk', {
                seq: String(seq),
                content: String(base64Chunk || '')
              });
            };
          }
          if (typeof host.saveImageEnd !== 'function') {
            host.saveImageEnd = function () { post('saveImageEnd', null); };
          }

          window.__tanxinHost = host;
        })();
        """
    }
}

// MARK: - 分享载荷（文档 §4）

/// `share(payload)` / `shareSquare(payload)` 的载荷。
///
/// 键名逐字：`title` / `description` / `iconUrl` / `url` / `source`（选填可缺省）。
/// ⚠️ 兼容老 AI 客服页：它把摘要放在 `summary` 里，这里一并接受（`description` 优先）。
struct TanxinSharePayload {

    /// 标题（必填，≤120）
    let title: String
    /// 描述（选填，≤300，允许空串）
    let summary: String
    /// 图标（选填，http/https，≤2048；无效直接丢，不影响分享）
    let iconURL: String
    /// 链接（必填，**https**，≤2048）
    let url: String
    /// 来源（选填，≤60）
    let source: String

    /// 只要求 `title` 与 `url` 有效；任何一项不满足就返回 nil（文档 §4：缺 title 或 url 的卡片不要发）。
    ///
    /// 键名兼容两套：文档里的全名（`title`/`description`/`iconUrl`/`url`/`source`）和
    /// **商城 H5 用的短键**（`t`=标题、`d`=内容、`u`=链接、`i`=头像、`s`=来源），全名优先。
    init?(json: Any) {
        guard let dict = json as? [String: Any] else { return nil }
        let title = Self.firstText(dict, "title", "t")
        let description = Self.firstText(dict, "description", "summary", "d")
        guard !title.isEmpty, let url = Self.httpsURL(Self.firstText(dict, "url", "u")) else { return nil }

        self.title = Self.clipped(title, limit: 120)
        self.summary = Self.clipped(description, limit: 300)
        self.iconURL = Self.httpURL(Self.firstText(dict, "iconUrl", "i"))
        self.url = url
        self.source = Self.clipped(Self.firstText(dict, "source", "s"), limit: 60)
    }

    /// 发到谈信会话的正文：**卡片 JSON**（`{t,d,u,i,s}`）。
    ///
    /// 2026-10-30 用户定：与 Android / Web 端**发成一致的**结构化内容（原来是可读文本），
    /// 因为文本版式塞不进头像 `i`，而聊天里要显示「头像 + 标题 + 内容 + 来源」的卡片。
    /// 键名沿用商城 H5 的短键：`t`=标题、`d`=内容、`u`=链接、`i`=头像、`s`=来源。
    ///
    /// ⚠️ **只影响分享到聊天**；分享到广场仍走 `squareContent`（可读文本，用户自己编辑发布）。
    func messageText(header: String? = nil) -> String {
        // 卡片样式关闭时发**文本版式**（之前的样式）：老版本 App / 其它端收到都能正常显示，
        // 不会把 `{"t":…}` 这种原始 JSON 露出来。开关见 `FZM_EnableShareLinkCard`。
        guard FZM_EnableShareLinkCard else {
            return contentText(header: header)
        }

        // 抬头（`来自小Y的分享`）在 JSON 里没有位置 ⇒ 载荷没给来源时，用抬头里的名字当来源，
        // 否则卡片底部只能显示域名。
        let source = self.source.isEmpty ? Self.headerName(header) : self.source
        let payload: [String: String] = [
            "t": title,
            "d": summary,
            "u": url,
            "i": iconURL,
            "s": source
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            // 极端情况（理论上不会）退回文本版式，至少别发一条空消息
            return contentText(header: header)
        }
        // `JSONSerialization` 会把 `/` 转义成 `\/`（合法但难看）：老版本 App 收到只会显示原文，
        // 这里还原成 `/`，让它至少是一条一眼能看懂、能点的链接。
        return json.replacingOccurrences(of: "\\/", with: "/")
    }

    /// 从抬头「来自X的分享」里取出 X（不是这个形状就返回空串）
    private static func headerName(_ header: String?) -> String {
        guard let header = header,
              header.hasPrefix("来自"), header.hasSuffix("的分享"),
              header.count > "来自".count + "的分享".count else { return "" }
        return String(header.dropFirst("来自".count).dropLast("的分享".count))
    }

    /// 打开发帖页时预填的正文（广场只有正文一个字段，**仍然用可读文本版式**，与 `messageText` 不同）
    func squareContent(header: String? = nil) -> String {
        contentText(header: header)
    }

    private func contentText(header: String?) -> String {
        var lines = [title]
        if !summary.isEmpty { lines.append(summary) }
        lines.append(url)
        if !source.isEmpty { lines.append("来源：\(source)") }
        let body = lines.joined(separator: "\n")
        // 正文用「」把内容包起来（没有抬头时也包）：老版本 / 其它端如果收到这种文本版式，
        // 聊天气泡能靠这个壳子把它认成「分享卡片」（`ShareLinkCard.parse`）。
        guard let header = header, !header.isEmpty else { return "「\(body)」" }
        return "\(header)\n「\(body)」"
    }

    // MARK: 校验

    /// 按顺序取**第一个非空**的文本（全名键在前、短键在后）
    private static func firstText(_ dict: [String: Any], _ keys: String...) -> String {
        for key in keys {
            let value = text(dict[key])
            if !value.isEmpty { return value }
        }
        return ""
    }

    private static func text(_ value: Any?) -> String {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return ""
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    private static func httpsURL(_ value: String) -> String? {
        guard !value.isEmpty, value.count <= 2048,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              (components.host ?? "").isEmpty == false else { return nil }
        return value
    }

    private static func httpURL(_ value: String) -> String {
        guard !value.isEmpty, value.count <= 2048,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              (components.host ?? "").isEmpty == false else { return "" }
        return value
    }
}

// MARK: - 桥

/// `window.__tanxinHost` 的页面 → 宿主收口。
///
/// - `WKUserContentController` 会**强引用** handler ⇒ 这里只弱持有宿主 VC（不形成循环引用）。
/// - 由 AI 客服页与通用 DApp 浏览器各持有一个实例（各自的 WebView 各自一套分片状态）。
final class TanxinHostBridge: NSObject, WKScriptMessageHandler {

    /// 承载桥的页面控制器（分享选择器 / 发帖页 / toast 都从它出发）
    weak var host: UIViewController?

    /// 分享文本第一行的抬头（AI 客服页 =「来自小Y的分享」；其它页面不传）
    var shareHeader: String?

    /// 动态抬头：每次分享时现算（DApp 浏览器用它拼「来自<当前 DApp 名称>的分享」）。
    /// 优先级高于 `shareHeader`，返回 nil/空串时回退到 `shareHeader`。
    var shareHeaderProvider: (() -> String?)?

    /// 页面点「返回」时的落地实现（各宿主自己决定：Web 历史优先，其次退出页面）
    var onBack: (() -> Void)?

    /// 分片保存图片的会话状态（单发不走它）
    private let imageSaver = TanxinHostImageSaver()

    // MARK: 页面 → 宿主

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == TanxinHostConfig.handlerName,
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        // 只接受主框架：分享 / 保存图片 / 打开聊天等能力不应被第三方 iframe 调起。
        guard message.frameInfo.isMainFrame else {
            FZMLog("H5 宿主桥：拒绝非主框架调用 action=\(action) origin=\(message.frameInfo.securityOrigin.host)")
            return
        }

        FZMLog("H5 宿主桥收到：\(action)（主框架=\(message.frameInfo.isMainFrame)，host=\(message.frameInfo.securityOrigin.host)）")

        // ★ 逐个 `if` 直接分发（不走 switch）—— 与 AI 客服页既有写法一致，
        //   避免「落到隔壁 case / 参数传错」这类只能靠日志才能查出来的问题。
        if action == "shareToSquare" {
            handleShareToSquare(rawPayload: body["payload"])
            return
        }
        if action == "share" {
            handleShareToChat(rawPayload: body["payload"])
            return
        }
        if action == "saveImage" {
            handleSaveImage(rawPayload: body["payload"])
            return
        }
        if action == "saveImageBegin" {
            handleSaveImageBegin(rawPayload: body["payload"])
            return
        }
        if action == "saveImageChunk" {
            handleSaveImageChunk(rawPayload: body["payload"])
            return
        }
        if action == "saveImageEnd" {
            handleSaveImageEnd()
            return
        }
        if action == "back" {
            handleBack()
            return
        }
        if action == "openChat" {
            // 文档 §7.2 的示例是把地址放在顶层 `address`；也兼容包在 `payload` 里的写法
            let payloadAddress = (body["payload"] as? [String: Any])?["address"]
            handleOpenChat(rawAddress: body["address"] ?? payloadAddress)
            return
        }
    }

    // MARK: 返回

    /// 页面自己接管顶栏时，页面返回键会调到这里；与原生返回同一语义（文档 §3）。
    func handleBack() {
        if let onBack = onBack {
            onBack()
        } else {
            host?.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: 分享到谈信（谈信 = 选择会话 + 发一条文本）

    /// 由 `userContentController` 里 `action == "share"` **直接调用**（不走 switch）。
    /// 目标会话由**用户自己在 App 里选**（用户 2026-10-20 明确：不需要 H5 决定和谁聊天）。
    func handleShareToChat(rawPayload: Any?) {
        guard let payload = TanxinSharePayload(json: rawPayload) else {
            FZMLog("H5 分享：谈信 —— 载荷无效（缺少 title/url 或 url 不是 https），忽略")
            toast(L("分享内容无效"))
            return
        }
        guard LoginUser.shared().isLogin else {
            toast(L("请先登录"))
            return
        }
        guard let host = host else { return }

        FZMLog("H5 分享：谈信（标题=\(payload.title)，链接=\(payload.url)）")
        let header = currentShareHeader()
        MessageForwarder.presentMultiPicker(from: host) { [weak host] sessionIDs in
            guard let host = host, let first = sessionIDs.first else { return }
            let message = Message(fromId: LoginUser.shared().address,
                                  sessionId: first,
                                  msgType: .init(text: payload.messageText(header: header)))
            MessageForwarder.forward([message], to: sessionIDs, from: host)
        }
    }

    // MARK: 分享到谈信广场（打开发帖页预填，由用户自己点发送）

    /// 由 `userContentController` 里 `action == "shareToSquare"` **直接调用**（不走 switch）。
    /// 不要在这里直接发帖 —— 交给 `SquareCreatePostVC`（复用它的字数限制 / 选图 / 提交与反馈）。
    func handleShareToSquare(rawPayload: Any?) {
        guard let payload = TanxinSharePayload(json: rawPayload) else {
            FZMLog("H5 分享：广场 —— 载荷无效（缺少 title/url 或 url 不是 https），忽略")
            toast(L("分享内容无效"))
            return
        }
        guard LoginUser.shared().isLogin else {
            toast(L("请先登录"))
            return
        }
        guard SquareStatusStore.canPost else {
            toast(SquareStatusStore.cannotPostMessage)
            return
        }
        guard let host = host else { return }

        FZMLog("H5 分享：广场（打开发帖页预填，标题=\(payload.title)，链接=\(payload.url)）")
        let vc = SquareCreatePostVC.create(withContent: payload.squareContent(header: currentShareHeader()))
        vc.hidesBottomBarWhenPushed = true
        if let nav = host.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            // 宿主导航栈缺失时（理论上只有模态容器）兜底包一层，避免点了没反应
            let nav = FZMNavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            host.present(nav, animated: true)
        }
    }

    // MARK: 保存图片（文档 §5）

    /// 单发：只在原图 ≤512KB 时页面才会走这里。
    /// 兼容两种键名：新文档是 `base64`，老 AI 页面发的是 `content`。
    func handleSaveImage(rawPayload: Any?) {
        guard let payload = rawPayload as? [String: Any] else {
            toast(L("图片保存失败"))
            return
        }
        let content = (payload["content"] as? String) ?? (payload["base64"] as? String) ?? ""
        let filename = payload["filename"] as? String ?? ""
        guard !content.isEmpty else {
            FZMLog("H5 保存图片：载荷无效（缺少 content/base64），忽略")
            toast(L("图片保存失败"))
            return
        }
        imageSaver.saveSingle(base64: content, filename: filename) { [weak self] success in
            self?.toast(success ? L("图片已保存") : L("图片保存失败"))
        }
    }

    /// 分片第一包（文档 §5.2：`begin → chunk × N → end`，每片 256KB 原图）
    func handleSaveImageBegin(rawPayload: Any?) {
        guard let payload = rawPayload as? [String: Any] else {
            imageSaver.cancel()
            return
        }
        let totalBytes = (payload["totalBytes"] as? String)
            ?? (payload["totalBytes"] as? NSNumber)?.stringValue
            ?? ""
        imageSaver.begin(filename: payload["filename"] as? String ?? "", totalBytes: totalBytes)
    }

    func handleSaveImageChunk(rawPayload: Any?) {
        guard let payload = rawPayload as? [String: Any],
              let content = payload["content"] as? String, !content.isEmpty else {
            imageSaver.cancel()
            return
        }
        let seq = (payload["seq"] as? String)
            ?? (payload["seq"] as? NSNumber)?.stringValue
            ?? ""
        imageSaver.append(seq: seq, base64: content)
    }

    func handleSaveImageEnd() {
        imageSaver.finish { [weak self] success in
            self?.toast(success ? L("图片已保存") : L("图片保存失败"))
        }
    }

    // MARK: 打开聊天（文档 §2）

    /// 防连点：查用户要发一次链上请求，期间重复调用直接忽略
    private var isOpeningChat = false

    /// `openChat(address)`：H5 传的是**谈信账号地址**（原样使用，不改大小写）。
    ///
    /// 用户 2026-10-22：点击谈信地址时**先弹确认框**，确认后再跳聊天页，
    /// 避免在第三方 H5 里误触就直接切走页面。
    /// 确认后才按地址查联系人（`UserManager.getNetUser`，会顺带把昵称/头像回写本地会话），
    /// 再统一走 `FZMUIMediator.goChatVC` 打开 1:1 聊天。
    /// 查无此人 / 未登录都由 App 自己 toast，**不抛回页面**。
    func handleOpenChat(rawAddress: Any?) {
        let address = ((rawAddress as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            FZMLog("H5 打开聊天：地址为空，忽略")
            toast(L("无效地址"))
            return
        }
        guard LoginUser.shared().isLogin else {
            toast(L("请先登录"))
            return
        }
        FZMLog("H5 打开聊天：弹确认框 address=\(address)")
        confirmOpenChat(with: address)
    }

    /// 确认弹窗：文案里的地址用 `shortAddress`（前 4 后 4），让用户能核对目标。
    private func confirmOpenChat(with address: String) {
        let message = String(format: L("即将离开当前页面，打开与「%@」的聊天。"), address.shortAddress)
        let alert = UIAlertController(title: L("打开谈信聊天"),
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: L("打开"), style: .default) { [weak self] _ in
            self?.startOpenChat(with: address)
        })
        present(alert)
    }

    /// 用户点了「打开」之后才真正查人 / 跳页
    private func startOpenChat(with address: String) {
        guard !isOpeningChat else { return }
        isOpeningChat = true

        // 自己：不用查链，直接进自己的聊天页（不会存在“和自己”的会话，这里直接拦下体验更好）
        if address == LoginUser.shared().address {
            isOpeningChat = false
            openChat(with: address)
            return
        }

        lookupChatUser(candidates: lookupCandidates(for: address), index: 0)
    }

    /// 在宿主之上弹 alert（已 present 其它页面时弹到最上层，避免 present 无效）
    private func present(_ alert: UIAlertController) {
        DispatchQueue.main.async { [weak self] in
            guard let base = self?.host ?? UIViewController.current() else { return }
            var top = base
            while let presented = top.presentedViewController { top = presented }
            top.present(alert, animated: true)
        }
    }

    /// 按候选地址依次查用户（文档 §2：`0x…` / `1…` 两种写法都要落到同一个人）。
    ///
    /// 先按原样查；失败且是 `0x…` 时再补一次 BTY 写法（同一个账号地址的两种编码）。
    /// ⚠️ 这里**不是** EVM 钱包地址转换：BTY 地址的 20 字节与 `keccak256(pub)` 不是同一段数据，
    /// `WalletapiBtyAddrToEthAddr` 只是重新编码；所以只在「谈信账号地址的 0x 写法」场景下作为兜底。
    private func lookupCandidates(for address: String) -> [String] {
        var result = [address]
        guard address.count == 42, address.lowercased().hasPrefix("0x") else { return result }

        var error: NSError?
        let bty = WalletapiEthAddrToBtyAddr(address, &error)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if error == nil, !bty.isEmpty, bty != address {
            result.append(bty)
            FZMLog("H5 打开聊天：0x 写法补一个 BTY 候选 \(bty)")
        } else {
            FZMLog("H5 打开聊天：0x 地址转 BTY 失败（\(error?.localizedDescription ?? "空结果")）")
        }
        return result
    }

    private func lookupChatUser(candidates: [String], index: Int) {
        guard index < candidates.count else {
            isOpeningChat = false
            FZMLog("H5 打开聊天：候选地址都查不到用户 \(candidates)")
            toast(L("没有匹配对象"))
            return
        }
        let candidate = candidates[index]
        UserManager.shared().getNetUser(targetAddress: candidate, successBlock: { [weak self] user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isOpeningChat = false
                // 用服务端返回的地址（与服务端同源），大小写/格式以它为准
                self.openChat(with: user.address)
            }
        }, failureBlock: { [weak self] _ in
            DispatchQueue.main.async {
                self?.lookupChatUser(candidates: candidates, index: index + 1)
            }
        })
    }

    private func openChat(with address: String) {
        guard !address.isEmpty else {
            toast(L("无效地址"))
            return
        }
        FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.person(address)))
    }

    // MARK: 工具

    /// 本次分享使用的抬头（动态优先；两者都没有就不加抬头）
    private func currentShareHeader() -> String? {
        if let dynamic = shareHeaderProvider?(), !dynamic.isEmpty { return dynamic }
        if let header = shareHeader, !header.isEmpty { return header }
        return nil
    }

    private func toast(_ text: String) {
        if let host = host {
            host.showToast(text)
        } else {
            APP.shared().showToast(text)
        }
    }
}
