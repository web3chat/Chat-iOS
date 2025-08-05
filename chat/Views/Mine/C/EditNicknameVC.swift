//
//  EditNicknameVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/25.
//

import UIKit
import SnapKit

enum EditTypeStyle: Int {
    case nickname = 1
    case alias = 2
}

class EditNicknameVC: UIViewController, ViewControllerProtocol {

    private let disposeBag = DisposeBag.init()
    
    private lazy var remarkBlockView : UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 5
        
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(7)
            m.height.equalTo(23)
        })
        view.addSubview(remarkNumLab)
        remarkNumLab.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(7)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(17)
        })
        view.addSubview(remarkInput)
        remarkInput.snp.makeConstraints({ (m) in
            m.left.equalTo(titleLab)
            m.right.equalToSuperview()
            m.bottom.equalToSuperview()
            m.height.equalTo(40)
        })
        return view
    }()
    
    private lazy var titleLab: UILabel = {
        let str = editType == .alias ? "备注" : "昵称"
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .left, text:str)
        return lab
    }()
    
    private lazy var remarkNumLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: Color_8A97A5, textAlignment: .right, text: "0/20")
        return lab
    }()
    
    private lazy var remarkInput : UITextField = {
        let input = UITextField()
        input.font = UIFont.systemFont(ofSize: 16)
        input.textColor = Color_24374E
        input.tintColor = Color_Theme
        let str = editType == .alias ? "请输入备注" : "请输入昵称"
        input.attributedPlaceholder = NSAttributedString(string: str, attributes: [.foregroundColor:Color_8A97A5])
        input.addToolBar(with: "确定", target: self, sel: #selector(commitInfo))
        return input
    }()
    
    private lazy var confirmBtn : UIButton = {
        let btn = UIButton.getNormalBtn(with: "确定")
        btn.layer.cornerRadius = 20
        return btn
    }()

    var placeholder: String?
    
    var compeletionBlcok: ((String)->())?
    
    var editType: EditTypeStyle = .alias
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = self.editType == .alias ? "修改备注" : "修改昵称"
        
        self.createUI()
    }
    
    private func createUI() {
        self.view.addSubview(remarkBlockView)
        remarkBlockView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(15)
            m.width.equalTo(k_ScreenWidth - 30.0)
            m.height.equalTo(80)
        }
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        self.view.addSubview(view)
        view.snp.makeConstraints { (m) in
            m.bottom.left.right.equalTo(self.view.safeArea)
            m.height.equalTo(70)
        }
        view.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth - 30 , height: 40))
        }
        
        confirmBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.commitInfo()
        }.disposed(by: disposeBag)
        
        remarkInput.rx.text.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.remarkInput.limitText(with: 20)
            if let text = strongSelf.remarkInput.text, text.count > 0 {
                strongSelf.remarkNumLab.text = "\(text.count)/20"
            }else {
                strongSelf.remarkNumLab.text = "0/20"
            }
        }.disposed(by: disposeBag)
                
        remarkInput.text = self.placeholder
        remarkNumLab.text = "\(remarkInput.text?.count ?? 0)/20"
    }
    
    @objc private func commitInfo() {
//        guard let name = remarkInput.text, name.count > 0 else { return }
        var name = remarkInput.text
        if name?.isBlank == true {
            name = ""
        }
        self.compeletionBlcok?(name!)
        self.navigationController?.popViewController(animated: true)
    }

}
