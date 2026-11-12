//
//  VoiceRoomModeSheet.swift
//  chat
//
//  语音房模块 V 层：发起前的模式选择弹窗（当前只列「语音聊天」，见 options）
//  GitHub Copilot 生成
//

import SnapKit
import UIKit

/// 发起聊天室前的模式选择弹窗（微信风格：选项白卡 + 8pt 间隙 + 独立「取消」白卡）
///
/// ⚠️ 为什么不复用 `FZMBottomSelectView`（`chat/BusinessTool/FZMEditHeadImageVC/`）：
///    那个组件的「取消」是**和选项同一个卡片**里的最后一行，不是微信那种**独立分离**的取消卡片；
///    而且它已被「更换头像」在用 —— 改它会连带影响那个功能。
///    所以这里在语音房模块自己的 V 层单独写一个，两边互不影响。
final class VoiceRoomModeSheet: UIView {

    // MARK: 常量

    private static let rowHeight: CGFloat = 56
    private static let cornerRadius: CGFloat = 12
    /// 选项卡与「取消」卡之间的间隙
    private static let cardGap: CGFloat = 8
    /// 收起时内容整体下移的距离（只要大于自身高度即可）
    private static let hiddenOffset: CGFloat = 400

    // MARK: 数据

    /// 选项：**只保留「语音聊天」**（2026-10-16 用户要求去掉「视频聊天」一项）
    private let options: [VoiceRoomMode] = [.voice]
    /// 回调：选中的模式；点「取消」或遮罩返回 `nil`
    private let onSelect: (VoiceRoomMode?) -> Void

    private let dimmingView = UIView()
    private let contentView = UIView()

    // MARK: 初始化

    init(onSelect: @escaping (VoiceRoomMode?) -> Void) {
        self.onSelect = onSelect
        super.init(frame: k_ScreenBounds)
        backgroundColor = UIColor(white: 0, alpha: 0.5)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 从窗口弹出
    /// - Parameter host: 只用来优先取它所在的窗口，不参与层级
    static func show(from host: UIViewController? = nil, onSelect: @escaping (VoiceRoomMode?) -> Void) {
        guard let window = host?.view.window ?? UIApplication.shared.keyWindow else { return }
        let sheet = VoiceRoomModeSheet(onSelect: onSelect)
        window.addSubview(sheet)
        sheet.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        sheet.showAnimated()
    }

    // MARK: 布局

    private func setupViews() {
        // 遮罩单独放一层：手势挂它身上，点选项就不会被口袋里的手势抢走
        //（手势若挂在 self 上，点卡片里的按钮会「手势 + 按钮」双双触发）
        dimmingView.backgroundColor = .clear
        addSubview(dimmingView)
        dimmingView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimmingTap)))

        addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(Self.hiddenOffset)
        }

        // ① 选项卡片：白底、只圆上面两个角
        let optionsCard = UIView()
        optionsCard.backgroundColor = .white
        optionsCard.layer.cornerRadius = Self.cornerRadius
        optionsCard.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        optionsCard.clipsToBounds = true
        contentView.addSubview(optionsCard)
        optionsCard.snp.makeConstraints { (make) in
            make.left.right.top.equalToSuperview()
        }

        var previousRow: UIView?
        for (index, mode) in options.enumerated() {
            let row = makeRow(title: mode.title) { [weak self] in
                self?.dismiss(selecting: mode)
            }
            optionsCard.addSubview(row)
            row.snp.makeConstraints { (make) in
                make.left.right.equalToSuperview()
                make.height.equalTo(Self.rowHeight)
                if let previousRow = previousRow {
                    make.top.equalTo(previousRow.snp.bottom)
                } else {
                    make.top.equalToSuperview()
                }
            }
            // 行之间 0.5pt 分割线（最后一行不加）
            if index < options.count - 1 {
                let line = UIView()
                line.backgroundColor = Color_E6EAEE
                row.addSubview(line)
                line.snp.makeConstraints { (make) in
                    make.left.right.bottom.equalToSuperview()
                    make.height.equalTo(0.5)
                }
            }
            previousRow = row
        }
        if let previousRow = previousRow {
            optionsCard.snp.makeConstraints { (make) in
                make.bottom.equalTo(previousRow.snp.bottom)
            }
        }

        // ②「取消」独立卡片：与上面隔 8pt，四周圆角
        let cancelCard = makeRow(title: L("取消")) { [weak self] in
            self?.dismiss(selecting: nil)
        }
        cancelCard.layer.cornerRadius = Self.cornerRadius
        cancelCard.clipsToBounds = true
        contentView.addSubview(cancelCard)
        cancelCard.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(optionsCard.snp.bottom).offset(Self.cardGap)
            make.height.equalTo(Self.rowHeight)
            make.bottom.equalToSuperview().offset(-(Self.cardGap + k_SafeBottomInset))
        }
    }

    private func makeRow(title: String, tap: @escaping () -> Void) -> UIButton {
        let button = VoiceRoomModeRowButton(type: .custom)
        button.backgroundColor = .white
        button.setTitle(title, for: .normal)
        button.setTitleColor(Color_24374E, for: .normal)
        button.titleLabel?.font = UIFont.regularFont(17)
        button.addAction(UIAction { _ in tap() }, for: .touchUpInside)
        return button
    }

    // MARK: 弹出 / 收起

    private func showAnimated() {
        layoutIfNeeded()
        contentView.snp.updateConstraints { (make) in
            make.bottom.equalToSuperview().offset(0)
        }
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }

    @objc private func dimmingTap() {
        dismiss(selecting: nil)
    }

    private func dismiss(selecting mode: VoiceRoomMode?) {
        contentView.snp.updateConstraints { (make) in
            make.bottom.equalToSuperview().offset(Self.hiddenOffset)
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.layoutIfNeeded()
            self.backgroundColor = .clear
        }, completion: { _ in
            self.removeFromSuperview()
            self.onSelect(mode)
        })
    }
}

// MARK: - 行按钮（按下变灰，接近微信的手感）

private final class VoiceRoomModeRowButton: UIButton {
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor(white: 0.96, alpha: 1) : .white }
    }
}
