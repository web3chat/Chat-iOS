//
//  OKRH5WebViewVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/11/16.
//

import Foundation
import dsBridge

class OKRH5WebViewVC: UIViewController, ViewControllerProtocol, WKNavigationDelegate, UIGestureRecognizerDelegate {
    
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
        
        if let url = URL.init(string: OKRH5Url) {
           webView.load(URLRequest.init(url: url))
        }
        
        webView.addObserver(self, forKeyPath: estimatedProgress, options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        
        webView.setDebugMode(true)
        
        self.configBridgeRegister()
    }

    // MARK: - 域名白名单

    /// 只允许 OKR 官方站点（含 www 跳转）；其它 https 一律交给系统浏览器。
    private var allowedHosts: Set<String> {
        var hosts = Set<String>()
        if let host = URL(string: OKRH5Url)?.host?.lowercased(), !host.isEmpty {
            hosts.insert(host)
            if !host.hasPrefix("www.") {
                hosts.insert("www." + host)
            }
        }
        return hosts
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "https" else {
            // http / file / data / 自定义 scheme 一律不在 OKR 容器内加载
            decisionHandler(.cancel)
            if scheme == "http" {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }
        guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
            FZMLog("OKR：拒绝非白名单域名 \(url.host ?? "nil")")
            decisionHandler(.cancel)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        decisionHandler(.allow)
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
            // KVO 的 object 不一定是 UIView；强转会崩，改为可选判断
            if let observedView = object as? UIView, observedView == webView {
                self.navigationItem.title = webView.title
            }else{
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }
}

extension OKRH5WebViewVC {
    
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
                let alertView = UIAlertController.init(title: L("扫描结果"), message: qrcodeStr, preferredStyle: .alert)
                let alert = UIAlertAction.init(title: L("确定"), style: .destructive) { _ in
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

extension OKRH5WebViewVC {
    // 获取我的员工信息
    private func refreshMyStaffInfoRequest() {
        guard FZM_EnableEnterpriseFeature else { return }// 企业号功能关闭，不发员工信息请求
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

extension OKRH5WebViewVC {
    
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
    
    // ⚠️ 安全整改（2026-11-10）：
    //   `signAuth` 会把当前会话签名（含公钥、可复用的 FZM-SIGNATURE）直接交给页面；
    //   `sign` 会用用户私钥对页面传入的任意键值对盲签，且无内容展示。
    //   两者都足以让钓鱼页伪造身份/授权，已下线；OKR 若确需签名，请走服务端
    //   「一次性挑战 + 结构化字段 + 原生确认页」，不要恢复这两个方法。
    //
    // @objc func signAuth(...)
    // @objc func sign(...)
}
