//
//  DBManager.swift
//  chat
//
//  Created by 陈健 on 2021/1/12.
//  使用文档可参考：https://juejin.cn/post/6844904117446377485

import UIKit
import WCDBSwift

class DBManager {
    
    enum Table: String {
        case session = "session"
        case user = "user"
        case message = "message"
        case virtualMessage = "virtualMessage"
        case grouplist = "grouplist"
        case groupUserInfo = "groupUserInfo"
        case staffInfo = "staffInfo"
        case teamInfo = "teamInfo"
    }
    
    private static let sharedInstance = DBManager.init()
    static func shared() -> DBManager { return sharedInstance }
    
    private var mainDB: Database?
    private var dbFTS: Database?
    private let ftsQueue = DispatchQueue(label: "com.ftsQueue")
    
    private init() {
        self.createDB()
//        self.createTable()
        self.addObserver()
    }
    
    deinit {
        FZM_NotificationCenter.removeObserver(self)
    }
    
    private func createDB() {
        guard let userDirectory = LoginUser.shared().fileDirectory else { return }
        
        let dbURL = userDirectory.appendingPathComponent("WCDB/main.db")
//        FZMLog("DBURL MainDB------------------\(dbURL)")
        self.mainDB = Database.init(withFileURL: dbURL)
        
        let virtualDBURL = userDirectory.appendingPathComponent("WCDB/virtualFTS.db")
//        FZMLog("DBURL VirDB------------------\(virtualDBURL)")
        self.dbFTS = Database.init(withFileURL: virtualDBURL)
        self.dbFTS!.setTokenizes(.WCDB)
        
        self.createTable()
    }
    
    private func closeDB() {
        guard let mainDB = self.mainDB, let dbFTS = self.dbFTS else { return }
        
        mainDB.close()
        self.mainDB = nil
        
        dbFTS.close()
        self.dbFTS = nil
    }
    
    private func createTable() {
        
        /**
         WCDB使用可参考以下链接
         https://www.dazhuanlan.com/2020/02/09/5e3f9fce09777/
         
         表新增字段，只需在定义处添加，并再次执行createTableAndIndexesOfName:withClass:即可。
         对于需要删除字段，只需将其定义删除即可。
         由于SQLite不支持修改字段名称，因此WCDB使用WCDB_SYNTHESIZE_COLUMN(className, propertyName, columnName)重新映射宏。
         */
//        try? self.mainDB!.create(table: Table.message.rawValue, of: MessageDB.self)
//        try? self.mainDB!.create(table: Table.grouplist.rawValue, of: GroupDB.self)
        
        
        if let mainDB = self.mainDB {
            //创建会话表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.session.rawValue), isTableExists == false {
                try? mainDB.create(table: Table.session.rawValue, of: SessionDB.self)
            //}
            //创建聊天消息表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.message.rawValue),isTableExists == false {
                try? mainDB.create(table: Table.message.rawValue, of: MessageDB.self)
            //}
            //创建用户表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.user.rawValue),isTableExists == false {
                try? mainDB.create(table: Table.user.rawValue, of: UserDB.self)
            //}
            //创建员工信息表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.staffInfo.rawValue),isTableExists == false {
                try? mainDB.create(table: Table.staffInfo.rawValue, of: StaffInfoDB.self)
            //}
            //创建企业信息表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.teamInfo.rawValue),isTableExists == false {
                try? mainDB.create(table: Table.teamInfo.rawValue, of: EnterpriseDB.self)
            //}
            //创建群表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.grouplist.rawValue),isTableExists == false {
                try? mainDB.create(table: Table.grouplist.rawValue, of: GroupDB.self)
            //}
            //创建群用户表
            //if let isTableExists = try? mainDB.isTableExists(DBManager.Table.groupUserInfo.rawValue),isTableExists == false {
                try? mainDB.create(table: Table.groupUserInfo.rawValue, of: GroupMemberDB.self)
            //}
            
            //创建消息虚表(搜索用)
            //if let isTableExists = try? mainDB.isTableExists(Table.virtualMessage.rawValue), !isTableExists {
                try? self.dbFTS?.create(virtualTable: Table.virtualMessage.rawValue, of: VirtualMessageDB.self)
            //}
        }
        
//        if let dbFTS = self.dbFTS {
//            //创建消息虚表(搜索用)
//            if let isTableExists = try? dbFTS.isTableExists(Table.virtualMessage.rawValue),
//               !isTableExists {
//                try? dbFTS.create(virtualTable: Table.virtualMessage.rawValue, of: VirtualMessageDB.self)
//            }
//        }
        
    }
}

// MARK: - CRUD
extension DBManager {
    func insert<Object: TableEncodable>(intoTable table: Table, list: [Object]) {
        if let mainDB = self.mainDB {
            try? mainDB.insert(objects: list, intoTable: table.rawValue)
            
        } else {
            FZMLog("mainDB数据插入失败, 数据库DB为空")
        }
        
        if table == .message {
            self.insertVirtualMore(.virtualMessage, list: list)
        }
    }
    
