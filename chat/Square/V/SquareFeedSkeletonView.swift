//
//  SquareFeedSkeletonView.swift
//  chat
//
//  广场骨架屏（两个）：
//  - `SquareFeedSkeletonView`：列表形态（广场流 / 作者页 / 我的信息页），几条帖子占位
//  - `SquarePostDetailSkeletonView`：帖子详情页，一条帖子 + 评论标题 + 三条评论
//  占位结构与真实布局一致（头像 · 昵称 · 时间 · 正文 · 图片 · 操作栏），只是把内容换成灰条 + 呼吸动画。
//

import Foundation
import UIKit

final class SquareFeedSkeletonView: UIView {

    /// 占位条数：3 条足够铺满常见可视区域，多出来的部分被裁掉
    private static let rowCount = 3

    private var rows = [SquareFeedSkeletonRow]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = Color_FFFFFF
        self.clipsToBounds = true
        for _ in 0..<SquareFeedSkeletonView.rowCount {
            let row = SquareFeedSkeletonRow()
            addSubview(row)
            rows.append(row)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        for (index, row) in rows.enumerated() {
            row.frame = CGRect(x: 0,
                               y: SquareFeedSkeletonRow.height * CGFloat(index),
                               width: width,
                               height: SquareFeedSkeletonRow.height)
        }
    }

    // MARK: - 动效

    func startAnimating() {
        rows.forEach { $0.startAnimating() }
    }

    func stopAnimating() {
        rows.forEach { $0.stopAnimating() }
    }
}

// MARK: - 单条骨架帖

private final class SquareFeedSkeletonRow: UIView {

    /// 行高：按 375pt 宽算出来的一条帖子的高度
    static let height: CGFloat = 250

    /// 占位灰（比分割线略深一点，白底上看得清）
    private static let placeholderColor = UIColor(hex: 0xEDF0F3)

    private let avatarBar = SquareFeedSkeletonRow.makeBar(cornerRadius: 20)
    private let nameBar = SquareFeedSkeletonRow.makeBar(cornerRadius: 6)
    private let timeBar = SquareFeedSkeletonRow.makeBar(cornerRadius: 5)
    private let lineBar1 = SquareFeedSkeletonRow.makeBar(cornerRadius: 6)
    private let lineBar2 = SquareFeedSkeletonRow.makeBar(cornerRadius: 6)
    private let imageBar1 = SquareFeedSkeletonRow.makeBar(cornerRadius: 6)
    private let imageBar2 = SquareFeedSkeletonRow.makeBar(cornerRadius: 6)
    private let imageBar3 = SquareFeedSkeletonRow.makeBar(cornerRadius: 6)
    private let actionBar1 = SquareFeedSkeletonRow.makeBar(cornerRadius: 5)
    private let actionBar2 = SquareFeedSkeletonRow.makeBar(cornerRadius: 5)
    private let actionBar3 = SquareFeedSkeletonRow.makeBar(cornerRadius: 5)

    private lazy var bars: [UIView] = {
        return [avatarBar, nameBar, timeBar, lineBar1, lineBar2, imageBar1, imageBar2, imageBar3,
                actionBar1, actionBar2, actionBar3]
    }()

    private lazy var divider: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()

    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Color_FFFFFF
        bars.forEach { addSubview($0) }
        addSubview(divider)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = SquarePostCell.contentInset
        let leading = SquarePostCell.textLeading
        let contentWidth = bounds.width - leading - inset
        guard contentWidth > 0 else { return }

        avatarBar.frame = CGRect(x: inset, y: 14, width: 40, height: 40)
        nameBar.frame = CGRect(x: leading, y: 20, width: min(96, contentWidth * 0.42), height: 12)
        timeBar.frame = CGRect(x: nameBar.frame.maxX + 10, y: 21, width: 46, height: 10)

        lineBar1.frame = CGRect(x: leading, y: 66, width: contentWidth, height: 12)
        lineBar2.frame = CGRect(x: leading, y: 86, width: contentWidth * 0.62, height: 12)

        // 三张图方块（与九宫格同一套尺寸）
        let side = ceil((contentWidth - 12) / 3)
        let imageY: CGFloat = 110
        imageBar1.frame = CGRect(x: leading, y: imageY, width: side, height: side)
        imageBar2.frame = CGRect(x: imageBar1.frame.maxX + 6, y: imageY, width: side, height: side)
        imageBar3.frame = CGRect(x: imageBar2.frame.maxX + 6, y: imageY, width: side, height: side)

