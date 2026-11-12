//
//  SquareCreatePostVC.swift
//  chat
//
//  广场发帖页：正文（2000 字）+ 图片（≤9 张，先传 OSS 再提交 URL）
//  公众号账号额外支持「允许评论」开关；非公众号展示申请入口。
//

import Foundation
import UIKit
import ImageIO
import SnapKit
import RxSwift

final class SquareCreatePostVC: UIViewController, ViewControllerProtocol {

    /// 发帖成功（已发布 / 待审）后回调，广场流页据此刷新
    var onPosted: (() -> Void)?

    /// 二次编辑模式（《App增量-置顶与二次编辑》§3）：非空时预填正文并走 `PUT /square/app/posts/:id`
    private var editingPost: SquarePost?
    /// 编辑模式下**保留的已发布图片地址**（提交时原样回传，不重新上传）
    private var editingMediaURLs = [String]()

    /// 进编辑页（预填正文与已发布图片）
    static func edit(with post: SquarePost) -> SquareCreatePostVC {
        let vc = SquareCreatePostVC.init()
        vc.editingPost = post
        return vc
    }

    /// 预填正文（分享到广场用）：正常发帖（提交走 `POST /square/app/posts`），只是进去时正文已经写好
    private var prefilledContent: String?

    /// 带预填正文进入发帖页（AI 客服「分享到谈信广场」）
    static func create(withContent content: String) -> SquareCreatePostVC {
        let vc = SquareCreatePostVC.init()
        vc.prefilledContent = content
        return vc
    }

    /// 提交按钮文案（编辑模式是「保存」）
    private var submitTitle: String {
        return editingPost == nil ? L("发送") : L("保存")
    }

    private let bag = DisposeBag()

    private var officialState: SquareOfficialState = .none
    /// 已通过公众号的名称与头像（发帖进审时记进本机快照，快照帖也按公众号展示）
    private var officialName = ""
    private var officialAvatar = ""
    /// 已选图片（提交时上传成 mediaUrls，不再插到正文里）
    private var selectedImages = [UIImage]()
    private var isSubmitting = false
    private let imageSpacing: CGFloat = 8
    private let sideInset: CGFloat = 15
    /// 已选图片九宫格的高度约束（没图时置 0 收起）
    private var collectionHeightConstraint: SnapKit.Constraint?
    /// 发送按钮的底部约束（键盘弹起时上移到键盘上方）
    private var sendBtnBottomConstraint: SnapKit.Constraint?
    /// 当前键盘高度（0 = 收起）
    private var keyboardHeight: CGFloat = 0
    /// 项目已有的键盘模块（KeyboardObserver.swift / KeyboardNotification.swift）
    private lazy var keyboardObserver = KeyboardObserver()
    /// 抹掉系统键盘图层里那条滚动条细线（和详情页输入条同一套，见 SquareCommentInputBar.swift 末尾）
    private let scrollIndicatorHider = SquareSystemScrollIndicatorHider()

