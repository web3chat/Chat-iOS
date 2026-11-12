//
//  FZMStorageManager.swift
//  chat
//
//  「存储空间」的统计与清理（设置中心 → 存储空间）
//
//  设计要点：
//  1. **消息表驱动**：媒体文件按 cacheKey 命名（`Video/{cacheKey}.MOV`、`File/{cacheKey}/`、
//     `Voice/WavFile/{cacheKey}.wav`），图片走 Kingfisher（key 就是 cacheKey）⇒ 从 message 表
//     反查比遍历目录更准。
//  2. **绝不构造 `Message`**：`Message.init(with:)` 会解析整段 JSON 并创建 NSAttributedString/UIFont，
//     几万条扫下来既慢又容易在后台线程碰 UIKit。这里只读 `MessageDB` 的字符串字段。
//  3. **图片是双 key**：`MediaMessageCell` 显示时用了
//     `[.processor(DownsamplingImageProcessor(size: 150*scale)), .cacheOriginalImage]`
//     ⇒ 磁盘上「原图（cacheKey）+ 降采样图（cacheKey+processorIdentifier）」两份，统计和清理都要带。
//  4. 所有 IO 都在私有串行队列上跑，结果回主线程。
//

import UIKit
import Kingfisher
import SDWebImage
import WCDBSwift

// MARK: - 模型

/// 单个会话的本地占用（对应「存储空间 → 聊天记录」里的一行）
struct FZMChatStorageItem {
    let sessionId: String
    let isGroup: Bool

    var msgCount: Int = 0
    /// 消息体（JSON）在数据库里的大致字节数
    var textBytes: Int64 = 0
    var imageBytes: Int64 = 0
    var videoBytes: Int64 = 0
    var fileBytes: Int64 = 0
    var voiceBytes: Int64 = 0

    var mediaBytes: Int64 { imageBytes + videoBytes + fileBytes + voiceBytes }
    var totalBytes: Int64 { textBytes + mediaBytes }

    var sessionID: SessionID { isGroup ? .group(sessionId) : .person(sessionId) }
}

/// 未关联媒体：没有被任何消息 `cacheKey` 引用、且超过 30 天的本地文件（可清理）
struct FZMOrphanMedia {
    var imageBytes: Int64 = 0
    var videoBytes: Int64 = 0
    var fileBytes: Int64 = 0
    var voiceBytes: Int64 = 0

    var totalBytes: Int64 { imageBytes + videoBytes + fileBytes + voiceBytes }
    var isEmpty: Bool { totalBytes == 0 }
}

/// 存储空间总览
struct FZMStorageBreakdown {
    /// 聊天记录：按消息归属（各会话消息体 + 被引用的媒体），与详情页各会话之和一致
    var chatBytes: Int64 = 0
    /// 可清理的缓存：Documents/Tmp、Library/Caches、头像缩略图、系统 tmp
    var cacheBytes: Int64 = 0
    /// App 必要文件：钱包库、UserDefaults、WebKit 数据、数据库页/索引等（不可清，只展示）
    var otherBytes: Int64 = 0

    var totalBytes: Int64 { chatBytes + cacheBytes + otherBytes }
}

/// 缓存明细（「存储空间 → 缓存」页）
struct FZMStorageCacheDetail {
    /// 图片缓存：Kingfisher（消息图片/视频封面/头像/广场图）+ SDWebImage（广场大图）
    var imageBytes: Int64 = 0
    /// 其它缓存：Documents/Tmp、Library/Caches、头像缩略图、系统 tmp
    var otherBytes: Int64 = 0

    var totalBytes: Int64 { imageBytes + otherBytes }
}

// MARK: - 管理器

final class FZMStorageManager {

    static let shared = FZMStorageManager()
    private init() {}

    /// 所有磁盘扫描/删除都在这条串行队列上，避免与 UI 抢主线程
    private let workQueue = DispatchQueue(label: "com.fzm.storage.scan", qos: .utility)

