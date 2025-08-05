//
//  VersionCheck.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/16.
//

import Foundation

struct VersionCheck {
    var id: Int//最新的版本 版本编号
    var platform: String//平台 chat33pro
    var status: Int//线上状态 0：历史；1：线上版本
    var deviceType: String//终端类型 Android/IOS
    var versionName: String//版本名 3.6.8.10
    var versionCode: Int//版本code 36810
    var url: String//下载地址
    var force: Bool//是否强制更新
    var description: Array<String>//描述信息
    var opeUser: String//操作者
    var md5: String//包的md5
    var size: Int//包大小 单位：byte
    var updateTime: Int//更新时间
    var createTime: Int//创建时间
}

extension VersionCheck {
    init(json: JSON) {
        self.id = json["id"].intValue
        self.platform = json["platform"].stringValue
        self.status = json["status"].intValue
        self.deviceType = json["deviceType"].stringValue
        self.versionName = json["versionName"].stringValue
        self.versionCode = json["versionCode"].intValue
        self.url = json["url"].stringValue
        self.force = json["force"].boolValue
        self.description = json["description"].arrayValue.compactMap{ $0.stringValue }
        self.opeUser = json["opeUser"].stringValue
        self.md5 = json["md5"].stringValue
        self.size = json["size"].intValue
        self.updateTime = json["updateTime"].intValue
        self.createTime = json["createTime"].intValue
    }
}

extension VersionCheck: Codable {
    private enum CodingKeys: CodingKey {
        case id, platform, status, deviceType, versionName, versionCode, url, force, description, opeUser, md5, size, updateTime, createTime
    }
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(platform, forKey: .platform)
        try container.encode(status, forKey: .status)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(versionName, forKey: .versionName)
        try container.encode(versionCode, forKey: .versionCode)
        try container.encode(url, forKey: .url)
        try container.encode(force, forKey: .force)
        try container.encode(description, forKey: .description)
        try container.encode(opeUser, forKey: .opeUser)
        try container.encode(md5, forKey: .md5)
        try container.encode(size, forKey: .size)
        try container.encode(updateTime, forKey: .updateTime)
        try container.encode(createTime, forKey: .createTime)
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.platform = try container.decode(String.self, forKey: .platform)
        self.status = try container.decode(Int.self, forKey: .status)
        self.deviceType = try container.decode(String.self, forKey: .deviceType)
        self.versionName = try container.decode(String.self, forKey: .versionName)
        self.versionCode = try container.decode(Int.self, forKey: .versionCode)
        self.url = try container.decode(String.self, forKey: .url)
        self.force = try container.decode(Bool.self, forKey: .force)
        self.description = try container.decode(Array.self, forKey: .description)
        self.opeUser = try container.decode(String.self, forKey: .opeUser)
        self.md5 = try container.decode(String.self, forKey: .md5)
        self.size = try container.decode(Int.self, forKey: .size)
        self.updateTime = try container.decode(Int.self, forKey: .updateTime)
        self.createTime = try container.decode(Int.self, forKey: .createTime)
    }
}
