//
//  String+Extension.swift
//  xls
//
//  Created by 陈健 on 2020/8/31.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation

extension String {
    
    /// 生成随机字符串
    ///
    /// - Parameters:
    ///   - count: 生成字符串长度
    ///   - isLetter: false=大小写字母和数字组成，true=大小写字母组成，默认为false
    /// - Returns: String
    static func random(_ count: Int, _ isLetter: Bool = false) -> String {
        
        var ch: [CChar] = Array(repeating: 0, count: count)
        for index in 0..<count {
            
            var num = isLetter ? arc4random_uniform(58)+65:arc4random_uniform(75)+48
            if num>57 && num<65 && isLetter==false { num = num%57+48 }
            else if num>90 && num<97 { num = num%90+65 }
            
            ch[index] = CChar(num)
        }
        
        return String(cString: ch)
    }
    
    static func randomStringWithLength(len : Int) -> String {
     
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
     
        let randomString : NSMutableString = NSMutableString(capacity: len)
     
        for _ in 0..<len {
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C",letters.character(at: Int(rand)))
        }
     
        return randomString as String
    }
}

// MARK: - 字符串截取
extension String {
    /// String使用下标截取字符串
    /// string[index] 例如："abcdefg"[3] // c
    subscript (i:Int)->String{
        let startIndex = self.index(self.startIndex, offsetBy: i)
        let endIndex = self.index(startIndex, offsetBy: 1)
        return String(self[startIndex..<endIndex])
    }
    /// String使用下标截取字符串
    /// string[index..<index] 例如："abcdefg"[3..<4] // d
    subscript (r: Range<Int>) -> String {
        get {
            let startIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
            let endIndex = self.index(self.startIndex, offsetBy: r.upperBound)
            return String(self[startIndex..<endIndex])
        }
    }
    /// String使用下标截取字符串
    /// string[index,length] 例如："abcdefg"[3,2] // de
    subscript (index:Int , length:Int) -> String {
        get {
            let startIndex = self.index(self.startIndex, offsetBy: index)
            let endIndex = self.index(startIndex, offsetBy: length)
            return String(self[startIndex..<endIndex])
        }
    }
    // 截取 从头到i位置
    func substring(to:Int) -> String{
        return self[0..<to]
    }
    // 截取 从i到尾部
    func substring(from:Int) -> String{
        return self[from..<self.count]
    }
}

// MARK: 字符串转字典
extension String {
    
    func toDictionary() -> [String : Any] {
        
        var result = [String : Any]()
        guard !self.isEmpty else { return result }
        
        guard let dataSelf = self.data(using: .utf8) else {
            return result
        }
        
        if let dic = try? JSONSerialization.jsonObject(with: dataSelf,
                                                       options: .mutableContainers) as? [String : Any] {
            result = dic
        }
        return result
        
    }
}

// MARK: 字典转字符串
extension Dictionary {
    
    func toJsonString() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self,
                                                     options: []) else {
            return nil
        }
        guard let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}

extension String {
    static func timeString1(with timestamp: Int) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "yyyy-M-d HH:mm:ss"
        return formatter.string(from: date)
    }
    
    static func sessionTimeString(with timestamp: Int?) -> String? {
        guard let timestamp = timestamp, timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "yyyyMMdd"
        
        let dateString = formatter.string(from: date)
        let todayString = formatter.string(from: Date())
        formatter.dateFormat = "HH:mm"
        var resultDateString = formatter.string(from: date)
        guard let dateNumber = Int(dateString), let todayNumber = Int(todayString) else {
            return resultDateString
        }
        if dateNumber == todayNumber {
            // 上午下午待定
        } else if dateNumber == todayNumber - 1 {
            resultDateString = "昨天" + resultDateString
        } else {
            formatter.dateFormat = "yyyy/MM/dd"
            resultDateString = formatter.string(from: date)
        }
        return resultDateString
    }
}

extension String {
    /*
     1 Minimum 8 characters at least 1 Alphabet and 1 Number:
     let password = NSPredicate(format: "SELF MATCHES %@ ", "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,}$")
     
     2 Check if password contains characters and one special characters and is minimum six char long:
     let password = NSPredicate(format: "SELF MATCHES %@ ", "^(?=.*[a-z])(?=.*[$@$#!%*?&]).{6,}$")
     
     3 check if password contains one big letter, one special character and and is minimum six char long:
     let password = NSPredicate(format: "SELF MATCHES %@ ", "^(?=.*[a-z])(?=.*[$@$#!%*?&])(?=.*[A-Z]).{6,}$")
     
     4 check if password contains one big letter, one number and and is minimum eight char long:
     let password = NSPredicate(format: "SELF MATCHES %@ ", "^(?=.*[a-z])(?=.*[0-9])(?=.*[A-Z]).{8,}$")
     */

