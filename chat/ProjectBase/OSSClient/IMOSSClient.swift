//
//  IMOSSClient.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/19.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import AliyunOSSiOS

typealias OSSFileUploadHandler = (String?, Bool) -> ()

typealias OSSFileDownloadHandler = (Data?, Bool) -> ()

typealias OSSProgressHandler = (Float) -> ()

public class IMOSSClient: NSObject, URLSessionDelegate {
    
    var client : OSSClient?
    private static let sharedInstance = IMOSSClient.init()
    class func shared() -> IMOSSClient {
        return sharedInstance
    }
    class func launchClient() {
        _ = self.shared()
    }
    
    /*
    private override init() {
        #if DEBUG
        OSSLog.enable()
        #endif
//        let credential = OSSCustomSignerCredentialProvider.init { (contentToSign, error) -> String? in
//            let signature : String = OSSUtil.calBase64Sha1(withData: contentToSign, withSecret: OSS_Access_Secret)
//            return "OSS \(OSS_Access_Key):\(signature)"
//        }
//        client = OSSClient.init(endpoint: OSS_End_Point, credentialProvider: credential!)
        
        super.init()
        
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let federationProvider: OSSFederationCredentialProvider = OSSFederationCredentialProvider(federationTokenGetter: { () ->OSSFederationToken? in
            
            let url: URL = URL(string: OSS_AUTH_SERVER)!
            var request = URLRequest(url: url)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let signature = LoginUser.shared().signature ?? ""
            request.setValue(signature, forHTTPHeaderField: "FZM-SIGNATURE")
            request.setValue(version, forHTTPHeaderField: "FZM-VERSION")
            request.setValue(String.uuid(), forHTTPHeaderField: "FZM-UUID")
            request.setValue("iOS", forHTTPHeaderField: "FZM-DEVICE")
            request.setValue(k_DeviceName, forHTTPHeaderField: "FZM-DEVICE-NAME")
            let config: URLSessionConfiguration = URLSessionConfiguration.default;
            let session: URLSession = URLSession(configuration: config, delegate: self as URLSessionDelegate, delegateQueue: nil);
            
            let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
                
                //Convert Data to Jsons
                    tcs.setResult(data as AnyObject)
            })
            task.resume()
            tcs.task.waitUntilFinished()
            
            guard let json = try? JSONSerialization.jsonObject(with: tcs.task.result as! Data, options:.allowFragments) as? [String: Any] else {
                return nil
            }
            
//            let json = try? JSONSerialization.jsonObject(with: self?.tcs.task.result as! Data,
//                                                         options:.allowFragments) as? [String: Any]
            print("Json Object:", json as Any)
            
            let json1 = json["data"] as? [String: Any]
            let json2 = json1?["Credentials"] as? [String: Any]
            
            let token = OSSFederationToken()
            
            let accessKeyId = json2?["AccessKeyId"]
            let accessKeySecret = json2?["AccessKeySecret"]
            let securityToken = json2?["SecurityToken"]
            
            token.tAccessKey = accessKeyId as? String ?? ""
            token.tSecretKey = accessKeySecret as? String ?? ""
            token.tToken = securityToken as? String ?? ""
            
            return token
        })
        
        client = OSSClient.init(endpoint: OSS_End_Point, credentialProvider: federationProvider)
        
    }
    */
    
