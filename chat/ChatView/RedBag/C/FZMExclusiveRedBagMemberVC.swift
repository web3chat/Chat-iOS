//
//  FZMExclusiveRedBagMemberVC.swift
//  chat
//
//  专属红包：从群成员中选择 1 位或多位作为领取人（页面常驻搜索框，可按昵称/地址搜索）
//  列表样式：头像 - 昵称 - 地址（地址在昵称下方且左对齐）
//  实现参考 @ 选人页 FZMAtPeopleVC
//

import Foundation
import UIKit
import SnapKit

final class FZMExclusiveRedBagMemberVC: FZMGroupMemberListVC {

    /// 选中回调：[(群成员地址, 显示名)]，按选择顺序返回
    var selectedBlock: (([(address: String, name: String)]) -> ())?
    var cancelBlock: (() -> ())?

    /// 已选成员（保持选择顺序，地址唯一）
    private var selectedItems = [(address: String, name: String)]()

    /// 搜索框区域高度
    private static let searchBarHeight: CGFloat = 56
    /// 列表行高（昵称 + 地址两行需要比默认 50 更高）
    private static let memberRowHeight: CGFloat = 62

    private lazy var doneItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            title: L("确定"), style: .plain, target: self, action: #selector(doneClick))
        item.isEnabled = false
        return item
    }()

    /// 专属红包不需要「所有人」等自定义头部
    override var headerView: UIView {
        get { UIView(frame: .zero) }
        set {}
    }

    private lazy var searchField: UITextField = {
        let field = UITextField()
        field.font = UIFont.regularFont(15)
        field.textColor = Color_24374E
        field.tintColor = Color_Theme
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.attributedPlaceholder = NSAttributedString(
            string: L("搜索昵称或地址"),
            attributes: [.foregroundColor: Color_8A97A5, .font: UIFont.regularFont(15)])
        field.addTarget(self, action: #selector(searchFieldChanged(_:)), for: .editingChanged)
        return field
    }()

    /// 常驻搜索框（按昵称 / 群昵称 / 地址过滤群成员）
    private lazy var searchBar: UIView = {
        let container = UIView()
        container.backgroundColor = .white

        let circle = UIView()
        circle.backgroundColor = Color_F1F4F6
        circle.layer.cornerRadius = 18
        container.addSubview(circle)
        circle.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.height.equalTo(36)
        }

        let icon = UIImageView(
            image: #imageLiteral(resourceName: "tool_search").withRenderingMode(.alwaysTemplate))
        icon.tintColor = Color_8A97A5
        circle.addSubview(icon)
        icon.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(10)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 16, height: 16))
        }

        circle.addSubview(self.searchField)
        self.searchField.snp.makeConstraints { m in
            m.left.equalTo(icon.snp.right).offset(8)
            m.right.equalToSuperview().offset(-10)
            m.top.bottom.equalToSuperview()
        }
        return container
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = L("选择领取人")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L("取消"), style: .plain, target: self, action: #selector(cancelClick))
        // 搜索改为页面常驻搜索框，右上角只保留「确定」
        self.navigationItem.rightBarButtonItems = [self.doneItem]

        self.setupSearchBar()
        self.updateDoneItem()
    }

    /// 搜索框常驻在列表上方（基类列表是全屏约束，这里给搜索框让出顶部空间）
    private func setupSearchBar() {
        self.memberListView.rowHeight = FZMExclusiveRedBagMemberVC.memberRowHeight

        self.view.addSubview(self.searchBar)
        self.searchBar.snp.makeConstraints { m in
            m.left.right.equalToSuperview()
            m.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            m.height.equalTo(FZMExclusiveRedBagMemberVC.searchBarHeight)
        }
        self.memberListView.snp.remakeConstraints { m in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(self.searchBar.snp.bottom)
        }
        // 空态视图同步下移，否则会盖住搜索框导致无法继续输入
        self.noDataView.snp.remakeConstraints { m in
            m.left.right.bottom.equalToSuperview()
            m.top.equalTo(self.searchBar.snp.bottom)
        }
    }

    /// 搜索输入（中文输入法联想中不触发，与基类保持一致）
    @objc private func searchFieldChanged(_ textField: UITextField) {
        if textField.markedTextRange == nil || textField.markedTextRange?.isEmpty ?? false {
            self.searchMembers(with: textField.text ?? "")
        }
    }

    /// 页面常驻搜索框不需要基类「点背景关闭搜索」的全屏遮罩，这里盖掉
    override func searchMembers(with text: String) {
        super.searchMembers(with: text)
        self.tapControl.isHidden = true
    }

    @objc private func cancelClick() {
        self.dismiss(animated: true, completion: nil)
        self.cancelBlock?()
    }

    @objc private func doneClick() {
        guard !self.selectedItems.isEmpty else { return }
        let items = self.selectedItems
        self.dismiss(animated: true, completion: nil)
        self.selectedBlock?(items)
    }

    private func updateDoneItem() {
        let count = self.selectedItems.count
        self.doneItem.isEnabled = count > 0
        self.doneItem.title = count > 0 ? "\(L("确定"))(\(count))" : L("确定")
    }

    /// 群成员列表（允许选择自己：自己那一行会带「（我）」标识）
    override func deal(with list: [GroupMember]) {
        self.view.showProgress()
        DispatchQueue.global().async {
            self.dealtList = UserManager.shared().normalGroupMember(list)
            self.memberList = self.dealtList

            DispatchQueue.main.async {
                self.view.hideProgress()

                self.reloadData()
            }
        }
    }
}

