//
//  ControllerIntercepter.swift
//  xls
//
//  Created by 陈健 on 2020/7/31.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import UIKit

class ViewControllerIntercepter: NSObject {
    private static let sharedInstance = ViewControllerIntercepter()
    
    @discardableResult
    @objc class func shared() -> ViewControllerIntercepter {
        return sharedInstance
    }
    
    override private init() {
        super.init()
        
        // Do not use 'self.hook()', because of Aspect is incompatible with Bugly
        //self.hook();
    }
    
    
    private func hook() {
        // -------------viewDidLoad-------------
        let didLoadWrappedBlock: @convention(block) (AspectInfo) -> Void = {[weak self] aspectInfo in
            guard let vc = aspectInfo.instance() as? UIViewController else { return }
            self?.viewDidLoad(vc)
        }
        _ = try? UIViewController.aspect_hook(NSSelectorFromString("viewDidLoad"), with: AspectOptions(rawValue: 0), usingBlock: didLoadWrappedBlock)
        
        // -------------viewWillAppear-------------
        let willAppearWrappedBlock: @convention(block) (AspectInfo, Bool) -> Void = {[weak self] aspectInfo, animated in
            guard let vc = aspectInfo.instance() as? UIViewController else { return }
            self?.viewWillAppear(animated, vc)
        }
        _ = try? UIViewController.aspect_hook(NSSelectorFromString("viewWillAppear:"), with: AspectOptions(rawValue: 0), usingBlock: willAppearWrappedBlock)
        
        // -------------ViewDidAppear-------------
        let didAppearWrappedBlock: @convention(block) (AspectInfo, Bool) -> Void = {[weak self] aspectInfo, animated in
            guard let vc = aspectInfo.instance() as? UIViewController else { return }
            self?.viewDidAppear(animated, vc)
        }
        _ = try? UIViewController.aspect_hook(NSSelectorFromString("viewDidAppear:"), with: AspectOptions(rawValue: 0), usingBlock: didAppearWrappedBlock)
        
        // -------------viewWillDisappear-------------
        let willDisappearWrappedBlock: @convention(block) (AspectInfo, Bool) -> Void = {[weak self] aspectInfo, animated in
            guard let vc = aspectInfo.instance() as? UIViewController else { return }
            self?.viewWillDisappear(animated, vc)
        }
        _ = try? UIViewController.aspect_hook(NSSelectorFromString("viewWillDisappear:"), with: AspectOptions(rawValue: 0), usingBlock: willDisappearWrappedBlock)
        
        // -------------dealloc-------------
        let deinitWrappedBlock: @convention(block) (AspectInfo) -> Void = {[weak self] aspectInfo in
            guard let vc = aspectInfo.instance() as? UIViewController else { return }
            self?.controllerDeinit(vc)
        }
        _ = try? UIViewController.aspect_hook(NSSelectorFromString("dealloc"), with: .positionBefore, usingBlock: deinitWrappedBlock)
    }
    
    
    @objc func viewDidLoad(_ controller: UIViewController) {
        guard let controller = controller as? ViewControllerProtocol else { return }
        self.setView(controller)
    }
    
    @objc func viewWillAppear(_ animated: Bool, _ controller: UIViewController) {
        guard let controller = controller as? ViewControllerProtocol else { return }
        controller.navigationController?.setNavigationBarHidden(controller.xls_isNavigationBarHidden, animated: true)
        
        controller.navigationController?.navigationBar.isTranslucent = false
        //BackgroundColor
        controller.navigationController?.navigationBar.backgroundColor = controller.xls_navigationBarBackgroundColor ?? DefaultValue.navigationBarBackgroundColor
        controller.navigationController?.navigationBar.barTintColor = controller.xls_navigationBarBackgroundColor ?? DefaultValue.navigationBarBackgroundColor
        
        //rightBarButtonItem leftBarButtonItem color
        controller.navigationController?.navigationBar.tintColor = controller.xls_navigationBarTintColor ?? DefaultValue.navigationBarTintColor
        
        controller.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
    }
    
