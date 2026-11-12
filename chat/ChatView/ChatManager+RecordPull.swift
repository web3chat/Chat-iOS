//
//  ChatManager+RecordPull.swift
//  chat
//
//  进入 App 后异步预取私聊聊天记录（服务端优先），不阻塞主线程。
//  文档：《获取私聊记录_App对接文档》
//

import Foundation
import UIKit
import Kingfisher
import WCDBSwift

extension ChatManager {

    /// 记录预取队列：串行 + 低优先级 —— 逐个会话拉取，避免大量并发请求拖慢 App。
    private static let recordPrefetchQueue = DispatchQueue(label: "chat.record.prefetch", qos: .utility)

    /// 单次预取的会话上限（按最近聊天时间倒序取前 N 个）。
    /// ⚠️ 原来是无上限全量拉：会话多时网络 + 落库会持续几十秒，
    ///    正好和用户刚进 App 的点击操作抢资源 ⇒ 点分段 / 进会话都会卡一下。
    /// 30 → 10（2026-10-09）：会话再多也只先补最近 10 个，其余进会话时按需拉
    /// （`ChatVC.pullLatestRecordsIfEmpty` / `loadMoreMsg`）。
    private static let recordPrefetchSessionLimit = 10

    /// 相邻两个会话之间的间隔：把请求 / 落库的节奏摊开，避免连续占用资源。
    /// 0.1 → 0.3（2026-10-09）：串行拉取时给主线程 / DB 留出空档，别一路占到底。
    private static let recordPrefetchInterval: TimeInterval = 0.3

    /// 单次最多补几张加密图片（2026-10-09）：
    /// 一个群会话可能有几百张图，全下会把预取队列占住好几分钟；
    /// 先补最近的若干张，剩下的等 cell 可见时按需加载（`loadEncryptedImage`）兜底。
    private static let maxImagePrefetchPerCall = 10

    /// 重建单个会话时的翻页参数：每页条数 / 最多翻多少页（防异常情况下无限翻页）。
    /// 每页 20 条与进会话时的「加载更多」保持一致（count 太大有被服务端拒绝的风险）。
    private static let recordRebuildPageSize = 20
    private static let recordRebuildMaxPages = 30

    /// 上一次预取的**账号**与时间（节流用；只在主线程读写）。
    /// `SessionManager.init()` 与登录成功通知都会走 `loadDBSessions()` ⇒ 同一账号 10 秒内只跑一次；
    /// **切换账号后账号变了 ⇒ 立刻重建一次**（新账号必须重新拉一遍自己的记录）。
    private static var lastPrefetchAccount: String = ""
    private static var lastPrefetchStartTime: TimeInterval = 0

    /// 登录 / 进入 App / 切换账号后**重建**私聊会话的本地聊天记录缓存。
    ///
    /// ⚠️ 每次都会跑（不是「只补新的」）：把本地缓存**按服务端为准**整体替换一遍 ——
    ///    这样「对方删除了记录」或「我这边删过」，重新进 App 就会与服务器一致，
    ///    不必依赖服务端下发删除信令（见 `replaceLocalRecords`）。
    /// 不阻塞主线程；逐会话串行拉取 → 解密 → 图片解密缓存 → 替换本地库。
    /// ⚠️ 这是「补数据」不是关键路径：调用方要等首屏渲染完再触发（见 `SessionManager.loadDBSessions()`）。
    func prefetchPrivateRecords() {
        guard LoginUser.shared().isLogin else { return }

        // 节流：同一账号 10 秒内只跑一次（init / 登录通知会连着触发两次）；换账号立即跑
        let account = LoginUser.shared().address
        let now = Date().timeIntervalSince1970
        if account == ChatManager.lastPrefetchAccount,
           now - ChatManager.lastPrefetchStartTime < 10 { return }
        ChatManager.lastPrefetchAccount = account
        ChatManager.lastPrefetchStartTime = now

        // 会话数组在主线程读写，这里先快照出 targetId 列表
        // 只取最近聊过的若干会话：新记录对用户最有用，老会话进会话翻页时按需再拉
        let targets = SessionManager.shared().allSessions
            .filter { $0.isPrivateChat }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(ChatManager.recordPrefetchSessionLimit)
            .map { $0.id.idValue }
        guard !targets.isEmpty else {
            FZMLog("重建私聊记录缓存：本地没有私聊会话，跳过")
            return
        }

        FZMLog("开始重建私聊记录缓存：\(targets.count) 个会话 account=\(account)")
        ChatManager.recordPrefetchQueue.async {
            for targetId in targets {
                self.rebuildRecords(for: targetId)
                // 每条之间让一下，别长时间连着占网络 / 数据库
                Thread.sleep(forTimeInterval: ChatManager.recordPrefetchInterval)
            }
            FZMLog("私聊记录缓存重建结束")
        }
    }

