//
//  WebViewVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/24.
//

import UIKit
import WebKit

class WebViewVC: UIViewController, ViewControllerProtocol {

    var urlString: String = ""
    
    lazy var webView: WKWebView = {
       let v = WKWebView.init(frame: CGRect.init(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height - k_StatusNavigationBarHeight))
        if let url = URL.init(string: self.urlString) {
            v.load(URLRequest.init(url: url))
        }
        return v
    }()
    
    lazy var progressView: UIProgressView = {
        let v = UIProgressView.init(frame: CGRect.init(x: 0, y: 0, width: self.view.bounds.width, height: 1))
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
    
    let estimatedProgress = "estimatedProgress"
    
    deinit {
        self.webView.removeObserver(self, forKeyPath: estimatedProgress)
    }
    
    init(with url: String) {
        super.init(nibName: nil, bundle: nil)
        self.urlString = url
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let leftItem = UIBarButtonItem(image: #imageLiteral(resourceName: "nav_back_blue"), style: .plain, target: self, action: #selector(backAction))
//        self.navigationItem.leftBarButtonItem = leftItem
        
        self.view.addSubview(webView)
        self.view.addSubview(progressView)
        webView.addObserver(self, forKeyPath: estimatedProgress, options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath, keyPath == estimatedProgress {
            progress = Float(self.webView.estimatedProgress)
        }
    }
    
//    @objc private func backAction() {
//        self.dismiss(animated: true, completion: nil)
//    }
}
