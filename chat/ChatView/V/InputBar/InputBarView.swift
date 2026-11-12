
//
//  InputBarView.swift
//  chat
//
//  Created by fzm on 2021/2/2.
//

import UIKit
import NextGrowingTextView
import SnapKit
import TSVoiceConverter

protocol InputBarViewDelegate: NSObjectProtocol {
    // 发文字
    func inputBarView(_ inputBarView: InputBarView, sendText text: String, mentionIds: [String])
    func audioBarView(_ inputBarView: InputBarView, amrPath: String, wavPath: String, duration: Double)
    func inputBarViewDeleteReference()
}

extension InputBarViewDelegate {
    func inputBarView(_ inputBarView: InputBarView, sendText text: String, mentionIds: [String]) { }
    func audioBarView(_ inputBarView: InputBarView, amrPath: String, wavPath: String, duration: Double) { }
    func inputBarViewDeleteReference() { }
}


class InputBarView: UIView {
    
    let itemSize = CGSize.init(width: 50, height: 47)
    
    let disposeBag = DisposeBag()
    weak var delegate: InputBarViewDelegate?
    
    var group: Group?// 判断是否是群聊，如果是群聊需处理 @谁 相关
    
    private let atCache = FZMInputAtItemCache.init()// @谁 数据源
    
    var clickMoreBtnBlock : NormalBlock?//更多按钮点击
//    var showMoreBlock : NormalBlock?
//    var showTextViewBlock : NormalBlock?
    var hideKeyboardBlock : NormalBlock?//键盘隐藏
    
    var clickVoiceBtnBlock : NormalBlock?//语音按钮点击
    var showVoiceBlock : NormalBlock?
    
//    var clickDeleteReferenceBlock: NormalBlock?// 点击删除引用按钮
    
    var recordAudioCompleteBlock : ((String,String,Double,Bool)->())?
    var changeSpaceToBottom: ((CGFloat) ->())?
    
    var showVoice = false
    var showMore = false
    
    var sendMsgBlock : ((String,Bool,Bool,[String])->())?
    var sendImgsBlock : (([UIImage],Bool)->())?
    
    let contenView = UIView.init()
    
    let leftStackView: UIStackView = {
        let stackView = UIStackView.init()
        stackView.axis = .horizontal
        stackView.alignment = .bottom
        stackView.spacing = 0
        return stackView
    }()
    
    var leftStackViewWidth = 0
    
    let rightStackView: UIStackView = {
        let stackView = UIStackView.init()
        stackView.axis = .horizontal
        stackView.alignment = .bottom
        stackView.spacing = 0
        return stackView
    }()
    
    var rightStackViewWidth = 0
    private var rightStackViewWidthConstraint: SnapKit.Constraint?
    
    let textContenView = UIView.init()
    