        let actionY = imageY + side + 14
        actionBar1.frame = CGRect(x: leading, y: actionY, width: 46, height: 12)
        actionBar2.frame = CGRect(x: actionBar1.frame.maxX + 20, y: actionY, width: 46, height: 12)
        actionBar3.frame = CGRect(x: actionBar2.frame.maxX + 20, y: actionY, width: 46, height: 12)

        divider.frame = CGRect(x: inset, y: bounds.height - 0.5, width: max(bounds.width - inset * 2, 0), height: 0.5)
    }

    // MARK: - 动效

    /// 呼吸动画：整块占位在 1 → 0.45 之间来回，看起来就是「正在加载」
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        for (index, bar) in bars.enumerated() {
            bar.layer.removeAllAnimations()
            bar.alpha = 1
            UIView.animate(withDuration: 0.7,
                           delay: Double(index % 4) * 0.05,
                           options: [.repeat, .autoreverse, .curveEaseInOut, .allowUserInteraction]) {
                bar.alpha = 0.45
            }
        }
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        for bar in bars {
            bar.layer.removeAllAnimations()
            bar.alpha = 1
        }
    }

    private static func makeBar(cornerRadius: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = SquareFeedSkeletonRow.placeholderColor
        view.layer.cornerRadius = cornerRadius
        view.clipsToBounds = true
        return view
    }
}

// MARK: - 帖子详情页骨架

/// 详情页骨架：**一条帖子 + 「评论」标题 + 三条评论**。
/// 详情页不是列表，用广场那种「好几条帖子」的骨架不对版，所以单独做一个：
/// - 帖子：头像 / 昵称 / 时间 / 正文三行 / 三张图 / 操作栏（点赞·评论·阅读 + 右侧分享图标）
///   —— 详情页正文与头像**左对齐**（leading = contentInset），这里也按那个来
/// - 评论：小头像 / 昵称 / 两行正文 / 中间一条分割线（条数取 3，刚好铺满一屏，多的被裁掉）
final class SquarePostDetailSkeletonView: UIView {

    /// 占位灰（与列表骨架同一个色）
    private static let placeholderColor = UIColor(hex: 0xEDF0F3)
    /// 评论条数（3 条刚好铺满一屏，多的部分被裁掉）
    private static let commentCount = 3

