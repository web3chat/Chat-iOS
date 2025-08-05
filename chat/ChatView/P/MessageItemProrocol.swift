//
//  MessageItemProrocol.swift
//  chat
//
//  Created by 王俊豪 on 2021/11/10.
//

import Foundation
import Photos
import SwiftUI

// 图片、视频、语音
protocol MediaItem {
    var url: String? { get }
    func imageAsync(block: @escaping (UIImage?)->())
    var duration: Double? { get }
    var size : CGSize { get }
    var mediaCachekey: String? { get }
}

//// 转发
//protocol ForwardItem {
//    var forwardAvatar: String? { get }
//    var forwardName: String? { get }
//    var forwardMsgType: Int? { get }
//    var forwardMsg: Data? { get }
//    var forwardDatetime: Int? { get }
//}

// 名片
protocol ContactCardItem {
    var contactId: String? { get }
    var contactName: String? { get }
    var contactAvatar: String? { get }
    var contactType: Int? { get } // 1个人名片，2群聊名片 -1专属红包
}

// 文件
protocol FileItem {
    var fileUrl: String? { get }
    var fileSize: Int? { get }
    var fileName: String? { get }
    var localFilePath: String? { get }
    var md5: String? { get }
    var iconImageName: String? { get }
    var cachekey: String? { get }
}

// 通知
/** ** type **
 UpdateGroupNameAlert //0
 SignInGroupAlert   //1
 SignOutGroupAlert  //2
 KickOutGroupAlert  //3
 DeleteGroupAlert  //4
 UpdateGroupMutedAlert   //5
 UpdateGroupMemberMutedAlert   //6
 UpdateGroupOwnerAlert //7
 MsgRevoked//8
 */
protocol NotifyItem {
    var text: String { get }//通知内容具体展示文字
    var type: Int { get }//通知类型                 all
    var groupId: Int { get }// 群id                all
    var operatorId: String? { get }// 操作人      0 2 3 4 5 6
    var groupname: String? { get }//更新的群名称     0
    var inviter: String? { get }//邀请人            1
    var members: [String]? { get }//成员列表        1 3 6
    var mutetype: Int? { get }//禁言类型            5
    var newOwner: String? { get }//新群主           7
}

// 通话
protocol RTCCallItem {
    var fileUrl: String? { get }
    var fileSize: Int? { get }
    var duration: Double? { get }
}


protocol TransferItem {
    var coinName:String? {get} // 币种名称
    var txHash:String? {get}
}
