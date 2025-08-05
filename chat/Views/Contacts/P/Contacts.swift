//
//  Contacts.swift
//  chat
//
//  Created by 陈健 on 2021/1/26.
//

import Foundation

protocol Contacts {
    var contactsName: String { get }
    var avatarURLStr: String { get }
    var sessionID: SessionID { get }
}
