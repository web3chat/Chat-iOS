//
//  StorageSpaceVC.swift
//  chat
//
//  设置中心 →「存储空间」（仿微信：总览 → 聊天记录 / 缓存）
//  - `StorageSpaceVC`：总占用 + 三个分类入口
//  - `CacheDetailVC`：图片缓存明细 + 一键清理
//

import UIKit
import SnapKit
import SwifterSwift

// MARK: - 总览

class StorageSpaceVC: UIViewController, ViewControllerProtocol {

    // MARK: UI

    private lazy var tableView: UITableView = {
        let view = UITableView.init(frame: .zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.separatorStyle = .none
        view.dataSource = self
        view.delegate = self
        view.rowHeight = 50
        view.showsVerticalScrollIndicator = false
        view.register(SettingTextCell.self, forCellReuseIdentifier: "SettingTextCell")
        return view
    }()

    private lazy var summaryView: StorageSummaryView = {
        let view = StorageSummaryView()
        view.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth - 30, height: 172)
        return view
    }()

    // MARK: 数据

    private var breakdown = FZMStorageBreakdown() {
        didSet {
            self.summaryView.configure(breakdown)
            self.refreshRows()
        }
    }

    private lazy var chatModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("聊天记录")
        model.rightString = "--"
        model.isShowLine = true
        model.selectedBlock = { [weak self] in
            self?.goChatStorage()
        }
        return model
    }()

    private lazy var cacheModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("缓存")
        model.rightString = "--"
        model.isShowLine = true
        model.selectedBlock = { [weak self] in
            self?.goCacheDetail()
        }
        return model
    }()

    private lazy var otherModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("App 必要文件")
        model.rightString = "--"
        model.isShowLine = false
        // 不可清（钱包库 / UserDefaults / WebView 数据 / 数据库等），只展示
        model.showsArrow = false
        return model
    }()

    private lazy var dataSource: [[SettingCellModel]] = {
        return [[chatModel, cacheModel, otherModel]]
    }()

    /// 首次进入才显示「--」占位，从子页面返回时保留上次数字，避免闪一下
    private var hasLoaded = false

    private var languageChangeObserver: NSObjectProtocol?

    // MARK: 生命周期

    deinit {
        if let observer = languageChangeObserver {
            FZM_NotificationCenter.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.title = L("存储空间")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        self.tableView.tableHeaderView = self.summaryView

        languageChangeObserver = FZM_NotificationCenter.addObserver(
            forName: LanguageManager.LanguageChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] (_) in
            guard let self = self else { return }
            self.applyLocalizedStrings()
            self.tableView.reloadData()
        }

        self.applyLocalizedStrings()
        self.tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从子页面返回时重新统计（子页面可能清理过数据）
        self.loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // tableHeaderView 不会自动跟随 tableView 宽度
        if self.summaryView.frame.width != self.tableView.bounds.width {
            var frame = self.summaryView.frame
            frame.size.width = self.tableView.bounds.width
            self.summaryView.frame = frame
            self.tableView.tableHeaderView = self.summaryView
        }
    }

    // MARK: 数据

    private func applyLocalizedStrings() {
        self.title = L("存储空间")
        self.chatModel.leftString = L("聊天记录")
        self.cacheModel.leftString = L("缓存")
        self.otherModel.leftString = L("App 必要文件")
        self.summaryView.applyLocalizedStrings()
    }

    private func loadData() {
        if !self.hasLoaded {
            self.summaryView.setLoading(true)
        }
        FZMStorageManager.shared.loadSummary { [weak self] breakdown in
            guard let self = self else { return }
            self.hasLoaded = true
            self.summaryView.setLoading(false)
            self.breakdown = breakdown
        }
    }

    private func refreshRows() {
        self.chatModel.rightString = FZMStorageManager.sizeText(self.breakdown.chatBytes)
        self.cacheModel.rightString = FZMStorageManager.sizeText(self.breakdown.cacheBytes)
        self.otherModel.rightString = FZMStorageManager.sizeText(self.breakdown.otherBytes)

        let rowCount = self.dataSource.first?.count ?? 0
        guard rowCount > 0 else { return }
        self.tableView.reloadRows(
            at: (0..<rowCount).map { IndexPath(row: $0, section: 0) },
            with: .none
        )
    }

    // MARK: 跳转

    private func goChatStorage() {
        let vc = ChatStorageVC(totalChatBytes: breakdown.chatBytes)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    private func goCacheDetail() {
        let vc = CacheDetailVC()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITableView

extension StorageSpaceVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: SettingTextCell.self, for: indexPath)
        guard let model = self.dataSource[indexPath.section][indexPath.row] as? SettingTextCellModel else {
            return cell
        }
        cell.configure(with: model)

        let sectionData = self.dataSource[indexPath.section]
        let isFirstRow = indexPath.row == 0
        let isLastRow = indexPath.row == sectionData.count - 1
        if isFirstRow && isLastRow {
            DispatchQueue.main.async {
                cell.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 5)
            }
        } else if isFirstRow {
            DispatchQueue.main.async {
                cell.roundCorners([.topLeft, .topRight], radius: 5)
            }
        } else if isLastRow {
            DispatchQueue.main.async {
                cell.roundCorners([.bottomLeft, .bottomRight], radius: 5)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.dataSource.count > indexPath.section,
              self.dataSource[indexPath.section].count > indexPath.row else { return }
        self.dataSource[indexPath.section][indexPath.row].selectedBlock?()
    }
}

