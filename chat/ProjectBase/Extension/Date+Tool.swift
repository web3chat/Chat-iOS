//
//  Date+Tool.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/19.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import Foundation

extension Date{
    //时间戳
    static var timestamp: Int  {
        return Int(Date().timeIntervalSince1970 * 1000) //取毫秒，单位毫秒
    }
    
    var timestamp: Int {
        return Int(self.timeIntervalSince1970 * 1000)
    }
    
    //MARK: -时间戳转时间函数
    static func timeStampToString(timeStamp: Double) -> Date {
        //时间戳为毫秒级要 ／ 1000， 秒就不用除1000，参数带没带000
        let timeSta:TimeInterval = TimeInterval(timeStamp / 1000)
        let date = Date(timeIntervalSince1970: timeSta)
        return date
    }
    
    //年
    var year : NSInteger {
        let calendar = NSCalendar.current
        let com = calendar.dateComponents([.year], from: self)
        guard let need = com.year else { return 1970 }
        return need
    }
    //月
    var month : NSInteger {
        let calendar = NSCalendar.current
        let com = calendar.dateComponents([.month], from: self)
        guard let need = com.month else { return 1 }
        return need
    }
    //日
    var day : NSInteger {
        let calendar = NSCalendar.current
        let com = calendar.dateComponents([.day], from: self)
        guard let need = com.day else { return 1 }
        return need
    }
    //时
    var hour : NSInteger {
        let calendar = NSCalendar.current
        let com = calendar.dateComponents([.hour], from: self)
        guard let need = com.hour else { return 1 }
        return need
    }
    //分
    var minute : NSInteger {
        let calendar = NSCalendar.current
        let com = calendar.dateComponents([.minute], from: self)
        guard let need = com.minute else { return 1 }
        return need
    }
    //星期几
    var weekDay : NSInteger {
        let interval = Int(self.timeIntervalSince1970)
        let days = Int(interval/86400)
        let weekday = ((days + 4)%7+7)%7
        return weekday == 0 ? 7 : weekday
    }
    
    //是否为今天
    var isToday : Bool {
        return NSCalendar.current.isDateInToday(self)
    }
    //是否为昨天
    var isYesterday : Bool {
        return NSCalendar.current.isDateInYesterday(self)
    }
    //是否为本周
    var isInWeekend : Bool {
        return NSCalendar.current.isDateInWeekend(self)
    }
    //是否为今年
    var isTheYear : Bool {
        let calendar = NSCalendar.current
        guard let year1 = calendar.dateComponents([.year], from: self).year else{
            return false
        }
        guard let year2 = calendar.dateComponents([.year], from: Date()).year else{
            return false
        }
        return year1 == year2
    }
    
}
