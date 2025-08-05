//
//  ChatInputBarView.swift
//  chat
//
//  Created by 陈健 on 2021/2/4.
//

import UIKit
import SnapKit
import RxSwift

class ChatInputBarView: InputBarView {
    
    override init() {
        super.init()
        self.leftStackViewWidth = 50
        self.rightStackViewWidth = 100
        
        self.leftStackView.addArrangedSubview(self.voiceBtn)
        self.rightStackView.addArrangedSubview(self.emojiBtn)
        self.rightStackView.addArrangedSubview(self.moreBtn)
        
//        voiceBtn.rx.controlEvent(.touchUpInside).subscribe(onNext:{[weak self] in
//            guard let strongSelf = self else { return }
//
//            strongSelf.showVoice = !strongSelf.showVoice
//            strongSelf.clickVoiceBtnBlock?()
//
////            if !strongSelf.showVoice {
////                strongSelf.showVoice = true
////                strongSelf.showVoiceBlock?()
////            }
//        }).disposed(by: disposeBag)
//
//        moreBtn.rx.controlEvent(.touchUpInside).subscribe(onNext:{[weak self] in
//            guard let strongSelf = self else { return }
//
//            strongSelf.showMore = !strongSelf.showMore
//            strongSelf.clickMoreBtnBlock?()
//        }).disposed(by: disposeBag)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
