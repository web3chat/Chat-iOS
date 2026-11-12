//
//  SocketManager+Msg.swift
//  chat
//
//  Created by fzm on 2021/1/20.
//

import Foundation


extension SocketManager {
    
    func msgConfigure() {
        self.isAuthSubject.subscribe(onNext: { (isAuth) in
            if isAuth {
                self.syncMsg()
            } else {
                // 断连 / 未鉴权：作废旧的同步链，避免它「卡在 inProgress」挡住下次同步
                self.syncGeneration += 1
                self.syncInProgress = false
                self.cleanAckWithSendFailed()
            }
        }).disposed(by: self.bag)
    }
}


//MARK - Send Msg
extension SocketManager {
    
    private struct AssociationMsgKey {
        static var ackDic = "SocketManager_AssociationMsgKey_Ack_Dic"
    }
    
    //key -> seq, valeu -> msgId
    private var _ackDic: [Int: String] {
        set {
            objc_setAssociatedObject(self, &AssociationMsgKey.ackDic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            // 用 `as?` 兑底：`as!` 在“检查-赋值”被并发穿插、或关联对象被写成别的类型时
            // 会直接 trap（_assertionFailure）—— 后台 socket 线程上这类崩溃不可 catch，不可恢复。
            if let dic = objc_getAssociatedObject(self, &AssociationMsgKey.ackDic) as? [Int: String] {
                return dic
            }
            objc_setAssociatedObject(self, &AssociationMsgKey.ackDic, [Int: String](), .OBJC_ASSOCIATION_RETAIN)
            // 返回真正存进去的那个（并发时可能是别的线程先存的），保证大家拿到同一份
            return (objc_getAssociatedObject(self, &AssociationMsgKey.ackDic) as? [Int: String]) ?? [:]
        }
    }
    
    enum SendMsgStatus {
        case delivered(logIds: [Int])//已送达，接收方成功收到消息
        case success((msgId: String, logId: Int, datetime: Int))//已发送，发送消息成功
        case failed(msgId: String)//发送失败
    }
    
    func send(msg: Message, publickey: String) {
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) 不可用, 发送msg失败")
            let sendFailed = SendMsgStatus.failed(msgId: msg.msgId)
            self.sendMsgStatusSubject.onNext(sendFailed)
            return
        }
        self.executeInSocketThread {
            // 序列化
            guard let pbEvent = PbMsg_event.init(with: msg, publickey: publickey),
                  let data = try? pbEvent.serializedData() else { return }
            
            var seq = Counter.increment()
            while self._ackDic[seq] != nil { seq = Counter.increment() }
            self._ackDic[seq] = msg.msgId
            let wrapData = SocketData.wrapData(with: PbSkt_Op.sendMsg.rawValue, seq: seq, ack: 0, body: data)
            FZMLog("websocket \(self.url) 发送msg:---\(msg)")
            self.write(data: wrapData)
            self.executeInSocketThread(afterDelay: 3) {
                let needResend = self._ackDic[seq] != nil
                guard needResend else { return }
                FZMLog("websocket \(self.url) 超时重发msg:---\(msg)")
                self.write(data: wrapData)
            }
            self.executeInSocketThread(afterDelay: 5) {
                let sendFailed = self._ackDic[seq] != nil
                guard sendFailed else { return }
                self.sendMsgStatusSubject.onNext(.failed(msgId: msg.msgId))
            }
        }
    }
    
    // 发送消息回执
    func sendMsgReply(data: SocketData.UnWrapData) {
        guard let msgId = self._ackDic[data.ack],
              let event = try? PbMsg_event.init(serializedData: data.body),
              let msgAck = try? PbMsg_SendMsgAck.init(serializedData: event.body) else { return }
        let sendSuccess = SendMsgStatus.success((msgId: msgId, logId: Int(msgAck.logID), datetime: Int(msgAck.datetime)))
        self.sendMsgStatusSubject.onNext(sendSuccess)
        self._ackDic.removeValue(forKey: data.ack)
    }
    
    private func cleanAckWithSendFailed() {
        guard !self._ackDic.isEmpty else { return }
        let allSendingMsgs = Array(self._ackDic.values)
        allSendingMsgs.forEach { (msgId) in
            self.sendMsgStatusSubject.onNext(.failed(msgId: msgId))
        }
        self._ackDic.removeAll()
    }
    
    //SyncMsg
    /// 发起 / 续跑一轮离线消息同步。幂等：已有同步链在跑就跳过。
    ///
    /// ⚠️ 服务端一次只推一批，`syncMsgReply` 到达后由 `handleSyncMsgReply()` 按最新断点继续补拉；
    ///    否则「一次进入 App 只能拿到一批、要反复重进才收全」。
    private func syncMsg() {
        guard !self.syncInProgress else {
            FZMLog("websocket \(self.url) syncMsg 跳过：已有同步在进行")
            return
        }
        // 新的一轮同步重新开始帧编号连续性检查：只和「本轮下发」的帧比，
        // 不跟上一轮 / 上一次连接比，避免误报缺口
        self.lastRecvSeq = 0
        self.gapDetectedInChain = false
        self.syncGeneration += 1
        self.syncInProgress = true
        // 记下这条链的起点断点：收尾时按「整条链有没有新增」决定要不要自动补拉
        self.syncStartLogId = self.serverSyncLogId
        // 本条链收到几条（补洞那一轮断点不动，但确实补到了数据，得靠这个计数判断）
        self.syncChainReceivedCount = 0
        FZMLog("websocket \(self.url) 开始同步（generation \(self.syncGeneration)）起点断点=\(self.syncStartLogId)")
        self.postSyncStateToUI(inProgress: true)
        self.requestSyncMsg(generation: self.syncGeneration, round: 1)
    }

    /// 把「离线同步开始 / 结束」通知给界面（统一回主线程发）
    private func postSyncStateToUI(inProgress: Bool) {
        let serverUrl = self.url.httpUrl
        DispatchQueue.main.async {
            FZM_NotificationCenter.post(
                name: FZM_Notify_OfflineSyncStateChanged,
                object: serverUrl,
                userInfo: ["inProgress": inProgress])
        }
    }

    /// 按当前断点（**这台服务器**已同步到的最大 logId）发一轮 SyncMsgReq。
    /// `generation`：旧链路上的定时器 / 回调发现代号对不上就自动失效。
    private func requestSyncMsg(generation: Int, round: Int) {
        guard generation == self.syncGeneration, self.syncInProgress else { return }
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) 不可用, 发送syncMsg失败")
            self.finishSync(generation: generation)
            return
        }
        guard round <= kMaxSyncMsgRounds else {
            FZMLog("websocket \(self.url) syncMsg 已达最大轮次 \(kMaxSyncMsgRounds)，稍后自动续")
            self.finishSync(generation: generation)
            DispatchQueue.main.asyncAfter(deadline: .now() + kSyncResumeDelay) { [weak self] in
                self?.restartOfflineSync()
            }
            return
        }
        // ⚠️ 断点必须按「这台服务器」算：全库最大 logId 在多服务器下可能来自别的服务器
        let logId = self.serverSyncLogId
        self.syncRequestedLogId = logId
        // 新一轮开始：本轮计数清零（reply 一到就用它判断这轮有没有货）
        self.syncRoundReceivedCount = 0
        var syncMsg = PbSkt_SyncMsg.init()
        syncMsg.logID = Int64(logId)
        guard let syncMsgData = try? syncMsg.serializedData() else {
            self.finishSync(generation: generation)
            return
        }
        let data = SocketData.wrapData(with: PbSkt_Op.syncMsgReq.rawValue, seq: 0, ack: 0, body: syncMsgData)
        FZMLog("websocket \(self.url) 发送syncMsg 第\(round)轮 断点logId=\(logId)")
        self.write(data: data)
        self.scheduleReplyTimeout(generation: generation, requestedLogId: logId)
    }

    /// 一轮请求发出后一直等不到 `syncMsgReply` 时，同步链会永久卡住 ⇒ 这里超时自救。
    ///
    /// ⚠️ 服务端是把「待投递队列」里的离线消息**逐条推完再回 reply**：离线消息多时，
    ///    推这一批可能超过 15s。原来超时只看「还没回 reply」就把同步链掐断，
    ///    剩下没推完的消息只能等下次进 App 再 sync —— 用户 2026-11-03 反馈
    ///    「群聊离线消息一次加载不完，要多进几次 App」就是这个。
    ///    ⇒ 超时回调里先看断点：**断点还在前进 = 服务端还在推，重新计时继续等**；
    ///       只有「断点没动」才说明真的卡死，才复位。
    private func scheduleReplyTimeout(generation: Int, requestedLogId: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + kSyncReplyTimeout) { [weak self] in
            guard let self = self else { return }
            guard generation == self.syncGeneration, self.syncInProgress else { return }
            // 没等到 reply 但断点前进了 ⇒ 服务端正在推这一批，不能判卡死，重新计时
            let latest = self.serverSyncLogId
            if latest > requestedLogId {
                FZMLog("websocket \(self.url) syncMsg 等待reply超时但断点前进 \(requestedLogId) → \(latest)，继续等")
                self.scheduleReplyTimeout(generation: generation, requestedLogId: latest)
                return
            }
            guard self.syncRequestedLogId == requestedLogId else { return }
            FZMLog("websocket \(self.url) syncMsg 等待reply超时，复位同步状态")
            self.finishSync(generation: generation)
        }
    }

    /// 收到 `syncMsgReply`：等本批消息处理一下再判断断点有没有前进。
    /// - Parameter replyLogId: 服务端回包 body 里带的 logId（-1 = body 为空 / 解析失败）。
    ///   诊断用：拿它跟「请求断点 / 本地断点」对比，能看出服务端这轮推到哪了。
    func handleSyncMsgReply(replyLogId: Int64 = -1) {
        let generation = self.syncGeneration
        guard self.syncInProgress, generation == self.syncGeneration else {
            FZMLog("websocket \(self.url) syncMsgReply 到达但同步链已不在跑（generation=\(self.syncGeneration) inProgress=\(self.syncInProgress)），忽略")
            return
        }
        guard self.isAvailable else {
            self.finishSync(generation: generation)
            return
        }
        let requestedLogId = self.syncRequestedLogId
        let latest = self.serverSyncLogId
        FZMLog("websocket \(self.url) syncMsgReply 处理：replyLogId=\(replyLogId) 请求断点=\(requestedLogId) 本地断点=\(latest)")
        // 🔴 用「这一轮**收到**了几条帧」判断，而不是等断点前进：
        //    断点是「落库才推进」（异步），等它动就得多等 2~10 秒 —— 两轮之间那段空白就是等出来的
        //    （用户 2026-11-05：「1-2、3-4 很快，2-3、4-5 中间隔了好几秒」）。
        //    收到几条这件事在 reply 到达前就已经确定了，所以可以立刻决策：
        if self.syncRoundReceivedCount > 0 {
            FZMLog("websocket \(self.url) 本轮收到 \(self.syncRoundReceivedCount) 条，立刻续拉下一轮（不等落库）")
            self.requestSyncMsg(generation: generation, round: 1)
            return
        }
        // 这一轮一条都没收到 = 服务端在这条连接上已经没有更多了。
        // 帧是按顺序到达的：reply 之前的那批帧都已经处理完，所以这个计数是准的 ⇒ 直接收尾，
        // 不用再等「断点前进」那套轮询（原来这里要干等 10 秒）。
        FZMLog("websocket \(self.url) 本轮 0 条 ⇒ 这条连接扫空，立刻收尾")
        self.finishSync(generation: generation)
    }

    /// 收到一条**新的**（非重复）消息帧时调用：只做计数，用来驱动同步链的快慢决策。
    ///
    /// 注意这里在「落库之前」调用：断点要等落库，但「有没有收到」不需要等。
    func noteIncomingMessage() {
        self.syncChainReceivedCount += 1
        self.syncRoundReceivedCount += 1
    }

    /// 等本批消息入库后再判断断点有没有前进。
    ///
    /// 断点改成「落库时推进」后，每条消息要等「查公钥 → 解密 → 落库」才推进断点，
    /// 这批耗时可能 2~8s ⇒ 检查间隔从 1s 放宽到 3s，避免消息还在处理就被误判收尾。
    /// 没前进时最多再确认 `kMaxSyncIdleChecks` 次。
    private func checkSyncProgress(generation: Int, requestedLogId: Int, round: Int, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            guard generation == self.syncGeneration, self.syncInProgress else { return }
            guard self.isAvailable else {
                self.finishSync(generation: generation)
                return
            }
            // 只认「这台服务器」的断点
            let latest = self.serverSyncLogId
            if latest > requestedLogId {
                FZMLog("websocket \(self.url) syncMsg 第\(round + 1)轮检查：断点前进 \(requestedLogId) → \(latest)，继续补拉下一轮")
                self.requestSyncMsg(generation: generation, round: round + 1)
                return
            }
            // 断点没动：打日志（每 5 次一刷，避免刷屏），看它到底等到第几秒才收尾
            if attempt == 0 || attempt % 5 == 0 {
                FZMLog("websocket \(self.url) syncMsg 检查 attempt=\(attempt)：断点未动 latest=\(latest) requested=\(requestedLogId)")
            }
            // ⚠️ 补洞循环里只做最短确认：这时候收尾马上就要重连换新连接，
            //    本轮没落库完的消息下一轮会被服务端重推（按 msgId 去重），不需要在这里干等十几秒。
            //    用户 2026-11-05：「1-2、3-4 很快，但 2-3、4-5 中间隔了好几秒」—— 等就等在这里。
            let maxIdleChecks = self.extraScanStartTime > 0 ? kMaxSyncIdleChecksInExtraScan : kMaxSyncIdleChecks
            guard attempt < maxIdleChecks else {
                FZMLog("websocket \(self.url) syncMsg 断点连续 \(Int(Double(maxIdleChecks) * 2.0 + 2.0))s 未动，收尾")
                self.finishSync(generation: generation)
                return
            }
            self.checkSyncProgress(generation: generation, requestedLogId: requestedLogId, round: round, attempt: attempt + 1)
        }
    }

    /// 同步链收尾（只对当前 generation 生效）
    private func finishSync(generation: Int) {
        guard generation == self.syncGeneration else { return }
        guard self.syncInProgress else { return }
        self.syncInProgress = false
        FZMLog("websocket \(self.url) syncMsg 同步结束：断点 \(self.syncRequestedLogId) → \(self.serverSyncLogId)")
        // 有消息因「本地还没有这个群」被跳过 ⇒ 断点回退，等群列表到位后重拉
        if self.applyPendingRewindIfNeeded() {
            // 后面还会再跑一轮 ⇒ **不通知界面结束**，否则转圈会闪一下又出来
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.restartOfflineSync()
            }
            return
        }
        // 到这里才是真的全拉完了：通知界面收起「加载中」
        // ⚠️ 只有在**不再补洞**时才通知 + 重试解密：补洞循环每轮都通知一次的话，
        //    界面会跟着刷新好几次，看起来像「消息乱跳 / 重新加载」
        //    （用户 2026-11-05：「一次一次重连会导致消息重新刷新，看起来像消息错乱了」）。

        // 服务端「一次推送会跳过队列中间若干条」的兜底 —— **只能靠换新连接重扫**。
        //
        //    🔴 实证（用户 2026-11-05 三次冷启动日志）：
        //       · 第 1 次连接：推 27 条，中间跳过 11 条（8510968616… → 8510968714… 之间）；
        //       · 同连接再发 syncMsgReq：只把已推过的 27 条重推一遍，跳过的 11 条一条都不下来；
        //       · 重启 App 换新连接：那 11 条（logId 全小于断点）一次补回。
        //    ⇒ 所以不能用「同连接再补一轮」，必须断开重连，让服务端重扫队列。
        //       判定用「本条链收到几条」（补洞那轮断点不前进，但确实收到了数据）。
        if self.syncChainReceivedCount > 0,
           self.canKeepExtraScan() {
            self.beginOrContinueExtraScan()
            return
        }
        if self.syncChainReceivedCount > 0 {
            FZMLog("websocket \(self.url) 重扫补洞停止（次数 \(self.extraScanReconnectCount)/\(kMaxExtraScanReconnects)，"
                   + "累计 \(Int(self.extraScanElapsed))s/\(Int(kExtraScanMaxDuration))s）")
        }
        // 扫干净了：会话级状态归零，通知界面并统一重试解密
        self.resetExtraScanState()
        self.postSyncStateToUI(inProgress: false)
        DispatchQueue.global(qos: .utility).async {
            ChatManager.shared().retryAllUnparsedMsgs()
        }
    }

    /// 还能不能继续「重连重扫」：次数没到上限、总时长没超时
    private func canKeepExtraScan() -> Bool {
        guard self.extraScanReconnectCount < kMaxExtraScanReconnects else { return false }
        let start = self.extraScanStartTime
        guard start > 0 else { return true }
        return Date().timeIntervalSince1970 - start < kExtraScanMaxDuration
    }

    /// 累计补洞耗时（仅用于日志）
    private var extraScanElapsed: TimeInterval {
        let start = self.extraScanStartTime
        guard start > 0 else { return 0 }
        return Date().timeIntervalSince1970 - start
    }

    /// 记一次「重连重扫」：0.2 秒后断开，让服务端在新连接上重扫队列
    private func beginOrContinueExtraScan() {
        if self.extraScanStartTime <= 0 {
            self.extraScanStartTime = Date().timeIntervalSince1970
        }
        self.extraScanReconnectCount += 1
        FZMLog("websocket \(self.url) 本轮收到 \(self.syncChainReceivedCount) 条，"
               + "\(kExtraScanReconnectDelay) 秒后主动重连做第 "
               + "\(self.extraScanReconnectCount) 次重扫补洞（累计 \(Int(self.extraScanElapsed))s）")
        DispatchQueue.main.asyncAfter(deadline: .now() + kExtraScanReconnectDelay) { [weak self] in
            guard let self = self, self.isAvailable, !self.syncInProgress else { return }
            self.forceReconnectForOfflineSync()
        }
    }

    /// 整个补洞循环真正结束时，把会话级状态归零
    private func resetExtraScanState() {
        self.extraScanReconnectCount = 0
        self.extraScanStartTime = 0
    }

    /// 进入会话时调用：**主动重跑一次离线消息补拉**。
    ///
    /// ⚠️ 为什么需要它：`syncMsg()` 只在**鉴权成功**时跑一次。socket 一直连着（没有重连）时，
    /// 上一次同步只要提前收尾（或当时刚好没跟完），离线期间/漏掉的消息就再也不会自动补。
    /// 幂等：内部按当前断点增量拉、落库按 msgId 去重，重复调用没有副作用。
    func restartOfflineSync() {
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) restartOfflineSync 跳过：socket 不可用（未连接 / 未鉴权）")
            return
        }
        // 有消息因「本地还没有这个群」被跳过时，先用回退后的断点拉
        _ = self.applyPendingRewindIfNeeded()
        // 已经有同步链在跑就不重复发起
        guard !self.syncInProgress else {
            FZMLog("websocket \(self.url) restartOfflineSync 跳过：已有同步在进行")
            return
        }
        FZMLog("websocket \(self.url) 进入会话，重新补拉一轮离线消息")
        // 外部触发（进会话 / 鉴权 / 断点回退重启）视为新一轮，补洞循环重新计数
        self.resetExtraScanState()
        self.syncMsg()
    }
}

