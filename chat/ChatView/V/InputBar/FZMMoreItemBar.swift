//
//  FZMMoreItemBar.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/9/26.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import SnapKit

class FZMMoreItemBar: UIView {
    
    let disposeBag = DisposeBag()
    
    weak var delegate : MoreItemClickDelegate?
    
    let itemSize = CGSize(width: 61, height: 82)
    
    lazy var photoView : UIView = {
        let view = UIView()
        let imV = UIImageView(image: UIImage.init(named: "inputBar_image"))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 61, height: 60))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "图片/视频")
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
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "拍摄")
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
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "文件")
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
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "专属红包")
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
    
//    lazy var burnView : UIView = {
//        let view = UIView()
//        let imV = UIImageView(image: UIImage.init(named: "inputBar_burn_icon"))
//        view.addSubview(imV)
//        imV.snp.makeConstraints({ (m) in
//            m.top.equalToSuperview()
//            m.centerX.equalToSuperview()
//            m.size.equalTo(CGSize(width: 61, height: 60))
//        })
//        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "阅后即焚")
//        view.addSubview(lab)
//        lab.snp.makeConstraints({ (m) in
//            m.bottom.equalToSuperview()
//            m.centerX.equalToSuperview()
//            m.height.equalTo(17)
//        })
//        return view
//    }()
    
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
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "转账")
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
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "名片")
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
            m.left.equalTo(fileView.snp.right).offset(20)
            m.centerY.equalTo(cameraView)
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
//
//        let redbagMsgTap = UITapGestureRecognizer()
//        redbagMsgTap.rx.event.subscribe(onNext:{[weak self] (_) in
//            self?.delegate?.sendRedBagMsg()
//        }).disposed(by: disposeBag)
//        redBagMsgView.addGestureRecognizer(redbagMsgTap)
//
//        let burnTap = UITapGestureRecognizer()
//        burnTap.rx.event.subscribe(onNext:{[weak self] (_) in
//            self?.delegate?.burnCtrl()
//        }).disposed(by: disposeBag)
//        burnView.addGestureRecognizer(burnTap)
        
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
    
    
    func hideTrans(){
        self.transferView.isHidden = true
        self.redBagView.isHidden = false
    }
    
    func hideRed(){
//        transferView.isHidden = true
        self.redBagView.isHidden = true
        self.transferView.isHidden = false
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
//    func burnCtrl()
    func sendFile()
    func transfer()
    func sendContact()
//    func receipt()
//    func sendRedBagMsg()
}
