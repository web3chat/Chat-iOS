//
//  FZMGroupApplyListVC.swift
//  chat
//
//  入群申请列表（加群方式 joinType == 2「入群需审核」时使用）
//  仅群主/管理员可进入，可在此通过或拒绝入群申请
//  接口：POST /group/app/get-group-applys、accept-group-apply、reject-group-apply
//

import UIKit
import SnapKit
import Kingfisher
import MJRefresh

class FZMGroupApplyListVC: UIViewController, ViewControllerProtocol {
    
    private let groupId: Int
    private let serverUrl: String
    
    /// 审批过申请后回调（群详情用于刷新待审批数量）
    var changedBlock: NormalBlock?
    
    private var applyList = [GroupApply]()// 只保留待审核（applyStatus == 0）的申请
    
    /// 一次拉取的条数（不做分页，入群申请页只需看当前待审的）
    private let pageCount = 50
    
    private lazy var tableView : UITableView = {
        let view = UITableView(frame: CGRect.zero, style: .plain)
        view.backgroundColor = .white
        // 关掉系统自动内边距：否则初始 contentOffset 为 -inset，MJRefresh 的「下拉刷新」文字会露在页面上
        view.contentInsetAdjustmentBehavior = .never
        view.dataSource = self
        view.delegate = self
        view.tableFooterView = UIView(frame: CGRect.zero)
        view.rowHeight = 70
        view.separatorColor = Color_E6EAEE
        view.separatorInset = UIEdgeInsets(top: 0, left: 65, bottom: 0, right: 0)
        view.register(FZMGroupApplyCell.self, forCellReuseIdentifier: FZMGroupApplyCell.reuseId)
        return view
    }()
    
    private lazy var emptyLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: L("暂无入群申请"))
        lab.isHidden = true
        return lab
    }()
    
    init(with groupId: Int, serverUrl: String) {
        self.groupId = groupId
        self.serverUrl = serverUrl
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = L("入群申请")
        self.view.backgroundColor = .white
        
        self.createUI()
        
        // 查询入群申请列表
        self.loadApplyList()
    }
}

// MARK: - UI
extension FZMGroupApplyListVC {
    private func createUI() {
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            // 从导航栏下方开始（配合 .never，避免下拉刷新文字显示在页面上）
            m.top.equalTo(self.view.safeAreaTop)
            m.left.right.equalToSuperview()
            m.bottom.equalTo(self.view.safeAreaBottom)
        }
        
        self.view.addSubview(emptyLab)
        emptyLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.centerY.equalToSuperview().offset(-40)
        }
        
        // 没有「新入群申请」信令，只能进页面主动拉 + 下拉刷新
        self.tableView.mj_header = MJRefreshNormalHeader.init(refreshingBlock: { [weak self] in
            self?.loadApplyList()
        })
    }
    
    private func refreshUI() {
        self.emptyLab.isHidden = self.applyList.count > 0
        self.tableView.reloadData()
    }
}

// MARK: - 网络请求
extension FZMGroupApplyListVC {
    /// 查询入群申请列表（只需一页，不做上拉加载）
    private func loadApplyList() {
        self.view.showProgress()
        GroupManager.shared().getGroupApplys(serverUrl: self.serverUrl, groupId: self.groupId, count: self.pageCount, offset: 0) { [weak self] (list) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideProgress()
            strongSelf.tableView.mj_header?.endRefreshing()
            
            // 申请列表拉回来后在本地只展示待审核的（applyStatus == 0）
            strongSelf.applyList = list.filter { $0.isWaiting }
            strongSelf.refreshUI()
        } failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.view.hideProgress()
            strongSelf.tableView.mj_header?.endRefreshing()
            strongSelf.showToast(GroupManager.applyFailureMessage(error))
            strongSelf.refreshUI()
        }
    }
    
    /// 通过 / 拒接入群申请
    private func deal(with apply: GroupApply, accept: Bool) {
        guard !apply.applyId.isBlank else {
            self.showToast(L("操作失败，请稍后重试"))
            return
        }
        
        self.showProgress(with: nil)
        
        let successBlock: Provider.SuccessBlock = { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast(accept ? L("已同意") : L("已拒绝"))
            // 本地把该条置为已处理（列表只剩待审的）
            strongSelf.applyList = strongSelf.applyList.filter { $0.applyId != apply.applyId }
            strongSelf.refreshUI()
            // 群成员会在 SignInGroup 信令到达后刷新
            strongSelf.changedBlock?()
        }
        let failureBlock: Provider.FailureBlock = { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            let code = (error as NSError).code
            strongSelf.showToast(GroupManager.applyFailureMessage(error))
            switch code {
            case -10028, -10030:// 该申请已处理 / 该申请不存在 → 刷新列表
                strongSelf.loadApplyList()
            default:
                break
            }
        }
        
        if accept {
            GroupManager.shared().acceptGroupApply(serverUrl: self.serverUrl, groupId: self.groupId, applyId: apply.applyId, successBlock: successBlock, failureBlock: failureBlock)
        } else {
            GroupManager.shared().rejectGroupApply(serverUrl: self.serverUrl, groupId: self.groupId, applyId: apply.applyId, successBlock: successBlock, failureBlock: failureBlock)
        }
    }
}