    var isValidPassword: Bool {
        // ^(?![0-9]+$)(?![a-zA-Z]+$)(?![^A-Za-z0-9]+$)([\w^\\|<>\[\]{}#%+-=~/:;()$&"`?!*@,.']){8,16}$
        // ^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,16}$
        let password = NSPredicate(format: "SELF MATCHES %@ ", "^(?![0-9]+$)(?![a-zA-Z]+$)(?![^A-Za-z0-9]+$)([\\w^\\\\|<>\\[\\]{}#%+-=~/:;()$&\"`?!*@,.']){8,16}$")
        return password.evaluate(with: self)
    }
    
    
    var isIncludeChinese: Bool {
        for (_, value) in self.enumerated() {
            
            if ("\u{4E00}" <= value  && value <= "\u{9FA5}") {
                return true
            }
        }
        return false
    }
    
//    var isBlank: Bool {
//        let trimmedStr = self.trimmingCharacters(in: .whitespacesAndNewlines)
//        return trimmedStr.isEmpty
//    }
    var isBlank: Bool {
        return allSatisfy({ $0.isWhitespace })
    }
    
    var shortAddress: String {
        if self.count > 8 && !self.contains("****") {
            let str = self as NSString
            return str.replacingCharacters(in: NSMakeRange(4, str.length - 8), with: "****")
        }
        return self
    }
}

extension Optional where Wrapped == String {
    var isBlank: Bool {
        return self?.isBlank ?? true
    }
}

extension String {
    /// 文字末尾拼接图片
    func jointImage(image: UIImage, rect: CGRect = CGRect.init(x: 0, y: 0, width: 12, height: 12)) -> NSAttributedString {
        guard !self.isBlank else { return NSAttributedString.init() }
        let attch = NSTextAttachment.init()
        attch.image = image
        attch.bounds = rect
        let string = NSAttributedString.init(attachment: attch)
        let attri = NSMutableAttributedString.init(string: self + " ")
        attri.insert(string, at: self.count + 1)
        return attri
    }
}

extension String {
    /// 获取拼音首字母（大写字母）
    func firstLetter() -> String {
        //转变成可变字符串
        let mutableString = NSMutableString.init(string: self)
        //将中文转换成带声调的拼音
        CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformToLatin, false)
        //去掉声调
        let pinyinString = mutableString.folding(options: String.CompareOptions.diacriticInsensitive, locale: NSLocale.current)
        //将拼音首字母换成大写
        let strPinYin = pinyinString.uppercased()
        //截取大写首字母
        let firstString = String(strPinYin.first ?? Character.init(""))
        //判断首字母是否为大写
        let regexA = "^[A-Z]$"
        let predA = NSPredicate.init(format: "SELF MATCHES %@", regexA)
        
        return predA.evaluate(with: firstString) ? firstString : "#"
    }
    
    //获取拼音首字母（大写字母）
    func findFirstLetterFromString() -> String {
        //转变成可变字符串
        let mutableString = NSMutableString.init(string: self)
        //将中文转换成带声调的拼音
        CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformToLatin, false)
        //去掉声调
        let pinyinString = mutableString.folding(options: String.CompareOptions.diacriticInsensitive, locale: NSLocale.current)
        //将拼音首字母换成大写
        let strPinYin = pinyinString.uppercased()
        //截取大写首字母
        let firstString = strPinYin.substring(from: 0, to: 0)
        //判断首字母是否为大写
        let regexA = "^[A-Z]$"
        let predA = NSPredicate.init(format: "SELF MATCHES %@", regexA)
        return predA.evaluate(with: firstString) ? firstString : "#"
    }
    
    //文字转为拼音
    func findAllLetterFromString() -> String {
        //转变成可变字符串
        let mutableString = NSMutableString.init(string: self)
        //将中文转换成带声调的拼音
        CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformToLatin, false)
        //去掉声调
        let pinyinString = mutableString.folding(options: String.CompareOptions.diacriticInsensitive, locale: NSLocale.current)
        //将拼音首字母换成小写
        let strPinYin = pinyinString.lowercased()
        return strPinYin
    }
}

extension String{
    
    static func dateString(with timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "yyyyMMdd"
        
        let dateString = formatter.string(from: date)
        let todayString = formatter.string(from: Date())
        formatter.dateFormat = "HH:mm"
        var resultDateString = formatter.string(from: date)
        guard let dateNumber = Int(dateString), let todayNumber = Int(todayString) else {
            return resultDateString
        }
        if dateNumber == todayNumber {
            // 上午下午待定
        } else if dateNumber == todayNumber - 1 {
            resultDateString = "昨天" + resultDateString
        } else {
            formatter.dateFormat = "yyyy/MM/dd"
            resultDateString = formatter.string(from: date)
        }
        return resultDateString
    }
    