    func getStsToken() -> Void {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let federationProvider: OSSFederationCredentialProvider = OSSFederationCredentialProvider(federationTokenGetter: {() ->OSSFederationToken? in
            let url: URL = URL(string: OSS_AUTH_SERVER)!
            var request = URLRequest(url: url)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let signature = LoginUser.shared().signature ?? ""
            request.setValue(signature, forHTTPHeaderField: "FZM-SIGNATURE")
            request.setValue(version, forHTTPHeaderField: "FZM-VERSION")
            request.setValue(String.uuid(), forHTTPHeaderField: "FZM-UUID")
            request.setValue("iOS", forHTTPHeaderField: "FZM-DEVICE")
            request.setValue(k_DeviceName, forHTTPHeaderField: "FZM-DEVICE-NAME")
            let config: URLSessionConfiguration = URLSessionConfiguration.default;
            let session: URLSession = URLSession(configuration: config, delegate: self as URLSessionDelegate, delegateQueue: nil);
            
            let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
                
                //Convert Data to Jsons
                tcs.setResult(data as AnyObject)
            })
            task.resume()
            tcs.task.waitUntilFinished()
            
            guard let json = try? JSONSerialization.jsonObject(with: tcs.task.result as! Data, options:.allowFragments) as? [String: Any] else {
                return nil
            }
            
            print("Json Object:", json as Any)
            
            let json1 = json["data"] as? [String: Any]
            let json2 = json1?["Credentials"] as? [String: Any]
            
            let token = OSSFederationToken()
            
            let accessKeyId = json2?["AccessKeyId"]
            let accessKeySecret = json2?["AccessKeySecret"]
            let securityToken = json2?["SecurityToken"]
            
            token.tAccessKey = accessKeyId as? String ?? ""
            token.tSecretKey = accessKeySecret as? String ?? ""
            token.tToken = securityToken as? String ?? ""
            
            return token
        })
        
        client = OSSClient.init(endpoint: OSS_End_Point, credentialProvider: federationProvider)
        
        do {
            try federationProvider.getToken()
        } catch{
            print("get Error")
        }
    }
    
    
    
    func download(with fileUrl : URL , downloadProgressBlock : OSSProgressHandler? , callBack: OSSFileDownloadHandler?){
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
                downloadProgressBlock?(Float(totalBytesSent)/Float(totalBytesExpectedToSend))
            }
        }
        let task = client!.getObject(get)
        task.continue ({(backTask) -> Any? in
            var downloadData : Data?
            defer{
                DispatchQueue.main.async {
                    callBack?(downloadData, !(downloadData == nil))
                }
            }
            if backTask.error == nil {
                guard let result = backTask.result as? OSSGetObjectResult else {
                    return nil
                }
                downloadData = result.downloadedData
            }
            return nil
        })
    }
    
    //上传图片
    func uploadImage(file: Data,uploadProgressBlock : OSSProgressHandler? , callBack: OSSFileUploadHandler?) {
        let put = OSSPutObjectRequest.init()
        put.bucketName = OSS_Buket
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let address = LoginUser.shared().address
        let path = "chatList/picture/\(str1)/\(str2)_\(address).jpg"
        put.objectKey = path
        put.uploadingData = file
        put.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                uploadProgressBlock?(Float(totalBytesSent)/Float(totalBytesExpectedToSend))
            }
        }
        let task = client!.putObject(put)
        task.continue ({(backTask) -> Any? in
            var coverPath : String?
            defer{
                DispatchQueue.main.async {
                    callBack?(coverPath, coverPath != nil)
                }
            }
            if backTask.error == nil {
                let useTask = self.client!.presignPublicURL(withBucketName: OSS_Buket, withObjectKey: path)
                coverPath = useTask.result as? String
            }
            return nil
        })
    }
    
    //上传音频，目前只支持AMR格式
    func uploadVoice(file: Data,uploadProgressBlock : OSSProgressHandler? , callBack: OSSFileUploadHandler?) {
        let put = OSSPutObjectRequest.init()
        put.bucketName = OSS_Buket
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let address = LoginUser.shared().address
        let path = "chatList/voice/\(str1)/\(str2)_\(address).amr"
        put.objectKey = path
        put.uploadingData = file
        put.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                uploadProgressBlock?(Float(totalBytesSent/totalBytesExpectedToSend))
            }
        }
        let task = client!.putObject(put)
        task.continue ({(backTask) -> Any? in
            var coverPath : String?
            defer{
                DispatchQueue.main.async {
                    callBack?(coverPath, coverPath != nil)
                }
            }
            if backTask.error == nil {
                let useTask = self.client!.presignPublicURL(withBucketName: OSS_Buket, withObjectKey: path)
                coverPath = useTask.result as? String
            }
            return nil
        })
    }
    
    
    func uploadVideo(filePath:String ,uploadProgressBlock : OSSProgressHandler? , callBack: OSSFileUploadHandler?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let address = LoginUser.shared().address
        let path = "chatList/video/\(str1)/\(str2)_\(address).\((filePath as NSString).components(separatedBy: ".").last ?? "mp4")"
        self.resumableUpload(filePath: filePath, severPath: path, uploadProgressBlock: uploadProgressBlock, callBack: callBack)
    }
    
    func uploadFile(filePath:String ,uploadProgressBlock : OSSProgressHandler? , callBack: OSSFileUploadHandler?) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        let str2 = formatter.string(from: Date.init())
        let address = LoginUser.shared().address
        let path = "chatList/file/\(str1)/\(str2)_\(address).\((filePath as NSString).components(separatedBy: ".").last ?? "")"
        self.resumableUpload(filePath: filePath, severPath: path, uploadProgressBlock: uploadProgressBlock, callBack: callBack)
    }
    
    func resumableUpload(filePath:String,severPath:String,uploadProgressBlock : OSSProgressHandler? , callBack: OSSFileUploadHandler?) {
        let resumableUpload = OSSResumableUploadRequest.init()
        resumableUpload.bucketName = OSS_Buket
        resumableUpload.objectKey = severPath
        resumableUpload.uploadingFileURL = URL.init(fileURLWithPath: filePath)
        resumableUpload.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesExpectedToSend > 0 {
                uploadProgressBlock?(Float(totalBytesSent/totalBytesExpectedToSend))
            }
        }
        if let cachesDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            resumableUpload.recordDirectoryPath = cachesDir
        }
        let resumeTask = client!.resumableUpload(resumableUpload)
        resumeTask.continue ({ (backTask) -> Any? in
            var coverPath : String?
            defer{
                DispatchQueue.main.async {
                    callBack?(coverPath, coverPath != nil)
                }
            }
            if backTask.error == nil {
                let useTask = self.client!.presignPublicURL(withBucketName: OSS_Buket, withObjectKey: severPath)
                coverPath = useTask.result as? String
            }
            return nil
        })
    }
    
}



