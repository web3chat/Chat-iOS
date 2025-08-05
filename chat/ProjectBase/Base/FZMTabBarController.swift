//
//  FZMTabBarController.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/21.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

public class FZMTabBarController: UITabBarController {

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.drawTabBar()
        self.tabBar.tintColor = Color_Theme
    }
    
    private func drawTabBar(){
        self.tabBar.backgroundColor = Color_FAFBFC
        self.tabBar.isTranslucent = false
        self.tabBar.shadowImage = UIImage.imageWithColor(with: Color_FAFBFC, size: CGSize(width: k_ScreenWidth, height: 1))
        self.tabBar.backgroundImage = UIImage.imageWithColor(with: Color_FAFBFC, size: self.tabBar.bounds.size)
        let path = CGMutablePath()
        path.addRect(self.tabBar.bounds)
        self.tabBar.layer.shadowPath = path
        path.closeSubpath()
        self.tabBar.makeNormalShadow()
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
