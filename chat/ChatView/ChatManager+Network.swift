//
//  ChatManager+Network.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/2.
//

import Foundation
import Alamofire

enum UploadFileType {
    case image// 图片
    case gifImage// gif图片
    case audio// 音频
    case video// 视频
    case file// 文件
}

// 上传文件
extension ChatManager {
    
    // 消息文件上传文件到服务器（私聊且有公钥时加密后上传）
    func uploadFileRequest(fileData: Data, msg: Message, publickey: String, success: StringBlock?, failure: StringBlock?) {
        var uploadData = fileData
        
        var fileType: UploadFileType = .image
        var isEncrypt = false
        var isNeedEncrypt = false
        switch msg.msgType {
        case .image:
            fileType = .image
            if let _ = msg.gifData {
                fileType = .gifImage
            }
            isNeedEncrypt = true
        case .audio:
            fileType = .audio
            isNeedEncrypt = true
        case .video:
            fileType = .video
            isNeedEncrypt = true
            
        case .file:
            fileType = .file
            isNeedEncrypt = true
        default:
            FZMLog("暂不支持")
        }
        guard !uploadData.isEmpty else {
            failure?("文件内容为空")
            return
        }
        
        // 需要加密的消息内容
        if isNeedEncrypt {
            //wjhTEST
            let semaphore = DispatchSemaphore.init(value: 0)
            FZMLog("文件加密开始")
            DispatchQueue.global().async {
                uploadData = ChatManager.encryptUploadData(fileData, publickey: publickey, isEncryptPersionChatData: msg.sessionId.isPersonChat)
                semaphore.signal()
            }
            semaphore.wait()//等待异步任务执行完成才可以继续执行
            FZMLog("文件加密结束，继续下一步操作")
        }
        
        if uploadData.count > fileData.count {// 如果加密则文件名拼上特殊字符串 "$ENC$"，解密时判断文件名是否包含此字符串以判断是否为加密上传的文件
            isEncrypt = true
        }
        
        self.uploadRequest(fileData: uploadData, type: fileType, isEncrypt: isEncrypt, success: success, failure: failure)
    }
    
    // 文件上传请求
    func uploadRequest(fileData: Data, type: UploadFileType, isEncrypt: Bool? = false, success: StringBlock?, failure: StringBlock?) {
        var fileType = ""
        var fileEndName = ".jpg"
        switch type {
        case .image:
            fileType = "picture"
            fileEndName = ".jpg"
        case .gifImage:
            fileType = "picture"
            fileEndName = ".gif"
        case .audio:
            fileType = "audio"
//            fileEndName = ".amr"
            fileEndName = ".wav"
        case .video:
            fileType = "video"
            fileEndName = ".mp4"
        case .file:
            fileType = "file"
            fileEndName = ""
        }
        
        let formatter = DateFormatter.init()
        formatter.dateFormat = "YYYYMMdd"
        let str1 = formatter.string(from: Date.init())
        formatter.dateFormat = "YYYYMMddhhmmssSSS"
        var str2 = formatter.string(from: Date.init())
        if isEncrypt == true {// 如果加密则文件名拼上特殊字符串 "$ENC$"，解密时判断文件名是否包含此字符串以判断是否为加密上传的文件
            str2 = encryptFlgStr + str2
        }
        let uid = LoginUser.shared().address
        
        let filepath =  fileData.count > fileData.count ? "chatList/\(fileType)/\(str1)/$ENC$\(str2)_\(uid)\(fileEndName)" : "chatList/\(fileType)/\(str1)/\(str2)_\(uid)\(fileEndName)"
        
        var headers: HTTPHeaders {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let signature = LoginUser.shared().signature ?? ""
            return ["Content-type": "multipart/form-data",
                    "Content-Disposition" : "form-data",
                    "FZM-SIGNATURE": signature,
                    "FZM-VERSION": version,
                    "FZM-UUID": String.uuid(),
                    "FZM-DEVICE": "iOS",
                    "FZM-DEVICE-NAME": k_DeviceName
            ]
        }
        
        var response: DataResponse<Data?, AFError>?
        let multipartFormData = MultipartFormData.init()
        multipartFormData.append(fileData, withName: "file", fileName: "file")
        multipartFormData.append(APPID.data(using: .utf8)!, withName: "appId")
        multipartFormData.append(filepath.data(using: .utf8)!, withName: "key")
        
        AF.upload(multipartFormData: multipartFormData, to: BackUpOSSURL, headers: headers).response { resp in
            response = resp
            if response?.result.isSuccess == true {// 上传成功
                FZMLog("上传文件请求成功 - response data -- \(String(describing: response?.data))")
                do{
                    if let jsonData = resp.data{
                        
                        let json = try JSON.init(data: jsonData)
                        FZMLog("response json -- \(json)")
                        guard let code = json["result"].int, code == 0 else {// code == 0为消息发送成功，其他则报错
                            let error = NSError.init(domain: "", code: json["result"].intValue, userInfo: [NSLocalizedDescriptionKey: json["message"].stringValue])
                            FZMLog("上传文件失败 -- error \(error)")
                            // 上传失败
                            failure?("上传文件失败")
                            return
                        }
                        
//                        let uri = json["data"]["uri"].stringValue
                        let url = json["data"]["url"].stringValue
                        FZMLog("上传文件成功！！！！！！！！url: \(url)")
                        
                        // 上传成功
                        success?(url)
                    }
                }catch{
                    FZMLog("文件上传失败 -- error message json 解析失败")
                    // 发送消息失败
                    failure?("发送消息失败")
                }
            } else {// 上传失败（消息发送失败）
                FZMLog("文件上传失败 - response data -- \(String(describing: resp.error))")
                // 发送消息失败
                failure?("文件上传失败")
            }
        }
    }
}