/// 一次同步最多补拉几轮（防服务端异常时无限请求）。
/// 每轮都必须「服务端回了 syncMsgReply 且断点确实前进」才会继续，所以放大上限是安全的。
/// 50 → 200（2026-11-02）：离线消息多的用户一轮拉不完，到上限只能等自动续，观感就是「加载不完」。
private let kMaxSyncMsgRounds = 200

/// 一轮补拉里，断点没前进时最多再确认几次（每次间隔 3s ⇒ 共约 15s）。
/// 断点改成「落库才推进」后（2026-11-03），每条消息要等「查公钥 → 解密 → 落库」，
/// 15s 足够；太长会让「服务端重推旧消息」的轮次白等。
private let kMaxSyncIdleChecks = 5

/// 补洞循环（重连重扫）期间，断点没动时最多确认几次（每次间隔 2s ⇒ 约 4s）。
/// 这时候收尾后立刻就要重连换新连接，本轮没落库完的消息下一轮会被服务端重推 + 去重，
/// 没必要像平时那样等十几秒（用户 2026-11-05：两轮之间要隔好几秒，就是等在这里）。
private let kMaxSyncIdleChecksInExtraScan = 1

/// 发出一轮 SyncMsgReq 后，多久没收到 reply 就认为链卡死（复位，等下次触发）。
/// 15 → 120（2026-11-03 用户要求）：真正卡死的判定放宽到 2 分钟；
/// 因为「断点还在前进」时会重新计时（见 `scheduleReplyTimeout`），
/// 这里只兜底「既没 reply、也没任何新消息」的极端情况，2 分钟不影响正常同步。
private let kSyncReplyTimeout: TimeInterval = 120

