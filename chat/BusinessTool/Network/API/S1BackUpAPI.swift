//
//  S1BackUpAPI.swift
//  chat
//
//  Created by fzm on 2021/1/29.
//

import Foundation
import Moya

enum S1BackUpAPI {
    case s1phoneSend(phone:String,purpose:String) // 验证码用途purpose: backup / reset / get / delete
    case storeShard(phone:String,code:String,chataddress:String,shard_key:String) //  purpose为backup 存储分片秘钥（首次备份）phone:手机号 code:验证码 chataddress:聊天地址 0x或1x shard_key:分片秘钥
    case getShard(phone:String,code:String) // 获取分片秘钥 本地存储 purpose为get
    case getShardBySms(phone:String,code:String) // 获取分片秘钥,通过手机短信发送给用户 purpose为get
    case checkShardExists(phone:String) // 查询秘钥是否存在
    case resetShard(phone:String,code:String,chataddress:String,shard_key:String) //  purpose为reset 重置分片秘钥phone:手机号 code:验证码 chataddress:聊天地址 0x或1x shard_key:分片秘钥
    case deleteShard(phone:String,code:String) // 注销分片秘钥, purpose为delete
    
    case bindAccount(phone:String,wechat_id:String,xiaohongshu_id:String,douyin_id:String,chataddress:String) // 绑定账号到聊天地址 将手机号微信号小红书号抖音号绑定到聊天地址，支持一个或多个账号到同一个聊天地址
    case queryChatAddress(phone:String,wechat_id:String,xiaohongshu_id:String,douyin_id:String) // 根据手机号、微信号、小红书号或抖音号查询对应的聊天地址。 /
    case queryAccounts(chataddress:String) // 根据聊天地址查询绑定的手机号、微信号、小红书账号。
}

extension S1BackUpAPI: XLSTargetType {
    
    var baseURL: URL {
        return UNCONFIGURED_SERVER_URL
    }
    
    var parameters: [String : Any] {
        switch self {
        case .s1phoneSend(let phone,let purpose):
            return ["phone":phone,"purpose":purpose]
        case .storeShard(let phone,let code,let chataddress,let shard_key):
            return ["phone": phone, "code": code,"chataddress":chataddress,"shard_key":shard_key]
        case .getShard(let phone, let code):
            return ["phone":phone,"code":code]
        case .getShardBySms(let phone, let code):
            return ["phone":phone,"code":code]
        case .checkShardExists(let phone):
            return ["phone":phone]
        case .resetShard(let phone,let code,let chataddress,let shard_key):
            return ["phone": phone, "code": code,"chataddress":chataddress,"shard_key":shard_key]
        case .deleteShard(let phone, let code):
            return ["phone":phone,"code":code]
        case .bindAccount(let phone,let wechat_id,let xiaohongshu_id,let douyin_id,let chataddress):
            return ["phone":phone,"wechat_id":wechat_id,"xiaohongshu_id":xiaohongshu_id,"douyin_id":douyin_id,"chataddress":chataddress]
        case .queryChatAddress(let phone,let wechat_id,let xiaohongshu_id,let douyin_id):
            return ["phone":phone,"wechat_id":wechat_id,"xiaohongshu_id":xiaohongshu_id,"douyin_id":douyin_id]
        case .queryAccounts(let chataddress):
            return ["chataddress":chataddress]
        }
    }
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .s1phoneSend:
            return "/api/v1/send-code"
        case .storeShard:
            return "/api/v1/store-shard"
        case .getShard:
            return "/api/v1/get-shard"
        case .getShardBySms:
            return "/api/v1/get-shard-by-sms"
        case .checkShardExists:
            return "/api/v1/check-shard-exists"
        case .resetShard:
            return "/api/v1/reset-shard"
        case .deleteShard:
            return "/api/v1/delete-shard"
        case .bindAccount:
            return "/api/v1/bind-account"
        case .queryChatAddress:
            return "/api/v1/query-chataddress"
        case .queryAccounts:
            return "/api/v1/query-accounts"
            
        }
    }
}