    /// 保存「服务端拉取」的消息：先把加密图片（$ENC$）后台下载解密缓存，再落库。
    /// 否则图片 cell 在缓存缺失时会用加密 URL 加载 → 白块。
    /// ⚠️ 落库**一律在后台队列**（`recordPrefetchQueue`）：写库本身线程安全，但在主线程
    ///    写十几条消息 + 同步虚表标记会直接挤掉用户当下的点击（2026-10-09 修）。
    ///    需要知道「已落库」时机的调用方用 `completion`（回调已回主线程）。
    func savePulledRecords(_ msgs: [Message], completion: (() -> Void)? = nil) {
        guard !msgs.isEmpty else {
            completion?()
            return
        }
        // 诊断：这条日志是查「删掉的消息又出现」的关键 —— 能看出是谁把服务端记录写回本地的
        FZMLog("【记录回写】服务端拉取→落库 \(msgs.count) 条 session=\(msgs.first?.targetId ?? "") msgIds=\(msgs.prefix(8).map { $0.msgId })")
        ChatManager.recordPrefetchQueue.async {
            // 加密图（$ENC$）后台下载解密（已在缓存里的会直接跳过）
            self.prefetchEncryptedImages(msgs)
            self.save(msgs)
            guard let completion = completion else { return }
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - 内部

    /// 重建单个会话的本地缓存：**拉全量**服务端记录 → 整体替换本地缓存。
    /// - Parameter maxPages: 最多翻几页（0 = 默认全量 30 页）；切账号补被删除的会话时只拉最近 1 页。
    /// ⚠️ 拉不到（请求失败）就整条跳过、本地缓存保持不动 —— 断网 / 接口报错时绝不能把缓存清空。
    @discardableResult
    func rebuildRecords(for targetId: String, maxPages: Int = 0) -> RecordRebuildResult {
        let pageLimit = maxPages > 0 ? maxPages : ChatManager.recordRebuildMaxPages
        let startedAt = Date.timestamp      // 毫秒；这之后新到的消息不能在重建时丢掉
        var allMsgs = [Message]()
        var cursor: String?
        var page = 0

        while page < pageLimit {
            page += 1
            guard let result = self.fetchRecordPage(targetId: targetId,
                                                    count: ChatManager.recordRebuildPageSize,
                                                    logId: cursor) else {
                FZMLog("重建私聊记录：请求失败，本次跳过 targetId=\(targetId)")
                return .requestFailed
            }
            // 第一页成功但服务端一条都没有 ⇒ 该会话在服务器已清空（对方删过），本地缓存也要清掉
            if page == 1, result.serverCount == 0 {
                self.replaceLocalRecords(sessionId: targetId, with: [], keepSince: startedAt)
                return .empty
            }
            allMsgs.append(contentsOf: result.msgs)
            // 这一页没满 / 拿不到更早的游标 ⇒ 已经没有更多了
            guard result.serverCount >= ChatManager.recordRebuildPageSize,
                  let oldest = result.minLogId else { break }
            if let cursorValue = cursor.flatMap({ Int($0) }), cursorValue <= oldest { break }  // 游标没前进，防死循环
            cursor = String(oldest)
        }

        guard !allMsgs.isEmpty else {
            FZMLog("重建私聊记录：解密后为空，本地缓存保持不动 targetId=\(targetId)")
            return .empty
        }
        // 加密图先解密进缓存，再替换落库（否则图片 cell 拿加密 URL 去解码 → 白块）
        self.prefetchEncryptedImages(allMsgs)
        self.replaceLocalRecords(sessionId: targetId, with: allMsgs, keepSince: startedAt)
        return .restored(allMsgs.count)
    }

    /// 拉取一页服务端记录（同步等回调；只在后台重建流程里调用）
    /// - Returns: nil = 请求失败；否则给出「服务端这一页的原始条数 / 解密后的消息 / 最小 logId」
    private func fetchRecordPage(targetId: String,
                                 count: Int,
                                 logId: String?) -> (serverCount: Int, msgs: [Message], minLogId: Int?)? {
        var serverCount = 0
        var msgs = [Message]()
        var minLogId: Int?
        var succeeded = false
        let semaphore = DispatchSemaphore(value: 0)

        PriChatRecordAPI.records(targetId: targetId, count: count, logId: logId, successBlock: { (json) in
            let arr = json["records"].array ?? []
            serverCount = arr.count
            minLogId = arr.compactMap { item -> Int? in
                if let i = item["logId"].int { return i }
                if let s = item["logId"].string { return Int(s) }
                return nil
            }.min()
            guard !arr.isEmpty else {
                succeeded = true
                semaphore.signal()
                return
            }
            Message.serverRecords(fromData: json, peerAddress: targetId) { (parsed) in
                msgs = parsed
                succeeded = true
                semaphore.signal()
            }
        }, failureBlock: { (error) in
            FZMLog("重建私聊记录：拉取失败 targetId=\(targetId) \(error.localizedDescription)")
            semaphore.signal()
        })

        semaphore.wait()
        guard succeeded else { return nil }
        return (serverCount, msgs, minLogId)
    }

    /// 用服务端记录**替换**某私聊会话的本地缓存（以服务端为准）。只在 `recordPrefetchQueue` 上调用。
    /// - `msgs` 为空 = 服务端该会话已无记录 ⇒ 本地缓存一起清掉
    /// - `keepSince`：重建开始时间（毫秒）。这两类本地消息必须保留：
    ///   ① 「发送中 / 发送失败」的消息（服务端还没有）；② 重建期间新到的 socket 消息。
    private func replaceLocalRecords(sessionId: String, with serverMsgs: [Message], keepSince: Int) {
        let localRows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.is(sessionId)
        }
        let localMsgs = localRows.compactMap { Message(with: $0) }

        // ⚠️ 服务端历史记录**不带 reference**，而这里是「先删本地 → 再 save」，等 `save()` 里的
        //    本地补全逻辑跑起来，行已经被删掉了 ⇒ 必须在删除**之前**把引用关系搬到服务端那批消息上。
        //    否则重进 App / 切换账号后，私聊里的引用条会全部消失（用户 2026-11-04 反馈）。
        var msgs = serverMsgs
        var localRefs: [String: Message.Reference] = [:]
        for msg in localMsgs {
            guard let ref = msg.reference, ref.ref > 0 else { continue }
            localRefs[msg.msgId] = ref
        }
        if !localRefs.isEmpty {
            var filled = 0
            for i in 0..<msgs.count where msgs[i].reference == nil {
                if let ref = localRefs[msgs[i].msgId] {
                    msgs[i].reference = ref
                    filled += 1
                }
            }
            FZMLog("【引用】重建记录时保留本地引用关系 \(filled)/\(localRefs.count) 条 session=\(sessionId)")
        }

        let keepMsgs = localMsgs.filter { msg in
            msg.status == .sending || msg.status == .failed || msg.datetime > keepSince
        }
        let keepIds = Set(keepMsgs.map { $0.msgId })
        let serverIds = Set(msgs.map { $0.msgId })
        // 真正从服务端消失的消息（既不在保留集、也不在服务端记录里）—— 通知聊天页从界面移除
        let removedMsgs = localMsgs.filter { !keepIds.contains($0.msgId) && !serverIds.contains($0.msgId) }

        // 清空本地缓存：只动消息表，**不碰会话表**、也不在「清空瞬间」重算会话预览
        //（否则会话会被当成「没有消息」的会话删掉）
        DBManager.shared().delete(fromTable: .message) { (constraint) in
            constraint.condition = MessageDB.Properties.sessionId.is(sessionId)
        }

        let newMsgs = msgs + keepMsgs
        if !newMsgs.isEmpty {
            self.save(newMsgs)
        }

        FZMLog("私聊记录缓存重建：sessionId=\(sessionId) 服务端=\(msgs.count) 保留本地=\(keepMsgs.count) 清掉=\(removedMsgs.count)")
        FZMLog("【记录回写】重建写入 session=\(sessionId) msgIds=\(newMsgs.prefix(8).map { $0.msgId })")

        DispatchQueue.main.async {
            let session = SessionManager.shared().getSingleLocalSession(by: SessionID.person(sessionId))
            if !removedMsgs.isEmpty, let session = session {
                // 正在查看该会话时，让聊天页把消失的消息从界面上摘掉
                FZM_NotificationCenter.post(name: FZM_Notify_DeleteChatMsgs, object: (session.id, removedMsgs))
            }
            // 刷新会话预览（列表里的「最后一条」要与聊天页一致）
            if let session = session {
                SessionManager.shared().refreshLastMsgInfo(session: session)
            }
        }
    }

    /// 补齐某会话本地图片消息的解密缓存（**进入会话时调用**）。
    /// 清缓存后无需滑动列表：后台重下 + 解密，完成后回调新缓存数量，调用方可刷新列表。
    func reloadMissingImageCache(sessionId: String, completion: ((Int) -> Void)? = nil) {
        ChatManager.recordPrefetchQueue.async {
            // ⚠️ 不在 SQL 里拼 `&& msgType == 3`：WCDB 表达式在这里推断失败
            //    （报 Cannot convert value of type 'Expression' to expected argument type 'Bool'）。
            //    改为「先按会话读、再用 Swift 过滤」——最贵的一步（构造 `Message`）仍然只对图片消息做。
            let imageMsgType = 3   // 3 = 图片（见 `Message.MsgType` 各 case 行尾注释）
            let dbMsgs: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { (constraint) in
                constraint.condition = MessageDB.Properties.sessionId.is(sessionId)
                // 最近的图片优先补（配合 `maxImagePrefetchPerCall` 上限，老图不无限下）
                constraint.orderBy = [MessageDB.Properties.datetime.asOrder(by: .descending)]
            }
            let msgs = dbMsgs.filter { $0.msgType == imageMsgType }.compactMap { Message(with: $0) }
            guard !msgs.isEmpty else {
                DispatchQueue.main.async { completion?(0) }
                return
            }
            // 统计「缓存缺失」的图片数量（含非加密图：调用方重刷列表 → cell 重新加载）
            let missingCount = msgs.filter { msg in
                guard let key = msg.msgType.mediaCachekey, !key.isEmpty else { return true }
                return !ChatMediaCache.isCached(forKey: key)
            }.count
            // 加密图（$ENC$）后台重下 + 解密 + 回填缓存
            self.prefetchEncryptedImages(msgs)
            DispatchQueue.main.async { completion?(missingCount) }
        }
    }

    /// 历史图片（$ENC$）：后台下载 + 解密 + 按消息自带 cacheKey 缓存（与 socket 收图同款加密处理）
    /// - Parameter limit: 单次最多处理几张（默认 `maxImagePrefetchPerCall`），防止一个会话几百张图把队列占死
    /// - Returns: 本次新写入缓存的数量
    @discardableResult
    private func prefetchEncryptedImages(_ msgs: [Message], limit: Int = ChatManager.maxImagePrefetchPerCall) -> Int {
        var cachedCount = 0
        var attempted = 0
        for msg in msgs {
            // 到上限就停：剩下的交给 cell 可见时按需加载（`loadEncryptedImage`）
            guard attempted < limit else { break }
            guard case .image = msg.msgType,
                  let urlStr = msg.msgType.url, urlStr.contains(encryptFlgStr),
                  let cacheKey = msg.msgType.mediaCachekey, !cacheKey.isEmpty,
                  !ChatMediaCache.isCached(forKey: cacheKey),
                  let url = URL(string: urlStr) else { continue }

            attempted += 1
            // ⚠️ 必须区分私聊 / 群聊：群图片是用**群密钥**加的密（`isGetUserKey: false` +
            //    `isEncryptPersionChatData: false`）。按私聊那套取对端公钥解会解不开 ⇒ 缩略图白块。
            let isPersonChat = msg.sessionId.isPersonChat
            let address = isPersonChat
                ? (msg.fromId == LoginUser.shared().address ? msg.targetId : msg.fromId)
                : msg.targetId
            let semaphore = DispatchSemaphore(value: 0)
            ChatManager.getPublickey(by: address, isGetUserKey: isPersonChat) { (publickey) in
                defer { semaphore.signal() }
                // ⚠️ 用 URLSession（带超时）而不是 `Data(contentsOf:)`：后者没有超时，
                //    断网 / 慢网时会把调用线程按住很久（2026-10-09 改）。
                guard let raw = ChatManager.fetchImageData(from: url) else { return }
                // 按加密数据解密（与大图 / 实时收图同款）；解不出再用原始数据兜底
                var image: UIImage?
                var cacheData: Data?
                if !publickey.isBlank {
                    let dec = ChatManager.decryptUploadData(raw, publickey: publickey, isEncryptPersionChatData: isPersonChat)
                    if dec.count > 0 {
                        image = UIImage.safeDecodedImage(data: dec, maxPixelSize: 2048)
                        cacheData = dec
                    }
                }
                if image == nil {
                    image = UIImage.safeDecodedImage(data: raw, maxPixelSize: 2048)
                    cacheData = raw
                }
                guard let image = image else {
                    FZMLog("历史图片解密失败 cacheKey=\(cacheKey) isPersonChat=\(isPersonChat) publickeyLen=\(publickey.count) 原始=\(raw.count)B url=\(urlStr)")
                    return
                }
                // 省图模式：存原始压缩字节（而不是让 Kingfisher 把解码后的 2048px 图重新编码写盘）
                if FZM_EnableImageSaveMode {
                    ChatMediaCache.store(image, original: cacheData, forKey: cacheKey)
                } else {
                    ChatMediaCache.store(image, forKey: cacheKey)
                }
                cachedCount += 1
                FZMLog("历史图片解密缓存成功 cacheKey=\(cacheKey)")
            }
            semaphore.wait()
        }
        return cachedCount
    }

    /// 异步下载单张图片的同步封装（URLSession + 超时），替代无超时的 `Data(contentsOf:)`。
    /// ⚠️ 只在后台队列上调用（内部 `semaphore.wait()`）。
    static func fetchImageData(from url: URL, timeout: TimeInterval = 15) -> Data? {
        var result: Data?
        let semaphore = DispatchSemaphore(value: 0)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        let session = URLSession(configuration: configuration)
        session.dataTask(with: url) { (data, _, _) in
            result = data
            semaphore.signal()
        }.resume()
        semaphore.wait()
        session.finishTasksAndInvalidate()
        return result
    }

    /// 按需加载加密图片（$ENC$）：命中缓存直接回；否则下载 + 解密 + 存缓存（后台），主线程回调。
    /// ⚠️ 图片 cell 在缓存缺失时会把**加密 URL** 交给 Kingfisher → 解码失败 → 白块，
    ///    所以加密图片必须走这里（与实时收图同款加解密）。
    func loadEncryptedImage(for msg: Message, completion: @escaping (UIImage?) -> Void) {
        guard case .image = msg.msgType,
              let urlStr = msg.msgType.url,
              let cacheKey = msg.msgType.mediaCachekey, !cacheKey.isEmpty else {
            completion(nil)
            return
        }
        ChatMediaCache.safeRetrieveImage(forKey: cacheKey) { [weak self] image in
            if let image = image {
                completion(image)
                return
            }
            guard urlStr.contains(encryptFlgStr), let url = URL(string: urlStr) else {
                completion(nil)
                return
            }
            // ⚠️ 必须区分私聊 / 群聊：群图片是用**群密钥**加的密（`isGetUserKey: false` +
            //    `isEncryptPersionChatData: false`）。之前写死私聊那套，导致**群聊图片缩略图全白块**
            //    （点开大图能看到是另一条下载/解密路径，走对了）。
            let isPersonChat = msg.sessionId.isPersonChat
            let address = isPersonChat
                ? (msg.fromId == LoginUser.shared().address ? msg.targetId : msg.fromId)
                : msg.targetId
            // ⚠️ 群密钥必须知道「群在哪台服务器」：不传会退成空地址，永远拿不到密钥
            //    ⇒ 群图片解密失败、气泡白块。优先用本地会话记下的服务器。
            let chatServerUrl = SessionManager.shared().getSingleLocalSession(by: msg.sessionId)?.chatServerUrl ?? ""
            ChatManager.getPublickey(by: address, isGetUserKey: isPersonChat, chatServerUrl: chatServerUrl) { (publickey) in
                DispatchQueue.global(qos: .userInitiated).async {
                    var image: UIImage?
                    var cacheData: Data?
                    let rawData = ChatManager.fetchImageData(from: url)
                    if let raw = rawData {
                        // 按加密数据解密（与大图 / 实时收图同款）；解不出再用原始数据兜底
                        if !publickey.isBlank {
                            let dec = ChatManager.decryptUploadData(raw, publickey: publickey, isEncryptPersionChatData: isPersonChat)
                            if dec.count > 0 {
                                image = UIImage.safeDecodedImage(data: dec, maxPixelSize: 2048)
                                cacheData = dec
                            }
                        }
                        if image == nil {
                            image = UIImage.safeDecodedImage(data: raw, maxPixelSize: 2048)
                            cacheData = raw
                        }
                    }
                    if let image = image {
                        // 省图模式：存原始压缩字节，避免 Kingfisher 把解码后的图重新编码成大文件
                        if FZM_EnableImageSaveMode {
                            ChatMediaCache.store(image, original: cacheData, forKey: cacheKey)
                        } else {
                            ChatMediaCache.store(image, forKey: cacheKey)
                        }
                    } else {
                        FZMLog("加密图片解密失败 cacheKey=\(cacheKey) isPersonChat=\(isPersonChat) publickeyLen=\(publickey.count) 原始=\(rawData?.count ?? -1)B url=\(urlStr)")
                    }
                    DispatchQueue.main.async { completion(image) }
                }
            }
        }
    }
}

// MARK: - 重装 / 换机后的私聊记录恢复

/// 单个会话重建的结果
enum RecordRebuildResult {
    /// 成功重建：写入的条数（服务端记录 + 保留的本地在途消息）
    case restored(Int)
    /// 服务端没有该会话的记录（本地缓存已同步清空）
    case empty
    /// 请求失败：本地缓存保持不动，调用方可以稍后重试
    case requestFailed
}

/// 一次恢复的汇总（用于回执 / 日志）
struct PrivateRecordRecoverSummary {
    var totalTargets = 0
    var restoredSessions = 0
    var restoredMessages = 0
    var failedSessions = 0
    /// 恢复途中切了账号 ⇒ 后面的会话不再拉
    var cancelled = false
}

extension ChatManager {

