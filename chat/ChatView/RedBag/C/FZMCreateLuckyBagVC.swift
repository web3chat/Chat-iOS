//
//  FZMCreateLuckyBagVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/11/7.
//  Copyright © 2018年 吴文拼. All rights reserved.
//


import UIKit
import RxSwift
import KeychainAccess

class FZMCreateLuckyBagVC: FZMBaseViewController {
    
    let toId : String
    let isGroup : Bool
    var isRandom = true
    var isTextRedBag = false
    
    var sendCompleteBlock : (( Int, String, IMRedPacketType, String, String, String, Bool)->())?
    
    lazy var coinTypeLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = Color_24374E
        lbl.font = UIFont.regularFont(18)
        return lbl
    }()
    
    lazy var coinTypeLab2: UILabel = {
        let lbl = UILabel()
        lbl.textColor = Color_24374E
        lbl.font = UIFont.regularFont(17)
        lbl.text = coinTypeLab.text
        return lbl
    }()
    
    lazy var totalCountLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = Color_24374E
        lbl.font = UIFont.boldFont(40)
        return lbl
    }()
    
    var packetType: IMRedPacketType = .luck
    
    lazy var randomView: UIView = {
        let view = UIView.init()
        let arrowsImageV = UIImageView()
        arrowsImageV.image = UIImage.init(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate)
        arrowsImageV.contentMode = .scaleAspectFit
        arrowsImageV.tintColor = UIColor.init(hex: 0xF4C85D)
        view.addSubview(arrowsImageV)
        arrowsImageV.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview()
            m.width.equalTo(6)
            m.height.equalTo(10)
        })
        
        let manyImageV = UIImageView()
        manyImageV.image = UIImage.init(named:"send_bag_many")
        view.addSubview(manyImageV)
        manyImageV.snp.makeConstraints({ (m) in
            m.centerY.equalToSuperview()
            m.left.equalTo(arrowsImageV.snp.right).offset(5)
            m.width.height.equalTo(20)
        })
        
        let totalLbl = UILabel()
        totalLbl.textColor = Color_24374E
        totalLbl.font = UIFont.regularFont(18)
        view.addSubview(totalLbl)
        totalLbl.snp.makeConstraints({ (m) in
            if self.isGroup {
                m.left.equalTo(manyImageV.snp.right).offset(10)
            } else {
                arrowsImageV.isHidden = true
                manyImageV.isHidden = true
                m.left.equalToSuperview()
            }
            m.centerY.equalToSuperview()
        })
        
        if self.isGroup {
            totalLbl.text = "总数额"
        } else {
            totalLbl.text = "单个数额"
        }
        
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            if let strongSelf = self, strongSelf.isGroup {
                strongSelf.isRandom = !strongSelf.isRandom
                if strongSelf.isRandom {
                    arrowsImageV.tintColor = UIColor.init(hex: 0xF4C85D)
                    manyImageV.image = UIImage.init(named:"send_bag_many")
                    totalLbl.text = "总数额"
                    strongSelf.packetType = .luck
                } else {
                    arrowsImageV.tintColor = UIColor.init(hex: 0xF06666)
                    manyImageV.image = UIImage.init(named:"send_bag_common")
                    totalLbl.text = "单个数额"
                    strongSelf.packetType = .common
                }
                strongSelf.setTotalCount()
            }
        }).disposed(by: disposeBag)
        view.addGestureRecognizer(tap)
        
        return view
    }()

    lazy var bagMoneyTF: UITextField = {
        let tf = UITextField()
        tf.textAlignment = .right
        tf.keyboardType = .decimalPad
        tf.font = UIFont.regularFont(18)
        return tf
    }()
    
    lazy var balanceLbl: UILabel = {
        let lbl = UILabel()
        lbl.textColor =  Color_Theme
        lbl.textAlignment = .right
        lbl.font = UIFont.regularFont(14)
        lbl.text = "余额 0"
        lbl.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            if strongSelf.selectedIndex < strongSelf.dataArray.count || strongSelf.selectedIndex >= 0 {
                let model = FZMRedBagCoinCellModel.init(with: strongSelf.dataArray[strongSelf.selectedIndex])
                guard  model.amount > strongSelf.fee else { return }
                strongSelf.bagMoneyTF.text = "\((model.amount - strongSelf.fee).roundTo(places: model.decimalPlaces))"
                strongSelf.setTotalCount()
            }
        }).disposed(by: disposeBag)
        lbl.addGestureRecognizer(tap)
        return lbl
    }()
    
    lazy var bagNumberTF: UITextField = {
        let tf = UITextField()
        tf.placeholder = "填入数量"
        tf.textAlignment = .right
        tf.keyboardType = .numberPad
        tf.font = UIFont.regularFont(18)
        return tf
    }()
    
    
    lazy var bagRemark: UITextField = {
        let tf = UITextField()
        tf.layer.cornerRadius = 3
        tf.layer.masksToBounds = true
        tf.sizeToFit()
        tf.placeholder = self.isTextRedBag ? "请输入消息内容" : "恭喜发财，大吉大利！"
        return tf
    }()
    
    lazy var changeTypeView: UIImageView = {
        let v = UIImageView.init()
        v.isUserInteractionEnabled = true
        v.image = self.isTextRedBag ? UIImage(named:"redBag_msgType") : UIImage(named:"redBag_bagType")
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(changeRedBagType))
        v.addGestureRecognizer(tap)
        return v
    }()
    
    var remarkCount: Int {
        get{
            return self.isTextRedBag ? 500 : 20
        }
    }
    
    lazy var remarkCountLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = Color_8A97A5
        lbl.textAlignment = .right
        lbl.font = UIFont.regularFont(14)
        lbl.text = "0/" + "\(self.remarkCount)"
        return lbl
    }()
    
     let sendBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = UIColor(hex: 0xE14D5C)
        btn.setTitle("塞币进红包", for: .normal)
        btn.titleLabel?.font = UIFont.boldFont(18)
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.setTitleColor(UIColor(hex: 0xff7878), for: .disabled)
        btn.layer.cornerRadius = 25
        btn.layer.masksToBounds = true
        return btn
    }()
    
     let adBtn: UIButton = {
        let btn = UIButton(type: .custom)
         btn.backgroundColor = UIColor(hex: 0xE14D5C)
        btn.setTitle("推广红包", for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(18)
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.setTitleColor(UIColor(hex: 0xff7878), for: .disabled)
        btn.layer.cornerRadius = 3
        btn.layer.masksToBounds = true
        return btn
    }()
    
    
    lazy var coinView: FZMRedBagCoinView = {
        let view = FZMRedBagCoinView.init()
        view.selectedBlock = {[weak self] (index) in
            self?.selectedIndex = index
            self?.hideCoinView()
        }
        return view
    }()
    
    let bty: UILabel = {
        let lbl = UILabel()
        lbl.textColor = Color_24374E
        lbl.font = UIFont.regularFont(18)
        return lbl
    }()
    
    var decimalPlaces: Int = 0
    var singleMax:Double = 0
    var singleMin:Double = 0 {
        didSet {
            bagMoneyTF.placeholder = "最小" + "\(singleMin)"
        }
    }
    
    var balance:Double = 0
    var selectedIndex: Int = -1 {
        didSet {
            guard selectedIndex != oldValue else {return}
            if selectedIndex < self.dataArray.count || selectedIndex >= 0 {
                let model = FZMRedBagCoinCellModel.init(with: self.dataArray[selectedIndex])
                self.decimalPlaces = model.decimalPlaces
                self.singleMax = model.singleMax
                self.singleMin = model.singleMin
                self.coinTypeLab.text = model.coinName
                self.bty.text = self.coinTypeLab.text
                self.coinTypeLab2.text = self.coinTypeLab.text
                self.balance = model.amount.roundTo(places: model.decimalPlaces)
                self.balanceLbl.text = "可用 " + "\(self.balance)" + model.coinName
                self.bagMoneyTF.text = nil
                if self.isGroup {
                    self.bagNumberTF.text = nil
                    self.fee = model.fee
                }
                self.setTotalCount()
            }
        }
    }
 
    lazy var coinViewGroup: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight))
        view.backgroundColor = UIColor.init(white: 0, alpha: 0.7)
        
        let tap = UITapGestureRecognizer.init()
        tap.delegate = self
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            self?.hideCoinView()
        }).disposed(by: disposeBag)
        view.addGestureRecognizer(tap)
        
        coinView.frame = CGRect.init(x: view.frame.size.width, y: 0, width: view.frame.size.width - 70, height: view.frame.size.height)
        view.addSubview(coinView)
        return view
    }()
    
    var fee: Double = 0 {
        didSet {
            if fee < 0.00000001 {
                feeLab.isHidden = true
            } else {
                feeLab.isHidden = false
                feeLab.text = "群红包每次收取" + "\(fee)" + (self.coinTypeLab.text ?? "") + "手续费"
            }
        }
    }
    
    lazy var feeLab: UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_Theme, textAlignment: .center, text: "")
    }()
    
    
    private lazy var changeRedBagTypeGuideView: UIView = {
        let bgView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight))
        bgView.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha:0.8)
        
        let imageView = UIImageView.init(image: UIImage(named:"redBag_msg_guide"))
        imageView.contentMode = .scaleAspectFill
        
        bgView.addSubview(imageView)
        imageView.snp.makeConstraints { (m) in
            m.bottom.equalTo(bgView.snp.centerY).offset(-80)
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize.init(width: 310, height: 143))
        }

        let tapView = UIImageView.init(image: UIImage(named:"admire_guide_know"))
        tapView.isUserInteractionEnabled = true
        tapView.contentMode = .scaleAspectFit
        
        bgView.addSubview(tapView)
        tapView.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(imageView.snp.bottom).offset(134)
        }
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: {[weak self, weak bgView] (_) in
            self?.view.isUserInteractionEnabled = true
            bgView?.removeFromSuperview()
        }).disposed(by: disposeBag)
        tapView.addGestureRecognizer(tap)
        
        return bgView
    }()
    
    @objc func changeRedBagType() {
        self.isTextRedBag = !self.isTextRedBag
        self.changeTypeView.image = self.isTextRedBag ? UIImage(named:"redBag_msgType") : UIImage(named:"redBag_bagType")
        self.bagRemark.placeholder = self.isTextRedBag ? "请输入消息内容" : "恭喜发财，大吉大利！"
        self.bagRemark.limitText(with: 20)
        let count = self.bagRemark.text?.count ?? 0
        self.remarkCountLab.text = "\(count)" + "/" + "\(self.remarkCount)"
    }
    
    func showCoinView() {
        
        UIApplication.shared.keyWindow?.addSubview(coinViewGroup)
        UIView.animate(withDuration: 0.3) {
            self.coinView.frame = CGRect.init(x: 70, y: 0, width: self.coinView.frame.size.width, height: self.coinView.frame.size.height)
        }
    }
    
    func hideCoinView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.coinView.frame = CGRect.init(x: self.coinViewGroup.frame.size.width, y: 0, width: self.coinView.frame.size.width, height: self.coinView.frame.size.height)
        }) { (_) in
            self.coinViewGroup.removeFromSuperview()
        }
    }
    
    init(to: String, isGroup: Bool) {
        self.toId = to
        self.isGroup = isGroup
        self.isRandom = isGroup
        super.init()
        if !isGroup {
            self.bagNumberTF.text = "1"
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.navBarColor = UIColor(hex: 0xFAFBFC)
//        self.navTintColor = Color_Theme
//        self.navTitleColor = Color_Theme
        self.navigationItem.title = "发红包"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "红包记录", style: .plain, target: self, action: #selector(pushToRecord))
        self.navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : Color_Theme,.font : UIFont.boldFont(14)], for: .normal)
        self.navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : Color_Theme,.font : UIFont.boldFont(14)], for: .highlighted)
        initView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (try? Keychain.init().getString((LoginUser.shared().address + "change_redBag_type_guide"))) == nil {
            UIApplication.shared.keyWindow?.addSubview(self.changeRedBagTypeGuideView)
            self.view.isUserInteractionEnabled = false
            try? Keychain.init().set("hasShow", key: (LoginUser.shared().address + "change_redBag_type_guide"))
        }
    }
    
    @objc func pushToRecord() {
        let vc = FZMRedBagRecordVC.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    private func initView() {
        setupViews()
        setActions()
        self.loadData()
    }
    
    var dataArray = Array<[String:Any]>.init() {
        didSet {
            coinView.data = dataArray
            if !dataArray.isEmpty {
                self.selectedIndex = 0
            }
        }
    }
    
    func loadData() {
        self.showProgress()
//        HttpConnect.shared().getRedPacketBalance { (response) in
//            self.hideProgress()
//            if response.success == true, let array = response.data?["balances"].array?.compactMap({$0.dictionaryObject}) {
//                self.dataArray = array
//            } else {
//                self.showToast(with: response.message)
//            }
//        }
    }
    
    private func setActions() {
        Observable.combineLatest([bagMoneyTF.rx.text, bagNumberTF.rx.text]).subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.bagNumberTF.limitText(with: 10)
            if strongSelf.bagNumberTF.text ?? "" == "0" {
                strongSelf.bagNumberTF.text = nil
            }
            
            if strongSelf.bagMoneyTF.text ?? "" == "." {
                strongSelf.bagMoneyTF.text = nil
            }
            
            if let text = strongSelf.bagMoneyTF.text, text.count == 2,
                let first = text.first, first == Character.init("0"),
                text != "0."{
                 strongSelf.bagMoneyTF.text = "0"
            }
            
            
            if let text = strongSelf.bagMoneyTF.text, let last = text.last, last == Character.init(".") {
                let newText = text.substring(to: text.count - 2)
                if newText.contains(".") {
                    strongSelf.bagMoneyTF.text = newText
                }
            }
           
            if let text = strongSelf.bagMoneyTF.text,
                text.contains("."),
                let integer = (text as NSString).components(separatedBy: ".").first,
                let decimal = (text as NSString).components(separatedBy: ".").last,
                decimal.count > strongSelf.decimalPlaces {
                strongSelf.bagMoneyTF.text = integer + "." + decimal.substring(to: strongSelf.decimalPlaces - 1)
            }
            
            if Double(strongSelf.bagMoneyTF.text ?? "0") ?? 0 > strongSelf.balance - strongSelf.fee {
                if (strongSelf.balance - strongSelf.fee) <= 0 {
                    strongSelf.bagMoneyTF.text = ""
                } else {
                    strongSelf.bagMoneyTF.text = "\(strongSelf.balance - strongSelf.fee)"
                }
            }
            var btnEnabled = false
            if let money = strongSelf.bagMoneyTF.text, let numberString = strongSelf.bagNumberTF.text, let number = Int(numberString), let moneyNumber = Double(money) {
                if moneyNumber > strongSelf.balance {
                    strongSelf.bagMoneyTF.text = "\(strongSelf.balance)"
                }
                btnEnabled = moneyNumber > 0 && number > 0
            }
            strongSelf.setBtnEnable(btnEnabled)
            strongSelf.setTotalCount()
            
        }).disposed(by: disposeBag)
        //发送红包
        sendBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.checkPaw(with: 1)
            
        }).disposed(by: disposeBag)
        
        adBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.checkPaw(with: 2)
        }).disposed(by: disposeBag)
        
        bagRemark.rx.text.orEmpty.asObservable().subscribe(onNext: { [weak self] (str) in
            guard let strongSelf = self else{ return }
            strongSelf.bagRemark.limitText(with: strongSelf.remarkCount)
            if let text = strongSelf.bagRemark.text, text.count > 0 {
                strongSelf.remarkCountLab.text = "\(text.count)/" + "\(strongSelf.remarkCount)"
            }else {
                strongSelf.remarkCountLab.text = "0/" + "\(strongSelf.remarkCount)"
            }
        }).disposed(by: disposeBag)
    }
    
    private func setTotalCount() {
        if !self.isRandom {
            if let str1 = self.bagMoneyTF.text, let str2 = self.bagNumberTF.text,
                let mu = Double(str1), let count = Double(str2) {
                if mu == 0 {
                    return
                }
                let total = mu * count + fee
                var totalCount = "\(total)"
                
                if let decimals = totalCount.components(separatedBy: ".").last, decimals.count == 1 {
                    totalCount = totalCount + "0"
                }
                self.totalCountLab.text =  totalCount
                
                if total > self.balance {
                    self.showToast("资产不足")
                    self.setBtnEnable(false)
                    return
                }
                
                if count > 99999 {
                    self.showToast("红包个数不能大于99999")
                    self.setBtnEnable(false)
                    return
                }
                
                if mu < self.singleMin {
                    self.showToast("单个红包金额不能小于\(self.singleMin)")
                    self.setBtnEnable(false)
                    return
                }
                if total > self.singleMax {
                    self.showToast("红包总金额不能大于\(self.singleMax)")
                    self.setBtnEnable(false)
                    return
                }
                self.setBtnEnable(true)
                
            } else {
                self.totalCountLab.text = "0.00"
                self.setBtnEnable(false)
            }
        } else {
            if let str1 = self.bagMoneyTF.text,let mu = Double(str1) {
                if mu == 0 {
                    return
                }
                let total = mu + fee
                var totalCount = "\(total)"
                
                if let decimals = totalCount.components(separatedBy: ".").last, decimals.count == 1 {
                    totalCount = totalCount + "0"
                }
                self.totalCountLab.text =  totalCount
                
                if mu < self.singleMin {
                    self.showToast("红包金额不能小于\(self.singleMin)")
                    self.setBtnEnable(false)
                    return
                }
                
                if mu > self.singleMax {
                    self.showToast("红包金额不能大于\(self.singleMax)")
                    self.setBtnEnable(false)
                    return
                }
                
                guard let str2 = self.bagNumberTF.text,let count = Double(str2) else { return }
                if count > 99999 {
                    self.showToast("红包个数不能大于99999")
                    self.setBtnEnable(false)
                    return
                }
                if (mu >= self.singleMin) && (mu / count) < pow(0.1, Double(self.decimalPlaces)).roundTo(places: self.decimalPlaces) {
                    self.showToast("当前金额下红包个数不能大于\(Int((mu / pow(0.1, Double(self.decimalPlaces))).rounded()))")
                    self.setBtnEnable(false)
                    return
                }
                self.setBtnEnable(true)
                
            } else {
                self.totalCountLab.text = "0.00"
                self.setBtnEnable(false)
            }
        }
    }
    
    private func checkPaw(with type: Int) {
        self.view.endEditing(true)
//        IMLoginUserManager.shared().isSetPayPwd { arr in
//            guard let isSetPayPwd = arr[0] as? Bool, let response = arr[1] as? HttpResponse else { return }
//            if response.success == true {
//                if isSetPayPwd {
//                    if let total = self.totalCountLab.text, let type = self.coinTypeLab.text {
//                        let inpPawView = FZMInputPawAlertView.init(title: total + " " + type)
//                        inpPawView.okBlock = {[weak self] (pwd) in
//                            self?.sendRedPacket(with: pwd)
//                        }
//                        inpPawView.forgetBlock = {[weak self] in
//                            let vc = PWChangePwdViewController.init()
//                            self?.navigationController?.pushViewController(vc, animated: true)
//                        }
//                        inpPawView.show()
//                    }
//                    
//                }else {
//                    let alert =  FZMAlertView.init(with: NSAttributedString.init(string: "为了您的账户资金安全，请先设置支付密码", attributes: [NSAttributedString.Key.foregroundColor: FZM_BlackWordColor]), confirmBlock: {
//                        let vc = FZMSetPayPwdController.init()
//                        self.navigationController?.pushViewController(vc, animated: true)
//                    })
//                    alert.show()
//                }
//            }else {
//                self.showToast(with: response.message)
//            }
//        }
    }
    
    private func sendRedPacket(with pwd :String) {
        
        var remark = "恭喜发财，大吉大利"
        if let txt = self.bagRemark.text, txt.count > 0 {
            remark = txt
        }
        guard let money = self.totalCountLab.text, let numberString = self.bagNumberTF.text, let number = Int(numberString), let moneyNumber = Double(money) else {
            return
        }
        let amount = moneyNumber - Double(self.fee)
        guard self.selectedIndex < self.dataArray.count && self.selectedIndex >= 0,
            let coin = self.dataArray[self.selectedIndex]["coinId"] as? Int,
            let coinName = self.dataArray[self.selectedIndex]["coinName"] as? String   else {return}
        self.showProgress(with: nil)
        let type = isRandom ? 1 : 2
//        HttpConnect.shared().sendRedPacket(isGroup: isGroup, toId: self.toId, coin: coin, type: type, amount: amount, size:number , remark: remark, toUsers: "", ext: ["pay_password" : pwd]) { (packetId, packetUrl, response) in
//            self.hideProgress()
//            guard response.success, let packetId = packetId, let packetUrl = packetUrl else {
//                self.showToast(with: response.message)
//                return
//            }
//            //发socket消息
//            self.sendCompleteBlock?(coin,coinName,self.packetType,packetId,packetUrl,remark,self.isTextRedBag)
//            self.popLongBack(to: FZMConversationChatVC.self)
//        }
    }
    
    private func setBtnEnable(_ enabled: Bool) {
        sendBtn.isEnabled = enabled
        adBtn.isEnabled = enabled
        adBtn.backgroundColor = UIColor(hex: enabled ? 0xE33143: 0xD45353)
        sendBtn.backgroundColor = UIColor(hex: enabled ? 0xE33143: 0xD45353)
    }
    private func setupViews() {
        let luckyImageV: UIImageView = {
            let imgV = UIImageView()
            imgV.contentMode = .scaleAspectFill
            imgV.image = UIImage(named: "")
            return imgV
        }()
        self.view.addSubview(luckyImageV)
        let bgView = UIView()
        bgView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer()
        bgView.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            self?.dismissKeyboard()
        }).disposed(by: disposeBag)
        self.view.addSubview(bgView)
        
        luckyImageV.snp.makeConstraints { (m) in
            m.edges.equalTo(self.safeArea)
        }
        bgView.snp.makeConstraints { (m) in
            m.edges.equalTo(self.safeArea)
        }
        
        let coinTypePart: UIView = {
           let v = UIView.init()
            v.makeOriginalShdowShow()
            return v
        }()
        bgView.addSubview(coinTypePart)
        
        let coinName: UILabel = {
            let lbl = UILabel()
            lbl.textColor = Color_24374E
            lbl.font = UIFont.regularFont(18)
            lbl.text = "币种"
            return lbl
        }()
        let arrowsImageV: UIImageView = {
            let v = UIImageView.init()
            v.image = UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate)
            v.contentMode = .scaleAspectFit
            v.tintColor = UIColor.init(hex: 0x333333)
            v.transform = CGAffineTransform.init(rotationAngle: CGFloat(Double.pi))
            return v
        }()
        
        coinTypePart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.top.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(50)
        }
        
        coinTypePart.addSubview(coinName)
        coinName.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
        }
        coinTypePart.addSubview(arrowsImageV)
        arrowsImageV.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.width.equalTo(6)
            m.height.equalTo(10)
        }
        coinTypePart.addSubview(coinTypeLab)
        coinTypeLab.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalTo(arrowsImageV.snp.left).offset(-10)
        }
        
        let tap2 = UITapGestureRecognizer.init()
        tap2.rx.event.subscribe(onNext: {[weak self] (_) in
            self?.showCoinView()
        }).disposed(by: disposeBag)
        coinTypePart.addGestureRecognizer(tap2)
        
        
        let onePart: UIView = {
            let v = UIView()
            v.makeOriginalShdowShow()
            return v
        }()
        bgView.addSubview(onePart)
        onePart.addSubview(randomView)
        onePart.addSubview(bagMoneyTF)
        
        onePart.addSubview(bty)
        
        onePart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.top.equalTo(coinTypePart.snp.bottom).offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(coinTypePart)
        }
        randomView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.bottom.equalToSuperview()
            m.width.equalTo(101)
        }
        
        bagMoneyTF.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(90)
            m.centerY.equalToSuperview()
            m.trailing.equalToSuperview().offset(-64)
            m.height.equalTo(40)
        }
        bty.snp.makeConstraints { (m) in
            m.trailing.equalToSuperview().offset(-10)
            m.centerY.equalToSuperview()
        }
        
        bgView.addSubview(balanceLbl)
        balanceLbl.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.top.equalTo(onePart.snp.bottom).offset(10)
            m.height.equalTo(20)
        }
        
        let twoPart: UIView = {
            let v = UIView()
            v.makeOriginalShdowShow()
            return v
        }()
        bgView.addSubview(twoPart)
        let bagNumberLbl: UILabel = {
            let lbl = UILabel()
            lbl.textColor = Color_24374E
            lbl.font = UIFont.regularFont(18)
            lbl.text = "红包个数"
            return lbl
        }()
        twoPart.addSubview(bagNumberLbl)
        twoPart.addSubview(bagNumberTF)
        
        let countLbl: UILabel = {
            let lbl = UILabel()
            lbl.textColor = Color_24374E
            lbl.font = UIFont.regularFont(18)
            lbl.text = "个"
            return lbl
        }()
        twoPart.addSubview(countLbl)
        twoPart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.top.equalTo(balanceLbl.snp.bottom).offset(10)
            m.height.equalTo(isGroup ? onePart : 0)
        }
        twoPart.isHidden = isGroup ? false : true
        bagNumberLbl.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
        bagNumberTF.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(80)
            m.trailing.equalToSuperview().offset(-41)
            m.height.equalTo(40)
            m.centerY.equalToSuperview()
        }
        countLbl.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-10)
        }
        let bgRemark: UIView = {
            let v = UIView()
            v.makeOriginalShdowShow()
            return v
        }()
        bgView.addSubview(bgRemark)
        self.view.addSubview(changeTypeView)
        bgRemark.addSubview(bagRemark)
        bgRemark.addSubview(remarkCountLab)
        bgRemark.snp.makeConstraints { (make) in
            if isGroup {
                make.top.equalTo(twoPart.snp.bottom).offset(20)
            } else {
                make.top.equalTo(balanceLbl.snp.bottom).offset(20)
            }
            make.height.equalTo(80)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
        }
        changeTypeView.snp.makeConstraints { (m) in
            m.right.equalToSuperview()
            m.centerY.equalTo(bgRemark.snp.top)
            m.size.equalTo(CGSize.init(width: 60, height: 30))
        }
        bagRemark.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(13)
            make.height.equalTo(40)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(0)
        }
        remarkCountLab.snp.makeConstraints { (m) in
            m.bottom.equalToSuperview().offset(-5)
            m.right.equalToSuperview().offset(-15)
        }
        
        let threePart = UIView()
        bgView.addSubview(threePart)
        threePart.addSubview(sendBtn)
        threePart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(50)
            m.top.equalTo(bgRemark.snp.bottom).offset(30)
        }
        sendBtn.snp.makeConstraints { (m) in
            m.leading.trailing.equalToSuperview()
            m.height.equalTo(50)
            m.top.equalToSuperview()
        }

        bgView.addSubview(totalCountLab)
        totalCountLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalTo(threePart.snp.bottom).offset(35)
            m.height.equalTo(47)
        }
        
        bgView.addSubview(coinTypeLab2)
        coinTypeLab2.snp.makeConstraints { (m) in
            m.top.equalTo(totalCountLab.snp.bottom).offset(5)
            m.centerX.equalTo(totalCountLab)
            m.height.equalTo(24)
        }
        if self.isGroup {
            bgView.addSubview(feeLab)
            feeLab.snp.makeConstraints { (m) in
                m.top.equalTo(coinTypeLab2.snp.bottom).offset(10)
                m.centerX.equalTo(totalCountLab)
                m.height.equalTo(20)
            }
        }
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func dismissKeyboard() {
        self.bagMoneyTF.resignFirstResponder()
        self.bagNumberTF.resignFirstResponder()
        self.bagRemark.resignFirstResponder()
    }
    
}

extension FZMCreateLuckyBagVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == self.coinViewGroup
    }
}
