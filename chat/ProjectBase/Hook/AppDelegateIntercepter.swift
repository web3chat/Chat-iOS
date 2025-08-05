//
//  AppDelegateIntercepter.swift
//  xls
//
//  Created by 陈健 on 2020/8/18.
//  Copyright © 2020 陈健. All rights reserved.
//

import UIKit
#if DEBUG
import GDPerformanceView_Swift
#endif
import IQKeyboardManagerSwift
import Bugly

class AppDelegateIntercepter: NSObject {
    private static let sharedInstance = AppDelegateIntercepter()
    
    @discardableResult
    @objc class func shared() -> AppDelegateIntercepter {
        return sharedInstance
    }
    
    override private init() {
        super.init()
        // -------------didFinishLaunchingWithOptions-------------
        let didLoadWrappedBlock: @convention(block) (AspectInfo, UIApplication, [UIApplication.LaunchOptionsKey: Any]?) -> Void = { (aspectInfo, application, launchOptions) in
            guard let appDelegate = aspectInfo.instance() as? AppDelegate else { return }
            self.application(application, didFinishLaunchingWithOptions: launchOptions, appDelegate)
        }
        _ = try? AppDelegate.aspect_hook(NSSelectorFromString("application:didFinishLaunchingWithOptions:"), with: AspectOptions(rawValue: 0), usingBlock: didLoadWrappedBlock)
    }
    
    private func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?, _ appDelegate: AppDelegate) {
//        self.loadIQKeyboard()
        self.loadBugly()
        #if DEBUG
        self.loadDebug()
        #endif
    }
}

//MARK:-Bugly
extension AppDelegateIntercepter {
    private func loadBugly() {
        let config = BuglyConfig.init()
        config.blockMonitorEnable = true// 卡顿监控开关
        config.blockMonitorTimeout = 1// 卡顿监控判断间隔，单位为秒
//        config.viewControllerTrackingEnable = false// 页面信息记录开关，默认开启
        config.reportLogLevel = .warn// 自定义日志上报 warn 崩溃时会上报Warn、Error接口打印的日志
        Bugly.start(withAppId: BUGLYID, config: config)
    }
}

//MARK:- DEBUG
extension AppDelegateIntercepter {
    #if DEBUG
    private func loadDebug() {
        self.loadInjectionIII()
//        self.loadPerformanceView()
    }
    
    private func loadInjectionIII() {
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
    }
    
    private func loadPerformanceView() {
        PerformanceMonitor.shared().performanceViewConfigurator.options = [.performance, .memory, .device]
        PerformanceMonitor.shared().performanceViewConfigurator.interactors = [UITapGestureRecognizer.init(target: self, action: #selector(performanceViewTap))]
        PerformanceMonitor.shared().start()
    }
    @objc private func performanceViewTap() {
        PerformanceMonitor.shared().hide()
    }
    #endif
}

//MARK: - touchOutsideToHideKeyboard
extension AppDelegateIntercepter {
    //使用IQKeyboardManager 无需此方法
    private func touchOutsideToHideKeyboard() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    @objc private func keyboardWillShow() {
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(hideKeyboard(sender:)))
        UIApplication.shared.delegate?.window??.addGestureRecognizer(tap)
    }
    
    @objc private func hideKeyboard(sender: UITapGestureRecognizer) {
        UIApplication.shared.delegate?.window??.endEditing(true)
        UIApplication.shared.delegate?.window??.removeGestureRecognizer(sender)
    }
}

//MARK: - IQKeyboardManager
extension AppDelegateIntercepter {
    private func loadIQKeyboard() {
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.shouldResignOnTouchOutside = true
        IQKeyboardManager.shared.keyboardDistanceFromTextField = 20
        IQKeyboardManager.shared.disabledDistanceHandlingClasses = [MessageVC.self]
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
}
