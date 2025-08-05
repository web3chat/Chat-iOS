//
//  FZMFileSearchController.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/22.
//

import Foundation

class FZMFileSearchController: FZMFileViewController {
    
    lazy var searchBlockView : UIView = {
        let view = UIView.init()
        view.layer.backgroundColor = Color_F1F4F6.cgColor
        view.layer.cornerRadius = 20
        view.tintColor = Color_8A97A5
        let imageV = UIImageView(image: #imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysTemplate))
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
    
    lazy var searchInput: UITextField = {
        let input = UITextField.init()
        input.tintColor = Color_Theme
        input.textAlignment = .left
        input.font = UIFont.regularFont(16)
        input.textColor = Color_24374E
        input.attributedPlaceholder = NSAttributedString(string: "文件名", attributes: [.foregroundColor:Color_8A97A5,.font:UIFont.regularFont(16)])// 文件名/上传者
        input.returnKeyType = .search
        input.delegate = self
        return input
    }()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchInput.becomeFirstResponder()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let selectBtn = UIBarButtonItem.init(title: "选择", style: .done, target: self, action: #selector(selectFileOrCancel))
        self.navigationItem.rightBarButtonItems = [selectBtn]
    }
    
    override func createUI() {
        
        let titleView = IntrinsicView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 40))
        self.navigationItem.titleView = titleView
        titleView.addSubview(searchBlockView)
        searchBlockView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.centerX.equalToSuperview().offset(-10)
            m.width.equalTo(280)
            m.height.equalTo(40)
        }
        
        self.view1 = FZMFileListView.init(with: "", session: self.session)
        if let view1 = self.view1 {
            let param = FZMSegementParam()
            param.headerHeight = 0
            let pageView = FZMScrollPageView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight-k_StatusNavigationBarHeight), dataViews: [view1], param: param)
            self.view.addSubview(pageView)
        }
    }
}

extension FZMFileSearchController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string == "\n", let text = self.searchInput.text, text.count > 0 {
            var isEmpty = true
            text.forEach { (c) in
                if c != " " && c != "\n" {
                    isEmpty = false
                }
            }
            if !isEmpty {
                self.search(self.searchInput.text!)
            }
            self.searchInput.endEditing(true)
            return false
        }
        return true
    }
    
    private func search(_ text: String) {
        self.view1?.searchText = text
    }
}

class IntrinsicView: UIView {
    override var intrinsicContentSize: CGSize {
        get {
            return CGSize.init(width: 280, height: 40)
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
