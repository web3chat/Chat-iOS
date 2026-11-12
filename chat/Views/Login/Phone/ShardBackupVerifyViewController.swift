//
//  ShardBackupVerifyViewController.swift
//  chat
//
//  校验用户抄写的 s2 是否与本地分片一致（通过 recoverMnemonic 比对助记词）
//

import SnapKit
import UIKit

class ShardBackupVerifyViewController: UIViewController, ViewControllerProtocol {

    var s1: String = ""
    var s2: String = ""

    private lazy var titleLab: UILabel = {
        let l = UILabel()
        l.font = UIFont.boldSystemFont(ofSize: 30)
        l.textColor = Color_24374E
        l.text = L("验证您备份的分片秘钥")
        l.numberOfLines = 0
        return l
    }()

    private lazy var inputTextView: UITextView = {
        let t = UITextView()
        t.font = UIFont.systemFont(ofSize: 20)
        t.textColor = Color_24374E
        t.backgroundColor = UIColor(red: 0.9647, green: 0.9686, blue: 0.9725, alpha: 1)
        t.layer.cornerRadius = 5
        t.layer.masksToBounds = true
        t.isEditable = true
        t.isScrollEnabled = true
        t.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        t.textContainer.lineFragmentPadding = 0
        t.tintColor = Color_Theme
        return t
    }()

    private lazy var confirmBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        b.setTitle(L("确定"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = Color_Theme
        b.layer.cornerRadius = 20
        b.layer.masksToBounds = true
        b.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        xls_isNavigationBarHidden = false
        navigationItem.title = L("验证分片密钥")
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupCustomBackButton()
    }

    /// 使用系统 UIBarButtonItem（customView 会贴左、且 iOS 26 会被套玻璃胶囊）
    private func setupCustomBackButton() {
        let item = UIBarButtonItem(image: UIImage(named: "nav_back")?.withRenderingMode(.alwaysTemplate),
                                   style: .plain,
                                   target: self,
                                   action: #selector(backTapped))
        item.tintColor = Color_24374E
        navigationItem.leftBarButtonItem = item
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func setupLayout() {
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints { m in
            m.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            m.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            m.top.equalTo(view.safeAreaLayoutGuide).offset(12)
        }
        view.addSubview(inputTextView)
        inputTextView.snp.makeConstraints { m in
            m.left.right.equalTo(titleLab)
            m.top.equalTo(titleLab.snp.bottom).offset(24)
            m.height.greaterThanOrEqualTo(200)
        }
        view.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { m in
            m.left.right.equalTo(titleLab)
            m.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            m.height.equalTo(40)
        }
    }

    @objc private func confirmTapped() {
        view.endEditing(true)
        let input = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showToast(L("请输入密钥分片"))
            return
        }

        guard let recovered = SeedManager.recoverMnemonic(s1: s1, s2: input), !recovered.isEmpty else {
            showToast(L("密钥分片不正确"))
            return
        }
       
        navigationController?.dismiss(animated: true) {
            FZMUIMediator.shared().backToRootVC()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
