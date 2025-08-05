//
//  IMSharePlatformView.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/12.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class FZMSharePlatformView: UIView {
    
    init(clickBlock : ((_ clickIndex : Int)->())?) {
        super.init(frame: CGRect.zero)
        let titleLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: UIColor.white, textAlignment: NSTextAlignment.center, text: "选择你的分享方式")
        self.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.centerX.top.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 105, height: 14))
        }
        let lineV1 = UIView()
        lineV1.backgroundColor = UIColor.white
        self.addSubview(lineV1)
        lineV1.snp.makeConstraints { (m) in
            m.centerY.equalTo(titleLab)
            m.left.equalToSuperview()
            m.right.equalTo(titleLab.snp.left).offset(-13)
            m.height.equalTo(1)
        }
        let lineV2 = UIView()
        lineV2.backgroundColor = UIColor.white
        self.addSubview(lineV2)
        lineV2.snp.makeConstraints { (m) in
            m.centerY.equalTo(titleLab)
            m.right.equalToSuperview()
            m.left.equalTo(titleLab.snp.right).offset(13)
            m.height.equalTo(1)
        }
        
//        let wxView = FZMImageTitleView.init(headImage: GetBundleImage("share_wx_2"), imageSize: CGSize.init(width: 41, height: 41), title: "微信好友") {
//            if clickBlock != nil {
//                clickBlock?(1)
//            }
//        }
//        self.addSubview(wxView)
//        wxView.snp.makeConstraints { (m) in
//            m.left.equalToSuperview().offset(5)
//            m.bottom.equalToSuperview()
//            m.size.equalTo(CGSize.init(width: 52, height: 60))
//        }
//        let timeLineView = FZMImageTitleView.init(headImage: GetBundleImage("share_timeline"), imageSize: CGSize.init(width: 41, height: 41), title: "朋友圈") {
//            if clickBlock != nil {
//                clickBlock?(2)
//            }
//        }
//        self.addSubview(timeLineView)
//        timeLineView.snp.makeConstraints { (m) in
//            m.right.equalTo(self.snp.centerX).offset(-8)
//            m.bottom.equalToSuperview()
//            m.size.equalTo(CGSize.init(width: 52, height: 60))
//        }
//        let qqView = FZMImageTitleView.init(headImage: GetBundleImage("share_qq"), imageSize: CGSize.init(width: 41, height: 41), title: "QQ好友") {
//            if clickBlock != nil {
//                clickBlock?(3)
//            }
//        }
//        self.addSubview(qqView)
//        qqView.snp.makeConstraints { (m) in
//            m.left.equalTo(self.snp.centerX).offset(8)
//            m.bottom.equalToSuperview()
//            m.size.equalTo(CGSize.init(width: 52, height: 60))
//        }
//        let qzoneView = FZMImageTitleView.init(headImage: GetBundleImage("share_timeline"), imageSize: CGSize.init(width: 41, height: 41), title: "QQ空间") {
//            if clickBlock != nil {
//                clickBlock?(4)
//            }
//        }
//        self.addSubview(qzoneView)
//        qzoneView.snp.makeConstraints { (m) in
//            m.right.equalToSuperview().offset(-5)
//            m.bottom.equalToSuperview()
//            m.size.equalTo(CGSize.init(width: 52, height: 60))
//        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

}