    /// 聊天图缩略图（`MediaMessageCell` 的 Downsampling 尺寸）。
    /// 统计与清理都要带上它，否则 `.cacheOriginalImage` 留下的降采样副本会成为"清不掉的占用"。
    private static let thumbnailProcessorIdentifier: String = {
        let scale = UIScreen.main.scale
        return DownsamplingImageProcessor(size: CGSize(width: 150 * scale, height: 150 * scale)).identifier
    }()

    // MARK: - 路径

    private func documentPath(_ sub: String) -> String { DocumentPath + sub }

    private var cachesRootPath: String { NSHomeDirectory() + "/Library/Caches" }

    private var avatarThumbnailPath: String { NSHomeDirectory() + "/Library/Application Support/AvatarThumbnails" }

    // MARK: - 文案

    /// 与系统「关于本机 → 存储」一致的大小文案
    static func sizeText(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - 总览

    /// 存储空间总览（聊天记录 / 缓存 / 其它）
    func loadSummary(completion: @escaping (FZMStorageBreakdown) -> Void) {
        var finished = false

        workQueue.async {
            var breakdown = FZMStorageBreakdown()

            // 1) 聊天记录：**按消息归属**统计（各会话内容 + 引用媒体），
            //    这样上级「聊天记录」与详情页各会话之和一致（X = Y）。
            //    数据库页/索引、未被引用的孤儿媒体都归到「App 必要文件」。
            let chatItems = self.buildChatStorageItems()
            breakdown.chatBytes = chatItems.reduce(Int64(0)) { $0 + $1.totalBytes }

            // 2) 缓存：按目录归属算，避免同一目录被加两次
            //    `ImageCache.default` 的 cachePathBlock 不一定生效：如果它实际还在 Library/Caches 里，
            //    直接 `cachesBytes + imageBytes` 就会把整个 Caches 算两遍（真机上会导致 App 必要文件变成 0）。
            let cachesRoot = self.cachesRootPath
            let cachesBytes = Self.directorySize(cachesRoot)
            let imageDir = self.kingfisherCacheDirectory(ImageCache.default)
            let imageBytes = Self.directorySize(imageDir)
            let chatMediaDir = self.kingfisherCacheDirectory(ChatMediaCache)
            let chatMediaBytes = Self.directorySize(chatMediaDir)
            let tmpDocBytes = Self.directorySize(self.documentPath("Tmp"))
            let avatarBytes = Self.directorySize(self.avatarThumbnailPath)
            let systemTmpBytes = Self.directorySize(NSTemporaryDirectory())

            var cacheBytes = tmpDocBytes + cachesBytes + avatarBytes + systemTmpBytes
            if !Self.isUnder(imageDir, cachesRoot) {
                cacheBytes += imageBytes
            }
            // 聊天图片属于「聊天记录」：如果它们落在 Caches 里，从缓存里扣掉，避免和 chatBytes 重复
            if Self.isUnder(chatMediaDir, cachesRoot) {
                cacheBytes -= chatMediaBytes
            }
            breakdown.cacheBytes = max(0, cacheBytes)

            // 3) App 必要文件 = 整个沙盒 - 聊天记录 - 缓存（数据库页/索引、钱包库、UserDefaults、WebKit…）
            let sandboxBytes = Self.directorySize(NSHomeDirectory())
            breakdown.otherBytes = max(0, sandboxBytes - breakdown.chatBytes - breakdown.cacheBytes)
            FZMLog("存储统计：sandbox=\(sandboxBytes) chat=\(breakdown.chatBytes) cache=\(breakdown.cacheBytes) other=\(breakdown.otherBytes)")
            FZMLog("存储明细：caches=\(cachesBytes) imageDir=\(imageDir) image=\(imageBytes) chatDir=\(chatMediaDir) chat=\(chatMediaBytes) tmpDoc=\(tmpDocBytes) avatar=\(avatarBytes) systemTmp=\(systemTmpBytes)")

            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                completion(breakdown)
            }
        }

        // 兜底：30 秒还没算完也回调一次，避免第一次进来一直是「正在计算…」
        // （现在总览要扫 message 表算「聊天记录=各会话之和」，大账号会比以前慢）
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            guard !finished else { return }
            finished = true
            completion(FZMStorageBreakdown())
        }
    }

    /// 缓存明细（图片缓存 + 其它缓存）
    func loadCacheDetail(completion: @escaping (FZMStorageCacheDetail) -> Void) {
        var finished = false

        workQueue.async {
            var detail = FZMStorageCacheDetail()

            // SDWebImage 的磁盘目录在 Library/Caches 里，单独算。
            // ⚠️ 不要用 `imageCache.getSize()`：它内部 `dispatch_sync` 到 SDWebImage 自己的 ioQueue，
            //    清理任务排队时会把统计线程一起堵住（表现为「缓存页一直转圈 / 数字出不来」）。
            let sdBytes = Self.sdWebImageDiskSize()
            let imageDir = self.kingfisherCacheDirectory(ImageCache.default)
            let imageBytes = Self.directorySize(imageDir)
            detail.imageBytes = imageBytes + sdBytes

            // 其它缓存：Documents/Tmp、Library/Caches（扣掉已算进图片缓存的 SDWebImage / Kingfisher 目录）、
            //          聊天图片目录（属于聊天记录）、头像缩略图、系统 tmp
            let cachesTotal = Self.directorySize(self.cachesRootPath)
            var otherCaches = cachesTotal - sdBytes
            if Self.isUnder(imageDir, self.cachesRootPath) {
                otherCaches -= imageBytes
            }
            let chatMediaDir = self.kingfisherCacheDirectory(ChatMediaCache)
            if Self.isUnder(chatMediaDir, self.cachesRootPath) {
                otherCaches -= Self.directorySize(chatMediaDir)
            }
            detail.otherBytes = Self.directorySize(self.documentPath("Tmp"))
                                + max(0, otherCaches)
                                + Self.directorySize(self.avatarThumbnailPath)
                                + Self.directorySize(NSTemporaryDirectory())

            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                completion(detail)
            }
        }

        // 兜底：10 秒还没算完也回调一次，避免 HUD 常驻、页面像卡死
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            guard !finished else { return }
            finished = true
            completion(FZMStorageCacheDetail())
        }
    }

    // MARK: - 按会话统计

    /// 扫描 message 表，按会话聚合本地占用。
    /// - Parameter progress: 已扫描的消息条数（主线程回调）
    func loadChatStorage(progress: ((Int) -> Void)? = nil,
                         completion: @escaping ([FZMChatStorageItem]) -> Void) {
        workQueue.async {
            let list = self.buildChatStorageItems(progress: progress)
            DispatchQueue.main.async { completion(list) }
        }
    }

    /// 同步扫描 message 表（调用方保证在 workQueue 上）。
    /// `loadSummary` 也用它算「聊天记录」，保证上级与详情页 X = Y。
    private func buildChatStorageItems(progress: ((Int) -> Void)? = nil) -> [FZMChatStorageItem] {
        var items: [String: FZMChatStorageItem] = [:]
        /// 同一个媒体文件可能被多条消息引用（转发 / 多会话），按 cacheKey 只计一次，
        /// 否则各会话之和会把「聊天记录」算得比真实磁盘还大（App 必要文件就会被挤成 0）
        var countedMediaKeys = Set<String>()
        var cursorDatetime = Int.max
        var cursorLogId = Int.max
        let pageSize = 300
        var scanned = 0

        while true {
            let conditionDatetime = cursorDatetime
            let conditionLogId = cursorLogId

            let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
                // 首页（cursor 仍是最大值）不加时间条件
                if conditionDatetime != Int.max {
                    // 与 getHistoryMsgs 同款 (datetime, logId) 复合游标：
                    // 只用 datetime < 会漏掉同一毫秒的多条消息
                    // ⚠️ 每个子条件必须显式标注为 WCDBSwift.Expression，否则 `||` / `&&` / `<`
                    //    会被 Swift 解析成标准库的 Bool / BinaryInteger 版本（实测编译报错）
                    let datetimeCondition: WCDBSwift.Expression = MessageDB.Properties.datetime < conditionDatetime
                    let sameDatetimeCondition: WCDBSwift.Expression = MessageDB.Properties.datetime == conditionDatetime
                    let logIdCondition: WCDBSwift.Expression = MessageDB.Properties.logId < conditionLogId
                    constraint.condition = datetimeCondition || (sameDatetimeCondition && logIdCondition)
                }
                constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending),
                                      MessageDB.CodingKeys.logId.asOrder(by: .descending)]
                constraint.limit = pageSize
            }

            if rows.isEmpty { break }

            for row in rows {
                var item = items[row.sessionId]
                    ?? FZMChatStorageItem(sessionId: row.sessionId, isGroup: row.channelType == 1)
                item.msgCount += 1
                item.textBytes += Int64(row.msg.utf8.count)

                if let cacheKey = Self.cacheKey(inJSON: row.msg), !cacheKey.isEmpty {
                    guard !countedMediaKeys.contains(cacheKey) else {
                        items[row.sessionId] = item
                        continue
                    }
                    countedMediaKeys.insert(cacheKey)
                    switch row.msgType {
                    case 2: // 音频
                        item.voiceBytes += Self.fileSize(self.documentPath("Voice/WavFile/\(cacheKey).wav"))
                                        + Self.fileSize(self.documentPath("Voice/AmrFile/\(cacheKey).amr"))
                    case 3: // 图片
                        item.imageBytes += self.imageCacheSize(forKey: cacheKey)
                    case 4: // 视频
                        item.videoBytes += Self.fileSize(self.documentPath("Video/\(cacheKey).MOV"))
                    case 5: // 文件
                        item.fileBytes += Self.directorySize(self.documentPath("File/\(cacheKey)"))
                    default:
                        break
                    }
                }
                items[row.sessionId] = item
            }

            guard let last = rows.last else { break }
            let nextDatetime = last.datetime
            let nextLogId = last.logId ?? 0
            // 防死循环：游标没前进（同一毫秒 + 同一 logId 的脏数据）就直接结束
            if nextDatetime == cursorDatetime && nextLogId == cursorLogId { break }
            cursorDatetime = nextDatetime
            cursorLogId = nextLogId

            scanned += rows.count
            if let progress = progress {
                DispatchQueue.main.async { progress(scanned) }
            }
            if rows.count < pageSize { break }
        }

        return items.values.sorted { lhs, rhs in
            if lhs.totalBytes == rhs.totalBytes { return lhs.sessionId < rhs.sessionId }
            return lhs.totalBytes > rhs.totalBytes
        }
    }

    // MARK: - 未关联媒体（可清理）

    /// 只清理「30 天前、且没有被当前账号消息引用」的媒体，避免误删正在用的缓存。
    private static let orphanMinAge: TimeInterval = 30 * 24 * 60 * 60

    /// 统计未关联媒体（不删）
    func loadOrphanMedia(completion: @escaping (FZMOrphanMedia) -> Void) {
        workQueue.async {
            let info = self.scanOrphanMedia(delete: false)
            DispatchQueue.main.async { completion(info) }
        }
    }

    /// 删除未关联媒体，回传删掉的大小
    func clearOrphanMedia(completion: @escaping (FZMOrphanMedia) -> Void) {
        workQueue.async {
            let info = self.scanOrphanMedia(delete: true)
            DispatchQueue.main.async { completion(info) }
        }
    }

    private func scanOrphanMedia(delete: Bool) -> FZMOrphanMedia {
        let keys = self.referencedCacheKeys()
        var info = FZMOrphanMedia()

        // 视频：Video/{cacheKey}.MOV
        for url in Self.fileURLs(in: self.documentPath("Video")) {
            let key = url.deletingPathExtension().lastPathComponent
            guard !keys.contains(key), Self.isOlderThan(url, interval: Self.orphanMinAge) else { continue }
            info.videoBytes += Self.fileSize(url.path)
            if delete { try? FileManager.default.removeItem(at: url) }
        }

        // 语音：Voice/WavFile/{cacheKey}.wav、Voice/AmrFile/{cacheKey}.amr
        for sub in ["Voice/WavFile", "Voice/AmrFile"] {
            for url in Self.fileURLs(in: self.documentPath(sub)) {
                let key = url.deletingPathExtension().lastPathComponent
                guard !keys.contains(key), Self.isOlderThan(url, interval: Self.orphanMinAge) else { continue }
                info.voiceBytes += Self.fileSize(url.path)
                if delete { try? FileManager.default.removeItem(at: url) }
            }
        }

        // 文件：File/{cacheKey}/ 整个目录
        for url in Self.directoryURLs(in: self.documentPath("File")) {
            let key = url.lastPathComponent
            guard !keys.contains(key), Self.isOlderThan(url, interval: Self.orphanMinAge) else { continue }
            info.fileBytes += Self.directorySize(url.path)
            if delete { try? FileManager.default.removeItem(at: url) }
        }

        // 聊天图片：Kingfisher 文件名是 key 的哈希，反推不了 ⇒ 先算出所有在用 key 的 cachePath，再删不在集合里的
        let probe = ChatMediaCache.cachePath(forKey: "__orphan_probe__")
        let imageDir = (probe as NSString).deletingLastPathComponent
        var expected = Set<String>()
        for key in keys {
            let original = ChatMediaCache.cachePath(forKey: key)
            expected.insert(URL(fileURLWithPath: original).standardizedFileURL.path)
            let thumb = ChatMediaCache.cachePath(forKey: key,
                                                processorIdentifier: Self.thumbnailProcessorIdentifier)
            expected.insert(URL(fileURLWithPath: thumb).standardizedFileURL.path)
        }
        for url in Self.fileURLs(in: imageDir) {
            let path = url.standardizedFileURL.path
            guard !expected.contains(path), Self.isOlderThan(url, interval: Self.orphanMinAge) else { continue }
            info.imageBytes += Self.fileSize(url.path)
            if delete { try? FileManager.default.removeItem(at: url) }
        }

        return info
    }

    /// 当前账号 message 表里所有被引用的 cacheKey
    private func referencedCacheKeys() -> Set<String> {
        var keys = Set<String>()
        var cursorDatetime = Int.max
        var cursorLogId = Int.max
        let pageSize = 500

        while true {
            let conditionDatetime = cursorDatetime
            let conditionLogId = cursorLogId
            let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
                if conditionDatetime != Int.max {
                    let datetimeCondition: WCDBSwift.Expression = MessageDB.Properties.datetime < conditionDatetime
                    let sameDatetimeCondition: WCDBSwift.Expression = MessageDB.Properties.datetime == conditionDatetime
                    let logIdCondition: WCDBSwift.Expression = MessageDB.Properties.logId < conditionLogId
                    constraint.condition = datetimeCondition || (sameDatetimeCondition && logIdCondition)
                }
                constraint.orderBy = [MessageDB.CodingKeys.datetime.asOrder(by: .descending),
                                      MessageDB.CodingKeys.logId.asOrder(by: .descending)]
                constraint.limit = pageSize
            }
            if rows.isEmpty { break }
            for row in rows {
                if let key = Self.cacheKey(inJSON: row.msg), !key.isEmpty {
                    keys.insert(key)
                }
            }
            guard let last = rows.last else { break }
            let nextDatetime = last.datetime
            let nextLogId = last.logId ?? 0
            if nextDatetime == conditionDatetime && nextLogId == conditionLogId { break }
            cursorDatetime = nextDatetime
            cursorLogId = nextLogId
            if rows.count < pageSize { break }
        }
        return keys
    }

    private static func fileURLs(in path: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return [] }
        var urls: [URL] = []
        while let sub = enumerator.nextObject() as? String {
            let full = (path as NSString).appendingPathComponent(sub)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }
            urls.append(URL(fileURLWithPath: full))
        }
        return urls
    }

    private static func directoryURLs(in path: String) -> [URL] {
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        var urls: [URL] = []
        for child in children {
            let full = (path as NSString).appendingPathComponent(child)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            urls.append(URL(fileURLWithPath: full))
        }
        return urls
    }

    private static func isOlderThan(_ url: URL, interval: TimeInterval) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else { return false }
        return Date().timeIntervalSince(date) > interval
    }

    // MARK: - 清理：缓存

    /// 清理全部可再生的缓存（图片缓存 / HTTP 缓存 / 解密临时文件 / 头像缩略图）
    /// ⚠️ 必须等两个图片缓存库真正删完再回调，否则重新统计时拿到的还是旧值（表现为「清不掉」）
    func clearCache(completion: @escaping () -> Void) {
        SquareImageMemoryCache.removeAll()
        ImageCache.default.clearMemoryCache()
        let sdCache = SDWebImageManager.shared().imageCache
        sdCache?.clearMemory()
        URLCache.shared.removeAllCachedResponses()

        let group = DispatchGroup()

        group.enter()
        ImageCache.default.clearDiskCache {
            group.leave()
        }

        group.enter()
        if let sdCache = sdCache {
            sdCache.clearDisk(onCompletion: {
                group.leave()
            })
        } else {
            group.leave()
        }

        // 临时文件 / 头像缩略图 / 系统 tmp 同步删（在后台队列上）
        workQueue.async {
            Self.removeContents(atPath: self.documentPath("Tmp"))
            Self.removeContents(atPath: self.avatarThumbnailPath)
            Self.removeContents(atPath: NSTemporaryDirectory())
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    // MARK: - 清理：单个会话

    /// 只清理媒体（图片/视频/文件/语音），保留聊天文字
    func clearMedia(for item: FZMChatStorageItem, completion: @escaping () -> Void) {
        workQueue.async {
            let msgTypes: [Int] = [2, 3, 4, 5]
            let rows: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
                // 同上：子条件显式标注为 Expression
                let sessionCondition: WCDBSwift.Expression = MessageDB.Properties.sessionId.is(item.sessionId)
                let typeCondition: WCDBSwift.Expression = MessageDB.Properties.msgType.in(msgTypes)
                constraint.condition = sessionCondition && typeCondition
            }

            for row in rows {
                guard let cacheKey = Self.cacheKey(inJSON: row.msg), !cacheKey.isEmpty else { continue }
                switch row.msgType {
                case 2:
                    Self.removeItem(atPath: self.documentPath("Voice/WavFile/\(cacheKey).wav"))
                    Self.removeItem(atPath: self.documentPath("Voice/AmrFile/\(cacheKey).amr"))
                case 3:
                    // 原图 + 降采样副本都要删（聊天图片在专用缓存 `ChatMediaCache` 里）
                    ChatMediaCache.removeImage(forKey: cacheKey)
                    ChatMediaCache.removeImage(forKey: cacheKey,
                                               processorIdentifier: Self.thumbnailProcessorIdentifier)
                case 4:
                    Self.removeItem(atPath: self.documentPath("Video/\(cacheKey).MOV"))
                case 5:
                    Self.removeItem(atPath: self.documentPath("File/\(cacheKey)"))
                default:
                    break
                }
            }

            DispatchQueue.main.async { completion() }
        }
    }

    /// 删除整个会话（消息 + 媒体 + 会话行）。
    /// ⚠️ 只删本机：服务端没有「按会话删除」接口，下次同步仍可能把历史补回来。
    func deleteSession(_ item: FZMChatStorageItem, completion: @escaping () -> Void) {
        clearMedia(for: item) {
            ChatManager.shared().deleteSessionMsgs(targetId: item.sessionId)
            DispatchQueue.main.async {
                SessionManager.shared().deleteSession(id: item.sessionID)
                completion()
            }
        }
    }

    // MARK: - 私有工具

    /// 某个 Kingfisher 缓存的磁盘占用（默认缓存 / `ChatMediaCache` 分开统计）。
    /// 内部回调在 Kingfisher 自己的 ioQueue，这里在 workQueue 上同步等它；**带超时**，
    /// 避免异常情况下（目录不可读等）把整条统计队列永久卡住。
    private func kingfisherDiskSize(_ cache: ImageCache = ImageCache.default) -> Int64 {
        var size: Int64 = 0
        let semaphore = DispatchSemaphore(value: 0)
        cache.calculateDiskStorageSize { result in
            if case .success(let value) = result { size = Int64(value) }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 10)
        return size
    }

    /// 某个 Kingfisher 缓存实际落盘的目录（从 cachePath 反推；
    /// 兼容 `cachePathBlock` 没生效、实际仍落在 Library/Caches 的情况）。
    private func kingfisherCacheDirectory(_ cache: ImageCache = ImageCache.default) -> String {
        let probe = cache.cachePath(forKey: "__storage_probe__")
        return (probe as NSString).deletingLastPathComponent
    }

    private static func isUnder(_ path: String, _ parent: String) -> Bool {
        let p = URL(fileURLWithPath: path).standardizedFileURL.path
        let q = URL(fileURLWithPath: parent).standardizedFileURL.path
        return p == q || p.hasPrefix(q + "/")
    }

    /// SDWebImage 的磁盘占用。
    /// 默认目录：`Library/Caches/default/com.hackemist.SDWebImageCache.default`
    /// （`SDImageCache.initWithNamespace("default")` → `makeDiskCachePath("default")`
    ///  + `com.hackemist.SDWebImageCache.default`）。
    /// 不用 `imageCache.getSize()`：它内部 `dispatch_sync` 到自己的 ioQueue，
    /// 清理任务排队时会把统计线程一起堵住。
    private static func sdWebImageDiskSize() -> Int64 {
        let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
            ?? (NSHomeDirectory() + "/Library/Caches")
        let candidates = [
            (caches as NSString).appendingPathComponent("default/com.hackemist.SDWebImageCache.default"),
            (caches as NSString).appendingPathComponent("com.hackemist.SDWebImageCache.default")
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return directorySize(path)
        }
        return 0
    }

    /// 单张聊天图片在磁盘上的占用（原图 + 降采样副本，在 `ChatMediaCache` 里）
    private func imageCacheSize(forKey key: String) -> Int64 {
        let originalPath = ChatMediaCache.cachePath(forKey: key)
        let thumbnailPath = ChatMediaCache.cachePath(forKey: key,
                                                     processorIdentifier: Self.thumbnailProcessorIdentifier)
        var size = Self.fileSize(originalPath)
        if thumbnailPath != originalPath {
            size += Self.fileSize(thumbnailPath)
        }
        return size
    }

    /// 从消息 JSON 里取 cacheKey。
    /// ⚠️ 不要为了这个构造 `Message`（会解析整段 JSON + 建 UI 对象）
    private static func cacheKey(inJSON json: String) -> String? {
        guard let range = json.range(of: "\"cacheKey\"") else { return nil }
        var index = range.upperBound
        // 跳过冒号、空格与开引号
        while index < json.endIndex, json[index] == ":" || json[index] == " " || json[index] == "\"" {
            index = json.index(after: index)
        }
        guard index < json.endIndex else { return nil }
        let rest = json[index...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let value = String(rest[..<end])
        return (value.isEmpty || value == "null") ? nil : value
    }

    static func fileSize(_ path: String) -> Int64 {
        guard !path.isEmpty,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType, type == .typeRegular,
              let number = attributes[.size] as? NSNumber else { return 0 }
        return number.int64Value
    }

    static func directorySize(_ path: String) -> Int64 {
        guard !path.isEmpty else { return 0 }
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue { return fileSize(path) }

        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }
        var total: Int64 = 0
        while let sub = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(sub)
            total += fileSize(fullPath)
        }
        return total
    }

    /// 只删目录里的内容，保留目录本身（下次写入不用重新建）
    static func removeContents(atPath path: String) {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(atPath: path) else { return }
        for child in children {
            try? fileManager.removeItem(atPath: (path as NSString).appendingPathComponent(child))
        }
    }

    static func removeItem(atPath path: String) {
        guard !path.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}
