//
//  TeamH5WebViewVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/15.
//

import Foundation
import dsBridge

enum TeamViewType {
    case createTeam// 创建团队
    case joinTeam(url: String)// 加入团队
    case teamMemberList// 组织架构
    case managerTeam// 团队管理
    case selectMember// 选择团队成员（转发消息选择）
    case addGroupMember(groupId: String)// 选择多个团队成员（添加新群成员）
    case createGroup// 选择多个团队成员(创建群聊)
}

class TeamH5WebViewVC: UIViewController, ViewControllerProtocol, WKNavigationDelegate, UIGestureRecognizerDelegate {

    private let urlString: String
    
    private let viewType: TeamViewType
    
    var isCreateOrJoinTeamVCEnter = false
    
    var teamOperationBlock: NormalBlock?// 创建/解散/退出团队block
    
    var selectUsersBlock: StringArrayBlock?// 选择成员block
    
    var excludeUsers: [String]?
    
    lazy var webView: DWKWebView = {
       let v = DWKWebView.init(frame: CGRect.init(x: 0, y: k_StatusBarHeight, width: k_ScreenWidth, height: k_ScreenHeight - k_StatusBarHeight))
        return v
    }()
    
    lazy var progressView: UIProgressView = {
        let v = UIProgressView.init(frame: CGRect.init(x: 0, y: k_StatusBarHeight, width: self.view.bounds.width, height: 1))
        v.tintColor = Color_Theme
        v.trackTintColor = .clear
        v.progress = 0
        return v
    }()
    
    var progress:Float = 0 {
        didSet {
            self.title = webView.title
            self.progressView .setProgress(progress, animated: true)
            if progress >= 1 {
                self.progressView.isHidden = true
                self.progressView.progress = 0
            }
        }
    }
    
    //MARK: -
    let estimatedProgress = "estimatedProgress"
    
    deinit {
        self.webView.removeObserver(self, forKeyPath: estimatedProgress)
        self.webView.removeObserver(self, forKeyPath: "title")
    }
    
    init(with type: TeamViewType) {
        self.viewType = type
        
        var urlStr = ""
        switch type {
        case .createTeam:// 创建团队地址
            urlStr = TeamCreateURL
        case .joinTeam(let url):// 加入团队
            urlStr = url
        case .teamMemberList:// 组织架构入口
            urlStr = TeamListURL
        case .managerTeam:// 管理团队
            urlStr = TeamManagerURL
        case .selectMember:// 团队成员列表（单选，转发消息）
            urlStr = TeamSelectorURL
//        case .selectMultiMember(let groupId):// 团队成员列表（多选，创建群聊/添加新群成员）
//            urlStr = TeamSelectorURL + "&excludeSelf=true&type=multiple&gid=" + groupId
        case .addGroupMember(groupId: let groupId):// 选择多个团队成员（添加新群成员）
            urlStr = TeamSelectorURL + "?action=inviteGroup&excludeSelf=true&type=multiple&gid=" + groupId
        case .createGroup:// 选择多个团队成员(创建群聊)
            urlStr = TeamSelectorURL + "?action=createGroup&excludeSelf=true&type=multiple"
        }
        // http://121.40.18.70:8886/team/selector?action=inviteGroup&excludeSelf=true&type=multiple&gid=174204465929261056
        // createGroup
        self.urlString = urlStr
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 隐藏系统导航栏
        self.xls_isNavigationBarHidden = true
        
        self.view.addSubview(webView)
        self.view.addSubview(progressView)
        
        // "FZM-3SYXIN"
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] (info, error) in
            if var userAgent = info as? String {
                userAgent = userAgent + ";FZM-3SYXIN;"
                self?.webView.customUserAgent = userAgent
                FZMLog(userAgent)
            }
        }
        
        if let url = URL.init(string: self.urlString) {
           webView.load(URLRequest.init(url: url))
        }
        
        webView.addObserver(self, forKeyPath: estimatedProgress, options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        
        webView.setDebugMode(true)
        
        self.configBridgeRegister()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 禁用右滑返回手势
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // 返回上一级页面，没有上一级页面则退出页面
    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            self.closeVC()
        }
    }
    
    // 退出页面
    func closeVC() {
        self.navigationController?.popViewController()
    }
    
    func configBridgeRegister() {
        
        // 处理接收到的h5传入值
        func parameterValid(with data: Any?) -> (result: Bool, data: [String: Any]) {
            if let parameter = data, parameter is NSDictionary {
                let dic = parameter as! NSDictionary
                if let params = dic as? [String: Any] {
                    return (true, params)
                }
            }
            
            return (false, [:])
        }
        
        webView.addJavascriptObject(self, namespace: nil)
        
        webView.navigationDelegate = self
        
        webView.setJavascriptCloseWindowListener {
            FZMLog("H5 func --- window.close called")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath, keyPath == estimatedProgress {
            progress = Float(self.webView.estimatedProgress)
        } else if keyPath == "title" {
            if (object as! UIView == webView){
                self.navigationItem.title = webView.title
            }else{
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }
}

extension TeamH5WebViewVC {
    
    //  进入用户详情页
    private func goUserDetailInfoVC(_ address: String) {
        FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: address, source: .team))
    }
    
    // 扫一扫
    private func goQRCodeReaderVC() {
        // 扫描二维码
        let vc = QRCodeReaderVC.init()
        vc.readBlock = { (qrcodeStr) in
            if qrcodeStr.contains(ShareURL) {
                let address = qrcodeStr.replacingOccurrences(of: ShareURL, with: "")
                
                // 跳转到用户/好友详情页
                FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: address, source: .sweep))
            } else if qrcodeStr.contains("http") {
                // 跳转到Safari打开网页
                APP.shared().openUrl(with: qrcodeStr)
            } else {
                let alertView = UIAlertController.init(title: "扫描结果", message: qrcodeStr, preferredStyle: .alert)
                let alert = UIAlertAction.init(title: "确定", style: .destructive) { _ in
                    FZMLog("扫一扫结果弹窗显示点击确定按钮")
                }
                alertView.addAction(alert)
                DispatchQueue.main.async {
                    UIViewController.current()?.present(alertView, animated: true, completion: nil)
                }
            }
        }
        DispatchQueue.main.async {
            UIViewController.current()?.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
}