    // 输入框初始Inset
    let textContenViewInsetDefault = UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10)
    
    let textViewHeightDefault = 27.5
    
    // 当前输入框Inset
    lazy var textContenViewInsetCurrent = textContenViewInsetDefault
    
    // 表情
    let emojiView = CustomEmojiView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 270))
    
    // 输入框
    let inputTextView: NextGrowingTextView = {
        let inputTextView = NextGrowingTextView.init()
        inputTextView.textView.returnKeyType = .send
        inputTextView.maxNumberOfLines = 5
        inputTextView.textView.font = UIFont.systemFont(ofSize: 16)
        inputTextView.textView.textColor = Color_24374E
        inputTextView.textView.tintColor = Color_Theme
        inputTextView.textView.limitText(with: 6000)// 限制最大输入文字个数为6000字
        inputTextView.placeholderAttributedText = NSAttributedString.init(string: L("想说点什么呢…"), attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Color_8A97A5])
        return inputTextView
    }()
    
    var recordHelper: AudioMessageManager!
    var lastSendVoicePath = "" //用于松开手指的时候判断是否已发送
    let recordHub: IMRecordTipHub = IMRecordTipHub(with: .recording)
    
    // 录音按钮
    lazy var recordVoiceBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.isHidden = true
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_Theme.cgColor
        btn.setAttributedTitle(NSAttributedString(string: L("按住说话"), attributes: [.foregroundColor:Color_Theme,.font:UIFont.regularFont(16)]), for: .normal)
        btn.setAttributedTitle(NSAttributedString(string: L("松开结束"), attributes: [.foregroundColor:Color_Theme,.font:UIFont.regularFont(16)]), for: .highlighted)
        btn.setBackgroundColor(color: UIColor(hexString: "#E7F5FC")!, state: .normal)
        btn.setBackgroundColor(color: UIColor(hexString: "#D0E6F2")!, state: .highlighted)
        return btn
    }()
    
    // 切换表情按钮
    lazy var emojiBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.snp.makeConstraints { $0.size.equalTo(itemSize) }
        btn.tintColor = Color_Theme
        btn.setImage(#imageLiteral(resourceName: "inputBar_emojiNor").withRenderingMode(.alwaysTemplate), for: .normal)
        btn.setImage(#imageLiteral(resourceName: "inputBar_emojiSel").withRenderingMode(.alwaysTemplate), for: .selected)
        btn.addTarget(self, action: #selector(self.emojiBtnAction(_:)), for: .touchUpInside)
        return btn
    }()
    
    // 左侧切换为语音模式按钮
    lazy var voiceBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.tintColor = Color_Theme
        btn.setImage(#imageLiteral(resourceName: "inputBar_voice").withRenderingMode(.alwaysTemplate), for: .normal)
        btn.snp.makeConstraints { $0.size.equalTo(itemSize) }
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext:{[weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.showMore = false
            strongSelf.showVoice = !strongSelf.showVoice
            strongSelf.clickVoiceBtnBlock?()
            
//            if !strongSelf.showVoice {
//                strongSelf.showVoice = true
//                strongSelf.showVoiceBlock?()
//            }
        }).disposed(by: disposeBag)
        return btn
    }()
    
    // 左侧切换为文字输入模式按钮
    lazy var textBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.tintColor = Color_Theme
        btn.setImage(#imageLiteral(resourceName: "inputBar_text").withRenderingMode(.alwaysTemplate), for: .normal)
        btn.snp.makeConstraints { $0.size.equalTo(itemSize) }
        return btn
    }()
    
    // 右侧更多按钮
    lazy var moreBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.tintColor = Color_Theme
        btn.setImage(#imageLiteral(resourceName: "inputBar_more").withRenderingMode(.alwaysTemplate), for: .normal)
        btn.snp.makeConstraints { $0.size.equalTo(itemSize) }
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext:{[weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.showVoice = false
            strongSelf.showMore = !strongSelf.showMore
            strongSelf.clickMoreBtnBlock?()
        }).disposed(by: disposeBag)
        return btn
    }()
    
    /* - - - - - - */
    // 引用消息视图
    lazy var referenceView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        
        view.addSubview(labBgView)
        labBgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-10)
            make.width.lessThanOrEqualTo(k_ScreenWidth - 15 - 45)
        }
        
        view.addSubview(deleteBtn)
        deleteBtn.snp.makeConstraints { (m) in
//            m.size.equalTo(CGSize(width: 45, height: 45))
            m.bottom.equalToSuperview().offset(-10)
            m.top.equalToSuperview().offset(10)
            m.left.equalTo(labBgView.snp.right)
            m.centerY.equalTo(labBgView)
        }
        
        return view
    }()
    
    // 删除按钮
    lazy var deleteBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "icon_close"), for: .normal)
        btn.addTarget(self, action: #selector(clickDeleteAction), for: .touchUpInside)
        return btn
    }()
    
    // 引用文本背景
    lazy var labBgView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.init(hexString: "#8A97A5", transparency: 0.09)!
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        
        view.addSubview(referenceLab)
        referenceLab.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8.5)
            make.left.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-8.5)
            self.referenceLabRightConstraint = make.right.equalToSuperview().offset(-10).constraint
        }

        // 引用的是图片/视频/文件时，右侧显示缩略图（和气泡下方引用条一致）
        view.addSubview(referenceThumbView)
        referenceThumbView.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-8)
            m.centerY.equalToSuperview()
            m.width.height.equalTo(QuoteBlockMetrics.thumbSide)
        }
        
        return view
    }()

    /// 引用条右侧的缩略图（图片/视频/文件）
    private lazy var referenceThumbView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor = UIColor.init(hexString: "#8A97A5", transparency: 0.12)
        iv.isHidden = true
        return iv
    }()

    /// 引用文本右边距约束（有缩略图时要让出空间）
    /// ⚠️ 必须写全 `SnapKit.Constraint`：项目里另有一个 `Constraint` 类型，直接写会撞名
    private var referenceLabRightConstraint: SnapKit.Constraint?
    /// 缩略图异步加载的令牌（切引用时丢弃过期回调）
    private var referenceThumbToken: Int = 0
    
    // 引用文本
    lazy var referenceLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: "")
        lab.numberOfLines = 2
        return lab
    }()
    /* - - - - - - */
    
    
    // 禁言视图
    lazy var bannedView : UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: UIColor.white, textAlignment: .center, text: nil)
        lab.backgroundColor = UIColor(hex: 0x142E4D, alpha: 0.8)
        lab.isHidden = true
        lab.isUserInteractionEnabled = true
        return lab
    }()
    
    init() {
        super.init(frame: .zero)
        //语音相关
        self.recordHelper = AudioMessageManager()
        self.recordHelper.updateMeterDelegate = self.recordHub
        self.recordHelper.stopRecordCompletion = {
            
        }
        self.recordHelper.recordMaxTimeBlock = {[weak self] in
            self?.endRecordVoiceSend()
        }
        
        self.inputTextView.textView.delegate = self
        self.emojiView.delegate = self
    }
    
    deinit { }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    var bottomConstraint: SnapKit.Constraint?
    
    // 输入框高度约束
    var inputTextViewHeightConstraint: SnapKit.Constraint?
    
    /// 阅后即焚模式样式：整个输入框边界变蓝（+ 浅色底）；提示条浮在**输入框上方**。
    /// 输入框内的占位文案保持不变（提示不放输入框里）。
    func setBurnMode(_ on: Bool) {
        textContenView.layer.cornerRadius = 6
        textContenView.layer.borderWidth = on ? 1 : 0
        textContenView.layer.borderColor = Color_Theme.cgColor
        textContenView.backgroundColor = on ? Color_Theme.withAlphaComponent(0.06) : .clear
        burnHintView.isHidden = !on
    }

    /// 阅后即焚提示条：浮在输入框上方（不在内容链里，**不影响输入栏高度**）
    private lazy var burnHintView: UIView = {
        let v = UIView()
        v.backgroundColor = Color_Theme
        v.layer.cornerRadius = 10
        v.layer.masksToBounds = true
        v.isHidden = true
        self.addSubview(v)
        v.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalTo(self.snp.top).offset(-8)
            m.height.equalTo(20)
        }
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 12), textColor: .white, textAlignment: .center, text: "🔥 " + L("阅后即焚"))
        v.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.centerY.equalToSuperview()
        }
        return v
    }()
    
    func bindTo(view: UIView) {
        self.removeFromSuperview()
        
        view.addSubview(self)
        
        self.setupViews()
        
        self.observeHeight()
        
        self.observeKeyboard()
        //语音
        self.setRecordActions()
    }
    
    private func setupViews() {
        self.backgroundColor = Color_FFFFFF
        self.layer.backgroundColor = Color_FFFFFF.cgColor
        
        self.snp.makeConstraints { (m) in
            m.right.left.equalToSuperview()
            m.bottom.equalToSuperview().offset(-k_SafeBottomInset)
//            self.bottomConstraint = m.bottom.equalToSuperview().offset(-k_SafeBottomInset).constraint
        }
        
        let safeBottomView = UIView.init()
        safeBottomView.backgroundColor = self.backgroundColor
        self.addSubview(safeBottomView)
        safeBottomView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.snp.bottom)
            m.height.equalTo(k_SafeBottomInset)
        }
        
        // 引用视图
        self.addSubview(self.referenceView)
        self.referenceView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.height.equalTo(0)// 0 一行文字：50 两行文字：70
        }
        
        self.addSubview(self.contenView)
        self.contenView.snp.makeConstraints { (m) in
            m.top.equalTo(self.referenceView.snp.bottom).offset(11)
            m.bottom.equalToSuperview().offset(-11)
            m.left.equalToSuperview()
            m.right.equalToSuperview()
        }
        
        self.contenView.addSubview(self.leftStackView)
        self.leftStackView.snp.makeConstraints { (m) in
            m.top.left.bottom.equalToSuperview()
            m.width.equalTo(leftStackViewWidth)
        }
        
        self.contenView.addSubview(self.rightStackView)
        self.rightStackView.snp.makeConstraints { (m) in
            m.top.right.bottom.equalToSuperview()
            m.width.equalTo(rightStackViewWidth)
            self.rightStackViewWidthConstraint = m.width.equalTo(rightStackViewWidth).constraint
        }
        
        self.contenView.addSubview(self.textContenView)
        self.textContenView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(self.textContenViewInsetDefault.top)
            m.bottom.equalToSuperview().offset(-self.textContenViewInsetDefault.bottom)
            m.left.equalTo(self.leftStackView.snp.right).offset(self.textContenViewInsetDefault.left)
            m.right.equalTo(self.rightStackView.snp.left).offset(-self.textContenViewInsetDefault.right)
        }
        
