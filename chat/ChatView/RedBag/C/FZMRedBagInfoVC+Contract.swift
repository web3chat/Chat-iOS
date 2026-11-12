//
//  FZMRedBagInfoVC+Contract.swift
//  chat
//
//  FZMRedBagInfoVC 的合约接口扩展
//  演示如何使用 RedPacketContract 查询红包详情
//

import Foundation

// MARK: - 使用合约接口查询红包详情
extension FZMRedBagInfoVC {

    /// 使用合约接口获取红包详情
    func getRedPacketInfoFromContract() {
        guard !packetId.isEmpty else {
            self.showToast(with: L("红包ID无效"))
            return
        }

        self.showProgress(with: nil)

        // 使用红包服务查询详情
        guard let service = RedPacketService() else {
            self.hideProgress()
            self.showToast(with: L("服务初始化失败"))
            return
        }

        service.getRedPacketDetail(id: packetId) { [weak self] result in
            self?.hideProgress()

            switch result {
            case .success(let detail):
                // 更新 UI
                self?.updateUI(with: detail)
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }

    /// 使用合约接口获取领取记录
    func getRedPacketClaimRecordsFromContract() {
        guard !packetId.isEmpty else { return }

        guard let service = RedPacketService() else { return }

        service.getRedPacketClaimRecords(id: packetId) { [weak self] result in
            switch result {
            case .success(let records):
                // 转换为现有的数据模型并刷新列表
                self?.updateClaimRecords(records: records)
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }

    /// 检查是否可以领取红包
    func checkCanClaimRedPacket() {
        guard !packetId.isEmpty else { return }

        guard let service = RedPacketService() else { return }

        service.canClaimRedPacket(id: packetId) { [weak self] result in
            switch result {
            case .success(let claimResult):
                if claimResult.canClaim {
                    // 显示领取按钮或自动领取
                    if let amount = claimResult.estimatedAmount {
                        self?.showToast(with: String(format: L("预计可领取: %@"), "\(amount)"))
                    }
                } else {
                    // 显示不能领取的原因
                    if let reason = claimResult.reason {
                        self?.showToast(with: reason)
                    }
                }
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }

    /// 领取红包
    func claimRedPacketFromContract() {
        guard !packetId.isEmpty else {
            self.showToast(with: L("红包ID无效"))
            return
        }

        self.showProgress(with: L("领取中..."))

        guard let service = RedPacketService() else {
            self.hideProgress()
            self.showToast(with: L("服务初始化失败"))
            return
        }

        service.claimRedPacket(id: packetId) { [weak self] result in
            self?.hideProgress()

            switch result {
            case .success(let amount):
                self?.showToast(with: String(format: L("成功领取 %@"), "\(amount)"))
                // 刷新红包详情
                self?.getRedPacketInfoFromContract()
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }

    // MARK: - UI 更新辅助方法

    /// 使用合约详情更新 UI
    private func updateUI(with detail: RedPacketDetailModel) {
        // 更新备注
        remarkLab.text = detail.remark

        // 更新总金额显示
        let amountStr = "\(detail.totalAmount) \(detail.tokenSymbol)"
        totalLab.text = amountStr

        // 根据状态更新 UI
        switch detail.status {
        case .active:
            // 大号金额用香槟金（`RP.onRedStrong`）—— 与头图 / 发红包页封面保持一致。
            // ⚠️ 这里原来是 `UIColor.white`，会把我的头图金色**覆盖掉**（这个方法确实会被调到，见本文件第 36 行）
            totalLab.textColor = RP.onRedStrong
        case .claimedAll:
            totalLab.text = L("红包已领完")
            // 失效态用「红底上的次要文字」令牌。
            // ⚠️ 原来是硬编码的 #FFB7B7（淡粉）—— 偏粉、和金色体系不搭、真机上看也脏
            totalLab.textColor = RP.onRedWeak
        case .expired:
            totalLab.text = L("红包已过期")
            totalLab.textColor = RP.onRedWeak
        case .withdrawn:
            totalLab.text = L("红包已取回")
            totalLab.textColor = RP.onRedWeak
        }

        // 更新领取进度
        remainLab.text = String(
            format: L("已领取%@/%@个，余%@个"),
            "\(detail.claimedCount)",
            "\(detail.totalCount)",
            "\(detail.remainingCount)"
        )

        // 检查是否可以取回（仅创建者）
        checkCanWithdraw(detail: detail)
    }

    /// 更新领取记录列表
    private func updateClaimRecords(records: [RedPacketClaimRecordModel]) {
        // 将合约记录转换为现有的 IMRedPacketReceiveModel
        // 这里需要根据实际模型结构调整
        self.tableView.reloadData()
    }

    /// 检查是否可以取回红包
    private func checkCanWithdraw(detail: RedPacketDetailModel) {
        guard let service = RedPacketService() else { return }

        service.canWithdrawRedPacket(id: detail.id) { [weak self] result in
            switch result {
            case .success(let canWithdraw):
                if canWithdraw {
                    // 显示取回按钮
                    self?.showWithdrawButton()
                }
            case .failure:
                break
            }
        }
    }

    /// 显示取回按钮
    private func showWithdrawButton() {
        // 添加取回按钮到界面
    }

    /// 取回红包
    @objc func withdrawRedPacket() {
        guard !packetId.isEmpty else { return }

        self.showProgress(with: L("取回中..."))

        guard let service = RedPacketService() else {
            self.hideProgress()
            self.showToast(with: L("服务初始化失败"))
            return
        }

        service.withdrawRedPacket(id: packetId) { [weak self] result in
            self?.hideProgress()

            switch result {
            case .success:
                self?.showToast(with: L("取回成功"))
                // 刷新红包详情
                self?.getRedPacketInfoFromContract()
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }
}

// MARK: - 创建红包视图控制器扩展
/// 符合合约接口的创建红包方法
/// 参考 contract-api22.md 中的参数要求
extension FZMCreateLuckyBagVC {

    /// 使用合约创建固定金额红包
    /// - Parameters:
    ///   - token: 代币合约地址（原生代币传 "0x000...000"）
    ///   - totalAmount: 总金额（字符串，会被转换为最小单位）
    ///   - totalCount: 红包份数
    ///   - expireHours: 过期时间（小时）
    ///   - allowedAddresses: 白名单地址（空数组表示人人可领）
    func createFixedRedPacketWithContract(
        token: String,
        totalAmount: String,
        totalCount: Int,
        expireHours: Int,
        allowedAddresses: [String] = []
    ) {
        self.showProgress(with: L("创建中..."))

        guard let service = RedPacketService() else {
            self.hideProgress()
            self.showToast(with: L("服务初始化失败"))
            return
        }

        // 判断是否是原生代币
        let isNative = token == "0x0000000000000000000000000000000000000000" || token.isEmpty
        
        // 对于 ERC20 代币，需要先检查授权
        if !isNative {
            // TODO: 检查并授权 ERC20 代币
            // 1. 调用 approve(redPacketContract, totalAmount)
            // 2. 授权成功后再创建红包
        }

        service.createFixedRedPacket(
            token: token,
            totalAmount: totalAmount,
            totalCount: totalCount,
            expireHours: expireHours,
            allowedAddresses: allowedAddresses
        ) { [weak self] result in
            self?.hideProgress()

            switch result {
            case .success(let packetId):
                self?.showToast(with: String(format: L("红包创建成功，ID: %@"), packetId))
                // 跳转到红包详情或分享页面
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }

    /// 使用合约创建随机金额红包
    /// - Parameters:
    ///   - token: 代币合约地址（原生代币传 "0x000...000"）
    ///   - totalAmount: 总金额（字符串，会被转换为最小单位）
    ///   - totalCount: 红包份数
    ///   - expireHours: 过期时间（小时）
    ///   - allowedAddresses: 白名单地址（空数组表示人人可领）
    func createRandomRedPacketWithContract(
        token: String,
        totalAmount: String,
        totalCount: Int,
        expireHours: Int,
        allowedAddresses: [String] = []
    ) {
        self.showProgress(with: L("创建中..."))

        guard let service = RedPacketService() else {
            self.hideProgress()
            self.showToast(with: L("服务初始化失败"))
            return
        }

        // 判断是否是原生代币
        let isNative = token == "0x0000000000000000000000000000000000000000" || token.isEmpty
        
        // 对于 ERC20 代币，需要先检查授权
        if !isNative {
            // TODO: 检查并授权 ERC20 代币
            // 1. 调用 approve(redPacketContract, totalAmount)
            // 2. 授权成功后再创建红包
        }

        service.createRandomRedPacket(
            token: token,
            totalAmount: totalAmount,
            totalCount: totalCount,
            expireHours: expireHours,
            allowedAddresses: allowedAddresses
        ) { [weak self] result in
            self?.hideProgress()

            switch result {
            case .success(let packetId):
                self?.showToast(with: String(format: L("红包创建成功，ID: %@"), packetId))
                // 跳转到红包详情或分享页面
            case .failure(let error):
                self?.showToast(with: error.localizedDescription)
            }
        }
    }

    /// 便捷的创建红包方法（使用当前选中的币种）
    func createRedPacketWithCurrentSettings() {
        // 1. 检查参数
        guard let moneyText = bagMoneyTF.text,
              let money = Double(moneyText),
              let numberText = bagNumberTF.text,
              let number = Int(numberText) else {
            showToast(L("请输入正确的金额和数量"))
            return
        }
        
        guard selectedIndex >= 0 && selectedIndex < dataArray.count else {
            showToast(L("请选择币种"))
            return
        }
        
        let model = FZMRedBagCoinCellModel(with: dataArray[selectedIndex])
        
        // 2. 计算总金额
        let totalAmount = isRandom ? money : money * Double(number)
        
        // 3. 转换为最小单位字符串
        let multiplier = pow(10.0, Double(model.decimalPlaces))
        let amountInMinUnit = Int64(totalAmount * multiplier)
        
        // 4. 获取合约地址
        let tokenAddress = model.contractAddress ?? "0x0000000000000000000000000000000000000000"
        
        // 5. 创建红包
        if isRandom {
            createRandomRedPacketWithContract(
                token: tokenAddress,
                totalAmount: "\(amountInMinUnit)",
                totalCount: number,
                expireHours: 24
            )
        } else {
            createFixedRedPacketWithContract(
                token: tokenAddress,
                totalAmount: "\(amountInMinUnit)",
                totalCount: number,
                expireHours: 24
            )
        }
    }
}