//MARK: - 网络请求

extension TeamH5WebViewVC {
    // 获取我的员工信息
    private func refreshMyStaffInfoRequest() {
        TeamManager.shared().getStaffInfo(address: LoginUser.shared().address, successBlock: { [weak self] (staffinfo) in
            guard let strongSelf = self else { return }
            // 获取我的企业信息
            strongSelf.refreshMyTeamInfoRequest()
        }, failureBlock: nil)
    }
    
    // 获取我的企业信息
    private func refreshMyTeamInfoRequest() {
        guard let staffinfo = LoginUser.shared().myStaffInfo else { return }
        TeamManager.shared().getEnterPriseInfo(entId: staffinfo.entId)
    }
}

//MARK: - JS交互

extension TeamH5WebViewVC {
    
    /**
     发送企业名片调用方法是
     sendTeamCard
     参数：id  name  avatar  server
     */
    
    // 必须给第一个参数前添加下划线"_"来显式忽略参数名。
    // 关闭页面
    @objc func close(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- close")
        self.closeVC()
    }
    
    // 返回上一级页面
    @objc func back(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- back")
        self.goBack()
    }
    
    // 进入用户详情页
    @objc func openCompanyUserInfo(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- openCompanyUserInfo")
        guard let address = arg["address"] as? String else { return }
        self.goUserDetailInfoVC(address)
    }
    
    // 扫一扫
    @objc func scanCode(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        handler(String(format:"%@[Swift async call:%@]", arg, "test"), true)
        FZMLog("H5 func --- scanCode")
        self.goQRCodeReaderVC()
    }
    
    // 给h5传值-我的信息
    @objc func getUserInfo(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- getUserInfo")
        
        guard let staffInfo = LoginUser.shared().myStaffInfo else {
            // 获取用户员工信息
            refreshMyStaffInfoRequest()
            return
        }
        
        guard let _ = staffInfo.company else {
            // 获取我的企业信息
            refreshMyTeamInfoRequest()
            return
        }
        
        guard let jsonStr = staffInfo.pDictionary.toJsonString() else {
            return
        }
        FZMLog("getUserInfo \(jsonStr)")
        handler(jsonStr, true)
    }
    
