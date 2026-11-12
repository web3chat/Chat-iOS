//
//  VoiceRoomService.swift
//  chat
//
//  语音房 H5 服务：站点配置 + 建房接口 + 房间链接模板。
//
//  对接文档（`谈信广场功能/语音/README.md`）：
//  · `POST /api/v1/room/create` —— App 端建房入口，服务端生成随机房间号 + PIN，
//    「校验、撞号重试、PIN 限流都在服务端」，**App 端不自造房间参数**；
//  · 响应 `{ "code": 0, "room": "abc234", "pin": "8866", "mode": "voice", "owner": "0x…" }`，
//    失败 `{ "code": 1, "error": "…" }`；
//  · 建房时可带 `owner`（房主 0x 地址，存进房主列表）。本模块**不传** `user_addr`
//    —— 不绑定就凭 room + PIN 进房，适配「把链接发给对方一起聊」的场景。
//
//  为什么走 `URLSession` 而不是项目自有的 Moya/`Provider`：
//  这是**第三方 H5 后端**，与项目自有 API 没有签名/鉴权约定，套 `XLSTargetType` 会把
//  `FZM-SIGNATURE` / `X-App-Id` 等自有请求头一起发过去。同模块的 AI 客服（`AICustomerAPI`）
//  也是同一个理由走 `URLSession` 直连。
//
//  host 配置方式与 AI 客服完全一致：UserDefaults → Info.plist → `SeverContext` 常量。
//

import Foundation

// MARK: - 错误

enum VoiceRoomError: LocalizedError {

    /// 没有配置站点地址（`VoiceRoomBaseURL` / `VoiceRoomSiteURL` 都空）
    case notConfigured
    /// 网络层失败 / 响应不是合法 JSON
    case network(String)
    /// 服务端返回 `code != 0`
    case business(String)
    /// 响应缺少 `room` / `pin`
    case incomplete

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L("房间服务未配置")
        case .network(let message):
            return message
        case .business(let message):
            return message
        case .incomplete:
            return L("房间创建失败")
        }
    }
}

// MARK: - 模式

/// 房间模式（与 H5 / 服务端约定的取值）
///
/// 文档：`mode` 缺省是 `video`；`voice` = 服务端强制仅麦克风（页面不显示摄像头按钮）。
/// ⚠️ 模式在**建房时定死**并存进服务端 Redis，之后以服务端返回为准
///    ⇒ 建房请求体与进房链接里必须带**同一个**模式，不能不一致。
enum VoiceRoomMode: String {
    /// 语音聊天
    case voice
    /// 视频聊天
    case video

    /// 弹窗 / 界面上的显示名
    var title: String {
        switch self {
        case .voice:
            return L("语音聊天")
        case .video:
            return L("视频聊天")
        }
    }
}

// MARK: - 服务

enum VoiceRoomService {

    // MARK: 站点配置

    /// UserDefaults / Info.plist 里的站点地址键（不配置则用 `SeverContext.VoiceRoomBaseURL`）
    static let siteURLKey = "VoiceRoomSiteURL"

    /// 单次请求超时
    static let requestTimeout: TimeInterval = 10

    /// 是否放行**自签证书**（只对 `siteURL` 的那个 host 生效，其它 host 一律走系统默认校验）。
    ///
    /// 内网联调期需要开着 —— 本地机房用自签证书，iOS 默认会以
    /// `NSURLErrorServerCertificateUntrusted (-1202)` 拒绝整页加载。
    /// 实现见 `VoiceRoomWebSupport.handleChallenge(_:completionHandler:)`
    /// （由 `DAppBrowserViewController` 在 `WKNavigationDelegate` 里转发）。
    ///
    /// ✅ 站点已切到正式域名（证书链正常）⇒ 改回 `false`，恢复严格校验。
    /// 若日后又指向内网自签证书的地址，需要再把它临时改回 `true`。
    static let trustsSelfSignedCertificate = false

