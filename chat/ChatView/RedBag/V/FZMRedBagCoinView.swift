//
//  FZMRedBagCoinView.swift
//  IMSDK
//
//  Created by fzm on 2019/3/13.
//

import UIKit
import RxSwift
import SwiftyJSON

class FZMRedBagCoinView: UIView {
    private let disposeBag = DisposeBag.init()

    /// 直接使用 LocalCoin 数组作为数据源
    private var coinArray: [LocalCoin] = []

    /// 选择币种回调，直接返回 LocalCoin
    var selectedBlock: ((LocalCoin) -> Void)?

    private lazy var tableView: UITableView = {
        let v = UITableView.init(frame: CGRect.zero, style: .plain)
        v.register(FZMRedBagCoinCell.self, forCellReuseIdentifier: "FZMRedBagCoinCell")
        v.separatorStyle = .none
        v.keyboardDismissMode = .onDrag
        v.backgroundColor = RP.cream
        v.rowHeight = 64
        v.tableFooterView = UIView.init()
        return v
    }()

    init() {
        super.init(frame: CGRect.zero)
        self.backgroundColor = RP.cream
        // 从右侧滑入的面板：只圆左侧两角。
        // ⚠️ 因为 tableView 铺满面板下半部，必须 masksToBounds 把子视图一起裁掉，
        // 否则 tableView 的方角会从圆角外露出来（代价：不投阴影）
        self.layer.cornerRadius = 20
        self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        self.layer.masksToBounds = true
        createView()
        bindTableView()
    }

    private func createView() {
        let title = UILabel.getLab(font: UIFont.regularFont(15), textColor: RP.inkSoft, textAlignment: .left, text: L("选择币种"))
        // 金色装饰竖条（先 addSubview，再建引用了它的约束）
        let goldBar = UIView()
        goldBar.backgroundColor = RP.gold
        goldBar.layer.cornerRadius = 1.5
        self.addSubview(goldBar)
        self.addSubview(title)
        goldBar.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalTo(title)
            m.size.equalTo(CGSize(width: 3, height: 14))
        }
        title.snp.makeConstraints { (m) in
            m.top.equalTo(safeArea).offset(28)
            m.left.equalTo(goldBar.snp.right).offset(8)
            m.height.equalTo(22)
        }
        self.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.top.equalTo(title.snp.bottom).offset(22)
            m.left.right.bottom.equalToSuperview()
        }
    }

    /// 设置数据源 - 直接使用 LocalCoin 数组
    func setCoins(_ coins: [LocalCoin]) {
        self.coinArray = coins
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    private func bindTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension FZMRedBagCoinView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coinArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FZMRedBagCoinCell", for: indexPath) as! FZMRedBagCoinCell
        let coin = coinArray[indexPath.row]
        let model = createModel(from: coin)
        cell.configure(with: model)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedCoin = coinArray[indexPath.row]
        selectedBlock?(selectedCoin)
    }

    /// 根据 LocalCoin 创建 FZMRedBagCoinCellModel
    private func createModel(from coin: LocalCoin) -> FZMRedBagCoinCellModel {
        let dict = RedPacketWalletBridge.convertToDictionary(coin: coin)
        return FZMRedBagCoinCellModel.init(with: dict)
    }
}
