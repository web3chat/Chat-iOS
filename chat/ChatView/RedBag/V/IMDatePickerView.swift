//
//  IMDatePickerView.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/18.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class IMDatePickerView: UIView {
    
    fileprivate var maxDate : Date = Date.init()
    
    fileprivate var minDate : Date = Date.init(timeIntervalSince1970: 0)
    
    
    fileprivate lazy var centerView : UIView = {
        let view = UIView()
        view.backgroundColor = FZM_BackgroundColor
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        let titleLab = UILabel.getLab(font: UIFont.regularFont(13), textColor: FZM_GrayWordColor, textAlignment: .left, text: "时间")
        view.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.height.equalTo(40)
        }
        return view
    }()
    
    fileprivate lazy var yearView : IMPickerColumnView = {
        let view = IMPickerColumnView.init()
        return view
    }()
    fileprivate lazy var monthView : IMPickerColumnView = {
        let view = IMPickerColumnView.init()
        return view
    }()
    
    fileprivate var yearDataArr = [String](){
        didSet{
            self.yearView.dataArr = yearDataArr
        }
    }
    fileprivate var yearIndex : NSInteger = 0
    
    fileprivate var monthDataArr = [String](){
        didSet{
            self.monthView.dataArr = monthDataArr
        }
    }
    fileprivate var monthIndex : NSInteger = 0
    
    var selectedDate:(Date,Bool)? {
        get {
            let yearStr = self.yearDataArr[self.yearIndex]
            let monthStr = self.monthDataArr[self.monthIndex]
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy年/MM月"
            var date = dateFormatter.date(from: "\(yearStr)/\(monthStr)")
            if monthStr == "全年" {
                dateFormatter.dateFormat = "yyyy年"
                date = dateFormatter.date(from: "\(yearStr)")
            }
            let isAllYear = monthStr.contains("全年")
            if let selectDate = date {
                return (selectDate, isAllYear)
            } else {
                return nil
            }
        }
    }
    
    
    convenience init() {
        self.init(maxDate: Date.init(), minDate: Date.init(timeIntervalSince1970: 0))
    }
    
    //MARK: 初始化
    init(maxDate : Date,minDate : Date) {
        self.maxDate = maxDate
        self.minDate = minDate
        super.init(frame: CGRect.zero)
        self.addSubview(centerView)
        centerView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        centerView.addSubview(self.yearView)
        yearView.selectIndexBlock = {[weak self] (index : NSInteger) in
            self?.yearIndex = index
            self?.loadMonth()
        }
        yearView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(40)
            m.left.equalToSuperview()
            m.right.equalTo(centerView.snp.centerX)
            m.height.equalTo(175)
        }
        centerView.addSubview(self.monthView)
        monthView.selectIndexBlock = {[weak self] (index : NSInteger) in
            self?.monthIndex = index
        }
        monthView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(40)
            m.right.equalToSuperview()
            m.left.equalTo(centerView.snp.centerX)
            m.height.equalTo(175)
        }
        self.loadYear()
    }
    
    func loadYear() -> Void {
        var yearDistance = maxDate.year - minDate.year
        var yearArr = [String]()
        while yearDistance >= 0 {
            yearArr.append("\(minDate.year + yearDistance)年")
            yearDistance -= 1
        }
        self.yearDataArr = yearArr
        self.loadMonth()
    }
    
    func loadMonth() -> Void {
        if yearView.selectRow == 0 {
            var monthIndex = maxDate.month
            let minIndex = yearView.selectRow == yearView.dataArr.count - 1 ? minDate.month : 1
            var monthArr = [String]()
            while monthIndex >= minIndex {
                monthArr.append("\(monthIndex)月")
                monthIndex -= 1
            }
            self.monthDataArr = monthArr
        }else if yearView.selectRow == yearView.dataArr.count - 1 {
            var monthIndex = minDate.month
            var monthArr = [String]()
            while monthIndex <= 12 {
                monthArr.append("\(monthIndex)月")
                monthIndex += 1
            }
            self.monthDataArr = monthArr.reversed()
        }else{
            self.monthDataArr = ["12月","11月","10月","9月","8月","7月","6月","5月","4月","3月","2月","1月",]
        }
        self.monthDataArr.insert("全年", at: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

fileprivate class IMPickerColumnView: UIView {
    private lazy var backTableView : UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: .plain)
        view.clipsToBounds = true
        view.rowHeight = 40
        view.backgroundColor = UIColor.clear
        view.separatorStyle = .none
        view.delegate = self
        view.dataSource = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.tableHeaderView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 80))
        view.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 80))
        view.register(IMDatePickerViewCell.self, forCellReuseIdentifier: "IMDatePickerViewCell")
        return view
    }()
    private lazy var centerTableView : UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: .plain)
        view.clipsToBounds = true
        view.rowHeight = 40
        view.backgroundColor = UIColor.clear
        view.separatorStyle = .none
        view.delegate = self
        view.dataSource = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.tableHeaderView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat.leastNormalMagnitude))
        view.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat.leastNormalMagnitude))
        view.register(IMDatePickerViewCell.self, forCellReuseIdentifier: "IMDatePickerViewCell")
        return view
    }()
    var dataArr = [String](){
        didSet{
            self.safeReload()
        }
    }
    
    var selectIndexBlock : ((_ index : NSInteger) -> ())?
    
    
    var selectRow : NSInteger = 0{
        didSet{
            selectIndexBlock?(selectRow)
        }
    }
    
    init() {
        super.init(frame: CGRect.zero)
        self.addSubview(self.backTableView)
        backTableView.snp.makeConstraints { (m) in
            m.top.bottom.left.right.equalToSuperview()
        }
        self.addSubview(self.centerTableView)
        centerTableView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.centerY.equalToSuperview()
            m.height.equalTo(40)
        }
        self.safeReload()
    }
    
    func safeReload() -> Void {
        backTableView.reloadData()
        centerTableView.reloadData()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension IMPickerColumnView : UITableViewDelegate,UITableViewDataSource,UIScrollViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArr.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IMDatePickerViewCell", for: indexPath) as! IMDatePickerViewCell
        cell.backgroundColor = .clear
        cell.titleLab.text = dataArr[indexPath.row]
        cell.titleLab.textColor = tableView == centerTableView ? FZM_BlackWordColor : FZM_GrayWordColor
        cell.titleLab.font = tableView == centerTableView ? UIFont.boldFont(18) : UIFont.regularFont(13)
        cell.titleLab.backgroundColor = tableView == centerTableView ? FZM_LineColor : UIColor.clear
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        centerTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        selectRow = indexPath.row
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        if scrollView == backTableView as UIScrollView {
            centerTableView.contentOffset = CGPoint.init(x: 0, y: offset.y)
        } else if scrollView == centerTableView as UIScrollView {
            backTableView.contentOffset = CGPoint.init(x: 0, y: offset.y)
        }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.scrollViewDidEndDecelerating(scrollView)
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let tableView = scrollView as? UITableView else {
            return
        }
        if tableView == backTableView {
            let indexPath = tableView.indexPathForRow(at: CGPoint.init(x: tableView.contentOffset.x, y: tableView.contentOffset.y + 100))
            if indexPath != nil {
                centerTableView.scrollToRow(at: indexPath!, at: .top, animated: true)
            }
        }else{
            let indexPath = tableView.indexPathForRow(at: CGPoint.init(x: tableView.contentOffset.x, y: tableView.contentOffset.y + 20))
            if indexPath != nil {
                centerTableView.scrollToRow(at: indexPath!, at: .top, animated: true)
            }
        }
        
        var row = NSInteger(centerTableView.contentOffset.y / 40 + 0.5)
        if row < 0 {
            row = 0
        }
        if row >= dataArr.count {
            row = dataArr.count - 1
        }
        selectRow = row
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
    }
}