    /// 语音房 H5 站点地址；三级回退都拿不到时返回 nil（调用方应提示「未配置」而不是发一个坏请求）
    static var siteURL: URL? {
        let configured = (UserDefaults.standard.string(forKey: siteURLKey) ?? infoPlistSiteURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let configured = configured, !configured.isEmpty, let url = URL(string: configured) {
            return url
        }
        let fallback = VoiceRoomBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fallback.isEmpty else { return nil }
        return URL(string: fallback)
    }

    private static var infoPlistSiteURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: siteURLKey) as? String else { return nil }
        return value
    }

    /// 专用 URLSession：只为放行配置 host 的自签证书（见 `trustsSelfSignedCertificate`）。
    ///
    /// ⚠️ `NSAppTransportSecurity`（`NSAllowsArbitraryLoads`）**不管证书链校验** —— ATS 只放宽协议层
    /// 要求（允许 http / 弱加密套件），证书可信性由 TLS 栈独立判定。所以内网自签证书下，
    /// 建房请求走 `URLSession.shared` 会直接以 `NSURLErrorServerCertificateUntrusted` 失败。
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        return URLSession(configuration: configuration,
                          delegate: SelfSignedTrustDelegate(),
                          delegateQueue: nil)
    }()

    /// 证书挑战：**只对 `siteURL` 的 host** 放行自签证书，其它 host 一律走系统默认校验
    private final class SelfSignedTrustDelegate: NSObject, URLSessionDelegate {

        func urlSession(_ session: URLSession,
                        didReceive challenge: URLAuthenticationChallenge,
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
    }

    // MARK: 房间链接

    /// 房间号 + PIN → 进房链接
    ///
    /// 形态照对接文档与 App 侧示例：`https://host/?room=abc234&pin=8866&mode=voice#/`
    /// · 查询串在 `#` **之前**、并保留 `#/` 后缀 —— 这是 H5 的实际形态；
    ///   若前端改成 history 路由，**只改这一个方法**即可（全仓唯一拼链接的地方）。
    static func roomLink(room: String, pin: String, mode: VoiceRoomMode = .voice) -> URL? {
        guard let base = siteURL else { return nil }
        // 去掉基址末尾的 "/"，再统一补 "/?"（`URLComponents` 在空 path 时不会补这个斜杠，
        // 会拼出 `https://host?room=…`，与文档形态不一致）
        var root = base.absoluteString
        while root.hasSuffix("/") { root.removeLast() }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "room", value: room),
            URLQueryItem(name: "pin", value: pin),
            URLQueryItem(name: "mode", value: mode.rawValue)
        ]
        guard let query = components.percentEncodedQuery, !query.isEmpty else { return nil }
        return URL(string: "\(root)/?\(query)#/")
    }

    // MARK: 进房链接补 `name`

    /// 给进房链接补上 `name`（H5 用它当**参与者在房间里的显示名**）
    ///
    /// ⚠️ 需要它是必需的：H5 侧（`index-*.js`）读 `window.location.search` 的
    ///    `room` / `pin` / `name`，**三者齐全才会自动加入房间**（缺一个就要用户手填）。
    /// ⚠️ `name` 必须**按人、在打开时**补：消息里分享的那条链接**不能**带名字，
    ///    否则收到链接的人会顶着**发起人的名字**进房。所以这里只改「真正加载的 URL」，
    ///    不改 `roomLink` 拼出来、发进聊天的那个链接。
    /// 幂等：已存在的 `name` 会被替换掉；`name` 为空时原样返回。
    static func link(_ url: URL, addingName name: String) -> URL {
        guard !name.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        items.removeAll { $0.name.lowercased() == "name" }
        items.append(URLQueryItem(name: "name", value: name))
        components.queryItems = items
        return components.url ?? url
    }

    // MARK: 链接解析

    /// 取链接里的**房间号**（`room` 查询参数）；取不到返回 nil
    static func roomCode(of url: URL) -> String? {
        queryValue("room", in: url)
    }

    /// 取链接里的**模式**（`mode` 查询参数）；取不到按 `voice`
    static func mode(of url: URL) -> VoiceRoomMode {
        guard let raw = queryValue("mode", in: url)?.lowercased() else { return .voice }
        return VoiceRoomMode(rawValue: raw) ?? .voice
    }

    /// 是否**语音房 / 群视频房间链接**：`room` 与 `mode` 必须**同时存在且合法**，
    /// 且 host 必须是配置的语音房站点。
    ///
    /// ⚠️ 2026-11-06 安全整改：此前只按 `room`/`mode` 参数判定、不校验域名，
    ///    任意 `https://evil.com/?room=x&mode=voice` 都能让 App 打开一个「语音房」容器：
    ///    自动获得麦克风/摄像头权限，并被注入 `window.H5Wallet` 读取钱包地址。
    ///    现在要求 host 与 `siteURL`（由 `VoiceRoomBaseURL` / `VoiceRoomSiteURL` 配置）一致；域名更换时改配置即可。
    ///
    /// ⚠️ 不能只看 `room`：其它业务链接（外部 H5 / DApp）也可能带 `room` 参数。
    static func isRoomLink(_ url: URL) -> Bool {
        // `queryValue` 已做 trim，空值返回 nil ⇒ 非 nil 即为「存在且非空」
        guard queryValue("room", in: url) != nil else { return false }
        guard let raw = queryValue("mode", in: url)?.lowercased(),
              VoiceRoomMode(rawValue: raw) != nil else { return false }
        guard let allowedHost = siteURL?.host?.lowercased(), !allowedHost.isEmpty else { return false }
        return url.host?.lowercased() == allowedHost
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let value = items.first { $0.name.lowercased() == name }?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = value, !value.isEmpty else { return nil }
        return value
    }

    // MARK: 邀请文案

    /// 建房后发到会话里的邀请文案（**不含**链接；链接由调用方另起一行拼上）
    ///
    /// ⚠️ 文案按 **模式（语音 / 视频）× 会话类型（私聊 / 群聊）** 共 4 种：
    ///    群聊 = `%@ 发起了群语音/群视频，点击下方按钮或链接一起…`，
    ///    私聊 = `%@ 发起了语音/视频聊天，点击下方按钮或链接…`。
    ///    「按钮或链接」两者都写上：本机（新版）气泡里看到的是「加入语音」按钮，
    ///    其它端 / 老版本仍然只有可点的链接（正文里那行链接没有被删）。
    /// ⚠️ 群聊正文前面加 `@所有人`（`@` + 「所有人」+ `\u{2004}` 标记，与输入栏 @ 功能同格式）——
    ///    本工程**任何人都能 @所有人**（`FZMAtPeopleVC.headerView` 里「普通群成员不能 @所有人」
    ///    的判断已被注释掉）。
    /// ⚠️ 光有正文文字**不生效**：还得由调用方把消息的 `mentionIds` 置成 `["ALL"]`
    ///    （`ChatVC.createVoiceRoom` 已这么做）—— 会话列表的「有人@我」红点、服务端按 @ 推送
    ///    都是靠 `mentionIds` 判定的（`SessionManager` 匹配 `"ALL"` 或本人地址）。
    /// ⚠️ 链接必须留在消息正文里：气泡是「整条文本」响应点击、取第一段 http/https 链接
    ///    （`ChatVC.firstLink`），只发文案就没有可点的链接了。
    static func inviteText(mode: VoiceRoomMode, isPrivateChat: Bool, name: String) -> String {
        let format: String
        switch (mode, isPrivateChat) {
        case (.voice, true):
            format = L("%@ 发起了语音，点击下方按钮或链接加入语音聊天吧")
        case (.voice, false):
            format = L("%@ 发起了群语音，点击下方按钮或链接一起语音聊天吧")
        case (.video, true):
            format = L("%@ 发起了视频聊天，点击下方按钮或链接加入视频聊天吧")
        case (.video, false):
            format = L("%@ 发起了群视频，点击下方按钮或链接一起视频聊天吧")
        }
        let text = String(format: format, name)
        guard !isPrivateChat else { return text }
        // `AtChar` / `AtEndChar` 是输入栏 @ 功能的全局常量（`FZMInputAtItem.swift`）
        return AtChar + L("所有人") + AtEndChar + text
    }

    // MARK: 建房

    /// `POST /api/v1/room/create` —— 建房并拿到服务端生成的房间号 + PIN
    /// - Parameters:
    ///   - owner: 房主 0x 地址（当前登录用户的钱包地址），会存进服务端房主列表
    ///   - mode: 语音 / 视频（**建房时定死**，见 `VoiceRoomMode`）
    static func createRoom(owner: String, mode: VoiceRoomMode = .voice) async throws -> (room: String, pin: String) {
        guard let site = siteURL else {
            FZMLog("语音房：站点地址未配置（VoiceRoomSiteURL / VoiceRoomBaseURL 均为空）")
            throw VoiceRoomError.notConfigured
        }
        let url = site.appendingPathComponent("api/v1/room/create")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = ["mode": mode.rawValue]
        if !owner.isEmpty { body["owner"] = owner }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        FZMLog("语音房：建房请求 \(url.absoluteString) mode=\(mode.rawValue) owner=\(owner.isEmpty ? "(空)" : "\(owner.prefix(6))...\(owner.suffix(4))")）")

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw VoiceRoomError.network(L("网络连接错误，请稍后再试"))
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            throw VoiceRoomError.network(L("网络连接错误，请稍后再试"))
        }

        let code = intValue(json["code"]) ?? -1
        guard code == 0 else {
            let message = (json["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            FZMLog("语音房：建房业务失败 code=\(code) error=\(message)")
            throw VoiceRoomError.business(message.isEmpty ? L("房间创建失败") : message)
        }

        // `pin` 服务端返回的是字符串（"8866"），但兼容数字型返回
        guard let room = stringValue(json["room"]), !room.isEmpty,
              let pin = stringValue(json["pin"]), !pin.isEmpty else {
            FZMLog("语音房：建房响应缺少 room / pin")
            throw VoiceRoomError.incomplete
        }
        // PIN 不是敏感凭证（同房间共享的口令），打全便于联调
        FZMLog("语音房：建房成功 room=\(room) pin=\(pin)")
        return (room, pin)
    }

    // MARK: 私有

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }
}

