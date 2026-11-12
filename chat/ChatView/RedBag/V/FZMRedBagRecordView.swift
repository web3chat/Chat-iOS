//
//  FZMRedBagRecordView.swift
//  IMSDK
//
//  Created by fzm on 2019/3/20.
//

import UIKit
import MJRefresh

class FZMRedBagRecordView: UIView {
    
    /// 父控制器顶部汇总文案（收到 / 发出 + 个数）
    var onSummaryStrings: ((String, String) -> Void)?
    /// 年份筛选变更，同步父控制器右上角展示
    var onFilterDateChanged: ((Date, Bool) -> Void)?

    private(set) var lastFilterDate = Date()
    private(set) var lastFilterIsAllYear = true
    
    /// 空态：信封图标 + 文案
    /// 旧实现把 label 挂在图片 **bounds 之外**、图片本身也没有尺寸约束，布局很脆；
    /// 这里改成容器 + 显式尺寸（先 addSubview，再建互相引用的约束）。
    lazy var coverView: UIView = {
        let v = UIView()
        let imageView = UIImageView(image: UIImage(named: "hongbao") ?? UIImage(named: "red_bag_cover"))
        imageView.contentMode = .scaleAspectFit
        v.addSubview(imageView)
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: RP.inkSoft, textAlignment: .center, text: L("暂无红包记录\n可切换右上角年份查看"))
        lab.numberOfLines = 0
        v.addSubview(lab)

        imageView.snp.makeConstraints({ (m) in
            m.top.equalToSuperview()
            m.centerX.equalToSuperview()
            m.size.equalTo(CGSize(width: 120, height: 120))
        })
        lab.snp.makeConstraints({ (m) in
            m.top.equalTo(imageView.snp.bottom).offset(16)
            m.left.right.bottom.equalToSuperview()
        })
        return v
    }()
    
    var didFilterDateBlock: ((Int?,Date,Bool) -> ())?
    
    var page = 0
    /// 列表加载中：防止 `viewWillAppear` / 切 tab / 筛选连续触发导致重复请求
    var isLoadingRecords = false
    var coinId: Int?
    var startTime: Int?
    var endTime: Int?
    var isAllYearFilter = true
    var model : IMRedPacketRecordListModel? {
        didSet {
            self.refreshHeaderView()
            self.coverView.isHidden = model?.redPackets.count != 0
        }
    }
    
    lazy var tableView : UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: UITableView.Style.plain)
        view.backgroundColor = RP.pageBg
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        // 卡片式行：卡片高 64 + 上下各 4pt 留白（与详情页领取记录一致）
        view.rowHeight = 72
        // 卡片之间靠间距区分，不用系统分割线
        view.separatorStyle = .none
        view.tableHeaderView = nil
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat(k_SafeBottomInset)))
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
        makeRightItem(date: Date(), isAllYear: true)
    }

    /// 由父控制器在回调就绪后调用，拉取列表数据
    func reloadFromParent() {
        loadData()
    }

    /// 切换 Tab 时刷新父控制器汇总文案
    func emitSummaryStrings() {
        refreshHeaderView()
    }
    
    let pageSize = 20
//    private var redPacketItems: [RedPacketListItemModel] = []

    func loadData() {
        guard !isLoadingRecords else { return }
        isLoadingRecords = true
        page = 0
        loadRedPacketRecordsFromWeb3(page: 0, replace: true)
        return
        self.page = 0
        self.showProgress(with: nil)

//         let service = RedPacketService()
        // 根据操作类型加载不同的红包列表
//        if operation == .receive {
//            service.getMyReceivedRedPackets { [weak self] result in
//                self?.handleLoadResult(result: result)
//            }
//        } else {
//            service.getMySentRedPackets { [weak self] result in
//                self?.handleLoadResult(result: result)
//            }
//        }
    }

//    private func handleLoadResult(result: Result<[RedPacketListItemModel], RedPacketServiceError>) {
//        hideProgress()
//
//        switch result {
//        case .success(let items):
//            self.page = 1
//            self.redPacketItems = items
//            self.convertToModel(items: items)
//            self.tableView.reloadData()
//            self.tableView.mj_footer!.isHidden = items.count < self.pageSize
//        case .failure(let error):
//            self.tableView.mj_footer!.isHidden = true
//            self.showToast(error.localizedDescription)
//        }
//    }

    func loadMore() {
        guard !isLoadingRecords else {
            tableView.mj_footer?.endRefreshing()
            return
        }
        isLoadingRecords = true
        page += 1
        loadRedPacketRecordsFromWeb3(page: page, replace: false)
    }

