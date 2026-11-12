//
//  ControllerIntercepter.swift
//  xls
//
//  Created by fzm on 2020/7/31.
//  Copyright © 2020 fzm. All rights reserved.
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

        // 默认返回按钮在这里补（不能放 viewDidLoad，原因见方法注释）
        setDefaultBackItemIfNeeded(controller)
        
        // 侧滑返回被取消时，这里会被再调一次（回滚结束时再恢复一次左边距）
        if let coordinator = controller.transitionCoordinator, coordinator.isInteractive {
            coordinator.animate(alongsideTransition: nil) { [weak self, weak controller] _ in
                guard let self = self, let controller = controller else { return }
                self.restoreNavigationBarLeftMarginIfNeeded(controller)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak controller] in
                    guard let self = self, let controller = controller else { return }
                    self.restoreNavigationBarLeftMarginIfNeeded(controller)
                }
            }
        }
    }
    
    @objc func viewDidAppear(_ animated: Bool, _ controller: UIViewController) {
        // 转场结束后再开右滑返回（本工程几乎都用了自定义 leftBarButtonItem，UIKit 会禁用该手势；
        // 放在 viewWillAppear 里会在 push 过程中改手势状态，容易出现闪屏/手势失效）
        Self.enableSwipeBackIfNeeded(controller)
        restoreNavigationBarLeftMarginIfNeeded(controller)
        // 兜底：页面在 viewWillAppear 之后才设自己的左侧按钮 ⇒ 摘掉这里补的默认返回按钮
        if let vc = controller as? ViewControllerProtocol {
            removeDefaultBackItemIfPageHasOwn(vc)
        }
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
    
    // MARK: - 导航栏：取消侧滑返回后返回按钮左移被裁
    ///
    /// 取消侧滑回滚后，`_UINavigationBarContentView` 的 `layoutMargins.left` 会被 UIKit 置 0，
    /// 返回按钮随即左移被屏幕左边缘裁掉。
    ///
    /// ⚠️ contentView 是私有视图，直接改它的 layoutMargins 会崩
    /// （Client error attempting to change layout margins of a private view），
    /// 所以改公开的 `navigationBar.layoutMargins`，让系统重新推断内容视图的边距。
    ///
    /// ⚠️ iOS 26/27 的 contentView 左边距**恒为 0**（2026-10-30 真机日志），
    ///    所以这里只能在「先见过非 0 值」的机型上生效；那种机型本来也不会出现这个 bug。
    private var navigationBarNormalMargins: UIEdgeInsets?

    /// 只打一次的导航栏度量日志（排查返回按钮位置用）
    private var hasLoggedNavMetrics = false

    private func restoreNavigationBarLeftMarginIfNeeded(_ controller: UIViewController) {
        guard let nav = (controller as? UINavigationController) ?? controller.navigationController else { return }
        let bar = nav.navigationBar
        guard let contentView = bar.subviews.first(where: { String(describing: type(of: $0)).contains("ContentView") }) else { return }
        let margins = contentView.layoutMargins
        #if DEBUG
        // 返回按钮位置排查：左边距 + `_leadingBarConstraints` 的实际常量
        // （GKNavigationBar 会把常量改成 `gk_navItemLeftSpace - gk_fixedSpace()`）
        if !hasLoggedNavMetrics {
            hasLoggedNavMetrics = true
            let constants = (viewControllerLayoutLeadingConstants(bar) ?? []).map { String(format: "%.1f", $0) }
            FZMLog("[NAV] contentView.layoutMargins=\(margins) leadingConstraints=\(constants)")
        }
        #endif
        if margins.left > 0 {
            // 正常态：记下边距
            navigationBarNormalMargins = margins
            return
        }
        guard let normal = navigationBarNormalMargins, normal.left > 0 else { return }
        // ⚠️ 值相同时 UIKit 不会重新推断内容视图边距（这就是第一次能修好、第二次修不好的原因），
        // 所以先制造一次变化，再写回正常值。
        var barMargins = bar.layoutMargins
        if barMargins.left == normal.left {
            barMargins.left = normal.left - 1
            bar.layoutMargins = barMargins
            bar.layoutIfNeeded()
        }
        barMargins.left = normal.left
        bar.layoutMargins = barMargins
        bar.layoutIfNeeded()
    }

    /// 私有 API 的 KVC 取值：key 不存在时会抛 `NSUnknownKeyException`（`valueForUndefinedKey:`）直接崩溃，
    /// 所以先用 `responds(to:)` 判断 getter 是否存在。
    /// （iOS 26 起 `_UINavigationBarContentView` 已经没有 `_layout` 这个 key）
    private func safeValue(forKey key: String, on object: NSObject) -> Any? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key)
    }

    /// `_UINavigationBarContentViewLayout` 里 leading 约束的实际常量（排查返回按钮位置用）
    private func viewControllerLayoutLeadingConstants(_ bar: UINavigationBar) -> [CGFloat]? {
        guard let contentView = bar.subviews.first(where: { String(describing: type(of: $0)).contains("ContentView") }),
              let layout = safeValue(forKey: "_layout", on: contentView) as? NSObject,
              let constraints = safeValue(forKey: "_leadingBarConstraints", on: layout) as? [NSLayoutConstraint] else {
            return nil
        }
        return constraints
            .filter { $0.firstAttribute == .leading && $0.secondAttribute == .leading }
            .map { $0.constant }
    }

    @objc func controllerDeinit(_ controller: UIViewController) {
        #if DEBUG
        print("------🐂🍺dealloc🐂🍺------\(controller.description)")
        #endif
    }
}

