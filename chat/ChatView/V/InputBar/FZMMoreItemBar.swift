//
//  FZMMoreItemBar.swift
//  Chat33
//
//  Created by fzm on 2018/9/26.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import SnapKit

class FZMMoreItemBar: UIView {
    
    let disposeBag = DisposeBag()
    
    weak var delegate : MoreItemClickDelegate?
    
    let itemSize = CGSize(width: 61, height: 82)
    
    /// 阅后即焚入口的图标 / 文字 / 底色（用于选中态高亮）
    private weak var burnIconView: UIImageView?
    private weak var burnLabel: UILabel?
    private weak var burnBgView: UIView?
    
    lazy var photoView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_image"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("图片/视频"))
//        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "图片")//wjhTEST
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()
    
    lazy var cameraView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_camera"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("拍摄"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()
    
    lazy var fileView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_file"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("文件"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()
    
    lazy var redBagView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_redBag"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("红包"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()

    /// 专属红包（仅群聊展示：先选 1 位群成员作为领取人）
    lazy var exclusiveRedBagView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_redBag"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("专属红包"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()

    /// 聊天室（发起语音聊天：选模式 → 建房 → 把房间链接发到当前会话 → 直接进房）
    ///
    /// 项名「语音聊天」（2026-10-16 由「视频聊天」改名，用户要求）。
    /// 图标 = `inputBar_voiceRoom`（自绘：浅青底 `#E4F8F8` + 实心麦克风 `#2FC6C4`，
    /// 180×180@3x、圆角 30，与面板其它图标同规格）；资源缺失才回退到旧的 `inputBar_voice`
    lazy var voiceRoomView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_voiceRoom") ?? UIImage.init(named: "inputBar_voice"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("语音聊天"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()
    //
    //    lazy var redBagMsgView : UIView = {
    //        let view = UIView()
    //        let imV = UIImageView(image: UIImage.init(named: "inputBar_redBag_msg"))
    //        view.addSubview(imV)
    //        imV.snp.makeConstraints({ (m) in
    //            m.top.equalToSuperview()
    //            m.centerX.equalToSuperview()
    //            m.size.equalTo(CGSize(width: 61, height: 60))
    //        })
    //        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "红包消息")
    //        view.addSubview(lab)
    //        lab.snp.makeConstraints({ (m) in
    //            m.bottom.equalToSuperview()
    //            m.centerX.equalToSuperview()
    //            m.height.equalTo(17)
    //        })
    //        return view
    //    }()
    
    // 阅后即焚入口（第 2 行第 4 格；资源包无 inputBar_burn_icon，用系统符号 + 圆角底，
    // 与「视频聊天」等自带底色的图标体量保持一致）
    lazy var burnView : UIView = {
        let view = UIView()
        let bg = UIView()
        bg.backgroundColor = Color_F6F7F8
        bg.layer.cornerRadius = 14
        bg.layer.masksToBounds = true
        view.addSubview(bg)
        bg.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(2)
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 56, height: 56))
        })
        let imV = UIImageView()
        imV.image = UIImage(systemName: "flame.fill")
        imV.tintColor = Color_8A97A5
        imV.contentMode = .scaleAspectFit
        bg.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: 28, height: 28))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("阅后即焚"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        self.burnBgView = bg
        self.burnIconView = imV
        self.burnLabel = lab
        return view
    }()
    
