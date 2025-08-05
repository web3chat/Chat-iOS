//
//  FZMRedBagCoinView.swift
//  IMSDK
//
//  Created by 陈健 on 2019/3/13.
//

import UIKit
import RxSwift
import SwiftyJSON

class FZMRedBagCoinView: UIView {
    private let disposeBag = DisposeBag.init()
    private let dataSubject = BehaviorSubject<[[String:Any]]>.init(value: [])
    var data = [[String:Any]]() {
        didSet {
            DispatchQueue.main.async {
                self.dataSubject.onNext(self.data)
            }
        }
    }
    
    var selectedBlock: IntBlock?
    
    private lazy var tableView: UITableView = {
        let v = UITableView.init(frame: CGRect.zero, style: .plain)
        v.register(FZMRedBagCoinCell.self, forCellReuseIdentifier: "FZMRedBagCoinCell")
        v.separatorStyle = .none
        v.keyboardDismissMode = .onDrag
        v.backgroundColor = Color_Theme
        v.rowHeight = 60
        v.tableFooterView = UIView.init()
        return v
    }()
    
    init() {
        super.init(frame: CGRect.zero)
        self.backgroundColor = Color_Theme
        createView()
        bindTableView()
    }
    
    private func createView() {
        let title = UILabel.getLab(font: UIFont.boldFont(17), textColor: UIColor(hex: 0x0D73AD), textAlignment: .left, text: "选择币种")
        title.backgroundColor = Color_Theme
        self.addSubview(title)
        title.snp.makeConstraints { (m) in
            m.top.equalTo(safeArea).offset(31)
            m.left.equalToSuperview().offset(15)
            m.height.equalTo(24)
        }
        self.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.top.equalTo(title.snp.bottom).offset(31)
            m.left.right.bottom.equalToSuperview()
        }
    }
    
    
    private func bindTableView() {
        dataSubject.bind(to: tableView.rx.items(cellIdentifier: "FZMRedBagCoinCell", cellType: FZMRedBagCoinCell.self)) {[weak self] (row, element, cell) in
            guard let strongSelf = self else {return}
            let model = strongSelf.getModel(with: element)
            cell.configure(with: model)
        }.disposed(by: disposeBag)
        
        tableView.rx.itemSelected.subscribe { [weak self] (event) in
            guard let strongSelf = self, case .next(let indexPath) = event else {return}
            strongSelf.selectedBlock?(indexPath.row)
        }.disposed(by: disposeBag)
    }
    
    var modelArray = [FZMRedBagCoinCellModel]()
    func getModel(with data: [String: Any]) -> FZMRedBagCoinCellModel {
        if let coin = data["coin"] as? Int, let model = (modelArray.filter {$0.coin == coin}.first) {
            return model
        } else {
            let model = FZMRedBagCoinCellModel.init(with: data)
            modelArray.append(model)
            return model
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
