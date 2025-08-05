//
//  FZMSelectContactController.swift
//  chat
//
//  Created by 郑晨 on 2025/3/7.
//

import UIKit

//typealias SelectContactBlock = ([FZMContactViewModel])->()

@objc public class FZMSelectContactController: UIViewController  {

    @objc var seletedBlock :((ContactViewModel)->())?
    private var friendArrayForSearch = [User]()
    private var selectArr = [ContactViewModel]()
    @objc var selectedBlock:((NSDictionary)->())?
    @objc var coin : LocalCoin?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isTranslucent = false
        self.view.backgroundColor =  UIColor(hex: 0xFAFBFC)
        self.navigationController?.navigationBar.tintColor = UIColor(hex: 0x32B2F7)
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: Color_Theme]
        self.navigationController?.navigationBar.shadowImage = UIImage.imageWithColor(with: UIColor(hex: 0xFAFBFC), size: CGSize(width: k_ScreenWidth, height: 1))
        self.navigationController?.navigationBar.setBackgroundImage(UIImage.imageWithColor(with: UIColor(hex: 0xFAFBFC), size: CGSize(width: k_ScreenWidth, height: 1)), for: .default)
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor =  UIColor(hex: 0xFAFBFC)
            naba.shadowColor = UIColor.lightGray
            
            naba.titleTextAttributes = [.foregroundColor:Color_Theme,.font:UIFont.systemFont(ofSize: 18)]
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
        self.navigationItem.title = "选择好友"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissPage))
        self.createUI()
    }
    
    @objc private func dismissPage() {
//        self.navigationController?.dismiss(animated: true, completion: {
//            
//        })
        
        self.navigationController?.popViewController(animated: true)
    }
    
    private func createUI() {
        
        let view1 = FZMFriendContactListView(with: "选择好友", .no)
        
        view1.selectBlock = {[weak self] (model) in
            self?.deal(contact: model)
        }
        self.friendArrayForSearch = UserManager.shared().friends
        let friendDataSource = UserManager.shared().divideUser(self.friendArrayForSearch)
        view1.originDataSource = friendDataSource
        let view = FZMScrollPageView(frame: CGRect(x: 0, y: 14, width: k_ScreenWidth, height: k_ScreenHeight-k_StatusNavigationBarHeight), dataViews: [view1])
        self.view.addSubview(view)
        
    }
    
    private func deal(contact: ContactViewModel?) {
        if let contactViewModel = contact {
//            self.navigationController?.dismiss(animated: true, completion: {
//                self.seletedBlock?(user)
//            })

//            FZMUIMediator.shared().pushVC(.goChatVC(sessionID:contactViewModel.user!.sessionID, locationMsg: nil))

//            let vc = TransferViewController.init()
            let user = contactViewModel.user
            let avatarUrl = user?.avatarURLStr
            let address = user?.aliasName
            let sessionId = user?.sessionID.idValue
            var toAddre = ""
            User.getUser(targetAddress: user!.address, count: 100, index: "", successBlock: {[weak self] (json) in
                guard let strongSelf = self else { return }
                let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
                
                for field in fields {
                    if case .ETH = field.name {
                        toAddre = field.value
                    }
                }
                if toAddre.count == 0{
                    strongSelf.showToast("未获取到对方地址")
                    return
                }
                if self!.selectedBlock != nil {
                    self?.dismissPage()
                    self!.selectedBlock!(["avatarUrl":avatarUrl! as NSString,"address":address! as NSString,"toAddr":toAddre as NSString,"sessionId":sessionId! as NSString])
                }
//                vc.contactDict = ["avatarUrl":avatarUrl! as NSString,"address":address! as NSString,"toAddr":toAddre as NSString,"sessionId":sessionId! as NSString]
//                vc.coin = strongSelf.coin
//                vc.transferBlock =  { [] (coinName,txHash,amount) in
//                    FZMUIMediator.shared().pushVC(.goChatVCToTransfer(sessionID: user!.sessionID, coinName: coinName, txHash: txHash!))
//                }
//                strongSelf.navigationController?.pushViewController(vc, animated: true)
                // 未设置过IM服务器 连接默认IM服务器 并上传保存到服务端
               
            }, failureBlock: nil)

        }
    }
    
    
    
}
