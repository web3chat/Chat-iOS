//
//  FZMBaseViewController.swift
//  chat
//
//  Created by 王俊豪 on 2021/12/20.
//

import Foundation
import UIKit
import GKNavigationBarSwift

class FZMBaseViewController: UIViewController {
    let disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        self.modalPresentationStyle = .fullScreen
    }
    
    // 如果想要在控制器中动态改变状态栏样式，需要在基类控制器实现下面的方法
    override var prefersStatusBarHidden: Bool {
        return self.gk_statusBarHidden
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.gk_statusBarStyle
    }
    
    /*
     // 如果切换控制器的时候出现状态栏显示异常（一半黑一半白等） 解决办法：在控制器初始化方法里面设置状态栏样式
     // 最好在初始化方法中设置gk_statusBarStyle，否则可能导致状态栏切换闪动问题
     override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
     super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
     
     self.gk_statusBarStyle = .lightContent
     }
     
     required init?(coder: NSCoder) {
     fatalError("init(coder:) has not been implemented")
     }
     */
}
