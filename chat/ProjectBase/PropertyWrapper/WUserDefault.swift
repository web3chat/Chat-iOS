//
//  UserDefault.swift
//  xls
//
//  Created by 陈健 on 2020/11/13.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation

@propertyWrapper
struct WUserDefaults<T:Codable> {
    
    private let key: String
    var wrappedValue: T? {
        set {
            let data = try? JSONEncoder().encode(newValue)
            FZM_UserDefaults.set(data, forKey: key)
        }
        get {
            guard let data = FZM_UserDefaults.value(forKey: key) as? Data else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }
    
    init(key: String) {
        self.key = key
    }
}