//        self.contenView.addSubview(self.emojiBtn)
//        self.emojiBtn.snp.makeConstraints { (m) in
//            m.centerY.equalTo(self.contenView)
//            m.left.equalTo(self.textContenView.snp.right).offset(10)
//            m.size.equalTo(26)
//        }
        
        self.textContenView.addSubview(self.inputTextView)
        self.inputTextView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
            self.inputTextViewHeightConstraint = m.height.equalTo(self.inputTextView.intrinsicContentSize.height).constraint
        }
        
        self.contenView.addSubview(recordVoiceBtn)
        recordVoiceBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalTo(self.leftStackView.snp.right).offset(25)
            m.right.equalTo(self.rightStackView.snp.left).offset(-40)
            m.height.equalTo(40)
        }
        
        self.contenView.addSubview(bannedView)
        bannedView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.superview?.layoutIfNeeded()
    }
    
    /// 隐藏/显示右侧"更多(+)"按钮
    func setMoreBtnHidden(_ hidden: Bool) {
        self.moreBtn.isHidden = hidden
        let width = hidden ? 50 : 100
        self.rightStackViewWidth = width
        self.rightStackViewWidthConstraint?.update(offset: width)
    }
    
    // 点击引用视图删除事件
    @objc private func clickDeleteAction() {
        
        self.referenceLab.text = nil
        self.referenceThumbView.isHidden = true
        self.referenceThumbView.image = nil
        self.referenceThumbToken += 1
        self.referenceLabRightConstraint?.update(offset: -10)
        resetReferenceViewHeight(type: 0)
        
//        self.clickDeleteReferenceBlock?()
        self.delegate?.inputBarViewDeleteReference()
        self.notifySpaceToBottom()
    }
    
    /// 设置引用视图高度
    /// - Parameter type: 0：隐藏引用视图 1：引用内容为1行文字；2：引用内容为2行文字；
    private func resetReferenceViewHeight(type: Int) {
        var height = 0
        if type == 1 {
            height = 50
        } else if type == 2 {
            height = 70
        }
        
        self.referenceView.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
    }
    
    // 设置引用消息文字
    func referenceMsgStr(_ contStr: String) {
        self.referenceLab.text = contStr

        let height = contStr.getContentHeight(font: referenceLab.font, width: k_ScreenWidth - 80)// 一行：16.8 2行：33.6

        self.resetReferenceViewHeight(type: height > 20 ? 2 : 1)
        self.notifySpaceToBottom()
    }

    /// 设置引用条（带缩略图）：图片/视频显示缩略图，文件显示类型图标
    func setReference(_ preview: QuotePreview) {
        // 有缩略图时给文字让出右侧空间
        let trailing = -(10 + (preview.media.exists ? QuoteBlockMetrics.thumbSide + 8 : 0))
        self.referenceLabRightConstraint?.update(offset: trailing)
        self.referenceThumbView.isHidden = !preview.media.exists
        self.loadReferenceThumb(preview.media)
        self.referenceMsgStr(preview.barText)
    }

    /// 加载引用条缩略图（与气泡下方引用条同一套取图逻辑）
    private func loadReferenceThumb(_ media: QuoteMedia) {
        self.referenceThumbToken += 1
        let token = self.referenceThumbToken
        self.referenceThumbView.kf.cancelDownloadTask()
        self.referenceThumbView.image = nil
        self.referenceThumbView.contentMode = .scaleAspectFill
        self.referenceThumbView.backgroundColor = UIColor.init(hexString: "#8A97A5", transparency: 0.12)
        guard media.exists else { return }

        switch media {
        case .none:
            break
        case .photo(let cacheKey, let url):
            self.loadCachedThumb(cacheKey) { [weak self] image in
                guard let self = self, self.referenceThumbToken == token else { return }
                if let image = image {
                    self.referenceThumbView.image = image
                } else if let urlString = url, let url = URL(string: urlString) {
                    self.referenceThumbView.kf.setImage(
                        with: url,
                        options: [
                            .processor(
                                DownsamplingImageProcessor(
                                    size: CGSize(width: 64, height: 64))),
                            .targetCache(ChatMediaCache)
                        ])
                }
            }
        case .video(let cacheKey):
            self.loadCachedThumb(cacheKey) { [weak self] image in
                guard let self = self, self.referenceThumbToken == token else { return }
                self.referenceThumbView.image = image
            }
        case .file(let iconName):
            self.referenceThumbView.contentMode = .scaleAspectFit
            self.referenceThumbView.backgroundColor = .clear
            self.referenceThumbView.image =
                UIImage.init(named: iconName ?? "") ?? UIImage.init(named: "chat_file_default")
        }
    }

    private func loadCachedThumb(_ key: String?, completion: @escaping (UIImage?) -> Void) {
        guard let key = key, !key.isBlank else {
            completion(nil)
            return
        }
        ChatMediaCache.safeRetrieveImage(forKey: key, maxPixelSize: 200) { image in
            completion(image)
        }
    }

    /// 清空引用条（发送成功后 / 外部取消引用）
    func clearReference() {
        guard self.referenceLab.text != nil else { return }
        self.referenceLab.text = nil
        self.referenceThumbView.isHidden = true
        self.referenceThumbView.kf.cancelDownloadTask()
        self.referenceThumbView.image = nil
        self.referenceThumbToken += 1
        self.referenceLabRightConstraint?.update(offset: -10)
        self.resetReferenceViewHeight(type: 0)
        self.layoutIfNeeded()
        self.notifySpaceToBottom()
    }

    /// 引用条高度变化后，把「输入框到屏幕底」的占用高度同步给聊天列表 ——
    /// 不通知的话列表底部 inset 不跟着变，气泡会被引用条压住。
    private func notifySpaceToBottom() {
        guard let superview = self.superview else { return }
        superview.layoutIfNeeded()
        self.changeSpaceToBottom?(superview.height - self.frame.origin.y)
    }
    
    private func setRecordActions() {
        //按下按钮
        recordVoiceBtn.rx.controlEvent(.touchDown).subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.recordHub.type = .recording
            strongSelf.superview?.addSubview(strongSelf.recordHub)
            strongSelf.recordHub.snp.remakeConstraints({ (m) in
                m.centerY.equalToSuperview()
                m.centerX.equalToSuperview()
            })
            guard let path = FZMLocalFileClient.shared().createFile(with: .wav(fileName: String.getTimeStampStr())) else { return }
            strongSelf.recordHelper.startRecordingWithPath(path) { () -> Void in

            }
        }).disposed(by: disposeBag)
        
        //点击开始到结束
        recordVoiceBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
                self?.endRecordVoiceSend()
        }).disposed(by: disposeBag)
        
        //松开按钮
        recordVoiceBtn.rx.controlEvent(.touchUpOutside).subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            self?.recordHub.removeFromSuperview()
            guard let recordPath = strongSelf.recordHelper.recordPath else {
                return
            }
            if strongSelf.lastSendVoicePath != recordPath {
                self?.recordHelper.cancelledDeleteWithCompletion()
            }
        }).disposed(by: disposeBag)
        //取消发送
        recordVoiceBtn.rx.controlEvent(.touchDragExit).subscribe(onNext: {[weak self] (_) in
            self?.recordHub.type = .cancel
        }).disposed(by: disposeBag)
        //录音
        recordVoiceBtn.rx.controlEvent(.touchDragEnter).subscribe(onNext: {[weak self] (_) in
            self?.recordHub.type = .recording
        }).disposed(by: disposeBag)
    }
    
    private func endRecordVoiceSend(){
        guard let recordPath = self.recordHelper.recordPath else {
            return
        }
        if self.lastSendVoicePath == recordPath {
            return
        }
        self.lastSendVoicePath = recordPath
        self.recordHelper.finishRecordingCompletion()
        guard let duration = self.recordHelper.recordDuration, let durationNumber = Double(duration), durationNumber >= 1 else {
            self.recordHub.type = .shortTime
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.recordHub.removeFromSuperview()
            })
            return
        }
        self.recordHub.removeFromSuperview()
        UIApplication.shared.keyWindow?.showProgress(with: L("处理中"))
        DispatchQueue.global().async {
            guard let filename = self.recordHelper.recordPath?.fileName(), let amrPath = FZMLocalFileClient.shared().createFile(with: .amr(fileName: filename)), let recordpath = self.recordHelper.recordPath else { return }
            let result = TSVoiceConverter.convertWavToAmr(recordpath, amrSavePath: amrPath)
            DispatchQueue.main.async {
                UIApplication.shared.keyWindow?.hideProgress()
                if result {
                    self.delegate?.audioBarView(self, amrPath: amrPath, wavPath: self.recordHelper.recordPath!, duration: durationNumber)
                } else {
                    FZMLog("转码失败")
                }
            }
        }
    }
    
    //成员禁言
    func bannedAction(with time: Double,type:Int) {
        guard type == 0 else {
            //全员禁言
            bannedView.isHidden = false
            FZMAnimationTool.removeCountdown(with: bannedView)
            bannedView.text = L("全员禁言")
            return
        }
        
        //单个禁言
        if time > 0 {
            bannedView.isHidden = false
            if time > k_OnedaySeconds {
                bannedView.text = L("禁言中")
            } else {
                let formatter = DateFormatter.getDataformatter()
                formatter.dateFormat = "HH:mm:ss"
                FZMAnimationTool.countdown(with: bannedView, fromValue: time, toValue: 0, block: { [weak self] (useTime) in
                    let time = useTime - 8 * 3600
                    let date = Date.init(timeIntervalSince1970: TimeInterval(time))
                    self?.bannedView.text = L("禁言中 ") + formatter.string(from: date)
                    },finishBlock: {[weak self] in
                        self?.bannedView.isHidden = true
                })
            }
        } else {
            bannedView.isHidden = true
            FZMAnimationTool.removeCountdown(with: bannedView)
        }
    }
    
    // 添加 @ 数据，添加 @谁 文本
    func addAt(_ item: FZMInputAtItem) {
        guard let range = self.inputTextView.textView.selectedTextRange else { return }
        self.atCache.add(item)
        self.inputTextView.textView.replace(range, withText: item.name)
    }
    
    // 输入 @ 后弹出选择群成员视图
    private func showSelectAtGroupMemberVC(from startRange: NSRange) {
        guard let group = self.group else { return }
        let vc = FZMAtPeopleVC.init(with: group,fromTag: 0)
        vc.selectedBlock = {[weak self] (uid, name) in
            guard let strongSelf = self else { return }
            // 选择完群成员
            let atItem = FZMInputAtItem.init(uid: uid, name: name, startIndex: startRange.location)
            strongSelf.addAt(atItem)
            strongSelf.inputTextView.textView.becomeFirstResponder()
        }
        vc.cancelBlock = {[weak self] in
            // 取消 @ 群成员
            guard let strongSelf = self else { return }
            strongSelf.inputTextView.textView.becomeFirstResponder()
        }
        UIViewController.current()?.present(FZMNavigationController.init(rootViewController: vc), animated: true, completion: nil)
    }
    
    // 非输入文字 @ 方式  1.群聊长按头像；2.引用消息
    func mentionGroupMember(with groupId: Int, msg: Message) {
        let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: msg.fromId)
        let selectedRange = self.inputTextView.textView.selectedRange
        let atItem = FZMInputAtItem.init(uid: msg.fromId, name: member?.atName ?? msg.fromId.shortAddress, startIndex: selectedRange.length)
        
        self.atCache.add(atItem)
        if let textRange = self.inputTextView.textView.selectedTextRange {
            self.inputTextView.textView.replace(textRange, withText: atItem.name)
        }
        
        self.inputTextView.textView.becomeFirstResponder()
    }
    
    // 判断删除的内容是否是 @谁
    private func getDeleteAtRange(in text: String) -> NSRange? {
        guard let range = self.atCache.atItemRang(in: text) else { return nil}
        return range
    }
    
}