/// 达到最大轮次后隔多久自动续一轮（有积压时慢慢补齐，不无限快速请求）
/// 60 → 8（2026-11-02）：用户等不起一分钟，断点/去重都是幂等的，缩短无副作用
private let kSyncResumeDelay: TimeInterval = 8

/// 一条同步链收尾后，最多主动重连几次来「重扫队列补洞」。
/// 🔴 服务端一次推送会跳过队列中间若干条，且**同一条连接上补不回来**，
///    只有换新连接才会重扫（用户 2026-11-05 日志实证：27 条里跳 11 条，换连接后一次补回）。
/// ⚠️ 这是**安全阀**不是目标次数：只有「某条链一条都没收到」才正常结束，
///    每轮都还在收到就一直重连下去。600 条这种量级按每轮几十条算，几十次都算正常。
private let kMaxExtraScanReconnects = 60

/// 补洞循环的总时长安全阀（秒）。超时就收手，防止服务端异常时无限重连。
private let kExtraScanMaxDuration: TimeInterval = 180

/// 重连前等多久。只等落库/收尾这一拍，不要拖长
/// （用户 2026-11-05：「1.5 秒间隔太长了，几百条消息一次一次重连会一直刷新，看起来像消息错乱」）。
private let kExtraScanReconnectDelay: TimeInterval = 0.2

