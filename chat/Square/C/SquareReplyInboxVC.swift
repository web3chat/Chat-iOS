//
//  SquareReplyInboxVC.swift
//  chat
//
//  广场收件箱：有人评论我的帖子 / 回复我的评论（《App增量-评论回复》§5）
//  · 点一条进帖子详情并定位到那条评论；
//  · 点开某条才标该条已读，右上角可「全部已读」；
//  · 未读数回传给广场首页铃铛红点。
//

import Foundation
import UIKit
import SnapKit
import Kingfisher
import MJRefresh

final class SquareReplyInboxVC: UIViewController, ViewControllerProtocol {

    /// 未读数变化（广场首页铃铛红点）
    var onUnreadChanged: ((Int) -> Void)?

    private var items = [SquareReplyInboxItem]()
    private var page = 1
    private var hasMore = false
    private var isLoading = false
    private var didLoadOnce = false
    private var unreadCount = 0
    private let pageSize = 20

    // MARK: - 子视图

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.backgroundColor = Color_FFFFFF
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        view.rowHeight = UITableView.automaticDimension
        view.estimatedRowHeight = 120
        view.register(SquareReplyInboxCell.self, forCellReuseIdentifier: SquareReplyInboxCell.identifier)
        view.dataSource = self
        view.delegate = self
        view.mj_header = MJRefreshNormalHeader(refreshingBlock: { [weak self] in
            self?.load(reset: true)
        })
        view.mj_footer = MJRefreshAutoNormalFooter(refreshingBlock: { [weak self] in
            guard let self = self, self.hasMore, !self.isLoading else {
                self?.tableView.mj_footer?.endRefreshing()
                return
            }
            self.load(reset: false)
        })
        view.mj_footer?.isHidden = true
        return view
    }()

    private lazy var emptyView: UIView = {
        let view = UIView()
        view.isHidden = true
        // 空态只是视觉遮罩：不能吃掉下拉刷新/滚动
        view.isUserInteractionEnabled = false
        let icon = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right"))
        icon.tintColor = Color_8A97A5
        icon.contentMode = .scaleAspectFit
        view.addSubview(icon)
        let label = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("还没有收到回复"))
        view.addSubview(label)
        icon.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-24)
            make.size.equalTo(CGSize(width: 40, height: 40))
        }
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(icon.snp.bottom).offset(12)
            make.left.greaterThanOrEqualToSuperview().offset(20)
            make.right.lessThanOrEqualToSuperview().offset(-20)
        }
        return view
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Color_FFFFFF
        navigationItem.title = L("回复我的")
        setupReadAllButton()
        view.addSubview(tableView)
        view.addSubview(emptyView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didLoadOnce {
            load(reset: true)
        }
    }

    // MARK: - 右上角「全部已读」

    private func setupReadAllButton() {
        let btn = UIButton(type: .custom)
        btn.setTitle(L("全部已读"), for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .mediumFont(14)
        btn.addTarget(self, action: #selector(readAllTapped), for: .touchUpInside)
        btn.frame = CGRect(x: 0, y: 0, width: 68, height: 30)
        let item = UIBarButtonItem(customView: btn)
        item.isEnabled = false
        navigationItem.rightBarButtonItem = item
    }

    private func updateReadAllButton() {
        navigationItem.rightBarButtonItem?.isEnabled = unreadCount > 0
    }

    @objc private func readAllTapped() {
        guard unreadCount > 0 else { return }
        SquareService.shared.markRepliesRead(ids: [], all: true, success: { [weak self] unread in
            guard let self = self else { return }
            self.unreadCount = unread
            for index in self.items.indices {
                self.items[index].read = true
            }
            self.tableView.reloadData()
            self.updateReadAllButton()
            self.onUnreadChanged?(unread)
            self.showToast(L("已全部标为已读"))
        }, failure: { [weak self] failure in
            self?.showToast(with: failure.message)
        })
    }

    // MARK: - 数据

    private func load(reset: Bool) {
        guard !isLoading else { return }
        isLoading = true
        let targetPage = reset ? 1 : page + 1
        SquareService.shared.replyInbox(read: nil, page: targetPage, pageSize: pageSize, success: { [weak self] pageData in
            guard let self = self else { return }
            self.isLoading = false
            self.didLoadOnce = true
            self.page = targetPage
            self.hasMore = pageData.hasMore
            self.unreadCount = pageData.unreadCount
            if reset {
                self.items = pageData.list
            } else {
                self.items.append(contentsOf: pageData.list)
            }
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            self.tableView.mj_footer?.isHidden = !self.hasMore
            self.tableView.reloadData()
            self.emptyView.isHidden = !self.items.isEmpty
            self.updateReadAllButton()
            self.onUnreadChanged?(self.unreadCount)
            // 全部列表接口不一定带 `unreadCount`（为 0 时再单独按 read=0 查一次，保证「全部已读」状态正确）
            if reset, pageData.unreadCount == 0 {
                SquareService.shared.replyUnreadCount(success: { [weak self] count in
                    guard let self = self else { return }
                    self.unreadCount = count
                    self.updateReadAllButton()
                    self.onUnreadChanged?(count)
                })
            }
        }, failure: { [weak self] failure in
            guard let self = self else { return }
            self.isLoading = false
            self.didLoadOnce = true
            self.tableView.mj_header?.endRefreshing()
            self.tableView.mj_footer?.endRefreshing()
            self.showToast(with: failure.message)
        })
    }

    /// 点开某条才标已读
    private func markRead(_ item: SquareReplyInboxItem) {
        guard item.id > 0, !item.read else { return }
        SquareService.shared.markRepliesRead(ids: [item.id], all: false, success: { [weak self] unread in
            guard let self = self else { return }
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                self.items[index].read = true
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
            self.unreadCount = unread
            self.updateReadAllButton()
            self.onUnreadChanged?(unread)
        }, failure: nil)
    }
}

// MARK: - 列表

extension SquareReplyInboxVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SquareReplyInboxCell.identifier, for: indexPath) as! SquareReplyInboxCell
        guard indexPath.row < items.count else { return cell }
        cell.configure(items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < items.count else { return }
        let item = items[indexPath.row]
        guard item.available else {
            showToast(L("该内容已不可查看"))
            return
        }
        guard item.postId > 0 else {
            showToast(L("帖子已不存在"))
            return
        }
        let vc = SquarePostDetailVC(postId: item.postId,
                                    focusCommentId: item.commentId > 0 ? item.commentId : nil,
                                    focusParentId: item.parentId > 0 ? item.parentId : nil)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
        markRead(item)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row >= items.count - 1, hasMore, !isLoading else { return }
        load(reset: false)
    }
}

