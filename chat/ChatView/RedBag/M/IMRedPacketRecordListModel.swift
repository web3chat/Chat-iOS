//
//  IMRedPacketRecordListModel.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/9/13.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import SwiftyJSON

class IMRedPacketRecordListModel: NSObject {

    var count = 0
    var sum :Float = 0
    var coinId = 0
    var coinName = ""
    var redPackets = [IMRedPacketModel]()
    
    init(with httpJson: JSON) {
        super.init()
        count = httpJson["count"].intValue
        sum = httpJson["sum"].floatValue
        coinId = httpJson["coinId"].intValue
        coinName = httpJson["coinName"].stringValue
        redPackets = httpJson["redPackets"].arrayValue.compactMap({ IMRedPacketModel.init(with: $0)})
    }
}

