//
//  SearchUserVC.swift
//  chat
//
//  Created by 陈健 on 2021/1/14.
//

import UIKit
import SnapKit
import SwifterSwift
import SwiftyJSON

class SearchUserVC: UIViewController, ViewControllerProtocol {
    private let disposeBag = DisposeBag.init()
    
    private var listArr = [User]()
    
    private lazy var listView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_FAFBFC
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = UIView(frame: CGRect.zero)
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 50
        view.register(SearchUserCell.self, forCellReuseIdentifier: "SearchUserCell")
        view.separatorColor = Color_F1F4F6
        view.keyboardDismissMode = .onDrag
        return view
    }()
    
    private lazy var cancelBtn : UIButton = {
        let btn = UIButton()
        btn.setAttributedTitle(NSAttributedString(string: "取消", attributes: [.foregroundColor:Color_Theme,.font:UIFont.systemFont(ofSize: 16)]), for: .normal)
        btn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            self?.navigationController?.popViewController(animated: true)
        }.disposed(by: disposeBag)
        return btn
    }()
    
    private lazy var searchBlockView : UIView = {
        let view = UIView()
        view.layer.backgroundColor = Color_F1F4F6.cgColor
        view.layer.cornerRadius = 20
        view.tintColor = Color_8A97A5
        let imageV = UIImageView(image: UIImage.init(named: "tool_search")?.withRenderingMode(.alwaysTemplate))
        view.addSubview(imageV)
        imageV.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 17, height: 18))
        })
        view.addSubview(searchInput)
        searchInput.snp.makeConstraints({ (m) in
            m.top.bottom.right.equalToSuperview()
            m.left.equalTo(imageV.snp.right).offset(10)
        })
        return view
    }()
    
    private lazy var searchInput : UITextField = {
        let input = UITextField()
        input.tintColor = Color_Theme
        input.textAlignment = .left
        input.font = UIFont.systemFont(ofSize: 16)
        input.textColor = Color_24374E
        input.attributedPlaceholder = NSAttributedString(string: "输入用户账号", attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.systemFont(ofSize: 16)])
        input.returnKeyType = .search
        input.clearButtonMode = .whileEditing
        input.delegate = self
        return input
    }()
    
    lazy var headerView : UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 50))
        let tapa = UITapGestureRecognizer()
        tapa.rx.event.subscribe({[weak self] (_) in
            guard let self = self else { return }
            self.view.endEditing(true)
        }).disposed(by: disposeBag)
        view.addGestureRecognizer(tapa)
        
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_24374E, textAlignment: .center, text: nil)
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview().offset(-20)
            m.height.equalTo(50)
        })
        let imageView = UIImageView(image: #imageLiteral(resourceName: "icon_qrcode_gray"))
        view.addSubview(imageView)
        imageView.snp.makeConstraints({ (m) in
            m.centerY.equalTo(lab)
            m.left.equalTo(lab.snp.right).offset(10)
            m.width.height.equalTo(20)
        })
        if !LoginUser.shared().address.isEmpty {
            lab.text = "我的账号：\(LoginUser.shared().address.shortAddress)"
        }
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer()
        tap.rx.event.subscribe({[weak self] (_) in
            guard let self = self else { return }
            self.qrcodeClick()
        }).disposed(by: disposeBag)
        imageView.addGestureRecognizer(tap)
        return view
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: 246))
        var noDataView = FZMNoDataView(image: #imageLiteral(resourceName: "nodata_search"), imageSize: CGSize(width: 250, height: 200), desText: "没有匹配的对象", btnTitle: nil, clickBlock: nil)
        view.addSubview(noDataView)
        noDataView.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(65)
            m.left.right.equalToSuperview()
            m.height.equalTo(181)
        })
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xls_isNavigationBarHidden = true
        
        self.createUI()
    }
    
    private func createUI() {
        self.view.addSubview(cancelBtn)
        cancelBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview()
            m.width.equalTo(65)
            m.height.equalTo(40)
            m.top.equalToSuperview().offset(k_StatusBarHeight + 5)
        }
        self.view.addSubview(searchBlockView)
        searchBlockView.snp.makeConstraints { (m) in
            m.top.bottom.equalTo(cancelBtn)
            m.right.equalTo(cancelBtn.snp.left)
            m.left.equalToSuperview().offset(15)
        }
        self.view.addSubview(listView)
        listView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(searchBlockView.snp.bottom).offset(5)
        }
        listView.tableHeaderView = self.headerView
        
        searchInput.rx.text.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            if (strongSelf.searchInput.text?.isEmpty ?? false) && strongSelf.listArr.isEmpty {
                strongSelf.listView.tableFooterView = UIView(frame: CGRect.zero)
            }
        }.disposed(by: disposeBag)
        
        searchInput.becomeFirstResponder()
    }
    
    private func search(_ text: String) {
        listArr.removeAll()
        self.view.showActivity()
        
        // 判断搜索关键词是否为手机号或邮箱(手机号判断规则：1开头，11位，纯数字)，是则先获取对应的地址再去区块链上查用户信息，否则直接去区块链上查
        if text.isValidEmail || text.isDigits, text.count == 11, text.hasPrefix("1") {
            Provider.request(BackupAPI.getAddress(text)) { [weak self] (json) in
                guard let strongSelf = self else { return }
                let address = json["address"].stringValue
                strongSelf.getNetUser(with: address)
            } failureBlock: { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.getNetUser(with: text)
            }
        } else {
            self.getNetUser(with: text)
        }
    }
    
    // 去区块链查询用户信息
    private func getNetUser(with address: String) {
        UserManager.shared().getNetUser(targetAddress: address) { (user) in
            self.view.hideActivity()
            self.view.endEditing(true)
            self.listArr = [user]
            self.listView.tableFooterView = self.listArr.count == 0 ? self.footerView : UIView(frame: CGRect.zero)
            self.listView.reloadData()
        } failureBlock: { (error) in
            self.view.hideActivity()
            self.showToast("没有匹配对象")
        }
    }
    
    private func qrcodeClick() {
        self.view.endEditing(true)
        FZMUIMediator.shared().pushVC(.goQRCodeShow(type: .me))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}


extension SearchUserVC: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string == "\n", let text = self.searchInput.text, text.count > 0 {
            var isEmpty = true
            text.forEach { (c) in
                if c != " " && c != "\n" {
                    isEmpty = false
                }
            }
            if !isEmpty {
                self.search(text)
            }
            self.searchInput.endEditing(true)
            return false
        }
        return true
    }
}

extension SearchUserVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listArr.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: SearchUserCell.self, for: indexPath)
        guard listArr.count > indexPath.row else {
            return cell
        }
        let model = listArr[indexPath.row]
        let name = model.contactsName
        let avatar = model.avatarURLStr
        cell.configure(with: (name , avatar))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.view.endEditing(true)
        guard listArr.count > indexPath.row else {
            return
        }
        let user = listArr[indexPath.row]
        if user.isFriend {
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: SessionID.person(user.address)))
        } else {
            FZMUIMediator.shared().pushVC(.goUserDetailInfoVC(address: user.address, source: .search))
        }
    }
}
