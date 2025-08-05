//
//  FZMGroupMembersView.swift
//  chat
//
//  Created by 王俊豪 on 2022/1/11.
//

import Foundation
import UIKit
import SDWebImage

class FZMGroupMembersView: UIView {
    private let bag = DisposeBag.init()
    
    var selectedBlock: ((FZMGroupDetailUserViewModel)->())?
    
    var sourceData = [FZMGroupDetailUserViewModel]() {
        didSet {
            DispatchQueue.main.async {
                self.reloadViews()
            }
        }
    }
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 重载页面
    private func reloadViews() {
        removeAllSubViews()
        
        guard sourceData.count > 0 else {
            return
        }
        
        let itemViewSize = CGSize.init(width: 48, height: 64)// 单个视图size
        
        let lineMaxNum: CGFloat = 5// 单行最多显示个数
        
        var xFloat: CGFloat = 0
        var yFloat: CGFloat = 10
        
        let xPadding = (k_ScreenWidth - 60)/lineMaxNum
        
        for i in 0..<sourceData.count {
            let item = sourceData[i]
            
            xFloat = 15 + CGFloat(i).truncatingRemainder(dividingBy: lineMaxNum) * xPadding
            yFloat = i > 4 ? 79 : 0
            
            let view = FZMMemberView.init(frame: CGRect.init(x: xFloat, y: yFloat, width: itemViewSize.width, height: itemViewSize.height))
            view.tag = i
            view.isUserInteractionEnabled = true
            
            let tap = UITapGestureRecognizer()
            tap.rx.event.subscribe(onNext: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.selectedBlock?(item)
            }).disposed(by: bag)
            view.addGestureRecognizer(tap)
            
            self.addSubview(view)
            
            switch item.type {
            case .person:
                view.headImageView.sd_setImage(with: URL.init(string: item.avatar), placeholderImage: #imageLiteral(resourceName: "friend_chat_avatar"))
                view.nameLab.text = item.name
                view.nameLab.textColor = Color_8A97A5
            case .invite:
                view.nameLab.text = "邀请"
                view.nameLab.textColor = Color_Theme
                view.headImageView.image = #imageLiteral(resourceName: "group_add_user")
            case .remove:
                view.nameLab.text = "移除"
                view.nameLab.textColor = Color_Theme
                view.headImageView.image = #imageLiteral(resourceName: "group_remove_user")
            }
        }
    }
    
    @objc private func clickMemberView() {
        
    }
    
    private func removeAllSubViews() {
        if self.subviews.count > 0 {
            self.subviews.forEach({ $0.removeFromSuperview() })
        }
    }
}

class FZMMemberView: UIView {
    lazy var headImageView : UIImageView = {
        let imV = UIImageView.init(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(10), textColor: Color_8A97A5, textAlignment: .center, text: nil)
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(headImageView)
        headImageView.snp.makeConstraints { (m) in
            m.top.centerX.equalToSuperview()
            m.height.width.equalTo(48)
        }
        
        self.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.bottom.left.right.equalToSuperview()
            m.height.equalTo(14)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
