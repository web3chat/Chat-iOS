//
//  GroupApply.swift
//  chat
//
//  入群申请（加群方式 joinType == 2「入群需审核」时的申请单）
//  接口：POST /group/app/create-group-apply、get-group-applys、accept-group-apply、reject-group-apply
//  字段以《审批入群_App对接文档》为准
//

import Foundation
import SwiftyJSON

struct GroupApply {
    /// 申请单号（通过/拒绝时回传）
    var applyId: String
    /// 群ID（JSON 字段名是 id，注意它不是申请单号）
    var groupId: String
    /// 邀请人；空表示自己申请
    var inviterId: String
    /// 申请人
    var memberId: String
    /// 申请备注
    var applyNote: String
    /// 审批人，待审为空
    var operatorId: String
    /// 0 待审，1 通过，2 拒绝，10 忽略
    var applyStatus: Int
    /// 拒绝原因
    var rejectReason: String
    /// 创建时间（毫秒）
    var createTime: Int
    /// 更新时间（毫秒）
    var updateTime: Int

    /// 是否待审核
    var isWaiting: Bool {
        return self.applyStatus == 0
    }
}

extension GroupApply {
    init(json: JSON) {
        self.applyId = GroupApply.str(json, ["applyId"])
        self.groupId = GroupApply.str(json, ["id", "idStr", "groupId"])
        self.inviterId = GroupApply.str(json, ["inviterId"])
        self.memberId = GroupApply.str(json, ["memberId", "uid", "userId"])
        self.applyNote = GroupApply.str(json, ["applyNote", "applyInfo"])
        self.operatorId = GroupApply.str(json, ["operatorId"])
        self.applyStatus = GroupApply.num(json, ["applyStatus", "status"])
        self.rejectReason = GroupApply.str(json, ["rejectReason"])
        self.createTime = GroupApply.num(json, ["createTime"])
        self.updateTime = GroupApply.num(json, ["updateTime"])
    }
}

extension GroupApply {
    /// 解析申请列表：data.applys（兼容直接数组 / list / items 等结构）
    static func parseList(_ json: JSON) -> [GroupApply] {
        var array = json["applys"].array ?? json.array ?? []
        if array.isEmpty {
            let arrayKeys = ["applies", "list", "items", "rows", "records"]
            for key in arrayKeys {
                if let list = json[key].array {
                    array = list
                    break
                }
            }
        }
        let list = array.map { GroupApply.init(json: $0) }
        return list.filter { !$0.applyId.isEmpty }
    }

    /// 从多个候选 key 里取第一个存在的值
    fileprivate static func value(_ json: JSON, _ keys: [String]) -> JSON? {
        for key in keys {
            if json[key].exists() {
                return json[key]
            }
        }
        return nil
    }

    fileprivate static func str(_ json: JSON, _ keys: [String]) -> String {
        guard let value = value(json, keys), value.type != .null else { return "" }
        if let str = value.string {
            return str
        }
        if let num = value.int {
            return String(num)
        }
        return ""
    }

    fileprivate static func num(_ json: JSON, _ keys: [String]) -> Int {
        guard let value = value(json, keys), value.type != .null else { return 0 }
        if let num = value.int {
            return num
        }
        if let str = value.string {
            return Int(str) ?? 0
        }
        return 0
    }
}