// MARK: - 收件箱 cell

final class SquareReplyInboxCell: UITableViewCell {

    static let identifier = "SquareReplyInboxCell"

    private static let defaultAvatar = #imageLiteral(resourceName: "friend_chat_avatar")

    private let avatarView = UIImageView()
    private let nameLab = UILabel()
    private let unreadDot = UIView()
    private let timeLab = UILabel()
    private let actionLab = UILabel()
    private let contentLab = UILabel()
    private let separator = UIView()

    private var currentAddress = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Color_FFFFFF
        contentView.backgroundColor = Color_FFFFFF
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 18
        avatarView.image = SquareReplyInboxCell.defaultAvatar

        nameLab.font = .mediumFont(14)
        nameLab.textColor = Color_24374E

        unreadDot.backgroundColor = Color_Theme
        unreadDot.layer.cornerRadius = 4
        unreadDot.isHidden = true

        timeLab.font = .regularFont(11)
        timeLab.textColor = Color_8A97A5
        timeLab.setContentCompressionResistancePriority(.required, for: .horizontal)

        actionLab.font = .regularFont(12)
        actionLab.textColor = Color_8A97A5

        contentLab.font = .regularFont(14)
        contentLab.textColor = Color_24374E
        contentLab.numberOfLines = 2

        separator.backgroundColor = Color_E6EAEE

        [avatarView, nameLab, unreadDot, timeLab, actionLab, contentLab, separator].forEach {
            contentView.addSubview($0)
        }

        avatarView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalToSuperview().offset(14)
            make.size.equalTo(CGSize(width: 36, height: 36))
        }
        nameLab.snp.makeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(10)
            make.top.equalToSuperview().offset(14)
            make.height.equalTo(20)
        }
        unreadDot.snp.makeConstraints { make in
            make.left.equalTo(nameLab.snp.right).offset(6)
            make.centerY.equalTo(nameLab)
            make.size.equalTo(CGSize(width: 8, height: 8))
        }
        timeLab.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalTo(nameLab)
            make.left.greaterThanOrEqualTo(unreadDot.snp.right).offset(8)
        }
        actionLab.snp.makeConstraints { make in
            make.left.equalTo(nameLab)
            make.top.equalTo(nameLab.snp.bottom).offset(1)
            make.right.lessThanOrEqualToSuperview().offset(-15)
        }
        contentLab.snp.makeConstraints { make in
            make.left.equalTo(nameLab)
            make.top.equalTo(actionLab.snp.bottom).offset(6)
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview().offset(-14)
        }
        separator.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(61)
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }

    func configure(_ item: SquareReplyInboxItem) {
        currentAddress = item.authorAddr
        nameLab.text = SquareDisplayName.of(name: item.authorName, address: item.authorAddr)
        nameLab.font = item.read ? .regularFont(14) : .mediumFont(14)
        unreadDot.isHidden = item.read
        timeLab.text = SquareDateParser.displayText(from: item.createdDate)

        let action = item.isReplyToComment ? L("回复了你的评论") : L("评论了你的帖子")
        if item.postTitle.isEmpty {
            actionLab.text = action
        } else {
            actionLab.text = "\(action) · \(item.postTitle)"
        }

        contentLab.text = item.content.isEmpty ? L("评论内容不可见") : item.content
        contentLab.textColor = item.content.isEmpty ? Color_8A97A5 : Color_24374E

        avatarView.image = SquareReplyInboxCell.defaultAvatar
        SquareAvatarResolver.avatarURL(for: item.authorAddr) { [weak self] url in
            guard let self = self,
                  self.currentAddress == item.authorAddr,
                  let url = url,
                  let link = SquareMediaURLParser.displayURL(from: url, pixelSide: 72) else { return }
            self.avatarView.kf.setImage(with: link, placeholder: SquareReplyInboxCell.defaultAvatar)
        }
    }
}
