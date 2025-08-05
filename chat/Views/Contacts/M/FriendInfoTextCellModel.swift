//
//  FriendInfoTextCellModel.swift
//  chat
//
//  Created by 陈健 on 2021/3/5.
//

import UIKit

//class FriendInfoCellModel: NSObject {
//    var leftString: String?
//    var leftAttributedString: NSAttributedString?
//
//    var selectedBlock: (()->())?
//}

// 黑名单
class FriendInfoTextCellModel: NSObject {
    var leftString: String?
    var rightString: String?
    
    var selectedBlock: (()->())?
}

// 置顶/免打扰
class FriendInfoSwitchCellModel: NSObject {
    
    var isOnTop: Bool?
    
    var isMuteNofification: Bool?
    
    var isOnTopSwitchChangeBlock: BoolBlock?
    
    var isMuteSwitchChangeBlock: BoolBlock?
    
    var clickChatRecordBlock: NormalBlock?
    
    var clickChatFileBlock: NormalBlock?
}

// 服务器
class FriendInfoServerCellModel: NSObject {
    var serverName: String?
    var serverUrlStr: String?
    var isAvailable: Bool?
    
    var selectedBlock: NormalBlock?
}

// 员工信息
class FriendInfoTeamCellModel: NSObject {
    // 真实姓名
    var userRealName: String? {
        didSet {
            guard let userRealName = userRealName, !userRealName.isBlank else {
                self.userRealName = "无"
                return
            }
        }
    }
    // 团队
    var organizationName: String? {
        didSet {
            guard let organizationName = organizationName, !organizationName.isBlank else {
                self.organizationName = "无"
                return
            }
        }
    }
    var phone: String?// 手机号
    var shortPhone: String?// 警用短号
    // 员工邮箱
    var email: String? {
        didSet {
            guard let email = email, !email.isBlank else {
                self.email = "无"
                return
            }
        }
    }
    // 员工所属部门名称
    var depName: String? {
        didSet {
            guard let depName = depName, !depName.isBlank else {
                self.depName = "无"
                return
            }
        }
    }
    // 员工职位
    var position: String? {
        didSet {
            guard let position = position, !position.isBlank else {
                self.position = "无"
                return
            }
        }
    }
}