extension InputBarView {
    private func observeHeight() {
        
        self.inputTextView.delegates.willChangeHeight = {[weak self] (textViewHeight) in
            guard let self = self, let superview = self.superview else { return }
            
            let isOneLine = textViewHeight < 30
            let topOffset = isOneLine ? self.textContenViewInsetDefault.top : 1
            let bottomOffset = isOneLine ? self.textContenViewInsetDefault.bottom : 1
            
            let oldSpaceToBottom = superview.height - self.frame.origin.y
            let newSpaceToBottom = oldSpaceToBottom - self.inputTextView.height - self.textContenViewInsetCurrent.vertical + topOffset + bottomOffset + textViewHeight
            self.changeSpaceToBottom?(newSpaceToBottom)
            
            self.textContenViewInsetCurrent.top = topOffset
            self.textContenViewInsetCurrent.bottom = bottomOffset
            self.textContenView.snp.updateConstraints { (m) in
                m.top.equalToSuperview().offset(self.textContenViewInsetCurrent.top)
                m.bottom.equalToSuperview().offset(-self.textContenViewInsetCurrent.bottom)
            }
            self.inputTextViewHeightConstraint?.update(offset: textViewHeight)
            
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                self.superview?.layoutIfNeeded()
            } completion: { (_) in }
        }
    }
}