    // MARK: - 子视图

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = Color_F6F7F8
        view.showsVerticalScrollIndicator = false
        return view
    }()

    private lazy var contentView: UIView = {
        return UIView()
    }()

    /// 正文格式工具栏（Markdown 标记，点一下在光标处插入；跟着发送按钮一起避开键盘）
    private lazy var formatBar: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        return view
    }()

    private lazy var formatScrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var formatStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 8
        view.alignment = .center
        return view
    }()

    /// 垂直堆叠：正文卡 / 允许评论（仅公众号可见，紧贴输入框下方）/ 已选图片 / 添加图片
    private lazy var stackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [textCard, commentSwitchCard, imageCollectionView, addImageBtn])
        view.axis = .vertical
        view.spacing = 12
        view.alignment = .fill
        view.isLayoutMarginsRelativeArrangement = true
        view.layoutMargins = UIEdgeInsets.init(top: 0, left: sideInset, bottom: 0, right: sideInset)
        return view
    }()

    private lazy var textCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.font = .regularFont(16)
        view.textColor = Color_24374E
        view.tintColor = Color_Theme
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets.init(top: 8, left: 0, bottom: 8, right: 0)
        // 输入框不需要滚动条（横向的会显示成输入框底部的一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.addSubview(placeHolderLab)
        placeHolderLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(5)
            m.top.equalToSuperview().offset(8)
            m.right.equalToSuperview().offset(-5)
        }
        return view
    }()

    private lazy var placeHolderLab: UILabel = {
        return UILabel.getLab(font: .regularFont(16), textColor: Color_8A97A5, textAlignment: .left, text: L("这一刻的想法..."))
    }()

    private lazy var countLab: UILabel = {
        return UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .right, text: "0/\(SquareLimits.maxPostLength)")
    }()

    /// 已选图片九宫格（每行 3 个，右上角删除）
    private lazy var imageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = imageSpacing
        layout.minimumInteritemSpacing = imageSpacing
        let view = UICollectionView.init(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        // 不需要横向滚动条（会显示成一条黑线）
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        // 删除按钮画在格子右上角略微出界，不要裁掉
        view.clipsToBounds = false
        view.delegate = self
        view.dataSource = self
        view.isHidden = true
        view.register(SquareImagePickerCell.self, forCellWithReuseIdentifier: SquareImagePickerCell.identifier)
        return view
    }()

    private lazy var addImageBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("  " + L("添加图片"), for: .normal)
        btn.setTitleColor(Color_8A97A5, for: .normal)
        btn.titleLabel?.font = .regularFont(14)
        btn.setImage(UIImage.init(systemName: "plus.square")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_8A97A5
        btn.contentHorizontalAlignment = .left
        btn.addTarget(self, action: #selector(addImageTap), for: .touchUpInside)
        return btn
    }()

    /// 「允许评论」一栏（仅已通过公众号可见；个人帖由服务端忽略该字段）
    private lazy var commentSwitchCard: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        // 默认隐藏：拉完公众号状态（applyOfficialLayout）再决定是否显示，避免个人用户看到闪一下
        view.isHidden = true

        let lab = UILabel.getLab(font: .regularFont(15), textColor: Color_24374E, textAlignment: .left, text: L("允许评论"))
        view.addSubview(lab)
        view.addSubview(commentSwitch)

        // ⚠️ 上下都要有约束，卡片才有高度：只写 centerY 的话这个卡片在 stackView 里高度为 0（看不见）
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.lessThanOrEqualTo(commentSwitch.snp.left).offset(-10)
            m.top.equalToSuperview().offset(14)
            m.bottom.equalToSuperview().offset(-14)
        }
        commentSwitch.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(lab)
        }
        return view
    }()

    private lazy var commentSwitch: UISwitch = {
        let view = UISwitch()
        view.onTintColor = Color_Theme
        view.isOn = true
        return view
    }()

    private lazy var sendBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        // 这里不要引用实例属性（闭包里访问实例成员要显式 self，容易踩编译错误）：
        // 编辑模式的「保存」文案由 applyEditModeIfNeeded() 在 viewDidLoad 里设
        btn.setTitle(L("发送"), for: .normal)
        btn.setTitleColor(Color_FFFFFF, for: .normal)
        btn.titleLabel?.font = .mediumFont(16)
        btn.backgroundColor = Color_CCD1E0
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.isEnabled = false
        btn.addTarget(self, action: #selector(sendTap), for: .touchUpInside)
        return btn
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_F6F7F8
        self.navigationItem.title = L("发帖")
        self.xls_navigationBarBackgroundColor = Color_FFFFFF

        setupViews()
        setRX()
        loadOfficialState()
        observeKeyboard()
        applyEditModeIfNeeded()
        applyPrefilledContentIfNeeded()
    }

    /// 编辑模式：换标题、预填正文与已发布图片，按钮改「保存」
    private func applyEditModeIfNeeded() {
        guard let post = editingPost else { return }
        self.navigationItem.title = L("编辑帖子")
        self.editingMediaURLs = post.mediaUrls
        self.commentSwitch.isOn = post.commentsEnabled
        self.textView.text = post.content
        self.sendBtn.setTitle(submitTitle, for: .normal)
        // ⚠️ 程序化赋值不会触发 `rx.didChange`（它靠 textViewDidChange），所以手动刷一次占位/字数/按钮态
        self.refreshInputState()
        self.reloadImages()
    }

    /// 预填正文（分享到广场）：非编辑模式，仅把分享内容写进输入框，等用户自己点「发送」
    private func applyPrefilledContentIfNeeded() {
        guard editingPost == nil, let content = prefilledContent, !content.isEmpty else { return }
        self.textView.text = content
        // ⚠️ 程序化赋值不会触发 `rx.didChange`（同编辑模式），手动刷一次占位/字数/按钮态
        self.refreshInputState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏白底、去掉滚动时出现的底部细线
        applySquareNavBarStyle()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // 安全区变化（横竖屏 / 机型切换）时对齐发送按钮
        updateSendBtnBottom()
    }

    // MARK: - 键盘
    //
    // 发送按钮（连同上方输入区域）跟着键盘上移，保证输入框与发送按钮始终在键盘上方
    // （IQKeyboardManager 在这几个页面已禁用，见 `AppDelegateIntercepter.loadIQKeyboard`）。

    private func observeKeyboard() {
        let follow: (KeyboardNotification) -> Void = { [weak self] notification in
            guard let self = self else { return }
            let height = notification.endFrame.height
            guard height > 0, abs(height - self.keyboardHeight) > 0.5 else { return }
            self.keyboardHeight = height
            self.updateSendBtnBottom(notification)
        }
        keyboardObserver.callbacks[.willShow] = follow
        keyboardObserver.callbacks[.willChangeFrame] = follow
        keyboardObserver.callbacks[.willHide] = { [weak self] notification in
            guard let self = self, self.keyboardHeight > 0 else { return }
            self.keyboardHeight = 0
            self.updateSendBtnBottom(notification)
        }
    }

    /// 发送按钮离屏幕底部的距离 = 键盘高度 + 10（键盘收起时是安全区 + 10）
    private func updateSendBtnBottom(_ notification: KeyboardNotification? = nil) {
        let base = max(keyboardHeight, self.view.safeAreaInsets.bottom)
        sendBtnBottomConstraint?.update(offset: -(base + 10))
        guard let notification = notification else { return }
        UIView.animate(withDuration: notification.timeInterval,
                       delay: 0,
                       options: [notification.animationOptions, .allowAnimatedContent, .beginFromCurrentState],
                       animations: { [weak self] in
                           self?.view.layoutIfNeeded()
                       },
                       completion: nil)
    }

    private func setupViews() {
        self.view.addSubview(scrollView)
        self.view.addSubview(formatBar)
        self.view.addSubview(sendBtn)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { (m) in
            m.left.right.top.equalToSuperview()
            m.bottom.equalTo(formatBar.snp.top).offset(-8)
        }
        formatBar.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.bottom.equalTo(sendBtn.snp.top).offset(-8)
            m.height.equalTo(44)
        }
        contentView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
            m.width.equalToSuperview()
        }
        sendBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(sideInset)
            m.right.equalToSuperview().offset(-sideInset)
            sendBtnBottomConstraint = m.bottom.equalToSuperview().offset(-10).constraint
            m.height.equalTo(40)
        }
        updateSendBtnBottom()
        setupFormatBar()

        contentView.addSubview(stackView)
        textCard.addSubview(textView)
        textCard.addSubview(countLab)

        stackView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalToSuperview().offset(12)
            m.bottom.equalToSuperview().offset(-20)
        }

        textCard.snp.makeConstraints { (m) in
            m.height.equalTo(180)
        }
        countLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-12)
            m.bottom.equalToSuperview().offset(-8)
        }
        textView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.top.equalToSuperview().offset(6)
            m.bottom.equalTo(countLab.snp.top).offset(-2)
        }

        addImageBtn.snp.makeConstraints { (m) in
            m.height.equalTo(30)
        }
        imageCollectionView.snp.makeConstraints { (m) in
            collectionHeightConstraint = m.height.equalTo(0).constraint
        }

        // 输入框编辑期间抹掉系统键盘里的滚动条细线（发帖页弹/收键盘也会闪那一条）。
        // ⚠️ delegate 必须在 setRX() 订阅 rx.didChange 之前设好，Rx 代理才会把回调转发给我们
        textView.delegate = self
        scrollIndicatorHider.isStillEditing = { [weak self] in
            self?.textView.isFirstResponder ?? false
        }
    }

    private func setRX() {
        textView.rx.didChange.subscribe(onNext: { [weak self] in
            self?.refreshInputState()
        }).disposed(by: bag)
    }

    /// 输入内容变化：限长 / 字数 / 占位文案 / 发送按钮状态
    private func refreshInputState() {
        limitInputLength()
        let count = textView.text.count
        countLab.text = "\(count)/\(SquareLimits.maxPostLength)"
        placeHolderLab.isHidden = count > 0
        addImageBtn.isHidden = mediaCount >= SquareLimits.maxImageCount
        updateSendBtnState()
    }

    /// 正文限长（纯文本，直接用 text 截断即可）
    private func limitInputLength() {
        let limit = SquareLimits.maxPostLength
        guard textView.text.count > limit else { return }
        let truncated = String((textView.text ?? "").prefix(limit))
        textView.text = truncated
        textView.selectedRange = NSRange(location: truncated.count, length: 0)
    }

    // MARK: - 正文格式工具栏

    private func setupFormatBar() {
        formatBar.addSubview(formatScrollView)
        formatScrollView.addSubview(formatStack)
        formatScrollView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        formatStack.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(sideInset)
            m.right.equalToSuperview().offset(-sideInset).priority(.low)
            m.height.equalToSuperview()
        }

        addFormatButton("B", font: .boldFont(15), action: #selector(boldTap))
        addFormatButton("I", font: .italicSystemFont(ofSize: 15), action: #selector(italicTap))
        addFormatButton("H", font: .mediumFont(15), action: #selector(headingTap))
        addFormatButton("•", font: .mediumFont(16), action: #selector(bulletTap))
        addFormatButton("❝", font: .mediumFont(14), action: #selector(quoteTap))
        addFormatButton("</>", font: .regularFont(13), action: #selector(codeTap))
        addFormatButton("🔗", font: .regularFont(13), action: #selector(linkTap))
        addFormatButton("#", font: .mediumFont(15), action: #selector(topicTap))
        addFormatButton("@", font: .mediumFont(15), action: #selector(mentionTap))
        addFormatButton("?", font: .mediumFont(14), action: #selector(formatHelpTap))
    }

    private func addFormatButton(_ title: String, font: UIFont, action: Selector) {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(Color_24374E, for: .normal)
        btn.titleLabel?.font = font
        btn.backgroundColor = Color_F6F7F8
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.snp.makeConstraints { $0.height.equalTo(28) }
        formatStack.addArrangedSubview(btn)
    }

    @objc private func boldTap() { insertMarkdown(prefix: "**", suffix: "**", placeholder: L("加粗文字")) }
    @objc private func italicTap() { insertMarkdown(prefix: "*", suffix: "*", placeholder: L("斜体文字")) }
    @objc private func headingTap() { insertLinePrefix("# ") }
    @objc private func bulletTap() { insertLinePrefix("- ") }
    @objc private func quoteTap() { insertLinePrefix("> ") }
    @objc private func codeTap() { insertMarkdown(prefix: "`", suffix: "`", placeholder: L("代码")) }
    @objc private func linkTap() { insertMarkdown(prefix: "[", suffix: "](https://)", placeholder: L("链接文字")) }
    @objc private func topicTap() { insertMarkdown(prefix: "#", suffix: "", placeholder: L("话题")) }
    @objc private func mentionTap() { insertMarkdown(prefix: "@", suffix: "") }

    @objc private func formatHelpTap() {
        let alert = UIAlertController.init(title: L("正文支持的格式"),
                                           message: L("# 标题\n**加粗**、*斜体*\n- 无序列表、1. 有序列表\n> 引用\n`行内代码`、``` 代码块\n[文字](https://链接)\n@昵称、#话题\n空行即分段"),
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L("知道了"), style: .default, handler: nil))
        self.present(alert, animated: true)
    }

    /// 在光标处插入标记；有选中内容就把它包起来，没选中就插入占位文字并选中它
    private func insertMarkdown(prefix: String, suffix: String, placeholder: String = "") {
        textView.becomeFirstResponder()
        let ns = (textView.text ?? "") as NSString
        let range = safeRange(textView.selectedRange, in: ns)
        let selectedText = range.length > 0 ? ns.substring(with: range) : ""
        let body = selectedText.isEmpty ? placeholder : selectedText
        let insertion = prefix + body + suffix

        textView.text = ns.replacingCharacters(in: range, with: insertion)
        // 选中中间那段（占位文字 / 原选中内容），方便直接输入替换
        let bodyStart = range.location + (prefix as NSString).length
        textView.selectedRange = NSRange(location: bodyStart, length: (body as NSString).length)
        refreshInputState()
    }

    /// 在当前行开头插入标记（标题 / 列表 / 引用）
    private func insertLinePrefix(_ prefix: String) {
        textView.becomeFirstResponder()
        let ns = (textView.text ?? "") as NSString
        let caret = safeRange(textView.selectedRange, in: ns).location
        let lineStart = ns.lineRange(for: NSRange(location: caret, length: 0)).location
        textView.text = ns.replacingCharacters(in: NSRange(location: lineStart, length: 0), with: prefix)
        textView.selectedRange = NSRange(location: caret + (prefix as NSString).length, length: 0)
        refreshInputState()
    }

    /// 防止越界的选区（程序化改文本后选区可能已经越界）
    private func safeRange(_ range: NSRange, in text: NSString) -> NSRange {
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), text.length - location)
        return NSRange(location: location, length: length)
    }

    private func updateSendBtnState() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // 纯图片帖也算有内容
        let valid = (hasText || mediaCount > 0) && !isSubmitting
        sendBtn.isEnabled = valid
        sendBtn.backgroundColor = valid ? Color_Theme : Color_CCD1E0
    }

    // MARK: - 公众号状态

    private func loadOfficialState() {
        SquareService.shared.officialMe(success: { [weak self] me in
            guard let self = self else { return }
            self.officialState = me.state
            self.officialName = me.official?.name ?? ""
            self.officialAvatar = me.official?.avatar ?? ""
            self.applyOfficialLayout()
        }, failure: { [weak self] _ in
            // 拉取失败不阻塞发帖，按个人身份处理
            self?.officialState = .none
            self?.applyOfficialLayout()
        })
    }

    private func applyOfficialLayout() {
        // 堆叠布局里隐藏的卡片会自动收起
        // 公众号申请/详情入口统一放在「我的」页，发帖页不再提供入口
        // 只有「已通过」的公众号发文才需要选是否允许评论；个人帖服务端忽略该字段，所以整栏不显示
        commentSwitchCard.isHidden = !officialState.isApproved
    }

    // MARK: - 图片（已选图片九宫格，提交为媒体附件）

    /// 已选（含编辑模式保留的）图片总数
    private var mediaCount: Int {
        return editingMediaURLs.count + selectedImages.count
    }

    /// 刷新九宫格：没图时高度置 0 隐藏，高度按行数算（每行 3 个）
    private func reloadImages() {
        imageCollectionView.reloadData()
        let count = mediaCount
        let rows = Int(ceil(Double(count) / 3.0))
        let itemSize = (k_ScreenWidth - sideInset * 2 - imageSpacing * 2) / 3
        let height = count == 0 ? 0 : CGFloat(rows) * itemSize + CGFloat(rows - 1) * imageSpacing
        collectionHeightConstraint?.update(offset: height)
        imageCollectionView.isHidden = count == 0
        addImageBtn.isHidden = count >= SquareLimits.maxImageCount
        updateSendBtnState()
    }

    @objc private func addImageTap() {
        let remain = SquareLimits.maxImageCount - mediaCount
        guard remain > 0 else {
            self.showToast(with: L("最多只能选择 9 张图片"))
            return
        }
        self.view.endEditing(true)

        // 与聊天发图一致的系统相册选择器（只列图片，能展示相册全部图片）
        SystemMediaPicker.shared.present(from: self, maxCount: remain, imagesOnly: true) { [weak self] results in
            guard let self = self else { return }
            // 点了关闭/取消：什么都不做，也不要弹提示
            guard !results.isEmpty else { return }

            var images = [UIImage]()
            for media in results {
                switch media.mediaType {
                case .image:
                    if let image = media.image {
                        images.append(image)
                    }
                case .gif:
                    // GIF 取首帧（上传时会统一压缩成 JPEG）
                    if let gifData = media.gifData, let firstFrame = SquareCreatePostVC.firstFrame(of: gifData) {
                        images.append(firstFrame)
                    }
                default:
                    break
                }
            }

            guard !images.isEmpty else {
                self.showToast(with: L("仅支持选择图片"))
                return
            }

            self.selectedImages.append(contentsOf: images)
            if self.selectedImages.count > SquareLimits.maxImageCount {
                self.selectedImages = Array(self.selectedImages.prefix(SquareLimits.maxImageCount))
            }
            self.reloadImages()
        }
    }

    /// GIF 取第一帧（避免 UIImage(data:) 全帧解码导致内存暴涨）
    private static func firstFrame(of gifData: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(gifData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage.init(cgImage: cgImage)
    }

    // MARK: - 提交

    // MARK: - 辅助

    private func popBack() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc private func sendTap() {
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || mediaCount > 0, !isSubmitting else { return }
        guard !officialState.isBanned else {
            self.showToast(with: L("公众号已被封禁，请联系运营"))
            return
        }

        isSubmitting = true
        updateSendBtnState()
        sendBtn.setTitle(L("发送中..."), for: .normal)

        // 编辑模式：已发布图片原样回传，只上传新加的
        let existingMedia = editingMediaURLs
        if selectedImages.isEmpty {
            submit(content: content, mediaUrls: existingMedia)
            return
        }

        // 多图并行压缩 + 限并发上传，按钮上显示进度，避免看起来像卡住
        _ = SquareService.shared.uploadImages(selectedImages, progress: { [weak self] finished, total in
            guard let self = self else { return }
            if total > 1 {
                self.sendBtn.setTitle("\(L("发送中..."))\(finished)/\(total)", for: .normal)
            }
        }, success: { [weak self] urls in
            self?.submit(content: content, mediaUrls: existingMedia + urls)
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isSubmitting = false
            self.updateSendBtnState()
            self.sendBtn.setTitle(self.submitTitle, for: .normal)
            self.showToast(with: failure.message)
        })
    }

    private func submit(content: String, mediaUrls: [String]) {
        // 只有公众号帖才允许关闭评论，个人帖传 nil 由服务端忽略
        let commentsEnabled: Bool? = officialState.isApproved ? commentSwitch.isOn : nil
        // 编辑模式走 PUT /square/app/posts/:id（同样会重新走审核）
        if let editing = editingPost {
            submitUpdate(editing: editing, content: content, mediaUrls: mediaUrls, commentsEnabled: commentsEnabled)
            return
        }
        SquareService.shared.createPost(content: content,
                                        nickname: nil,
                                        mediaUrls: mediaUrls,
                                        commentsEnabled: commentsEnabled,
                                        success: { [weak self] outcome in
            guard let self = self else { return }
            self.isSubmitting = false
            self.updateSendBtnState()
            self.sendBtn.setTitle(self.submitTitle, for: .normal)
            switch outcome {
            case .published:
                self.showToast(with: L("发布成功"))
                self.onPosted?()
                self.popBack()
            case .pendingReview:
                // 服务端待审帖不返回 id，本地记一条快照，用户可在「我的帖子」里看到自己刚发的内容
                let isOfficial = self.officialState.isApproved
                SquareMyPostStore.appendPending(content: content,
                                                mediaUrls: mediaUrls,
                                                authorKind: isOfficial ? .official : .person,
                                                authorAvatar: isOfficial ? self.officialAvatar : "",
                                                authorName: isOfficial ? self.officialName : "",
                                                commentsEnabled: self.commentSwitch.isOn)
                self.showToast(with: L("已提交，等待审核"))
                self.onPosted?()
                self.popBack()
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isSubmitting = false
            self.updateSendBtnState()
            self.sendBtn.setTitle(self.submitTitle, for: .normal)
            self.showToast(with: failure.message)
        })
    }

    /// 编辑提交：帖子已存在（有 id），不再写本地待审快照
    private func submitUpdate(editing post: SquarePost,
                              content: String,
                              mediaUrls: [String],
                              commentsEnabled: Bool?) {
        SquareService.shared.updatePost(id: post.id,
                                        content: content,
                                        nickname: nil,
                                        mediaUrls: mediaUrls,
                                        commentsEnabled: commentsEnabled,
                                        success: { [weak self] outcome in
            guard let self = self else { return }
            self.isSubmitting = false
            self.updateSendBtnState()
            self.sendBtn.setTitle(self.submitTitle, for: .normal)
            switch outcome {
            case .published:
                self.showToast(with: L("已保存"))
                self.onPosted?()
                self.popBack()
            case .pendingReview:
                self.showToast(with: L("已提交，等待审核"))
                self.onPosted?()
                self.popBack()
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isSubmitting = false
            self.updateSendBtnState()
            self.sendBtn.setTitle(self.submitTitle, for: .normal)
            // 404（编辑接口还没上线）不弹提示；-20415「超过可编辑时间」等照常提示
            if failure.shouldStaySilent {
                FZMLog("编辑提交失败(静默) \(failure.rawCode)")
            } else {
                self.showToast(with: failure.message)
            }
        })
    }
}

// MARK: - 输入框编辑（抹掉系统键盘滚动条细线）

extension SquareCreatePostVC: UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        scrollIndicatorHider.start()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // 键盘收起动画期间系统还会重建一次滚动条，多抹 1.2 秒再停
        scrollIndicatorHider.stop(grace: 1.2)
    }
}

// MARK: - 已选图片九宫格

extension SquareCreatePostVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SquareImagePickerCell.identifier, for: indexPath) as! SquareImagePickerCell
        // 前 editingMediaURLs.count 个是编辑模式保留的已发布图片（远程），后面是新选的本地图
        let remoteCount = editingMediaURLs.count
        if indexPath.item < remoteCount {
            let url = editingMediaURLs[indexPath.item]
            cell.configure(url: url)
        } else {
            let localIndex = indexPath.item - remoteCount
            guard localIndex < selectedImages.count else { return cell }
            cell.configure(image: selectedImages[localIndex])
        }
        cell.onDelete = { [weak self] in
            guard let self = self else { return }
            if indexPath.item < self.editingMediaURLs.count {
                self.editingMediaURLs.remove(at: indexPath.item)
            } else {
                let localIndex = indexPath.item - remoteCount
                guard localIndex < self.selectedImages.count else { return }
                self.selectedImages.remove(at: localIndex)
            }
            self.reloadImages()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemSize = (k_ScreenWidth - sideInset * 2 - imageSpacing * 2) / 3
        return CGSize(width: itemSize, height: itemSize)
    }
}