    static func yyyyMMddDateString(with timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
    static func yyyy_MM_dd_DateString(with timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    static func mm_dd_DateString(with timestamp: Double) -> String {
        let date = Date.init(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.init()
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }
    static func mm_dd_HH_dd_DateString(with timestamp: Double) -> String {
        let date = Date.init(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.init()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    static func showTimeString(with timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.getDataformatter()
        if date.isToday {
            formatter.dateFormat = "HH:mm"
        }else if date.isYesterday {
            formatter.dateFormat = "昨天HH:mm"
        }else if date.isTheYear {
            formatter.dateFormat = "M月d日 HH:mm"
        }else{
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    static func showTimeString2(with timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        
        return formatter.string(from: date)
    }
    
    
    static func timeString(with timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter.getDataformatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// 获取毫秒级的时间字符串
    static func getTimeStampStr() -> String {
        let dateFormatter = DateFormatter.getDataformatter()
        dateFormatter.dateFormat = "yyyyMMddhhmmssSSS"
        return dateFormatter.string(from: Date())
    }
    
    /// 字符串转为utf8格式data
    var utf8Encoded: Data {
        return data(using: .utf8)!
    }
    
    /// 字符串转为Int64格式
    var intEncoded: Int {
        let str = self as NSString
        return str.integerValue
    }
    
    //字符串操作
    /// range转换为NSRange
    func nsRange(from range: Range<String.Index>) -> NSRange {
        return NSRange(range, in: self)
    }
    
    func nsRange(from string: String) -> NSRange {
        let range = self.range(of: string)
        return self.nsRange(from: range!)
    }
    
    /// NSRange转化为range
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self)
            else { return nil }
        return from ..< to
    }
    
    ///在字符串中查找另一字符串首次出现的位置（如果backwards参数设置为true，则返回最后出现的位置）
    func positionOf(sub:String, backwards:Bool = false)->Int {
        // 如果没有找到就返回-1
        var pos = -1
        if let range = range(of:sub, options: backwards ? .backwards : .literal ) {
            if !range.isEmpty {
                pos = self.distance(from:startIndex, to:range.lowerBound)
            }
        }
        return pos
    }
    
    func substring(with nsRange : NSRange) -> String {
        return self.substring(from: nsRange.location, length: nsRange.length)
    }
    
    func substring(from: Int?, to: Int?) -> String {
        if let start = from {
            guard start < self.count else {
                return ""
            }
        }
        
        if let end = to {
            guard end >= 0 else {
                return ""
            }
        }
        
        if let start = from, let end = to {
            guard end - start >= 0 else {
                return ""
            }
        }
        
        let startIndex: String.Index
        if let start = from, start >= 0 {
            startIndex = self.index(self.startIndex, offsetBy: start)
        } else {
            startIndex = self.startIndex
        }
        
        let endIndex: String.Index
        if let end = to, end >= 0, end < self.count {
            endIndex = self.index(self.startIndex, offsetBy: end + 1)
        } else {
            endIndex = self.endIndex
        }
        
        return String(self[startIndex ..< endIndex])
    }
    
    func substring(from: Int?, length: Int) -> String {
        guard length > 0 else {
            return ""
        }
        
        let end: Int
        if let start = from, start > 0 {
            end = start + length - 1
        } else {
            end = length - 1
        }
        
        return self.substring(from: from, to: end)
    }
    
    func substring(length: Int, to: Int?) -> String {
        guard let end = to, end > 0, length > 0 else {
            return ""
        }
        
        let start: Int
        if let end = to, end - length > 0 {
            start = end - length + 1
        } else {
            start = 0
        }
        
        return self.substring(from: start, to: to)
    }
    
    func pathExtension() -> String {
        return (self as NSString).pathExtension as String
    }
    
    func lastPathComponent() -> String {
        return formatFileName()
    }
    
    func formatFileName() -> String {
        return (self as NSString).lastPathComponent as String
    }
    
    func fileName() -> String {
        let str = self.formatFileName()
        return (str as NSString).deletingPathExtension as String
    }
    
    //根据宽度获取需求尺寸的图片的下载地址
    func getDownloadUrlString(width: Int) -> String {
        return "\(self)?x-oss-process=image/resize,w_\(width*2)"
    }
    
    static func transToHourMinSec(time: Double) -> String
    {
        let allTime: Int = Int(time)
        var hours = 0
        var minutes = 0
        var seconds = 0
        var hoursText = ""
        var minutesText = ""
        var secondsText = ""
        
        hours = allTime / 3600
        hoursText = hours > 9 ? "\(hours)" : "0\(hours)"
        
        minutes = allTime % 3600 / 60
        minutesText = minutes > 9 ? "\(minutes)" : "0\(minutes)"
        
        seconds = allTime % 3600 % 60
        secondsText = seconds > 9 ? "\(seconds)" : "0\(seconds)"
        if hours == 0 {
            return "\(minutesText):\(secondsText)"
        }
        return "\(hoursText):\(minutesText):\(secondsText)"
    }
    
    static func getStringFrom(double doubleVal: Double) -> String? {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true;
        formatter.maximumSignificantDigits = 100
        formatter.groupingSeparator = "";
        formatter.numberStyle = .decimal
        let stringValue = formatter.string(from: NSNumber.init(value: doubleVal));
        return stringValue
    }
    
    /// 返回的是删除以prefixStr开头的字符串
    func getStringRemovingPrefix(with prefixStr: String) -> String {
        var finalKey = self
        
        if finalKey.starts(with: prefixStr) {
            finalKey = finalKey.removingPrefix(prefixStr)
        }
        
        return finalKey
    }
    
    /// 返回去除以“0x”开头的字符串（处理公私钥和签名等字符串）
    var finalKey: String {
        var finalKey = self
        let prefixStr = "0x"
        if finalKey.starts(with: prefixStr) {
            finalKey = finalKey.removingPrefix(prefixStr)
        }
        
        return finalKey
    }
    
    /// 字符串Base64编码
    /// - Returns: 编码后的字符串
    func base64Encoding() -> String {
        let plainData = self.data(using: String.Encoding.utf8)
        let base64String = plainData?.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String!
    }
    
    static func uuid() -> String {
        return UUID.init().uuidString
    }
}

// MARK: ------------------------ 计算文本的size
extension String {
    
    ///获取内容size
    func getContentSize(font: UIFont, size: CGSize) -> CGSize {
        if self.count == 0 {
            return CGSize.zero
        }
        return (self as NSString).boundingRect(with: size, options: NSStringDrawingOptions(rawValue: NSStringDrawingOptions.usesLineFragmentOrigin.rawValue | NSStringDrawingOptions.usesFontLeading.rawValue), attributes: [.font: font], context: nil).size
    }
    func getContentHeight(font: UIFont, width: CGFloat) -> CGFloat {
        return self.getContentSize(font: font, size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
    }
    func getContentWidth(font: UIFont, height: CGFloat) -> CGFloat {
        return self.getContentSize(font: font, size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: height)).width
    }
    
    /// 计算字体的宽度
    /// - Parameters:
    ///   - font: 字体大小
    ///   - height: label高度
    /// - Returns: 字体宽度
    public func caclulateTextWidth(font: UIFont, height: CGFloat) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let option = NSStringDrawingOptions.usesLineFragmentOrigin
        let rect:CGRect = self.boundingRect(with: CGSize(width: 100000, height: height), options: option, attributes: attributes, context: nil)
        return rect.size.width;
    }
    
    /// 计算字体的高度
    /// - Parameters:
    ///   - font: 字体大小
    ///   - width: 文字宽度
    /// - Returns: 字体高度
    public func caclulateTextHeight(font: UIFont, width: CGFloat) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let option = NSStringDrawingOptions.usesLineFragmentOrigin
        let rect:CGRect = self.boundingRect(with: CGSize(width: width, height: 100000), options: option, attributes: attributes, context: nil)
        return rect.size.width;
    }
}

extension String{
    /// 替换手机号中间四位
    var secretPhone: String {
        let start = self.index(self.startIndex,offsetBy: 3)
        let end = self.index(self.startIndex,offsetBy: 7)
        let range = Range(uncheckedBounds: (lower: start,upper: end))
        return self.replacingCharacters(in: range,with: "****")
    }
    
    /// 把url转换成只保留ip/域名的格式
    var shortUrlStr: String {
        var urlStr = self
        if self.contains("http://") {
            urlStr = self.replacingOccurrences(of: "http://", with: "")
        } else if self.contains("https://") {
            urlStr = self.replacingOccurrences(of: "https://", with: "")
        } else if urlStr.contains("ws://") {
            urlStr = self.replacingOccurrences(of: "ws://", with: "")
        } else if urlStr.contains("wss://") {
            urlStr = self.replacingOccurrences(of: "wss://", with: "")
        }
        
        if urlStr.contains(":"), let startRang = urlStr.range(of: ":") {
            let urlSeparated = urlStr[..<startRang.lowerBound]
            urlStr = String(urlSeparated)
        }
        if urlStr.contains("/"), let startRang = urlStr.range(of: "/") {
            let urlSeparated = urlStr[..<startRang.lowerBound]
            urlStr = String(urlSeparated)
        }
        return urlStr
    }
}