    /// 相邻两个会话之间恢复的间隔（比日常预取略短，但同样要给主线程 / DB 留空档）
    private static let recordRecoverInterval: TimeInterval = 0.2

    /// 恢复任务是否在跑（只在主线程读写，防止手动入口连点 / 与自动恢复并发）
    private static var isRecoveringPrivateRecords = false

    /// 「补被删除会话」任务是否在跑（切账号 / 回前台共用，防止重复执行）
    private static var isRecoveringMissingSessions = false

    /// 自动恢复等待好友列表的重试次数（好友列表是从合约异步拉的）
    private static var autoRecoverRetryCount = 0
    private static let autoRecoverRetryLimit = 12
    private static let autoRecoverRetryDelay: TimeInterval = 10

    /// 「这个账号在本机已自动恢复过一次」的标记 key。
    /// ⚠️ 用 UserDefaults：重装 / 换机后它也会被清零 —— 正好就是我们要触发恢复的时机。
    private static func autoRecoveredKey(account: String) -> String {
        return "chat.recover.privateRecords.done.\(account)"
    }

    /// 重装 / 换机后**自动**恢复一次私聊历史（登录后延迟调用，见 `SessionManager.loadDBSessions()`）。
    ///
    /// 只在本机「一条私聊会话都没有」时跑；每个账号在本机只跑一次，之后由日常预取维护，
    /// 避免用户主动删光会话后又被自动补回来。
    func autoRecoverPrivateRecordsIfFreshInstall() {
        guard LoginUser.shared().isLogin else { return }
        let account = LoginUser.shared().address
        guard !account.isEmpty else { return }
        let key = ChatManager.autoRecoveredKey(account: account)
        guard !FZM_UserDefaults.bool(forKey: key) else { return }

        // 本地还有私聊会话 ⇒ 不是重装后的第一次启动（或上次已经恢复过）⇒ 标记后不再自动跑
        if SessionManager.shared().allSessions.contains(where: { $0.isPrivateChat }) {
            FZM_UserDefaults.set(true, forKey: key)
            return
        }
        // 好友列表是从合约异步拉的：还没就绪就过一会儿再试（最多 12 次 × 10s）
        guard !ChatManager.recoverTargets().isEmpty else {
            guard ChatManager.autoRecoverRetryCount < ChatManager.autoRecoverRetryLimit else {
                FZMLog("自动恢复私聊记录：好友列表一直为空，本次放弃（下次启动再试）")
                ChatManager.autoRecoverRetryCount = 0
                return
            }
            ChatManager.autoRecoverRetryCount += 1
            FZMLog("自动恢复私聊记录：好友列表还没就绪，\(Int(ChatManager.autoRecoverRetryDelay))s 后重试（第 \(ChatManager.autoRecoverRetryCount) 次）")
            DispatchQueue.main.asyncAfter(deadline: .now() + ChatManager.autoRecoverRetryDelay) { [weak self] in
                self?.autoRecoverPrivateRecordsIfFreshInstall()
            }
            return
        }
        ChatManager.autoRecoverRetryCount = 0
        FZMLog("自动恢复私聊记录：检测到本机没有私聊会话，开始恢复 account=\(account)")
        recoverPrivateRecordsFromServer { (summary) in
            // 只有「一轮全成功」才写标记：断网 / 接口报错时下次启动继续补
            guard !summary.cancelled, summary.totalTargets > 0, summary.failedSessions == 0 else {
                FZMLog("自动恢复私聊记录：本轮未完成（失败=\(summary.failedSessions) 取消=\(summary.cancelled)），下次启动重试")
                return
            }
            FZM_UserDefaults.set(true, forKey: key)
        }
    }

