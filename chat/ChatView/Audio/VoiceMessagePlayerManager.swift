//
//  VoiceMessagePlayerManager.swift
//  IM_SocketIO_Demo
//
//  Created by Wang on 2018/5/31.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import AVFoundation
import TSVoiceConverter
import RxSwift

typealias VoicePlayHandler = ()->()

let PlayVoiceModeKey = "PlayVoiceModeKey"

enum FZMAudioPlayType {
    case playAndRecord
    case playBack
}

enum FZMVoicePalyState {
    case start
    case finish
    case failed
}

class VoiceMessagePlayerManager: NSObject {
    static let singleTon = VoiceMessagePlayerManager()
    fileprivate var player: AVAudioPlayer?
    private var isPlayingVoiceMsg: Message?
    let voicePalyStateSubject = BehaviorSubject<(String,FZMVoicePalyState)?>.init(value: nil)
    
    static func shared() -> VoiceMessagePlayerManager {
        return singleTon
    }
    fileprivate override init() {
        super.init()
        
    }
    // test player
    
    func playVoice(_ recordPath:String, suspendBlock: (()->())?) {
        do {
            FZMLog("\(recordPath)")
            let player:AVAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: recordPath))
            player.volume = 1
            player.delegate = self
            player.numberOfLoops = 0
            player.prepareToPlay()
            player.play()
            
        } catch let error as NSError {
            FZMLog("get AVAudioPlayer is fail \(error)")
        }
    }
 
    func playVoiceAction(_ fileUrl: String) {
        do {
            self.player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileUrl))
            self.player?.volume = 1
            self.player?.delegate = self
            self.player?.numberOfLoops = 0
            self.player?.prepareToPlay()
            self.player?.play()
            self.voicePalyStateSubject.onNext((self.isPlayingVoiceMsg?.msgId ?? "",.start))
            UIApplication.shared.isIdleTimerDisabled = true
        } catch let error as NSError {
            APP.shared().showToast("语音消息播放失败")
            FZMLog("get AVAudioPlayer is fail \(error)")
        }
    }
    
    func playVoice(msg: Message) {
        //wjhTODO
        // 语音消息未读状态改为已读
        ChatManager.shared().update(mes: msg.msgId, isRead: true)
        
        self.setAudioSession()
        self.stopVoice()
        if msg.msgId == isPlayingVoiceMsg?.msgId {
            isPlayingVoiceMsg = nil
            return
        }
        isPlayingVoiceMsg = msg
        
        // 修改播放标识为已读
        
        let filePath = DocumentPath.appendingPathComponent("Voice/WavFile/\(msg.msgType.cachekey ?? "").wav")// 待播放语音的本地路径（传输用amr格式，播放用wav格式）
        
        if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
            // 本地有缓存文件
            self.playVoiceAction(filePath)
        }
        
//        let voiceUrl = msg.msgType.url
//        let fileUrl = msg.fromId//msg.body.localWavPath
//
//        if FZMLocalFileClient.shared().haveFile(with: .wav(fileName: fileUrl.fileName())) {
//            guard let data = FZMLocalFileClient.shared().readData(fileName: .wav(fileName: fileUrl.fileName())) else { return }
//            self.playVoiceAction(data)
//        }
    }
    
    func stopVoice() {
        self.voicePalyStateSubject.onNext((self.isPlayingVoiceMsg?.msgId ?? "",.finish))
        self.player?.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func setAudioSession() {
        let session = AVAudioSession.sharedInstance()
        if FZM_UserDefaults.bool(forKey: PlayVoiceModeKey) {
            if #available(iOS 10.0, *) {
                try? session.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [.allowAirPlay, .allowBluetooth])
            } else {
                // Fallback on earlier versions
            }
        }else {
            if #available(iOS 10.0, *) {
                try? session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.allowAirPlay, .allowBluetooth])
            } else {
                // Fallback on earlier versions
            }
        }
        try? session.setActive(true)
    }
    
    func exchangePlayMode() {
        if FZM_UserDefaults.bool(forKey: PlayVoiceModeKey) {
            FZM_UserDefaults.set(false, forKey: PlayVoiceModeKey)
//            FZM_UserDefaults.synchronize()
        }else {
            FZM_UserDefaults.set(true, forKey: PlayVoiceModeKey)
//            FZM_UserDefaults.synchronize()
        }
    }
    
    var playMode : Bool {
        return FZM_UserDefaults.bool(forKey: PlayVoiceModeKey)
    }
    
    func vibrateAction() {
        AudioServicesPlaySystemSound(1520)
    }
    
    func alertAction() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        AudioServicesPlaySystemSound(1007)
    }
}

extension VoiceMessagePlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.stopVoice()
        //wjhTODO 自动播放下一条未读语音信息
//        if let isPlayingVoiceMsg = self.isPlayingVoiceMsg, isPlayingVoiceMsg.isOutgoing == false,
//           let nextVoiceMsg = ChatManager.getNextUnreadVoiceMsg(timestamp: isPlayingVoiceMsg.datetime, type: isPlayingVoiceMsg.channelType, msgType: isPlayingVoiceMsg.msgType, sessionId: isPlayingVoiceMsg.sessionId.idValue)  {
//            self.playVoice(msg: nextVoiceMsg)
////            nextVoiceMsg.isRead = true
//            ChatManager.shared().update(mes: nextVoiceMsg.msgId, isRead: true)
////            ChatManager.shared().save([nextVoiceMsg])
//        } else {
            isPlayingVoiceMsg = nil
//        }
    }
}

protocol VoicePlayerDelegate: AnyObject {
    func voiceDidStartPlay(url: String, path: String)
    func voiceDidFinishPlay(url: String, path: String)
    func voiceDidFailPlay(url: String, path: String)
}

//MARK: socket连接消息
class WeakVoicePlayerDelegate: NSObject {
    weak var delegate: VoicePlayerDelegate?
    required init(delegate: VoicePlayerDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
