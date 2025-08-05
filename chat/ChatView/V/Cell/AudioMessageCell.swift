//
//  AudioMessageCell.swift
//  chat
//
//  Created by 陈健 on 2020/12/28.
//

import UIKit
import SnapKit
import RxSwift

class AudioMessageCell: MessageContentCell {
    
    let voiceImageViewSize = CGSize.init(width: 15, height: 22)
    
    // 语音小喇叭动画
    lazy var voiceImageView: UIImageView = {
        let imgV = UIImageView()
        imgV.contentMode = .scaleAspectFit
        //动画时间：数组里面所有的图片转一圈所用时间
        imgV.animationDuration = 2
        //循环次数：大于0的数：写几就循环几次，结束    0:无限循环
        imgV.animationRepeatCount = 0
        return imgV
    }()
    
    // 语音时长
    lazy var voiceLab : UILabel = {
        let lab = UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: "1s")
        return lab
    }()
    
    let countDownCount = 10
    
    var voiceDisposeBag = DisposeBag()
    
    override func setupViews() {
        super.setupViews()
        
        self.messageContainerView.addSubview(voiceImageView)
        self.messageContainerView.addSubview(voiceLab)
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        guard let attributes = layoutAttributes as? MessageCollectionViewLayoutAttributes else { return }
        
//        let totalHeight = attributes.size.height
        
        var originImgV = CGPoint.zero
        var originLab = CGPoint.zero
//        var sizeLab = CGSize.init(width: 0, height: totalHeight)
        let audioPadding = attributes.audioLeadingTrailingPadding
        
        switch attributes.audioPosition.horizontal {
        case .cellLeading:
            originImgV.x = audioPadding
            self.voiceLab.textAlignment = .left
            originLab.x = audioPadding + voiceImageViewSize.width + 10
        case .cellTrailing:
            originImgV.x = attributes.messageContainerSize.width - voiceImageViewSize.width - audioPadding
            self.voiceLab.textAlignment = .right
        }
        
        originImgV.y = 10
        originLab.y = 10
        
        self.voiceImageView.frame = CGRect.init(origin: originImgV, size: voiceImageViewSize)
        
        let width = attributes.messageContainerSize.width - voiceImageViewSize.width - audioPadding - 10
        self.voiceLab.frame = CGRect.init(origin: originLab, size: CGSize.init(width: width, height: voiceImageViewSize.height))
    }
    
    private func setVoiceImageVIewAnimateImages(isOutGoing: Bool) {
        var arr = [UIImage]()
        if isOutGoing {
            arr.append(#imageLiteral(resourceName: "voice_right_1"))
            arr.append(#imageLiteral(resourceName: "voice_right_2"))
            arr.append(#imageLiteral(resourceName: "voice_right_3"))
        } else {
            arr.append(#imageLiteral(resourceName: "voice_left_1"))
            arr.append(#imageLiteral(resourceName: "voice_left_2"))
            arr.append(#imageLiteral(resourceName: "voice_left_3"))
        }
        
        //设置动画图片，需要接收一个数组，数组里面的类型必须是UIImage类型
        self.voiceImageView.animationImages = arr
    }
    
    func startAnimate(isOutGoing: Bool) {
        
//        //动画时间：数组里面所有的图片转一圈所用时间
//        self.voiceImageView.animationDuration = 1
//        //循环次数：大于0的数：写几就循环几次，结束    0:无限循环
//        self.voiceImageView.animationRepeatCount = 0
        // 开始动画
        self.voiceImageView.startAnimating()
    }
    
    func stopAnimate(isOutGoing: Bool) {
        // 结束动画
        self.voiceImageView.stopAnimating()
//        if isOutGoing {
//            self.voiceImageView.image = #imageLiteral(resourceName: "voice_right_3")
//        } else {
//            self.voiceImageView.image = #imageLiteral(resourceName: "voice_left_3")
//        }
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        
        super.configure(with: message, at: indexPath, and: messageCollectionView)
        
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessagesDisplayDelegate")
        }
        
        switch message.kind {
        case .audio(let audioItem):
            self.voiceLab.text = String(format: "%.0fs", audioItem.duration ?? 0)
        default:
            break
        }
        
        self.voiceImageView.image = message.isOutgoing ? #imageLiteral(resourceName: "voice_right_3") : #imageLiteral(resourceName: "voice_left_3")
        
        self.setVoiceImageVIewAnimateImages(isOutGoing: message.isOutgoing)
        
        displayDelegate.configureRedDotView(self.redDotView, for: message, at: indexPath, in: messageCollectionView)
        
        self.voiceDisposeBag = DisposeBag()
        
        VoiceMessagePlayerManager.shared().voicePalyStateSubject.subscribe { [weak self] (event) in
            guard let strongSelf = self, case .next(let even) = event, let msgId = even?.0, let state = even?.1 else { return }
            guard var msg = self?.msg, msg.msgId == msgId else {
                return
            }
            msg.isRead = true
            
            strongSelf.redDotView.isHidden = true
            if state == .start {
                strongSelf.voiceImageView.startAnimating()
            } else if state == .finish {
                strongSelf.voiceImageView.stopAnimating()
            } else if state == .failed {
                strongSelf.voiceImageView.stopAnimating()
                APP.shared().showToast("播放失败")
            }
        }.disposed(by: voiceDisposeBag)
    }
}