extension FZMExclusiveRedBagMemberVC {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        guard let memberCell = cell as? FZMGroupMemberCell else { return cell }

        // ⚠️ 顺序很关键：configure（在 super 里调用的）内部就会读 showSelect / showAddress，
        // 而开关只能在这里设置 —— 所以设置完必须自己补一次昵称/地址渲染，
        // 否则会出现「地址时有时无」（新创建的 cell 读到的是开关默认值 false）。
        if !memberCell.showSelect {
            memberCell.showSelect = true
        }
        if !memberCell.showAddress {
            memberCell.showAddress = true
        }

        guard indexPath.section < self.memberList.count,
            indexPath.row < self.memberList[indexPath.section].value.count
        else {
            memberCell.isSelect = false
            return memberCell
        }
        let model = self.memberList[indexPath.section].value[indexPath.row]
        memberCell.isSelect = self.selectedItems.contains(where: { $0.address == model.sessionIDStr })

        // 允许给自己发专属红包：自己那一行昵称后面加「(我)」标识
        if model.sessionIDStr == LoginUser.shared().address {
            memberCell.nameLab.attributedText = nil
            memberCell.nameLab.text = model.name + "(" + L("我") + ")"
        }
        // 开关刚打开，configure 阶段还没读到，这里补画地址
        memberCell.refreshAddressDisplay(model.sessionIDStr)
        return memberCell
    }

    /// 点选/取消选中（可多选，支持搜索过滤后再点选）
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < self.memberList.count,
            indexPath.row < self.memberList[indexPath.section].value.count
        else {
            return
        }
        let model = self.memberList[indexPath.section].value[indexPath.row]
        let address = model.sessionIDStr
        guard !address.isEmpty else { return }

        if let index = self.selectedItems.firstIndex(where: { $0.address == address }) {
            self.selectedItems.remove(at: index)
        } else {
            let name = model.name.isEmpty ? address.shortAddress : model.name
            self.selectedItems.append((address, name))
        }
        // ⚠️ 这里原来是无条件 `reloadRows`：它会重跑 `configure` 里的 `updateConstraints`
        // （头像左约束 15↔45、昵称左约束 +10↔+70、地址行高 5↔17）。对**正在显示**的 cell
        // 改约束常量，一旦落在动画事务里，UIKit 会把「旧位置 → 新位置」渲染成动画，
        // 用户看到的就是「同一份头像/文字像是叠了两层」——即反馈的「重影」。
        // 勾选态本来就只换一个图标，所以直接改可见 cell；cell 不可见时再退回无动画 reload。
        if let visibleCell = memberListView.cellForRow(at: indexPath) as? FZMGroupMemberCell {
            visibleCell.isSelect = self.selectedItems.contains(where: { $0.address == address })
        } else {
            UIView.performWithoutAnimation {
                self.memberListView.reloadRows(at: [indexPath], with: .none)
            }
        }
        self.updateDoneItem()
    }
}
