//
//  APP.swift
//  xls
//
//  Created by 陈健 on 2020/9/4.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import SwiftyJSON
import AFNetworking
import Reachability
import RxSwift
import sqlcipher

class APP {
    private static let sharedInstance = APP.init()
    
    class func shared() -> APP {
        return sharedInstance
    }
    private(set) lazy var hasNetworkSubject = PublishSubject<Bool>()
//    private(set) lazy var hasNetworkSubject = BehaviorSubject.init(value: false)
    
    var hasNetwork = false {
        didSet {
            self.hasNetworkSubject.onNext(self.hasNetwork)
        }
    }
    
    var deviceToken: String?// 推送用
    
    var isAutoLogin = true// 是否是手动登录（区分socket的连接状态）
    
    var showUpdateViewFlg = false// 审核状态flg（我的页面是否显示检测更新UI用）
    
    var version: VersionCheck?// 版本检测数据源
    
    var modules = [Modules]()// 模块启用状态
    
    var hasShowNotifCenterFlg = false// 显示去设置推送通知权限alert标识
    
    var hasShowQRCodeViewFlg = false// 首页显示/隐藏下拉的二维码视图标识
    
    private init() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(didFinishLaunching), name: UIApplication.didFinishLaunchingNotification, object: nil)
    }
    
    deinit {
        FZM_NotificationCenter.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

enum AlertType {
    case notifCenter
}

extension APP {
    @objc private func didFinishLaunching() {
       
        // 读取本地存储的审核状态flg
        let flg = FZM_UserDefaults.bool(forKey: CHAT33PRO_SHOW_UPDATE_KEY)
        if flg {
            self.showUpdateViewFlg = flg
        }
        
        // 开启网络状态消息监听
        self.networkStatusListener()
        
        // 检测是否有更新
        self.updateApp()
        
        // 获取模块启用状态
        self.getModulesRequest()
        
        // 刷新我的员工信息和企业信息
        LoginUser.shared().refreshMyStaffInfoAndTeamInfo()
        
        // 刷新我的个人信息
        LoginUser.shared().refreshUserInfo()
        
        // 更新地址弹窗
//        showNoticeView(type: 2) //WJHTODO
    }
}

extension APP {
    /// 重载app页面
    func reloadView() {
       
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.launchView()
    }
    
    /// 多端登录处理（被踢下线）
    func endpointLoginAction(_ pbMsg: PbMsg_ActionEndpointLogin) {
        
        DispatchQueue.main.async {
            // 退出登录时先返回到根页面
            FZMUIMediator.shared().backToRootVC()
            
            LoginUser.shared().logout()

            APP.shared().reloadView()
        }
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
//            let device = pbMsg.device
//            var deviceType = "未知设备"
            
            let deviceName = pbMsg.deviceName
            let datetime = String.showTimeString(with: Double(pbMsg.datetime))
            
            let alert = InfoAlertView.init()
            alert.hideCrossBtn = true
            alert.autoHide = false
            alert.touchBackgroundToHide = false
            alert.attributedTitle = NSAttributedString.init(string: "退出通知", attributes: [.font : UIFont.boldFont(17), .foregroundColor : Color_24374E])
            let prefix = "你的账号于 \(datetime) 在 \(deviceName) 设备上登录。如果不是你的操作，可能你的密码或助记词已经泄露。请尽快修改密码或创建新助记词账户使用。\n"
            
            let attString = NSMutableAttributedString(string: prefix, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.regularFont(16)])
            alert.attributedInfo = attString
            
            alert.confirmBtnTitle = "知道了"
            
            alert.confirmBlock = {
                alert.removeFromSuperview()
            }
            alert.show()
        }
    }
    
    /// 系统公告
    /// - Parameter type: 展示类型，1：生成新地址；2.备份信息
    private func showNoticeView(type: Int) {
        let alert = InfoAlertView.init()
        alert.hideCrossBtn = true
        alert.autoHide = false
        alert.touchBackgroundToHide = false
        alert.attributedTitle = NSAttributedString.init(string: "系统公告", attributes: [.font : UIFont.systemFont(ofSize: 17), .foregroundColor : Color_24374E])
        var prefix = ""
        var suffix = ""
        var btnTitle = ""
        if type == 1 {
            prefix = "谈信平台的用户账号将统一升级为新地址，为保证您的账号信息能成功备份，请在2022年2月14号前生成新地址并与原地址关联。\n\n"
            suffix = "2022年2月14号前未完成操作则无法备份账号信息，登录后将成为全新的账号！"
            btnTitle = "生成新地址"
        } else if type == 2 {
            prefix = "谈信平台的用户账号将统一升级为新地址，为保证您的账号信息能成功备份，请在2022年2月17号前完成备份。\n\n"
            suffix = "2022年2月17号前未完成操作则无法备份账号信息，登录后将成为全新的账号！"
            btnTitle = "备份信息"
        }
        let prefixAttr = [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.regularFont(16)]
        let suffixAttr = [NSAttributedString.Key.foregroundColor: Color_DD5F5F, NSAttributedString.Key.font: UIFont.boldFont(16)]
        let attString = NSMutableAttributedString(string: prefix + suffix)
        attString.addAttributes(prefixAttr, range: NSRange.init(location: 0, length: prefix.count))
        attString.addAttributes(suffixAttr, range: NSRange.init(location: prefix.count, length: suffix.count))
        alert.attributedInfo = attString
        
        alert.confirmBtnTitle = btnTitle
        
        alert.confirmBlock = {
            alert.removeFromSuperview()
            FZMUIMediator.shared().pushVC(.goTeamH5WebVC(type: .managerTeam, completeBlock: {
            }))
        }
        alert.show()
    }
    
    // 使用系统自带浏览器打开网页
    func openUrl(with path: String) {
        var path = path
        if !(path as NSString).contains("http") {
            path = "http://" + path
        }
        guard let url = URL(string: path) else { return }
        let can = UIApplication.shared.canOpenURL(url)
        if can {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:]) { (b) in
                    FZMLog("打开结果: \(b)")
                }
            } else {
                //iOS 10 以前
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    func showAlertController(type: AlertType) {
        var titleStr = ""
        var messageStr = ""
        var btnStr = ""
        switch type {
        case .notifCenter:
            self.hasShowNotifCenterFlg = true
            titleStr = "“\(APPNAME)”想给您发送通知"
            messageStr = "“通知”可能包括提醒、声音和图标标记。这些可在“设置”中配置"
            btnStr = "去设置"
        }
        let alertController = UIAlertController.init(title: titleStr, message: messageStr, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        let okAction = UIAlertAction.init(title: btnStr, style: .destructive) { _ in
            //打开应用的设置界面
            if let url = URL(string: UIApplication.openSettingsURLString) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        DispatchQueue.main.async {
            UIViewController.current()?.present(alertController, animated: true, completion: nil)
        }
    }
    
    func showToast(_ message: String) {
        DispatchQueue.main.async {
            UIApplication.shared.keyWindow?.showToast(message)
        }
    }
    
    
}

// MARK: - 网络请求
extension APP {
    
    /// 从中心化服务器获取默认的IM服务器地址和区块链节点地址
    func getOfficialServerRequest(successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        
        Provider.request(DiscoveryAPI.disc) {(json) in
            
            // IM地址
            OfficialChatServers = json["servers"].arrayValue.compactMap {
                Server.init(name: $0["name"].stringValue, value: $0["address"].stringValue)
            }
            
            // 区块链节点地址
            OfficialBlockchainServers = json["nodes"].arrayValue.compactMap {
                Server.init(name: $0["name"].stringValue, value: $0["address"].stringValue)
            }
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("获取模块启用状态失败 \(error)")
            failureBlock?(error)
        }
    }
    
    // 获取模块启用状态
    func getModulesRequest(successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        Provider.request(SystemAPI.getModules) { [weak self] (json) in
            let items = json.arrayValue.compactMap { Modules.init(json: $0) }
            self?.modules = items
            for item in items {
                if case .oa = item.name {
                    if let url = item.endPoints.first {
                        TeamOAServerUrl = url
                    }
                }
                if case .wallet = item.name {
                    if let url = item.endPoints.first {
                        WalletServerUrl = url
                    }
                }
            }
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("获取模块启用状态失败 \(error)")
            failureBlock?(error)
        }
    }
    
    // 检测是否有更新
    func updateApp() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !currentVersion.isEmpty else { return }
        let versionCode = Int(currentVersion.replacingOccurrences(of: ".", with: ""))!
        Provider.request(SystemAPI.update(versionCode: versionCode), successBlock: { [weak self] (json) in
            guard let self = self else { return }
            self.version = VersionCheck.init(json: json)
            guard self.version != nil else { return }
            if !self.showUpdateViewFlg {
                self.showUpdateViewFlg = self.version!.versionCode < versionCode
                if self.showUpdateViewFlg {
                    FZM_UserDefaults.set(self.showUpdateViewFlg, forKey: CHAT33PRO_SHOW_UPDATE_KEY)
                }
            }
            
            guard self.version!.versionCode > versionCode else {
                FZMLog("检测是否有更新成功 : 暂无更新")
                return
            }
            
            let updateView = UpdateAppView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight), versionCheck: self.version!)
            
            UIApplication.shared.keyWindow?.addSubview(updateView)
            
        }) { (error) in
            FZMLog("检测是否有更新 error : \(error)")
        }
    }
}

extension APP {
    // 开启网络状态消息监听
    private func networkStatusListener() {
        AFNetworkReachabilityManager.shared().startMonitoring()
        AFNetworkReachabilityManager.shared().setReachabilityStatusChange { [weak self] (status) in
            switch status {
            case .unknown:
                FZMLog("netmanager-------当前网络未知unknown")
                self?.hasNetwork = false
            case .notReachable:
                FZMLog("netmanager-------当前网络不可以用，请检查!")
                self?.hasNetwork = false
            case .reachableViaWWAN:
                FZMLog("netmanager-------网络连接：蜂窝可用")
                self?.hasNetwork = true
            case .reachableViaWiFi:
                FZMLog("netmanager-------网络连接：WIFI可用")
                self?.hasNetwork = true
            @unknown default:
                FZMLog("netmanager-------当前网络未知default")
                self?.hasNetwork = false
            }
        }
    }
}
