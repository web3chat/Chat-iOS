//
//  RecordPush.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/16.
//

import Foundation

struct RecordPush {
    var logId: Int
    var datetime: Int
}

extension RecordPush {
    init(json: JSON) {
        self.logId = json["logId"].intValue
        self.datetime = json["datetime"].intValue
    }
}

extension RecordPush: Codable {
    private enum CodingKeys: CodingKey {
        case logId, datetime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(logId, forKey: .logId)
        try container.encode(datetime, forKey: .datetime)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.logId = try container.decode(Int.self, forKey: .logId)
        self.datetime = try container.decode(Int.self, forKey: .datetime)
    }
}
