//
//  SettingCellModel.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/15.
//

import UIKit

class SettingCellModel: NSObject {
    var leftString: String?
    var leftAttributedString: NSAttributedString?
    
    var isShowLine: Bool?
    
    var selectedBlock: (()->())?
}

class SettingTextCellModel: SettingCellModel {
    var rightString: String?
    var rightAttributedString: NSAttributedString?
}

class SettingSwitchCellModel: SettingCellModel {
    var isSwitchOn: Bool = false
    
    var switchChangeBlock: ((Bool)->())?
}