/// 「进会话回退断点补拉」的最大回退窗口（logId 单位）。
/// logId 是「毫秒时间戳 << 22」的雪花号 ⇒ 1 天 ≈ 86_400_000 * 2^22。
/// 作用是防止「某个群半年没打开」时，为了一条历史消息把服务器半年的消息整体重拉。
private let kSessionRewindMaxWindow: Int = 86_400_000 << 22

//MARK - SyncMsg 状态（extension 不能加存储属性，沿用同文件 `_ackDic` 的关联对象写法）
extension SocketManager {
    
    private struct SyncStateKey {
        static var requestedLogId = "SocketManager_SyncStateKey_RequestedLogId"
        static var inProgress = "SocketManager_SyncStateKey_InProgress"
        static var generation = "SocketManager_SyncStateKey_Generation"
        static var serverLogId = "SocketManager_SyncStateKey_ServerLogId"
        static var pendingRewindLogId = "SocketManager_SyncStateKey_PendingRewindLogId"
        static var lastRewindTarget = "SocketManager_SyncStateKey_LastRewindTarget"
        static var lastSessionRewindTarget = "SocketManager_SyncStateKey_LastSessionRewindTarget"
        static var deepResyncUntil = "SocketManager_SyncStateKey_DeepResyncUntil"
        static var lastDeepResyncAt = "SocketManager_SyncStateKey_LastDeepResyncAt"
        static var lastRecvSeq = "SocketManager_SyncStateKey_LastRecvSeq"
        static var gapReconnectCount = "SocketManager_SyncStateKey_GapReconnectCount"
        static var gapDetectedInChain = "SocketManager_SyncStateKey_GapDetectedInChain"
        static var startLogId = "SocketManager_SyncStateKey_StartLogId"
        static var chainReceivedCount = "SocketManager_SyncStateKey_ChainReceivedCount"
        static var roundReceivedCount = "SocketManager_SyncStateKey_RoundReceivedCount"
        static var extraScanCount = "SocketManager_SyncStateKey_ExtraScanCount"
        static var extraScanStartTime = "SocketManager_SyncStateKey_ExtraScanStartTime"
    }

