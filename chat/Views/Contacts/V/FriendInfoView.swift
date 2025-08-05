//
//  FriendInfoView.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/26.
//

import Foundation
import UIKit
import SnapKit
import RxSwift

// 底部按钮视图
class FriendInfoBottomView: UIView {
    private let disposeBag = DisposeBag.init()
    
    var clickActionBlock: IntBlock?
    
    // 底部控件获取 type 0. 专属红包 1. 语音通话 2. 视频通话 3. 发消息 4. 添加好友 5. 删除好友
    private func getItemView(type: Int) -> UIView {
        let view = UIView.init()
        view.isUserInteractionEnabled = true
        var img = UIImage.init()
        var title = ""
        var textColor = Color_Theme
        if type == 0 {
            img = #imageLiteral(resourceName: "friend_red")
            title = "专属红包"
            textColor = Color_DD5F5F
        } else if type == 1 {
            img = #imageLiteral(resourceName: "friend_transfer")
            title = "转账"
        } else if type == 2 {
            img = #imageLiteral(resourceName: "friend_facetime")
            title = "视频通话"
        } else if type == 3 {
            img = #imageLiteral(resourceName: "friend_sendMsg")
            title = "发消息"
        } else if type == 4 {
            img = #imageLiteral(resourceName: "friend_addfriend")
            title = "添加好友"
        } else if type == 5 {
            img = #imageLiteral(resourceName: "friend_delete")
            title = "删除好友"
        }
        
        let imgV = UIImageView.init(image: img)
        view.addSubview(imgV)
        imgV.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 40, height: 40))
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(15)
        }
        
        let lab = UILabel.getLab(font: .boldFont(12), textColor: textColor, textAlignment: .center, text: title)
        view.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.bottom.equalToSuperview().offset(-3)
            m.centerX.equalToSuperview()
        }
        
        return view
    }
    // 红包
    lazy var itemRedView: UIView = {
        let view = self.getItemView(type: 0)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 转账
            strongSelf.clickActionBlock?(0)
        }).disposed(by: self.disposeBag)
        return view
    }()
    // 转账
    lazy var itemTransferView: UIView = {
        let view = self.getItemView(type: 1)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 转账
            strongSelf.clickActionBlock?(1)
        }).disposed(by: self.disposeBag)
        return view
    }()
//    语音
    lazy var itemVoiceView: UIView = {
        let view = self.getItemView(type: 1)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 语音
            strongSelf.clickActionBlock?(1)
        }).disposed(by: self.disposeBag)
        return view
    }()
//    视频
    lazy var itemVideoView: UIView = {
        let view = self.getItemView(type: 2)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 视频
            strongSelf.clickActionBlock?(2)
        }).disposed(by: self.disposeBag)
        return view
    }()
//    发消息
    lazy var itemSendMsgView: UIView = {
        let view = self.getItemView(type: 3)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 发消息
            strongSelf.clickActionBlock?(3)
        }).disposed(by: self.disposeBag)
        return view
    }()
//    加好友
    lazy var itemAddFriendView: UIView = {
        let view = self.getItemView(type: 4)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 加好友
            strongSelf.clickActionBlock?(4)
        }).disposed(by: self.disposeBag)
        return view
    }()
//    删好友
    lazy var itemDeleteFriendView: UIView = {
        let view = self.getItemView(type: 5)
        let tap = UITapGestureRecognizer.init()
        view.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { [weak self] (ges) in
            guard let strongSelf = self else { return }
            // 删好友
            strongSelf.clickActionBlock?(5)
        }).disposed(by: self.disposeBag)
        return view
    }()
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitview = super.hitTest(point, with: event)
        
        if hitview == itemTransferView || hitview == itemRedView  || hitview == itemSendMsgView || hitview == itemAddFriendView || hitview == itemDeleteFriendView {
            return hitview
        } else {
            return nil
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth - 30, height: 110))
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func hideRed(){
        itemRedView.isHidden = true
        let width: CGFloat = (k_ScreenWidth - 30)/5
        let height: CGFloat = 90
        let size = CGSize.init(width: width, height: height)
        
        itemTransferView.snp.remakeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(width)
        }
        itemSendMsgView.snp.remakeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(width * 2)
        }
        
        itemAddFriendView.snp.remakeConstraints { (m) in
//            m.left.equalToSuperview().offset(4*width)
            m.left.equalTo(itemSendMsgView.snp.right)
            m.size.equalTo(size)
            m.top.equalToSuperview()
        }
        
        itemDeleteFriendView.snp.remakeConstraints { (m) in
//            m.left.equalToSuperview().offset(4*width)
            m.left.equalTo(itemSendMsgView.snp.right)
            m.size.equalTo(size)
            m.top.equalToSuperview()
        }
    }
    
    func hideother(){
        let width: CGFloat = (k_ScreenWidth - 30)/5
        let height: CGFloat = 90
        let size = CGSize.init(width: width, height: height)
        itemRedView.isHidden = false
        itemTransferView.isHidden = false
        itemSendMsgView.isHidden = true
        itemAddFriendView.isHidden = true
        itemDeleteFriendView.isHidden = true
        
        itemRedView.snp.remakeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(width * 1.5)
        }
        itemTransferView.snp.remakeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(width * 2.5)
        }
        
    }
    
    
    private func setupViews() {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth - 30, height: 110))
        v.backgroundColor = .clear
        self.addSubview(v)
        
        let width: CGFloat = (k_ScreenWidth - 30)/4
        let height: CGFloat = 90
        let size = CGSize.init(width: width, height: height)
        
        v.addSubview(itemRedView)
//        itemTransferView.isHidden = true
        itemRedView.snp.makeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview()
        }
        v.addSubview(itemTransferView)
        itemTransferView.snp.makeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(width)
        }
//        v.addSubview(itemVideoView)
//        itemVideoView.isHidden = true
//        itemVideoView.snp.makeConstraints { (m) in
//            m.size.equalTo(size)
//            m.top.equalToSuperview()
//            m.left.equalToSuperview().offset(2*width)
//        }
        
        v.addSubview(itemSendMsgView)
        itemSendMsgView.snp.makeConstraints { (m) in
            m.size.equalTo(size)
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(2*width)
//            m.right.equalToSuperview().offset(-(k_ScreenWidth - 30)/3)
        }
        
        v.addSubview(itemAddFriendView)
        itemAddFriendView.snp.makeConstraints { (m) in
//            m.left.equalToSuperview().offset(4*width)
            m.left.equalTo(itemSendMsgView.snp.right)
            m.size.equalTo(size)
            m.top.equalToSuperview()
        }
        
        v.addSubview(itemDeleteFriendView)
        itemDeleteFriendView.isHidden = true
        itemDeleteFriendView.snp.makeConstraints { (m) in
//            m.left.equalToSuperview().offset(4*width)
            m.left.equalTo(itemSendMsgView.snp.right)
            m.size.equalTo(size)
            m.top.equalToSuperview()
        }
    }
}
