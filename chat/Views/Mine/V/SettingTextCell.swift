//
//  SettingTextCell.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/15.
//

import UIKit
import SnapKit

class SettingTextCell: UITableViewCell {
    
    private lazy var leftLabel: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text:nil)
        lab.numberOfLines = 1
        return lab
    }()
    
    private lazy var rightLabel: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    /// 右侧指示箭头。
    /// 用户 2026-09-28：「设置页里的多语言右边不要三个点，要箭头」——
    /// 这个 cell 目前只有「多语言」一行在用（SettingVC），所以直接换成 chevron；
    /// 尺寸/颜色与广场里其它箭头（`SquareReportVC` / `SquareMyPostsVC`）保持一致。
    private lazy var moreImgV: UIImageView = {
        let moreImgV = UIImageView.init(image: UIImage.init(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate))
        moreImgV.tintColor = Color_C8D3DE
        moreImgV.contentMode = .scaleAspectFit
        return moreImgV
    }()
    
    private lazy var lineView: UIImageView = {
        let view = UIImageView.init()
        view.backgroundColor = Color_E6EAEE
        view.isHidden = true
        return view
    }()
    
    /// 右侧文案的右边界约束：有箭头时让位给箭头，没箭头时直接贴右边（见 `configure`）
    /// ⚠️ 本工程内有同名 `Constraint`（数据库层 `chat/BusinessTool/Database/sql/Constraint.swift`），
    ///    这里必须显式写 `SnapKit.Constraint`，否则报 `Cannot assign value of type 'SnapKit.Constraint' to type 'chat.Constraint'`。
    private var rightLabelRightConstraint: SnapKit.Constraint?

    /// 右侧给箭头让出的宽度（右边距 15 + 箭头 14 + 间距 5）。
    /// ⚠️ 必须显式声明为 CGFloat：直接写 `-(15 + 14 + 5)` 会因为 SnapKit 的
    /// offset 有多套数值重载而报 `ambiguous use of operator '+'`。
    private static let arrowTrailingInset: CGFloat = 15 + 14 + 5
    /// 没有箭头时只留右边距 15。
    private static let plainTrailingInset: CGFloat = 15
    
    private var selectedBlock: (()->())?
    
    override func prepareForReuse() {
        self.leftLabel.text = nil
        self.leftLabel.attributedText = nil
        self.rightLabel.text = nil
        self.rightLabel.attributedText = nil
        DispatchQueue.main.async {
            self.roundCorners([.topLeft,.topRight,.bottomLeft,.bottomRight], radius: 0)
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.contentView.backgroundColor = Color_FFFFFF
        self.contentView.addSubview(leftLabel)
        leftLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(moreImgV)
        moreImgV.snp.makeConstraints { (m) in
            // 箭头是正方形图标（原来的三个点是 4×20 的竖点）
            m.size.equalTo(CGSize.init(width: 14, height: 14))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(rightLabel)
        rightLabel.snp.makeConstraints { (m) in
            // 默认让位给箭头（15 + 箭头 14 + 间距 5）；隐藏箭头时由 `configure` 改成只留 15。
            // 用常量而不引用 `moreImgV.snp.left`，避免两视图互相引用。
            self.rightLabelRightConstraint = m.right.equalToSuperview().offset(-Self.arrowTrailingInset).constraint
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(lineView)
        lineView.snp.makeConstraints { (m) in
            m.height.equalTo(0.5)
            m.bottom.equalToSuperview()
            m.left.right.equalToSuperview()
        }
    }
    
    func configure(with model: SettingCellModel) {
        guard let model = model as? SettingTextCellModel else {
            return
        }
        
        if let attri = model.leftAttributedString {
            self.leftLabel.attributedText = attri
        } else {
            self.leftLabel.text = model.leftString
        }
        
        if let attri = model.rightAttributedString {
            self.rightLabel.attributedText = attri
        } else {
            self.rightLabel.text = model.rightString
        }
        
        // 右侧箭头：默认显示；「清理缓存」这类行隐藏箭头，并把右侧文案贴到最右边
        let showsArrow = model.showsArrow
        self.moreImgV.isHidden = !showsArrow
        self.rightLabelRightConstraint?.update(offset: showsArrow ? -Self.arrowTrailingInset : -Self.plainTrailingInset)
        
        self.lineView.isHidden = !(model.isShowLine ?? false)
        
        self.selectedBlock = model.selectedBlock
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