//    lazy var receiptView : UIView = {
//        let view = UIView()
//        let imV = UIImageView(image: UIImage.init(named: "inputBar_receipt"))
//        view.addSubview(imV)
//        imV.snp.makeConstraints({ (m) in
//            m.top.equalToSuperview()
//            m.centerX.equalToSuperview()
//            m.size.equalTo(CGSize(width: 61, height: 60))
//        })
//        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "收款")
//        view.addSubview(lab)
//        lab.snp.makeConstraints({ (m) in
//            m.bottom.equalToSuperview()
//            m.centerX.equalToSuperview()
//            m.height.equalTo(17)
//        })
//        return view
//    }()
//
    lazy var transferView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_transfer"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("转账"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()
    
    lazy var contactView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_contactcard"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: L("名片"))
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.bottom.equalToSuperview()
            m.centerX.equalToSuperview()
            m.height.equalTo(17)
        })
        return view
    }()
    
    init() {
        super.init(frame: CGRect.zero)
        self.clipsToBounds = true
    }
    
    func bindTo(view: UIView) {
        self.removeFromSuperview()
        
        view.addSubview(self)
        
        self.setupViews()
    }
    
    private func setupViews() {
        
//        if IMSDK.shared().showRedBag {
//            self.addSubview(redBagView)
//            self.addSubview(photoView)
//            self.addSubview(cameraView)
//            self.addSubview(burnView)
//            self.addSubview(fileView)
//            self.addSubview(transferView)
//            self.addSubview(receiptView)
//            self.addSubview(redBagMsgView)
//            photoView.snp.makeConstraints { (m) in
//                m.right.equalTo(self.snp.centerX).offset(-10)
//                m.top.equalToSuperview().offset(5)
//                m.size.equalTo(itemSize)
//            }
//            redBagView.snp.makeConstraints { (m) in
//                m.centerY.equalTo(photoView)
//                m.right.equalTo(photoView.snp.left).offset(-20)
//                m.size.equalTo(itemSize)
//            }
//            cameraView.snp.makeConstraints { (m) in
//                m.centerY.equalTo(photoView)
//                m.left.equalTo(self.snp.centerX).offset(10)
//                m.size.equalTo(itemSize)
//            }
//            burnView.snp.makeConstraints { (m) in
//                m.centerY.equalTo(photoView)
//                m.left.equalTo(cameraView.snp.right).offset(20)
//                m.size.equalTo(itemSize)
//            }
//
//            fileView.snp.makeConstraints { (m) in
//                m.left.equalTo(redBagView)
//                m.top.equalTo(redBagView.snp.bottom).offset(19)
//                m.size.equalTo(itemSize)
//            }
//            transferView.snp.makeConstraints { (m) in
//                m.left.equalTo(photoView)
//                m.top.equalTo(fileView)
//                m.size.equalTo(itemSize)
//            }
//            receiptView.snp.makeConstraints { (m) in
//                m.left.equalTo(cameraView)
//                m.top.equalTo(fileView)
//                m.size.equalTo(itemSize)
//            }
//            redBagMsgView.snp.makeConstraints { (m) in
//                m.left.equalTo(burnView)
//                m.top.equalTo(fileView)
//                m.size.equalTo(itemSize)
//            }
//        }else {
        
        self.backgroundColor = Color_FFFFFF
        self.layer.backgroundColor = Color_FFFFFF.cgColor
        
//        self.snp.makeConstraints { (m) in
//            m.right.left.equalToSuperview()
//            m.height.equalTo(100)
//            m.bottom.equalToSuperview().offset(100+k_SafeBottomInset)
//        }
        
        let safeBottomView = UIView.init()
        safeBottomView.backgroundColor = self.backgroundColor
        self.addSubview(safeBottomView)
        safeBottomView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.snp.bottom)
            m.height.equalTo(k_SafeBottomInset)
        }
        
        self.addSubview(cameraView)
        cameraView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(5)
            m.right.equalTo(self.snp.centerX).offset(-10)
            m.size.equalTo(itemSize)
        }
        
        self.addSubview(photoView)
        photoView.snp.makeConstraints { (m) in
            m.right.equalTo(cameraView.snp.left).offset(-20)
            m.centerY.equalTo(cameraView)
            m.size.equalTo(itemSize)
        }
        
        self.addSubview(fileView)
        fileView.snp.makeConstraints { (m) in
            m.centerY.equalTo(cameraView)
            m.left.equalTo(cameraView.snp.right).offset(20)
            m.size.equalTo(itemSize)
        }
        self.addSubview(transferView)