    private let postAvatar = SquarePostDetailSkeletonView.makeBar(cornerRadius: 20)
    private let postName = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postTime = SquarePostDetailSkeletonView.makeBar(cornerRadius: 5)
    private let postLine1 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postLine2 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postLine3 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postImage1 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postImage2 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postImage3 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 6)
    private let postAction1 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 5)
    private let postAction2 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 5)
    private let postAction3 = SquarePostDetailSkeletonView.makeBar(cornerRadius: 5)
    private let postShare = SquarePostDetailSkeletonView.makeBar(cornerRadius: 8)
    private let commentTitle = SquarePostDetailSkeletonView.makeBar(cornerRadius: 7)
    private var commentAvatars = (0..<SquarePostDetailSkeletonView.commentCount).map { _ in SquarePostDetailSkeletonView.makeBar(cornerRadius: 16) }
    private var commentNames = (0..<SquarePostDetailSkeletonView.commentCount).map { _ in SquarePostDetailSkeletonView.makeBar(cornerRadius: 5) }
    private var commentLines1 = (0..<SquarePostDetailSkeletonView.commentCount).map { _ in SquarePostDetailSkeletonView.makeBar(cornerRadius: 6) }
    private var commentLines2 = (0..<SquarePostDetailSkeletonView.commentCount).map { _ in SquarePostDetailSkeletonView.makeBar(cornerRadius: 6) }
    private var commentDividers = (0..<SquarePostDetailSkeletonView.commentCount).map { _ in SquarePostDetailSkeletonView.makeDivider() }

    private lazy var bars: [UIView] = {
        var list: [UIView] = [postAvatar, postName, postTime, postLine1, postLine2, postLine3,
                              postImage1, postImage2, postImage3,
                              postAction1, postAction2, postAction3, postShare, commentTitle]
        list.append(contentsOf: commentAvatars)
        list.append(contentsOf: commentNames)
        list.append(contentsOf: commentLines1)
        list.append(contentsOf: commentLines2)
        return list
    }()

    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Color_FFFFFF
        clipsToBounds = true
        bars.forEach { addSubview($0) }
        commentDividers.forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0 else { return }
        let inset = SquarePostCell.contentInset
        // 详情页的正文 / 图片 / 操作栏都与头像左对齐（leading = contentInset）
        let contentWidth = width - inset * 2
        guard contentWidth > 0 else { return }

        // 1) 帖子：头像 + 昵称 + 时间
        var y: CGFloat = 14
        postAvatar.frame = CGRect(x: inset, y: y, width: 40, height: 40)
        postName.frame = CGRect(x: inset + 50, y: y + 6, width: min(96, contentWidth * 0.36), height: 12)
        postTime.frame = CGRect(x: width - inset - 46, y: y + 7, width: 46, height: 10)
        y = postAvatar.frame.maxY + 12

        // 2) 正文三行（末行短一点）
        postLine1.frame = CGRect(x: inset, y: y, width: contentWidth, height: 12)
        postLine2.frame = CGRect(x: inset, y: y + 20, width: contentWidth, height: 12)
        postLine3.frame = CGRect(x: inset, y: y + 40, width: contentWidth * 0.62, height: 12)
        y += 62

        // 3) 三张图（与列表九宫格同一套尺寸）
        let side = ceil((contentWidth - 12) / 3)
        postImage1.frame = CGRect(x: inset, y: y, width: side, height: side)
        postImage2.frame = CGRect(x: postImage1.frame.maxX + 6, y: y, width: side, height: side)
        postImage3.frame = CGRect(x: postImage2.frame.maxX + 6, y: y, width: side, height: side)
        y += side + 16

        // 4) 操作栏：点赞 / 评论 / 阅读 + 右侧分享图标
        postAction1.frame = CGRect(x: inset, y: y, width: 46, height: 12)
        postAction2.frame = CGRect(x: inset + 66, y: y, width: 46, height: 12)
        postAction3.frame = CGRect(x: inset + 132, y: y, width: 46, height: 12)
        postShare.frame = CGRect(x: width - inset - 17, y: y - 3, width: 17, height: 17)
        y += 20 + 18

        // 5) 「评论 N」标题
        commentTitle.frame = CGRect(x: inset, y: y + 15, width: 64, height: 14)
        y += 15 + 14 + 16

        // 6) 两条评论：小头像 + 昵称 + 两行正文（中间一条分割线）
        let avatarSide: CGFloat = 32
        let textLeft = inset + avatarSide + 10
        let textWidth = max(width - inset - textLeft, 40)
        for index in 0..<SquarePostDetailSkeletonView.commentCount {
            commentAvatars[index].frame = CGRect(x: inset, y: y, width: avatarSide, height: avatarSide)
            commentNames[index].frame = CGRect(x: textLeft, y: y + 4, width: min(72, textWidth * 0.45), height: 10)
            commentLines1[index].frame = CGRect(x: textLeft, y: y + 26, width: textWidth, height: 10)
            commentLines2[index].frame = CGRect(x: textLeft, y: y + 42, width: textWidth * 0.55, height: 10)
            if index < SquarePostDetailSkeletonView.commentCount - 1 {
                commentDividers[index].frame = CGRect(x: inset, y: y + 66, width: contentWidth, height: 0.5)
            }
            y += 80
        }
    }

    // MARK: - 动效

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        for (index, bar) in bars.enumerated() {
            bar.layer.removeAllAnimations()
            bar.alpha = 1
            UIView.animate(withDuration: 0.7,
                           delay: Double(index % 5) * 0.04,
                           options: [.repeat, .autoreverse, .curveEaseInOut, .allowUserInteraction]) {
                bar.alpha = 0.45
            }
        }
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        for bar in bars {
            bar.layer.removeAllAnimations()
            bar.alpha = 1
        }
    }

    private static func makeBar(cornerRadius: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = SquarePostDetailSkeletonView.placeholderColor
        view.layer.cornerRadius = cornerRadius
        view.clipsToBounds = true
        return view
    }

    private static func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }
}