// MARK: - 邀请消息在气泡里的呈现

/// 语音 / 视频聊天邀请消息在聊天气泡里的**展示层**规格：正文去掉房间链接 + 底部一个高亮按钮。
///
/// ⚠️ 消息正文（`msgType.text`）**保持原样**（邀请文案 + `\n` + 房间链接），不做任何裁剪：
///    · 其它端（Android / Web）和老版本 App 仍然靠正文里那行链接进房；
///    · 本机点击依旧走气泡原来的路径（`ChatVC.didTapMessage` → `.text` → `openUrl` →
///      `firstLink` → `VoiceRoomLauncher.open`），所以按钮只要转发同一次点击即可。
///    本类型只负责「怎么显示」：把那一行链接从气泡正文里摘掉，换成「加入语音」按钮。
///
/// ⚠️ 尺寸常量必须与 `TextMessageSizeCalculator`（算高度）和 `TextMessageCell`（摆按钮）**同源**，
///    改这里一处即可；两边各写一份会导致按钮压住正文或底部留白。
enum VoiceRoomInvite {

    // MARK: - 卡片样式（2026-10-22 用户要求：整条消息 = 图标 + 「语音聊天」+「点击加入聊天 · 房间 …」）

    /// 卡片左右内边距
    static let cardPaddingH: CGFloat = 12
    /// 卡片上下内边距
    static let cardPaddingV: CGFloat = 12
    /// 左侧图标边长
    static let cardIconSide: CGFloat = 38
    /// 图标底色圆角
    static let cardIconCorner: CGFloat = 10
    /// 图标与右侧文字的间距
    static let cardIconGap: CGFloat = 10
    /// 标题与副标题之间的间距
    static let cardTitleSpacing: CGFloat = 2
    /// 卡片最小宽度
    static let minimumBubbleWidth: CGFloat = 160
    /// 卡片最大宽度（房间号那行靠截断塞进来，别让气泡越撑越长）
    static let maxCardWidth: CGFloat = 232
    /// 卡片圆角
    static let cardCornerRadius: CGFloat = 10
    /// 卡片描边（白底卡片需要一层细边才不糊在背景里）
    static let cardBorderWidth: CGFloat = 0.5

