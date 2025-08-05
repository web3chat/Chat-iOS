//
//  FZMRedBagCoinCellVM.swift
//  IMSDK
//
//  Created by 陈健 on 2019/3/18.
//

import UIKit

class FZMRedBagCoinCellModel: NSObject {
    var amount: Double = 0
    var icon = ""
    var coin = -909
    var decimalPlaces = 2
    var coinNickname = ""
    var coinName = ""
    var singleMax:Double = 0
    var singleMin:Double = 0
    var fee: Double = 0
    var coinNameAndNickname: String {
        get {
            return coinNickname + "/" + coinName
        }
    }
    init(with dic:[String:Any]) {
        super.init()
        if let coinName = dic["coinName"] as? String,
            let coinNickname = dic["coinNickname"] as? String,
            let icon = dic["iconUrl"] as? String,
            let amount = dic["amount"] as? Double,
            let coin = dic["coinId"] as? Int,
            let decimalPlaces = dic["decimalPlaces"] as? Int,
            let singleMin = dic["singleMin"] as? Double,
            let singleMax = dic["singleMax"] as? Double {
            let fee = dic["fee"] as? Double ?? 0
            self.coinName = coinName
            self.coinNickname = coinNickname
            self.icon = icon
            self.amount = amount
            self.coin = coin
            self.decimalPlaces = decimalPlaces
            self.singleMin = singleMin
            self.singleMax = singleMax
            self.fee = fee
        }
    }
}