fileprivate class IMDatePickerViewCell: UITableViewCell {
    
    lazy var titleLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: FZM_GrayWordColor, textAlignment: .center, text: nil)
        lab.isUserInteractionEnabled = true
        return lab
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.contentView.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}




class FZMSelectCoinView: UIView {
    
    var selectedCoinType: Int?
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout.init()
        layout.itemSize = CGSize.init(width: (k_ScreenWidth - 85 - 30 - 20) / 3 , height: 40)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        let v = UICollectionView.init(frame: CGRect.zero, collectionViewLayout: layout)
        v.backgroundColor = FZM_BackgroundColor
        v.delegate = self
        v.dataSource = self
        v.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "FZMSelectCoinCell")
        return v
    }()
    
    init() {
        super.init(frame: CGRect.zero)
        self.createViews()
        self.loadData()
    }
    
    var dataArray = Array<[String:Any]>.init() {
        didSet {
            collectionView.reloadData()
        }
    }
    
    func loadData() {
        self.showProgress()
//        HttpConnect.shared().getRedPacketBalance { (response) in
//            self.hideProgress()
//            if response.success == true, let array = response.data?["balances"].array?.compactMap({$0.dictionaryObject}) {
//                self.dataArray = [["coinName":"全部"]] + array
//            } else {
//                self.showToast(with: response.message)
//            }
//        }
    }
    
    func createViews() {
        let lab = UILabel.getLab(font: UIFont.regularFont(13), textColor: FZM_GrayWordColor, textAlignment: .center, text: "币种")
        self.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.height.equalTo(40)
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview()
        }
        
        self.addSubview(collectionView)
        collectionView.snp.makeConstraints { (m) in
            m.top.equalTo(lab.snp.bottom)
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FZMSelectCoinView: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FZMSelectCoinCell", for: indexPath)
        if let lab = cell.viewWithTag(1010) as? UILabel {
            lab.text = dataArray[indexPath.row]["coinName"] as? String
        } else {
            let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: FZM_BlackWordColor, textAlignment: .center, text: dataArray[indexPath.row]["coinName"] as? String)
            lab.tag = 1010
            lab.frame = cell.bounds
            cell.addSubview(lab)
            lab.layer.cornerRadius = 5
            lab.layer.masksToBounds = true
            lab.backgroundColor = .white
        }
        cell.backgroundColor = collectionView.backgroundColor
        if indexPath.row == 0 {
            self.selectCell(cell: cell)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath){
            let cionType = dataArray[indexPath.row]["coinId"] as? Int
            if self.selectedCoinType == cionType {
                self.selectedCoinType = nil
                self.deselectCell(cell: cell)
            } else {
                self.selectedCoinType = cionType
                self.selectCell(cell: cell)
            }
        }
    }
    
    func selectCell(cell: UICollectionViewCell) {
        collectionView.visibleCells.forEach { (cell) in
            self.deselectCell(cell: cell)
        }
        if let lab = cell.viewWithTag(1010) as? UILabel {
            lab.font = UIFont.boldFont(16)
            lab.backgroundColor = FZM_LuckyPacketColor
            lab.textColor = .white
        }
    }
    
    func deselectCell(cell: UICollectionViewCell) {
        if let lab = cell.viewWithTag(1010) as? UILabel {
            lab.font = UIFont.regularFont(16)
            lab.backgroundColor = UIColor.white
            lab.textColor = FZM_BlackWordColor
        }
    }
    
    
}


