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
    
    //下载文件 语音 视频 文件
    func downloadData() {
        var needDownload = false
        switch self.message.msgType {
        case .video, .file,.audio:
            needDownload = true
        default:
            needDownload = false
        }
        // 判断文件是否为需要下载的类型 + 本地是否已有缓存，避免重复下载
        guard needDownload, !isLocalFileExist else {
            return
        }
        // 文件url地址
        guard let fileUrl = self.message.msgType.fileUrl, !fileUrl.isBlank else {
            APP.shared().showToast("数据加载失败")
            return
        }
        let downloadTask: URLSessionDownloadTask
        let urlString: String = fileUrl
        let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        downloadTask = session.downloadTask(with: urlString.url!)
        downloadTask.resume()
    }
}

extension FZMMessageBaseVM: URLSessionDelegate, URLSessionDownloadDelegate {
    // 语音、视频、文件下载回调
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        let curMsg = self.message
        
        let fileData : Data = FileManager.default.contents(atPath: location.path)!
//        let address = curMsg.sessionId.isPersonChat ? curMsg.fromId : curMsg.targetId
        var address = curMsg.targetId
        if curMsg.sessionId.isPersonChat {
            address = curMsg.fromId == LoginUser.shared().address ? curMsg.targetId : curMsg.fromId
        }
        ChatManager.getPublickey(by: address , isGetUserKey: curMsg.sessionId.isPersonChat) { [weak self] (pubkey) in
            
            var fromFilePath = location.path
            
            let filePath = self?.localFilePath ?? FZMMessageBaseVM.getFilePath(with: curMsg)
            var fileName = "\(curMsg.msgType.cachekey ?? "")"
            if case .file = curMsg.msgType {
                if let name = curMsg.msgType.fileName {
                    fileName = fileName + "/\(name)"
                }
            }
            
            if !pubkey.isBlank {// 有公钥需解密
                let semaphore = DispatchSemaphore.init(value: 0)
                DispatchQueue.global().async {
                    // 解密
                    let decryptData = ChatManager.decryptUploadData(fileData, publickey: pubkey, isEncryptPersionChatData: curMsg.sessionId.isPersonChat)
                    
                    // 转存本地临时文件
                    if decryptData.count > 0, let tmpFilePath = FZMLocalFileClient.shared().createFile(with: .tmp(fileName: fileName)), FZMLocalFileClient.shared().saveData(decryptData, filePath: tmpFilePath) {
                        fromFilePath = tmpFilePath
                    }
                    semaphore.signal()
                }
                semaphore.wait()//等待异步任务执行完成才可以继续执行
                FZMLog("文件解密结束，继续下一步操作")
            }
            
            defer {
                // 清除零时文件
                let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: fromFilePath)
            }
            
            // 转存成功
            if FZMLocalFileClient.shared().move(fromFilePath: fromFilePath, toFilePath: filePath) {
                
                self?.isLocalFileExist = true
                
                if case .video = self?.message.msgType {// 视频
                    // 获取视频封面
                    self?.getVideoCoverImage(with: URL.init(fileURLWithPath: filePath), fileName: fileName)
                    
                    // 记录视频本地路径，播放视频页面保存时使用
                    self?.saveVideoToAlUrl = filePath
                }
                
                // 发出下载成功订阅
                self?.fileDownloadSucceedSubject.onNext(curMsg)
                
            } else {
//                APP.shared().showToast("下载失败")
                FZMLog("下载文件保存到本地沙盒失败 message \(curMsg)")
                
                // 发出下载失败订阅
                self?.fileDownloadFailedSubject.onNext(curMsg)
            }
        }
    }
    
    // 从下载的视频文件中获取视频封面
    private func getVideoCoverImage(with url: URL, fileName: String) {
        // 获取视频第一帧作为封面
        
        UIImage.getVideoCropPicture(url) { (image) in
            guard let image = image else {
                APP.shared().showToast("视频封面获取失败")
                FZMLog("视频封面获取出错")
                return
            }
            // 缓存封面图片
            ImageCache.default.store(image, forKey: fileName)
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
//                ImageCache.default.store(image, forKey: fileName)
//            }
//        } catch let error {
//            print(error)
//            APP.shared().showToast("视频封面获取失败")
//            FZMLog("视频封面获取出错")
//        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
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
        // 下载进度订阅通知
        self.fileDownloadProgressSubject.onNext(progress)
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
        let coinArray = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID()
        let arr = NSArray(array: coinArray!)
        let coinName = msg.msgType.coinName
        var localCoin = LocalCoin.init()
        for data  in arr {
            let coin = data as! LocalCoin
            if coin.coin_type == coinName {
                localCoin = coin
            }
        }
        return localCoin
    }
    
}


