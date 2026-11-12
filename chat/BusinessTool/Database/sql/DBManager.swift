//
//  DBManager.swift
//  chat
//
//  Created by fzm on 2021/1/12.
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
        case burnPending = "burn_pending_confirm"
        /// 解密失败消息的原始密文（点击气泡可重试解密）
        case unparsedMsg = "unparsed_msg_cipher"
    }
    
    private static let sharedInstance = DBManager.init()
    static func shared() -> DBManager { return sharedInstance }
    
    private var mainDB: Database?
    private var dbFTS: Database?
    private let ftsQueue = DispatchQueue(label: "com.ftsQueue")
    /// 当前连接对应的文件路径（判断能否复用，避免同一 path 反复新建 / 关闭连接）
    private var mainDBPath: String?
    private var ftsDBPath: String?
    
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
        
        // ⚠️ 安全整改：聊天库、媒体副本、钱包库都在 Documents/<address>/ 下且为明文，
        //    默认会进 iCloud/iTunes 备份。这里把整个用户目录排除出备份，降低离线泄露面。
        Self.excludeFromBackup(userDirectory)
        
        let dbURL = userDirectory.appendingPathComponent("WCDB/main.db")
        let virtualDBURL = userDirectory.appendingPathComponent("WCDB/virtualFTS.db")

        // 路径没变就复用已有的 Database（同一个句柄池），**不要关掉重建**：
        // WCDB 把 sqlite 句柄缓存在线程本地（`Database.flowOut() → threadedHandles[path]`），
        // 关掉再新建会让这条线程手里的缓存变成已关闭句柄 —— 详见 `closeDB()` 的注释。
        if self.mainDBPath == dbURL.path, self.mainDB != nil, self.dbFTS != nil {
            FZMLog("数据库路径未变，复用已有连接: \(dbURL.path)")
            // 建表是幂等的（IF NOT EXISTS），顺手再跑一次，保持和「新建」分支行为一致
            self.createTable()
            return
        }

        self.mainDB = Database.init(withFileURL: dbURL)
        self.mainDBPath = dbURL.path
        
        // 虚表库（FTS 搜索）
        // - Database.init 是懒打开的，不碰文件，所以可以当场建好对象 + 注册 tokenizer，
        //   保证登录后搜索、消息写入能立刻用上；
        // - 「建虚表」这个碰文件的动作排到 ftsQueue 上**异步**执行：
        //   ① 和所有虚表写入串行，不会出现「表还没建就往里写」；
        //   ② **不阻塞调用线程** —— 登录/登出通知是主线程发出的。
        let fts = Database.init(withFileURL: virtualDBURL)
        fts.setTokenizes(.WCDB)
        // 先把这个「建虚表」的块排进队列，再切换 self.dbFTS：
        // 这样后续入队的写入一定排在「建虚表」之后，不会出现「表还没建就往里写」。
        self.ftsQueue.async {
            do {
                try fts.create(virtualTable: Table.virtualMessage.rawValue, of: VirtualMessageDB.self)
            } catch {
                FZMLog("消息虚表创建失败: \(error)")
            }
        }
        self.dbFTS = fts
        self.ftsDBPath = virtualDBURL.path
        
        self.createTable()
    }
    
    /// 把用户目录及其下所有文件标记为「不参与备份」。
    ///
    /// 聊天正文、图片/语音副本、钱包库都是明文；排除备份后，即使 iCloud/iTunes 备份
    /// 泄露也不会带走这些数据（换机/重装会丢本地历史，这是安全上的取舍）。
    private static func excludeFromBackup(_ directory: URL) {
        var dir = directory
        var dirValues = URLResourceValues()
        dirValues.isExcludedFromBackup = true
        try? dir.setResourceValues(dirValues)

        guard let enumerator = FileManager.default.enumerator(at: directory,
                                                              includingPropertiesForKeys: nil) else { return }
        for case let file as URL in enumerator {
            var url = file
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
    }

    private func closeDB() {
        // ⚠️ 这里**故意不调用 `Database.close()`**（= `HandlePool.drain()`）。
        //
        // WCDB 会把 sqlite 句柄缓存在**线程本地**（见 Pods/WCDB.swift/.../Database.swift）：
        //     private static var threadedHandles = ThreadLocal<[String: RecyclableHandle]>()
        //     private func flowOut() { if let handle = threadedHandles[path] { return handle } ... }
        // 也就是说「同一个 path」这条线程下次还会拿到同一份句柄。
        // 而 drain() 会把池子里的句柄 `clear()` 掉（= 关闭），可线程本地那份缓存并不知道，
        // 于是这条线程（虚表写入全部跑在 ftsQueue 上）下一次写就会用到**已关闭的句柄**，
        // 直接崩在 WCDBSwift 内部 —— 历次闪退栈：
        //     closure #1 in DBManager.syncVirtualMessages(_:) → WCDBSwift → libswiftCore
        //
        // 所以这里只放开引用：没人用时 ARC 自然释放；同一个 path 下次登录会走到
        // createDB() 的「复用」分支，也就不会出现「关掉再重建」的窗口。
        self.mainDB = nil
        self.mainDBPath = nil
        self.dbFTS = nil
        self.ftsDBPath = nil
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
            
            //创建阅后即焚待确认队列表
            try? mainDB.create(table: Table.burnPending.rawValue, of: BurnPendingDB.self)

            //创建「解密失败密文」暂存表（点击气泡重试解密用）
            try? mainDB.create(table: Table.unparsedMsg.rawValue, of: UnparsedMsgDB.self)
            
            //创建消息虚表(搜索用)：现在跟着「换库」一起在 ftsQueue 上异步建（见 createDB）
            //if let isTableExists = try? mainDB.isTableExists(Table.virtualMessage.rawValue), !isTableExists {
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
            guard let messages = list as? [MessageDB] else {
                // 以前这里用泛型 + 运行时强转：强转失败时什么也不会发生，搜索会莫名其妙搜不到，很难查
                FZMLog("消息虚表同步被跳过：入参不是 [MessageDB]（\(Object.self)）")
                return
            }
            self.insertVirtualMore(.virtualMessage, list: messages)
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
            guard let messages = list as? [MessageDB] else {
                FZMLog("消息虚表同步被跳过：入参不是 [MessageDB]（\(Object.self)），这部分消息将搜不到")
                return
            }
            // 语音(2)/图片(3)/视频(4) 没有可搜索文本，`VirtualMessageDB.init?(with:)` 里已按内容过滤
            self.syncVirtualMessages(messages)
            
        default:
            break
        }
    }

    /// 消息写入（主表 + 搜索虚表）：收/发消息都走这条，**类型明确、不做任何运行时强转**
    func insertOrReplaceMessages(_ list: [MessageDB]) {
        guard let mainDB = self.mainDB else {
            FZMLog("mainDB数据插入失败, 数据库DB为空（\(list.count) 条消息未落库）")
            return
        }
        do {
            try mainDB.insertOrReplace(objects: list, intoTable: Table.message.rawValue)
        } catch {
            // ⚠️ 不能静默吞掉：写库失败 = 这批消息本地永久缺失，
            //    而 syncMsg 断点会随后面的消息继续前进，服务端不会再发回来。
            FZMLog("消息写入 main.db 失败（\(list.count) 条）: \(error)")
        }
        self.syncVirtualMessages(list)
    }
    
    func delete(fromTable table: Table, constraintBlock: ConstraintBlock?) {
        guard let mainDB = self.mainDB else {
            FZMLog("mainDB数据插入失败, 数据库DB为空")
            return
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        try? mainDB.delete(fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
        
        // 删除消息同时删除消息虚表（同样排在 ftsQueue 上，和写入 / 关库串行）
        if table == .message {
            self.ftsQueue.async { [weak self] in
                guard let self = self, let dbFTS = self.dbFTS else { return }
                let virtable: Table = .virtualMessage
                do {
                    try dbFTS.delete(fromTable: virtable.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
                } catch {
                    FZMLog("消息虚表删除失败: \(error)")
                }
            }
        }
    }
    
    func getObjects<Object: TableDecodable>(fromTable table: Table, constraintBlock: ConstraintBlock?) -> [Object] {
        // 虚表查询保持「直接读、不排队」：搜索是主线程发起的，排队等 ftsQueue 会卡 UI。
        // 安全性：WCDB 的 close() → HandlePool.drain() 只清池子里的**空闲**句柄，
        // 正在被本线程使用的句柄不会被关（下面同时用 dbFTS 强引用住对象）。
        if table == .virtualMessage, self.dbFTS == nil {
            FZMLog("dbFTS查询数据失败, 数据库DB为空")
            return []
        } else if self.mainDB == nil {
            FZMLog("mainDB查询数据失败, 数据库DB为空")
            return []
        }
        let constraint = Constraint.init()
        constraintBlock?(constraint)
        let db = table == .virtualMessage ? self.dbFTS : self.mainDB
        // 注意：必须显式标注成 [Object]?，否则 `try?` 的泛型只能从返回值反推，
        // 编译器会报 "Generic parameter 'Object' could not be inferred"
        let objects: [Object]? = try? db?.getObjects(on: Object.Properties.all, fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
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
        self.ftsQueue.async { [weak self] in
            guard let self = self, let dbFTS = self.dbFTS else { return }
            let constraint = Constraint.init()
            constraintBlock?(constraint)
            do {
                try dbFTS.delete(fromTable: table.rawValue, where: constraint.condition, orderBy: constraint.orderBy, limit: constraint.limit, offset: constraint.offset)
            } catch {
                FZMLog("消息虚表删除失败: \(error)")
            }
        }
    }
    
    /// 把消息追加进搜索虚表。
    /// 入参类型写死 `[MessageDB]`：不再用泛型 + `list as? [MessageDB]` ——
    /// 泛型里做这个运行时强转，类型对不上时既不报错也不干活（搜索莫名其妙搜不到），
    /// 而且它属于「运行时才知道行不行」的写法，出问题时很难定位。
    func insertVirtualMore(_ table: Table, list: [MessageDB]) {
        guard table == .virtualMessage else {
            FZMLog("消息虚表写入被跳过：表名不是 virtualMessage（\(table.rawValue)）")
            return
        }
        self.syncVirtualMessages(list)
    }
    
    /// 把消息同步进 FTS 虚表（**所有虚表写入都走这条函数**）。
    ///
    /// 三个坑：
    /// 1. 必须全程在 `ftsQueue` 上：和 `closeDB()`（也排在这条队列）串行，
    ///    否则关库会和正在写的语句并发，句柄被 drain 掉就是 EXC_BAD_ACCESS 闪退；
    /// 2. 可搜索行要在**调用线程**上先构造好（纯属性读取、无 IO）：异步块里就不再拿着
    ///    `MessageDB` 模型对象，避免对象在别的线程被释放/改写；
    /// 3. 不能再用 `try?` 把错误吞掉：出错时完全无感（搜索莫名其妙搜不到），现在打日志。
    private func syncVirtualMessages(_ messages: [MessageDB]) {
        guard !messages.isEmpty else { return }
        // 语音 / 图片 / 视频消息没有可搜索文本，在 `VirtualMessageDB.init?` 里返回 nil 被过滤。
        // ⚠️ 这一步必须在**调用线程**上做完：`MessageDB` 是消息管线里的对象，可能被别的线程改写/释放，
        //    放到 ftsQueue 上去读它，就会在 WCDB 编码字符串时炸（栈：WCDBSwift → libswiftCore）。
        //    这样异步块里只剩下自己新建的、不再被别人碰的 `VirtualMessageDB`。
        let rows = messages.compactMap { VirtualMessageDB.init(with: $0) }
        guard !rows.isEmpty else { return }
        // 分批入队（每批一个独立事务）：网关积压时可能一次来上千条，
        // 一条大事务会把 ftsQueue 占住很久（搜索/关库都得排队等），拆小更稳
        var start = 0
        while start < rows.count {
            let end = min(start + DBManager.virtualMessageBatchSize, rows.count)
            let batch = Array(rows[start..<end])
            start = end
            self.ftsQueue.async { [weak self] in
                guard let self = self else { return }
                guard let dbFTS = self.dbFTS else {
                    FZMLog("消息虚表写入失败, 数据库DB为空（条数 \(batch.count)）")
                    return
                }
                let table = Table.virtualMessage.rawValue
                do {
                    // FTS3 虚表没有唯一约束（建表时写的 PRIMARY KEY 也不会生效，
                    // 已用 sqlite3 验证过：CREATE VIRTUAL TABLE ... fts3(msgId TEXT PRIMARY KEY, ...) 合法但不去重），
                    // 同一个 msgId 重复插入会让搜索结果出现重复行，所以先按 msgId 删旧行；
                    // 「删 + 插」放在一个事务里：少几次落盘、也不会出现「删了没插」的中间态。
                    try dbFTS.run(transaction: {
                        for row in batch {
                            try dbFTS.delete(fromTable: table, where: VirtualMessageDB.Properties.msgId == row.msgId)
                        }
                        try dbFTS.insert(objects: batch, intoTable: table)
                    })
                } catch {
                    FZMLog("消息虚表写入失败（条数 \(batch.count)）: \(error)")
                }
            }
        }
    }

    /// 单次虚表写入的最大条数（超过就拆成多个事务）
    private static let virtualMessageBatchSize = 200
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