class FZMRedBagRecordFilterView: UIView {
    
    var confirmBlock : (((selectDate: Date, isAllYear: Bool)?, _ selectCoinType: Int?) -> ())?
    
    private let datePicker = IMDatePickerView.init()
    private let selectCoinView = FZMSelectCoinView.init()

    private lazy var coverView : UIView = {
        let view = UIView()
        view.backgroundColor = FZM_BackgroundColor
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        return view
    }()
    
    init() {
        super.init(frame: k_ScreenBounds)
        self.backgroundColor = UIColor.init(white: 0, alpha: 0.5)
        let backCtrl = UIControl.init(frame: k_ScreenBounds)
        backCtrl.addTarget(self, action: #selector(hide), for: .touchUpInside)
        self.addSubview(backCtrl)
        self.createViews()
    }
    
    
    @objc func hide() {
        let delay = DispatchTime.now() + 0.05
        DispatchQueue.main.asyncAfter(deadline: delay) {
            self.setNeedsUpdateConstraints()
            self.coverView.snp.updateConstraints { (m) in
                m.left.equalTo(self).offset(k_ScreenWidth)
            }
            UIView.animate(withDuration: 0.3, animations: {
                self.layoutIfNeeded()
            }, completion: { (_) in
                self.removeFromSuperview()
            })
        }
    }
    
    @objc func cancelBtnClick() -> Void {
        self.hide()
    }
    
    @objc func confirmBtnClick() -> Void {
        let selectedDate = datePicker.selectedDate
        let selectedCoin = selectCoinView.selectedCoinType
        self.confirmBlock?(selectedDate,selectedCoin)
        self.hide()
    }
    
    
    func show() -> Void {
        UIApplication.shared.keyWindow?.addSubview(self)
        let delay = DispatchTime.now() + 0.05
        DispatchQueue.main.asyncAfter(deadline: delay) {
            self.setNeedsUpdateConstraints()
            self.coverView.snp.updateConstraints { (m) in
                m.left.equalTo(self).offset(85)
            }
            UIView.animate(withDuration: 0.3) {
                self.layoutIfNeeded()
            }
        }
    }
    
    func createViews() {
        
        self.addSubview(coverView)
        coverView.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalTo(self).offset(k_ScreenWidth)
            m.width.equalToSuperview().offset(-85)
        }
        
        let cancelBtn = UIButton.init(type: .custom)
        cancelBtn.setAttributedTitle(NSAttributedString.init(string: "取消", attributes: [.foregroundColor:FZM_LuckyPacketColor,.font:UIFont.boldFont(16)]), for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        coverView.addSubview(cancelBtn)
        cancelBtn.layer.borderColor = FZM_LuckyPacketColor?.cgColor
        cancelBtn.layer.borderWidth = 1
        cancelBtn.layer.cornerRadius = 5
        cancelBtn.layer.masksToBounds = true
        cancelBtn.backgroundColor = FZM_WhiteColor
        cancelBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalTo(safeArea).offset(-15)
            m.width.equalToSuperview().multipliedBy(0.43)
            m.height.equalTo(40)
        }
        
        let confirmBtn = UIButton.init(type: .custom)
        confirmBtn.setAttributedTitle(NSAttributedString.init(string: "确定", attributes: [.foregroundColor:FZM_WhiteColor,.font:UIFont.boldFont(16)]), for: .normal)
        confirmBtn.addTarget(self, action: #selector(confirmBtnClick), for: .touchUpInside)
        coverView.addSubview(confirmBtn)
        confirmBtn.layer.cornerRadius = 5
        confirmBtn.layer.masksToBounds = true
        confirmBtn.backgroundColor = FZM_LuckyPacketColor
        confirmBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.bottom.equalTo(safeArea).offset(-15)
            m.width.equalTo(cancelBtn)
            m.height.equalTo(cancelBtn)
        }
        
        
        coverView.addSubview(datePicker)
        datePicker.snp.makeConstraints { (m) in
            m.top.equalTo(safeArea)
            m.left.right.equalToSuperview()
            m.height.equalTo(240)
        }
        
        coverView.addSubview(selectCoinView)
        selectCoinView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(datePicker.snp.bottom).offset(20)
            m.bottom.equalTo(confirmBtn.snp.top).offset(-15)
        }

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
