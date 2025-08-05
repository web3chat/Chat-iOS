//
//  FZMMenuView.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/15.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

// MARK: 纯文字菜单
class FZMMenuView: UIView {
    
    var hideBlock: (()->())?
    
    let disposeBag = DisposeBag()
    
    var itemArr = [FZMMenuItem]()
    
    lazy var listView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.isScrollEnabled = false
        view.makeOriginalShdowShow()
        view.layer.backgroundColor = UIColor.white.cgColor
        view.separatorStyle = .none
        view.rowHeight = 40
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.delegate = self
        view.dataSource = self
        view.register(UITableViewCell.self, forCellReuseIdentifier: "FZMMenuViewCell")
        return view
    }()
    
    init(with arr: [FZMMenuItem]) {
        super.init(frame: k_ScreenBounds)
        itemArr += arr
        let control = UIControl(frame: k_ScreenBounds)
        control.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.hide()
        }.disposed(by: disposeBag)
        self.addSubview(control)
    }
    
    func show(in point: CGPoint) {
        UIApplication.shared.keyWindow?.addSubview(self)
        self.addSubview(listView)
        let height = CGFloat(itemArr.count*40)
        listView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize(width: 150, height: height))
            if point.y + height > k_ScreenHeight - 100 {
                m.bottom.equalToSuperview().offset(point.y - k_ScreenHeight)
            }else {
                m.top.equalToSuperview().offset(point.y)
            }
            if point.x > k_ScreenWidth / 2 {
                m.right.equalToSuperview().offset(point.x - k_ScreenWidth)
            }else {
                m.left.equalToSuperview().offset(point.x)
            }
        }
    }
    
    func hide() {
        hideBlock?()
        self.removeFromSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension FZMMenuView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemArr.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FZMMenuViewCell", for: indexPath)
        guard itemArr.count > indexPath.row else {
            return cell
        }
        let item = itemArr[indexPath.row]
        cell.clipsToBounds = false
        cell.backgroundColor = UIColor.clear
        cell.contentView.subviews.forEach { (view) in
            view.removeFromSuperview()
        }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .center, text: item.title)
        cell.contentView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard itemArr.count > indexPath.row else {
            return
        }
        let item = itemArr[indexPath.row]
        item.block?()
        self.hide()
    }
}

class FZMMenuItem: NSObject {
    
    let title: String
    
    let block: (()->())?
    init(title: String, block: (()->())?) {
        self.title = title
        self.block = block
        super.init()
    }
}


// MARK: 带图菜单（首页更多菜单）
class FZMImageMenuView: UIView {
    
    var hideBlock : (()->())?
    
    let disposeBag = DisposeBag()
    
    var itemArr = [FZMImageMenuItem]()
    
    lazy var listView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.isScrollEnabled = false
        view.makeOriginalShdowShow()
        view.layer.backgroundColor = UIColor.white.cgColor
        view.separatorStyle = .none
        view.rowHeight = 40
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.delegate = self
        view.dataSource = self
        view.register(UITableViewCell.self, forCellReuseIdentifier: "FZMMenuViewCell")
        return view
    }()
    
    init(with arr: [FZMImageMenuItem]) {
        super.init(frame: k_ScreenBounds)
        itemArr += arr
        let control = UIControl(frame: k_ScreenBounds)
        control.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.hide()
        }.disposed(by: disposeBag)
        self.addSubview(control)
    }
    
    func show(in point: CGPoint) {
        UIApplication.shared.keyWindow?.addSubview(self)
        self.addSubview(listView)
        let height = CGFloat(itemArr.count*40)
        listView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize(width: 150, height: height))
            if point.y + height > k_ScreenHeight - 100 {
                m.bottom.equalToSuperview().offset(point.y - k_ScreenHeight)
            }else {
                m.top.equalToSuperview().offset(point.y)
            }
            if point.x > k_ScreenWidth / 2 {
                m.right.equalToSuperview().offset(point.x - k_ScreenWidth)
            }else {
                m.left.equalToSuperview().offset(point.x)
            }
        }
    }
    
    func hide() {
        hideBlock?()
        self.removeFromSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension FZMImageMenuView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemArr.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FZMMenuViewCell", for: indexPath)
        guard itemArr.count > indexPath.row else {
            return cell
        }
        let item = itemArr[indexPath.row]
        cell.clipsToBounds = false
        cell.backgroundColor = UIColor.clear
        cell.contentView.subviews.forEach { (view) in
            view.removeFromSuperview()
        }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: item.title)
        cell.contentView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.top.bottom.right.equalToSuperview()
            m.left.equalToSuperview().offset(46)
        }
        let imageV = UIImageView(image: item.image)
        imageV.tintColor = Color_Theme
        cell.contentView.addSubview(imageV)
        imageV.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.centerX.equalTo(cell.contentView.snp.left).offset(23)
            m.size.equalTo(item.imageSize)
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard itemArr.count > indexPath.row else {
            return
        }
        let item = itemArr[indexPath.row]
        item.block?()
        self.hide()
    }
}