extension FZMGroupApplyListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.applyList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < self.applyList.count else { return UITableViewCell() }
        
        var cell = tableView.dequeueReusableCell(withIdentifier: FZMGroupApplyCell.reuseId, for: indexPath) as? FZMGroupApplyCell
        if cell == nil {
            cell = FZMGroupApplyCell.init(style: .default, reuseIdentifier: FZMGroupApplyCell.reuseId)
        }
        guard let applyCell = cell else { return UITableViewCell() }
        
        let apply = self.applyList[indexPath.row]
        applyCell.configure(with: apply)
        applyCell.acceptBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.deal(with: apply, accept: true)
        }
        applyCell.rejectBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.deal(with: apply, accept: false)
        }
        return applyCell
    }
}

// MARK: - 入群申请 cell
fileprivate final class FZMGroupApplyCell: UITableViewCell {
    
    static let reuseId = "FZMGroupApplyCell"
    
    /// 同意
    var acceptBlock: NormalBlock?
    /// 拒绝
    var rejectBlock: NormalBlock?
    
    private var applyId: String = ""
    
    private lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 4
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    private lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "")
    }()
    
    private lazy var detailLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: "")
    }()
    
    private lazy var acceptBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(L("同意"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(14)
        btn.backgroundColor = Color_Theme
        btn.layer.cornerRadius = 14
        btn.clipsToBounds = true
        return btn
    }()
    
    private lazy var rejectBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(L("拒绝"), for: .normal)
        btn.setTitleColor(Color_8A97A5, for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(14)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Color_C8D3DE.cgColor
        return btn
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .white
        
        self.contentView.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize(width: 40, height: 40))
        }
        
        self.contentView.addSubview(acceptBtn)
        acceptBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize(width: 56, height: 28))
        }
        
        self.contentView.addSubview(rejectBtn)
        rejectBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalTo(acceptBtn.snp.left).offset(-10)
            m.size.equalTo(CGSize(width: 56, height: 28))
        }
        
        self.contentView.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.left.equalTo(headerImageView.snp.right).offset(10)
            m.right.lessThanOrEqualTo(rejectBtn.snp.left).offset(-10)
            m.top.equalToSuperview().offset(16)
            m.height.equalTo(20)
        }
        
        self.contentView.addSubview(detailLab)
        detailLab.snp.makeConstraints { (m) in
            m.left.equalTo(nameLab)
            m.right.lessThanOrEqualTo(rejectBtn.snp.left).offset(-10)
            m.top.equalTo(nameLab.snp.bottom).offset(2)
            m.height.equalTo(16)
        }
        
        acceptBtn.rx.controlEvent(.touchUpInside).subscribe { [weak self] (_) in
            self?.acceptBlock?()
        }.disposed(by: disposeBag)
        
        rejectBtn.rx.controlEvent(.touchUpInside).subscribe { [weak self] (_) in
            self?.rejectBlock?()
        }.disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let disposeBag = DisposeBag.init()
    
    func configure(with apply: GroupApply) {
        self.applyId = apply.applyId
        
        // 申请单里只有地址，昵称/头像先用占位，再从本地用户信息补充
        headerImageView.image = #imageLiteral(resourceName: "friend_chat_avatar")
        nameLab.text = apply.memberId.shortAddress
        
        // 申请备注 + 申请时间（毫秒）
        var details = [String]()
        if !apply.applyNote.isBlank {
            details.append(apply.applyNote)
        }
        if apply.createTime > 0 {
            var seconds = Double(apply.createTime)
            if seconds > 9999999999 {// 服务端返回毫秒
                seconds = seconds / 1000
            }
            let date = Date.timeStampToString(timeStamp: seconds)
            let formatter = DateFormatter.getDataformatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            details.append(formatter.string(from: date))
        }
        if details.isEmpty {
            details.append(L("申请加入群聊"))
        }
        detailLab.text = details.joined(separator: " · ")
        
        guard !apply.memberId.isBlank else { return }
        let requestApplyId = apply.applyId
        UserManager.shared().getUser(by: apply.memberId) { [weak self] (user) in
            guard let strongSelf = self, strongSelf.applyId == requestApplyId, let user = user else { return }
            strongSelf.nameLab.text = user.contactsName
            strongSelf.headerImageView.kf.setImage(with: URL.init(string: user.avatarURLStr), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
        }
    }
}
