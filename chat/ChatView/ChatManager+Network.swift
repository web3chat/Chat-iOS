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
            failure?(L("文件内容为空"))
            return
        }
        
        // 需要加密的消息内容 —— 加密移到后台线程执行，主线程不再阻塞等待（发送消息不卡 UI）
        if isNeedEncrypt {
            FZMLog("文件加密开始(后台)")
            DispatchQueue.global(qos: .userInitiated).async {
                let encrypted = ChatManager.encryptUploadData(fileData, publickey: publickey, isEncryptPersionChatData: msg.sessionId.isPersonChat)
                // 如果加密则文件名拼上特殊字符串 "$ENC$"，解密时判断文件名是否包含此字符串以判断是否为加密上传的文件
                let enc = encrypted.count > fileData.count
                self.uploadRequest(fileData: encrypted, type: fileType, isEncrypt: enc, success: success, failure: failure)
                FZMLog("文件加密结束，继续下一步操作(后台)")
            }
        } else {
            self.uploadRequest(fileData: uploadData, type: fileType, isEncrypt: isEncrypt, success: success, failure: failure)
        }
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
        
        // ⚠️ 原来这里写的是 `fileData.count > fileData.count ? ".../$ENC$\(str2)..." : ".../\(str2)..."`——
        //    自己跟自己比**恒为 false**，是个恒走 false 分支的死代码；`$ENC$` 实际是在上面拼进 `str2` 的。
        //    去掉死分支，行为与线上保持一致（即原来的 false 分支）。
        let filepath = "chatList/\(fileType)/\(str1)/\(str2)_\(uid)\(fileEndName)"
        
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
            // ⚠️ 上传失败时服务端可能返回**非 JSON**（413 / 网关错误页），
            //    原来只打一句「json 解析失败」根本查不出原因 ⇒ 这里把状态码和响应体原文打出来。
            let statusCode = resp.response?.statusCode ?? -1
            let bodyText = resp.data.flatMap { String(data: $0, encoding: .utf8) } ?? "<无响应体>"
            if response?.result.isSuccess == true, let jsonData = resp.data, !jsonData.isEmpty {// 上传成功
                FZMLog("上传文件请求成功 - status=\(statusCode) 响应体=\(bodyText)")
                do{
                    let json = try JSON.init(data: jsonData)
                    FZMLog("response json -- \(json)")
                    guard let code = json["result"].int, code == 0 else {// code == 0为消息发送成功，其他则报错
                        let error = NSError.init(domain: "", code: json["result"].intValue, userInfo: [NSLocalizedDescriptionKey: json["message"].stringValue])
                        FZMLog("上传文件失败 -- error \(error)")
                        // 上传失败
                        failure?(L("上传文件失败"))
                        return
                    }

//                        let uri = json["data"]["uri"].stringValue
                    let url = json["data"]["url"].stringValue
                    FZMLog("上传文件成功！！！！！！！！url: \(url)")

                    // 上传成功
                    success?(url)
                }catch{
                    FZMLog("文件上传失败 -- status=\(statusCode) 响应体不是 JSON：\(bodyText)")
                    // 发送消息失败
                    failure?(L("发送消息失败"))
                }
            } else {// 上传失败（消息发送失败）
                FZMLog(
                    "文件上传失败 - status=\(statusCode) error=\(String(describing: resp.error)) "
                        + "响应体=\(bodyText)")
                // 发送消息失败
                failure?(L("上传文件失败"))
            }
        }
    }
}
