//
//  FZMMessageBaseVM.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/22.
//

import Foundation
import AVKit
import Kingfisher
import RxSwift

class FZMMessageBaseVM: NSObject {
    var message: Message
    
    var time: String
    
    var localFilePath: String = ""// 文件的本地沙盒路径（语音、视频、文件）
    var isLocalFileExist = false// 文件是否已有本地缓存
    
    var saveVideoToAlUrl: String = ""// 视频文件本地沙盒路径（保存到相册时使用，本地存在视频数据则字段不为空）
    
    let fileDownloadFailedSubject = PublishSubject<Message>.init()// 下载失败订阅
    let fileDownloadSucceedSubject = PublishSubject<Message>.init()// 下载成功订阅
    let fileDownloadProgressSubject = PublishSubject<CGFloat>.init()// 下载进度订阅
    
    var selected = false
    
//    override init() {
//        super.init()
//    }
    
    init(with msg: Message) {
        self.message = msg
        
        self.time = String.yyyyMMddDateString(with: Double(msg.datetime))
        
        // 文件本地沙盒路径
        switch msg.kind {
        case .audio, .video, .file:
            self.localFilePath = FZMMessageBaseVM.getFilePath(with: msg)
            if FZMLocalFileClient.shared().isFileExists(atPath: self.localFilePath) {
                // 本地有缓存文件
                self.isLocalFileExist = true
            }
        default:
            self.localFilePath = ""
            self.isLocalFileExist = false
        }
    }
    
    func update(with msg: Message) {
        message = msg
    }
    
    // MARK: - 下载状态（视频/文件/语音共用）
    
    /// 下载回调使用的后台队列。
    /// ⚠️ 原来是 `OperationQueue.main`：下载进度回调、以及下载完成后的
    /// 「全量读文件 + AES 解密 + 落盘」全挤在主线程上 —— 大视频会卡住 UI，
    /// 进度条到 100% 之后还要干等一段时间才能播放。放到后台队列后，
    /// 主线程只负责刷新进度和播放。
    private static let downloadDelegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "chat.file.download.delegate"
        // 串行回调会把「解密 + 落盘」排成队（批量下载时后一条的进度条要等前一条处理完），
        // 全放开又会同时解密好几个大文件、内存飙升；这里取 2，兼顾响应和内存。
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // MARK: - 下载互斥 / 预下载状态（同一条消息只跑一个下载）
    
    /// 正在下载的消息 id。⚠️ cell 复用会给**同一条消息**建出多个 VM 实例
    /// （每次 configure 都 `FZMMessageBaseVM.init(with:)`），只靠实例上的标志拦不住。
    private static var loadingMsgIds = Set<String>()
    /// 其中由「预下载」发起的消息 id（用来限制预下载并发数）
    private static var prefetchLoadingMsgIds = Set<String>()
    /// 等待同一条消息下载结果的其它 VM（点开时那条消息正在被预下载，结果要转发过来）
    private static var loadingWaiters: [String: [FZMMessageBaseVM]] = [:]
    /// 预下载排队（进会话 / 滚到可见时排进来，最多 maxPrefetchCount 条并行）
    private static var prefetchWaitQueue: [FZMMessageBaseVM] = []
    private static let maxPrefetchCount = 2
    private static let maxPendingPrefetchCount = 4
    private static let downloadStateLock = NSLock()

    /// 正在下载的 VM 保活表（msgId → VM）。
    /// 退出聊天页时 cell 会被回收、VM 随之释放，`URLSession` 的 delegate 也没了 ⇒ 下载直接中断。
    /// 用户要求「退出聊天页后下载继续」（2026-11-05），所以下载期间把 VM 强引用在这里，
    /// `finishDownload` 里移除，恢复正常生命周期。
    private static var activeDownloadVMs: [String: FZMMessageBaseVM] = [:]
    
