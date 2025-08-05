//
//  FZMLocalFileClient.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/12.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

public enum FileFormatterType {
    case amr(fileName: String)
    case wav(fileName: String)
    case jpg(fileName: String)
    case png(fileName: String)
    case video(fileName: String)
    case file(fileName: String)
    case tmp(fileName: String)
    
    var path: String{
        var usePath : String
        switch self {
        case .amr(let useStr):
            usePath = useStr + ".amr"
        case .wav(let useStr):
            usePath = useStr + ".wav"
        case .jpg(let useStr):
            usePath = useStr + ".jpg"
        case .png(let useStr):
            usePath = useStr + ".png"
        case .video(let useStr):
            usePath = useStr + ".MOV"
        case .file(let useStr):
            usePath = useStr
        case .tmp(let useStr):
            usePath = useStr
        }
        return usePath
    }
}

//音频文件存放
private let voicePath = DocumentPath + "Voice"
//wav音频文件
private let wavPath = voicePath + "/WavFile"
//amr音频文件
private let amrPath = voicePath + "/AmrFile"

//图片文件
private let imagePath = DocumentPath + "Image"
//jpg图片
private let jpgPath = imagePath + "/JpgFile"
//png图片
private let pngPath = imagePath + "/PngFile"

//视频文件
private let videoPath = DocumentPath + "Video"

// 文件
private let FilePath = DocumentPath + "File"

// 临时文件
private let TmpPath = DocumentPath + "Tmp"


private let pathArr = [videoPath,voicePath,wavPath,amrPath,imagePath,jpgPath,pngPath,FilePath,TmpPath]

public class FZMLocalFileClient: NSObject {

    private static let sharedInstance = FZMLocalFileClient()
    
    private let fileManager = FileManager.default
    
    private override init() {
        super.init()
        pathArr.forEach { (path) in
            self.createFolder(with: path)
        }
    }
    
    // 判断文件或文件夹是否存在
    func isFileExists(atPath path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    func createFolder(with path : String) {
        let exist = isFileExists(atPath: path)
        if exist {
            FZMLog("存在\(path)")
        }else {
            FZMLog("文件不存在 创建路径\(path)")
            //不存在则创建
            //withIntermediateDirectories为ture表示路径中间如果有不存在的文件夹都会创建
            try! fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public class func shared() -> FZMLocalFileClient {
        return sharedInstance
    }
    
    class func launchClient() {
        _ = self.shared()
    }
    
    
    func getFilePath(with fileName: FileFormatterType) -> String {
        var folderPath : String
        switch fileName {
        case .amr:
            folderPath = amrPath
        case .wav:
            folderPath = wavPath
        case .jpg:
            folderPath = jpgPath
        case .png:
            folderPath = pngPath
        case .video:
            folderPath = videoPath
        case .file:
            folderPath = FilePath
        case .tmp:
            folderPath = TmpPath
        }
        let filePath = folderPath + "/" + fileName.path
        return filePath
    }
    
    func createFile(with fileName: FileFormatterType) -> String? {
        var folderPath : String
        switch fileName {
        case .amr:
            folderPath = amrPath
        case .wav:
            folderPath = wavPath
        case .jpg:
            folderPath = jpgPath
        case .png:
            folderPath = pngPath
        case .video:
            folderPath = videoPath
        case .file:
            folderPath = FilePath
        case .tmp:
            folderPath = TmpPath
        }
        let filePath = folderPath + "/" + fileName.path
        if fileManager.fileExists(atPath: filePath) {
            do{
                try fileManager.removeItem(atPath: filePath)
            }catch{
                return nil
            }
        }
        return filePath
    }
    
    func haveFile(with fileName: FileFormatterType) -> Bool {
        var folderPath : String
        switch fileName {
        case .amr:
            folderPath = amrPath
        case .wav:
            folderPath = wavPath
        case .jpg:
            folderPath = jpgPath
        case .png:
            folderPath = pngPath
        case .video:
            folderPath = videoPath
        case .file:
            folderPath = FilePath
        case .tmp:
            folderPath = TmpPath
        }
        let filePath = folderPath + "/" + fileName.path
        return fileManager.fileExists(atPath: filePath)
    }
}

//文件存储
extension FZMLocalFileClient {
    public func saveData(_ data: Data, filePath: String) -> Bool {
        
        let toFolder = (filePath as NSString).replacingOccurrences(of: (filePath as NSString).lastPathComponent, with: "")
        if !fileManager.fileExists(atPath: toFolder) {
            do {
                try fileManager.createDirectory(atPath: filePath, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                FZMLog(error)
                return false
            }
        }
        if fileManager.fileExists(atPath: filePath) {
            try? fileManager.removeItem(atPath: filePath)
        }
        do {
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch let error {
            FZMLog(error)
            return false
        }
        FZMLog("\(filePath)文件保存成功")
        return true
    }
}

//读取文件
extension FZMLocalFileClient {
    public func readData(fileName: FileFormatterType) -> Data? {
        var folderPath : String
        switch fileName {
        case .amr:
            folderPath = amrPath
        case .wav:
            folderPath = wavPath
        case .jpg:
            folderPath = jpgPath
        case .png:
            folderPath = pngPath
        case .video:
            folderPath = videoPath
        case .file:
            folderPath = FilePath
        case .tmp:
            folderPath = TmpPath
        }
        let filePath = folderPath + "/" + fileName.path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        return data
    }
}

extension FZMLocalFileClient {
    public func move(fromFilePath: String, toFilePath: String) -> Bool {
        guard fileManager.fileExists(atPath: fromFilePath) else {
            return false
        }
        
        let toFolder = (toFilePath as NSString).replacingOccurrences(of: (toFilePath as NSString).lastPathComponent, with: "")
        if !fileManager.fileExists(atPath: toFolder) {
            try? fileManager.createDirectory(atPath: toFilePath, withIntermediateDirectories: true, attributes: nil)
        }
        
        if fileManager.fileExists(atPath: toFilePath) {
            try? fileManager.removeItem(atPath: toFilePath)
        }

        do {
            try fileManager.moveItem(atPath: fromFilePath, toPath: toFilePath)
        } catch {
            return false
        }
        return true
    }
    
    public func deleteFile(atFilePath: String) -> Bool {
        guard fileManager.fileExists(atPath: atFilePath) else {
            return true
        }
        do {
            try fileManager.removeItem(atPath: atFilePath)
        } catch  {
            return false
        }
        return true
    }
}
