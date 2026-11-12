//
//  RedPacketTheme.swift
//  chat
//
//  红包模块统一视觉令牌（「红金奢华」）
//  只提供视图层能力：颜色 / 渐变 / 金色描边 / 发光 / 卡片阴影 / 数字字体。
//  不含任何业务逻辑，不改变任何接口与数据流。
//

import UIKit

/// 红包模块视觉令牌
enum RP {

    // ⚠️ 每个颜色都**必须显式标注 `: UIColor`**：
    // 工程里有 `init(hex: UInt32, alpha:)`（非可选，见 `chat/ProjectBase/Extension/UIColor+Tool.swift`），
    // 而 SwifterSwift 另有 `init?(hex: Int, transparency:)`（**可选**）—— 两者都被可见时，
    // 无类型注解的整数字面量会按 `Int` 解析而落到可选的 SwifterSwift 那个，
    // 导致常量变成 `UIColor?`，再放进 `[UIColor]` 就报
    // `Cannot convert value of type 'UIColor?' to expected element type 'UIColor'`。

    // MARK: - 红（渐变两端）
    // 取值演进：原版 #9E1226 → #E8515F（末端是**亮粉红**，大面积铺开很廉价 ✗）
    //          → v2-A 暗酒红 #7A1A24 → #9E2833（够高级，但真机看**太暗发闷** ✗）
    //          → 中国红 #BE1418 → #E52521（G/B 压到 13~16% 够鲜，但仍偏暗）
    //          → **现在：按用户给的参考图直接采样**（2026-09-28）。
    //
    //   ⚠️ 采样口径（别直接照抄截图的数值）：
    //   参考图 `截屏2026-09-28 14.51.42.png` 是 448×156 的**纯色圆角块**（中心区域 100% 同一色），
    //   它的 ICC 描述是 **Display P3**；不做色彩管理直接读到的是 `#D65C49`，
    //   换算到 sRGB 才是 **`#E75140`** —— 这个才是"看上去一样"的那个红。
    //   （iOS 的 `UIColor(hex:)` 是 sRGB 口径：直接填 P3 那组数值会**偏灰偏暗**，
    //    正是前几轮"看着还是太暗"的同一类坑。）
    //   三支令牌以采样值为中心、保持色相（G/R≈0.351、B/R≈0.277）上下各拉约 10%：
    //   深端 = 采样值 × 0.90 / 中 = 采样值 / 亮端 = 采样值 × 1.06
    //   ⇒ `primaryGradient`（深→亮）**两端的平均值 ≈ 采样值本身**，整块铺开就是参考图那个红。
    static let redDeep: UIColor = UIColor(hex: 0xD0493A)    // #E75140 × 0.90
    static let redMid: UIColor = UIColor(hex: 0xE75140)     // 参考图采样值（P3 → sRGB）
    static let redBright: UIColor = UIColor(hex: 0xF55644)  // #E75140 × 1.06

    // MARK: - 金（香槟金：**只做细线 / 小字**，不做大面积填充 —— 大面积黄就是廉价感来源）
    static let gold: UIColor = UIColor(hex: 0xC9A961)
    static let goldLight: UIColor = UIColor(hex: 0xE4CFA3)
    static let goldDeep: UIColor = UIColor(hex: 0x8A6E38)

    /// 红底上的**大面积金色填充**（红包弹窗的按钮底：「开」圆钮 / 「查看详情」胶囊）：
    /// 比 `gold`(#C9A961) 亮两档、比 `goldLight`(#E4CFA3) 亮一档，但仍留在香槟金色相里
    ///（用户 2026-09-28：「领取红包弹窗的金色亮一点」，原来的 `gold` 压在珊瑚红上发闷）。
    /// 字用 `goldDeep`，对比刚好够；只服务**红底大块**，白卡上仍用 `gold`/`goldLight`。
    static let goldBright: UIColor = UIColor(hex: 0xF2DCA8)

