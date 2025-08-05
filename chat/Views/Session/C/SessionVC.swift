//
//  SessionVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/4.
//

import UIKit
import SnapKit
import MapKit
import RxSwift
import GKNavigationBarSwift

class SessionVC: UIViewController, ViewControllerProtocol, UIScrollViewDelegate {
    
    private var showView : FZMScrollPageView?
    private let bag = DisposeBag.init()
    
    lazy var downQRcodeView : SessionListDownQRCodeView = {
        let view = SessionListDownQRCodeView()
        view.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight - k_TabBarHeight)
        return view
    }()
    
    lazy var privateHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "私聊")
        view.show(true)
        return view
    }()
    
    lazy var groupHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: "群聊")
        return view
    }()
    
    lazy var selectBackView : UIView = {
        let view = UIView()
        view.backgroundColor = Color_Auxiliary
        view.layer.cornerRadius = 17.5
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var activityIndicatorView: FZMActivityIndicatorView = {
        let v = FZMActivityIndicatorView.init(frame: CGRect.zero, title: "收取中...")
        v.isHidden = true
        v.backgroundColor = Color_FAFBFC
        return v
    }()
    
    lazy var navigationHeaderView : UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.snp.makeConstraints({ (m) in
            m.size.equalTo(CGSize(width: 100, height: 50))
        })
        view.addSubview(selectBackView)
        selectBackView.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(0)
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
            m.width.equalTo(50)
        })
        view.addSubview(privateHeader)
        privateHeader.snp.makeConstraints({ (m) in
            m.left.equalToSuperview()
            m.right.equalTo(view.snp.centerX)
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
        })
        view.addSubview(groupHeader)
        groupHeader.snp.makeConstraints({ (m) in
            m.right.equalToSuperview()
            m.left.equalTo(view.snp.centerX)
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
        })
        
        view.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints({ (m) in
            m.edges.equalToSuperview().inset(UIEdgeInsets.init(top: 0, left: -10, bottom: 0, right: -10))
        })
        return view
    }()
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = .white
        
        navView.addSubview(self.navigationHeaderView)
        navigationHeaderView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 100, height: 44))
        }
        
        let rightView = CustomBarView.init()
        navView.addSubview(rightView)
        rightView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview()
            make.size.equalTo(CGSize.init(width: 108, height: 44))
        }
        
        return navView
    }()
    
    private lazy var mainView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight - k_TabBarHeight))
        v.backgroundColor = .white
        v.layer.cornerRadius = 0
        v.layer.masksToBounds = true
        return v
    }()
    
    
    var privateUnreadCount = 0 {
        didSet {
            privateHeader.setBadge(privateUnreadCount)
        }
    }
    var groupUnreadCount = 0 {
        didSet{
            groupHeader.setBadge(groupUnreadCount)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNavBackgroundColor()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.hideRQCodeView()
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor = .white
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupViews()
        self.setRX()
        
        FZM_NotificationCenter.addObserver(self,selector: #selector(handleShowQRCodeViewNofi),name: FZM_Notify_ShowQRCodeView,object: nil)
    }
    
    private func setupViews() {
        self.xls_isNavigationBarHidden = true
        self.xls_navigationBarTintColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        
        self.view.addSubview(self.downQRcodeView)
        
        self.view.addSubview(self.mainView)
        
        self.mainView.addSubview(self.navBarView)
        
        let block : (Session)->() = { session in
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: session.id))
        }
        let view1 = FZMPrivateChatListView(with: "好友消息")
        view1.selectBlock = block
        let view2 = FZMGroupChatListView(with: "群聊消息")
        view2.selectBlock = block
        let param = FZMSegementParam()
        param.headerHeight = 0
        
        let height = k_ScreenHeight - k_TabBarHeight - k_StatusNavigationBarHeight
        let view = FZMScrollPageView(frame: CGRect(x: 0, y: k_StatusNavigationBarHeight, width: k_ScreenWidth, height: height), dataViews: [view1,view2], param: param)
        self.showView = view
        view.selectBlock = {[weak self] index in
            guard let strongSelf = self else { return }
            if index == 0 {
                strongSelf.privateHeader.show(true)
                strongSelf.groupHeader.show(false)
                strongSelf.selectBackView.snp.updateConstraints({ (m) in
                    m.left.equalToSuperview().offset(0)
                })
            }else {
                strongSelf.privateHeader.show(false)
                strongSelf.groupHeader.show(true)
                strongSelf.selectBackView.snp.updateConstraints({ (m) in
                    m.left.equalToSuperview().offset(50)
                })
            }
        }
        self.mainView.addSubview(view)
        view.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(k_StatusNavigationBarHeight)
            m.left.right.bottom.equalToSuperview()
        }
        
        let privateTap = UITapGestureRecognizer()
        privateTap.rx.event.subscribe {[weak self, weak view] (_) in
            guard let _ = self else { return }
            view?.select(with: 0)
        }.disposed(by: bag)
        privateHeader.addGestureRecognizer(privateTap)
        
        let groupTap = UITapGestureRecognizer()
        groupTap.rx.event.subscribe {[weak self, weak view] (_) in
            guard let _ = self else { return }
            view?.select(with: 1)
        }.disposed(by: bag)
        groupHeader.addGestureRecognizer(groupTap)
