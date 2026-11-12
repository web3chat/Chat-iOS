//
//  FZMRedBagCoinCellVM.swift
//  IMSDK
//
//  Created by fzm on 2019/3/18.
//

import UIKit

class FZMRedBagCoinCellModel: NSObject {
    var amount: Double = 0
    var icon = ""
    var coin = -909
    var decimalPlaces = 2
    var coinNickname = ""
    var coinName = ""
    /// 代币合约地址，nil 表示原生代币（ETH/BTY 等）
    var contractAddress: String?
    /// 是否是原生代币
    var isNativeToken: Bool {
        return contractAddress == nil || contractAddress == "0x0000000000000000000000000000000000000000" || contractAddress?.isEmpty == true
    }
    
    var coinNameAndNickname: String {
        get {
            return coinNickname + "/" + coinName
        }
    }
    
    init(with dic:[String:Any]) {
        super.init()
        // 必需的字段
        guard let coinName = dic["coinName"] as? String,
              let coin = dic["coinId"] as? Int else {
            return
        }

        // 可选字段，使用默认值
        self.coinName = coinName
        self.coin = coin
        self.coinNickname = dic["coinNickname"] as? String ?? coinName
        self.icon = dic["iconUrl"] as? String ?? ""
        self.amount = dic["amount"] as? Double ?? 0
        self.decimalPlaces = dic["decimalPlaces"] as? Int ?? 18
        self.contractAddress = dic["contractAddress"] as? String
    }
}