    /// 本条消息当前的下载会话（结束后失效，避免会话和 VM 一直不释放）
    private var downloadSession: URLSession?
    /// 是否正在下载：同一条消息连点时不再重复发起（多个相同请求并行只会互相抢带宽，反而更慢）
    private var isDownloading = false
    /// 下载期间并行预取的公钥（省掉「文件下完了才开始查密钥」的那一个来回）
    private var prefetchedPublickey: String?
    /// 进度回调限流用（系统进度回调非常密集）
    private var lastProgressTime: TimeInterval = 0
    
    /// 取密钥用的地址（私聊取对方地址，群聊取群 id）
    private var publickeyAddress: String {
        let msg = self.message
        if msg.sessionId.isPersonChat {
            return msg.fromId == LoginUser.shared().address ? msg.targetId : msg.fromId
        }
        return msg.targetId
    }
    
    //下载文件 语音 视频 文件
    func downloadData() {
        guard canStartDownload() else {
            return
        }
        // 同一条消息只跑一个下载（cell 复用会产生多个 VM 实例，预下载与用户点击也会撞车）
        guard beginDownload(isPrefetch: false) else {
            FZMLog("该消息正在下载中，本次请求转为等待结果 msgId \(self.message.msgId)")
            return
        }
        startDownload()
    }
    