    /// **从服务端恢复私聊聊天记录**（手动入口 / 自动恢复共用）。
    ///
    /// 逐个 target 拉全量记录 → 解密 → 落库 → 补建会话行，会话列表和历史消息一起长回来。
    /// - 后台串行执行，不阻塞主线程；每拉完一个回主线程报一次进度。
    /// - 切账号立刻中止（旧账号的记录不能写进新账号的库）。
    /// - ⚠️ 群聊历史没有服务端接口，这里不处理。
    func recoverPrivateRecordsFromServer(progress: ((_ finished: Int, _ total: Int) -> Void)? = nil,
                                         completion: ((PrivateRecordRecoverSummary) -> Void)? = nil) {
        let account = LoginUser.shared().address
        let targets = ChatManager.recoverTargets()
        var summary = PrivateRecordRecoverSummary()
        summary.totalTargets = targets.count

        guard LoginUser.shared().isLogin, !account.isEmpty, !targets.isEmpty else {
            completion?(summary)
            return
        }
        guard !ChatManager.isRecoveringPrivateRecords else {
            FZMLog("恢复私聊记录：已有任务在跑，忽略本次请求")
            completion?(summary)
            return
        }
        ChatManager.isRecoveringPrivateRecords = true
        FZMLog("恢复私聊记录开始：\(targets.count) 个会话 account=\(account)")

        ChatManager.recordPrefetchQueue.async {
            var result = summary
            for (index, targetId) in targets.enumerated() {
                if LoginUser.shared().address != account {
                    result.cancelled = true
                    FZMLog("恢复私聊记录：账号已切换，中止")
                    break
                }
                switch self.rebuildRecords(for: targetId) {
                case .restored(let count):
                    result.restoredSessions += 1
                    result.restoredMessages += count
                    // 记录落了库但会话行不存在时，会话列表里依然看不到 —— 这里补建
                    self.ensurePrivateSession(targetId: targetId)
                case .empty:
                    break
                case .requestFailed:
                    result.failedSessions += 1
                }
                let finished = index + 1
                DispatchQueue.main.async { progress?(finished, targets.count) }
                Thread.sleep(forTimeInterval: ChatManager.recordRecoverInterval)
            }
            DispatchQueue.main.async {
                ChatManager.isRecoveringPrivateRecords = false
                FZMLog("恢复私聊记录结束：会话=\(result.restoredSessions) 消息=\(result.restoredMessages) 失败=\(result.failedSessions) 取消=\(result.cancelled)")
                completion?(result)
            }
        }
    }

