//
//  OBS.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/8.
//  Copyright © 2021 王俊豪. All rights reserved.
//  华为云
//


import UIKit
import OBS

typealias OBSProgressBlock = (Float) -> ()
typealias OBSDownloadSuccessBlock = (Data) -> ()
typealias OBSUploadSuccessBlock = (String) -> ()
typealias OBSFailureBlock = (Error) -> ()

public class OBS: NSObject,URLSessionDelegate {
    
    var client : OBSClient!
    private static let sharedInstance = OBS()
    private override init() {
//        #if DEBUG
//        OBSLoggingEnabled()
//        #endif
        
//        let credentailProvider = OBSStaticCredentialProvider.init(accessKey: OBS_Access_Key, secretKey: OBS_Access_Secret)
//        let conf = OBSServiceConfiguration.init(urlString: OBS_EDN_POINT, credentialProvider: credentailProvider)
//        client = OBSClient.init(configuration: conf)
        super.init()
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            self!.getStsToken()
        }
    }
    
    class func shared() -> OBS {
        return sharedInstance
    }
    
    class func launchClient() {
        _ = self.shared()
    }
    
    func getStsToken() {
        
//        let tcs = OSSTaskCompletionSource<AnyObject>.init()
        let tcs = OBSBFTaskCompletionSource<AnyObject>.init()
        Provider.request(TokenAPI.OBSToken, successBlock: { (json) in
            tcs.set(result: json as AnyObject)
//            tcs.setResult(json as AnyObject)
        }) { (error) in
            tcs.set(error: error)
//            tcs.setError(error)
        }
        
        tcs.task.waitUntilFinished()
        
        if tcs.task.error != nil {
            return
        } else {
            let json:JSON = JSON(tcs.task.result as AnyObject)
            
            print("Json Object:", json as Any)
            
            let credentials = TokenCredentials.init(json: json["Credentials"])
            
            let tAccessKey = credentials.AccessKeyId
            let tSecretKey = credentials.AccessKeySecret
            let tToken = credentials.SecurityToken
            
            
//            let credentailProvider = OBSStaticCredentialProvider(accessKey: tAccessKey, secretKey: tSecretKey)
            
            let credentailProvider = OBSSTSCredentialProvider(accessKey: tAccessKey, secretKey: tSecretKey, stsToken: tToken, authVersion: .V4)
            let conf = OBSServiceConfiguration.init(urlString: OBS_EDN_POINT, credentialProvider: credentailProvider)
            client = OBSClient.init(configuration: conf)
        }
    }
    
    /*
    func download(with fileUrl: URL, progress: OBSProgressBlock? = nil, success: OBSDownloadSuccessBlock?, failure: OBSFailureBlock?){
        let get = OBSGetObjectRequest.init()
        get.bucketName = OBS_Buket
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
                }else if let result = backTask.result as? OBSGetObjectResult {
                    success?(result.downloadedData)
                }
            }
        })
    }*/
    
    //上传图片
    func uploadImage(file: Data, progress: OBSProgressBlock? = nil, success: OBSUploadSuccessBlock?, failure: OBSFailureBlock?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/picture/\(str1)/\(str2)_\(uid).jpg"
        let request = OBSPutObjectWithDataRequest.init(bucketName: OBS_BUCKET_NAME, objectKey: path, uploadData: file)
        
        request?.uploadProgressBlock = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                progress?(Float(totalBytesSent)/Float(totalBytesExpectedToSend))
            }
        }
        
        //FIXME: 崩溃
        /**
         * Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[OBSSTSCredentialProvider setProtocolType:]: unrecognized selector sent to instance 0x28390f150'
         terminating with uncaught exception of type NSException
         */
        client.putObject(request) { response, error in
            if let error = error {
                FZMLog("error---\(error)")
                failure?(error)
            } else {
                FZMLog("resopnse---\(String(describing: response))")
            }
        }
        
//        client.putObject(request, completionHandler: { (resopnse, error) -> Void in
//            if let error = error {
//                failure?(error)
//            } else {
//                FZMLog("resopnse---\(resopnse)")
//            }
//        })
        
//        let task = client.putObject(put)
//        task.continue ({ (backTask) -> Any? in
//            DispatchQueue.main.async {
//                if let error = backTask.error {
//                    failure?(error)
//                }else if let coverPath = self.client.presignPublicURL(withBucketName: OBS_Buket, withObjectKey: path).result as? String {
//                    success?(coverPath)
//                }
//            }
//        })
    }
    /*
    //上传音频，目前只支持AMR格式
    func uploadVoice(file: Data, progress: OBSProgressBlock? = nil, success: OBSUploadSuccessBlock?, failure: OBSFailureBlock?) {
        let put = OBSPutObjectRequest.init()
        put.bucketName = OBS_Buket
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
                }else if let coverPath = self.client.presignPublicURL(withBucketName: OBS_Buket, withObjectKey: path).result as? String {
                    success?(coverPath)
                }
            }
        })
    }
    
    func uploadVideo(filePath: String, progress: OBSProgressBlock? = nil, success: OBSUploadSuccessBlock?, failure: OBSFailureBlock?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/video/\(str1)/\(str2)_\(uid).\((filePath as NSString).components(separatedBy: ".").last ?? "mp4")"
        self.resumableUpload(filePath: filePath, severPath: path, progress: progress, success: success, failure: failure)
    }
    
    func uploadFile(filePath: String, progress: OBSProgressBlock? = nil, success: OBSUploadSuccessBlock?, failure: OBSFailureBlock?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let uid = LoginUser.shared().address
        let path = "zk-retail/file/\(str1)/\(str2)_\(uid).\((filePath as NSString).components(separatedBy: ".").last ?? "")"
        self.resumableUpload(filePath: filePath, severPath: path, progress: progress, success: success, failure: failure)
    }
    
    func resumableUpload(filePath: String, severPath: String, progress: OBSProgressBlock? = nil, success: OBSUploadSuccessBlock?, failure: OBSFailureBlock?) {
        let resumableUpload = OBSResumableUploadRequest.init()
        resumableUpload.bucketName = OBS_Buket
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
                }else if let coverPath = self.client.presignPublicURL(withBucketName: OBS_Buket, withObjectKey: severPath).result as? String {
                    success?(coverPath)
                }
            }
        })
    }*/
}



