//
//  ContactViewModel.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/10.
//

import Foundation
import RxSwift

@objc class ContactViewModel: NSObject {
    
    var type: Message.ChannelType = .person
    
    var sessionIDStr: String = ""
    
    var name = "" {
        didSet{
            infoSubject.onNext((name,avatar))
        }
    }
    
    var avatar = "" {
        didSet{
            infoSubject.onNext((name,avatar))
        }
    }
    
    var isSelected = false
    
    var infoSubject = BehaviorSubject<(String,String)>(value: ("",""))
    
    var user: User?
    
    var group: Group?
    
    var groupMember: GroupMember?
    
    var searchString: String? = nil
    
    override init() {
        super.init()
    }
    
    init(with user: User) {
        super.init()
        type = .person
        name = user.contactsName
        avatar = user.avatarURLStr
        
        sessionIDStr = user.sessionID.idValue
        self.user = user
    }
    
    init(with group: Group) {
        super.init()
        type = .group
        name = group.contactsName
        avatar = group.avatarURLStr
        sessionIDStr = group.sessionID.idValue
        self.group = group
    }
    
    init(with groupMember: GroupMember) {
        super.init()
        type = .person
        name = groupMember.contactsName
        avatar = groupMember.avatarURLStr
        sessionIDStr = groupMember.memberId
        self.groupMember = groupMember
    }
}
