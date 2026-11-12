//
//  SquareReportVC.swift
//  chat
//
//  举报页（《App增量-关注热门举报流量》§4 的独立落地页）：
//    ① 被举报内容摘要（作者 + 正文前 60 字）—— 让用户确认举报对象；
//    ② 举报类型：点一下弹底部选择框选（与长按图片那个菜单同一个组件）；
//    ③ 举报理由（选填，最多 500 字，实时字数）；
//    ④ 底部「提交举报」—— 键盘弹起时这份按钮会同时出现在键盘上方（`inputAccessoryView`，与评论输入条同一套）。
//
//  接口：POST /square/app/posts/:id/report
//  ⚠️ 同一地址对同一帖只能举报一次（服务端 -20410「已举报过该内容」）；举报**不会**立刻藏帖，
//     所以提交成功后只返回上一页，不刷新列表。
//

import Foundation
import UIKit
import SnapKit

final class SquareReportVC: UIViewController, ViewControllerProtocol {

    /// 举报成功回调（调用方可以收起举报入口 / 记一次本地标记）
    var onReported: (() -> Void)?

    /// 被举报的帖（列表页 / 详情页传进来的那份）
    private let post: SquarePost
    /// 当前选中的举报类型（**不默认选中**：点「举报类型」那行弹底部选择框选）
    private var reason: SquareReportReason?
    /// 防重复提交
    private var isSubmitting = false

    private let sideInset: CGFloat = 15

    // MARK: - 入口

    /// 打开举报页：有导航栈就 push（可侧滑返回），没有就包一层导航栏模态呈现
    /// - Parameter onReported: 举报成功后回调
    static func present(from viewController: UIViewController,
                        post: SquarePost,
                        onReported: (() -> Void)? = nil) {
        guard post.id > 0 else { return }
        let vc = SquareReportVC.init(post: post)
        vc.onReported = onReported
        vc.hidesBottomBarWhenPushed = true
        if let nav = viewController.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController.init(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            viewController.present(nav, animated: true)
        }
    }

