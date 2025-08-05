//
//  FZMFullTextSearchHistoryView.swift
//  IMSDK
//
//  Created by 陈健 on 2019/9/25.
//

import UIKit
import SnapKit
import RxSwift

class FZMFullTextSearchHistoryView: UIView {
    
    private let disposeBag = DisposeBag.init()
    private let historyLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "搜索历史")
    private lazy var clearAllHistoryBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle("清空历史", for: .normal)
        btn.setTitleColor(Color_8A97A5, for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(14)
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.clearAllHistoryBlock?()
        }).disposed(by: disposeBag)
        return btn
    }()
    
    var clearAllHistoryBlock: (()->())?
    var deleteHistoryBlock: ((String)->())?
    var selectedHistoryBlock: ((String)->())?
    
    var histories = [String]() {
        didSet {
            self.subviews.forEach { $0.removeFromSuperview() }
            self.addSubview(historyLab)
            historyLab.snp.makeConstraints { (m) in
                m.top.equalToSuperview()
                m.left.equalToSuperview().offset(15)
                m.height.equalTo(30)
            }
            for i in 0..<histories.count {
                let history = histories[i]
                let cell = self.getCell(title: history, deleteBlock: {[weak self] in
                    self?.deleteHistoryBlock?(history)
                }) { [weak self] in
                    self?.selectedHistoryBlock?(history)
                }
                
                cell.tag = i + 13700
                self.addSubview(cell)
                cell.snp.makeConstraints { (m) in
                    m.left.right.equalToSuperview()
                    m.height.equalTo(50)
                    if i == 0 {
                        m.top.equalTo(historyLab.snp.bottom)
                    } else if let v = self.viewWithTag(cell.tag - 1) {
                        m.top.equalTo(v.snp.bottom)
                    }
                }
                if i == histories.count - 1 {
                    self.addSubview(clearAllHistoryBtn)
                    clearAllHistoryBtn.snp.makeConstraints { (m) in
                        m.centerX.equalToSuperview()
                        m.size.equalTo(CGSize.init(width: 70, height: 25))
                        m.top.equalTo(cell.snp.bottom).offset(15)
                    }
                }
            }
            self.layoutIfNeeded()
        }
    }
    
    
    init() {
        super.init(frame: CGRect.zero)
    }
    
    func getCell(title: String, deleteBlock: @escaping(() -> ()),selectedBlock: @escaping(() -> ())) -> UIView {
        let cell = UIView.init()
        cell.backgroundColor = Color_FAFBFC
        let imageView = UIImageView.init()
        imageView.image = #imageLiteral(resourceName: "fts_search_clock")
        cell.addSubview(imageView)
        imageView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.size.equalTo(CGSize.init(width: 10, height: 11))
        }
        let titleLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_24374E, textAlignment: .left, text: title)
        titleLab.numberOfLines = 0
        cell.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalTo(imageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-50)
        }
        
        let deleteBtn = UIButton.init(type: .custom)
        deleteBtn.setImage(#imageLiteral(resourceName: "fts_search_delete"), for: .normal)
        deleteBtn.enlargeClickEdge(15, 15, 15, 15)
        cell.addSubview(deleteBtn)
        deleteBtn.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.size.equalTo(CGSize.init(width: 20, height: 20))
        }
        deleteBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak cell] (_) in
            cell?.snp.updateConstraints({ (m) in
                m.height.equalTo(0)
            })
            cell?.isHidden = true
            UIView.animate(withDuration: 0.3) {
                self.layoutIfNeeded()
            }
            deleteBlock()
        }).disposed(by: disposeBag)
        
        let line = UILabel.getNormalLineView()
        cell.addSubview(line)
        line.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(1)
        }
        
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: { (_) in
            selectedBlock()
        }).disposed(by: disposeBag)
        cell.addGestureRecognizer(tap)
        return cell
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