extension ViewControllerIntercepter: UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    /// 全局右滑返回：栈内多于一页就允许，不做动画、不改转场，避免闪屏
    static func enableSwipeBackIfNeeded(_ controller: UIViewController) {
        guard let nav = controller.navigationController,
              let gesture = nav.interactivePopGestureRecognizer else { return }
        let intercepter = ViewControllerIntercepter.shared()
        if gesture.delegate !== intercepter {
            gesture.delegate = intercepter
        }
        let shouldEnable = nav.viewControllers.count > 1
        if gesture.isEnabled != shouldEnable {
            gesture.isEnabled = shouldEnable
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = gestureRecognizer.view?.next
        while let current = responder, !(current is UINavigationController) {
            responder = current.next
        }
        guard let nav = responder as? UINavigationController else { return false }
        guard nav.viewControllers.count > 1 else { return false }
        // 转场进行中不响应，避免嵌套 push/pop
        guard nav.transitionCoordinator == nil else { return false }
        return true
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        navigationController.interactivePopGestureRecognizer?.isEnabled = navigationController.viewControllers.count > 1
        // push/pop 完成后，把可能被 UIKit 清零的导航栏左边距恢复
        restoreNavigationBarLeftMarginIfNeeded(viewController)

        // push 进二级页面 / pop 回 Tab 根页面 ⇒ 让 TabBar 上的 AI 客服悬浮球重新判断显隐。
        // ⚠️ 只覆盖「本类是导航代理」的那几个 Tab（根页面是 ViewControllerProtocol）；
        // 资产/发现走 OC 基类 `CommonViewController` 发同名通知，切 Tab 由 FZMTabBarController 的 didSelect 处理。
        NotificationCenter.default.post(name: FZM_Notify_FloatingAIVisibilityShouldUpdate, object: nil)
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
        // 默认返回按钮不在这里补（见 `setDefaultBackItemIfNeeded`）
    }
    
    private func setTitleTextAttributes(_ controller: ViewControllerProtocol) {
        controller.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: DefaultValue.navigationBarTitleColor]
    }
    
    /// 补默认返回按钮（导航栈第 2 页及以后），**只在页面自己没设左侧按钮时补**。
    ///
    /// ⚠️ 必须在 `viewWillAppear` 里补、不能放在 `viewDidLoad`：
    ///    iOS 26 上页面自己设的 `leftBarButtonItem` 不会顶掉这里设的 `leftBarButtonItems`，
    ///    两者会并排显示在导航栏左侧 ⇒ 看起来就是「多了返回按钮」
    ///    （2026-11-06 头像大图页 / 红包详情页反馈：一深一浅两个返回箭头）。
    ///    放到 `viewWillAppear` 时页面的 `viewDidLoad` 已经跑完，能先判断页面自己有没有左侧按钮。
    private func setDefaultBackItemIfNeeded(_ controller: ViewControllerProtocol) {
        guard controller.navigationItem.leftBarButtonItem == nil,
              (controller.navigationItem.leftBarButtonItems ?? []).isEmpty else { return }
        guard let parent = controller.parent, parent.children.count > 1 else { return }
        let backItem = BackBarButtonItem.init { [unowned controller] in
            controller.navigationController?.popViewController(animated: true)
        }

        if #available(iOS 26.0, *) {
            // iOS 26 起导航栏 item 的间距改由 `NavigationBarContentView` 自己算，GKNavigationBar
            // 的私有约束 hook 不再触发；同时 AppDelegate 为了关掉液态玻璃给 `buttonAppearance`
            // 塞了空 backgroundImage，图标因此丢掉了胶囊自带的左右内边距（推测），结果返回图标
            // 直接压在屏幕左边缘（真机截图实测图标距屏幕左边约 6pt）。
            // 这里补一段 fixedSpace 顶回去，让它和有胶囊内边距的系统版本对齐。
            // 只想微调位置就改 `ios26BackItemLeadingSpace` 这一个数：0 = 恢复 iOS 26 原生位置。
            controller.navigationItem.leftBarButtonItems = [Self.leadingSpaceItem(Self.ios26BackItemLeadingSpace), backItem]
        } else {
            // iOS 25 及以下由 GKNavigationBar 统一控制左边距（gk_navItemLeftSpace），保持原样。
            controller.navigationItem.leftBarButtonItem = backItem
        }
    }

    /// 兜底：页面在 `viewWillAppear` 之后才设自己的左侧按钮（如助记词备份校验页），
    /// 把这里补的默认返回按钮（含它前面的 fixedSpace）摘掉，别和页面自己的并排显示。
    private func removeDefaultBackItemIfPageHasOwn(_ controller: ViewControllerProtocol) {
        let items = controller.navigationItem.leftBarButtonItems ?? []
        let others = items.filter { !Self.isDefaultBackItem($0) }
        guard others.count != items.count, !others.isEmpty else { return }
        controller.navigationItem.leftBarButtonItems = others
    }

    /// 是否为这里补的默认返回按钮（`BackBarButtonItem`，或 iOS 26 上它前面那个 fixedSpace）
    private static func isDefaultBackItem(_ item: UIBarButtonItem) -> Bool {
        if item is BackBarButtonItem { return true }
        return item.customView == nil && item.image == nil && item.title == nil
            && item.style == .plain && item.width == ios26BackItemLeadingSpace
    }

    /// iOS 26+ 返回按钮的补偿左边距（pt）。10 ≈ 被空 backgroundImage 去掉的胶囊内边距。
    private static let ios26BackItemLeadingSpace: CGFloat = 10

    /// ⚠️ 每个 navigationItem 必须用**独立**的 item 实例，不能共用同一个静态实例。
    private static func leadingSpaceItem(_ width: CGFloat) -> UIBarButtonItem {
        let item = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        item.width = width
        return item
    }
    
    private class BackBarButtonItem: UIBarButtonItem {
        private let block: () -> Void
        init(_ block: @escaping () -> Void) {
            self.block = block
            super.init()
            // 使用系统 UIBarButtonItem，左内边距由系统给。
            // ⚠️ 旧写法是 customView（45pt 的容器 + 左对齐按钮），图标会贴着屏幕左边（偏左），
            //    在 iOS 26/27 上还会被套上「液态玻璃」胶囊。
            image = UIImage(named: "nav_back")?.withRenderingMode(.alwaysTemplate)
            style = .plain
            target = self
            action = #selector(backAction)
            tintColor = Color_24374E
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
