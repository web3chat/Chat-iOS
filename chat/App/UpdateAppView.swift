//
//  UpdateAppView.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/16.
//
//  版本更新视图
//

import UIKit
import SnapKit

class UpdateAppView: UIView {

    private lazy var bgImg : UIImageView = {
        let v = UIImageView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight))
        v.backgroundColor = UIColor(hex: 0x000000).withAlphaComponent(0.5)
        
        return v
    }()
    
    private lazy var iconImg : UIImageView = {
        let v = UIImageView.init(image: #imageLiteral(resourceName: "icon_updateapp"))
        return v
    }()
    
    private lazy var titleLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 20), textColor: Color_24374E, textAlignment: .center, text: nil)
        lab.numberOfLines = 1
        lab.text = "发现新版本"
        return lab
    }()
    
    private lazy var versionLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 16), textColor: Color_Theme, textAlignment: .center, text: nil)
        lab.numberOfLines = 1
        return lab
    }()
    
    private lazy var descriptionTV : UITextView = {
        let tv = UITextView.init(frame: CGRect.init())
        tv.isScrollEnabled = true
        tv.isSelectable = false
        tv.isEditable = false
        tv.textColor = Color_24374E
        tv.font = UIFont.mediumFont(16)
        tv.showsHorizontalScrollIndicator = false
        tv.showsVerticalScrollIndicator = false
        
        return tv
    }()
    
    private lazy var updateBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Color_Theme
        btn.setTitle("立即更新", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.isHidden = true
        
//        btn.rx.controlEvent(.touchUpInside).subscribe { [weak self] (_) in
//            guard let strongSelf = self else { return }
//            strongSelf.updateAppAction()
//        }.disposed(by: disposeBag)
        
        btn.addTarget(self, action: #selector(updateAppAction), for: .touchUpInside)
        return btn
    }()
    
    private lazy var updateLaterBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = .white
        btn.setTitle("稍后更新", for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.isHidden = true
        
        btn.rx.controlEvent(.touchUpInside).subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.removeFromSuperview()
        }.disposed(by: disposeBag)
        
//        btn.addTarget(self, action: #selector(updateAppAction), for: .touchUpInside)
        return btn
    }()
    
    private lazy var updateView : UIView = {
        let v = UIView.init()
        v.backgroundColor = .white
        v.layer.cornerRadius = 10
        v.layer.masksToBounds = true
        
        return v
    }()
    
    let disposeBag = DisposeBag()
    
    let versionCheck : VersionCheck
    
    init(frame: CGRect, versionCheck: VersionCheck) {
        self.versionCheck = versionCheck
        super.init(frame: frame)
        self.createUI()
        self.loadVersionInfo()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createUI() {
        self.addSubview(bgImg)
        bgImg.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.addSubview(updateView)
        updateView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(30)
            m.right.equalToSuperview().offset(-30)
            m.height.equalTo(408)
            m.centerY.equalToSuperview()
        }
        
        updateView.addSubview(iconImg)
        iconImg.snp.makeConstraints { (m) in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(150)
        }
        
        updateView.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(iconImg.snp.bottom).offset(15)
        }
        
        updateView.addSubview(versionLab)
        versionLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(titleLab.snp.bottom).offset(10)
        }
        
        updateView.addSubview(descriptionTV)
        descriptionTV.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(versionLab.snp.bottom).offset(15)
            m.bottom.equalToSuperview().offset(-85)
        }
        
    }
    
    private func loadVersionInfo() {
        let version = versionCheck.versionName
        let desc = versionCheck.description
        let force = versionCheck.force
        
        //wjhTEST
//        var version = versionCheck.versionName
//        var desc = versionCheck.description
//        var force = versionCheck.force
//        version = "2.3.0"
//        desc = ["新增***功能","修复系统已知问题，提升用户体验","UI界面优化","还有其他很多更新"]
//        force = false
        
        var descStr = ""
        for i in 0..<desc.count {
            descStr = descStr + "\(i + 1).\(desc[i])\n"
        }
        
        versionLab.text = "V" + version
        
        descriptionTV.text = descStr
        
        if force {
            updateView.addSubview(updateBtn)
            updateBtn.isHidden = false
            updateBtn.snp.makeConstraints { (m) in
                m.height.equalTo(40)
                m.left.equalToSuperview().offset(15)
                m.right.equalToSuperview().offset(-15)
                m.bottom.equalToSuperview().offset(-30)
            }
        } else {
            updateView.addSubview(updateLaterBtn)
            updateLaterBtn.isHidden = false
            updateLaterBtn.snp.makeConstraints { (m) in
                m.height.equalTo(40)
                m.left.equalToSuperview().offset(15)
                m.width.equalToSuperview().multipliedBy(0.5).offset(-20)
                m.bottom.equalToSuperview().offset(-30)
            }
            
            updateView.addSubview(updateBtn)
            updateBtn.isHidden = false
            updateBtn.snp.makeConstraints { (m) in
                m.height.equalTo(40)
                m.width.equalToSuperview().multipliedBy(0.5).offset(-20)
                m.right.equalToSuperview().offset(-15)
                m.bottom.equalToSuperview().offset(-30)
            }
        }
    }
    
    @objc private func updateAppAction() {
        APP.shared().openUrl(with: APPSTORE_DOWNLOAD_URL)
    }
    
}
