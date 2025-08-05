//
//  IMLuckyBagModel.swift
//  IM_SocketIO_Demo
//
//  Created by Wang on 2018/6/19.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import SwiftyJSON

@objc public enum IMRedPacketType : NSInteger {
    case luck = 1//拼手气
    case common = 2//普通
    case promote = 3//推广红包
}

@objc enum IMRedPacketReceiveUserType : NSInteger {
    case old = 1//老用户
    case new = 2//新用户
}

@objc enum IMRedPacketCurrency : NSInteger {
    //1 CNY 2 BTC 3 BTY 4 ETH   5 ETC 7 SC 8 ZEC 9 BTS    10 LTC 11 BCC 12 YCC    15 USDT 17 DCR
    case CNY = 1
    case BTC = 2
    case BTY = 3
    case ETH = 4
    case ETC = 5
    case SC = 7
    case ZEC = 8
    case BTS = 9
    case LTC = 10
    case BCC = 11
    case YCC = 12
    case USDT = 15
    case DCR = 17
}

enum IMRedPacketRecordType: Int {
    case send = 1
    case receive = 2
}

//红包信息
class IMRedPacketModel: NSObject {
    var packetId = ""
    var type : IMRedPacketType = .luck //红包类型
    var senderId : String = "" //发红包用户uid
    var senderUid = "" //托管账户id
    var senderAvatar = ""
    var senderName = ""
    var coinId = -1 //币种
    var coinName = ""
    var amount : Float = 0 //红包金额
    var size : Int = 0 //红包个数
    var toUsers = ""
    var remain = 0
    var status: SocketLuckyPacketStatus = .normal//1:生效中2:已领取完3:过期已退回4:已完成
    var remark = "" //红包祝福语
    var createdAt : Date = Date.init() //发放时间
    var packetUrl = ""
    var revInfo =  IMRedPacketReceiveModel.init()
    
    var countStr: String {
        get {
            return "\(size - remain)/\(size)"
        }
    }

    init(with httpJson : JSON) {
        super.init()
        if let atype = IMRedPacketType.init(rawValue: httpJson["type"].intValue) {
            type = atype
        }
        senderId = httpJson["senderId"].stringValue
        senderUid = httpJson["senderUid"].stringValue
        senderAvatar = httpJson["senderAvatar"].stringValue
        senderName = httpJson["senderName"].stringValue
        coinId = httpJson["coinId"].intValue
        coinName = httpJson["coinName"].stringValue
        amount = httpJson["amount"].floatValue
        size = httpJson["size"].intValue
        toUsers = httpJson["toUsers"].stringValue
        remain = httpJson["remain"].intValue
        status = SocketLuckyPacketStatus.init(rawValue: httpJson["status"].intValue) ?? .normal
        remark = httpJson["remark"].stringValue
        packetUrl = httpJson["packetUrl"].stringValue
        packetId = httpJson["packetId"].stringValue
        let dateTime = httpJson["createdAt"].doubleValue
        createdAt = Date.init(timeIntervalSince1970: dateTime / 1000.0)
        revInfo = IMRedPacketReceiveModel.init(with: httpJson["revInfo"])
    }
    
    init(recordJson : JSON) {
        super.init()
        if let atype = IMRedPacketType.init(rawValue: recordJson["type"].intValue) {
            type = atype
        }
        senderId = recordJson["senderId"].stringValue
        senderUid = recordJson["senderUid"].stringValue
        senderAvatar = recordJson["senderAvatar"].stringValue
        senderName = recordJson["senderName"].stringValue
        coinId = recordJson["coinId"].intValue
        coinName = recordJson["coinName"].stringValue
        amount = recordJson["amount"].floatValue
        size = recordJson["size"].intValue
        toUsers = recordJson["toUsers"].stringValue
        remain = recordJson["remain"].intValue
        status = SocketLuckyPacketStatus.init(rawValue: recordJson["status"].intValue) ?? .normal
        remark = recordJson["remark"].stringValue
        packetUrl = recordJson["packetUrl"].stringValue
        packetId = recordJson["packetId"].stringValue
        let dateTime = recordJson["createdAt"].doubleValue
        createdAt = Date.init(timeIntervalSince1970: dateTime / 1000.0)
        revInfo = IMRedPacketReceiveModel.init(with: recordJson["revInfo"])
    }
    
    func getStatusStr(with type:IMRedPacketRecordType) -> String {
        switch status {
        case .normal:
            return type == .send ? "领取中" : "正在入账"
        case .receiveAll:
            return type == .send ? "已领完" : "入账成功"
        case .past:
            return type == .send ? "已过期" : "入账失败"
        case .opened:
            return type == .send ? "已完成" : "入账失败"
        default:
            return ""
        }
    }
}

//红包领取信息
class IMRedPacketReceiveModel: NSObject {
    var userId = "" //用户uid
    var userName = "" //用户
    var coinName = ""
    var coinId = -1
    var failMessage = ""
    var createdAt = Date.init() //领取时间
    var status = 1//1:正在入账2：入账成功3：入账失败4：用户token失效
    var amount : Float = 0 //领取金额
    var userAvatar = ""
    convenience init(with httpJson : JSON) {
        self.init()
        userId = httpJson["userId"].stringValue
        userName = httpJson["userName"].stringValue
        coinName = httpJson["coinName"].stringValue
        coinId = httpJson["coinId"].intValue
        failMessage = httpJson["failMessage"].stringValue
        let dateTime = httpJson["createdAt"].doubleValue
        createdAt = Date.init(timeIntervalSince1970: dateTime / 1000.0)
        status = httpJson["status"].intValue
        amount = httpJson["amount"].floatValue
        userAvatar = httpJson["userAvatar"].stringValue
       
    }
    override init() {
        super.init()
    }
}
