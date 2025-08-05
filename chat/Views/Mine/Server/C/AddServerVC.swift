//
//  SetServerVC.swift
//  chat
//
//  Created by 陈健 on 2021/2/25.
//

import UIKit
import RxSwift


class SetServerVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private let nameCountLab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .right, text: "0/15")
    
    private lazy var nameTextField: UITextField = {
        let input = UITextField()
        input.font = UIFont.systemFont(ofSize: 16)
        input.attributedPlaceholder = NSAttributedString(string: "请输入服务器名称", attributes: [.foregroundColor:Color_8A97A5, .font: UIFont.systemFont(ofSize: 16)])
        input.textColor = Color_24374E
        input.backgroundColor = Color_FAFBFC
        return input
    }()
    
    private lazy var nameView: UIView = {
        let v = UIView.init()
        v.makeOriginalShdowShow()
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: "服务器名称")
        v.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(5)
        }
        v.addSubview(nameCountLab)
        nameCountLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(5)
            m.right.equalToSuperview().offset(-15)
        }
        v.addSubview(nameTextField)
        nameTextField.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview()
            m.height.equalTo(50)
        }
        return v
    }()
    
    private lazy var valueTextField: UITextField = {
        let input = UITextField()
        input.font = UIFont.systemFont(ofSize: 16)
        input.attributedPlaceholder = NSAttributedString(string: "请输入域名", attributes: [.foregroundColor:Color_8A97A5, .font: UIFont.systemFont(ofSize: 16)])
        input.textColor = Color_24374E
        input.backgroundColor = Color_FAFBFC
        return input
    }()
    
    private lazy var valueView: UIView = {
        let v = UIView.init()
        v.makeOriginalShdowShow()
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: "域名")
        v.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(5)
        }
        
        v.addSubview(valueTextField)
        valueTextField.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview()
            m.height.equalTo(50)
        }
        return v
    }()
    
    private lazy var saveBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 50, height: 30)
        btn.setTitle("保存", for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        btn.backgroundColor = Color_C8D3DE
        btn.layer.cornerRadius = 15
        btn.layer.masksToBounds = true
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(saveBtnTouch), for: .touchUpInside)

        return btn
    }()
    
    private lazy var deleteBtn: UIButton = {
        let btn = UIButton.getNormalBtn(with: "删除", backgroundColor: Color_FAFBFC)
        btn.addTarget(self, action: #selector(deleteBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    var isHiddenDeleteBtn: Bool = false {
        didSet {
            self.deleteBtn.isHidden = isHiddenDeleteBtn
        }
    }
    
    var saveBlock: ((Server)->())?
    var deleteBlock: ((Server)->())?
    
    enum `Type` {
        case add
        case edit(Server)
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupViews()
        self.setRX()
    }
    
    private func setupViews() {
 
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem.init(customView: saveBtn)]
        
        self.view.addSubview(self.nameView)
        self.nameView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(10)
            m.height.equalTo(80)
        }
        
        self.view.addSubview(self.valueView)
        self.valueView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(self.nameView.snp.bottom).offset(15)
            m.height.equalTo(80)
        }
        
        self.view.addSubview(self.saveBtn)
        self.saveBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(self.valueView.snp.bottom).offset(15)
            m.height.equalTo(40)
        }
    }
    
    private func setRX() {
        let nameValid = self.nameTextField.rx.text.orEmpty.map { !$0.isEmpty }.share(replay: 1)
        let valueValid = self.valueTextField.rx.text.orEmpty.map { $0.isHttpURL || $0.isHttpsURL }
        Observable.combineLatest(nameValid, valueValid).map { $0 && $1 }.subscribe(onNext: {[weak self] (allValid) in
            self?.saveBtn.isEnabled = allValid
            self?.saveBtn.backgroundColor = allValid ? Color_32B2F7 : Color_C8D3DE
        }).disposed(by: self.bag)
        
        self.nameTextField.rx.text.orEmpty.subscribe(onNext: { (text) in
            self.nameTextField.limitText(with: 15)
            self.nameCountLab.text = "\(text.count)/15"
        }).disposed(by: self.bag)
    }

    @objc private func saveBtnTouch() {
        
    }
    
    @objc private func deleteBtnTouch() {
        
    }
}
