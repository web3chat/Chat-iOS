//
//  WJHNavView.swift
//  chat
//
//  Created by 王俊豪 on 2021/11/25.
//

import Foundation
import UIKit
import SnapKit
import Starscream
import sqlcipher
import SwifterSwift

class WJHNavView: UIView {
    private let isPrivateChat: Bool
    
    lazy var activityIndicatorView: FZMActivityIndicatorView = {
        let v = FZMActivityIndicatorView.init(frame: CGRect.zero, title: "收取中...")
        v.isHidden = true
        v.backgroundColor = Color_F6F7F8
        v.tintColor = .white
        return v
    }()
    
    // 标题
    private lazy var titleLab: UILabel = {
        let titleLab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .center, text: "")
        return titleLab
    }()
    
    // 群类型
    private lazy var typeLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_Theme, textAlignment: .center, text: "")
        lab.layer.cornerRadius = 4
        lab.layer.masksToBounds = true
        lab.backgroundColor = Color_Theme_Light
        lab.textAlignment = .center
        lab.numberOfLines = 1
        lab.isHidden = true
        return lab
    }()
    
    // 免打扰icon
    private lazy var muteNotificationView: UIImageView = {
        let v = UIImageView.init(image: #imageLiteral(resourceName: "session_mute"))
        v.isHidden = true
        return v
    }()
    
    private lazy var titleView: UIView = {
        let v = UIView.init()
        v.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalToSuperview().offset((self.width - 50)/2)
            m.width.equalTo(50)
        }
        
        v.addSubview(typeLab)
        typeLab.snp.makeConstraints { (m) in
            m.left.equalTo(titleLab.snp.right).offset(5)
            m.centerY.equalToSuperview()
            m.width.equalTo(34)
            m.height.equalTo(18)
        }
        
        v.addSubview(muteNotificationView)
        muteNotificationView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 17, height: 17))
            m.left.equalTo(titleLab.snp.right).offset(5)
            m.centerY.equalToSuperview()
        }
        
        return v
    }()
    
    // 顶部显示的服务器名称
    private lazy var serverLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 12), textColor: Color_62DEAD, textAlignment: .center, text: "")
        lab.layer.cornerRadius = 4
        lab.clipsToBounds = true
        lab.minimumScaleFactor = 0.7
        lab.adjustsFontSizeToFitWidth = true
        return lab
    }()
    
    /*
     navigationItem.titleView适配，不会挤到中间 iOS11之前默认不开启自动布局，
     iOS11之后模块打开了，所以原来用frame做的自定义view，需要实现intrinsicContentSize方法，
     但是2边还是有点间隙，可以设置偏移达到效果
    */
    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }
    
    init(frame: CGRect, isPrivateChat: Bool) {
        
        self.isPrivateChat = isPrivateChat
        
        super.init(frame: frame)
        
        self.createUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createUI() {
        
        self.addSubview(titleView)
        if isPrivateChat {
            titleView.snp.makeConstraints({ (m) in
                m.edges.equalToSuperview()
            })
        } else {
            titleView.snp.makeConstraints({ (m) in
                m.top.left.right.equalToSuperview()
                m.bottom.equalToSuperview().offset(-20)
            })
        }
        
        self.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints({ (m) in
            m.edges.equalToSuperview()
        })
        
        self.addSubview(serverLab)
        serverLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.height.equalTo(20)
            m.bottom.equalToSuperview()
            m.width.equalTo(100)
        }
        
        if isPrivateChat {
            serverLab.isHidden = true
        }
        
        self.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin]
        titleView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        serverLab.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
    }
    
    func setTitleStr(_ titleStr: String, typeStr: String = "", isMuteNotifi: Bool = false) {
        self.titleLab.text = titleStr
        var titleWidth = titleStr.caclulateTextWidth(font: .boldSystemFont(ofSize: 17), height: 30) + 2
        var typeWidth: CGFloat = 0
        var rightWidth: CGFloat = 0
        if isMuteNotifi {
            rightWidth = 5 + 17
        }
        
        if !typeStr.isBlank {
            self.typeLab.text = typeStr
            self.typeLab.isHidden = false
            
            typeWidth = typeStr.caclulateTextWidth(font: .systemFont(ofSize: 12), height: 18) + 10
            
            typeLab.snp.updateConstraints { make in
                make.width.equalTo(typeWidth)
            }
            
            rightWidth += typeWidth  + 5
        } else {
            self.typeLab.text = nil
            self.typeLab.isHidden = true
        }
        
        self.muteNotificationView.isHidden = !isMuteNotifi
        
        let viewWidth = self.width
        if rightWidth > 0 {
            let totalWidth = min(titleWidth + rightWidth, viewWidth)
            titleWidth = totalWidth - rightWidth
            
            self.titleLab.snp.updateConstraints { (m) in
                m.left.equalToSuperview().offset((viewWidth - totalWidth)/2)
                m.width.equalTo(titleWidth)
            }
            
            self.muteNotificationView.snp.updateConstraints { make in
                make.left.equalTo(titleLab.snp.right).offset(5 + typeWidth + 5)
            }
        } else {
            self.titleLab.snp.updateConstraints { (m) in
                m.left.equalToSuperview()
                m.width.equalTo(viewWidth)
            }
        }
    }
    
    func setServerUrl(_ serverUrl: String, connectType: SocketConnectStatus) {
        var serverNameStr = " \(serverUrl.shortUrlStr)) "
        if let server = LoginUser.shared().chatServerGroups.filter({ $0.value == serverUrl }).first {
            serverNameStr = " \(server.name)(\(server.value.shortUrlStr)) "
        }
        self.serverLab.text = serverNameStr
        let serverWidth = serverNameStr.getContentWidth(font: .systemFont(ofSize: 12), height: 20) + 5
        self.serverLab.snp.updateConstraints { make in
            make.width.equalTo(serverWidth)
        }
        
        // 绿 Color_62DEAD 灰 Color_8A97A5  红 Color_DD5F5F
        switch connectType {
        case .unConnected:// 未连接
            self.serverLab.backgroundColor = Color_F6F7F8
            self.serverLab.textColor = Color_8A97A5
        case .connected:// 已连接
            self.serverLab.backgroundColor = .init(hexString: "#62DEAD", transparency: 0.1)!
            self.serverLab.textColor = Color_62DEAD
        case .disConnected:// 断开连接
            self.serverLab.backgroundColor = .init(hexString: "#DD5F5F", transparency: 0.1)!
            self.serverLab.textColor = Color_DD5F5F
        }
    }
}