    /// 「重连重扫补洞」这一轮循环的开始时间（0 = 当前不在循环里）。
    /// 用来做总时长安全阀：服务端要是每轮都漏，也不能一直重连下去。
    private var extraScanStartTime: TimeInterval {
        get { (objc_getAssociatedObject(self, &SyncStateKey.extraScanStartTime) as? TimeInterval) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.extraScanStartTime, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 这条同步链收到并进入落库流程的消息条数。
    ///
    /// 用它（而不是「断点有没有前进」）判断「这条链有没有收获」：
    /// 补洞那一次收到的消息 logId 全都**小于**当前断点，断点不会前进，
    /// 但确实补到了数据 ⇒ 还得再扫一轮。
    private var syncChainReceivedCount: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.chainReceivedCount) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.chainReceivedCount, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 本**轮**（一次 syncMsgReq 到它对应的 syncMsgReply 之间）新收到的消息条数。
    /// 在「收到帧」时 +1（不等落库）⇒ reply 一到就能立刻判断这条连接还有没有东西。
    private var syncRoundReceivedCount: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.roundReceivedCount) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.roundReceivedCount, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 本次启动里「主动重连换新连接重扫队列」已经做了几次
    private var extraScanReconnectCount: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.extraScanCount) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.extraScanCount, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 这条同步链**开始时的**断点。
    ///
    /// ⚠️ 不能拿 `syncRequestedLogId` 判「本轮有没有新增」：它每一轮都会被覆盖成最新断点，
    ///    收尾那一轮往往"断点没动"，于是 `serverSyncLogId == syncRequestedLogId`，
    ///    自动补拉永远不触发 ⇒ 一次进会话只拉到一批（用户 2026-11-05：66 条要进三次才拉全）。
    private var syncStartLogId: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.startLogId) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.startLogId, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 本连接上收到的最后一个下发帧的 seq（0 = 还没收到过 / 刚重新开始检查）
    private var lastRecvSeq: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.lastRecvSeq) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.lastRecvSeq, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 因「帧跳号」重连的次数（防服务端持续跳号时无限重连）
    private var gapReconnectCount: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.gapReconnectCount) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.gapReconnectCount, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 本轮同步里是否出现过「帧跳号」（收尾时用它决定要不要重连）
    private var gapDetectedInChain: Bool {
        get { (objc_getAssociatedObject(self, &SyncStateKey.gapDetectedInChain) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &SyncStateKey.gapDetectedInChain, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    /// 本轮 sync 请求发出去的断点（logId）
    private var syncRequestedLogId: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.requestedLogId) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.requestedLogId, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 是否有一条同步链在跑。
    /// 🔴 原来用 `syncRound`（一个 Int）既当「轮次」又当「是否在跑」，
    ///    鉴权 / 进会话 / 超时 / 收尾四个地方都会把它归零 ⇒ 互相把对方正在跑的链掐断，
    ///    表现就是「同步进行到一半莫名结束 / 卡住，要重进 App 才继续」。
    private var syncInProgress: Bool {
        get { (objc_getAssociatedObject(self, &SyncStateKey.inProgress) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &SyncStateKey.inProgress, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 供界面查询：这台服务器当前是否正在同步离线消息（决定聊天页要不要显示「加载中」）
    var isOfflineSyncing: Bool { return self.syncInProgress }

    /// 同步链的「代」。每次发起新链 +1；旧链上的定时器/回调发现代号对不上就自动失效，
    /// 不再互相干扰。
    private var syncGeneration: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.generation) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.generation, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    /// 这台服务器「本地已有 / 本连接收到过」的最大 logId（syncMsg 断点）。
    ///
    /// 首次取值时按「该服务器上的会话」从本地库算种子；之后只增不减，
    /// 由这台 socket 收到的每条消息（`noteReceivedLogId`）抬高。
    private var serverSyncLogId: Int {
        get {
            if let cached = objc_getAssociatedObject(self, &SyncStateKey.serverLogId) as? Int {
                return cached
            }
            let seed = ChatManager.shared().getLatestLogId(serverUrl: self.url.httpUrl)
            objc_setAssociatedObject(self, &SyncStateKey.serverLogId, seed, .OBJC_ASSOCIATION_RETAIN)
            return seed
        }
        set {
            // 先触发种子计算，避免「先 set 后 get」把种子（可能更大）覆盖掉
            let current = self.serverSyncLogId
            guard newValue > current else { return }
            objc_setAssociatedObject(self, &SyncStateKey.serverLogId, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// 新连接建立 / 连接断开时重置帧序号基线。
    ///
    /// 🔴 服务端的 `seq` 是**每条连接**独立从 1 递增的；换连接后不清零的话，
    ///    旧连接残留的 seq（比如 16）会让新连接推来的第一批帧（seq 1、2、3…）
    ///    被 `trackFrameSeq` 误判成「跳号」⇒ 收尾重连 ⇒ 越连越乱、同步链被反复打断，
    ///    离线消息永远拉不全（2026-11-05 日志实测：重推批次顺序 6→1→2→3…9→7→8 被判跳号）。
    func resetFrameSeqBaseline() {
        self.lastRecvSeq = 0
    }

    /// 这台服务器收到一条新消息（已去重）时抬高断点
    func noteReceivedLogId(_ logId: Int?) {
        guard let logId = logId, logId > 0 else { return }
        self.serverSyncLogId = logId
    }

    // MARK: - 断点回退（消息被本地逻辑跳过时用）

    /// 本轮同步里「因为本地还没有这个群」被跳过的消息 logId（取最小值）。
    /// **不能立刻回退断点**：同一批里后续消息会再把断点抬高，必须等整批同步收尾时统一回退。
    private var pendingRewindLogId: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.pendingRewindLogId) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.pendingRewindLogId, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 上一次回退到的断点（防止同一条消息反复回退 → 死循环）
    private var lastRewindTarget: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.lastRewindTarget) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.lastRewindTarget, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 上一次「进会话回退」用过的断点（同一个会话重复进页面时不再回退）
    private var lastSessionRewindTarget: Int {
        get { (objc_getAssociatedObject(self, &SyncStateKey.lastSessionRewindTarget) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.lastSessionRewindTarget, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 手动深度补拉的「详细日志窗口」截止时间（这段时间内收到的每条消息都打一行日志，便于定位）
    private var deepResyncUntil: TimeInterval {
        get { (objc_getAssociatedObject(self, &SyncStateKey.deepResyncUntil) as? TimeInterval) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.deepResyncUntil, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 上一次手动深度补拉的时间（节流：避免重试时反复往前退断点）
    private var lastDeepResyncAt: TimeInterval {
        get { (objc_getAssociatedObject(self, &SyncStateKey.lastDeepResyncAt) as? TimeInterval) ?? 0 }
        set { objc_setAssociatedObject(self, &SyncStateKey.lastDeepResyncAt, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 是否处于「手动深度补拉」的诊断窗口（`handleReceiveMsg` 用它打详细日志）
    var isInDeepResyncWindow: Bool {
        return Date().timeIntervalSince1970 < self.deepResyncUntil
    }

    /// 记下一条被跳过的消息。
    ///
    /// 场景：`handleReceiveMsg` 里「本地没有这个群」会把消息丢掉，而这条消息的 ack 已经回了
    /// （服务端不会重推）。断点一旦被后续消息抬高，这条就**永久缺失**（群聊没有服务端历史接口）。
    /// 所以记下它，等这轮同步收尾时把断点回退到它前面，群列表到位后重拉。
    func markSkippedLogId(_ logId: Int?) {
        guard let logId = logId, logId > 0 else { return }
        let target = logId - 1
        let existing = self.pendingRewindLogId
        if existing == 0 || target < existing {
            self.pendingRewindLogId = target
        }
        FZMLog("websocket \(self.url) 记下待回退断点 \(target)（logId=\(logId) 因本地缺群被跳过）")
    }

    /// 同步链收尾时把断点回退到「最小的被跳过点」；返回是否真的回退了
    @discardableResult
    private func applyPendingRewindIfNeeded() -> Bool {
        let target = self.pendingRewindLogId
        guard target > 0 else { return false }
        self.pendingRewindLogId = 0
        return self.rewindSyncLogId(to: target)
    }

    //MARK: - 帧序号跳号检测
    /// 检查服务端下发帧的 `seq` 是否连续。不连续 = 中间有几帧**本机根本没收到**。
    ///
    /// 为什么要它：服务端把离线消息逐条推下来，客户端只能看到「收到了哪些」——
    /// 中间少了几帧是**完全静默**的（既不会报错，也不会触发重推），
    /// 而 `syncMsg` 的断点会按「收到最后一条的 logId」继续往前走 ⇒ 那一段就跳过了。
    ///
    /// 2026-11-03 真机实测（两次同步同一个断点）：
    /// - 第一次（12:58）`seq 16 → 23`（缺 6 帧）、`seq 25 → 27`（缺 1 帧），共 7 条没下来；
    ///   同一条连接上再请求 `syncMsg`，服务端**直接回空**（它认为已经推完了）。
    /// - 重启 App（**新连接**）后，用**完全相同**的断点 `850353949977350144`，
    ///   那 7 条全部推下来了 —— 而且它们的 logId 比断点还小，
    ///   说明服务端根本不按 `logId` 过滤，只把「本连接还没确认的」下发。
    /// ⇒ 跳号后**回退断点没用**，必须换一条连接（`connectSocket()` 会先 disconnect 再 connect）。
    func trackFrameSeq(_ data: SocketData.UnWrapData) {
        let seq = data.seq
        guard seq > 0 else { return }
        let last = self.lastRecvSeq
        // 帧号回退 = 服务端在同一条连接上重新编号（实测会整批重推）⇒ 对齐基线
        if last > 0, seq <= last {
            self.lastRecvSeq = seq
            return
        }
        self.lastRecvSeq = seq
        guard last > 0, seq > last + 1 else { return }

        // 🔴 这里**只打日志**，不做任何补偿动作。
        //    原因（2026-11-05 真机日志实测）：服务端会在**同一条连接**上把整批帧从 seq=1 重推一遍，
        //    且重推批次本身是**乱序到达**的（2,3,4,5,6,9,7,8,12,10,11…）。
        //    原来的「跳号 → 回退断点 → 收尾重连」会被反复误触发：重连 3 次 → `notAnUpgrade(200)`
        //    → `Connection reset by peer`，连接直接被打坏，尾巴上的消息就再也收不到
        //    （用户 2026-11-05：实际 52 条只加载 38 条）。
        //    完整性改由这三层保证：syncMsg 断点续拉 / 进会话按未读回退重拉 / 收尾补拉。
        FZMLog("websocket \(self.url) 【帧序号】seq \(last) → \(seq)（仅记录，不做补偿）")
    }


    /// 进会话时把本服务器的同步断点回退到「会话本地 logId」，让服务端把这段**重新推一遍**。
    ///
    /// ⚠️ 服务端不按 logId 过滤，只推「本连接还没确认的」；所以回退断点本身不一定有用，
    ///    但配合收尾重连跑一轮新的 syncMsg 时，能覆盖「中间漏了、后面又有新消息」的情况。
    func rewindSyncLogIdForSession(_ sessionLogId: Int) {
        guard sessionLogId > 0 else { return }
        let current = self.serverSyncLogId
        guard current > 0 else { return }
        // 会话很久没消息时不要为了一条历史消息把整段服务器消息重拉：窗口上限 1 天
        let floorLogId = current - kSessionRewindMaxWindow
        let target = max(sessionLogId, floorLogId)
        guard target < current else { return }
        guard target != self.lastSessionRewindTarget else {
            FZMLog("websocket \(self.url) 进会话补拉：断点已回退到 \(target) 过，跳过")
            return
        }
        self.lastSessionRewindTarget = target
        objc_setAssociatedObject(self, &SyncStateKey.serverLogId, target, .OBJC_ASSOCIATION_RETAIN)
        FZMLog("websocket \(self.url) 进会话补拉：断点回退 \(current) → \(target)（会话本地 logId=\(sessionLogId)）")
    }

    /// 手动「深度补拉」：把本服务器的同步断点按天回退，让服务端把这段时间的消息**重新推一遍**。
    ///
    /// ⚠️ 为什么需要它：自动补拉（`rewindSyncLogIdForSession`）只会退到「会话本地最大 logId」。
    ///    如果缺的那条消息**后面还有本地消息落库**（会话中间缺一条），就覆盖不到 ——
    ///    用户 2026-11-02 反馈的 12:46 图片就是这种情况（后面已经有新消息进来了）。
    ///    这里直接把断点退到 N 天前，整段重拉。
    ///
    /// ⚠️ 副作用：这段时间里**本地手动删过的消息会重新出现**（msgId 去重对未来消息有效，对已删除的无效）。
    /// - Parameter days: 回退多少天（建议 1 / 3 / 7 / 30）
    /// - Returns: 是否真的开始了（socket 不可用 / 没有可用断点时返回 false）
    @discardableResult
    func deepResync(days: Int) -> Bool {
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) 手动补拉跳过：socket 不可用（未连接 / 未鉴权）")
            return false
        }
        let current = self.serverSyncLogId
        guard current > 0 else {
            FZMLog("websocket \(self.url) 手动补拉跳过：本地没有可用断点")
            return false
        }
        // 节流：重试 / 连点时不重复往前退断点
        let now = Date().timeIntervalSince1970
        guard now - self.lastDeepResyncAt > 60 else {
            FZMLog("websocket \(self.url) 手动补拉跳过：\(Int(now - self.lastDeepResyncAt))s 前刚补拉过")
            return true
        }
        self.lastDeepResyncAt = now
        // 开 5 分钟的详细日志窗口：这段时间内收到的每条消息都会打 【深度补拉】
        self.deepResyncUntil = now + 300
        // logId ≈ 毫秒时间戳 << 22 ⇒ N 天 ≈ (N * 86_400_000) << 22
        let step = (max(days, 1) * 86_400_000) << 22
        let target = max(0, current - step)
        self.lastSessionRewindTarget = target
        objc_setAssociatedObject(self, &SyncStateKey.serverLogId, target, .OBJC_ASSOCIATION_RETAIN)
        // 手动触发：作废旧的同步链，退断点后**断开重连**再拉。
        // 🔴 服务端只在「新连接」上重扫待投递队列（同连接只会重推已推过的），
        //    所以这里不能只 `syncMsg()`，必须换连接（用户 2026-11-05 要求：
        //    「修复聊天记录里的重新同步，也要断开连接重新扫，和自动补洞一样」）。
        self.pendingRewindLogId = 0
        self.syncGeneration += 1
        self.syncInProgress = false
        FZMLog("websocket \(self.url) 手动深度补拉：断点回退 \(current) → \(target)（\(days) 天）")
        // 手动修复重新给满「重连重扫」预算
        self.resetExtraScanState()
        self.forceReconnectForOfflineSync()
        return true
    }

    /// 把本服务器的同步断点回退到 `logId`，让下一次 `restartOfflineSync()` 重拉这一段。
    /// 落库按 msgId 去重，重拉不会产生重复消息。
    @discardableResult
    private func rewindSyncLogId(to logId: Int) -> Bool {
        guard logId >= 0 else { return false }
        // 同一条消息已经回退过还补不回来（群列表里就是没有它）⇒ 不再重复回退，避免每 2s 一轮的死循环
        guard logId != self.lastRewindTarget else {
            FZMLog("websocket \(self.url) 断点已回退过到 \(logId) 仍拿不到该群消息，先不再回退")
            return false
        }
        let current = self.serverSyncLogId
        guard logId < current else { return false }
        self.lastRewindTarget = logId
        objc_setAssociatedObject(self, &SyncStateKey.serverLogId, logId, .OBJC_ASSOCIATION_RETAIN)
        FZMLog("websocket \(self.url) syncMsg 断点回退：\(current) → \(logId)（有消息被跳过，等待重拉）")
        return true
    }
}

//MARK - 收到消息的「在途」去重
extension SocketManager {

    private struct DedupeKey {
        static var inFlight = "SocketManager_DedupeKey_InFlight"
    }

    /// 收消息是单线程串行（socket 回调），这里再加一把锁兜底
    private static let dedupeLock = NSLock()

    /// 一条消息从「收到」到「落库」之间最长要几秒（用户/群成员查询、图片下载解密），
    /// 服务端在这段时间重推同一条，如果只靠「查库去重」就会漏过去 ⇒
    /// 同一条消息被处理两遍：未读数 +2、聊天页插两条（用户 2026-11-02 反馈「6 条显示成 12 条」）。
    /// 这里用一个 60 秒窗口的在途表挡住重复投递。
    /// - Returns: true = 第一次收到；false = 已在途 / 刚处理过
    func markMsgIdHandled(_ msgId: String) -> Bool {
        guard !msgId.isEmpty else { return true }
        SocketManager.dedupeLock.lock()
        defer { SocketManager.dedupeLock.unlock() }
        var dic = (objc_getAssociatedObject(self, &DedupeKey.inFlight) as? [String: TimeInterval]) ?? [:]
        let now = Date().timeIntervalSince1970
        if let time = dic[msgId], now - time < 60 {
            return false
        }
        // 顺手清理过期项，避免长期运行无限增长
        if dic.count > 500 {
            dic = dic.filter { now - $0.value < 60 }
        }
        dic[msgId] = now
        objc_setAssociatedObject(self, &DedupeKey.inFlight, dic, .OBJC_ASSOCIATION_RETAIN)
        return true
    }

    /// 撤销在途标记：这把消息我们**没落库也没 ack**（比如「本地还没有这个群」），
    /// 服务端会重推，不能让在途表把它挡住。
    func unmarkMsgIdHandled(_ msgId: String) {
        guard !msgId.isEmpty else { return }
        SocketManager.dedupeLock.lock()
        defer { SocketManager.dedupeLock.unlock() }
        var dic = (objc_getAssociatedObject(self, &DedupeKey.inFlight) as? [String: TimeInterval]) ?? [:]
        dic.removeValue(forKey: msgId)
        objc_setAssociatedObject(self, &DedupeKey.inFlight, dic, .OBJC_ASSOCIATION_RETAIN)
    }
}