    /// 「收到的红包」金额色：微信收到红包金额那种**暖金（偏橙）**。
    /// ⚠️ 别拿 `gold` 代替（#C9A961 太灰太浅，白底会发虚），也别拿 `goldDeep`
    ///（#8A6E38 发褐，看着像脏的、不“金”）。
    static let incomeGold: UIColor = UIColor(hex: 0xE0A02A)

    // MARK: - 暖中性（卡片改纯白、页面底改中性暖灰，去掉黄）
    static let ink: UIColor = UIColor(hex: 0x2B2521)
    static let inkSoft: UIColor = UIColor(hex: 0x7D7268)
    static let cream: UIColor = UIColor(hex: 0xFFFFFF)
    static let creamLine: UIColor = UIColor(hex: 0xEAE5DE)
    static let pageBg: UIColor = UIColor(hex: 0xF2EFEB)

    // MARK: - 禁用态 / 提示文案
    // ⚠️ 禁用**不要**用「红渐变 + alpha」表达 —— 半透明的红会糊成**脏粉色**
    // （发红包页真机截图里最丑的一块，已改）。
    static let disabledBgTop: UIColor = UIColor(hex: 0xEBE7E1)
    static let disabledBgBottom: UIColor = UIColor(hex: 0xDDD7CE)
    static let onDisabled: UIColor = UIColor(hex: 0x9C9288)
    /// 输入框 / 提示文案色：中性暖灰。
    /// ⚠️ 别用 `inkSoft`（棕褐）—— 在奶油底上会被当成正文，显脏。
    static let placeholder: UIColor = UIColor(hex: 0xA79C92)

    // MARK: - 语义
    /// 主红渐变：按钮 / 头图 / 气泡
    static var primaryGradient: [UIColor] { [redDeep, redBright] }
    /// 禁用态渐变（中性暖灰，替代「红 + alpha」）
    static var disabledGradient: [UIColor] { [disabledBgTop, disabledBgBottom] }
    /// 细金线（卡片内嵌描边 / 胶囊描边用；金只做线和小字）
    static var goldHairline: UIColor { gold.withAlphaComponent(0.30) }
    /// 金色渐变：开红包按钮 / 强调元素
    static var goldGradient: [UIColor] { [goldLight, goldDeep] }
    /// 红底上最醒目的文字（大号金额）/ 图标：**近白金**。
    /// ⚠️ 2026-09-28 提亮：原来直接复用 `goldLight`(#E4CFA3)，主红改成参考图采样的
    /// 珊瑚红 `#D0493A` 后，香槟金压在它上面只有 ~2.3:1 ⇒ 封面金额/按钮标题整片发闷。
    /// 只服务**红底**；白卡上的金仍用 `gold`/`goldLight`/`goldDeep`（白底铺亮金会发虚 ✗）。
    static let onRedStrong: UIColor = UIColor(hex: 0xFFF3DC)
    /// 红底上的金线 / 描边 / 金色弧线与高光
    ///（`applyRPGoldBorder` / `applyRPGoldHighlight` / `applyRPTopCurve` 内部用它）。
    /// 比 `gold`(#C9A961) 亮一档、但还留在香槟金色相里：压珊瑚红 ≈3.4:1（原来只 ~1.9:1）。
    static let onRedGold: UIColor = UIColor(hex: 0xF7E7C6)
    /// 红底上的次要文字
    static let onRedWeak: UIColor = UIColor.white.withAlphaComponent(0.62)
    /// 不可领取的失效红
    static var disabledRed: UIColor { redDeep.withAlphaComponent(0.45) }
}

/// 装饰层的名字：`applyRP*` 重复调用时据此找到并替换旧层。
/// ⚠️ 放**文件作用域**、不要放进 `extension UIView` —— 扩展里不能有存储属性（`static let` 也算）。
private let rpGradientLayerName = "RP.gradient"
private let rpHighlightLayerName = "RP.highlight"

