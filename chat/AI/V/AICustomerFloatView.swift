//
//  AICustomerFloatView.swift
//  chat
//
//  消息页「AI 客服」可拖动悬浮球。
//
//  - 默认位置在右下角**上方**：广场段右下角已有「发帖」悬浮按钮
//    （SquareFeedPageView.createBtn，right -18 / bottom -18，56×56），刻意避让避免叠住。
//  - 拖动后松手吸附左右边，位置按归一化坐标持久化（重启保持）。
//  - 显隐由宿主控制：**现在挂在 `FZMTabBarController` 上**（切 Tab 都在，push 进二级页面时隐藏），
//    规则见 `FZMTabBarController.updateFloatingAIVisibility()`。
//

import UIKit

final class AICustomerFloatView: UIButton {

    static let side: CGFloat = 56
    /// 与屏幕边缘的最小留白
    private static let edgeInset: CGFloat = 6
    /// 拖到边界时与边缘的距离（吸边后的 x）
    private static let snappedEdgeInset: CGFloat = 6

    /// 点击回调（打开客服页）
    var onTap: (() -> Void)?

    /// 拖动开始时的中心点
    private var dragStartCenter: CGPoint = .zero
    /// 上一次已知的容器尺寸与安全区（只在两者变化时重排，避免拖动过程中被布局回调拉回）
    private var lastContainerSize: CGSize = .zero
    private var lastSafeAreaInsets: UIEdgeInsets = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = Color_Theme
        layer.cornerRadius = Self.side / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        tintColor = Color_FFFFFF

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        setImage(UIImage(systemName: "headphones", withConfiguration: config)?.withRenderingMode(.alwaysTemplate),
                 for: .normal)

        accessibilityLabel = L("AI 客服")

        addTarget(self, action: #selector(tapAction), for: .touchUpInside)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    // MARK: - 安装与定位

    /// 挂到宿主视图最上层并定位。
    func install(in container: UIView) {
        container.addSubview(self)
        bounds = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        center = resolvedCenter(in: container.bounds, insets: container.safeAreaInsets)
        lastContainerSize = container.bounds.size
        lastSafeAreaInsets = container.safeAreaInsets
    }

    /// 容器尺寸 / 安全区变化后重新贴边（旋转、分屏、首次布局等；两者都没变则什么都不做）。
    ///
    /// 注意：`viewDidLoad` 阶段 `safeAreaInsets` 往往还是 0，所以必须把 inset 也纳入判断，
    /// 否则首次布局完成后不会重排，悬浮球会停得偏低（压到 TabBar 上）。
    func relayoutInContainer() {
        guard let container = superview else { return }
        let size = container.bounds.size
        let insets = container.safeAreaInsets
        guard size != lastContainerSize || insets != lastSafeAreaInsets, size.width > 0 else { return }
        lastContainerSize = size
        lastSafeAreaInsets = insets
        center = resolvedCenter(in: container.bounds, insets: insets)
    }

    private func resolvedCenter(in bounds: CGRect, insets: UIEdgeInsets) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return center }

        if let normalized = AICustomerStore.floatButtonNormalizedCenter {
            return clamped(CGPoint(x: normalized.x * bounds.width, y: normalized.y * bounds.height),
                           in: bounds,
                           insets: insets)
        }

        // 默认位置：右下角往上让开「发帖」悬浮按钮（18 + 56 + 18，再留 16pt 间距）
        let defaultCenter = CGPoint(x: bounds.width - 18 - Self.side / 2,
                                    y: bounds.height - 18 - Self.side * 1.5 - 16)
        return clamped(defaultCenter, in: bounds, insets: insets)
    }

    private func clamped(_ point: CGPoint, in bounds: CGRect, insets: UIEdgeInsets) -> CGPoint {
        let half = Self.side / 2
        let minX = half + Self.edgeInset
        let maxX = max(minX, bounds.width - half - Self.edgeInset)
        let minY = insets.top + half + Self.edgeInset
        let maxY = max(minY, bounds.height - insets.bottom - half - Self.edgeInset)
        return CGPoint(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }

    // MARK: - 拖动

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let container = superview else { return }
        switch gesture.state {
        case .began:
            // 拖动一旦识别，UIPanGestureRecognizer 会取消 button 的触摸跟踪，
            // touchUpInside 不会再触发，所以不需要额外的「刚拖过」标记。
            dragStartCenter = center
        case .changed:
            let translation = gesture.translation(in: container)
            center = clamped(CGPoint(x: dragStartCenter.x + translation.x,
                                     y: dragStartCenter.y + translation.y),
                             in: container.bounds,
                             insets: container.safeAreaInsets)
        case .ended, .cancelled, .failed:
            snapToNearestEdge(in: container)
        default:
            break
        }
    }

    /// 松手吸附到最近的左右边，并保存归一化位置。
    private func snapToNearestEdge(in container: UIView) {
        let bounds = container.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let half = Self.side / 2
        let targetX: CGFloat = (center.x < bounds.width / 2)
            ? (half + Self.snappedEdgeInset)
            : (bounds.width - half - Self.snappedEdgeInset)
        let target = clamped(CGPoint(x: targetX, y: center.y), in: bounds, insets: container.safeAreaInsets)

        UIView.animate(withDuration: 0.2) {
            self.center = target
        }
        AICustomerStore.saveFloatButtonNormalizedCenter(CGPoint(x: target.x / bounds.width,
                                                                y: target.y / bounds.height))
    }

    // MARK: - 点击

    @objc private func tapAction() {
        onTap?()
    }
}