//        transferView.isHidden = true
        transferView.snp.makeConstraints { (m) in
            m.left.equalTo(fileView.snp.right).offset(20)
            m.centerY.equalTo(cameraView)
            m.size.equalTo(itemSize)
        }
        
        self.addSubview(contactView)
        contactView.snp.makeConstraints { (m) in
            m.left.equalTo(photoView)
            m.top.equalTo(photoView.snp.bottom).offset(20)
            m.size.equalTo(itemSize)
        }

        self.addSubview(redBagView)
        redBagView.snp.makeConstraints { (m) in
            m.left.equalTo(contactView.snp.right).offset(20)
            m.centerY.equalTo(contactView)
            m.size.equalTo(itemSize)
        }

        // 专属红包紧跟在普通红包后面（仅群聊展示，由 ChatVC 控制）
        self.addSubview(exclusiveRedBagView)
        exclusiveRedBagView.snp.makeConstraints { (m) in
            m.left.equalTo(redBagView.snp.right).offset(20)
            m.centerY.equalTo(redBagView)
            m.size.equalTo(itemSize)
        }

        // 聊天室（语音 / 视频）：第 2 行第 3 格。
        // 默认按**私聊**布局（与隐藏的专属红包重叠）；群聊分支由 ChatVC 调
        // `layoutVoiceRoom(isPrivateChat: false)` 重排（那里 `hideTrans()` 会把红包挪到第 2 行第 1 格）。
        self.addSubview(voiceRoomView)
        voiceRoomView.snp.makeConstraints { (m) in
            m.left.equalTo(exclusiveRedBagView.snp.left)
            m.centerY.equalTo(exclusiveRedBagView)
            m.size.equalTo(itemSize)
        }
        // 阅后即焚入口：第 2 行第 4 格（语音房右边；两种配置下都空）
        self.addSubview(burnView)
        burnView.snp.makeConstraints { (m) in
            m.left.equalTo(voiceRoomView.snp.right).offset(20)
            m.centerY.equalTo(voiceRoomView)
            m.size.equalTo(itemSize)
        }
//        redBagView.isHidden = true
        self.makeActions()
//        seilf.addSubview(burnView)
//        self.addSubview(transferView)
//        self.addSubview(receiptView)
//        burnView.snp.makeConstraints { (m) in
//            m.centerY.equalTo(photoView)
//            m.left.equalTo(self.snp.centerX).offset(10)
//            m.size.equalTo(itemSize)
//        }
 
//        receiptView.snp.makeConstraints { (m) in
//            m.left.equalTo(cameraView)
//            m.top.equalTo(transferView)
//            m.size.equalTo(itemSize)
//        }
//        }
//
//        if !IMSDK.shared().showWallet {
//            self.hideTransferAndReceipt()
//        }
    }
    
    private func makeActions() {
        let photoTap = UITapGestureRecognizer()
        photoTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.sendPhoto()
        }).disposed(by: disposeBag)
        photoView.addGestureRecognizer(photoTap)
        
        let cameraTap = UITapGestureRecognizer()
        cameraTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.goCamera()
        }).disposed(by: disposeBag)
        cameraView.addGestureRecognizer(cameraTap)
        
        let redbagTap = UITapGestureRecognizer()
        redbagTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.sendRedBag()
        }).disposed(by: disposeBag)
        redBagView.addGestureRecognizer(redbagTap)

        let exclusiveRedbagTap = UITapGestureRecognizer()
        exclusiveRedbagTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.sendExclusiveRedBag()
        }).disposed(by: disposeBag)
        exclusiveRedBagView.addGestureRecognizer(exclusiveRedbagTap)
//
//        let redbagMsgTap = UITapGestureRecognizer()
//        redbagMsgTap.rx.event.subscribe(onNext:{[weak self] (_) in
//            self?.delegate?.sendRedBagMsg()
//        }).disposed(by: disposeBag)
//        redBagMsgView.addGestureRecognizer(redbagMsgTap)
        let burnTap = UITapGestureRecognizer()
        burnTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.burnCtrl()
        }).disposed(by: disposeBag)
        burnView.addGestureRecognizer(burnTap)
        
        let fileTap = UITapGestureRecognizer()
        fileTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.sendFile()
        }).disposed(by: disposeBag)
        fileView.addGestureRecognizer(fileTap)
        
        let transferTap = UITapGestureRecognizer()
        transferTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.transfer()
        }).disposed(by: disposeBag)
        transferView.addGestureRecognizer(transferTap)
        
        let contactTap = UITapGestureRecognizer()
        contactTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.sendContact()
        }).disposed(by: disposeBag)
        contactView.addGestureRecognizer(contactTap)

        let voiceRoomTap = UITapGestureRecognizer()
        voiceRoomTap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.delegate?.sendVoiceRoom()
        }).disposed(by: disposeBag)
        voiceRoomView.addGestureRecognizer(voiceRoomTap)
        
