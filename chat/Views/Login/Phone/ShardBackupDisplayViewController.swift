//
//  ShardBackupDisplayViewController.swift
//  chat
//
//  首次备份：展示第二段分片 s2，引导用户抄写后进入校验页
//

import SnapKit
import UIKit

class ShardBackupDisplayViewController: UIViewController, ViewControllerProtocol {

    var s1: String = ""
    var s2: String = ""

    private lazy var titleLab: UILabel = {
        let l = UILabel()
        l.font = UIFont.boldSystemFont(ofSize: 30)
        l.textColor = Color_24374E
        l.text = L("备份分片秘钥")
        return l
    }()

    private lazy var tipLab: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14)
        l.textColor = Color_8A97A5
        l.numberOfLines = 0
        l.text = L("请妥善保管第二段密钥分片，以便于解决本机不慎发生故障或遗失之后不能登录的问题。请勿截图 ,请抄写下密钥分片并存放在安全的地方，我们会在下一屏进行校验。")
        return l
    }()

    private lazy var s2TextView: UITextView = {
        let t = UITextView()
        t.font = UIFont.systemFont(ofSize: 20)
        t.textColor = Color_24374E
        t.backgroundColor = UIColor(red: 0.9647, green: 0.9686, blue: 0.9725, alpha: 1)
        t.layer.cornerRadius = 5
        t.layer.masksToBounds = true
        t.isEditable = false
        t.isSelectable = true
        t.isScrollEnabled = true
        t.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        t.textContainer.lineFragmentPadding = 0
        return t
    }()

    private lazy var nextBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        b.setTitle(L("下一步"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = Color_Theme
        b.layer.cornerRadius = 20
        b.layer.masksToBounds = true
        b.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        xls_isNavigationBarHidden = false
        navigationItem.title = L("备份密钥分片")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L("跳过"),
            style: .plain,
            target: self,
            action: #selector(skipTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = Color_Theme
        s2TextView.text = s2
        setupLayout()
    }

    private func setupLayout() {
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints { m in
            m.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            m.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            m.top.equalTo(view.safeAreaLayoutGuide).offset(12)
        }
        view.addSubview(tipLab)
        tipLab.snp.makeConstraints { m in
            m.left.right.equalTo(titleLab)
            m.top.equalTo(titleLab.snp.bottom).offset(12)
        }
        view.addSubview(s2TextView)
        s2TextView.snp.makeConstraints { m in
            m.left.right.equalTo(titleLab)
            m.top.equalTo(tipLab.snp.bottom).offset(20)
            m.height.greaterThanOrEqualTo(200)
        }
        view.addSubview(nextBtn)
        nextBtn.snp.makeConstraints { m in
            m.left.right.equalTo(titleLab)
            m.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            m.height.equalTo(40)
        }
    }

    @objc private func skipTapped() {
        navigationController?.dismiss(animated: true)
    }

    @objc private func nextTapped() {
        let vc = ShardBackupVerifyViewController()
        vc.s1 = s1
        vc.s2 = s2
        navigationController?.pushViewController(vc, animated: true)
    }
}
