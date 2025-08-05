//
//  GroupInfoCell.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/5.
//

import Foundation
import SnapKit

class GroupInfoCell: UICollectionViewCell {
    
    private lazy var nameLab: UILabel = {
        let lab = UILabel.getLab(font: .mediumFont(16), textColor: Color_62DEAD, textAlignment: .left, text: "服务器名称")
        lab.minimumScaleFactor = 0.7
        lab.adjustsFontSizeToFitWidth = true
        lab.numberOfLines = 0
        return lab
    }()
    
    private lazy var statusImageView: UIImageView = {
        let imageView = UIImageView.init(frame: CGRect.init(x: 0, y: 0, width: 10, height: 10))
        imageView.layer.cornerRadius = 5
        imageView.backgroundColor = Color_62DEAD
        
        return imageView
    }()
    
    private lazy var urlLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_62DEAD, textAlignment: .left, text: "172.16.101.107:8888")
        lab.minimumScaleFactor = 0.7
        lab.adjustsFontSizeToFitWidth = true
        return lab
    }()
    
    lazy var arrowView: UIImageView = {
        let imageView = UIImageView.init(frame: CGRect.init(x: 0, y: 0, width: 19, height: 10))
        imageView.image = #imageLiteral(resourceName: "arrow_green")
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var bgView: UIView = {
        let v = UIView.init()
        v.backgroundColor = .init(hexString: "#62DEAD", transparency: 0.1)!
        return v
    }()
    
    private lazy var groupInfoView: UIView = {
        let view = UIView.init()
        view.backgroundColor = .white
        view.layer.cornerRadius = 4
        
        view.addSubview(bgView)
        bgView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        view.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
//            m.top.equalToSuperview().offset(10)
            m.top.equalToSuperview().offset(5)
            m.height.equalTo(33)
            m.left.equalToSuperview().offset(10)
            m.width.lessThanOrEqualTo(97)
        }
        
        view.addSubview(statusImageView)
        statusImageView.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab.snp.right).offset(5)
            m.centerY.equalTo(nameLab)
            m.size.equalTo(CGSize.init(width: 10, height: 10))
        }
        
        view.addSubview(urlLab)
        urlLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.bottom.equalToSuperview().offset(-12)
        }
        
        return view
    }()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(groupInfoView)
        groupInfoView.snp.makeConstraints { (m) in
            m.top.left.right.equalToSuperview()
            m.height.width.equalTo(70)
        }
        
        self.contentView.addSubview(arrowView)
        arrowView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 19, height: 10))
            m.top.equalTo(groupInfoView.snp.bottom)
            m.centerX.equalTo(groupInfoView)
        }
    }
    
    func configure(with serverUrl: String, isSelected: Bool) {
        arrowView.isHidden = !isSelected
        
        let connectStatus = MultipleSocketManager.shared().getSingleSocketConnectStatus(serverUrl )
        
        switch connectStatus {
        case .unConnected:// 未连接
            bgView.backgroundColor = Color_F6F7F8
            nameLab.textColor = Color_24374E
            urlLab.textColor = Color_8A97A5
            statusImageView.backgroundColor = Color_8A97A5
            arrowView.image = #imageLiteral(resourceName: "arrow_gray")
        case .connected:// 已连接
            bgView.backgroundColor = .init(hexString: "#62DEAD", transparency: 0.1)!
            nameLab.textColor = Color_62DEAD
            urlLab.textColor = Color_62DEAD
            statusImageView.backgroundColor = Color_62DEAD
            arrowView.image = #imageLiteral(resourceName: "arrow_green")
        case .disConnected:// 断开连接
            bgView.backgroundColor = .init(hexString: "#DD5F5F", transparency: 0.1)!
            nameLab.textColor = Color_DD5F5F
            urlLab.textColor = Color_DD5F5F
            statusImageView.backgroundColor = Color_DD5F5F
            arrowView.image = #imageLiteral(resourceName: "arrow_red")
        }
        
        self.nameLab.text = self.getGroupName(serverUrl)
        self.urlLab.text = serverUrl.shortUrlStr
    }
    
    private func getGroupName(_ serverUrl: String) -> String {
        var serverName = ""
        LoginUser.shared().chatServerGroups.forEach { (serverGroup) in
            if serverGroup.value == serverUrl {
                serverName = serverGroup.name
                return
            }
        }
        return serverName
    }
}