class FZMImageMenuItem: NSObject {
    
    let title: String
    let image: UIImage?
    let imageSize: CGSize
    let block: (()->())?
    init(title: String, image: UIImage?, size: CGSize, block: (()->())?) {
        self.title = title
        self.block = block
        self.image = image
        self.imageSize = size
        super.init()
    }
    
    init(type: FZMMenuItemType, block: (()->())?) {
        self.title = type.title
        self.image = type.image
        self.imageSize = CGSize(width: 20, height: 20)
        self.block = block
        super.init()
    }
}

enum FZMMenuItemType {
    case copy// 复制（仅限文字消息）
    case forward// 转发
    case reply// 回复
    case attention// 关注
    case revoked// 撤回
    case delete// 删除
    case multselect// 多选
    case collect// 收藏
    case translate// 翻译
    case muted// 禁言
    case totext// 转文字（仅限语音消息）
    case loudspeaker// 扬声器播放（仅限语音消息）
    case handset// 听筒播放（仅限语音消息）
    var title: String {
        switch self {
        case .copy:
            return "复制"
        case .forward:
            return "转发"
        case .reply:
            return "回复"
        case .attention:
            return "关注"
        case .revoked:
            return "撤回"
        case .delete:
            return "删除"
        case .multselect:
            return "多选"
        case .collect:
            return "收藏"
        case .translate:
            return "翻译"
        case .muted:
            return "禁言"
        case .totext:
            return "转文字"
        case .loudspeaker:
            return "扬声器播放"
        case .handset:
            return "听筒播放"
        }
    }
    var image: UIImage {
        switch self {
        case .copy:
            return #imageLiteral(resourceName: "menu_copy")
        case .forward:
            return #imageLiteral(resourceName: "menu_forward")
        case .reply:
            return #imageLiteral(resourceName: "menu_reply")
        case .attention:
            return #imageLiteral(resourceName: "menu_attention")
        case .revoked:
            return #imageLiteral(resourceName: "menu_revoked")
        case .delete:
            return #imageLiteral(resourceName: "menu_delete")
        case .multselect:
            return #imageLiteral(resourceName: "menu_multselect")
        case .collect:
            return #imageLiteral(resourceName: "menu_collect")
        case .translate:
            return #imageLiteral(resourceName: "menu_translate")
        case .muted:
            return #imageLiteral(resourceName: "menu_muted")
        case .totext:
            return #imageLiteral(resourceName: "menu_totext")
        case .loudspeaker:
            return #imageLiteral(resourceName: "menu_loudspeaker")
        case .handset:
            return #imageLiteral(resourceName: "menu_handset")
        }
    }
}

class FZMMsgMenuItem: NSObject {
    let type: FZMMenuItemType
    let block: (()->())?
    
    init(type: FZMMenuItemType, block: (()->())?) {
        self.type = type
        self.block = block
        super.init()
    }
}

// MARK: 聊天页面长按弹出菜单
class FZMMsgMenuView: UIView {
    
    var hideBlock: (()->())?
    
    let disposeBag = DisposeBag()
    
    var itemArr = [FZMMsgMenuItem]()
    
