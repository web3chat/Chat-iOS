//
//  DownloadManager.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/3.
//

import Foundation
import RxSwift

class DownloadManager: NSObject {
    var msgVM: FZMMessageBaseVM
    
    private let bag = DisposeBag.init()
    
    let fileDownloadFailedSubject = PublishSubject<Message>.init()// 下载失败订阅
    let fileDownloadSucceedSubject = PublishSubject<Message>.init()// 下载成功订阅
    let fileDownloadProgressSubject = PublishSubject<CGFloat>.init()// 下载进度订阅
    
    init(with vm: FZMMessageBaseVM) {
        self.msgVM = vm
        super.init()
    }
    
    //下载文件 语音 视频 文件
    func downloadData() {
        var needDownload = false
        switch self.msgVM.message.msgType {
        case .video, .file:
            needDownload = true
        default:
            needDownload = false
        }
        // 判断文件是否为需要下载的类型 + 本地是否已有缓存，避免重复下载
        guard needDownload, !msgVM.isLocalFileExist else {
            return
        }
        // 文件url地址
        guard let fileUrl = msgVM.message.msgType.fileUrl, !fileUrl.isBlank else {
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

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
    // 语音、视频、文件下载回调
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        let curMsg = self.msgVM.message
        
        let fileData : Data = FileManager.default.contents(atPath: location.path)!
//        let address = curMsg.sessionId.isPersonChat ? curMsg.fromId : curMsg.targetId
        var address = curMsg.targetId
        if curMsg.sessionId.isPersonChat {
            address = curMsg.fromId == LoginUser.shared().address ? curMsg.targetId : curMsg.fromId
        }
        ChatManager.getPublickey(by: address , isGetUserKey: curMsg.sessionId.isPersonChat) { [weak self] (pubkey) in
            
            var fromFilePath = location.path
            
            let filePath = self?.msgVM.localFilePath ?? FZMMessageBaseVM.getFilePath(with: curMsg)
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
                
                self?.msgVM.isLocalFileExist = true
                
                if case .video = self?.msgVM.message.msgType {// 视频
                    // 获取视频封面
                    self?.getVideoCoverImage(with: URL.init(fileURLWithPath: filePath), fileName: fileName)
                }
                
                // 发出下载成功订阅
                self?.fileDownloadSucceedSubject.onNext(curMsg)
                
            } else {
                FZMLog("下载文件转存到本地沙盒失败 message \(curMsg)")
                
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
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        var progress: CGFloat = 0
        let num1: CGFloat = CGFloat(totalBytesWritten)
        let num2: CGFloat = CGFloat(totalBytesExpectedToWrite)
        progress = CGFloat(num1 / num2)
        
        // 下载进度订阅通知
        self.fileDownloadProgressSubject.onNext(progress)
    }
}
