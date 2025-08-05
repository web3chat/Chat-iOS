//
//  IMRecordTipHub.swift
//  IM_SocketIO_Demo
//
//  Created by Wang on 2018/6/20.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import SnapKit

enum IMRecordType {
    case recording
    case cancel
    case shortTime
}

extension IMRecordType {
    var title: String  {
        switch self {
        case .recording:
            return "手指上滑，取消发送"
        case .cancel:
            return "松开手指，取消发送"
        case .shortTime:
            return "录音时间太短"
        }
    }
    var titleColor: UIColor {
        switch self {
        case .recording:
            return UIColor.white
        case .cancel:
            return UIColor(hex: 0xDD5F5F)!
        case .shortTime:
            return UIColor.white
        }
    }
    var image: UIImage? {
        switch self {
        case .recording:
            return UIImage(text: .record_1, imageSize: CGSize(width: 98, height: 98))
        case .cancel:
            return UIImage(text: .undo, imageSize: CGSize(width: 98, height: 98))
        case .shortTime:
            return UIImage(text: .warning, imageSize: CGSize(width: 98, height: 98))
        }
    }
    
    
    
}

class IMRecordTipHub: UIView {
    var type: IMRecordType = .recording {
        didSet {
            setupViews()
        }
    }
   
    lazy var showImageV: UIImageView = {
        let imgV = UIImageView()
        return imgV
    }()
    
    lazy var tipLbl: UILabel = {
        let lbl = UILabel()
        lbl.textColor = UIColor.white
        lbl.font = UIFont.regularFont(16)
        lbl.textAlignment = .center
        return lbl
    }()
    
    lazy var recordLbl: UILabel = {
        let lbl = UILabel()
        lbl.textColor = UIColor.white
        lbl.font = UIFont.regularFont(16)
        lbl.textAlignment = .center
        lbl.text = "还可以说10秒"
        return lbl
    }()
    
    //设置音量
    public func setVolume(_ volume: Float){
        guard type == .recording else {
            return
        }
        FZMLog("录音音量\(volume)")
        let imageFont: FZMIconFont
        if volume >= 0 && volume <= 0.1 {
            imageFont = .record_1
        } else if volume > 0.1 && volume <= 0.3 {
            imageFont = .record_2
        } else if volume > 0.3 && volume <= 0.4 {
            imageFont = .record_3
        } else if volume > 0.4 && volume <= 0.5 {
            imageFont = .record_4
        } else if volume > 0.5 && volume <= 0.6 {
            imageFont = .record_5
        } else if volume > 0.6 && volume <= 0.8 {
            imageFont = .record_6
        } else {
            imageFont = .record_7
        }
        showImageV.image = UIImage(text: imageFont, imageSize: CGSize(width: 98, height: 98))
    }
    //设置倒计时
    public func setCountDown(_ time: Int) {
        self.recordLbl.isHidden = false
        if time == 0 {
            self.recordLbl.text = "录音结束,松开发送"
        } else {
            self.recordLbl.text = "还可以说\(time)秒"
        }
    }
    
    required init(with type: IMRecordType) {
        super.init(frame: CGRect.zero)
        initView()
        self.type = type
    }
    fileprivate override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func initView() {
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
        let bgView: UIView = {
            let v = UIView()
            v.backgroundColor = UIColor(hex: 0x000000, alpha: 0.75)
            return v
        }()
        self.addSubview(bgView)
        let topView: UIView = {
            let v = UIView()
            return v
        }()
        self.addSubview(topView)
        topView.addSubview(showImageV)
        self.addSubview(tipLbl)
        self.addSubview(recordLbl)
        bgView.snp.makeConstraints { (m) in
            m.width.equalTo(220)
            m.height.equalTo(250)
            m.edges.equalToSuperview()
        }
        topView.snp.makeConstraints { (m) in
            m.width.equalTo(220)
            m.height.equalTo(178)
            m.centerX.equalToSuperview()
            m.top.equalToSuperview()
        }
        showImageV.snp.makeConstraints { (m) in
            m.width.equalTo(98)
            m.height.equalTo(98)
            m.centerY.equalToSuperview()
            m.centerX.equalToSuperview()
        }
        tipLbl.snp.makeConstraints { (m) in
            m.top.equalTo(topView.snp.bottom)
            m.centerX.equalToSuperview()
        }
        
        recordLbl.snp.makeConstraints { (m) in
            m.top.equalTo(tipLbl.snp.bottom).offset(5)
            m.centerX.equalToSuperview()
        }
    }
    private func setupViews() {
        recordLbl.isHidden = true
        tipLbl.text = self.type.title
        tipLbl.textColor = self.type.titleColor
        showImageV.image = self.type.image
    }
    

}
