//
//  NSError+Extension.swift
//  chat
//
//  Created by 陈健 on 2021/1/22.
//

import Foundation

extension NSError {
    class func error(with description: String) -> NSError {
        let error = NSError.init(domain: "com.local.create.error", code: 101010, userInfo: [NSLocalizedDescriptionKey: description])
        return error
    }
}
