//
//  SquareOfficialVC.swift
//  chat
//
//  我的公众号：五态展示（none / pending / approved / rejected / banned）+ 申请表单
//

import Foundation
import UIKit
import ImageIO
import SnapKit
import RxSwift
import Kingfisher

final class SquareOfficialVC: UIViewController, ViewControllerProtocol {

    private let bag = DisposeBag()

    private var me: SquareOfficialMe?
    private var avatarURL = ""
    private var isSubmitting = false
    /// 已通过的公众号是否处于「修改资料」模式
    private var isEditingProfile = false
    /// 简介区参与卡片高度（申请模式）；修改资料模式下用 nameBottomConstraint 收尾
    private var introBottomConstraint: SnapKit.Constraint?
    private var nameBottomConstraint: SnapKit.Constraint?

    // MARK: - 子视图

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = Color_F6F7F8
        view.showsVerticalScrollIndicator = false
        view.keyboardDismissMode = .onDrag
        return view
    }()

    private lazy var contentView: UIView = {
        return UIView()
    }()

    /// 状态卡（审核中 / 已通过 / 已封禁 等状态说明）
    private lazy var stateCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.addSubview(stateLab)
        view.addSubview(stateDesLab)
        stateLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(15)
        }
        stateDesLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(stateLab.snp.bottom).offset(8)
            m.bottom.equalToSuperview().offset(-15)
        }
        return view
    }()

    private lazy var stateLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()

    private lazy var stateDesLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()

    /// 申请表单卡
    private lazy var formCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true

        let avatarLab = UILabel.getLab(font: .regularFont(14), textColor: Color_24374E, textAlignment: .left, text: L("头像（选填）"))
        view.addSubview(avatarLab)
        view.addSubview(avatarView)
        view.addSubview(avatarDeleteBtn)
        view.addSubview(nameLab)
        view.addSubview(nameField)
        view.addSubview(nameCountLab)
        view.addSubview(introLab)
        view.addSubview(introField)
        view.addSubview(introCountLab)

        avatarLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(15)
            m.height.equalTo(20)
        }
        avatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(avatarLab.snp.bottom).offset(10)
            m.size.equalTo(CGSize(width: SquareOfficialVC.avatarSide, height: SquareOfficialVC.avatarSide))
        }
        // 删除按钮：与发帖页已选图片格子一致，压在缩略图右上角
        avatarDeleteBtn.snp.makeConstraints { (m) in
            m.right.equalTo(avatarView.snp.right).offset(2)
            m.top.equalTo(avatarView.snp.top).offset(-2)
            m.size.equalTo(CGSize(width: 18, height: 18))
        }
        nameLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(avatarView.snp.bottom).offset(15)
            m.height.equalTo(20)
        }
        nameCountLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(nameLab)
        }
        nameField.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(nameLab.snp.bottom).offset(8)
            m.height.equalTo(44)
        }
        introLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(nameField.snp.bottom).offset(15)
            m.height.equalTo(20)
        }
        introCountLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(introLab)
        }
        introField.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(introLab.snp.bottom).offset(8)
            m.height.equalTo(80)
            introBottomConstraint = m.bottom.equalToSuperview().offset(-15).constraint
        }
        // 修改资料时不展示简介（对接文档 §6.12 只支持改名称与头像），卡片高度收到名称输入框下面
        nameBottomConstraint = nameField.snp.prepareConstraints { (m) in
            m.bottom.equalToSuperview().offset(-15)
        }.first
        return view
    }()

    /// 选图区边长（与发帖页已选图片格子同风格的方形缩略图）
    private static let avatarSide: CGFloat = 72

    /// 已选头像：方形缩略图，右上角带删除按钮（与发帖页选图一致）
    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.backgroundColor = Color_F6F7F8
        view.layer.borderWidth = 0.5
        view.layer.borderColor = Color_E6EAEE.cgColor
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTap)))
        return view
    }()

    /// 已选头像的删除按钮（与发帖页格子上的删除按钮样式一致）
    private lazy var avatarDeleteBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(UIImage.init(systemName: "xmark.circle.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_FFFFFF
        btn.backgroundColor = UIColor.init(white: 0, alpha: 0.4)
        btn.layer.cornerRadius = 9
        btn.clipsToBounds = true
        btn.isHidden = true
        btn.addTarget(self, action: #selector(avatarDeleteTap), for: .touchUpInside)
        return btn
    }()

    private lazy var nameLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_24374E, textAlignment: .left, text: L("公众号名称"))
    }()

    private lazy var nameField: UITextField = {
        let view = UITextField()
        view.font = .regularFont(15)
        view.textColor = Color_24374E
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 6
        view.leftView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 10, height: 1))
        view.leftViewMode = .always
        view.attributedPlaceholder = NSAttributedString.init(string: L("请输入名称"),
                                                            attributes: [.foregroundColor: Color_8A97A5, .font: UIFont.regularFont(15)])
        return view
    }()

    private lazy var nameCountLab: UILabel = {
        return UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .right, text: "0/\(SquareLimits.maxOfficialNameLength)")
    }()

    private lazy var introLab: UILabel = {
        return UILabel.getLab(font: .regularFont(14), textColor: Color_24374E, textAlignment: .left, text: L("简介（选填）"))
    }()

    private lazy var introField: UITextView = {
        let view = UITextView()
        view.font = .regularFont(15)
        view.textColor = Color_24374E
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 6
        view.textContainerInset = UIEdgeInsets.init(top: 10, left: 6, bottom: 10, right: 6)
        // 输入框不需要滚动条（横向的会显示成输入框底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        return view
    }()

    private lazy var introCountLab: UILabel = {
        return UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .right, text: "0/\(SquareLimits.maxOfficialIntroLength)")
    }()

    private lazy var submitBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("提交申请"), for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.titleLabel?.font = .mediumFont(16)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(submitTap), for: .touchUpInside)
        return btn
    }()

    /// 「修改资料」入口（仅已通过、且后端接口就绪时展示）
    private lazy var editProfileBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("修改资料"), for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .mediumFont(16)
        btn.backgroundColor = Color_FFFFFF
        btn.layer.cornerRadius = 20
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.addTarget(self, action: #selector(editProfileTap), for: .touchUpInside)
        return btn
    }()

    private lazy var infoCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.addSubview(infoAvatarView)
        view.addSubview(infoNameLab)
        view.addSubview(infoIntroLab)

        infoAvatarView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 56, height: 56))
            m.bottom.lessThanOrEqualToSuperview().offset(-15)
        }
        infoNameLab.snp.makeConstraints { (m) in
            m.left.equalTo(infoAvatarView.snp.right).offset(12)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(infoAvatarView.snp.top).offset(4)
        }
        infoIntroLab.snp.makeConstraints { (m) in
            m.left.equalTo(infoNameLab)
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(infoNameLab.snp.bottom).offset(6)
            m.bottom.equalToSuperview().offset(-15)
        }
        return view
    }()

    private lazy var infoAvatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 28
        view.backgroundColor = Color_F6F7F8
        return view
    }()

    private lazy var infoNameLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(16), textColor: Color_24374E, textAlignment: .left, text: nil)
    }()

    private lazy var infoIntroLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()

    /// 垂直堆叠容器：stateCard / formCard / infoCard / editProfileBtn / submitBtn（隐藏项自动收起，避免手写约束冲突）
    private lazy var stackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [stateCard, formCard, infoCard, editProfileBtn, submitBtn])
        view.axis = .vertical
        view.spacing = 12
        view.alignment = .fill
        return view
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_F6F7F8
        self.navigationItem.title = L("我的公众号")
        self.xls_navigationBarBackgroundColor = Color_FFFFFF

        setupViews()
        setRX()
        applyAvatarPlaceholder()
        applyData()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏白底、去掉滚动时出现的底部细线
        applySquareNavBarStyle()
    }

    private func setupViews() {
        self.view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        scrollView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        contentView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
            m.width.equalToSuperview()
        }
        stackView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(15)
            m.bottom.equalToSuperview().offset(-20)
        }
        // 提交按钮高度（已在 stackView 内，可直接约束自身高度）
        submitBtn.snp.makeConstraints { (m) in
            m.height.equalTo(40)
        }
        editProfileBtn.snp.makeConstraints { (m) in
            m.height.equalTo(40)
        }
    }

    private func setRX() {
        nameField.rx.text.orEmpty.subscribe(onNext: { [weak self] text in
            guard let self = self else { return }
            self.nameField.limitText(with: SquareLimits.maxOfficialNameLength)
            self.nameCountLab.text = "\(self.nameField.text?.count ?? 0)/\(SquareLimits.maxOfficialNameLength)"
            self.updateSubmitState()
        }).disposed(by: bag)

        introField.rx.didChange.subscribe(onNext: { [weak self] in
            guard let self = self else { return }
            if self.introField.text.count > SquareLimits.maxOfficialIntroLength {
                self.introField.text = String(self.introField.text.prefix(SquareLimits.maxOfficialIntroLength))
            }
            self.introCountLab.text = "\(self.introField.text.count)/\(SquareLimits.maxOfficialIntroLength)"
        }).disposed(by: bag)
    }

    private func updateSubmitState() {
        let valid = !(nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
        submitBtn.isEnabled = valid
        submitBtn.backgroundColor = valid ? Color_Theme : Color_CCD1E0
    }

    // MARK: - 数据

    private func loadData() {
        self.showProgress()
        SquareService.shared.officialMe(success: { [weak self] me in
            guard let self = self else { return }
            self.hideProgress()
            self.me = me
            self.applyData()
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.hideProgress()
            self.showToast(with: failure.message)
        })
    }

    private func applyData() {
        guard let me = me else { return }

        // 表单回填：改资料时用当前已生效的资料
        if isEditingProfile, let official = me.official {
            nameField.text = official.name
            introField.text = official.intro
            avatarURL = official.avatar
            applyRemoteAvatar(official.avatar)
        } else if let apply = me.apply {
            nameField.text = apply.name
        }
        nameCountLab.text = "\(nameField.text?.count ?? 0)/\(SquareLimits.maxOfficialNameLength)"
        introCountLab.text = "\(introField.text.count)/\(SquareLimits.maxOfficialIntroLength)"

        // 状态文案
        switch me.state {
        case .none:
            stateLab.text = L("尚未申请公众号")
            stateDesLab.text = L("填写名称与简介提交申请，通过后可用公众号身份发帖")
        case .pending:
            stateLab.text = L("审核中")
            stateDesLab.text = L("申请已提交，请耐心等待运营审核")
        case .rejected:
            stateLab.text = L("申请未通过")
            stateDesLab.text = me.apply?.remark.isEmpty == false ? (me.apply?.remark ?? "") : L("可修改名称与简介后重新提交")
        case .approved:
            stateLab.text = L("已通过")
            stateDesLab.text = L("你的公众号已生效，发帖将展示公众号名称")
        case .banned:
            stateLab.text = L("已封禁")
            stateDesLab.text = L("公众号已被封禁，如需恢复请联系运营")
        case .unknown:
            stateLab.text = L("状态未知")
            stateDesLab.text = L("请稍后重试")
        }

        // 公众号信息卡（已通过 / 已封禁时展示）
        if let official = me.official {
            infoNameLab.text = official.name
            infoIntroLab.text = official.intro
            infoAvatarView.kf.setImage(with: URL.init(string: official.avatar), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
        }

        refreshLayout()
    }

    private func refreshLayout() {
        let loaded = me != nil
        let canApply = me?.state.canApply ?? false
        let hasOfficial = me?.official != nil
        // 已通过的公众号可改资料（后端接口就绪后把开关打开即可）
        let canEditProfile = (me?.state.isApproved ?? false) && SquareOfficialAPI.supportsProfileUpdate
        let showForm = canApply || isEditingProfile

        stateCard.isHidden = !loaded
        formCard.isHidden = !showForm
        infoCard.isHidden = !hasOfficial
        editProfileBtn.isHidden = !canEditProfile
        editProfileBtn.setTitle(isEditingProfile ? L("取消修改") : L("修改资料"), for: .normal)
        submitBtn.isHidden = !showForm
        submitBtn.setTitle(isEditingProfile ? L("提交修改") : L("提交申请"), for: .normal)

        // 修改资料只改名称与头像：隐藏简介区，卡片高度收到名称输入框下面
        introLab.isHidden = isEditingProfile
        introField.isHidden = isEditingProfile
        introCountLab.isHidden = isEditingProfile
        if isEditingProfile {
            introBottomConstraint?.deactivate()
            nameBottomConstraint?.activate()
        } else {
            nameBottomConstraint?.deactivate()
            introBottomConstraint?.activate()
        }

        updateSubmitState()
    }

    // MARK: - 交互

    // MARK: - 头像

    /// 空态：小加号（不能设成 .scaleAspectFill，否则 72pt 的 SF 符号会被拉得很大）
    private func applyAvatarPlaceholder() {
        let config = UIImage.SymbolConfiguration.init(pointSize: 22, weight: .light)
        avatarView.contentMode = .center
        avatarView.image = UIImage.init(systemName: "plus", withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
        avatarView.tintColor = Color_C8D3DE
        avatarDeleteBtn.isHidden = true
    }

    /// 已选图：与发帖页格子一致，方形铺满 + 右上角删除按钮
    private func applyAvatarImage(_ image: UIImage) {
        avatarView.contentMode = .scaleAspectFill
        avatarView.image = image
        avatarDeleteBtn.isHidden = false
    }

    /// 展示已有的公众号头像（远程地址）
    private func applyRemoteAvatar(_ url: String) {
        let placeholder = #imageLiteral(resourceName: "friend_chat_avatar")
        guard !url.isEmpty, let link = URL.init(string: url) else {
            applyAvatarPlaceholder()
            return
        }
        avatarView.contentMode = .scaleAspectFill
        avatarView.kf.setImage(with: link, placeholder: placeholder)
        avatarDeleteBtn.isHidden = false
    }

    @objc private func avatarTap() {
        self.view.endEditing(true)
        // 与聊天/发帖一致的系统相册选择器
        SystemMediaPicker.shared.present(from: self, maxCount: 1, imagesOnly: true) { [weak self] results in
            guard let self = self else { return }
            let image = results.first(where: { $0.mediaType == .image })?.image
                ?? results.compactMap { $0.mediaType == .gif ? $0.gifData : nil }.compactMap { SquareOfficialVC.firstFrame(of: $0) }.first
            guard let image = image else { return }

            self.applyAvatarImage(image)
            // 上传中先隐藏删除按钮，避免把正在上传的图删掉后结果又回来
            self.avatarDeleteBtn.isHidden = true
            self.avatarURL = ""
            self.showProgress(with: L("上传中..."))
            _ = SquareService.shared.uploadImages([image], progress: nil, success: { [weak self] urls in
                guard let self = self else { return }
                self.hideProgress()
                self.avatarURL = urls.first ?? ""
                self.avatarDeleteBtn.isHidden = self.avatarURL.isEmpty
            }, failure: { [weak self] failure in
                guard let self = self else { return }
                self.hideProgress()
                self.avatarURL = ""
                self.applyAvatarPlaceholder()
                self.showToast(with: failure.message)
            })
        }
    }

    /// 移除已选头像
    @objc private func avatarDeleteTap() {
        avatarURL = ""
        applyAvatarPlaceholder()
    }

    /// GIF 取第一帧（上传时会统一压缩成 JPEG）
    private static func firstFrame(of gifData: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(gifData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage.init(cgImage: cgImage)
    }

    @objc private func submitTap() {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            self.showToast(with: L("请输入公众号名称"))
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        updateSubmitState()
        self.showProgress()

        let intro = introField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatar = avatarURL.isEmpty ? nil : avatarURL
        let success: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.isSubmitting = false
            self.hideProgress()
            self.showToast(with: L("已提交，等待审核"))
            self.isEditingProfile = false
            self.loadData()
        }
        let failure: (SquareFailure) -> Void = { [weak self] failure in
            guard let self = self else { return }
            self.isSubmitting = false
            self.hideProgress()
            // 资料修改接口还没上线时给个明确提示，而不是甩一个网络错误
            if self.isEditingProfile, failure.isEndpointMissing {
                self.showToast(with: L("资料修改接口未开放，请稍后重试"))
                return
            }
            self.showToast(with: failure.message)
            if failure.code == .applyPending {
                // 已有待审申请，刷新成 pending 态
                self.loadData()
            }
        }

        if isEditingProfile {
            // 修改资料：仅名称 + 头像（对接文档 §6.12），改完立即生效
            SquareService.shared.officialUpdate(name: name,
                                                avatar: avatarURL,
                                                success: { [weak self] profile in
                guard let self = self else { return }
                self.isSubmitting = false
                self.hideProgress()
                self.showToast(with: L("资料已更新"))
                self.isEditingProfile = false
                // 本地先更新，再拉一次服务端数据（昵称改了以后历史公众号帖展示名也会同步）
                if !profile.name.isEmpty, var official = self.me?.official {
                    official.name = profile.name
                    official.avatar = profile.avatar
                    self.me?.official = official
                }
                self.applyData()
                self.loadData()
            }, failure: failure)
        } else {
            SquareService.shared.officialApply(name: name,
                                               avatar: avatar,
                                               intro: intro.isEmpty ? nil : intro,
                                               success: { _ in success() },
                                               failure: failure)
        }
    }

    /// 已通过的公众号：进入 / 退出「修改资料」（表单用当前资料回填）
    @objc private func editProfileTap() {
        guard let me = me, me.state.isApproved else { return }
        self.view.endEditing(true)
        isEditingProfile = !isEditingProfile

        if isEditingProfile, let official = me.official {
            nameField.text = official.name
            introField.text = official.intro
            nameCountLab.text = "\(nameField.text?.count ?? 0)/\(SquareLimits.maxOfficialNameLength)"
            introCountLab.text = "\(introField.text.count)/\(SquareLimits.maxOfficialIntroLength)"
            avatarURL = official.avatar
            applyRemoteAvatar(official.avatar)
        }
        refreshLayout()
    }
}