// MARK: - 顶部总览卡片

private final class StorageSummaryView: UIView {

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_FFFFFF
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        return UILabel.getLab(font: .regularFont(13), textColor: Color_8A97A5, textAlignment: .left, text: L("总占用"))
    }()

    private let valueLabel: UILabel = {
        let lab = UILabel.getLab(font: .boldSystemFont(ofSize: 30), textColor: Color_24374E, textAlignment: .left, text: "--")
        lab.adjustsFontSizeToFitWidth = true
        lab.minimumScaleFactor = 0.6
        return lab
    }()

    private let barBackground: UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        return view
    }()

    private let chatBar: UIView = {
        let view = UIView()
        view.backgroundColor = Color_Theme
        return view
    }()

    private let cacheBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.init(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
        return view
    }()

    private let otherBar: UIView = {
        let view = UIView()
        view.backgroundColor = Color_C8D3DE
        return view
    }()

    private let legendLabel: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(11), textColor: Color_8A97A5, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()

    private var breakdown = FZMStorageBreakdown()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        self.backgroundColor = .clear

        self.addSubview(self.cardView)
        self.cardView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(15)
            m.left.right.equalToSuperview()
            m.height.equalTo(142)
        }

        self.cardView.addSubview(self.titleLabel)
        self.titleLabel.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(16)
            m.left.equalToSuperview().offset(16)
            m.right.equalToSuperview().offset(-16)
        }

        self.cardView.addSubview(self.valueLabel)
        self.valueLabel.snp.makeConstraints { (m) in
            m.top.equalTo(self.titleLabel.snp.bottom).offset(4)
            m.left.equalToSuperview().offset(16)
            m.right.equalToSuperview().offset(-16)
        }

        self.cardView.addSubview(self.barBackground)
        self.barBackground.snp.makeConstraints { (m) in
            m.top.equalTo(self.valueLabel.snp.bottom).offset(12)
            m.left.equalToSuperview().offset(16)
            m.right.equalToSuperview().offset(-16)
            m.height.equalTo(8)
        }
        [self.chatBar, self.cacheBar, self.otherBar].forEach { self.barBackground.addSubview($0) }

        self.cardView.addSubview(self.legendLabel)
        self.legendLabel.snp.makeConstraints { (m) in
            m.top.equalTo(self.barBackground.snp.bottom).offset(10)
            m.left.equalToSuperview().offset(16)
            m.right.equalToSuperview().offset(-16)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let height = self.barBackground.bounds.height
        let total = self.breakdown.totalBytes
        guard height > 0, total > 0 else {
            self.chatBar.frame = .zero
            self.cacheBar.frame = .zero
            self.otherBar.frame = .zero
            return
        }

        let width = self.barBackground.bounds.width
        let chatRatio = CGFloat(self.breakdown.chatBytes) / CGFloat(total)
        let cacheRatio = CGFloat(self.breakdown.cacheBytes) / CGFloat(total)

        var chatWidth = width * chatRatio
        var cacheWidth = width * cacheRatio
        // 有值但比例极小时给个最小可见宽度，避免"明明有占用却看不到"
        if self.breakdown.chatBytes > 0 { chatWidth = max(chatWidth, 3) }
        if self.breakdown.cacheBytes > 0 { cacheWidth = max(cacheWidth, 3) }
        if chatWidth + cacheWidth > width { cacheWidth = max(0, width - chatWidth) }
        let otherWidth = max(0, width - chatWidth - cacheWidth)

        self.chatBar.frame = CGRect(x: 0, y: 0, width: chatWidth, height: height)
        self.cacheBar.frame = CGRect(x: chatWidth, y: 0, width: cacheWidth, height: height)
        self.otherBar.frame = CGRect(x: chatWidth + cacheWidth, y: 0, width: otherWidth, height: height)
    }

    func applyLocalizedStrings() {
        self.titleLabel.text = L("总占用")
        self.refreshLegend()
    }

    func setLoading(_ loading: Bool) {
        if loading {
            self.valueLabel.text = "--"
            self.legendLabel.text = L("正在计算…")
        }
    }

    func configure(_ breakdown: FZMStorageBreakdown) {
        self.breakdown = breakdown
        self.valueLabel.text = FZMStorageManager.sizeText(breakdown.totalBytes)
        self.refreshLegend()
        self.setNeedsLayout()
    }

    private func refreshLegend() {
        self.legendLabel.text = L("聊天记录") + " " + FZMStorageManager.sizeText(self.breakdown.chatBytes)
            + "  ·  " + L("缓存") + " " + FZMStorageManager.sizeText(self.breakdown.cacheBytes)
            + "  ·  " + L("App 必要文件") + " " + FZMStorageManager.sizeText(self.breakdown.otherBytes)
    }
}