extension InputBarView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        if text == "\n" {
            if let text = self.inputTextView.textView.text, text.count > 0 {
                
                let isWhitespaceText = text.allSatisfy { $0.isWhitespace }
                
                guard !isWhitespaceText else { return false }
                
                // 获取 @ 成员ID数据（根据 '@ + 昵称 + \u{2004}' 格式匹配，如果与选择的 @谁 昵称不匹配则排除，此步骤是为了排除选择 @ 对象后删除部分昵称文字）
                let atUids = self.atCache.getAllAtUids(by:self.inputTextView.textView.text)
                self.delegate?.inputBarView(self, sendText: text, mentionIds: atUids)
                // 键盘点击发送（换行）按钮后重置输入框 和 @谁 数据
                self.atCache.clear()
                textView.text = nil
                
                return false
            }
            
            return true
        }
        
        // 群聊时输入'@'字符，显示 @ 列表
        if let _ = group, text == "@" {
            self.showSelectAtGroupMemberVC(from: range)
            return false
        }
        
        // 判断是否删除 @谁 文本的末尾，是则删除整个 @谁 内容
        if let _ = group, text == "", range.length == 1 {
            // 截取到未删除前光标所在位置之前的所有文本
            // 注意：range.location 是 NSRange 的 UTF-16 位置，必须用 NSString 语义操作，且需越界保护
            let nsText = self.inputTextView.textView.text as NSString
            let location = range.location + 1// UTF-16 位置
            guard location >= 0, location <= nsText.length else { return true }
            let subInputText = nsText.substring(to: location)
            if let needDelRange = self.getDeleteAtRange(in: subInputText) {
                let deletedAtInputText = (subInputText as NSString).replacingCharacters(in: needDelRange, with: "")
                let fromLocation = location
                DispatchQueue.main.async {
                    let currentText = textView.text as NSString
                    let tail = fromLocation <= currentText.length ? currentText.substring(from: fromLocation) : ""
                    textView.text = deletedAtInputText + tail
                    textView.selectedRange = NSRange.init(location: (deletedAtInputText as NSString).length, length: 0)
                }
                return false
            }
        }
        
        return true
    }
}

