//
//  FZMInputAtItem.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/9.
//

import Foundation

let AtChar = "@"
let AtEndChar = "\u{2004}"

class FZMInputAtItem: NSObject {
    let uid: String// 用户地址
    let name: String// 昵称
    var start: Int// @ 的起始位置
    // @ 空格的结束位置
    var end: Int {
        return self.start + self.name.count - 1
    }
    init(uid: String, name: String, startIndex: Int) {
        self.uid = uid
        let wholeName = AtChar + name + AtEndChar
        self.name = wholeName
        self.start = startIndex
        super.init()
    }
}

class FZMInputAtItemCache: NSObject {
    private var atItems = Array<FZMInputAtItem>.init()
    
    // 清除数据
    func clear() {
        self.atItems.removeAll()
    }
    
    // 添加数据
    func add(_ item: FZMInputAtItem) {
        self.atItems.append(item)
    }
    
    // 判断当前删除的是否是at的末尾空格（删除at最末位空格时需删除整个at元素）
    func isDeleteAtLastLocation(range: NSRange) -> FZMInputAtItem? {
        // start: 0, end: 5      location: 4, length: 1
        var needDeleteItem: FZMInputAtItem?
//        let beforeLocation = range.location + range.length// 删除前光标位置
        
        self.atItems.forEach { (item) in
            if item.end == range.location {
                needDeleteItem = item
                return
            }
        }
        
        return needDeleteItem
    }
    
    func remove(by name: String) {
        var item: FZMInputAtItem?
        for i in 0..<self.atItems.count {
            if self.atItems[i].name == name {
                item = self.atItems[i]
                break
            }
        }
        guard let obj = item, let index = self.atItems.firstIndex(where: {$0 == obj}) else { return }
        self.atItems.remove(at: index)
    }
    
    func getItem(by name: String) -> FZMInputAtItem? {
        for item in self.atItems {
            if item.name == name {
                return item
            }
        }
        return nil
    }
    
    func getAllAtUids(by text: String) -> [String] {
        var uids = Array<String>.init()
        self.match(text).forEach { (name) in
            if let item = self.getItem(by: name) {
                uids.append(item.uid)
            }
        }
        return uids
    }
    
    func atItemRang(in text: String) -> NSRange? {
        let pattern = "@([^\(AtEndChar)]+)\(AtEndChar)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            if let lastResult = results.last, (lastResult.range.location + lastResult.range.length) == text.count {
                let name = (text as NSString).substring(with: lastResult.range)
                if self.getItem(by: name) != nil {
                    return lastResult.range
                }
            }
        }
        return nil
    }
    
    private func match(_ text: String) -> [String] {
        // 正则匹配以 ‘@’ 开头 AtEndChar 结尾，中间 [^\(AtEndChar)] 除了AtEndChar外的任意多个字符
        let pattern = "@([^\(AtEndChar)]+)\(AtEndChar)"
        var matchs = Array<String>.init()
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            results.forEach { (result) in
                let name = (text as NSString).substring(with: result.range)
                matchs.append(name)
            }
        }
        return matchs
    }
}