    private init(post: SquarePost) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 子视图

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = Color_F6F7F8
        view.showsVerticalScrollIndicator = false
        // 点空白处收键盘（IQKeyboardManager 的 shouldResignOnTouchOutside 在工程里是开的，这里再兜一层）
        view.keyboardDismissMode = .onDrag
        return view
    }()

    private lazy var contentView: UIView = {
        return UIView()
    }()

    private lazy var stackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [targetCard, reasonCard, detailCard, submitBtn])
        view.axis = .vertical
        view.spacing = 12
        view.alignment = .fill
        return view
    }()

    // ① 被举报内容

    private lazy var targetCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    private lazy var targetTitleLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(15), textColor: Color_24374E, textAlignment: .left, text: L("被举报内容"))
    }()

    private lazy var targetContentLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")
        lab.numberOfLines = 2
        return lab
    }()

    // ② 举报类型

    private lazy var reasonCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    /// 左侧标题「举报类型」
    private lazy var reasonTitleLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(15), textColor: Color_24374E, textAlignment: .left, text: L("举报类型"))
    }()

    /// 右侧当前选中的类型（未选时是灰色占位文案）
    private lazy var reasonValueLab: UILabel = {
        return UILabel.getLab(font: .regularFont(15), textColor: Color_8A97A5, textAlignment: .right, text: L("请选择"))
    }()

    private lazy var reasonArrow: UIImageView = {
        let view = UIImageView.init(image: UIImage.init(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate))
        view.tintColor = Color_8A97A5
        view.contentMode = .scaleAspectFit
        return view
    }()

    /// 铺满整张卡片的透明按钮：点一下弹「举报类型」底部选择框
    private lazy var reasonTapBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.backgroundColor = .clear
        btn.addTarget(self, action: #selector(pickReason), for: .touchUpInside)
        return btn
    }()

    // ③ 举报理由

    private lazy var detailCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    private lazy var detailTitleLab: UILabel = {
        return UILabel.getLab(font: .mediumFont(15), textColor: Color_24374E, textAlignment: .left, text: L("举报理由"))
    }()

    private lazy var detailHintLab: UILabel = {
        return UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .right, text: L("选填，最多500字"))
    }()

    private lazy var detailTextView: UITextView = {
        let view = UITextView()
        view.font = .regularFont(15)
        view.textColor = Color_24374E
        view.tintColor = Color_Theme
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        view.textContainerInset = UIEdgeInsets.init(top: 10, left: 8, bottom: 10, right: 8)
        // 输入框不需要滚动条（横向那条会显示成输入框底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.returnKeyType = .default
        return view
    }()

    /// 举报理由的占位文案（UITextView 没有 placeholder，用一层 label 顶着）
    private lazy var detailPlaceholderLab: UILabel = {
        return UILabel.getLab(font: .regularFont(15), textColor: Color_8A97A5, textAlignment: .left,
                              text: L("请描述举报理由（选填）"))
    }()

    private lazy var detailCountLab: UILabel = {
        return UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .right, text: "0/\(SquareLimits.maxReportDetailLength)")
    }()

    // ④ 提交

    /// 提交按钮的样式（页面内 / 键盘上方各一个实例，样式抽出来避免两边不一致）
    /// ⚠️ 不能写 `private`：文件内的 `SquareReportAccessoryBar` 也要用它（跳类型读私有成员会报无权限）
    static func makeSubmitButton() -> UIButton {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("提交举报"), for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.titleLabel?.font = .mediumFont(16)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 22
        btn.clipsToBounds = true
        return btn
    }

    private lazy var submitBtn: UIButton = {
        let btn = SquareReportVC.makeSubmitButton()
        btn.addTarget(self, action: #selector(submitTap), for: .touchUpInside)
        return btn
    }()

    /// 键盘上方的提交条：作为理由输入框的 `inputAccessoryView`，键盘弹起时由系统直接挂在键盘顶上，
    /// 不用先收键盘再点提交。（与评论输入条同一套方案：自己监听键盘做动画会对不齐、落下错位残影。）
    private lazy var keyboardSubmitBar: SquareReportAccessoryBar = {
        let bar = SquareReportAccessoryBar()
        bar.submitBtn.addTarget(self, action: #selector(submitTap), for: .touchUpInside)
        return bar
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_F6F7F8
        self.navigationItem.title = L("举报")
        self.xls_navigationBarBackgroundColor = Color_FFFFFF

        self.setupViews()
        self.targetContentLab.text = self.targetSummary()
        // 举报类型**不预选**（用户自己选），初始只有理由输入区的占位/字数需要刷一次（refreshDetailState）

        // 模态打开（没有导航栈 → 外面包了一层导航控制器）时给个「取消」出口
        if self.presentingViewController != nil {
            let item = UIBarButtonItem.init(title: L("取消"), style: .plain, target: self, action: #selector(cancelTap))
            self.navigationItem.leftBarButtonItem = item
        }
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
            m.left.equalToSuperview().offset(sideInset)
            m.right.equalToSuperview().offset(-sideInset)
            m.top.equalToSuperview().offset(12)
            m.bottom.equalToSuperview().offset(-24)
        }
        submitBtn.snp.makeConstraints { (m) in
            m.height.equalTo(44)
        }

        setupTargetCard()
        setupReasonCard()
        setupDetailCard()
    }

    private func setupTargetCard() {
        targetCard.addSubview(targetTitleLab)
        targetCard.addSubview(targetContentLab)

        targetTitleLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(sideInset)
            m.right.equalToSuperview().offset(-sideInset)
            m.top.equalToSuperview().offset(14)
        }
        // ⚠️ 卡片高度靠「标题 top + 内容 bottom」这条链撑开：只写 top 的话卡片在 stackView 里高度为 0（看不见）
        targetContentLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(sideInset)
            m.right.equalToSuperview().offset(-sideInset)
            m.top.equalTo(targetTitleLab.snp.bottom).offset(8)
            m.bottom.equalToSuperview().offset(-14)
        }
    }

    private func setupReasonCard() {
        reasonCard.addSubview(reasonTitleLab)
        reasonCard.addSubview(reasonValueLab)
        reasonCard.addSubview(reasonArrow)
        // 透明按钮最后加（盖在最上层），整行都能点
        reasonCard.addSubview(reasonTapBtn)

        // 卡片高度靠标题的上下内边距撑开（和另外两张卡一致，不写死高度）
        reasonTitleLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(sideInset)
            m.top.equalToSuperview().offset(18)
            m.bottom.equalToSuperview().offset(-18)
        }
        reasonArrow.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-sideInset)
            m.centerY.equalToSuperview()
            m.width.height.equalTo(14)
        }
        reasonValueLab.snp.makeConstraints { (m) in
            m.right.equalTo(reasonArrow.snp.left).offset(-6)
            m.centerY.equalToSuperview()
            m.left.greaterThanOrEqualTo(reasonTitleLab.snp.right).offset(10)
        }
        reasonTapBtn.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }

    private func setupDetailCard() {
        detailCard.addSubview(detailTitleLab)
        detailCard.addSubview(detailHintLab)
        detailCard.addSubview(detailTextView)
        detailTextView.addSubview(detailPlaceholderLab)
        detailCard.addSubview(detailCountLab)

        detailTitleLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(sideInset)
            m.top.equalToSuperview().offset(14)
        }
        detailHintLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-sideInset)
            m.centerY.equalTo(detailTitleLab)
            m.left.greaterThanOrEqualTo(detailTitleLab.snp.right).offset(8)
        }
        detailTextView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(sideInset)
            m.right.equalToSuperview().offset(-sideInset)
            m.top.equalTo(detailTitleLab.snp.bottom).offset(10)
            m.height.equalTo(120)
        }
        detailPlaceholderLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(12)
            m.top.equalToSuperview().offset(10)
            m.right.lessThanOrEqualToSuperview().offset(-12)
        }
        detailCountLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-sideInset)
            m.top.equalTo(detailTextView.snp.bottom).offset(8)
            m.bottom.equalToSuperview().offset(-12)
        }

        // ⚠️ 必须显式设 delegate：UITextView 没有 placeholder，占位/字数都靠 textViewDidChange 驱动
        detailTextView.delegate = self
        // 键盘弹起时把「提交举报」挂到键盘上方（必须在 textView 成为第一响应者之前设好）
        detailTextView.inputAccessoryView = keyboardSubmitBar
        self.refreshDetailState()
    }

    // MARK: - 交互

    @objc private func cancelTap() {
        self.closePage()
    }

    /// 选中某个举报类型（**不默认选中**：只有用户从底部选择框里点选后才有值）
    private func applyReason(_ reason: SquareReportReason) {
        self.reason = reason
        reasonValueLab.text = reason.title
        reasonValueLab.textColor = Color_24374E
        self.refreshSubmitState()
    }

    /// 点「举报类型」那行：弹底部选择框。
    /// 用的是长按图片那个菜单的同一个组件（`FZMBottomSelectView`），表现、动画、高度都一致。
    @objc private func pickReason() {
        // 键盘还弹着的话先收掉，否则弹框会和键盘叠在一起
        self.view.endEditing(true)
        let options = SquareReportReason.allCases.map { reason -> FZMBottomOption in
            // 当前选中的那一项用主题色标一下（组件本身没有勾选态）
            let color = (reason == self.reason) ? Color_Theme : Color_24374E
            return FZMBottomOption.init(title: reason.title,
                                        titleColor: color,
                                        content: nil,
                                        contentColor: Color_8A97A5,
                                        block: { [weak self] in
                self?.applyReason(reason)
            })
        }
        FZMBottomSelectView.show(with: L("举报类型"), arr: options)
    }

    /// 理由输入变化：限长 / 字数 / 占位 / 按钮态
    private func refreshDetailState() {
        let limit = SquareLimits.maxReportDetailLength
        var text = detailTextView.text ?? ""
        if text.count > limit {
            text = String(text.prefix(limit))
            detailTextView.text = text
            detailTextView.selectedRange = NSRange(location: text.count, length: 0)
        }
        let count = text.count
        detailCountLab.text = "\(count)/\(limit)"
        detailPlaceholderLab.isHidden = count > 0
        self.refreshSubmitState()
    }

    /// 提交按钮态（页面内 + 键盘上方两份一起同步；只跟提交中状态有关，“类型未选”交给点击时的 toast 提示，按钮不置灰）
    private func refreshSubmitState() {
        let title = isSubmitting ? L("正在提交...") : L("提交举报")
        let background = isSubmitting ? Color_CCD1E0 : Color_Theme
        for btn in [submitBtn, keyboardSubmitBar.submitBtn] {
            btn.isEnabled = !isSubmitting
            btn.backgroundColor = background
            btn.setTitle(title, for: .normal)
        }
    }

    @objc private func submitTap() {
        guard !isSubmitting, post.id > 0 else { return }
        // 类型不默认选中 ⇒ 提交前必须自己校验一次
        guard let reason = reason else {
            self.showToast(with: L("请选择举报类型"))
            return
        }
        let detail = (detailTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // 选「其他」又什么都没写，运营没法处理 —— 先让用户补一句（服务端 detail 本身是选填）
        guard !(reason == .other && detail.isEmpty) else {
            self.showToast(with: L("选择「其他」时请补充举报理由"))
            detailTextView.becomeFirstResponder()
            return
        }

        self.view.endEditing(true)
        isSubmitting = true
        self.refreshSubmitState()
        SquareService.shared.report(postId: post.id, reason: reason, detail: detail, success: { [weak self] _ in
            guard let self = self else { return }
            self.isSubmitting = false
            self.refreshSubmitState()
            self.onReported?()
            self.showToast(with: L("举报成功，我们会尽快处理"))
            // 同一帖只能举报一次，提示完自动回上一页，免得用户反复提交
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.closePage()
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isSubmitting = false
            self.refreshSubmitState()
            // 接口还没上线（404）不弹提示；其余（含 -20410「已举报过该内容」）原样展示
            if failure.shouldStaySilent {
                FZMLog("举报失败(静默) \(failure.rawCode)")
            } else {
                self.showToast(with: failure.message)
            }
        })
    }

    /// 返回上一页（模态打开就 dismiss，push 打开就 pop）
    private func closePage() {
        if self.presentingViewController != nil {
            self.dismiss(animated: true)
        } else if let nav = self.navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        }
    }

    /// 被举报内容的摘要（作者：正文前 60 字；纯图片帖显示 [图片]）
    private func targetSummary() -> String {
        let name = post.authorName.isEmpty ? L("匿名用户") : post.authorName
        let body = post.content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return "\(name)：\(L("[图片]"))" }
        let summary = body.count > 60 ? String(body.prefix(60)) + "..." : body
        return "\(name)：\(summary)"
    }
}