    /// 预下载：进会话 / 滚动到可见时调用（只处理视频消息），点开即可播放
    func prefetchVideoIfNeeded() {
        guard case .video = self.message.msgType else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isLocalFileExist, !self.isDownloading else { return }
            FZMMessageBaseVM.enqueuePrefetch(self)
        }
    }
    
    /// 下载前校验：是否需要下载、本地是否已有、url 是否可用
    private func canStartDownload() -> Bool {
        var needDownload = false
        switch self.message.msgType {
        case .video, .file,.audio:
            needDownload = true
        default:
            needDownload = false
        }
        // 判断文件是否为需要下载的类型 + 本地是否已有缓存，避免重复下载
        guard needDownload, !isLocalFileExist else {
            return false
        }
        // 文件url地址
        guard let fileUrl = self.message.msgType.fileUrl, !fileUrl.isBlank else {
            APP.shared().showToast(L("数据加载失败"))
            return false
        }
        guard fileUrl.url != nil else {
            FZMLog("下载失败，无效的URL: \(fileUrl)")
            return false
        }
        return true
    }
    
    /// 真正发起下载
    private func startDownload() {
        guard let fileUrl = self.message.msgType.fileUrl, let url = fileUrl.url else {
            // 消息里的 url 不合法：把互斥标记放掉，别把预下载的并发名额永久占住
            finishDownload(success: false)
            return
        }
        
        isDownloading = true
        
        // 下载的同时并行取公钥：原来要等文件下完才开始查（白白多等一个来回）
        prefetchedPublickey = nil
        let address = self.publickeyAddress
        let isPersonChat = self.message.sessionId.isPersonChat
        ChatManager.getPublickey(by: address, isGetUserKey: isPersonChat) { [weak self] (pubkey) in
            self?.prefetchedPublickey = pubkey
        }
        
        let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: FZMMessageBaseVM.downloadDelegateQueue)
        self.downloadSession = session
        session.downloadTask(with: url).resume()
    }
    
    // MARK: - 下载互斥 / 预下载队列
    
    /// 登记「这条消息的下载由我发起」；如果已经有下载在跑，就把自己登记成等待者（拿到结果会转发给我）
    private func beginDownload(isPrefetch: Bool) -> Bool {
        let msgId = self.message.msgId
        FZMMessageBaseVM.downloadStateLock.lock()
        if FZMMessageBaseVM.loadingMsgIds.contains(msgId) {
            FZMMessageBaseVM.loadingWaiters[msgId, default: []].append(self)
            FZMMessageBaseVM.downloadStateLock.unlock()
            return false
        }
        FZMMessageBaseVM.loadingMsgIds.insert(msgId)
        if isPrefetch {
            FZMMessageBaseVM.prefetchLoadingMsgIds.insert(msgId)
        }
        // 保活：退出聊天页后 cell 释放，但这条下载要继续跑完
        FZMMessageBaseVM.activeDownloadVMs[msgId] = self
        FZMMessageBaseVM.downloadStateLock.unlock()
        return true
    }
    
    /// 下载收尾：解除互斥 → 把结果转发给等待同一条消息的 VM → 让排队的预下载补位
    private func finishDownload(success: Bool) {
        let msgId = self.message.msgId
        let msg = self.message
        
        FZMMessageBaseVM.downloadStateLock.lock()
        FZMMessageBaseVM.loadingMsgIds.remove(msgId)
        FZMMessageBaseVM.activeDownloadVMs.removeValue(forKey: msgId)
        let wasPrefetch = FZMMessageBaseVM.prefetchLoadingMsgIds.remove(msgId) != nil
        let waiters = FZMMessageBaseVM.loadingWaiters.removeValue(forKey: msgId) ?? []
        FZMMessageBaseVM.downloadStateLock.unlock()
        
        // 等待者都是「用户已经点了这条消息」的 cell：把结果原样通知它们，否则点击会像没反应一样。
        // 统一回主线程发（个别失败路径可能发生在后台线程上，不能从后台线程碰 UI）
        DispatchQueue.main.async {
            for waiter in waiters where waiter !== self {
                waiter.isDownloading = false
                if success {
                    waiter.isLocalFileExist = true
                    waiter.saveVideoToAlUrl = self.saveVideoToAlUrl
                    waiter.fileDownloadProgressSubject.onNext(1)
                    waiter.fileDownloadSucceedSubject.onNext(msg)
                } else {
                    waiter.fileDownloadFailedSubject.onNext(msg)
                }
            }
        }
        
        if wasPrefetch {
            FZMMessageBaseVM.pumpPrefetchQueue()
        }
    }
    
    /// 把一条视频排进预下载队列（已在下载 / 已在排队的不重复加；队列满了就丢掉最早排的那条）
    private static func enqueuePrefetch(_ vm: FZMMessageBaseVM) {
        let msgId = vm.message.msgId
        downloadStateLock.lock()
        let isLoading = loadingMsgIds.contains(msgId)
        let isQueued = prefetchWaitQueue.contains { $0.message.msgId == msgId }
        if !isLoading && !isQueued {
            if prefetchWaitQueue.count >= maxPendingPrefetchCount {
                prefetchWaitQueue.removeFirst()
            }
            prefetchWaitQueue.append(vm)
        }
        downloadStateLock.unlock()
        pumpPrefetchQueue()
    }
    
    /// 依次取队首任务发起下载（最多 maxPrefetchCount 条并行，避免滚屏时把带宽/内存一起打满）
    private static func pumpPrefetchQueue() {
        while true {
            downloadStateLock.lock()
            guard prefetchLoadingMsgIds.count < maxPrefetchCount, !prefetchWaitQueue.isEmpty else {
                downloadStateLock.unlock()
                return
            }
            let vm = prefetchWaitQueue.removeFirst()
            downloadStateLock.unlock()
            
            guard !vm.isLocalFileExist, vm.beginDownload(isPrefetch: true) else { continue }
            vm.startDownload()
        }
    }
}

extension FZMMessageBaseVM: URLSessionDelegate, URLSessionDownloadDelegate {
    // 语音、视频、文件下载回调（⚠️ 本回调运行在后台队列，不是主线程）
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // ⚠️ location 是系统临时文件，本方法返回后就会被删除，必须在这里同步处理完
        let curMsg = self.message
        
