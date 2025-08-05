//
//  UserDefaults+Tool.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/25.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import Foundation

let UUIDKey = "UUIDKey"

//let inputType = "ConversationInputType"

extension UserDefaults {
    
//    func setConversationInputValue(_ value: Bool, conversation: SocketConversationModel) {
//        let useKey = inputType + "_\(conversation.type.rawValue)" + "_\(conversation.conversationId)"
//        self.set(value, forKey: useKey.keyForUser())
//        self.synchronize()
//    }
//    
//    func getConversationInputValue(conversation: SocketConversationModel) -> Bool {
//        let useKey = inputType + "_\(conversation.type.rawValue)" + "_\(conversation.conversationId)"
//        return self.bool(forKey: useKey.keyForUser())
//    }
    
    func setUserValue(_ value: Any?, forKey key: String) {
        self.set(value, forKey: key.keyForUser())
//        self.synchronize()
    }
    func getUserObject(forKey key: String) -> Any? {
        return self.object(forKey: key.keyForUser())
    }
    
    class func getUUID() -> String {
        if let str = UserDefaults.standard.string(forKey: UUIDKey) {
            return str
        }else {
            var uuid = ""
            if let useid = UIDevice.current.identifierForVendor?.uuidString {
                uuid = useid
            }
            let formatter = DateFormatter.getDataformatter()
            formatter.dateFormat = "yyyyMMddhhmmss"
            let str = "\(uuid)\(formatter.string(from: Date()))"
            UserDefaults.standard.set(str, forKey: UUIDKey)
//            UserDefaults.standard.synchronize()
            return str
        }
    }
    
}

extension String {
    func keyForUser() -> String {
        if LoginUser.shared().isLogin {
            return "\(self)_\(LoginUser.shared().address)"
        }
        return self
    }
}