extension InputBarView: CustomEmojiDelegate {
    func didClickEmojiLabel(_ emojiStr: String) {
        let textRange = self.inputTextView.textView.selectedTextRange
        self.inputTextView.textView.replace(textRange!, withText: emojiStr)
    }
    
    func didClickSendEmojiBtn() {
        let text = self.inputTextView.textView.text
        if text?.isBlank == true{
            self.showToast(L("不能发送空白信息"))
            return
        }
        self.delegate?.inputBarView(self, sendText: self.inputTextView.textView.text, mentionIds: [])
        self.inputTextView.textView.text = nil
    }
    
    func didDeleteEmojiBtn() {
        self.inputTextView.textView.deleteBackward()
    }
    
    func lastRange(str:String) ->NSRange{
        let range =  str.rangeOfComposedCharacterSequence(at: str.index(before: str.endIndex))
        let nsLastRange = "".nsRange(from: range)
        return nsLastRange
    }
}

extension InputBarView{
    @objc func emojiBtnAction(_ sender:UIButton){
        sender.isSelected = !sender.isSelected

        if sender.isSelected {
            self.inputTextView.textView.inputView = self.emojiView
        } else {
            self.inputTextView.textView.inputView = nil
        }
        self.inputTextView.textView .reloadInputViews()
        
        if !self.inputTextView.textView.isFirstResponder {
            self.inputTextView.textView.becomeFirstResponder()
        }
    }
}
