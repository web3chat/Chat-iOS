//
//  DateFormatter+Extension.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/22.
//

import Foundation

extension DateFormatter {
    static func getDataformatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.system
        dateFormatter.calendar = Calendar.init(identifier: .iso8601)
        return dateFormatter
    }
}