    static var cardTitleFont: UIFont { UIFont.systemFont(ofSize: 15, weight: .semibold) }
    static var cardSubtitleFont: UIFont { UIFont.systemFont(ofSize: 12) }
    static var cardRoomFont: UIFont { UIFont.systemFont(ofSize: 11) }

    /// 卡片标题：语音聊天 / 视频聊天（按链接里的 `mode`）
    static func cardTitle(for link: URL) -> String {
        VoiceRoomService.mode(of: link) == .video ? L("视频聊天") : L("语音聊天")
    }

    /// 卡片第二行：点击加入聊天
    static func cardSubtitle(for link: URL) -> String {
        L("点击加入聊天")
    }

    /// 卡片第三行：房间 h5_xxx（单独一行，避免整条卡片被房间号撑得太长）
    static func cardRoom(for link: URL) -> String {
        let room = VoiceRoomService.roomCode(of: link) ?? ""
        guard !room.isEmpty else { return "" }
        return String(format: L("房间 %@"), room)
    }

    /// 卡片高度（= 气泡高度）：三行文字比图标高时以文字为准。
    static var cardHeight: CGFloat {
        let textHeight = cardTitleFont.lineHeight + cardTitleSpacing
            + cardSubtitleFont.lineHeight + cardTitleSpacing
            + cardRoomFont.lineHeight
        return ceil(max(cardIconSide, textHeight)) + cardPaddingV * 2
    }

