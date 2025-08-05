//
//  ResidentThread.swift
//  chat
//
//  Created by 陈健 on 2021/3/3.
//

import Foundation

class ResidentThread: NSObject {
    private let thread: Thread = {
        let thread = Thread.init {
            autoreleasepool {
                let currentRunLoop = RunLoop.current
                currentRunLoop.add(Port.init(), forMode: .common)
                currentRunLoop.run()
            }
        }
        thread.name = "com.residentThread.defauletName"
        thread.start()
        return thread
    }()
    
    var name: String? { didSet { self.thread.name = name } }
    
    override init() { }
    
    deinit {
        // need exit thred
    }
    
    @objc private func threadTask(_ task: ()->()) { task() }
    
    func execute(_ task: @escaping ()->(), waitUntilDone: Bool = false) {
        let wrappedBlock: @convention(block) () -> () = { task() }
        self.perform(#selector(self.threadTask(_:)), on: self.thread, with: wrappedBlock, waitUntilDone: waitUntilDone)
    }

    func execute(afterDelay: TimeInterval, execute: @escaping ()->(), waitUntilDone: Bool = false) {
        let wrappedBlock1: @convention(block) () -> () = { execute() }
        let wrappedBlock2: @convention(block) () -> () = {
            self.perform(#selector(self.threadTask(_:)), with: wrappedBlock1, afterDelay: afterDelay)
        }
        self.perform(#selector(self.threadTask(_:)), on: self.thread, with: wrappedBlock2, waitUntilDone: waitUntilDone)
    }
}
