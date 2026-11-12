//
//  FZMTabBarController.swift
//  Chat33
//
//  Created by fzm on 2018/9/21.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit

/// 「再次点击已在选中的 Tab」回调
/// 目前只有消息页（`SessionVC`）实现：把当前那一列表（广场 / 私聊 / 群聊）滚回顶部。
protocol FZMTabBarReselectHandler: AnyObject {
    /// 再次点击已经在选中的 Tab，且该 Tab 还停在根页面时回调
    func tabBarDidReselect()
}

public class FZMTabBarController: UITabBarController {

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.drawTabBar()
        self.tabBar.tintColor = Color_Theme
        // 需要知道「再次点击已选中的 Tab」（见文件末尾的 UITabBarControllerDelegate）
        self.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateLan), name: LanguageManager.LanguageChangedNotification, object: nil)

        // AI 客服悬浮球：挂在**本控制器**上（切 Tab 一直在），显隐规则见 `updateFloatingAIVisibility()`
        view.addSubview(aiFloatContainer)
        aiFloatView.install(in: aiFloatContainer)   // install 内部会把自己 addSubview 到容器上
        NotificationCenter.default.addObserver(self, selector: #selector(floatingAIVisibilityShouldUpdate),
                                              name: FZM_Notify_FloatingAIVisibilityShouldUpdate, object: nil)
        // 登录 / 退出登录后也要重判（球只在已登录时显示）
        NotificationCenter.default.addObserver(self, selector: #selector(floatingAIVisibilityShouldUpdate),
                                              name: FZM_Notify_UserLogin, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(floatingAIVisibilityShouldUpdate),
                                              name: FZM_Notify_UserLogout, object: nil)
    }
    
    // MARK: - AI 客服悬浮球（全局：挂在 TabBar 上，切 Tab 不消失）

    /// 悬浮球的透明容器：给出「TabBar 之上」那块区域。
    /// 高度 = 屏高 - TabBar 高度，与它原来挂在消息页时的可用区域**完全一致**
    /// ⇒ 默认位置、拖动夹取范围、已保存的归一化位置都不用改。
    private lazy var aiFloatContainer: AIFloatContainerView = {
        let view = AIFloatContainerView()
        view.backgroundColor = .clear
        return view
    }()

    /// AI 客服悬浮球（`chat/AI`）
    private lazy var aiFloatView: AICustomerFloatView = {
        let view = AICustomerFloatView()
        view.onTap = { [weak self] in
            guard let self = self else { return }
            // ⚠️ 不能写 `AICustomerLauncher.push(from: self)`：本控制器**不在导航栈里**，
            // 那样会退化成「包一层导航控制器 present」。必须从当前选中 Tab 的导航栈进页面。
            if let nav = self.selectedViewController as? UINavigationController {
                AICustomerLauncher.push(from: nav.topViewController ?? nav)
            } else {
                AICustomerLauncher.push()
            }
        }
        return view
    }()

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFloatingAIVisibility()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 容器高度用 TabBar 的**高度**算，不用 `tabBar.frame.minY`：
        // push 带 `hidesBottomBarWhenPushed` 的页面时 TabBar 会滑走、frame 一直在变，
        // 用它算会让容器忽大忽小、把球重新夹到别的位置
        let height = max(0, view.bounds.height - tabBar.bounds.height)
        aiFloatContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: height)
        // TabBar 是 UIKit 后加的 ⇒ 每次布局兜一次层级，保证球盖在 TabBar / 内容之上
        view.bringSubviewToFront(aiFloatContainer)
        aiFloatView.relayoutInContainer()
        updateFloatingAIVisibility()
    }

    /// 页面进出（push/pop、切 Tab、前后台）后重新判断悬浮球显隐
    @objc func floatingAIVisibilityShouldUpdate() {
        updateFloatingAIVisibility()
    }

    /// 悬浮球**只在「Tab 根页面」显示**：
    /// - 切 Tab **不隐藏**（用户 2026-09-30 要求）⇒ 只看「当前选中的 Tab 停在第几层」
    /// - push 进二级页面（聊天页 / 币种详情 / AI 客服页…）时隐藏
    private func updateFloatingAIVisibility() {
        guard isViewLoaded else { return }
        let isAtTabRoot = ((selectedViewController as? UINavigationController)?.viewControllers.count ?? 1) <= 1
        aiFloatView.isHidden = !(LoginUser.shared().isLogin && isAtTabRoot)
    }
    
    private func drawTabBar(){
        // 底部导航栏要**纯透明底**（用户 2026-10-23 提出、2026-10-26 再次确认、2026-11-03 又要求恢复）。
        // ⚠️ 不要再垫白色底：垫了就不透明了（曾经有过一层 92% 白，已删）。
        self.tabBar.backgroundColor = .clear
        self.tabBar.isTranslucent = true
        self.tabBar.layer.shadowOpacity = 0
        self.tabBar.layer.shadowRadius = 0
        self.tabBar.layer.shadowOffset = .zero
        self.tabBar.layer.shadowColor = UIColor.clear.cgColor

        // iOS 26/27 的液态玻璃 TabBar：只把「背景」变成透明，**不要覆盖 backgroundImage / shadowImage**
        // （盖了会把玻璃画成实心，反而不透明），所以单独一条分支。
        if #available(iOS 26.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            for item in [appearance.stackedLayoutAppearance,
                         appearance.inlineLayoutAppearance,
                         appearance.compactInlineLayoutAppearance] {
                item.normal.titleTextAttributes = [.foregroundColor: Color_8A97A5]
                item.selected.titleTextAttributes = [.foregroundColor: Color_Theme]
            }
            self.tabBar.standardAppearance = appearance
            self.tabBar.scrollEdgeAppearance = appearance
            return
        }

        // 老系统（< iOS 26）：除了 appearance，还要用空图把默认底/分割线拿掉，才是真透明。
        self.tabBar.shadowImage = UIImage()
        self.tabBar.backgroundImage = UIImage()

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            // 透明底：不再用 configureWithOpaqueBackground（那会画成实心/玻璃底）
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = .clear
            appearance.backgroundImage = UIImage()
            appearance.shadowColor = .clear
            for item in [appearance.stackedLayoutAppearance,
                         appearance.inlineLayoutAppearance,
                         appearance.compactInlineLayoutAppearance] {
                item.normal.titleTextAttributes = [.foregroundColor: Color_8A97A5]
                item.selected.titleTextAttributes = [.foregroundColor: Color_Theme]
            }
            self.tabBar.standardAppearance = appearance
            self.tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    public func setTabbarBadge(with index: Int, count: Int) {
        guard let items = self.tabBar.items, items.count > index else { return }
        let item = items[index]
        item.setUnreadCount(count)
    }
    
    public func setTabbarBadge(with index: Int, text: String) {
        guard let items = self.tabBar.items, items.count > index else { return }
        let item = items[index]
        item.set(text: text)
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override public var shouldAutorotate: Bool {
        return self.selectedViewController?.shouldAutorotate ?? false
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return self.selectedViewController?.supportedInterfaceOrientations ?? UIInterfaceOrientationMask.portrait
    }
    
    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return self.selectedViewController?.preferredInterfaceOrientationForPresentation ?? UIInterfaceOrientation.unknown
    }
    
    @objc func updateLan(){
        let titles = [L("资产"),L("发现"),L("消息"),L("通讯录"),L("我的")]
        if let items = self.tabBar.items {
            for (index, item) in items.enumerated() {
                if index < titles.count {
                    item.title = titles[index]
                }
            }
        }
    }
    
    deinit {
            NotificationCenter.default.removeObserver(self)
        }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension FZMTabBarController: UITabBarControllerDelegate {

    /// 再次点击「已经在选中的那个 Tab」：不重复切换，交给该 Tab 的根页面自己处理
    /// （消息页 = 当前列表回到顶部，见 `FZMTabBarReselectHandler`）。
    /// 其余情况（第一次点、已 push 到二级页面、其它 Tab 没实现）一律保持系统原有行为。
    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard viewController === tabBarController.selectedViewController else { return true }

        let nav = viewController as? UINavigationController
        // 已经 push 进二级页面（如聊天页）时不动：避免“明明在聊天页，却在后台把广场滚到顶”的行为
        if let nav = nav, nav.viewControllers.count > 1 { return true }

        guard let handler = (nav?.viewControllers.first ?? viewController) as? FZMTabBarReselectHandler else { return true }
        handler.tabBarDidReselect()
        // 阻止系统把同一个 Tab 再「选中」一次（避免多余的 viewWillAppear 等副作用）
        return false
    }

    /// 切 Tab：悬浮球**不隐藏**（用户 2026-09-30 要求），只是按新 Tab 的状态重算
    /// （新 Tab 若停在二级页面则隐藏）
    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateFloatingAIVisibility()
    }
}

/// AI 客服悬浮球的透明容器：**自己不参与命中测试**。
/// 否则「TabBar 之上」整块区域会挡住下面列表 / 按钮的点击
/// （球是它的子视图，所以不能简单地把 `isUserInteractionEnabled` 关掉 —— 那样球也点不动了）。
private final class AIFloatContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
