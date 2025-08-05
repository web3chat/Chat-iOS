//
//  QRCodeView.swift
//  chat
//
//  Created by 王俊豪 on 2022/1/18.
//  保存到相册的群二维码视图

import Foundation
import UIKit
import SnapKit
import Kingfisher

class QRCodeView: UIView {
    
    // 头像
    private lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "avatar_persion"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.isUserInteractionEnabled = true
        imV.contentMode = .scaleAspectFill
        imV.layer.borderWidth = 5
        imV.layer.borderColor = UIColor.white.cgColor
        imV.layer.cornerRadius = 7
        imV.layer.masksToBounds = true
        return imV
    }()
    
    // 名称
    private lazy var nickNameLab: UILabel = {
        let label = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .center, text: "")
        label.numberOfLines = 2
        return label
    }()
    
    // 地址
    private lazy var addressLab: UILabel = {
        let label = UILabel.getLab(font: .mediumFont(14), textColor: Color_24374E, textAlignment: .center, text: "")
        return label
    }()
    
    // 二维码视图
    private lazy var qrImageView: UIImageView = {
        let img = UIImageView.init()
        return img
    }()
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 582))
        
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.backgroundColor = Color_Theme
        
        let bgV = UIView()
        bgV.backgroundColor = .white
        bgV.layer.cornerRadius = 15
        bgV.layer.masksToBounds = true
        self.addSubview(bgV)
        bgV.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalToSuperview().offset(105)
            make.bottom.equalToSuperview().offset(-55)
        }
        
        self.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(55)
            make.size.equalTo(100)
        }
        
        self.addSubview(nickNameLab)
        nickNameLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(headerImageView.snp.bottom).offset(15)
        }
        
        self.addSubviews(addressLab)
        addressLab.snp.makeConstraints { make in
            make.left.right.equalTo(nickNameLab)
            make.top.equalTo(nickNameLab.snp.bottom).offset(5)
        }
        
        self.addSubview(qrImageView)
        qrImageView.snp.makeConstraints { make in
            make.size.equalTo(170)
            make.centerX.equalToSuperview()
            make.top.equalTo(addressLab.snp.bottom).offset(45)
        }
        
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: "扫描二维码加入群聊")
        self.addSubview(lab)
        lab.snp.makeConstraints { make in
            make.top.equalTo(qrImageView.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
        }
    }
    
    func loadData(groupInfo: Group) {
        // 群头像
        let avatar = groupInfo.avatarURLStr
        if avatar.isBlank {
            headerImageView.image = #imageLiteral(resourceName: "avatar_group")
        } else {
            headerImageView.kf.setImage(with: URL.init(string: groupInfo.avatar), placeholder:#imageLiteral(resourceName: "avatar_group") )
        }
        
        var typeImg: UIImage? = nil
        switch groupInfo.groupType {
        case 1:
            typeImg = #imageLiteral(resourceName: "icon_type_quanyuan")
        case 2:
            typeImg = #imageLiteral(resourceName: "icon_type_bumen")
        default:
            break
        }
        
        self.nickNameLab.attributedText = nil
        self.nickNameLab.text = nil
        
        // 群公开名称
        if let typeImg = typeImg {
            self.nickNameLab.attributedText = groupInfo.publicName.jointImage(image: typeImg, rect: CGRect.init(x: 0, y: 0, width: 34, height: 18))
        } else {
            self.nickNameLab.text = groupInfo.publicName
        }
        
        // 群号
        if let markId = groupInfo.markId {
            self.addressLab.text = "群号：\(markId)"
        } else {
            self.addressLab.text = "群ID：\(groupInfo.id)"
        }
        
        // 生成二维码视图
        let time = Date.timestamp.string
        let groupQrCode = APP_DOWNLOAD_URL + "gid=\(groupInfo.id)" + "&server=\(BackupURL.urlEncoded)" + "&inviterId=\(LoginUser.shared().address)" + "&createTime=\(time)"
        self.qrImageView.image = QRCodeGenerator.setupQRCodeImage(groupQrCode, image: #imageLiteral(resourceName: "logo_120"))
    }
}
