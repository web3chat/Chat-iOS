//
//  ChatManager+Burn.swift
//  chat
//
//  阅后即焚：待确认队列（落库）+ 焚毁处理
//  文档：《阅后即焚_App对接文档》
//

import Foundation
import WCDBSwift
import Kingfisher

extension ChatManager {

    // MARK: - 待确认队列

    /// 打开详情即落库待确认（防止只写内存丢失；接口幂等，可重复补发）
    func enqueueBurnPending(logId: Int, targetId: String) {
        guard logId > 0, !targetId.isEmpty else { return }
        let record = BurnPendingDB(logId: logId, targetId: targetId, openedAt: Date.timestamp)
        DBManager.shared().insertOrReplace(intoTable: .burnPending, list: [record])
        FZMLog("阅后即焚：写入待确认 logId=\(logId) targetId=\(targetId)")
    }

    /// 清除待确认记录（confirm 成功 / 收到焚毁信令 / 气泡已换）
    func clearBurnPending(logId: Int) {
        DBManager.shared().delete(fromTable: .burnPending) { (constraint) in
            constraint.condition = BurnPendingDB.Properties.logId.is(logId)
        }
    }

    /// 待确认记录列表
    func burnPendingList() -> [BurnPendingDB] {
        return DBManager.shared().getObjects(fromTable: .burnPending, constraintBlock: nil)
    }

    /// 启动补发待确认（接口幂等）
    func resendPendingBurnConfirms() {
        guard LoginUser.shared().isLogin else { return }
        let list = self.burnPendingList()
        guard !list.isEmpty else { return }
        FZMLog("阅后即焚：启动补发待确认 \(list.count) 条")
        for record in list {
            ChatRecordAPI.burnConfirm(targetId: record.targetId, logId: record.logId, successBlock: { [weak self] (_) in
                self?.clearBurnPending(logId: record.logId)
            }, failureBlock: { (error) in
                FZMLog("阅后即焚补发失败 logId=\(record.logId): \(error.localizedDescription)")
            })
        }
    }

    /// 收方关闭详情后调用焚毁确认
    func confirmBurn(logId: Int, targetId: String, success: (() -> Void)? = nil) {
        guard logId > 0, !targetId.isEmpty else {
            success?()
            return
        }
        ChatRecordAPI.burnConfirm(targetId: targetId, logId: logId, successBlock: { [weak self] (_) in
            self?.clearBurnPending(logId: logId)
            FZMLog("阅后即焚：确认成功 logId=\(logId)")
            success?()
        }, failureBlock: { (error) in
            FZMLog("阅后即焚确认失败 logId=\(logId): \(error.localizedDescription)")
        })
    }

    // MARK: - 焚毁落库

    /// 收到 reason=burned 信令：气泡换「已阅后焚毁」、删本地媒体、清待确认
    @discardableResult
    func handleBurnInDB(logId: Int) -> Message? {
        // 清待确认队列
        self.clearBurnPending(logId: logId)
        // 【诊断】发送方偶发不消失：这条日志能区分「信令到了但本地查不到」和「信令根本没到」
        FZMLog("【焚毁】收到 burned 信令 logId=\(logId)")

        let dbMessages: [MessageDB] = DBManager.shared().getObjects(fromTable: .message) { constraint in
            constraint.condition = MessageDB.Properties.logId.is(logId)
            constraint.limit = 1
        }
        guard let dbMsg = dbMessages.first else {
            FZMLog("【焚毁】本地未找到 logId=\(logId) 的消息（命中 \(dbMessages.count) 条）")
            return nil
        }
        var msg = Message(with: dbMsg)

        // 删除本地媒体缓存（图片/语音/视频/文件）
        self.removeLocalMedia(for: msg)

        // 变成「已阅后焚毁」通知消息（与「撤回了一条消息」区分；不出「重新编辑」）
        msg.msgType = Message.MsgType.init(notify: L("已阅后焚毁"), type: 8, groupId: Int(),
                                           operatorId: nil, groupname: nil, inviter: nil, members: nil,
                                           mutetype: nil, newOwner: nil, revokedContent: nil)
        msg.isBurn = true
        // 更新数据库
        self.update(msg: msg)
        return msg
    }

    /// 删除消息对应的本地媒体缓存
    private func removeLocalMedia(for msg: Message) {
        switch msg.msgType {
        case .image:
            if let cacheKey = msg.msgType.cachekey {
                ChatMediaCache.removeImage(forKey: cacheKey)
            }
        case .audio, .video, .file:
            let path = FZMMessageBaseVM.getFilePath(with: msg)
            if FZMLocalFileClient.shared().isFileExists(atPath: path) {
                _ = FZMLocalFileClient.shared().deleteFile(atFilePath: path)
            }
        default:
            break
        }
    }
}
