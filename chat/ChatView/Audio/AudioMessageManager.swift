//
//  AudioMessageManager.swift
//  IM_SocketIO_Demo
//
//  Created by Wang on 2018/5/30.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

typealias CompletionCallBack = () -> Void
let maxRecordTime = 60.0
class AudioMessageManager: NSObject {
    var stopRecordCompletion:CompletionCallBack?
    var startRecordCompleted:CompletionCallBack?
    var cancelledDeleteCompletion:CompletionCallBack?
    
    
    var recorder:AVAudioRecorder?
    var recordPath:String?
    var recordDuration:String?
    var theTimer:Timer?
    var currentTimeInterval:TimeInterval?
    
    weak var updateMeterDelegate:IMRecordTipHub?
    
    var recordMaxTimeBlock : (()->())?
    
    override init() {
        super.init()
    }
    
    deinit {
        self.stopRecord()
        self.recordPath = nil
    }
    @objc func updateMeters() {
        guard let recorder = self.recorder else {return}
        self.recorder?.updateMeters()
        self.currentTimeInterval = recorder.currentTime
        
        let volumeMax = recorder.peakPower(forChannel: 0)
        FZMLog("录音分贝\(volumeMax)")
        self.updateMeterDelegate?.setVolume(pow(10, volumeMax * 0.05))
        if let currentTime = self.currentTimeInterval, maxRecordTime - currentTime < 11, currentTime <= maxRecordTime {
            self.updateMeterDelegate?.setCountDown(Int(maxRecordTime - currentTime))
        }
        if self.currentTimeInterval > maxRecordTime {
            self.stopRecord()
            self.getVoiceDuration(self.recordPath!)
            if self.stopRecordCompletion != nil {
                DispatchQueue.main.async(execute: self.stopRecordCompletion!)
                self.recorder?.updateMeters()
            }
            recordMaxTimeBlock?()
        }
    }
    
    func getVoiceDuration(_ recordPath:String) {
        do {
            let player:AVAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: recordPath))
            player.play()
            self.recordDuration = "\(player.duration)"
        } catch let error as NSError {
            FZMLog("get AVAudioPlayer is fail \(error)")
        }
    }
    
    func resetTimer() {
        if self.theTimer == nil {
            return
        } else {
            self.theTimer!.invalidate()
            self.theTimer = nil
        }
    }

    func cancelRecording() {
        if self.recorder == nil { return }
        
        if self.recorder?.isRecording != false {
            self.recorder?.stop()
        }
        
        self.recorder = nil
    }
    
    func stopRecord() {
        self.cancelRecording()
        self.resetTimer()
    }
    
    func startRecordingWithPath(_ path:String, startRecordCompleted:@escaping CompletionCallBack) {
        FZMLog("Action - startRecordingWithPath:")
        self.startRecordCompleted = startRecordCompleted
        self.recordPath = path
        
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 10.0, *) {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [.allowAirPlay, .allowBluetooth])
            } else {
                // Fallback on earlier versions
            }
        } catch let error as NSError {
            FZMLog("could not set session category")
            FZMLog(error.localizedDescription)
        }
        
        do {
            try audioSession.setActive(true)
        } catch let error as NSError {
            FZMLog("could not set session active")
            FZMLog(error.localizedDescription)
        }
        
        let recordSettings:[String : AnyObject] = [
            AVFormatIDKey: kAudioFormatLinearPCM as AnyObject,
            AVNumberOfChannelsKey: 1 as AnyObject,
            AVSampleRateKey : 8000.0 as AnyObject,
            AVLinearPCMBitDepthKey : 16 as AnyObject
        ]
        
        do {
            self.recorder = try AVAudioRecorder(url: URL(fileURLWithPath: self.recordPath!), settings: recordSettings)
            self.recorder!.delegate = self
            self.recorder!.isMeteringEnabled = true
            self.recorder!.prepareToRecord()
            self.recorder?.record(forDuration: 60.0)
        } catch let error as NSError {
            recorder = nil
            FZMLog(error.localizedDescription)
        }
        
        if ((self.recorder?.record()) != false) {
            self.resetTimer()
            self.theTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(AudioMessageManager.updateMeters), userInfo: nil, repeats: true)
        } else {
            FZMLog("fail record")
        }
        
        if self.startRecordCompleted != nil {
            DispatchQueue.main.async(execute: self.startRecordCompleted!)
        }
    }
    
    func finishRecordingCompletion() {
        self.stopRecord()
        self.getVoiceDuration(self.recordPath!)
        
        if self.stopRecordCompletion != nil {
            DispatchQueue.main.async(execute: self.stopRecordCompletion!)
        }
    }
    
    func cancelledDeleteWithCompletion() {
        self.stopRecord()
        if self.recordPath != nil {
            let fileManager:FileManager = FileManager.default
            if fileManager.fileExists(atPath: self.recordPath!) == true {
                do {
                    try fileManager.removeItem(atPath: self.recordPath!)
                } catch let error as NSError {
                    FZMLog("can no to remove the voice file \(error.localizedDescription)")
                }
            } else {
                if self.cancelledDeleteCompletion != nil {
                    DispatchQueue.main.async(execute: self.cancelledDeleteCompletion!)
                }
            }
            
        }
    }
    
    
    
}
extension AudioMessageManager:  AVAudioPlayerDelegate{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        FZMLog("finished playing \(flag)")
        
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let e = error {
            FZMLog("\(e.localizedDescription)")
        }
    }
}
extension AudioMessageManager : AVAudioRecorderDelegate {
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
