//
//  FZMBottomSelectView.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/9/12.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

class FZMBottomSelectView: UIView {
    
    let disposeBag = DisposeBag()
    
    private let cancelBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setAttributedTitle(NSAttributedString(string: "取消", attributes: [.foregroundColor:Color_24374E,.font:UIFont.regularFont(16)]), for: .normal)
        return btn
    }()
    
    private lazy var cancelView: UIView = {
        let view = UIView.init()
        view.backgroundColor = .white
        
        view.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints { (m) in
            m.left.right.top.equalToSuperview()
            m.height.equalTo(60)
        }
        
        return view
    }()
    
    private lazy var titleLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(16), textColor: Color_8A97A5, textAlignment: .center, text: "标题")
        return lab
    }()
    
    private lazy var titleView: UIView = {
        let view = UIView.init()
        view.backgroundColor = .white
        
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        let line = getLineView()
        view.addSubview(line)
        line.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
        
//        DispatchQueue.main.async {
//            view.roundCorners([.topLeft, .topRight], radius: 30)
//        }
        return view
    }()
    
    private func getLineView() -> UIView {
        let view = UIView.init()
        view.backgroundColor = Color_E6EAEE
        return view
    }
    
    private lazy var contentView: UIView = {
        let view = UIView.init()
        view.backgroundColor = .white
        
        view.addSubview(titleView)
        titleView.snp.makeConstraints { (m) in
            m.left.right.top.equalToSuperview()
            m.height.equalTo(50)
        }
        
        view.addSubview(cancelView)
        
        cancelView.snp.makeConstraints { (m) in
            m.left.equalToSuperview()
            m.right.equalToSuperview()
            m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
            m.height.equalTo(60)
        }
        
        
        
        return view
    }()
    
    init(with title: String, titleArr:[FZMBottomOption]) {
        super.init(frame: k_ScreenBounds)
        self.backgroundColor = UIColor(white: 0, alpha: 0.5)
        let tap = UITapGestureRecognizer()
        tap.rx.event.subscribe(onNext:{[weak self] (_) in
            self?.hide()
        }).disposed(by: disposeBag)
        self.addGestureRecognizer(tap)
        
        cancelBtn.rx.controlEvent(.touchUpInside).subscribe(onNext:{[weak self] (_) in
            self?.hide()
        }).disposed(by: disposeBag)
        
        self.addSubview(contentView)
        let height = title.isBlank ? 60 + titleArr.count*60 : 50 + 60 + titleArr.count*60
        
        contentView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.height.equalTo(height + Int(k_SafeBottomInset))
            m.bottom.equalToSuperview().offset(300)
        }
        
        titleLab.text = title
        if title.isBlank {
            titleView.isHidden = true
            titleView.snp.updateConstraints { (m) in
                m.height.equalTo(0)
            }
        }
        
        var topView = titleView
        titleArr.forEach { (option) in
            let view = UIView.init()
            view.backgroundColor = .white
            
            let btn = UIButton(type: .custom)
            btn.layer.cornerRadius = 20
            btn.clipsToBounds = true
            let attStr = NSMutableAttributedString(string: option.title, attributes: [.foregroundColor:option.textColor,.font:UIFont.regularFont(16)])
            if let content = option.content, content.count > 0 {
                btn.titleLabel?.numberOfLines = 0
                btn.titleLabel?.textAlignment = .center
                attStr.append(NSAttributedString(string: "\n"))
                attStr.append(NSAttributedString(string: content, attributes: [.foregroundColor:option.contentColor,.font:UIFont.regularFont(14)]))
            }
            btn.setAttributedTitle(attStr, for: .normal)
            btn.rx.controlEvent(.touchUpInside).subscribe(onNext:{[weak self] (_) in
                option.clickBlock?()
                self?.hide()
            }).disposed(by: disposeBag)
            
            view.addSubview(btn)
            btn.snp.makeConstraints { (m) in
                m.edges.equalToSuperview()
            }
            
            let line = getLineView()
            view.addSubview(line)
            line.snp.makeConstraints { (m) in
                m.left.right.bottom.equalToSuperview()
                m.height.equalTo(0.5)
            }
            
            contentView.addSubview(view)
            view.snp.makeConstraints { (m) in
                m.left.right.equalToSuperview()
                m.top.equalTo(topView.snp.bottom)
                m.height.equalTo(60)
            }
            topView = view
        }
    }
    
    func show(){
       
        UIApplication.shared.keyWindow?.addSubview(self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateConstraints(with: 0.3) {
                self.contentView.snp.updateConstraints({ (m) in
                    m.bottom.equalToSuperview().offset(0)
                })
            }
        }
    }
    
    func hide(){
        self.updateConstraints(with: 0.3, updateBlock: {
            self.contentView.snp.updateConstraints({ (m) in
                m.bottom.equalToSuperview().offset(300)
            })
        }) {
            self.removeFromSuperview()
        }
    }
    
    class func show(with title: String, arr:[FZMBottomOption]){
        let view = FZMBottomSelectView(with: title, titleArr: arr)
        view.show()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class FZMBottomOption: NSObject {
    var title = ""
    var content : String?
    var textColor : UIColor
    var contentColor : UIColor
    var clickBlock : (()->())?
    init(title : String , titleColor : UIColor = Color_24374E, content: String? = nil, contentColor: UIColor = Color_8A97A5, block:(()->())?) {
        self.title = title
        self.content = content
        self.textColor = titleColor
        self.contentColor = contentColor
        self.clickBlock = block
        super.init()
    }
    
    
}