    /// 恢复用的 targetId 列表（**只在主线程调用**）：
    /// ① 本地已有的私聊会话（手动「再恢复一次」时把它们整体重拉一遍）；
    /// ② 好友列表（`UserDB.isFriend`）—— 重装后本地没有会话，这是唯一能拿到「和谁聊过」的线索。
    /// ⚠️ 群聊不在这里：服务端没有群聊历史接口，恢复不了。
    static func recoverTargets() -> [String] {
        let selfAddress = LoginUser.shared().address
        var ids = Set<String>()

        SessionManager.shared().allSessions.forEach { (session) in
            guard session.isPrivateChat, session.id.idValue != selfAddress else { return }
            ids.insert(session.id.idValue)
        }

        let friendRows: [UserDB] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition = UserDB.Properties.isFriend == true && UserDB.Properties.isShield == false
        }
        for row in friendRows {
            let address = row.address
            guard !address.isEmpty, address != selfAddress else { continue }
            ids.insert(address)
        }
        return Array(ids)
    }

    /// 拉回记录后补建会话行：会话列表只读本地 `SessionDB`，
    /// 只有消息没有会话行的话，用户在列表里仍然看不到这个会话。
    /// `refreshLastMsgInfo` 会按库里最新一条消息生成预览（没有消息时会删会话，这里已由调用方保证有消息）。
    private func ensurePrivateSession(targetId: String) {
        DispatchQueue.main.async {
            let id = SessionID.person(targetId)
            guard SessionManager.shared().getSingleLocalSession(by: id) == nil else { return }
            let session = SessionManager.shared().getOrCreateSession(id: id)
            SessionManager.shared().refreshLastMsgInfo(session: session)
            FZMLog("恢复私聊记录：补建会话 targetId=\(targetId)")
        }
    }

