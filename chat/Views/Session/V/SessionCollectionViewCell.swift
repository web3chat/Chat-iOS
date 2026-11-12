//
//  SessionCollectionViewCell.swift
//  chat
//
//  Created by fzm on 2021/1/11.
//

import UIKit
import SnapKit
import RxSwift

class SessionCollectionViewCell: UICollectionViewCell {
    
    private let disposeBag = DisposeBag()
    
    lazy var bgView: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_FFFFFF
        return v
    }()
    
    // 头像
    private lazy var avatarView: UIImageView = {
        let v = UIImageView.init()
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        v.contentMode = .scaleAspectFill
        return v
    }()
    
    // 未读数
    private lazy var unreadCountView: UnreadCountView = {
        let lab = UnreadCountView.init()
        return lab
    }()
    
    // 会话名称（好友昵称/群名称）
    private lazy var sessionNameLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.lineBreakMode = .byTruncatingTail
//        lab.setContentHuggingPriority(UILayoutPriority.init(100), for: .horizontal)
        return lab
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
    
    // 群聊服务器连接状态 绿 Color_62DEAD 灰 Color_8A97A5  红 Color_DD5F5F
    private lazy var statusView: UIView = {
        let view = UIView.init()
        view.backgroundColor = Color_DD5F5F
        view.layer.cornerRadius = 5
        view.isHidden = true
        return view
    }()
    
    // 消息时间
    private lazy var timeLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.setContentCompressionResistancePriority(UILayoutPriority.init(1000), for: .horizontal)
        return lab
    }()
    
    // 消息发送失败图标
    private lazy var failImg: UIImageView = {
        let img = UIImageView.init(image: #imageLiteral(resourceName: "chat_sendfail"))
//        img.isHidden = true
        return img
    }()
    
    // 最新一条消息
    private lazy var latestInfoLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()
    
    // 免打扰icon
    private lazy var muteNotificationView: UIImageView = {
        let v = UIImageView.init(image: #imageLiteral(resourceName: "session_mute"))
        v.isHidden = true
        return v
    }()
    
    lazy var separatorLine: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_E6EAEE
        return v
    }()
    
    private var session: Session?
    
    private var isMuteNotification = false
    
    private var isOnTop = false

    /// 当前是否为「小Y」（AI 客服）入口行（虚拟行：菜单里不提供删除聊天 / 免打扰）
    private var isAIEntry = false

    /// 「小Y」入口行长按菜单里点「置顶 / 取消置顶」的回调（由列表设置；其它行不设）
    var onToggleAIPin: (() -> Void)?

    /// AI 客服入口头像用的图标（SF Symbol 模板图，不占用图片资源）
    private static let aiAvatarImage: UIImage? = {
        let config = UIImage.SymbolConfiguration(pointSize: 21, weight: .medium)
        return UIImage(systemName: "headphones", withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
    }()
    
    var statusType: SocketConnectStatus = .unConnected {
        didSet {
            // 绿 Color_62DEAD 灰 Color_8A97A5  红 Color_DD5F5F
            switch statusType {
            case .unConnected:// 未连接
                self.statusView.backgroundColor = Color_8A97A5
            case .connected:// 已连接
                self.statusView.backgroundColor = Color_62DEAD
            case .disConnected:// 断开连接
                self.statusView.backgroundColor = Color_DD5F5F
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.bgView.backgroundColor = Color_FFFFFF
        self.isAIEntry = false
        self.onToggleAIPin = nil
        self.avatarView.image = nil
        // AI 客服入口行把头像设成了主题色底 + .center 图标，复用回真实会话时要还原
        self.avatarView.backgroundColor = .clear
        self.avatarView.contentMode = .scaleAspectFill
        self.unreadCountView.unreadCount = 0
        self.unreadCountView.isMuteNotification = false
        self.sessionNameLab.text = nil
        self.latestInfoLab.attributedText = nil
        self.timeLab.text = nil
        self.muteNotificationView.isHidden = true
        self.latestInfoLab.snp.updateConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
        }
        self.sessionNameLab.snp.updateConstraints { (m) in
            m.width.equalTo(k_ScreenWidth - 150)
        }
        self.statusView.snp.updateConstraints { (m) in
            m.width.equalTo(0)
        }
    }
    
    func configure(_ session: Session, isMuteNotification: Bool, isOnTop: Bool) {
        self.session = session
        self.isMuteNotification = isMuteNotification
        self.isOnTop = isOnTop
        
        let placeholderImg = session.isPrivateChat ?  #imageLiteral(resourceName: "friend_chat_avatar") : #imageLiteral(resourceName: "group_chat_avatar")
        // 头像 Downsampling 降采样，避免大图全尺寸解码（会话列表滚动更流畅）
        let avatarSize = CGSize(width: 60 * UIScreen.main.scale, height: 60 * UIScreen.main.scale)
        self.avatarView.kf.setImage(with: URL.init(string: session.imageURLStr), placeholder: placeholderImg,
                                    options: [.processor(DownsamplingImageProcessor(size: avatarSize))])
        
        self.unreadCountView.isMuteNotification = isMuteNotification
        self.unreadCountView.unreadCount = session.unreadCount
        
        let timeStr = String.sessionTimeString(with: session.timestamp) ?? ""
        let timeWidht = timeStr.getContentWidth(font: .systemFont(ofSize: 12), height: 17)
        self.timeLab.text = timeStr
        
        let sessionName = session.sessionName
        var nameWidth = sessionName.getContentWidth(font: .systemFont(ofSize: 16), height: 23) + 2// (+2): 计算有偏差，实际显示可能会显示不全，需再加宽一点
        self.sessionNameLab.text = sessionName
        
        let maxWidht = k_ScreenWidth - 69 - 7 - timeWidht - 15
        
        if session.isPrivateChat {// 私聊
            self.statusView.isHidden = true
            self.sessionNameLab.snp.updateConstraints { (m) in
                m.width.equalTo(maxWidht)
            }
            self.statusView.snp.updateConstraints { (m) in
                m.width.equalTo(0)
            }
        } else {// 群聊
            var typeStr = ""
            switch session.groupType {// 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
            case 1:
                typeStr = L("全员")
            case 2:
                typeStr = L("部门")
            default:
                typeStr = ""
            }
            self.typeLab.text = typeStr
            
            var rightWidth: CGFloat = 0
            let typeWidth = typeStr.isBlank ? 0 : typeStr.getContentWidth(font: .systemFont(ofSize: 12), height: 18) + 10
            rightWidth = typeWidth > 0 ? 5 + typeWidth + 5 + 10 : 5 + 10
            
            let totalWidth = min(nameWidth + rightWidth, maxWidht)
            nameWidth = totalWidth - rightWidth
            
            self.typeLab.isHidden = sessionName.isEmpty ? true : false
            self.statusView.isHidden = sessionName.isEmpty ? true : false
            
            self.sessionNameLab.snp.updateConstraints { (m) in
                m.width.equalTo(nameWidth)
            }
            self.typeLab.snp.updateConstraints { make in
                make.width.equalTo(typeWidth)
            }
            self.statusView.snp.updateConstraints { (m) in
                m.left.equalTo(self.sessionNameLab.snp.right).offset(rightWidth - 10)
                m.width.equalTo(10)
            }
        }
        
        if self.isMuteNotification == true{
            if session.unreadCount > 0 {
                let attText = "[" + session.unreadCount.string + L("条]")
                self.latestInfoLab.attributedText = NSAttributedString.init(string: attText) + session.latestInfo
            }else{
                self.latestInfoLab.attributedText = session.latestInfo
            }
            
        }else{
            self.latestInfoLab.attributedText = session.latestInfo
        }
                
        if session.isSendFailed {
            self.failImg.isHidden = false

            self.failImg.snp.updateConstraints { m in
                m.size.equalTo(CGSize.init(width: 15, height: 15))
            }

            self.latestInfoLab.snp.updateConstraints { m in
                m.left.equalTo(self.failImg.snp.right).offset(3)
            }
        } else {
            self.failImg.isHidden = true

            self.failImg.snp.updateConstraints { m in
                m.size.equalTo(CGSize.init(width: 0, height: 15))
            }

            self.latestInfoLab.snp.updateConstraints { m in
                m.left.equalTo(self.failImg.snp.right)
            }
        }
        
        if isMuteNotification {
            self.muteNotificationView.isHidden = false
            self.latestInfoLab.snp.updateConstraints { (m) in
                m.right.equalToSuperview().offset(-42)
            }
            self.unreadCountView.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize.init(width: 10, height: 10))
                m.top.equalToSuperview().offset(8)
                m.left.equalToSuperview().offset(54)
            }
        } else {
            self.muteNotificationView.isHidden = true
            self.latestInfoLab.snp.updateConstraints { (m) in
                m.right.equalToSuperview().offset(-15)
            }
            // 红点宽度随文案变（`99+` 比 16 宽）。
            // ⚠️ 向右变宽会压到会话名（会话名 left = 头像右边 + 10 ≈ 69），
            //    所以保持**右边缘不动**（51 + 16 = 67）、向左长，1~2 位数时宽度仍为 16 位置不变。
            let badgeWidth = self.unreadCountView.fittedWidth
            self.unreadCountView.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize.init(width: badgeWidth, height: 16))
                m.top.equalToSuperview().offset(5)
                m.left.equalToSuperview().offset(67 - badgeWidth)
            }
        }
        
        if isOnTop {// 置顶会话改变背景色
            self.bgView.backgroundColor = Color_F6F7F8
        }
    }

    /// 配置「小Y」（AI 客服）入口行（虚拟行，不是真实好友会话）。
    ///
    /// 排版全复用 `configure`：借一个假 `Session` 走「私聊」分支，
    /// 顺便把群类型/连接状态/免打扰/发送失败/置顶背景这些都归位；
    /// 只覆盖与真实会话不同的三处：头像、消息预览（引导文案）、时间（留空）。
    /// - Parameter isOnTop: 「小Y」自己的置顶状态（置顶时与置顶会话一样带底色）
    func configureAIEntry(name: String, subtitle: String, isOnTop: Bool) {
        var virtual = Session(id: .person(AICustomerStore.entrySessionID))
        virtual.sessionName = name
        virtual.imageURLStr = ""
        // 0 → `sessionTimeString` 返回 nil，时间列自然留空，也不占名称宽度
        virtual.timestamp = 0
        self.configure(virtual, isMuteNotification: false, isOnTop: isOnTop)

        self.isAIEntry = true

        // 头像：模板图标 + `.center`（不能用 .scaleAspectFill，会把图标拉伸铺满）
        self.avatarView.kf.cancelDownloadTask()
        self.avatarView.image = Self.aiAvatarImage
        self.avatarView.contentMode = .center
        self.avatarView.tintColor = Color_FFFFFF
        self.avatarView.backgroundColor = Color_Theme

        self.latestInfoLab.attributedText = NSAttributedString(string: subtitle, attributes: [
            .font: UIFont.regularFont(14),
            .foregroundColor: Color_8A97A5
        ])
    }
    
    private func setupViews() {
        self.contentView.addSubview(self.bgView)
        self.bgView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.bgView.addSubview(self.avatarView)
        self.avatarView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 44, height: 44))
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
        }
        
        self.bgView.addSubview(self.unreadCountView)
        self.unreadCountView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 16, height: 16))
            m.top.equalToSuperview().offset(5)
            m.left.equalToSuperview().offset(51)
        }
        
        self.bgView.addSubview(self.timeLab)
        self.timeLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(16.5)
        }
        
        self.bgView.addSubview(self.sessionNameLab)
        self.sessionNameLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(14)
            m.left.equalTo(self.avatarView.snp.right).offset(10)
