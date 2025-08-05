//
//  TeamManager.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/11.
//

import Foundation
import WCDBSwift

class TeamManager {
    
    private static let sharedInstance = TeamManager.init()
    static func shared() -> TeamManager { return sharedInstance }
    
    private let disposeBag = DisposeBag.init()
    
    private init() {
        self.addLoginObserver()
        
        // 加载本地我的团队信息数据和网络请求
        self.loadMyStaffInfoInDBAndNet()
    }
}

//MARK: - Group Net
extension TeamManager {
    /// 加载本地我的员工信息数据和网络请求我的员工信息
    func loadMyStaffInfoInDBAndNet() {
        if LoginUser.shared().isLogin {
            let myStaffInfo = self.getDBStaffInfo(address: LoginUser.shared().address)
            if myStaffInfo != nil {
                LoginUser.shared().myStaffInfo = myStaffInfo
                LoginUser.shared().isInTeam = true
                LoginUser.shared().save()
            }
            
            // 获取我的员工信息和企业信息网络请求
            getStaffInfo(address: LoginUser.shared().address)
        }
    }
    
    // 获取我的员工信息和企业信息网络请求 (顶部导航栏更多视图中点击创建团队调用)
    func getMyStaffInfoAndTeamInfoRequest(successBlock: NormalBlock? = nil, failureBlock: StringBlock? = nil) {
        // 获取员工信息
        self.getStaffInfo(address: LoginUser.shared().address, successBlock: { (info) in
            // 获取企业信息
            self.getEnterPriseInfo(entId: info.entId, successBlock: { _ in
                successBlock?()
            }, failureBlock: { (error) in
                FZMLog("获取企业信息 :\(error)")
                failureBlock?("获取企业信息失败 \(error.localizedDescription)")
            })
        }, failureBlock: { (error) in
            FZMLog("获取用户员工信息 :\(error)")
            failureBlock?("您当前还未加入或创建团队，请先加入或创建团队")
        })
    }
    
    // 获取用户员工信息
    func getStaffInfo(address: String, successBlock: ((StaffInfo)->())? = nil, failureBlock: StringBlock? = nil) {
        guard !TeamOAServerUrl.isBlank else {
            failureBlock?("获取团队信息失败")
            FZMLog("企业服务器地址为空!!!!!")
            
            // 获取模块启用状态
            APP.shared().getModulesRequest()
            return
        }
        Provider.request(TeamAPI.getStaff(address: address)) { (json) in
            if let code = json.int, code == 13001 {// // 查询是否绑定团队，未绑定错误代码13001
                //员工不存在 则从数据库中删除
                TeamManager.shared().deleteStaffInfo(address)
                // 如果查不到自己的员工信息
                if address == LoginUser.shared().address, LoginUser.shared().isInTeam {
                    // 解散/退出团队
                    LoginUser.shared().quitTeam()
                }
                failureBlock?("员工不存在")
            } else {
                let info = StaffInfo.init(json: json)
                
                self.saveStaffInfo([info])
                
                if address == LoginUser.shared().address {
                    LoginUser.shared().myStaffInfo = info
                    LoginUser.shared().isInTeam = true
                    LoginUser.shared().save()
                }
                
                successBlock?(info)
            }
        } failureBlock: { (error) in
            FZMLog("获取用户员工信息 :\(error)")
            failureBlock?(error.localizedDescription)
        }
    }
    
    // 获取企业信息
    func getEnterPriseInfo(entId: String, successBlock: ((EnterPriseInfo)->())? = nil, failureBlock: Provider.FailureBlock? = nil) {
        guard !TeamOAServerUrl.isBlank else {
            // 获取模块启用状态
            APP.shared().getModulesRequest()
            return
        }
        Provider.request(TeamAPI.enterpriseInfo(teamId: entId)) { (json) in
            let info = EnterPriseInfo.init(json: json)
            
            self.saveTeamInfo([info])
            
            if entId == LoginUser.shared().myStaffInfo?.entId {
                LoginUser.shared().myCompanyInfo = info
                LoginUser.shared().myStaffInfo?.company = info
                LoginUser.shared().save()
                
                TeamIMChatServer = Server.init(name: info.name, value: info.imServer, id: info.id)
                TeamBlockchainServer = Server.init(name: info.name, value: info.nodeServer, id: info.id)
                TeamOAServerUrl = info.oaServer
                
//                // 加入团队是否直接切换区块链节点？？
//                if let blockchainServer = TeamBlockchainServer {
//                    BlockchainServerInUse = blockchainServer
//                }
                
                FZM_NotificationCenter.post(name: FZM_Notify_InTeamStatusChanged, object: true)
            }
            
            successBlock?(info)
        } failureBlock: { (error) in
            FZMLog("获取企业信息 :\(error)")
            failureBlock?(error)
        }
    }
}

//MARK: - DB StaffInfo
extension TeamManager {
    
    /// 获取本地数据库员工信息
    func getDBStaffInfo(address: String) -> StaffInfo? {
        let staffInfo = DBManager.shared().getObjects(fromTable: .staffInfo) { (constraint) in
            constraint.condition = StaffInfoDB.Properties.id.is(address)
        }.compactMap { StaffInfo.init(with: $0) }.first
        
        if let info = staffInfo {
            return info
        } else {
            return nil
        }
    }
    
    /// 获取本地数据库员工姓名 - 备注>群昵称>团队姓名>昵称>地址(显示前后各四位)
    func getDBStaffName(address: String) -> String {
        let staffInfo = DBManager.shared().getObjects(fromTable: .staffInfo) { (constraint) in
            constraint.condition = StaffInfoDB.Properties.id.is(address)
        }.compactMap { StaffInfo.init(with: $0) }.first
        
        if let info = staffInfo {
            return info.name
        } else {
            return ""
        }
    }
    
    /// 插入一个员工信息到本地数据库
    func saveStaffInfo(_ infos: [StaffInfo]) {
        
        let staffInfoDBs = infos.compactMap { StaffInfoDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .staffInfo, list: staffInfoDBs)
    }
    
    //删除本地数据库中的某个员工信息
    func deleteStaffInfo(_ address: String){
        DBManager.shared().delete(fromTable: .staffInfo) { (constraint) in
            constraint.condition = StaffInfoDB.Properties.id.is(address)
        }
    }
}

//MARK: - DB EnterpriceInfo
extension TeamManager {
    
    /// 获取本地数据库企业信息
    func getDBTeamInfo(entId: String) -> EnterPriseInfo? {
        let teamInfo = DBManager.shared().getObjects(fromTable: .teamInfo) { (constraint) in
            constraint.condition = EnterpriseDB.Properties.id.is(entId)
        }.compactMap { EnterPriseInfo.init(with: $0) }.first
        
        if let info = teamInfo {
            FZMLog("getDBTeamInfo teamInfo --- \(info)")
            return info
        } else {
            return nil
        }
    }
    
    /// 插入一个企业信息到本地数据库
    func saveTeamInfo(_ infos: [EnterPriseInfo]) {
        
        let teamInfoDBs = infos.compactMap { EnterpriseDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .teamInfo, list: teamInfoDBs)
    }
}

//MARK: - 创建团队相关操作
extension TeamManager {
    func createTeam() {
        
    }
}

//MARK: - User Login
extension TeamManager {
    private func addLoginObserver() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogin), name: FZM_Notify_UserLogin, object: LoginUser.shared())
    }
    
    @objc private func userLogin() {
        self.loadMyStaffInfoInDBAndNet()
    }
}