    /// 切换账号成功后的补拉（用户 2026-11-12）。
    ///
    /// 场景：A 删掉 B 的会话 → 切到 B 给 A 发消息 → 再切回 A：
    /// A 本地没有 B 的会话行，`prefetchPrivateRecords()` 只遍历**已有会话** ⇒ 永远拉不到 B 的记录；
    /// 群聊又没有服务端历史接口，只能靠 socket 的离线队列。
    /// 这里做两件事：
    /// 1. 稍等新账号 socket 鉴权（1s；没赶上也没关系，鉴权成功后会自己跑 syncMsg），重启私聊/群聊的离线队列同步；
    /// 2. 对「好友列表里有、本地没有私聊会话」的人补会话：
    ///    本地还有消息（只删了会话行）→ 直接用库里最新一条补会话；
    ///    本地没有消息 → 拉**最近一页**服务端记录，再补会话。
    ///
    /// ⚠️ 群聊没有服务端历史接口，只能重跑离线队列；已经 ack 掉的群消息补不回来。
    func syncAfterAccountSwitch() {
        guard LoginUser.shared().isLogin else { return }
        let account = LoginUser.shared().address
        guard !account.isEmpty else { return }

        // 1) socket 离线队列：新账号的连接鉴权需要一点时间
        //    1s 还没鉴权也没关系：socket 鉴权成功后会自己跑一轮 syncMsg，这里只是提前补一次
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard LoginUser.shared().address == account else { return }
            MultipleSocketManager.shared().restartAllOfflineSync()
            FZMLog("切账号补拉：重启离线同步 account=\(account)")
        }

