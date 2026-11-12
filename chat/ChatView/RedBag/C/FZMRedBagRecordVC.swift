//
//  FZMRedBagRecordVC.swift
//  Chat33
//
//  Created by fzm on 2018/11/13.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

class FZMRedBagRecordVC: FZMBaseViewController {
    
    private var showReceive = true
    /// 「收到 / 发出」列表是否需要加载；只加载当前可见的那个，另一个切过去再加载
    private var receiveNeedsReload = true
    private var sendNeedsReload = true

    private lazy var topView: UIView = {
        let v = UIView()
        v.backgroundColor = RP.redDeep
        // 红金渐变与底部金色凹弧在 viewDidLayoutSubviews 里铺（红头高度由内容撑开，那时才有 bounds）
        return v
    }()

    private lazy var backBtn: UIButton = {
        let b = UIButton(type: .custom)
        b.setImage(UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate), for: .normal)
        b.tintColor = .white
        b.enlargeClickEdge(12, 12, 12, 12)
        b.rx.controlEvent(.touchUpInside).subscribe(onNext: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }).disposed(by: disposeBag)
        return b
    }()

    private lazy var segmentControl: UISegmentedControl = {
        let segment = UISegmentedControl(items: [L("收到红包"), L("发出红包")])
        segment.setTitleTextAttributes([
            .font: UIFont.boldFont(15),
            .foregroundColor: UIColor.white.withAlphaComponent(0.62)
        ], for: .normal)
        segment.setTitleTextAttributes([
            .font: UIFont.boldFont(15),
            .foregroundColor: RP.goldDeep
        ], for: .selected)
        segment.selectedSegmentIndex = 0
        let selectedBg = UIImage.imageWithColor(with: RP.cream, size: CGSize(width: 100, height: 34))
        let normalBg = UIImage.imageWithColor(with: UIColor.clear, size: CGSize(width: 100, height: 34))
        if #available(iOS 13, *) {
            segment.setBackgroundImage(selectedBg, for: .selected, barMetrics: .default)
            segment.setBackgroundImage(normalBg, for: .normal, barMetrics: .default)
        } else {
            segment.tintColor = RP.cream
        }
        segment.layer.cornerRadius = 34 * 0.5
        segment.layer.masksToBounds = true
        segment.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        segment.layer.borderWidth = 1
        segment.rx.controlEvent(.valueChanged).subscribe(onNext: { [weak self] in
            self?.segmentValueChanged()
        }).disposed(by: disposeBag)
        return segment
    }()

    private lazy var yearLabel: UILabel = {
        let lab = UILabel()
        lab.textAlignment = .right
        lab.isUserInteractionEnabled = true
        lab.font = UIFont.boldFont(16)
        lab.textColor = .white
        return lab
    }()

    /// 「共收到红包」
    private lazy var summaryTitleLabel: UILabel = {
        UILabel.getLab(font: UIFont.regularFont(13), textColor: UIColor.white.withAlphaComponent(0.72), textAlignment: .center, text: L("共收到红包"))
    }()

    /// 「0个」 / 「1.23 BTY」
    private lazy var summaryCountLabel: UILabel = {
        let lab = UILabel.getLab(font: UIFont.rpAmountFont(44, weight: .semibold), textColor: RP.onRedStrong, textAlignment: .center, text: "0" + L("个"))
        lab.adjustsFontSizeToFitWidth = true
        lab.minimumScaleFactor = 0.6
        return lab
    }()

    private lazy var receiveTableView = FZMRedBagRecordView(with: .receive)

    private lazy var sendTableView = FZMRedBagRecordView(with: .send)

    override func viewDidLoad() {
        super.viewDidLoad()
        gk_statusBarStyle = .lightContent
        view.backgroundColor = RP.pageBg
        createUI()
        wireRecordCallbacks()
        updateYearLabel(date: receiveTableView.lastFilterDate, isAllYear: receiveTableView.lastFilterIsAllYear)
        syncSummaryFromVisibleList()
        // 不在 viewDidLoad 里加载：viewWillAppear 紧跟其后会再调一次，原来等于首屏发两轮请求
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 顶部红头：红金渐变（竖直，顶边与状态栏/导航同色）+ 底部金色凹弧
        topView.applyRPGradient(
            RP.primaryGradient, start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
        topView.applyRPTopCurve()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshRedPacketRecords()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    /// 只刷新当前可见的 tab。
    ///
    /// 原来 `viewWillAppear` 会把「收到」「发出」两个列表**同时**加载：
    /// 两个列表各自拉一遍 `getMyRedPacketIds` + 每笔红包详情，RPC 直接翻倍，
    /// 而用户其实只看其中一个。隐藏的那个先标脏，切过去时再加载。
    private func refreshRedPacketRecords() {
        if showReceive {
            receiveNeedsReload = false
            sendNeedsReload = true
            receiveTableView.loadData()
        } else {
            sendNeedsReload = false
            receiveNeedsReload = true
            sendTableView.loadData()
        }
    }

    private func loadVisibleTabIfNeeded() {
        if showReceive, receiveNeedsReload {
            receiveNeedsReload = false
            receiveTableView.loadData()
        } else if !showReceive, sendNeedsReload {
            sendNeedsReload = false
            sendTableView.loadData()
        }
    }

    private func createUI() {
        view.addSubview(topView)
        topView.addSubview(backBtn)
        topView.addSubview(segmentControl)
        topView.addSubview(yearLabel)
        topView.addSubview(summaryTitleLabel)
        topView.addSubview(summaryCountLabel)

        let yearTap = UITapGestureRecognizer(target: self, action: #selector(yearTapped))
        yearLabel.addGestureRecognizer(yearTap)

        backBtn.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(12)
            m.top.equalTo(topView.safeAreaLayoutGuide.snp.top).offset(4)
            m.width.height.equalTo(44)
        }

        segmentControl.snp.makeConstraints { m in
            m.centerY.equalTo(backBtn)
            m.centerX.equalToSuperview()
            m.height.equalTo(34)
            m.width.equalTo(220)
        }

        yearLabel.snp.makeConstraints { m in
            m.centerY.equalTo(backBtn)
            m.right.equalToSuperview().offset(-15)
            m.left.greaterThanOrEqualTo(segmentControl.snp.right).offset(8)
        }

        summaryTitleLabel.snp.makeConstraints { m in
            m.left.right.equalToSuperview().inset(20)
            m.top.equalTo(backBtn.snp.bottom).offset(20)
        }

        summaryCountLabel.snp.makeConstraints { m in
            m.left.right.equalToSuperview().inset(20)
            m.top.equalTo(summaryTitleLabel.snp.bottom).offset(6)
            // 留 28pt：底部凹弧会切掉 20pt，留太少会把数字下缘裁掉
            m.bottom.equalToSuperview().offset(-28)
        }

        topView.snp.makeConstraints { m in
            m.top.left.right.equalToSuperview()
        }

        sendTableView.didFilterDateBlock = { [weak self] coinId, date, isAllYear in
            guard let self = self else { return }
            // 只同步筛选条件，不加载隐藏的「收到」列表；切过去时再按新条件加载
            self.receiveTableView.syncFilter(coinId: coinId, date: date, isAllYear: isAllYear)
            self.receiveNeedsReload = true
        }

        receiveTableView.didFilterDateBlock = { [weak self] coinId, date, isAllYear in
            guard let self = self else { return }
            self.sendTableView.syncFilter(coinId: coinId, date: date, isAllYear: isAllYear)
            self.sendNeedsReload = true
        }

        view.addSubview(sendTableView)
        sendTableView.snp.makeConstraints { m in
            m.top.equalTo(topView.snp.bottom)
            m.bottom.left.right.equalToSuperview()
        }

        view.addSubview(receiveTableView)
        receiveTableView.snp.makeConstraints { m in
            m.top.equalTo(topView.snp.bottom)
            m.bottom.left.right.equalToSuperview()
        }

        view.bringSubviewToFront(receiveTableView)
    }

    private func wireRecordCallbacks() {
        receiveTableView.onSummaryStrings = { [weak self] title, count in
            guard let self = self, self.showReceive else { return }
            self.summaryTitleLabel.text = title
            self.summaryCountLabel.text = count
        }
        receiveTableView.onFilterDateChanged = { [weak self] date, allYear in
            self?.updateYearLabel(date: date, isAllYear: allYear)
        }

        sendTableView.onSummaryStrings = { [weak self] title, count in
            guard let self = self, !self.showReceive else { return }
            self.summaryTitleLabel.text = title
            self.summaryCountLabel.text = count
        }
        sendTableView.onFilterDateChanged = { [weak self] date, allYear in
            self?.updateYearLabel(date: date, isAllYear: allYear)
        }
    }

    @objc private func yearTapped() {
        let active = showReceive ? receiveTableView : sendTableView
        active.showDatePicker()
    }

    private func updateYearLabel(date: Date, isAllYear: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = isAllYear ? "yyyy" : "yyyy/MM"
        let title = formatter.string(from: date) + " "
        let image = UIImage(text: .right, imageSize: CGSize(width: 11, height: 11), imageColor: .white)
        let textAttach = NSTextAttachment()
        textAttach.image = image
        let attMutStr = NSMutableAttributedString(string: title, attributes: [
            .font: UIFont.boldFont(16),
            .foregroundColor: UIColor.white
        ])
        attMutStr.append(NSAttributedString(attachment: textAttach))
        yearLabel.attributedText = attMutStr
    }

    private func segmentValueChanged() {
        showReceive = segmentControl.selectedSegmentIndex == 0
        if showReceive {
            view.bringSubviewToFront(receiveTableView)
        } else {
            view.bringSubviewToFront(sendTableView)
        }
        loadVisibleTabIfNeeded()
        syncSummaryFromVisibleList()
    }

    private func syncSummaryFromVisibleList() {
        let v = showReceive ? receiveTableView : sendTableView
        v.emitSummaryStrings()
        updateYearLabel(date: v.lastFilterDate, isAllYear: v.lastFilterIsAllYear)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}



