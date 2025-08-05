//
//  MultipleDownloadManager.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/3.
//

import Foundation

class MultipleDownloadManager {
    
    private static let sharedInstance = MultipleDownloadManager.init()
    static func shared() -> MultipleDownloadManager { return sharedInstance }
    
    private var downloadManages: [DownloadManager] = []
    
    init() {
    }
    
}