    func insertOrReplace<Object: TableEncodable>(intoTable table: Table, list: [Object]) {
        guard let mainDB = self.mainDB else {
            FZMLog("mainDB数据插入失败, 数据库DB为空")
            return
        }
        try? mainDB.insertOrReplace(objects: list, intoTable: table.rawValue)
        
        switch table {
        case .message:
            
            let msgList = list as? [MessageDB]
            var virList = [Object]()
            msgList?.forEach({ msgDB in
                // 语音、图片、视频消息搜索不了，排除在消息虚表外
                if msgDB.msgType != 2 || msgDB.msgType != 3 || msgDB.msgType != 4 {
                    virList.append(msgDB as! Object)
                }
            })
            
            guard virList.count > 0 else { return }
            self.insertVirtualData(.virtualMessage, list: virList)
            
        default:
            break
        }
    }
    
    func delete(fromTable table: Table, constraintBlock: ConstraintBlock?) {
        guard let mainDB = self.mainDB else {
            FZMLog("mainDB数据插入失败, 数据库DB为空")
            return
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        try? mainDB.delete(fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
        
        // 删除消息同时删除消息虚表
        if table == .message, self.dbFTS != nil  {
            self.ftsQueue.async {
                let virtable: Table = .virtualMessage
                try? self.dbFTS?.delete(fromTable: virtable.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
            }
        }
    }
    
    func getObjects<Object: TableDecodable>(fromTable table: Table, constraintBlock: ConstraintBlock?) -> [Object] {
        if table == .virtualMessage, self.dbFTS == nil {
            FZMLog("dbFTS查询数据失败, 数据库DB为空")
            return []
        } else if self.mainDB == nil {
            FZMLog("mainDB查询数据失败, 数据库DB为空")
            return []
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        let objects: [Object]?
        let db = table == .virtualMessage ? self.dbFTS : self.mainDB
        objects = try? db?.getObjects(on: Object.Properties.all, fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
        return objects ?? []
    }
    
    func update<Object: TableEncodable>(table: Table, with object: Object, constraintBlock: ConstraintBlock?) {
        guard let mainDB = self.mainDB else {
            FZMLog("数据更新失败, 数据库DB为空")
            return
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        try? mainDB.update(table: table.rawValue, on: Object.Properties.all, with: object, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
    }
    
    func update<Object: TableEncodable>(table: Table, on propertyConvertibleList: [PropertyConvertible], with object: Object, constraintBlock: ConstraintBlock?) {
        guard let mainDB = self.mainDB else {
            FZMLog("数据更新失败, 数据库DB为空")
            return
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        try? mainDB.update(table: table.rawValue, on: propertyConvertibleList, with: object, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
    }
    
    func update(table: Table, on propertyConvertibleList: [PropertyConvertible], with row: [ColumnEncodable], constraintBlock: ConstraintBlock?) {
        guard let mainDB = self.mainDB else {
            FZMLog("数据更新失败, 数据库DB为空")
            return
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        try? mainDB.update(table: table.rawValue, on: propertyConvertibleList, with: row, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
    }
}

extension DBManager {
    func deleteVirtualData(_ table: Table, constraintBlock: ConstraintBlock? = nil) {
        self.ftsQueue.async {
            let constraint = Constraint.init()
            constraintBlock?(constraint)
            guard let dbFTS = self.dbFTS else { return }
            try? dbFTS.delete(fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
        }
    }
    
    func insertVirtualMore<Object: TableEncodable>(_ table: Table, list: [Object]) {
        self.ftsQueue.async {
            if table == .virtualMessage, let list = list as? [MessageDB] {
                guard let dbFTS = self.dbFTS else { return }
                let virList = list.compactMap { return VirtualMessageDB.init(with: $0) }
                try? dbFTS.insert(objects: virList, intoTable: table.rawValue)
            }
        }
    }
    
    func insertVirtualData<Object: TableEncodable>(_ table: Table, list: [Object]) {
        self.ftsQueue.async {
            if table == .virtualMessage, let list = list as? [MessageDB] {
                guard let dbFTS = self.dbFTS else { return }
                let virList = list.compactMap { return VirtualMessageDB.init(with: $0) }
                
                /**
                 DBManager.shared().delete(fromTable: .message) { (constraint) in
                     constraint.condition = MessageDB.Properties.msgId.is(msgId)
                 }
                 
                 try? self.dbFTS?.delete(fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
                 */
                
                virList.forEach { msgDB in
                    try? dbFTS.delete(fromTable: table.rawValue, where: VirtualMessageDB.Properties.msgId == msgDB.msgId)
                }
                
//                try? dbFTS.insertOrReplace(objects: virList, intoTable: table.rawValue)
                
                try? dbFTS.insert(objects: virList, intoTable: table.rawValue)
            }
        }
    }
}

// MARK: - Login , Logout
extension DBManager {
    
    private func addObserver() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogin), name: FZM_Notify_UserLogin, object: LoginUser.shared())
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogout), name: FZM_Notify_UserLogout, object: LoginUser.shared())
    }
    
    @objc private func userLogin() {
        self.closeDB()
        self.createDB()
    }
    
    @objc private func userLogout() {
        self.closeDB()
    }
}
