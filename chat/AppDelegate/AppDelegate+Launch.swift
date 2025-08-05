//
//  AppDelegate+Launch.swift
//  chat
//
//  Created by 陈健 on 2021/1/12.
//

import Foundation

extension AppDelegate {
    func launch() {
        self.launchView()
        let _ = APP.shared()
        let _ = DBManager.shared()
        let _ = SessionManager.shared()
        let _ = UserManager.shared()
        let _ = GroupManager.shared()
        let _ = TeamManager.shared()
        
        OSS.launchClient()
        DispatchQueue.main.async {
            MultipleSocketManager.shared().updateConnectedSockets()
        }
    }
}