    /// 卡片宽度（= 气泡宽度），受气泡最大宽度与 `maxCardWidth` 双重限制（房间号过长由 label 截断）
    static func cardWidth(for link: URL, maxWidth: CGFloat) -> CGFloat {
        let widths = [cardTitle(for: link), cardSubtitle(for: link), cardRoom(for: link)].map { text -> CGFloat in
            let font = text == cardTitle(for: link) ? cardTitleFont
                : (text == cardSubtitle(for: link) ? cardSubtitleFont : cardRoomFont)
            return ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        let textWidth = widths.max() ?? 0
        let wanted = cardIconSide + cardIconGap + textWidth + cardPaddingH * 2
        let limit = maxWidth > 0 ? min(maxWidth, maxCardWidth) : maxCardWidth
        return min(limit, max(wanted, minimumBubbleWidth))
    }

    /// 找出正文里的**房间链接**（必须带 `room` + 合法 `mode`）；没有返回 nil。
    ///
    /// 判定复用 `VoiceRoomService.isRoomLink`（与 `isVoiceRoomLink` 同一套口径），
    /// 因此普通链接（非语音房）仍然原样显示成可点的蓝色链接。
    static func link(in text: String) -> URL? {
        // 绝大多数消息没有链接：先用最便宜的字符串判断挡掉，避免每条消息都跑一次探测器
        guard text.range(of: "http", options: .caseInsensitive) != nil,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, options: [], range: range) {
            guard let url = match.url else { continue }
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else { continue }
            if VoiceRoomService.isRoomLink(url) { return url }
        }
        return nil
    }

    /// 复制内容：邀请消息返回**完整房间链接**（含 `room` / `pin` / `mode`），
    /// 不是邀请消息则原样返回全文。
    static func copyText(for text: String) -> String {
        guard let link = link(in: text) else { return text }
        return link.absoluteString
    }

    /// 气泡里显示的正文：把**房间链接那一行**整行去掉（不是邀请消息则原样返回）
    static func displayText(_ text: String) -> String {
        guard let link = link(in: text), let room = VoiceRoomService.roomCode(of: link) else { return text }
        var kept: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 只跳过「同一房间」的那一行链接；正文里其它行一律保留
            if let lineURL = self.link(in: trimmed),
               let lineRoom = VoiceRoomService.roomCode(of: lineURL),
               lineRoom == room {
                continue
            }
            kept.append(line)
        }
        let joined = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // 极端情况（正文只有链接）：宁可显示原文，也不要出现空气泡
        return joined.isEmpty ? text : joined
    }

    /// 按钮标题（按链接里的 `mode`：语音 / 视频；缺失按语音）
    static func buttonTitle(for link: URL) -> String {
        return VoiceRoomService.mode(of: link) == .video ? L("加入视频") : L("加入语音")
    }

    /// 气泡里**真正显示**的正文：去链接行 + **自己发的**把开头昵称换成「我」。
    ///
    /// 为什么在展示层换：消息正文是**同一条**发给所有人的，里面必须是**真实昵称**
    ///（否则别人收到的会看到「我 发起了语音」）；
    /// 而「我」这个称呼只对**发消息的人自己**成立 ⇒ 自己发的显示「我」，别人发的保持昵称原文
    ///（用户 2026-10-20 要求）。
    ///
    /// ⚠️ 正文开头昵称必须与 `VoiceRoomWebSupport.currentDisplayName()` 对得上才替换：
    ///    开着聊天改昵称时对不上 ⇒ 原样显示旧昵称（宁可不换，也不能错换别人的名字）。
    static func displayText(for message: Message) -> String {
        guard case .text(let text) = message.kind else { return "" }
        let base = displayText(text)
        guard message.isOutgoing else { return base }

        let name = VoiceRoomWebSupport.currentDisplayName()
        guard !name.isEmpty else { return base }

        // 群聊正文前面带「@所有人」标记（`AtChar + … + AtEndChar`），先摘下来再换名字。
        // ⚠️ 不要按 `L("所有人")` 去匹配：发消息的人和看消息的人语言可能不同
        //    （正文里写的是发送方语言的「所有人」），只认 `@…\u{2004}` 这层结构。
        var prefix = ""
        var body = base
        if body.hasPrefix(AtChar), let endRange = body.range(of: AtEndChar) {
            prefix = String(body[body.startIndex..<endRange.upperBound])
            body = String(body[endRange.upperBound...])
        }

        guard body.hasPrefix(name) else { return base }
        let rest = String(body.dropFirst(name.count))
        // 名字后面必须紧跟空格（邀请文案是 `%@ 发起了…`），否则可能是名字前缀相同的另一个人
        guard rest.isEmpty || rest.hasPrefix(" ") else { return base }
        return prefix + L("我") + rest
    }
}
