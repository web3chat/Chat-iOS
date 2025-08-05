//
//  SetServerVC.swift
//  chat
//
//  Created by 陈健 on 2021/2/25.
//

import UIKit
import SnapKit
import RxSwift


class SetServerVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private let nameCountLab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .right, text: "0/15")
    
    private lazy var nameTextField: UITextField = {
        let input = UITextField()
        input.font = UIFont.systemFont(ofSize: 16)
        input.attributedPlaceholder = NSAttributedString(string: "请输入服务器名称", attributes: [.foregroundColor:Color_8A97A5, .font: UIFont.systemFont(ofSize: 16)])
        input.textColor = Color_24374E
        input.backgroundColor = Color_F6F7F8
        if case .edit(let server) = self.type {
            input.text = server.name
        } else if case .add(let server) = self.type {
            input.text = server.name
        }
        return input
    }()
    
    private lazy var nameView: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_F6F7F8
        v.layer.cornerRadius = 5
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
        input.backgroundColor = Color_F6F7F8
        if case .edit(let server) = self.type {
            input.text = server.value
        } else if case .add(let server) = self.type {
            input.text = server.value
        }
        return input
    }()
    
    private lazy var valueView: UIView = {
        let v = UIView.init()
        v.backgroundColor = Color_F6F7F8
        v.layer.cornerRadius = 5
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: "域名")
        v.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(5)
        }
        
        v.addSubview(valueTextField)
        valueTextField.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-35)
            m.bottom.equalToSuperview()
            m.height.equalTo(50)
        }
        v.addSubview(arrowBtn)
        arrowBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 10, height: 6))
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview().offset(-22)
        }
        return v
    }()
    
    private lazy var arrowBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 10, height: 6)
        btn.setImage(UIImage.init(named: "arrow_down"), for: .normal)
        btn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))
        btn.addTarget(self, action: #selector(arrowBtnTouch), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    
    private lazy var deleteBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 50, height: 30)
        btn.setAttributedTitle(NSAttributedString(string: "删除", attributes: [.foregroundColor: Color_DD5F5F,.font:UIFont.systemFont(ofSize: 14)]), for: .normal)
        btn.layer.cornerRadius = 15
        btn.layer.masksToBounds = true
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(deleteBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    private lazy var saveBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("保存", for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.backgroundColor = Color_C8D3DE
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(saveBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    private lazy var tableView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_FAFBFC
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 60
        view.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        view.separatorColor = Color_F1F4F6
        return view
    }()
    
    private lazy var serverListView: UIView = {
        let v = UIView.init(frame: UIScreen.main.bounds)
        v.backgroundColor =  UIColor.init(white: 0, alpha: 0.2)
        
        let whiteView = UIView.init(frame: CGRect.init(x: 0, y: k_ScreenHeight - 400, width: k_ScreenWidth, height: 400))
        whiteView.backgroundColor = Color_FAFBFC
        whiteView.roundCorners([.topLeft, .topRight], radius: 20)
        v.addSubview(whiteView)
        
        
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_Theme, textAlignment: .center, text: "添加记录")
        whiteView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(13)
            m.height.equalTo(24)
        }
        
        let cancelBtn = UIButton.init(type: .custom)
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.setTitleColor(Color_8A97A5, for: .normal)
        cancelBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        cancelBtn.addTarget(self, action: #selector(hideServerListView), for: .touchUpInside)
        
        whiteView.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints { (m) in
            m.centerY.equalTo(lab)
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize.init(width: 35, height: 20))
        }
        
        whiteView.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.top.equalToSuperview().offset(50)
        }
        return v
    }()
    
    var dataSource = [Server]() {
        didSet {
            self.arrowBtn.isHidden = false
            self.tableView.reloadData()
        }
    }
    
    var saveBlock: ((Server)->())?
    
    var deleteBlock: ((Server)->())?
    
    enum SetType {
        case addNewIMServer
        case addNewBlockchain
        case edit(Server)
        case add(Server)
    }
    
    let type: SetType
    
    init(type: SetType) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
        if case .add = type {
            self.title = "添加服务器"
        } else if case .addNewIMServer = type {
            self.title = "添加聊天服务器"
        } else if case .addNewBlockchain = type {
            self.title = "添加区块链节点"
        } else {
            self.title = "编辑服务器"
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupViews()
        self.setRX()
    }
    
    private func setupViews() {
        
        switch type {
        case .edit:
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem.init(customView: deleteBtn)]
        default:
            self.navigationItem.rightBarButtonItems = []
        }
        
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
            m.top.equalTo(self.valueView.snp.bottom).offset(30)
            m.height.equalTo(40)
        }
    }
    
    private func setRX() {
        let nameValid = self.nameTextField.rx.text.orEmpty.map { !$0.isEmpty }.share(replay: 1)
        let valueValid = self.valueTextField.rx.text.orEmpty.map { $0.contains("https://") || $0.contains("http://") }
        Observable.combineLatest(nameValid, valueValid).map { $0 && $1 }.subscribe(onNext: {[weak self] (allValid) in
            self?.saveBtn.isEnabled = allValid
            self?.saveBtn.backgroundColor = allValid ? Color_Theme : Color_C8D3DE
        }).disposed(by: self.bag)
        
        self.nameTextField.rx.text.orEmpty.subscribe(onNext: { (text) in
            self.nameTextField.limitText(with: 15)
            self.nameCountLab.text = "\(text.count)/15"
        }).disposed(by: self.bag)
    }
    
    @objc private func saveBtnTouch() {
        guard let name = self.nameTextField.text, let value = self.valueTextField.text else {
            return
        }
        var server = Server.init(name: name, value: value)
        if case .edit(let editServer) = self.type {
            server.id = editServer.id
        }
        self.saveBlock?(server)
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func deleteBtnTouch() {
        guard case .edit(let server) = self.type else { return }
        self.deleteBlock?(server)
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func arrowBtnTouch() {
        self.view.endEditing(true)
        UIApplication.shared.keyWindow?.addSubview(self.serverListView)
        
    }
    
    @objc private func hideServerListView() {
        self.serverListView.removeFromSuperview()
    }
}

extension SetServerVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        cell.backgroundColor = Color_FAFBFC
        guard dataSource.count > indexPath.row else {
            return cell
        }
        let server = dataSource[indexPath.row]
        let att = NSMutableAttributedString.init(string: server.name, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16),NSAttributedString.Key.foregroundColor : Color_24374E])
        att.append(NSAttributedString.init(string: "\n\(server.value)", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14),NSAttributedString.Key.foregroundColor : Color_8A97A5]))
        cell.textLabel?.attributedText = att
        cell.textLabel?.numberOfLines = 0
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.hideServerListView()
        guard indexPath.row < self.dataSource.count else { return }
        let server = self.dataSource[indexPath.row]
        self.nameTextField.text = server.name
        self.valueTextField.text = server.value
        self.nameTextField.sendActions(for: .allEditingEvents)
        self.valueTextField.sendActions(for: .allEditingEvents)
        tableView.cellForRow(at: indexPath)?.isSelected = false
    }
}
