//
//  ForwardMessageCell.swift
//  chat
//
//  合并转发（msgType = 8）的消息卡片：标题「聊天记录」+ 最多 4 条摘要 + 底部条数。
//  点开进详情页（`ForwardDetailVC`，由 `ChatVC.didTapMessage` 处理）。
//

import Kingfisher
import SnapKit
import UIKit

/// 卡片尺寸常量 —— cell 布局与 `ForwardMessageSizeCalculator` **必须**共用这一份，
/// 否则卡片内容与算出来的高度会对不上（气泡被裁 / 底部留白）。
enum ForwardCardMetrics {
    static let width: CGFloat = 230  // 卡片宽度
    static let paddingH: CGFloat = 12  // 左右内边距
    static let paddingV: CGFloat = 12  // 上下内边距
    static let titleHeight: CGFloat = 20  // 标题行高
    static let titleGap: CGFloat = 8  // 标题与列表之间
    static let lineHeight: CGFloat = 18  // 每条摘要的行高
    static let maxPreviewCount = 4  // 最多预览几条
    static let footerGap: CGFloat = 6  // 列表与底部之间
    static let footerHeight: CGFloat = 18  // 底部「查看全部」行高
}

class ForwardMessageCell: MessageContentCell {

    private let titleLabel: UILabel = {
        let lab = UILabel.init()
        lab.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lab.textColor = Color_24374E
        lab.numberOfLines = 1
        lab.text = L("聊天记录")
        return lab
    }()

    /// 摘要行（固定 4 条，多出来的隐藏）
    private lazy var lineLabels: [UILabel] = {
        var arr = [UILabel]()
        for _ in 0..<ForwardCardMetrics.maxPreviewCount {
            let lab = UILabel.init()
            lab.font = UIFont.systemFont(ofSize: 12)
            lab.textColor = Color_8A97A5
            lab.numberOfLines = 1
            lab.lineBreakMode = .byTruncatingTail
            arr.append(lab)
        }
        return arr
    }()

    private let footerLabel: UILabel = {
        let lab = UILabel.init()
        lab.font = UIFont.systemFont(ofSize: 12)
        lab.textColor = Color_8A97A5
        lab.numberOfLines = 1
        return lab
    }()

    private let verticalLine: UIView = {
        let view = UIView.init()
        view.backgroundColor = Color_F6F7F8
        return view
    }()

    override func setupViews() {
        super.setupViews()

        // ⚠️ 顺序：先 addSubview 再建互相引用的约束（父子关系没建立就激活约束会直接崩）
        self.messageContainerView.addSubview(verticalLine)
        self.messageContainerView.addSubview(titleLabel)
        lineLabels.forEach { self.messageContainerView.addSubview($0) }
        self.messageContainerView.addSubview(footerLabel)

        titleLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(ForwardCardMetrics.paddingH)
            m.right.equalToSuperview().offset(-ForwardCardMetrics.paddingH)
            m.top.equalToSuperview().offset(ForwardCardMetrics.paddingV)
            m.height.equalTo(ForwardCardMetrics.titleHeight)
        }

        // ⚠️ 每条摘要用「标题底 + 固定偏移」定位（**不**逐条累积约束），
        //    这样行位置只由常量决定，和 `ForwardMessageSizeCalculator` 算出的高度严格一致
        for (index, label) in lineLabels.enumerated() {
            let lineOffset: CGFloat =
                ForwardCardMetrics.titleGap + CGFloat(index) * ForwardCardMetrics.lineHeight
            label.snp.makeConstraints { (m) in
                m.left.equalTo(titleLabel).offset(8)
                m.right.equalTo(titleLabel)
                m.top.equalTo(titleLabel.snp.bottom).offset(lineOffset)
                m.height.equalTo(ForwardCardMetrics.lineHeight)
            }
        }

        // 底部贴底：卡片高度由尺寸计算给出，footer 不需要知道中间放了几条
        footerLabel.snp.makeConstraints { (m) in
            m.left.right.equalTo(titleLabel)
            m.bottom.equalToSuperview().offset(-ForwardCardMetrics.paddingV)
            m.height.equalTo(ForwardCardMetrics.footerHeight)
        }

        verticalLine.snp.makeConstraints { (m) in
            m.left.equalTo(titleLabel)
            m.width.equalTo(3)
            m.top.equalTo(titleLabel.snp.bottom).offset(ForwardCardMetrics.titleGap)
            m.bottom.equalTo(footerLabel.snp.top).offset(-ForwardCardMetrics.footerGap)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = L("聊天记录")
        lineLabels.forEach { $0.text = nil }
        footerLabel.text = nil
    }

    override func configure(
        with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView
    ) {
        super.configure(with: message, at: indexPath, and: messageCollectionView)

        let items = message.msgType.forwardItems ?? []
        titleLabel.text = L("聊天记录")

        let previewCount = min(items.count, ForwardCardMetrics.maxPreviewCount)
        for (index, label) in lineLabels.enumerated() {
            guard index < previewCount else {
                label.isHidden = true
                label.text = nil
                continue
            }
            let item = items[index]
            label.isHidden = false
            label.text = item.name + "：" + item.summaryText
        }

        footerLabel.text = L("查看全部") + " \(items.count) " + L("条消息")

        // 合并转发卡片不显示群昵称 / 身份标签（否则群聊里会在卡片上叠出一个「群主」）
        nameView.isHidden = true
    }
}