    init(with arr: [FZMMsgMenuItem]) {
        super.init(frame: k_ScreenBounds)
        itemArr += arr
        let control = UIControl(frame: k_ScreenBounds)
        control.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.hide()
        }.disposed(by: disposeBag)
        self.addSubview(control)
    }
    
    private func getItemView(type: FZMMenuItemType) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.frame = CGRect(x: 0, y: 0, width: 54, height: 60)
        
        let imgView = UIImageView.init(image: type.image)
        view.addSubview(imgView)
        imgView.snp.makeConstraints { (m) in
            m.size.equalTo(20)
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(9.5)
        }
        
        let lab = UILabel.getLab(font: UIFont.preferredFont(forTextStyle: .caption1), textColor: .white, textAlignment: .center, text: type.title)
        lab.numberOfLines = 0
        view.addSubview(lab)
        lab.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(31.5)
            make.left.right.equalToSuperview()
        }
        
        return view
    }
    
    /// 显示菜单视图
    /// - Parameters:
    ///   - viewFrame: 需要显示在此位置附近
    ///   - bottomHeight: 底部视图高度（需避开此区域）
    ///   - isOutGoing: 是否是自己发的消息（菜单视图对齐方式以此判断）
    func show(in viewFrame: CGRect, bottomHeight: CGFloat, isOutGoing: Bool) {
        UIApplication.shared.keyWindow?.addSubview(self)
        let listView = UIView.init()
        listView.backgroundColor = .black
        listView.layer.cornerRadius = 5
        listView.layer.masksToBounds = true
        
        let xFloat: CGFloat = 5
        let size = CGSize(width: 54, height: 60)
        
        if itemArr.count > 0 {
            for i in 0..<itemArr.count {
                let item = itemArr[i]
                let view = getItemView(type: item.type)
                view.isUserInteractionEnabled = true
                
                let btn = UIButton.init(type: .custom)
                btn.addTarget(self, action: #selector(clickItemAction(button:)), for: .touchUpInside)
                btn.tag = i+10000
                view.addSubview(btn)
                btn.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                let yFloat: CGFloat = i > 4 ? 65 : 5
                view.frame = CGRect.init(x: xFloat + CGFloat((i%5)*54), y: yFloat, width: size.width, height: size.height)
                listView.addSubview(view)
            }
        }
        
        self.addSubview(listView)
        let height: CGFloat = itemArr.count > 5 ? 130 : 70
        let width: CGFloat = itemArr.count > 5 ? 280 : 10 + CGFloat(itemArr.count)*size.width
        
        let viewHeight = 5 + height + 5// 上下间距5
        
        listView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize(width: width, height: height))
            if isOutGoing {
                m.right.equalToSuperview().offset(-12)
            } else {
                m.left.equalToSuperview().offset(12)
            }
            // 先判断顶部能否放下，放不下再放底部，还放不下则盖在view上
            if k_StatusBarHeight + viewHeight <= viewFrame.minY {
                m.bottom.equalToSuperview().offset(viewFrame.minY - k_ScreenHeight - 5)// 显示在消息顶部
            } else if viewHeight <= k_ScreenHeight - viewFrame.maxY {
                m.top.equalToSuperview().offset(viewFrame.maxY + 5)// 显示在消息底部
            } else {
                // 消息太高导致剩余空间不足以放下菜单视图
                if viewFrame.minY > 0 {
                    m.top.equalToSuperview().offset(viewFrame.minY + 5)
                } else if viewFrame.maxY < k_ScreenHeight - bottomHeight {
                    m.bottom.equalToSuperview().offset(viewFrame.maxY - k_ScreenHeight - 5)
                } else {
                    m.centerY.equalToSuperview()
                }
            }
//            if viewFrame.maxY + 5 + height < k_ScreenHeight - bottomHeight {// 底部放不下
//                m.bottom.equalToSuperview().offset(point.y - k_ScreenHeight)
//            } else {
//                m.top.equalToSuperview().offset(point.y)
//            }
        }
    }
    
    @objc private func clickItemAction(button: UIButton) {
        let index = button.tag - 10000
        guard index < itemArr.count else { return }
        let item = itemArr[index]
        
        item.block?()
        self.hide()
    }
    
    func hide() {
        hideBlock?()
        self.removeFromSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