//        self.downQRcodeView.isHidden = true
    }
    
    private func setRX() {
        // 私聊未读数订阅
        SessionManager.shared().privateUnReadCountSubject.subscribe(onNext: { [weak self] (unreadCount) in
            guard let self = self else { return }
            // 设置私聊未读数
            FZMLog("私聊未读数--------  \(unreadCount)")
            self.privateUnreadCount = unreadCount
        }).disposed(by: self.bag)
        
        // 群聊未读数订阅
        SessionManager.shared().groupUnReadCountSubject.subscribe(onNext: { [weak self] (unreadCount) in
            guard let self = self else { return }
            // 设置群聊未读数
            FZMLog("群聊未读数--------  \(unreadCount)")
            self.groupUnreadCount = unreadCount
        }).disposed(by: self.bag)
        
        // 底部显示未读总数
        Observable.combineLatest(SessionManager.shared().privateUnReadCountSubject, SessionManager.shared().groupUnReadCountSubject).subscribe { (event) in
            guard case .next((let groupUnreadCount, let privateUnreadCount)) = event else { return }
            let count = groupUnreadCount + privateUnreadCount
            FZMUIMediator.shared().setTabbarBadge(with: 0, count: count)
        }.disposed(by: bag)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: view) else { return }
        let p = self.mainView.layer.convert(point, from: view.layer)
        if self.mainView.layer.contains(p) {
            self.hideRQCodeView()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SessionVC {
    @objc private func handleShowQRCodeViewNofi(_ showFlgNofi: Notification) {
        let showFlg = showFlgNofi.object as? Bool ?? false
        
        if showFlg {
            UIView .animate(withDuration: 0.4) {
                self.mainView.layer.cornerRadius = 30
                self.mainView.frame = CGRect(x: 0, y: 420, width: k_ScreenWidth, height: self.mainView.frame.height)
                
            } completion: { Bool  in
//                self.downQRcodeView.isHidden = false
                APP.shared().hasShowQRCodeViewFlg = true
            }
        } else {
            self.hideRQCodeView()
        }
    }
    
    //展示下拉二维码
    private func showQRCodeView(_ data : Notification) {
        APP.shared().hasShowQRCodeViewFlg = true
        let offsetY = data.object as? CGFloat ?? 0
        if offsetY < -30 {
            UIView .animate(withDuration: 0.4) {
                self.mainView.layer.cornerRadius = 30
                self.mainView.frame = CGRect(x: 0, y: 420, width: k_ScreenWidth, height: self.mainView.frame.height)
                
            } completion: { Bool  in
//                self.downQRcodeView.isHidden = false
            }
        }
    }
    
    //点击收起下拉二维码
    private func hideRQCodeView() {
        UIView .animate(withDuration: 0.4) {
            self.mainView.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: self.mainView.frame.height)
            self.mainView.layer.cornerRadius = 0
        } completion: { Bool  in
//            self.downQRcodeView.isHidden = true
            APP.shared().hasShowQRCodeViewFlg = false
        }
    }
}