    // 给h5传值-我的公钥
    @objc func getPublicKey(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- getPublicKey")
        
        let pubKey = LoginUser.shared().publicKey
        FZMLog("getPublicKey \(pubKey)")
        handler(pubKey, true)
    }
    
    // 给h5传值-我的手机号
    @objc func getPhone(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- getPhone")
        
        let phone = LoginUser.shared().bindSeedPhone
        FZMLog("getPhone \(phone)")
        handler(phone, true)
    }
    
    // 给h5传值-签名
    @objc func signAuth(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- signAuth")
        guard let signAuth = LoginUser.shared().signature else {
            return }
        FZMLog("signAuth \(signAuth)")
        handler(signAuth, true)
    }
    
    // 接收h5传过来的数据，签名后再传给h5
    @objc func sign(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- sign")
        
        let dic = arg
        
        let privateKey = LoginUser.shared().privateKey
        
        let str = dic.sorted { $0.key < $1.key }.compactMap { "\($0.key)=\($0.value)"}.joined(separator: "&")
        
        guard let rawValue = str.data(using: .utf8)?.sha256(),
              let signature =  EncryptManager.sign(data: rawValue, privateKey: privateKey) else {
            return
        }
        let finalSignAture = signature.finalKey
        FZMLog("sign signature \(finalSignAture)")
        handler(finalSignAture, true)
    }
    
    // 刷新企业信息进入app聊天页面（创建/解散/退出团队）
    @objc func refreshCompanyState(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- refreshCompanyState")
        
        self.teamOperationBlock?()
        
        guard let goHome = arg["goHome"] as? Bool else { return }
        
        // 如果是从创建/加入团队页面进入的H5
        if isCreateOrJoinTeamVCEnter {
            if !goHome {//返回参数为true时则是创建团队成功
                // 获取用户员工信息-创建团队成功后需停留在团队二维码页面，可点击进入组织架构页面，此页面会获取签名
                refreshMyStaffInfoRequest()
            } else {// 返回参数为true时则是解散/退出团队操作
                self.navigationController?.popViewController(animated: false)
                // 解散/退出团队
                LoginUser.shared().quitTeam()
            }
        } else {
            if goHome {
                self.navigationController?.popViewController(animated: false)
            }
        }
    }
    
    // 给h5传值-OA服务器地址
    @objc func getOAServer(_ arg: Dictionary<String, Any>, handler:@escaping JSCallbackBlock) {
        FZMLog("H5 func --- getOAServer")
        
        if APP.shared().modules.count == 0 {
            // 模块启用状态请求（获取OA服务器地址）
            APP.shared().getModulesRequest { [weak self] (json) in
                guard let strongSelf = self else { return }
                strongSelf.view.hideActivity()
                let items = json.arrayValue.compactMap { Modules.init(json: $0) }
                for item in items {
                    if case .oa = item.name {
                        if let url = item.endPoints.first {
                            FZMLog("getOAServer \(url)")
                            handler(url, true)
                        }
                    }
                }
            } failureBlock: { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.view.hideActivity()
                strongSelf.showToast(error.localizedDescription)
            }
        } else {
            
            if TeamOAServerUrl.isBlank {
                for item in APP.shared().modules {
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
            }
            
            FZMLog("getOAServer \(TeamOAServerUrl)")
            handler(TeamOAServerUrl, true)
        }
    }
    
    // 给h5传值-已在群成员数据
    @objc func getGroupMembers(_ arg: Dictionary<String, Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- getGroupMembers")
        
        if let userIds = excludeUsers {
            FZMLog("getGroupMembers userIds - \(userIds)")
            let data : NSData! = try? JSONSerialization.data(withJSONObject: userIds, options: []) as NSData?
            let JSONString = NSString(data:data as Data,encoding: String.Encoding.utf8.rawValue)

            handler(JSONString! as String, true)
        }
    }
    
    // 接收h5传过来的选择团队成员数据
    @objc func selectGroupMembers(_ arg: Array<Any>, handler: JSCallbackBlock) {
        FZMLog("H5 func --- selectGroupMembers")
        
        let array = arg
        guard array.count > 0 else { return }
        let groupMembers: [String] = array.compactMap { ($0 as! String) }
        FZMLog("groupMembers --- \(groupMembers)")
        
        self.selectUsersBlock? (groupMembers)
        
        self.closeVC()
    }
}