//    /// 将RedPacketListItemModel转换为IMRedPacketModel
//    private func convertToModel(items: [RedPacketListItemModel]) {
//        let packets = items.map { item -> IMRedPacketModel in
//            let json: [String: Any] = [
//                "packetId": item.id,
//                "type": item.type == .random ? 1 : 2,
//                "senderId": "",
//                "senderUid": "",
//                "senderAvatar": "",
//                "senderName": "",
//                "coinId": 0,
//                "coinName": item.coinName,
//                "amount": Float(item.amount) ?? 0,
//                "size": Int(item.count.split(separator: "/").last?.description ?? "0") ?? 0,
//                "toUsers": "",
//                "remain": 0,
//                "status": 1,
//                "remark": "",
//                "packetUrl": "",
//                "createdAt": item.timestamp * 1000
//            ]
//            return IMRedPacketModel(recordJson: SwiftyJSON.JSON(json))
//        }
//
//        let listModel = IMRedPacketRecordListModel(with: JSON([:]))
//        listModel.redPackets = packets
//        listModel.count = packets.count
//        listModel.sum = Float(items.reduce(0) { $0 + (Double($1.amount) ?? 0) })
//        listModel.coinName = items.first?.coinName ?? ""
//
//        self.model = listModel
//    }
    
    func makeRightItem(date : Date , isAllYear : Bool) -> Void {
        lastFilterDate = date
        lastFilterIsAllYear = isAllYear
        onFilterDateChanged?(date, isAllYear)
    }
    
    /// 只同步筛选条件，不触发加载（另一个 tab 用；切过去时再加载）
    func syncFilter(coinId: Int?, date: Date, isAllYear: Bool) {
        applyFilter(coinId: coinId, date: date, isAllYear: isAllYear)
    }

    func didFilterDate(coinId:Int?, date : Date , isAllYear : Bool) -> Void {
        applyFilter(coinId: coinId, date: date, isAllYear: isAllYear)
        self.loadData()
    }

    private func applyFilter(coinId: Int?, date: Date, isAllYear: Bool) {
        self.makeRightItem(date: date, isAllYear: isAllYear)

        self.coinId = coinId
        self.isAllYearFilter = isAllYear
        self.startTime = Int(date.timestamp)

        var nextDate: TimeInterval?
        let f = DateFormatter.init()
        if isAllYear {
            let nextYear = date.year + 1
            f.dateFormat = "yyyy"
            let date = f.date(from: "\(nextYear)")
            nextDate = date!.timeIntervalSince1970 * 1000
        } else {
            let year = date.year
            let nextMonth = date.month + 1
            f.dateFormat = "yyyy/MM"
            let date = f.date(from: "\(year)/\(nextMonth)")
            nextDate = date!.timeIntervalSince1970 * 1000
        }
        if let nextDate = nextDate {
            self.endTime = Int(nextDate)
        }
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
    
    
    func refreshHeaderView() {
        let defaultTitle = operation == .receive ? L("共收到红包") : L("共发出红包")
        let defaultCount = "0" + L("个")
        guard let model = self.model else {
            onSummaryStrings?(defaultTitle, defaultCount)
            return
        }
        if self.coinId == nil {
            let title = operation == .receive ? L("共收到红包") : L("共发出红包")
            let count = "\(model.count)" + L("个")
            onSummaryStrings?(title, count)
        } else {
            let fmt = operation == .receive ? L("共收到%@个%@红包，共计") : L("共发出%@个%@红包，共计")
            let title = String(format: fmt, "\(model.count)", model.coinName)
            let count = "\(model.sum) \(model.coinName)"
            onSummaryStrings?(title, count)
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
        let packet = record.redPackets[indexPath.row]
        let packetId = packet.packetId
        guard !packetId.isEmpty else { return }
        self.goToRedBagInfoVC(with: packetId, coinName: packet.coinName)
    }
    
    private func goToRedBagInfoVC(with packetId:String, coinName: String){
        let infoVC = FZMRedBagInfoVC(with: packetId, isShowRecord: false, coinName: coinName)
        UIViewController.current()?.navigationController?.pushViewController(infoVC, animated: true)
    }
}