    @objc func viewDidAppear(_ animated: Bool, _ controller: UIViewController) {
        if let navigationController = controller as? UINavigationController, navigationController.viewControllers.first is ViewControllerProtocol {
            navigationBarBottomLineView(in: navigationController.navigationBar)?.isHidden = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
            navigationController.delegate = self
            return
        }
    }
    
    @objc func viewWillDisappear(_ animated: Bool, _ controller: UIViewController) {
        guard let _ = controller as? ViewControllerProtocol else { return }
    }
    
    @objc func controllerDeinit(_ controller: UIViewController) {
        #if DEBUG
        print("------🐂🍺dealloc🐂🍺------\(controller.description)")
        #endif
    }
}

extension ViewControllerIntercepter: UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        navigationController.interactivePopGestureRecognizer?.isEnabled = navigationController.viewControllers.count > 1
    }
}

extension ViewControllerIntercepter {
    private func navigationBarBottomLineView(in targetView: UIView) -> UIImageView? {
        if targetView.isKind(of: UIImageView.self) && targetView.frame.size.height <= 1.0 {
            return targetView as? UIImageView
        }
        for subV in targetView.subviews {
            if let imageV = navigationBarBottomLineView(in: subV) {
                return imageV
            }
        }
        return nil
    }
}

extension ViewControllerIntercepter {
    private func setNavLineHideOrShow(_ controller: ViewControllerProtocol) {
        guard let backgroundView = controller.navigationController?.navigationBar.subviews.first else { return }
        
        for view in backgroundView.subviews {
            if view.frame.size.height > 0 && view.frame.size.height <= 1.0 {
                view.isHidden = controller.xls_isNavigationLineHidden
            }
        }
    }
    
    private func setView(_ controller: ViewControllerProtocol) {
        if controller.view.backgroundColor == nil {
            controller.view.backgroundColor = DefaultValue.viewBackgroundColor
        }
        setTitleTextAttributes(controller)
        setBackItem(controller)
    }
    
    private func setTitleTextAttributes(_ controller: ViewControllerProtocol) {
        controller.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: DefaultValue.navigationBarTitleColor]
    }
    
    private func setBackItem(_ controller: ViewControllerProtocol) {
        guard let parent = controller.parent, parent.children.count > 1 else { return }
        let backItem = BackBarButtonItem.init { [unowned controller] in
            controller.navigationController?.popViewController(animated: true)
        }
        controller.navigationItem.leftBarButtonItem = backItem
    }
    
    private class BackBarButtonItem: UIBarButtonItem {
        private let block: () -> Void
        init(_ block: @escaping () -> Void) {
            self.block = block
            super.init()
//            image = UIImage(named: "nav_back")
//            style = .plain
//            target = self
//            action = #selector(backAction)
//            imageInsets = UIEdgeInsets(top: 0, left: -7, bottom: 0, right: 0)
//            tintColor = DefaultValue.backItemTintColor
            let leftView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 45, height: 44))
            let leftButton = UIButton.init(type: .custom)
            leftButton.frame = CGRect.init(x: 0, y: 0, width: 45, height: 44)
            leftButton.setImage(#imageLiteral(resourceName: "nav_back").withRenderingMode(.alwaysTemplate), for: .normal)
            leftButton.contentHorizontalAlignment = .left
            leftButton.contentVerticalAlignment = .center
            leftButton.tintColor = Color_24374E
            leftButton.addTarget(self, action: #selector(backAction), for: .touchUpInside)
            leftView.addSubview(leftButton)
            customView = leftView
        }
        
        @objc private func backAction() { block() }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}


extension ViewControllerIntercepter {
    private struct DefaultValue {
        static let viewBackgroundColor = UIColor.white
        static let navigationBarBackgroundColor = UIColor.white
        static let navigationBarTintColor = UIColor(red: 36 / 255, green: 55 / 255, blue: 78 / 255, alpha: 1)
        static let backItemTintColor = UIColor(red: 36 / 255, green: 55 / 255, blue: 78 / 255, alpha: 1)
        static let navigationBarTitleColor = UIColor(red: 36 / 255, green: 55 / 255, blue: 78 / 255, alpha: 1)
    }
}
