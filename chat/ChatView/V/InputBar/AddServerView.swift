//
//  AddServerView.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/10.
//
//  聊天页面底部添加聊天服务器视图
//

import Foundation
import SnapKit

class AddServerView: UIView {
    
    var addBlock: (()->())?
    
    private lazy var titleLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(16), textColor: Color_8A97A5, textAlignment: .center, text: "未连接当前群聊服务器，无法收发消息")
        lab.numberOfLines = 1
        lab.minimumScaleFactor = 0.5
        return lab
    }()
    
    private lazy var addServerBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle("添加服务器", for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.addTarget(self, action: #selector(addServerClick), for: .touchUpInside)
        btn.enlargeClickEdge(.init(top: 10, left: 10, bottom: 10, right: 10))
        return btn
    }()
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindTo(view: UIView) {
        self.removeFromSuperview()
        
        view.addSubview(self)
        
        self.setupViews()
    }
    
    private func setupViews() {
        self.backgroundColor = .white
        self.layer.backgroundColor = UIColor.white.cgColor
        
        self.snp.makeConstraints { (m) in
            m.right.left.equalToSuperview()
            m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
        }
        
        let safeBottomView = UIView.init()
        safeBottomView.backgroundColor = self.backgroundColor
        self.addSubview(safeBottomView)
        safeBottomView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.snp.bottom)
            m.height.equalTo(k_SafeBottomInset)
        }
        
        self.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(10)
            m.centerX.equalToSuperview()
        }
        
        self.addSubview(addServerBtn)
        addServerBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 100, height: 35))
            m.top.equalTo(titleLab.snp.bottom)
            m.centerX.equalToSuperview()
        }
        
        self.superview?.layoutIfNeeded()
    }
    
    @objc private func addServerClick() {
        self.addBlock?()
    }
    
}