// MARK: - 理由输入

extension SquareReportVC: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        self.refreshDetailState()
    }
}

// MARK: - 键盘上方的提交条

/// 举报页键盘上方的提交条：白底 + 顶部细线 + 一颗与页面内同款的「提交举报」。
///
/// 高度靠 `intrinsicContentSize` 交给系统（inputAccessoryView 就是按它定高的），
/// 内部按钮用约束摆布；`frame` 也给一份初值，避免挂在键盘上前被算出零尺寸。
private final class SquareReportAccessoryBar: UIView {

    /// 条高：顶部细线 +（上下各 6）+ 按钮 44
    private static let barHeight: CGFloat = 56

    /// 键盘上的那份「提交举报」（状态由 `SquareReportVC.refreshSubmitState()` 两处一起同步）
    let submitBtn: UIButton

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: SquareReportAccessoryBar.barHeight)
    }

    init() {
        self.submitBtn = SquareReportVC.makeSubmitButton()
        super.init(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: SquareReportAccessoryBar.barHeight))
        self.backgroundColor = Color_FFFFFF

        let line = UIView()
        line.backgroundColor = Color_E6EAEE
        self.addSubview(line)
        self.addSubview(submitBtn)

        line.snp.makeConstraints { (m) in
            m.left.right.top.equalToSuperview()
            m.height.equalTo(0.5)
        }
        submitBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(6)
            m.bottom.equalToSuperview().offset(-6)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
