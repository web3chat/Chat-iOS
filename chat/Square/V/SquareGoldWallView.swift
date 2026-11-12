//
//  SquareGoldWallView.swift
//  chat
//
//  广场「公众号」筛选页顶部的金标公众号目录墙（《App增量-公众号金标》§3）：
//  横向滚动卡片，点卡片进作者页（`SquareAuthorVC`），在那里关注 / 取关。
//
//  它作为 `SquareFeedPageView` 的 `tableView.tableHeaderView` 使用 ⇒ **随列表一起划走**。
//  ⚠️ `tableHeaderView` 不参与 Auto Layout：挂载方必须显式给 `frame`（宽度必须给，否则整块不显示）。
//

import Foundation
import UIKit
import SnapKit
import Kingfisher

final class SquareGoldWallView: UIView {

    /// 整块高度（挂载方用作 tableHeaderView 的 frame 高度）
    static let preferredHeight: CGFloat = 96

    /// 点某张卡片（进作者页）
    var onSelect: ((SquareOfficialCard) -> Void)?

    private var cards = [SquareOfficialCard]()

    private static let itemSize = CGSize(width: 104, height: 78)
    private static let sectionInset = UIEdgeInsets(top: 9, left: 15, bottom: 9, right: 15)
    private static let itemSpacing: CGFloat = 10

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = SquareGoldWallView.itemSize
        layout.sectionInset = SquareGoldWallView.sectionInset
        layout.minimumLineSpacing = SquareGoldWallView.itemSpacing
        layout.minimumInteritemSpacing = SquareGoldWallView.itemSpacing
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = Color_FFFFFF
        // 不显示滚动条：iOS 15 起横向滚动条会显示成卡片下方的一条黑细线
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.dataSource = self
        view.delegate = self
        view.register(SquareGoldWallCell.self, forCellWithReuseIdentifier: SquareGoldWallCell.identifier)
        return view
    }()

    /// 与下面帖子列表之间的分隔细线
    private lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_E6EAEE
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Color_FFFFFF
        addSubview(collectionView)
        addSubview(lineView)
        collectionView.snp.makeConstraints { (m) in
            m.left.right.top.equalToSuperview()
            m.bottom.equalTo(lineView.snp.top)
        }
        lineView.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(0.5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 铺数据（空数组时挂载方会把表头整体去掉，这里不做空态）
    func update(cards: [SquareOfficialCard]) {
        self.cards = cards
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }
}

// MARK: - 数据源

extension SquareGoldWallView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SquareGoldWallCell.identifier, for: indexPath) as! SquareGoldWallCell
        guard indexPath.item < cards.count else { return cell }
        cell.configure(card: cards[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < cards.count else { return }
        onSelect?(cards[indexPath.item])
    }
}

// MARK: - 卡片

/// 金标公众号卡片：头像（带金标角标）+ 名称。
/// 固定尺寸（104 × 78）保证横向布局确定性，名称单行截断。
final class SquareGoldWallCell: UICollectionViewCell {

    static let identifier = "SquareGoldWallCell"

    /// 头像降采样像素（与列表头像同一套：40pt 的 2 倍）
    private static let avatarSide: CGFloat = 40
    private static let avatarPixelSize = CGSize(width: avatarSide * UIScreen.main.scale * 2,
                                               height: avatarSide * UIScreen.main.scale * 2)
    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = SquareGoldWallCell.avatarSide / 2
        view.backgroundColor = Color_F6F7F8
        view.image = SquareGoldWallCell.defaultAvatar
        return view
    }()

    /// 头像右下角的金标（只对金标号展示）：橙底圆 + 白色实心五角星（`star.circle.fill`）。
    /// ⚠️ 这里的白色圆底**不能删**：该符号的星是**镂空**的，没有白底时会透出头像，星就不是白的了。
    private lazy var goldView: UIImageView = {
        let config = UIImage.SymbolConfiguration.init(pointSize: 13, weight: .bold)
        let view = UIImageView.init(image: UIImage.init(systemName: "star.circle.fill", withConfiguration: config)?.withRenderingMode(.alwaysTemplate))
        view.tintColor = Color_Gold
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 7.5
        view.clipsToBounds = true
        return view
    }()

    private lazy var nameLab: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(12), textColor: Color_24374E, textAlignment: .center, text: nil)
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()

    /// 已贴过的头像地址（地址没变就不重复贴，避免占位图闪一下）
    private var appliedAvatarKey = ""
    /// 当前卡片对应的地址（异步回调校验，避免复用串头像）
    private var currentAddress = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = Color_F6F7F8
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        contentView.addSubview(avatarView)
        contentView.addSubview(goldView)
        contentView.addSubview(nameLab)

        avatarView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(10)
            m.size.equalTo(CGSize(width: SquareGoldWallCell.avatarSide, height: SquareGoldWallCell.avatarSide))
        }
        goldView.snp.makeConstraints { (m) in
            m.right.equalTo(avatarView).offset(2)
            m.bottom.equalTo(avatarView).offset(2)
            m.size.equalTo(CGSize(width: 15, height: 15))
        }
        nameLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(6)
            m.right.equalToSuperview().offset(-6)
            m.top.equalTo(avatarView.snp.bottom).offset(5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        appliedAvatarKey = ""
        currentAddress = ""
        avatarView.kf.cancelDownloadTask()
        avatarView.image = SquareGoldWallCell.defaultAvatar
        nameLab.text = nil
    }

    func configure(card: SquareOfficialCard) {
        currentAddress = card.address
        nameLab.text = card.displayName
        goldView.isHidden = !card.gold
        loadAvatar(card)
    }

    /// 头像：服务端给了 `avatar` 就直接用，为空才按地址解析（与作者页 / 帖子列表同一套规则）
    private func loadAvatar(_ card: SquareOfficialCard) {
        if !card.avatar.isEmpty {
            applyAvatar(rawURL: card.avatar)
            return
        }
        let address = card.address
        SquareAvatarResolver.avatarURL(for: address) { [weak self] url in
            guard let self = self, self.currentAddress == address else { return }
            guard let url = url, !url.isEmpty else {
                self.appliedAvatarKey = ""
                self.avatarView.image = SquareGoldWallCell.defaultAvatar
                return
            }
            self.applyAvatar(rawURL: url)
        }
    }

    private func applyAvatar(rawURL: String) {
        guard rawURL != appliedAvatarKey || avatarView.image == nil else { return }
        guard let link = SquareMediaURLParser.displayURL(from: rawURL, pixelSide: SquareGoldWallCell.avatarPixelSize.width) else {
            appliedAvatarKey = ""
            avatarView.image = SquareGoldWallCell.defaultAvatar
            return
        }
        appliedAvatarKey = rawURL
        SquareAvatarLoader.apply(to: avatarView,
                                 url: link,
                                 key: rawURL,
                                 placeholder: SquareGoldWallCell.defaultAvatar,
                                 downsampleSize: SquareGoldWallCell.avatarPixelSize) { [weak self] success in
            guard let self = self, !success, self.appliedAvatarKey == rawURL else { return }
            // 失败清记录，下次重配时重试（否则会一直停在占位图）
            self.appliedAvatarKey = ""
        }
    }
}
