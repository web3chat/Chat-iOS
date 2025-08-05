//
//  FZMRedBagRecordView.swift
//  IMSDK
//
//  Created by 陈健 on 2019/3/20.
//

import UIKit
import MJRefresh

class FZMRedBagRecordView: UIView {
    
    lazy var dateView: UIView = {
        let v = UIView.init()
        return v
    }()
    
    lazy var numLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(14), textColor: UIColor.white, textAlignment: .center, text: nil)
        return lab
    }()
    
    lazy var countLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(40), textColor: UIColor.white, textAlignment: .center, text: nil)
        return lab
    }()
    
    lazy var headerView : UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 200))
        view.backgroundColor = UIColor(hex: 0xe14d5c)
        
        view.addSubview(dateView)
        dateView.snp.makeConstraints({ (m) in
            m.top.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(23)
            m.width.equalTo(65)
        })
        
        view.addSubview(numLab)
        numLab.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(65)
            m.height.equalTo(20)
        })
        view.addSubview(countLab)
        countLab.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(numLab.snp.bottom).offset(5)
            m.height.equalTo(56)
        })
        
        return view
    }()
    
    lazy var coverView: UIImageView = {
        let v = UIImageView.init(image: UIImage(named: "red_bag_cover"))
        v.contentMode = .scaleAspectFit
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: "暂无红包记录")
        v.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.top.equalTo(v.snp.bottom).offset(15)
            m.centerX.equalToSuperview()
        })
        return v
    }()
    
    var didFilterDateBlock: ((Int?,Date,Bool) -> ())?
    
    private var page = 0
    private var coinId: Int?
    private var startTime: Int?
    private var endTime: Int?
    private var model : IMRedPacketRecordListModel? {
        didSet {
            self.refreshHeaderView()
            self.coverView.isHidden = model?.redPackets.count != 0
        }
    }
    
    lazy var tableView : UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: UITableView.Style.plain)
        view.backgroundColor = Color_Theme
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.rowHeight = 80
        view.tableHeaderView = headerView
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat(k_SafeBottomInset)))
        view.separatorColor = UIColor(hex: 0xE6EAEE)
        view.separatorInset = UIEdgeInsets.init(top: 0, left: -20, bottom: 0, right: 0)
        view.delegate = self
        view.dataSource = self
        view.bounces = true
        view.register(IMRedBagRecordCell.self, forCellReuseIdentifier: "IMRedBagRecordCell")
        view.mj_footer = MJRefreshBackNormalFooter.init(refreshingBlock: {[weak self] in
            self?.loadMore()
        })
        view.addSubview(coverView)
        coverView.snp.makeConstraints({ (m) in
            m.centerX.equalToSuperview()
            m.centerY.equalToSuperview().offset(30)
        })
        coverView.isHidden = true
        return view
    }()
    
    let operation: IMRedPacketRecordType
    init(with operation: IMRedPacketRecordType) {
        self.operation = operation
        super.init(frame: CGRect.zero)
        self.addSubview(tableView)
        tableView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        self.makeRightItem(date: Date(),isAllYear: true)
        self.loadData()
    }
    
    let pageSize = 20
    func loadData() {
        self.page = 0
        self.showProgress(with: nil)
//        HttpConnect.shared().getRedPacketRecord(operation: self.operation.rawValue, coinId: self.coinId, type: nil, startTime: self.startTime, endTime: self.endTime, pageNum: 0, pageSize: pageSize) { (model, response) in
//            self.hideProgress()
//            guard response.success,let model = model else {
//                self.tableView.mj_footer.isHidden = true
//                self.showToast(with: response.message)
//                return
//            }
//            self.page = self.page + 1
//            self.model = model
//            self.tableView.reloadData()
//            self.tableView.mj_footer.isHidden = model.redPackets.count < self.pageSize
//            
//        }
    }
    
    func loadMore() {
//        HttpConnect.shared().getRedPacketRecord(operation: self.operation.rawValue, coinId: self.coinId, type: nil, startTime: self.startTime, endTime: nil, pageNum: self.page, pageSize: pageSize) { (model, response) in
//            self.hideProgress()
//            guard response.success,let model = model else {
//                self.showToast(with: response.message)
//                return
//            }
//            self.page = self.page + 1
//            self.model?.redPackets.append(contentsOf: model.redPackets)
//            self.tableView.mj_footer.endRefreshing()
//            if model.redPackets.count < self.pageSize {
//                self.tableView.mj_footer.isHidden = true
//            }
//            self.tableView.reloadData()
//
//        }
    }
    
    func makeRightItem(date : Date , isAllYear : Bool) -> Void {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy/MM"
        if isAllYear {
            formatter.dateFormat = "yyyy"
        }
        let title = formatter.string(from: date) + " "
        let lab = UILabel.getLab(font: UIFont.boldFont(16), textColor: UIColor.white, textAlignment: .right, text: nil)
        lab.isUserInteractionEnabled = true
        lab.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showDatePicker)))
        let image = UIImage(text: .right, imageSize: CGSize(width: 11, height: 11) , imageColor : UIColor.white)
        let textAttach = NSTextAttachment()
        textAttach.image = image
        let attMutStr = NSMutableAttributedString(string: title)
        attMutStr.append(NSAttributedString(attachment: textAttach))
        lab.attributedText = attMutStr
        dateView.subviews.first?.removeFromSuperview()
        dateView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.right.top.equalToSuperview()
        }
    }
    
    func didFilterDate(coinId:Int?, date : Date , isAllYear : Bool) -> Void {
        
        self.makeRightItem(date: date, isAllYear: isAllYear)
        
        self.coinId = coinId
        self.startTime = Int(date.timestamp)
        
        var nextDate: TimeInterval?
        let f = DateFormatter.init()
        if isAllYear {
            let nextYear = date.year + 1
            f.dateFormat = "yyyy"
//            nextDate = (f.date(from: "\(nextYear)"))?.timestamp
            let date = f.date(from: "\(nextYear)")
            nextDate = date!.timeIntervalSince1970 * 1000
        } else {
            let year = date.year
            let nextMonth = date.month + 1
            f.dateFormat = "yyyy/MM"
//            nextDate = (f.date(from: "\(year)/\(nextMonth)"))?.timestamp
            let date = f.date(from: "\(year)/\(nextMonth)")
            nextDate = date!.timeIntervalSince1970 * 1000
        }
        if let nextDate = nextDate {
            self.endTime = Int(nextDate)
        }
        self.loadData()
    }
    
    
    lazy private var filterView: FZMRedBagRecordFilterView = {
        let v = FZMRedBagRecordFilterView.init()
        v.confirmBlock = {[weak self] (selectedDate,selectedCoinType) in
            guard let strongSelf = self, let selectedDate = selectedDate else {return}
            let date = selectedDate.0
            let isAllYear = selectedDate.1
            
            strongSelf.didFilterDate(coinId: selectedCoinType, date: date, isAllYear: isAllYear)
            strongSelf.didFilterDateBlock?(selectedCoinType,date,isAllYear)
        }
        return v
    }()
    
    @objc func showDatePicker(){
        filterView.show()
    }
    
    
    func refreshHeaderView(){
        guard let model = self.model else { return }
        if self.coinId == nil {
            numLab.text = operation == .receive ? "共收到红包" : "共发出红包"
            countLab.text = "\(model.count)个"
        } else {
            let text = (operation == .receive ? "共收到" : "共发出") + "\(model.count)个\(model.coinName)红包，共计"
            let att = NSMutableAttributedString.init(string: text, attributes: [.font: UIFont.boldFont(14),.foregroundColor: UIColor.white])
            att.addAttributes([.foregroundColor: UIColor.init(hex: 0xFFDF5F)], range: NSRange.init(location: 3, length: "\(model.count)".count))
            numLab.attributedText = att
            countLab.text = "\(model.sum) \(model.coinName)"
        }
       
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


extension FZMRedBagRecordView : UITableViewDelegate,UITableViewDataSource{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let model = self.model else {
            return 0
        }
        return model.redPackets.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : IMRedBagRecordCell = tableView.dequeueReusableCell(withIdentifier: "IMRedBagRecordCell", for: indexPath) as! IMRedBagRecordCell
        guard let record = self.model else {
            return cell
        }
        let model = record.redPackets[indexPath.row]
        cell.configureWithData(packet: model, operation:operation )
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let record = self.model else {return}
        let packetId = record.redPackets[indexPath.row].packetId
        guard !packetId.isEmpty else { return }
        self.goToRedBagInfoVC(with: packetId)
    }
    
    private func goToRedBagInfoVC(with packetId:String){
        let infoVC = FZMRedBagInfoVC(with: packetId,isShowRecord:false)
        UIViewController.current()?.navigationController?.pushViewController(infoVC, animated: true)
    }
}
