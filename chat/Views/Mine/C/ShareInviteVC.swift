//
//  ShareInviteVC.swift
//  chat
//
//  「分享邀请」页面（2026-10-19）：
//  - 不再进入「我的二维码」页面，改为展示 TestFlight 下载链接 + 二维码；
//  - 点击链接 / 扫码都会用系统默认浏览器打开 TestFlight 参与链接去下载。
//

import UIKit
import SnapKit

class ShareInviteVC: UIViewController, ViewControllerProtocol {

    /// 邀请链接（TestFlight）
    private let inviteLink = TESTFLIGHT_DOWNLOAD_URL

    private lazy var cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var qrImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = QRCodeGenerator.setupQRCodeImage(self.inviteLink, image: #imageLiteral(resourceName: "logo_120"))
        return imageView
    }()

    // 下载地址不展示，只保留二维码 + 下方两个按钮（用户 2026-10-19 要求）
    private lazy var tipLabel: UILabel = {
        let label = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .center, text: L("扫描二维码，或点击下方按钮，使用默认浏览器打开下载"))
        label.numberOfLines = 0
        return label
    }()

    // 复制下载地址
    private lazy var copyButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Color_Auxiliary
        btn.setTitle(L("复制下载地址"), for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        btn.layer.cornerRadius = 22
        btn.addTarget(self, action: #selector(copyDownloadLink), for: .touchUpInside)
        return btn
    }()

    // 点击下载（默认浏览器打开）
    private lazy var goButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Color_Theme
        btn.setTitle(L("点击下载"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        btn.layer.cornerRadius = 22
        btn.addTarget(self, action: #selector(openDownloadLink), for: .touchUpInside)
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L("分享邀请")
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8

        self.setupUI()
    }

    private func setupUI() {
        self.view.addSubview(self.cardView)
        self.cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        self.cardView.addSubview(self.qrImageView)
        self.qrImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.centerX.equalToSuperview()
            make.size.equalTo(200)
        }

        self.cardView.addSubview(self.tipLabel)
        self.tipLabel.snp.makeConstraints { make in
            make.top.equalTo(self.qrImageView.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        self.cardView.addSubview(self.copyButton)
        self.copyButton.snp.makeConstraints { make in
            make.top.equalTo(self.tipLabel.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(16)
            make.height.equalTo(44)
        }

        self.cardView.addSubview(self.goButton)
        self.goButton.snp.makeConstraints { make in
            make.top.equalTo(self.copyButton)
            make.left.equalTo(self.copyButton.snp.right).offset(12)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(self.copyButton)
            make.width.equalTo(self.copyButton)
            make.bottom.equalToSuperview().offset(-30)
        }
    }

    /// 复制下载地址
    @objc private func copyDownloadLink() {
        UIPasteboard.general.string = self.inviteLink
        self.showToast(L("应用下载地址已复制"))
    }

    /// 点击链接：用系统默认浏览器打开（→ TestFlight 下载页）
    @objc private func openDownloadLink() {
        guard let url = URL(string: self.inviteLink) else { return }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard let self = self, !success else { return }
            // 打不开时兜底：复制链接，方便手动粘贴到浏览器
            UIPasteboard.general.string = self.inviteLink
            self.showToast(L("应用下载地址已复制"))
        }
    }
}
