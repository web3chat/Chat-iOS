//
//  FZMReleaseNotifyVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/30.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

class FZMReleaseNotifyVC: UIViewController {
    
    private let disposeBag = DisposeBag.init()
    
//    private let group : IMGroupDetailInfoModel
    private let group : Group
    
    var releaseBlock : NormalBlock?
    
    lazy var desBlockView : UIView = {
        let view = UIView()
        view.makeOriginalShdowShow()
        let titleLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "公告内容")
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(14)
            m.top.equalToSuperview().offset(5)
            m.height.equalTo(20)
        })
        view.addSubview(desNumLab)
        desNumLab.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(5)
            m.right.equalToSuperview().offset(-16)
            m.height.equalTo(20)
        })
        view.addSubview(desInput)
        desInput.snp.makeConstraints({ (m) in
            m.left.equalTo(titleLab).offset(-4)
            m.right.equalToSuperview().offset(-14)
            m.bottom.equalToSuperview().offset(-7)
            m.height.equalTo(84)
        })
        return view
    }()
    
    lazy var desNumLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .right, text: "0/50")
        return lab
    }()
    
    lazy var desInput : UITextView = {
        let input = UITextView()
        input.font = UIFont.regularFont(16)
        input.textColor = Color_24374E
        input.tintColor = Color_32B2F7
        input.backgroundColor = UIColor.clear
        input.addSubview(desPlaceLab)
        desPlaceLab.snp.makeConstraints({ (m) in
            m.left.top.equalToSuperview().offset(4)
            m.size.equalTo(CGSize(width: 150, height: 23))
        })
        return input
    }()
    
    lazy var desPlaceLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_8A97A5, textAlignment: .left, text: "点击编辑公告内容")
        return lab
    }()
    
    lazy var confirmBtn : UIButton = {
        let btn = UIButton.getNormalBtn(with: "确定")
        return btn
    }()
    
//    init(with group: IMGroupDetailInfoModel) {
    init(with group: Group) {
        self.group = group
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.title = "发布公告"
        self.view.addSubview(desBlockView)
        desBlockView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(15)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(120)
        }
        
        let view = UIView()
        view.makeOriginalShdowShow()
        self.view.addSubview(view)
        view.snp.makeConstraints { (m) in
            m.bottom.left.right.equalTo(self.safeArea)
            m.height.equalTo(70)
        }
        view.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: ScreenWidth - 30 , height: 40))
        }
        
        confirmBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.commitInfo()
        }.disposed(by: disposeBag)
        
        desInput.rx.didChange.subscribe(onNext:{[weak self] in
            guard let strongSelf = self else{ return }
            strongSelf.desInput.limitText(with: 50)
            if let text = strongSelf.desInput.text, text.count > 0 {
                strongSelf.desNumLab.text = "\(text.count)/50"
                strongSelf.desPlaceLab.isHidden = true
            }else {
                strongSelf.desNumLab.text = "0/50"
                strongSelf.desPlaceLab.isHidden = false
            }
        }).disposed(by: disposeBag)
        
        desInput.addToolBar(with: "确定", target: self, sel: #selector(FZMReleaseNotifyVC.commitInfo))
    }
    
    @objc private func commitInfo() {
        guard let text = desInput.text else { return }
        self.showProgress()
//        IMConversationManager.shared().groupReleaseNotify(groupId: group.groupId, content: text) { (response) in
//            self.hideProgress()
//            guard response.success else {
//                self.showToast(with: response.message)
//                return
//            }
//            self.releaseBlock?()
//            self.popBack()
//        }
    }

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