// MARK: - 自带渐变的容器
/// 渐变跟随 bounds 的容器（在 `layoutSubviews` 里重铺）。
/// 存在意义：很多场景下**配置数据时视图 bounds 还是零**（cell / 弹框在布局前就 configure），
/// 那时铺渐变会得到一张空图；交给这个类就不用在每个调用点 remind `layoutIfNeeded`。
final class RPGradientView: UIView {

    /// true = 可用的亮红；false = 已领取 / 过期 / 领完的暗红
    var isActiveStyle = true

    var gradientColors: [UIColor] {
        isActiveStyle ? RP.primaryGradient : [RP.redDeep, RP.redMid]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyRPGradient(gradientColors, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1, y: 1))
    }
}

// MARK: - 视图装饰工具
extension UIView {

    /// 铺一层线性渐变（重复调用会替换旧的）。
    ///
    /// ⚠️ 圆角 + 渐变 + 阴影**不能在同一层**：
    /// 本视图负责 `cornerRadius` + `clipsToBounds` + 渐变；
    /// 阴影必须交给**外层**容器（`clipsToBounds = false`）承接，否则会被裁掉。
    @discardableResult
    func applyRPGradient(_ colors: [UIColor],
                         start: CGPoint = CGPoint(x: 0, y: 0),
                         end: CGPoint = CGPoint(x: 1, y: 1),
                         cornerRadius: CGFloat = 0) -> CAGradientLayer {
        // 禁隐式动画：本方法常在 `viewDidLayoutSubviews`（可能被 push 转场事务包着）里调，
        // 不禁的话渐变会从旧尺寸「动画」到新尺寸。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.sublayers?
            .filter { ($0 as? CAGradientLayer)?.name == rpGradientLayerName }
            .forEach { $0.removeFromSuperlayer() }
        let gradient = CAGradientLayer()
        gradient.name = rpGradientLayerName
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = start
        gradient.endPoint = end
        gradient.cornerRadius = cornerRadius
        gradient.frame = bounds
        layer.insertSublayer(gradient, at: 0)
        return gradient
    }

