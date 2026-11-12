//
//  DAppRPCEditorVC.swift
//  chat
//
//  「选择网络」页 → 右上角「编辑」进入：按网络查看 / 修改 DApp 浏览器的 RPC 节点地址。
//
//  每行两行明细：默认地址 + 当前自定义地址（未设置时显示「未设置」）；
//  点 cell 弹输入框，留空 = 恢复默认。
//

import UIKit
import SnapKit

@objc class DAppRPCEditorVC: UIViewController {

    private let nets = DAppRPCSettings.supportedNets

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = UIColor(hexString: "#FCFCFF")
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.keyboardDismissMode = .onDrag
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 84
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()

    @objc init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("RPC 地址")
        view.backgroundColor = .white
        setupNavBar()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - 导航栏（与 `TokenApproveListVC` 同款：白色不透明 + nav_back）

    private func setupNavBar() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            appearance.buttonAppearance.normal.backgroundImage = UIImage()
            appearance.buttonAppearance.highlighted.backgroundImage = UIImage()
            appearance.doneButtonAppearance.normal.backgroundImage = UIImage()
            appearance.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            appearance.backButtonAppearance.normal.backgroundImage = UIImage()
            appearance.backButtonAppearance.highlighted.backgroundImage = UIImage()
            appearance.backgroundColor = .white
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: Color_24374E
            ]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        let backItem = UIBarButtonItem(image: UIImage(named: "nav_back"),
                                       style: .plain,
                                       target: self,
                                       action: #selector(goBack))
        backItem.tintColor = Color_24374E
        navigationItem.leftBarButtonItem = backItem
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - 编辑某一个网络的 RPC 地址

    /// - Parameter prefilled: 上一次输入非法时的原文，带回来让用户接着改。
    private func presentEditor(for net: NetType, prefilled: String? = nil) {
        let alert = UIAlertController(title: DAppRPCSettings.displayName(for: net),
                                      message: L("留空恢复默认地址"),
                                      preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = prefilled ?? DAppRPCSettings.customURLString(for: net)
            textField.placeholder = L("请输入 RPC 地址")
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
            textField.font = UIFont.systemFont(ofSize: 13)
        }
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("保存"), style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let input = alert?.textFields?.first?.text
            if DAppRPCSettings.setCustomURLString(input, for: net) {
                self.tableView.reloadData()
            } else {
                // 非法地址不入库：提示后带着原文重新弹，让用户改
                self.showCustomMessage(L("RPC 地址无效，请输入 http/https 开头的完整地址"), hideAfterDelay: 2)
                self.presentEditor(for: net, prefilled: input)
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension DAppRPCEditorVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        nets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identity = "DAppRPCEditorCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identity)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identity)
        let net = nets[indexPath.row]

        cell.backgroundColor = .white
        cell.textLabel?.text = DAppRPCSettings.displayName(for: net)
        cell.textLabel?.textColor = Color_24374E
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)

        let defaultText = String(format: L("默认：%@"), DAppRPCSettings.defaultURL(for: net).absoluteString)
        let customText = String(format: L("自定义：%@"), DAppRPCSettings.customURLString(for: net) ?? L("未设置"))
        cell.detailTextLabel?.text = defaultText + "\n" + customText
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
        cell.detailTextLabel?.textColor = Color_8A97A5

        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentEditor(for: nets[indexPath.row])
    }
}