//            m.right.lessThanOrEqualTo(self.timeLab.snp.left).offset(-5)
            m.width.equalTo(k_ScreenWidth - 150)
            m.height.equalTo(22.5)
        }
        
        self.bgView.addSubview(self.typeLab)
        self.typeLab.snp.makeConstraints { (m) in
            m.left.equalTo(self.sessionNameLab.snp.right).offset(5)
            m.centerY.equalTo(self.sessionNameLab)
            m.width.equalTo(34)
            m.height.equalTo(18)
        }
        
        self.bgView.addSubview(self.statusView)
        self.statusView.snp.makeConstraints { (m) in
            m.left.equalTo(self.sessionNameLab.snp.right).offset(5)
            m.width.height.equalTo(10)
            m.centerY.equalTo(self.sessionNameLab)
        }
        
        self.bgView.addSubview(self.muteNotificationView)
        self.muteNotificationView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 17, height: 17))
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview().offset(-13)
        }
        
        self.bgView.addSubview(self.failImg)
        self.failImg.snp.makeConstraints { m in
            m.size.equalTo(CGSize.init(width: 0, height: 15))
            m.top.equalTo(self.sessionNameLab.snp.bottom).offset(2)
            m.left.equalTo(self.sessionNameLab)
        }
        
        self.bgView.addSubview(self.latestInfoLab)
        self.latestInfoLab.snp.makeConstraints { (m) in
            m.left.equalTo(self.failImg.snp.right)
            m.top.equalTo(self.sessionNameLab.snp.bottom)
            m.height.equalTo(20)
            m.right.equalToSuperview().offset(-15)
        }
        
        self.bgView.addSubview(self.separatorLine)
        self.separatorLine.snp.makeConstraints { (m) in
            m.bottom.left.right.equalToSuperview()
            m.height.equalTo(0.5)
        }
        
        let longPress = UILongPressGestureRecognizer()
        longPress.rx.event.subscribe {[weak self] (event) in
            guard case .next(let ges) = event else { return }
            guard let strongSelf = self else { return }
            if ges.state == .began {
                let point = ges.location(in: UIApplication.shared.keyWindow!)
                VoiceMessagePlayerManager.shared().vibrateAction()
                strongSelf.handleLongPressCellAction(point)
            }
        }.disposed(by: disposeBag)
        self.contentView.addGestureRecognizer(longPress)
    }
    
    // 会话列表cell长按事件处理 - 显示操作弹窗
    private func handleLongPressCellAction(_ point: CGPoint) {
        guard let model = self.session else { return }
        
        var tempColor = Color_FFFFFF
        tempColor = self.bgView.backgroundColor!
        self.bgView.backgroundColor = UIColor.init(hexString: "#DCDCDC")!

        // 「小Y」（AI 客服）入口行：只提供置顶/取消置顶（隐藏删除聊天与免打扰 ——
        // 它没有真实好友/群可改，也没有聊天记录可删）
        if self.isAIEntry {
            let onTopItem = FZMMenuItem(title: self.isOnTop ? L("取消置顶") : L("置顶"), block: { [weak self] in
                self?.onToggleAIPin?()
            })
            let view = FZMMenuView(with: [onTopItem])
            view.show(in: point)
            view.hideBlock = { [weak self] in
                self?.bgView.backgroundColor = tempColor
            }
            return
        }
        
        let onTopItem = FZMMenuItem(title: self.isOnTop ? L("取消置顶") : L("置顶"), block: {
            if model.isPrivateChat {
                guard let user = UserManager.shared().user(by: model.id.idValue) else { return }
                // 更新本地用户信息
                UserManager.shared().updateUserIsOnTop(address: user.address, isOnTop: !self.isOnTop)
            } else {
                let groupId = model.id.idValue.intEncoded
                guard let group = GroupManager.shared().getDBGroup(by: groupId) else { return }
                // 更新本地群信息
                GroupManager.shared().updateDBGroupIsOnTop(groupId: group.id, isOnTop: !self.isOnTop)
            }
        })
        
        let deleteItem = FZMMenuItem(title: L("删除聊天"), block: {
            SessionManager.shared().deleteSession(id: model.id)
        })
        
        let muteNofiItem = FZMMenuItem(title: self.isMuteNotification ? L("取消免打扰") : L("免打扰"), block: {
            if model.isPrivateChat {
                guard let user = UserManager.shared().user(by: model.id.idValue) else { return }
                // 更新本地用户信息
                UserManager.shared().updateUserMuteNotifacation(address: user.address, isMuteNoti: !self.isMuteNotification)
                //更新私聊会话未读总数
                SessionManager.shared().refreshPrivateUnreadCount()
            } else {
                guard let group = GroupManager.shared().getDBGroup(by: model.id.idValue.intEncoded) else { return }
                // 更新本地群信息
                GroupManager.shared().updateDBGroupMuteNotifacation(groupId: group.id, isMuteNoti: !self.isMuteNotification)
                //更新群聊会话未读总数
                SessionManager.shared().refreshGroupUnreadCount()
            }
        })
        
        var itemArr = [FZMMenuItem]()
//        if model.isPrivateChat {
//            itemArr = (UserManager.shared().friend(by: model.id.idValue) != nil) ?[onTopItem, deleteItem, muteNofiItem] : [deleteItem]
//        } else {
//            itemArr = [onTopItem, deleteItem, muteNofiItem]
//        }
        if !model.isPrivateChat, let group = GroupManager.shared().getDBGroupInTable(groupId: model.id.idValue.intEncoded, onlyInquire: true), !group.isInGroup {
            itemArr = [deleteItem]
        } else {
            itemArr = [onTopItem, deleteItem, muteNofiItem]
        }
        
        let view = FZMMenuView(with: itemArr)
//        if (UserManager.shared().friend(by: model.id.idValue) != nil) {
//        } else {
//        }
        view.show(in: point)
        view.hideBlock = { [weak self] in
            self?.bgView.backgroundColor = tempColor
        }
    }
}
