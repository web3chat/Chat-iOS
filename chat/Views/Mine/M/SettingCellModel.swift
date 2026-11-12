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
    /// 右侧是否显示 chevron 箭头（默认显示；「清理缓存」这类只展示数值、点一下弹确认的行不需要）
    var showsArrow: Bool = true
}

class SettingSwitchCellModel: SettingCellModel {
    var isSwitchOn: Bool = false
    
    var switchChangeBlock: ((Bool)->())?
}
