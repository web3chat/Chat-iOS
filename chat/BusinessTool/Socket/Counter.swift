//
//  Counter.swift
//  chat
//
//  Created by 陈健 on 2021/1/19.
//

import Foundation

class Counter {
    static private let queue = DispatchQueue.init(label: "com.Counter.queue")
    static private(set) var value = Int.random(in: 1...2000000000)
    
    static func increment () -> Int {
        self.queue.sync {
            self.value = self.value + 1
        }
        return self.value
    }
}