        // 2) 被删除的私聊会话：好友里有、本地没有会话行
        recoverMissingPrivateSessions()
    }

    /// App 从后台回到前台时补一次：
    /// - socket 离线队列（私聊 + 群聊，群聊没有历史接口，只能靠这个）；
    /// - 最近会话的私聊历史（`prefetchPrivateRecords`，自带同账号 10s 节流）；
    /// - 被删除会话的恢复（好友里有、本地没有会话行，通常为空，开销很小）。
    func syncHistoryOnForeground() {
        guard LoginUser.shared().isLogin else { return }
        MultipleSocketManager.shared().restartAllOfflineSync()
        prefetchPrivateRecords()
        recoverMissingPrivateSessions()
    }

    /// 补「好友里有、本地没有会话行」的私聊会话（被删除的会话）。切账号 / 回前台共用。
    private func recoverMissingPrivateSessions() {
        guard LoginUser.shared().isLogin else { return }
        let account = LoginUser.shared().address
        guard !account.isEmpty else { return }
        guard !ChatManager.isRecoveringMissingSessions else {
            FZMLog("补缺失会话：已有任务在跑，忽略本次")
            return
        }
        let sessionIds = Set(SessionManager.shared().allSessions
            .filter { $0.isPrivateChat }
            .map { $0.id.idValue })
        let friendRows: [UserDB] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition = UserDB.Properties.isFriend == true && UserDB.Properties.isShield == false
        }
        let targets = friendRows
            .map { $0.address }
            .filter { !$0.isEmpty && $0 != account && !sessionIds.contains($0) }
        guard !targets.isEmpty else {
            FZMLog("补缺失会话：没有需要恢复的私聊会话")
            return
        }

        ChatManager.isRecoveringMissingSessions = true
        FZMLog("补缺失会话：开始恢复 \(targets.count) 个 account=\(account)")
        ChatManager.recordPrefetchQueue.async {
            for targetId in targets {
                if LoginUser.shared().address != account {
                    FZMLog("补缺失会话：账号已切换，中止")
                    break
                }
                if self.getLatestLogId(sessionId: targetId) > 0 {
                    // 消息还在、只是会话行被删了：不拉服务端，直接补会话
                    self.ensurePrivateSession(targetId: targetId)
                } else {
                    switch self.rebuildRecords(for: targetId, maxPages: 1) {
                    case .restored:
                        self.ensurePrivateSession(targetId: targetId)
                    case .empty, .requestFailed:
                        break
                    }
                }
                Thread.sleep(forTimeInterval: ChatManager.recordPrefetchInterval)
            }
            DispatchQueue.main.async {
                ChatManager.isRecoveringMissingSessions = false
                FZMLog("补缺失会话：结束 account=\(account)")
            }
        }
    }
}