//
//        let receiptTap = UITapGestureRecognizer()
//        receiptTap.rx.event.subscribe(onNext:{[weak self] (_) in
//            self?.delegate?.receipt()
//        }).disposed(by: disposeBag)
//        receiptView.addGestureRecognizer(receiptTap)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 按会话类型给「聊天室」项定位。
    ///
    /// 第 2 行第 3 格在**两种配置下都是空的**，所以不需要改面板高度常量（`moreItemBarHeight`）：
    /// · 私聊：`exclusiveRedBagView` 被隐藏，但 SnapKit 里仍占位 ⇒ 直接和它重叠，视觉上无缝；
    /// · 群聊：`hideTrans()` 把 `redBagView` 挪到第 2 行第 1 格，`exclusiveRedBagView` 占第 2 格
    ///   ⇒ 聊天室接在 `exclusiveRedBagView` 右边。
    /// 行宽校验：第 2 行 4 项 = 4×61 + 3×20 = 304pt < 375pt（最窄机型），放得下。
    func layoutVoiceRoom(isPrivateChat: Bool) {
        voiceRoomView.snp.remakeConstraints { (m) in
            if isPrivateChat {
                m.left.equalTo(exclusiveRedBagView.snp.left)
                m.centerY.equalTo(exclusiveRedBagView)
            } else {
                m.left.equalTo(exclusiveRedBagView.snp.right).offset(20)
                m.centerY.equalTo(exclusiveRedBagView)
            }
            m.size.equalTo(itemSize)
        }
    }

    func hideTrans(){
        self.transferView.isHidden = true
        self.redBagView.isHidden = false
        contactView.snp.remakeConstraints { (m) in
            m.left.equalTo(fileView.snp.right).offset(20)
            m.centerY.equalTo(cameraView)
            m.size.equalTo(itemSize)
        }

        redBagView.snp.remakeConstraints { (m) in
            m.left.equalTo(photoView)
            m.top.equalTo(photoView.snp.bottom).offset(20)
            m.size.equalTo(itemSize)
        }
    }
    
    func hideRed(){
//        transferView.isHidden = true
        self.redBagView.isHidden = true
        self.exclusiveRedBagView.isHidden = true
        self.transferView.isHidden = false
    }
    func hideRedAndTrans(){
        self.redBagView.isHidden = true
        self.exclusiveRedBagView.isHidden = true
        self.transferView.isHidden = true
    }
    
    /// 是否展示阅后即焚入口（仅私聊）
    func showBurn(_ show: Bool) {
        burnView.isHidden = !show
    }
    
    /// 阅后即焚模式选中态高亮
    func setBurnSelected(_ selected: Bool) {
        let color = selected ? Color_Theme : Color_8A97A5
        burnIconView?.tintColor = color
        burnLabel?.textColor = color
        burnBgView?.backgroundColor = selected ? Color_Theme.withAlphaComponent(0.12) : Color_F6F7F8
    }
    
//    func hideTransferAndReceipt() {
//        self.receiptView.isHidden = true
//        self.transferView.isHidden = true
//        if IMSDK.shared().showRedBag {
//            redBagMsgView.snp.remakeConstraints { (m) in
//                m.left.equalTo(photoView)
//                m.top.equalTo(fileView)
//                m.size.equalTo(itemSize)
//            }
//        }
//    }
}

protocol MoreItemClickDelegate: AnyObject {
    func sendPhoto()
    func goCamera()
    func sendRedBag()
    func sendExclusiveRedBag()
    func burnCtrl()
    func sendFile()
    func transfer()
    func sendContact()
    func sendVoiceRoom()
//    func receipt()
//    func sendRedBagMsg()
}