// MARK: - 缓存明细

class CacheDetailVC: UIViewController, ViewControllerProtocol {

    private lazy var tableView: UITableView = {
        let view = UITableView.init(frame: .zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.separatorStyle = .none
        view.dataSource = self
        view.delegate = self
        view.rowHeight = 50
        view.showsVerticalScrollIndicator = false
        view.register(SettingTextCell.self, forCellReuseIdentifier: "SettingTextCell")
        return view
    }()

    private lazy var clearButton: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.backgroundColor = Color_Theme
        btn.setTitle(L("清理缓存"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        btn.layer.cornerRadius = 22
        btn.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        return btn
    }()

    private var detail = FZMStorageCacheDetail()

    /// 缓存页说明：只有这里的内容会被「清理缓存」删掉
    private lazy var introLabel: UILabel = {
        let lab = UILabel.getLab(font: .regularFont(12), textColor: Color_8A97A5, textAlignment: .left,
                                 text: L("只清理缓存；聊天记录、App 必要文件不受影响"))
        lab.numberOfLines = 0
        return lab
    }()

    private lazy var introContainer: UIView = {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth - 30, height: 40))
        container.backgroundColor = .clear
        container.addSubview(self.introLabel)
        self.introLabel.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(4)
            m.right.equalToSuperview().offset(-4)
            m.top.bottom.equalToSuperview().inset(8)
        }
        return container
    }()

    private lazy var imageModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("图片缓存")
        model.rightString = "--"
        model.isShowLine = true
        model.showsArrow = false
        return model
    }()

    private lazy var otherModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("其它缓存")
        model.rightString = "--"
        model.isShowLine = false
        model.showsArrow = false
        return model
    }()

    private var languageChangeObserver: NSObjectProtocol?

    deinit {
        if let observer = languageChangeObserver {
            FZM_NotificationCenter.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        self.title = L("缓存")

        self.view.addSubview(self.clearButton)
        self.clearButton.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(44)
            m.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalTo(self.clearButton.snp.top).offset(-15)
        }
        self.tableView.tableHeaderView = self.introContainer

        languageChangeObserver = FZM_NotificationCenter.addObserver(
            forName: LanguageManager.LanguageChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] (_) in
            guard let self = self else { return }
            self.applyLocalizedStrings()
            self.tableView.reloadData()
        }

        self.applyLocalizedStrings()

        // 延后一拍：viewDidLoad 时视图还没上屏，HUD 加不上
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        var frame = introContainer.frame
        if frame.width != self.tableView.bounds.width {
            frame.size.width = self.tableView.bounds.width
            introContainer.frame = frame
            self.tableView.tableHeaderView = introContainer
        }
    }

    private func applyLocalizedStrings() {
        self.title = L("缓存")
        self.imageModel.leftString = L("图片缓存")
        self.otherModel.leftString = L("其它缓存")
        self.introLabel.text = L("只清理缓存；聊天记录、App 必要文件不受影响")
        self.clearButton.setTitle(L("清理缓存"), for: .normal)
    }

    private func loadData() {
        self.showProgress(with: L("正在计算…"))
        FZMStorageManager.shared.loadCacheDetail { [weak self] detail in
            guard let self = self else { return }
            self.hideProgress()
            self.detail = detail
            self.imageModel.rightString = FZMStorageManager.sizeText(detail.imageBytes)
            self.otherModel.rightString = FZMStorageManager.sizeText(detail.otherBytes)
            self.tableView.reloadData()
        }
    }

    @objc private func clearTapped() {
        let alert = UIAlertController.init(
            title: L("清理缓存"),
            message: L("清理后，图片和视频需要重新下载"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: L("确定"), style: .default, handler: { [weak self] (_) in
            guard let self = self else { return }
            self.showProgress(with: L("正在清理…"))
            FZMStorageManager.shared.clearCache {
                self.hideProgress()
                self.showToast(L("缓存已清理"))
                self.loadData()
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

extension CacheDetailVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: SettingTextCell.self, for: indexPath)
        cell.configure(with: indexPath.row == 0 ? self.imageModel : self.otherModel)

        let isFirstRow = indexPath.row == 0
        let isLastRow = indexPath.row == 1
        DispatchQueue.main.async {
            if isFirstRow && isLastRow {
                cell.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 5)
            } else if isFirstRow {
                cell.roundCorners([.topLeft, .topRight], radius: 5)
            } else {
                cell.roundCorners([.bottomLeft, .bottomRight], radius: 5)
            }
        }
        return cell
    }
}
