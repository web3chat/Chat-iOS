//
//  OSS.swift
//  xls
//
//  Created by 王俊豪 on 2021/6/9.
//  Copyright © 2021 王俊豪. All rights reserved.
//  阿里云
//

import UIKit

typealias OSSProgressBlock = (Float) -> ()
typealias OSSDownloadSuccessBlock = (Data) -> ()
typealias OSSUploadSuccessBlock = (String) -> ()
typealias OSSFailureBlock = (Error) -> ()

public class OSS: NSObject,URLSessionDelegate {
    
    var client : OSSClient!
    private static let sharedInstance = OSS()
    private override init() {
//        #if DEBUG
//        OSSLog.enable()
//        #endif
        super.init()
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            self!.getStsToken()
        }
    }
    
    class func shared() -> OSS {
        return sharedInstance
    }
    
    class func launchClient() {
        _ = self.shared()
    }
    
    func getStsToken() {
        let federationProvider: OSSFederationCredentialProvider = OSSFederationCredentialProvider(federationTokenGetter: { () ->OSSFederationToken? in
            
            let tcs = OSSTaskCompletionSource<AnyObject>.init()
            Provider.request(TokenAPI.OSSToken, successBlock: { (json) in
                tcs.setResult(json as AnyObject)
            }) { (error) in
                tcs.setError(error)
            }
            
            tcs.task.waitUntilFinished()
            
            if tcs.task.error != nil {
                return nil
            } else {
                let json:JSON = JSON(tcs.task.result as AnyObject)
                
                print("Json Object:", json as Any)
                
                let credentials = TokenCredentials.init(json: json["Credentials"])
                
                let token = OSSFederationToken()
                
                token.tAccessKey = credentials.AccessKeyId
                token.tSecretKey = credentials.AccessKeySecret
                token.tToken = credentials.SecurityToken
                
                return token
            }
        })
        
        client = OSSClient.init(endpoint: OSS_End_Point, credentialProvider: federationProvider)
    }
    
    func download(with fileUrl: URL, progress: OSSProgressBlock? = nil, success: OSSDownloadSuccessBlock?, failure: OSSFailureBlock?){
        let get = OSSGetObjectRequest.init()
        get.bucketName = OSS_Buket
        var path = fileUrl.path
        if let first = path.first,first == "/" {
            let index = path.index(path.startIndex, offsetBy: 1)
            path = String(path[index...])
        }
        get.objectKey = path
        get.downloadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                progress?(Float(totalBytesSent)/Float(totalBytesExpectedToSend))
            }
        }
        let task = client.getObject(get)
        task.continue ({ (backTask) -> Any? in
            DispatchQueue.main.async {
                if let error = backTask.error {
                    failure?(error)
                }else if let result = backTask.result as? OSSGetObjectResult {
                    success?(result.downloadedData)
                }
            }
        })
    }
    
    //上传图片
    func uploadImage(file: Data, progress: OSSProgressBlock? = nil, success: OSSUploadSuccessBlock?, failure: OSSFailureBlock?) {
        let put = OSSPutObjectRequest.init()
        put.bucketName = OSS_Buket
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/picture/\(str1)/\(str2)_\(uid).jpg"
        put.objectKey = path
        put.uploadingData = file
        put.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                progress?(Float(totalBytesSent)/Float(totalBytesExpectedToSend))
            }
        }
        let task = client.putObject(put)
        task.continue ({ (backTask) -> Any? in
            DispatchQueue.main.async {
                if let error = backTask.error {
                    self.getStsToken()
                    failure?(error)
                }else if let coverPath = self.client.presignPublicURL(withBucketName: OSS_Buket, withObjectKey: path).result as? String {
                    FZMLog("OSS uploadImage path---\(coverPath)")
                    success?(coverPath)
                }
            }
        })
    }
    
    //上传音频，目前只支持AMR格式
    func uploadVoice(file: Data, progress: OSSProgressBlock? = nil, success: OSSUploadSuccessBlock?, failure: OSSFailureBlock?) {
        let put = OSSPutObjectRequest.init()
        put.bucketName = OSS_Buket
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/voice/\(str1)/\(str2)_\(uid).amr"
        put.objectKey = path
        put.uploadingData = file
        put.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                progress?(Float(totalBytesSent/totalBytesExpectedToSend))
            }
        }
        let task = client.putObject(put)
        task.continue ({ (backTask) -> Any? in
            DispatchQueue.main.async {
                if let error = backTask.error {
                    failure?(error)
                }else if let coverPath = self.client.presignPublicURL(withBucketName: OSS_Buket, withObjectKey: path).result as? String {
                    success?(coverPath)
                }
            }
        })
    }
    
    func uploadVideo(filePath: String, progress: OSSProgressBlock? = nil, success: OSSUploadSuccessBlock?, failure: OSSFailureBlock?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/video/\(str1)/\(str2)_\(uid).\((filePath as NSString).components(separatedBy: ".").last ?? "mp4")"
        self.resumableUpload(filePath: filePath, severPath: path, progress: progress, success: success, failure: failure)
    }
    
    func uploadFile(filePath: String, progress: OSSProgressBlock? = nil, success: OSSUploadSuccessBlock?, failure: OSSFailureBlock?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/file/\(str1)/\(str2)_\(uid).\((filePath as NSString).components(separatedBy: ".").last ?? "")"
        self.resumableUpload(filePath: filePath, severPath: path, progress: progress, success: success, failure: failure)
    }
    
    func resumableUpload(filePath: String, severPath: String, progress: OSSProgressBlock? = nil, success: OSSUploadSuccessBlock?, failure: OSSFailureBlock?) {
        let resumableUpload = OSSResumableUploadRequest.init()
        resumableUpload.bucketName = OSS_Buket
        resumableUpload.objectKey = severPath
        resumableUpload.uploadingFileURL = URL.init(fileURLWithPath: filePath)
        resumableUpload.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                progress?(Float(totalBytesSent/totalBytesExpectedToSend))
            }
        }
        if let cachesDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            resumableUpload.recordDirectoryPath = cachesDir
        }
        let resumeTask = client.resumableUpload(resumableUpload)
        resumeTask.continue ({ (backTask) -> Any? in
            DispatchQueue.main.async {
                if let error = backTask.error {
                    failure?(error)
                }else if let coverPath = self.client.presignPublicURL(withBucketName: OSS_Buket, withObjectKey: severPath).result as? String {
                    success?(coverPath)
                }
            }
        })
    }
}