    /// 金色径向高光（装饰层，叠在渐变之上）；未铺渐变时不做任何事
    func applyRPGoldHighlight(center: CGPoint = CGPoint(x: 0.84, y: 0.10),
                              spread: CGFloat = 0.55,
                              alpha: CGFloat = 0.18) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.sublayers?
            .filter { ($0 as? CAGradientLayer)?.name == rpHighlightLayerName }
            .forEach { $0.removeFromSuperlayer() }
        guard let base = layer.sublayers?.first(where: { ($0 as? CAGradientLayer)?.name == rpGradientLayerName }) else {
            return
        }
        let highlight = CAGradientLayer()
        highlight.name = rpHighlightLayerName
        highlight.type = .radial
        highlight.colors = [RP.onRedGold.withAlphaComponent(alpha).cgColor, UIColor.clear.cgColor]
        highlight.startPoint = center
        highlight.endPoint = CGPoint(x: center.x + spread, y: center.y + spread)
        highlight.frame = bounds
        layer.insertSublayer(highlight, above: base)
    }

    /// 装饰层跟随 bounds（在 `viewDidLayoutSubviews` / `layoutSubviews` 里调用）。
    ///
    /// ⚠️ **必须禁掉隐式动画**（2026-09-28 逐帧录像定位的 bug）：
    /// `viewDidLayoutSubviews` 被 **push 转场动画**的 CATransaction 包着，
    /// 此时直接写 `sub.frame` 会走 CoreAnimation 的**隐式动画**（默认 0.25s）。
    /// 而渐变层是在 `lazy var` 里铺的（那时 `bounds == .zero`）⇒ frame 从 0 插值到满尺寸，
    /// 表现就是「点发红包进页面时，头图红色**慢慢铺满**」；
    /// 文字/图标看着正常是因为它们居中、位移小，而渐变层是从「宽 0」开始长。
    /// 录像实测：1.27s→1.57s 红色区域逐帧长大（0.30s）。
    func layoutRPDecorations() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.sublayers?.forEach { sub in
            guard let name = sub.name, name.hasPrefix("RP.") else { return }
            // 金弧的路径自带绝对坐标，不能改 frame
            if name == "RP.headerGoldArc" { return }
            sub.frame = bounds
        }
    }

    /// 金色描边（**红底专用**，用更亮的 `onRedGold`；白卡描边请用 `RP.goldHairline`）
    func applyRPGoldBorder(_ width: CGFloat = 1, alpha: CGFloat = 0.35, cornerRadius: CGFloat? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.borderWidth = width
        layer.borderColor = RP.onRedGold.withAlphaComponent(alpha).cgColor
        if let radius = cornerRadius { layer.cornerRadius = radius }
    }

    /// 红色（或金色）发光；**必须由 `clipsToBounds = false` 的视图承接**
    func applyRPGlow(_ color: UIColor = RP.redBright,
                     radius: CGFloat = 12,
                     opacity: Float = 0.28,
                     offsetY: CGFloat = 6) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.shadowOffset = CGSize(width: 0, height: offsetY)
        layer.masksToBounds = false
        clipsToBounds = false
    }

    /// 暖中性卡片阴影（替代工程里偏蓝的 `makeNormalShadow`）
    func applyRPCardShadow(radius: CGFloat = 12, opacity: Float = 0.06, offsetY: CGFloat = 4) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.shadowColor = RP.inkSoft.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.shadowOffset = CGSize(width: 0, height: offsetY)
        layer.masksToBounds = false
        clipsToBounds = false
    }

    /// 红包模块的暖白卡片：cream 底 + 大圆角（16）+ 暖阴影。
    /// 替代工程通用的 `makeOriginalShdowShow()`（灰白底 + 圆角 5 + 淡蓝阴影）。
    func makeRPCard(cornerRadius: CGFloat = 16) {
        layer.backgroundColor = RP.cream.cgColor
        layer.cornerRadius = cornerRadius
        applyRPCardShadow()
    }

    /// 红金头图底部「凹弧 + 金色细线」（红包详情页头图 / 记录页顶部红头共用）。
    /// ⚠️ 会**覆盖 `layer.mask`**，头图不要再自己设 mask；在 `viewDidLayoutSubviews` 里反复调是安全的。
    func applyRPTopCurve(curve: CGFloat = 20, goldAlpha: CGFloat = 0.38) {
        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1 else { return }

        // 本方法也在 `viewDidLayoutSubviews` 里反复调：禁隐式动画，否则 mask/弧线会「长」出来
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - curve))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - curve),
            controlPoint: CGPoint(x: w * 0.5, y: h + curve * 0.35))
        path.close()
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask

        // 金色弧线：沿凹弧内侧描 1pt 金线（上移 2pt，否则正好落在 mask 边界上会被裁掉一半）
        layer.sublayers?
            .filter { $0.name == "RP.headerGoldArc" }
            .forEach { $0.removeFromSuperlayer() }
        let arcY = h - curve - 2
        let arc = UIBezierPath()
        arc.move(to: CGPoint(x: 0, y: arcY))
        arc.addQuadCurve(
            to: CGPoint(x: w, y: arcY),
            controlPoint: CGPoint(x: w * 0.5, y: h + curve * 0.35 - 2))
        let arcLayer = CAShapeLayer()
        arcLayer.name = "RP.headerGoldArc"
        arcLayer.path = arc.cgPath
        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.strokeColor = RP.onRedGold.withAlphaComponent(goldAlpha).cgColor
        arcLayer.lineWidth = 1
        layer.addSublayer(arcLayer)
    }
}

// MARK: - 数字字体
extension UIFont {

    /// 金额数字用等宽数字字形：数字变化时宽度不跳动，视觉更整齐
    class func rpAmountFont(_ size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        return UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }
}