        // 公钥优先用下载期间预取到的，拿不到再补查一次（「是否解密」的判定口径保持原样）
        if let pubkey = self.prefetchedPublickey {
            self.saveDownloadedFile(at: location, msg: curMsg, publickey: pubkey)
        } else {
            ChatManager.getPublickey(by: self.publickeyAddress, isGetUserKey: curMsg.sessionId.isPersonChat) { [weak self] (pubkey) in
                self?.saveDownloadedFile(at: location, msg: curMsg, publickey: pubkey)
            }
        }
    }
    
    /// 下载完成后的收尾：读文件 → 解密 → 落盘 → 抽封面 → 通知
    /// ⚠️ 全程在后台队列执行，主线程只会收到「进度 / 成功 / 失败」三个通知
    private func saveDownloadedFile(at location: URL, msg curMsg: Message, publickey: String) {
        defer {
            // 到这里会话与 VM 的强引用关系结束（原来不失效，每下载一个文件就漏一个 URLSession）
            self.downloadSession?.finishTasksAndInvalidate()
            self.downloadSession = nil
        }
        
        // 映射方式读取，省掉一份同样大的内存拷贝（原来是 contents(atPath:) 全量读入 + 强解包）
        guard let fileData = try? Data(contentsOf: location, options: .mappedIfSafe) else {
            FZMLog("下载文件读取失败 \(location.path)")
            // ⚠️ 这里必须强引用 self：通知排队期间 cell 可能被复用、VM 被换掉，弱引用会让通知丢掉
            DispatchQueue.main.async {
                self.isDownloading = false
                self.fileDownloadFailedSubject.onNext(curMsg)
                self.finishDownload(success: false)
            }
            return
        }
        
        var fileName = "\(curMsg.msgType.cachekey ?? "")"
        if case .file = curMsg.msgType {
            if let name = curMsg.msgType.fileName {
                fileName = fileName + "/\(name)"
            }
        }
        
        let filePath = self.localFilePath.isEmpty ? FZMMessageBaseVM.getFilePath(with: curMsg) : self.localFilePath
        
        var fromFilePath = location.path
        if !publickey.isBlank {// 有公钥需解密
            // 直接在当前后台队列上解密（原来用 DispatchSemaphore 等待，而被阻塞的是主线程）
            let decryptData = ChatManager.decryptUploadData(fileData, publickey: publickey, isEncryptPersionChatData: curMsg.sessionId.isPersonChat)
            
            // 转存本地临时文件
            if decryptData.count > 0, let tmpFilePath = FZMLocalFileClient.shared().createFile(with: .tmp(fileName: fileName)), FZMLocalFileClient.shared().saveData(decryptData, filePath: tmpFilePath) {
                fromFilePath = tmpFilePath
            }
            FZMLog("文件解密结束，继续下一步操作")
        }
        
        defer {
            // 清除零时文件
            let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: fromFilePath)
        }
        
        // 转存成功
        guard FZMLocalFileClient.shared().move(fromFilePath: fromFilePath, toFilePath: filePath) else {
            FZMLog("下载文件保存到本地沙盒失败 message \(curMsg)")
            DispatchQueue.main.async {
                self.isDownloading = false
                // 发出下载失败订阅
                self.fileDownloadFailedSubject.onNext(curMsg)
                self.finishDownload(success: false)
            }
            return
        }
        
        if case .video = curMsg.msgType {// 视频
            // 排查用日志：输出取封面时用的本地文件路径
            //（`$ENC$` 只出现在消息的远程 URL 里，本地路径是 Video/<cachekey>.MOV，不会带该标记）
            FZMLog("获取视频封面 filePath: \(filePath)")
            // 获取视频封面（内部本身就是异步的，不会挡住这里）
            self.getVideoCoverImage(with: URL.init(fileURLWithPath: filePath), fileName: fileName)
        }
        
        // 主线程上更新状态并发订阅（调用方要在主线程播视频、弹预览）
        DispatchQueue.main.async {
            self.isDownloading = false
            self.isLocalFileExist = true
            if case .video = curMsg.msgType {
                // 记录视频本地路径，播放视频页面保存时使用
                self.saveVideoToAlUrl = filePath
            }
            // 进度补到 1：限流可能把最后一次进度回调丢掉了，进度条要能收起来
            self.fileDownloadProgressSubject.onNext(1)
            // 发出下载成功订阅
            self.fileDownloadSucceedSubject.onNext(curMsg)
            self.finishDownload(success: true)
        }
    }
    
    // 从下载的视频文件中获取视频封面
    private func getVideoCoverImage(with url: URL, fileName: String) {
        // 获取视频第一帧作为封面
        
        UIImage.getVideoCropPicture(url) { (image) in
            guard let image = image else {
                // 封面拿不到就不打扰用户了（只是列表里少个缩略图），仅留日志
                FZMLog("视频封面获取出错")
                return
            }
            // 缓存封面图片
            ChatMediaCache.store(image, forKey: fileName)
        }
        
//        let asset = AVURLAsset.init(url: url)
//        let gen = AVAssetImageGenerator.init(asset: asset)
//        gen.appliesPreferredTrackTransform = true
//        gen.apertureMode = .encodedPixels
//        let time = CMTimeMakeWithSeconds(0.0, preferredTimescale: 1)
//        var actualTime: CMTime = CMTimeMakeWithSeconds(0, preferredTimescale: 0)
//        do {
//            let imageCG = try gen.copyCGImage(at: time, actualTime: &actualTime)
//            let image = UIImage.init(cgImage: imageCG)
//
//            // 判断图片是否存在
//            if image.imageIsEmpty() {
//                // 缓存封面图片
//                ChatMediaCache.store(image, forKey: fileName)
//            }
//        } catch let error {
//            print(error)
//            APP.shared().showToast(L("视频封面获取失败"))
//            FZMLog("视频封面获取出错")
//        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 长度未知时（-1）不刷进度，避免出现负数进度
        guard totalBytesExpectedToWrite > 0 else { return }
        
        var progress: CGFloat = 0
        let num1: CGFloat = CGFloat(totalBytesWritten)
        let num2: CGFloat = CGFloat(totalBytesExpectedToWrite)
        progress = CGFloat(num1 / num2)
//        if self.downloadType == 1 {
//            self.curTapMediaCell?.updateDownLoadProcress(proress: progress)
//        } else if self.downloadType == 2 {
//            self.curTapFileCell?.updateDownLoadProcress(proress: progress)
//        } else {
//
//        }
        // 系统进度回调非常密集：限流到 0.1s 一次，并切回主线程去刷进度条
        let now = Date().timeIntervalSince1970
        guard now - self.lastProgressTime >= 0.1 else { return }
        self.lastProgressTime = now
        DispatchQueue.main.async { [weak self] in
            self?.fileDownloadProgressSubject.onNext(progress)
        }
    }
    
    // 下载出错（超时/断网/被取消）：原来没有这个回调，失败后状态不重置、也不提示，进度条就卡住了
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // error 为 nil 表示成功，成功路径在 didFinishDownloadingTo 里收尾
        guard let error = error else { return }
        FZMLog("文件下载失败 \(error)")
        let curMsg = self.message
        self.downloadSession?.finishTasksAndInvalidate()
        self.downloadSession = nil
        DispatchQueue.main.async {
            self.isDownloading = false
            self.fileDownloadFailedSubject.onNext(curMsg)
            self.finishDownload(success: false)
        }
    }
}

extension FZMMessageBaseVM {
    
    // 获取文件路径
    class func getFilePath(with msg: Message) -> String {
        var filePath = ""
        var fileName = "\(msg.msgType.cachekey ?? "")"
        if case .file = msg.msgType {
            if let name = msg.msgType.fileName {
                fileName = fileName + "/\(name)"
            }
            filePath = DocumentPath.appendingPathComponent("File/\(fileName)")
        } else if case .video = msg.msgType {
            filePath = DocumentPath.appendingPathComponent("Video/\(fileName).MOV")
        } else if case .audio = msg.msgType {
            let path = "Voice/WavFile/\(fileName).wav"
            filePath = DocumentPath.appendingPathComponent(path)
        }
        return filePath
    }
    
    class func getLocalCoin(with msg:Message) -> LocalCoin {
        // 没有选中钱包 / 没有币种时，原来 `coinArray!` + `as!` 会崩；取不到返回空币种即可
        let coins = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID() as? [LocalCoin] ?? []
        let coinName = msg.msgType.coinName
        return coins.first(where: { $0.coin_type == coinName }) ?? LocalCoin.init()
    }
    
}


