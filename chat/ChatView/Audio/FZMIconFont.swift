//
//  FZMIconFont.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/13.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

enum FZMIconFont: String {
    case noSelect = "\u{e61d}"
    case select = "\u{e698}"
    case close = "\u{e66b}"
    case service = "\u{e7e3}"
    case left = "\u{e68d}"
    case right = "\u{e71e}"
    case up = "\u{e96c}"
    case down = "\u{e96d}"
    case level = "\u{e72d}"
    case authentication = "\u{e971}"
    case star = "\u{e972}"
    case emoji = "\u{e752}"
    case chat = "\u{e753}"
    case notification = "\u{e754}"
    case undo = "\u{e755}"
    case sendVoice = "\u{e756}"
    case record_1 = "\u{e759}"
    case record_2 = "\u{e757}"
    case record_3 = "\u{e75c}"
    case record_4 = "\u{e758}"
    case record_5 = "\u{e75a}"
    case record_6 = "\u{e75b}"
    case record_7 = "\u{e75d}"
    case moreItem = "\u{e75e}"
    case picture = "\u{e75f}"
    case alone = "\u{e760}"
    case camera = "\u{e761}"
    case user = "\u{e762}"
    case noChat = "\u{e763}"
    case leftVoice_1 = "\u{e764}"
    case leftVoice_2 = "\u{e767}"
    case leftVoice_3 = "\u{e766}"
    case rightVoice_1 = "\u{e976}"
    case rightVoice_2 = "\u{e977}"
    case rightVoice_3 = "\u{e978}"
    case headerAny = "\u{e765}"
    case noRecord = "\u{e770}"
    case headerVIP = "\u{e769}"
    case userVIP = "\u{e76a}"
    case luckyCame = "\u{e76b}"
    case header = "\u{e76c}"
    case luckyPacket = "\u{e76e}"
    case zhaobi = "\u{e76d}"
    case chatService = "\u{e76f}"
    case leftTriangle = "\u{e975}"
    case rightTriangle = "\u{e60c}"
    case warning = "\u{e768}"
    case editPencil = "\u{e7bb}"
    case identificationArrow = "\u{e7e4}"
}

extension UIFont {
    class func iconfont(ofSize: CGFloat) -> UIFont {
        if let font = UIFont(name: "iconfont", size: ofSize) {
            return font
        }
        if (self.registerFont("iconfont")) {
            return UIFont(name: "iconfont", size: ofSize) ?? UIFont.systemFont(ofSize:ofSize)
        }
        return UIFont.systemFont(ofSize:ofSize)
    }
    
    static func registerFont(_ fontName:String) -> Bool {
        guard let bundleName = Bundle.main.infoDictionary?["CFBundleExecutable"],
            let fontPath = Bundle.main.path(forResource: fontName, ofType: "ttf", inDirectory: "\(bundleName).bundle"),
            let fontData = try? Data.init(contentsOf: URL.init(fileURLWithPath: fontPath)),
            let provider = CGDataProvider.init(data: fontData as CFData),
            let font = CGFont(provider) else {
                return false
        }
        var error: Unmanaged<CFError>?
        if (!CTFontManagerRegisterGraphicsFont(font, &error)) {
            #if DEBUG
            print(error.debugDescription)
            #endif
            return false
        } else {
            return true
        }
    }
}

extension UIImage {
    convenience init?(text: FZMIconFont, imageSize: CGSize, imageColor: UIColor = Color_Theme) {
        let scale = UIScreen.main.scale
        let realSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let iconfont = UIFont.iconfont(ofSize: realSize.width)
        UIGraphicsBeginImageContext(realSize)
        defer {
            UIGraphicsEndImageContext()
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        text.rawValue.draw(at: CGPoint.zero, withAttributes: [.font : iconfont,
                                                              .foregroundColor: imageColor,
                                                              .paragraphStyle: paragraphStyle])
        guard let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage else {
            self.init()
            return nil
        }
        self.init(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

extension String {
    func matchingFileType() -> String {
        switch self.lowercased() {
        case "mp3","wma","wav","ogg","cd","mp3pro","real","ape","module","midi","vqf":
            return "chat_file_music"
        case "avi","rmvb","divx","mpg","mpeg","mpe","wmv","mp4","mkv","vob","mov","3gp","flv","f4v","qsv":
            return "chat_file_video"
        case "docx","doc","dotx","dot","dotm","docm","xps","wps":
            return "chat_file_word"
        case "xlsb","xls","xlam","xla","xlsx":
            return "chat_file_excel"
        case "pdf":
            return "chat_file_pdf"
        case "pot","potm","potx","ppa","ppam","pps","ppsm","ppsx","ppt","pptm","pptx":
            return "chat_file_default"
        default:
            return "chat_file_default"
        }
    }
}
