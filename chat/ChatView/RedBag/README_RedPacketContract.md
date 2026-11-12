# RedPacketUpgradeable 合约接口说明

本文档介绍 iOS 工程中 RedPacketUpgradeable 合约的接口封装和使用方法。

## 更新记录

### 2025-04-28 更新
- ✅ 实现 `DefaultWeb3RequestManager`，使用 `Web3ProviderHandler` 处理 RPC 请求
- ✅ 添加 ERC20 授权支持（`approveERC20`, `allowanceERC20`, `balanceOfERC20`, `decimalsERC20`）
- ✅ `RedPacketService` 自动处理 ERC20 授权检查
- ✅ 完善只读合约方法调用（`eth_call`）
- ✅ 更新桥接头文件，添加 `Web3ProviderHandler.h` 导入
- ✅ 提供完整的使用文档 `README_RedPacketIntegration.md`

## 文件结构

```
chat/ChatView/RedBag/
├── M/
│   ├── RedPacketModels.swift                    # 数据模型定义（使用 JKBigInteger）
│   ├── RedPacketContract.swift                  # 合约接口协议和 ABI
│   ├── RedPacketContract+Implementation.swift   # 合约接口实现（已完整实现）
│   ├── RedPacketService.swift                   # 业务服务层封装（已完整实现）
│   ├── ABIEncoder.swift                         # ABI 编码/解码工具（含 ERC20 编码）
│   └── RedPacketWalletDataSource.swift          # 钱包数据源
├── C/
│   ├── FZMCreateLuckyBagVC.swift               # 创建红包页面（已集成）
│   ├── FZMRedBagInfoVC.swift                   # 红包详情页面
│   └── FZMRedBagInfoVC+Contract.swift          # 红包详情合约扩展（已集成）
├── V/
│   └── FZMRedBagCoinView.swift                 # 币种选择视图
├── Extesion/
│   └── contract-api22.md                       # 合约 ABI 文档（源文件）
├── README_RedPacketContract.md                  # 本文件
└── README_RedPacketIntegration.md               # 详细集成指南 ⭐新
```

## 依赖说明

本接口使用项目中已有的依赖：
- `JKBigInteger`: 大整数运算（已在 Podfile 中）
- `SwiftyJSON`: JSON 解析（已在 Podfile 中）
- `CryptoSwift`: SHA3/Keccak256 哈希（已在 Podfile 中）

**注意**: 不再依赖 `AlphaWalletWeb3` 模块。

## 核心组件

### 1. RedPacketModels.swift
定义合约相关的数据模型：

- `RedPacketType`: 红包类型枚举（固定/随机）
- `RedPacketInfo`: 红包信息结构体
- `ClaimRecord`: 领取记录结构体
- `RedPacketIdParts`: 红包 ID 解析结果
- `RedPacketContractError`: 合约错误类型
- `EthereumAddress`: 以太坊地址简化模型
- `RedPacketContractConfig`: 默认配置

### 2. RedPacketContract.swift
定义合约配置和 ABI：

- `RedPacketContractABI`: 完整的合约 ABI JSON
- `RedPacketContractProtocol`: 合约接口协议

### 3. RedPacketContract+Implementation.swift
合约接口的具体实现：

- 封装了所有合约方法的调用
- 错误解析和转换
- 包含 `Web3RequestManagerProtocol` 协议，需要项目中实现实际的网络请求

### 4. ABIEncoder.swift
ABI 编码/解码工具：

- `ABIEncoder`: 通用 ABI 编码/解码方法
- `RedPacketABIEncoder`: 红包合约专用的 ABI 编码/解码方法
- 支持所有 Solidity 基础类型：address、uint256、bool、string、数组等

### 5. RedPacketService.swift
业务服务层，提供高级业务功能：

- 创建固定/随机红包
- 领取红包
- 取回过期的红包
- 查询红包详情和记录
- 检查可领取/可取回状态

## 快速开始

### 1. 配置合约地址和网络

在 `RedPacketModels.swift` 中配置合约信息：

```swift
struct RedPacketContractConfig: Web3Configurable {
    // 替换为实际部署的合约地址
    static let contractAddress = "0xYourDeployedContractAddress"

    // 根据目标链配置 ChainID
    static let chainID = 2999  // BTY 链示例

    // 配置 RPC 节点
    static let rpcURL = "https://mainnet.bityuan.com/eth"
}
```

### 2. 初始化服务

`DefaultWeb3RequestManager` 已实现，可直接使用：

```swift
// 方式 1：使用默认配置（直接使用已实现的 DefaultWeb3RequestManager）
if let service = RedPacketService() {
    // 使用 service 进行操作
}

// 方式 2：使用自定义合约实例
let contract = RedPacketContract(
    contractAddress: "0xYourContractAddress",
    rpcURL: "https://mainnet.infura.io/v3/YOUR_PROJECT_ID",
    chainID: 1
    // web3RequestManager 参数可选，默认使用 DefaultWeb3RequestManager
)
let service = RedPacketService(contract: contract)
```

**说明**: 请求数据已经通过 `ABIEncoder` 编码完成，使用 `DefaultWeb3RequestManager` 直接发送即可。

### 3. 创建红包

```swift
// 创建固定金额红包
service.createFixedRedPacket(
    token: "0x0000000000000000000000000000000000000000",  // 原生代币
    totalAmount: "1.5",  // 1.5 ETH
    totalCount: 10,      // 10 份
    expireHours: 24,     // 24 小时后过期
    allowedAddresses: [], // 空数组表示人人可领
    pwd: "wallet_password",
    coin: selectedCoin
) { result in
    switch result {
    case .success(let packetId):
        print("红包创建成功，ID: \(packetId)")
    case .failure(let error):
        print("创建失败: \(error.localizedDescription)")
    }
}

// 创建随机金额红包
service.createRandomRedPacket(
    token: "0x...",      // ERC20 代币地址
    totalAmount: "100",  // 100 Token
    totalCount: 5,       // 5 份
    expireHours: 48,
    allowedAddresses: ["0x...", "0x..."],  // 指定白名单
    pwd: "wallet_password",
    coin: selectedCoin
) { result in
    // ...
}
```

**注意**: ERC20 代币红包会自动检查授权并处理 `approve`，无需手动调用。

### 4. 领取红包

```swift
service.claimRedPacket(id: "123456") { result in
    switch result {
    case .success(let amount):
        print("成功领取 \(amount)")
    case .failure(let error):
        print("领取失败: \(error.localizedDescription)")
    }
}
```

### 5. 查询红包详情

```swift
service.getRedPacketDetail(id: "123456") { result in
    switch result {
    case .success(let detail):
        print("红包状态: \(detail.status)")
        print("总金额: \(detail.totalAmount) \(detail.tokenSymbol)")
        print("领取进度: \(detail.claimedCount)/\(detail.totalCount)")
    case .failure(let error):
        print("查询失败: \(error.localizedDescription)")
    }
}
```

### 6. 查询领取记录

```swift
service.getRedPacketClaimRecords(id: "123456") { result in
    switch result {
    case .success(let records):
        for record in records {
            print("\(record.userAddress) 领取了 \(record.amount)")
            if record.isBest {
                print("  👑 手气最佳！")
            }
        }
    case .failure(let error):
        print("查询失败: \(error.localizedDescription)")
    }
}
```

### 7. 查询红包列表

```swift
// 查询我发的红包
service.getMySentRedPackets { result in
    switch result {
    case .success(let packets):
        for packet in packets {
            print("ID: \(packet.id), 金额: \(packet.amount), 进度: \(packet.count)")
        }
    case .failure(let error):
        print("查询失败: \(error.localizedDescription)")
    }
}

// 查询我收的红包
service.getMyReceivedRedPackets { result in
    // ...
}
```

### 8. 检查是否可以领取/取回

```swift
// 检查是否可以领取
service.canClaimRedPacket(id: "123456") { result in
    switch result {
    case .success(let claimResult):
        if claimResult.canClaim {
            print("可以领取")
            if let amount = claimResult.estimatedAmount {
                print("预计可领: \(amount)")
            }
        } else {
            print("不能领取: \(claimResult.reason ?? "")")
        }
    case .failure(let error):
        print("检查失败: \(error.localizedDescription)")
    }
}

// 检查是否可以取回（仅创建者，过期后）
service.canWithdrawRedPacket(id: "123456") { result in
    switch result {
    case .success(let canWithdraw):
        if canWithdraw {
            print("可以取回剩余金额")
        }
    case .failure(let error):
        print("检查失败: \(error.localizedDescription)")
    }
}
```

### 9. 取回过期红包

```swift
service.withdrawRedPacket(id: "123456") { result in
    switch result {
    case .success:
        print("取回成功")
    case .failure(let error):
        print("取回失败: \(error.localizedDescription)")
    }
}
```

## 配置说明

在使用前需要配置合约地址和 RPC 节点：

```swift
// RedPacketModels.swift
struct RedPacketContractConfig {
    /// 合约地址（根据实际部署配置）
    static let contractAddress = "0xYourContractAddress"

    /// 链 ID
    static let chainID = 1  // 主网

    /// RPC 节点地址
    static let rpcURL = "https://mainnet.infura.io/v3/YOUR_PROJECT_ID"
}
```

## 错误处理

所有操作都返回 `Result` 类型，包含具体的错误信息：

```swift
case .failure(let error):
    if let serviceError = error as? RedPacketServiceError {
        switch serviceError {
        case .insufficientBalance:
            // 余额不足
        case .notApproved:
            // ERC20 未授权
        case .contractError(let contractError):
            // 合约错误
            print(contractError.localizedDescription)
        default:
            print(serviceError.localizedDescription)
        }
    }
```

## 注意事项

1. **合约地址**: 使用前确保配置了正确的合约地址
2. **ABI 更新**: 如果合约 ABI 有变化，需要更新 `RedPacketContractABI.abiString`
3. **Web3RequestManagerProtocol**: 必须实现此协议才能使用合约接口
4. **Gas 费用**: 创建和领取红包需要支付 Gas 费用
5. **ERC20 授权**: 创建 ERC20 红包前需要先授权合约使用代币
6. **密码处理**: 实际使用时需要处理钱包密码/私钥的安全存储

## 扩展用法

### 直接使用合约接口

如果需要更底层的控制，可以直接使用 `RedPacketContract`：

```swift
import JKBigInteger

let contract = RedPacketContract()

// 调用只读方法
if let packetId = JKBigInteger(string: "123") {
    contract.getRedPacket(id: packetId) { result in
        // ...
    }
}
```

### 解析红包 ID

```swift
if let packetId = JKBigInteger(string: "123456") {
    contract.getRedPacketIdParts(id: packetId) { result in
        switch result {
        case .success(let parts):
            print("创建日期: \(parts.formattedDate())")
            print("当日序号: \(parts.sequence.stringValue)")
        case .failure:
            break
        }
    }
}
```

### 使用 ABIEncoder 进行编码

如果需要手动编码合约调用数据：

```swift
// 编码创建固定金额红包
let data = RedPacketABIEncoder.encodeCreateFixedRedPacket(
    token: "0x0000000000000000000000000000000000000000",
    totalAmount: JKBigInteger(string: "1500000000000000000")!, // 1.5 ETH
    totalCount: JKBigInteger(string: "10")!,
    expireAt: JKBigInteger(string: "1893456000")!, // 过期时间戳
    allowedAddresses: []
)
print("编码后的数据: \(data)")
// 输出: 0x + 8字节函数选择器 + 编码后的参数

// 编码领取红包
let claimData = RedPacketABIEncoder.encodeClaim(
    id: JKBigInteger(string: "123456")!
)

// 解码返回值
let returnData = "0x..." // 从合约调用返回的十六进制数据
if let packetInfo = RedPacketABIEncoder.decodeGetRedPacketResult(
    id: JKBigInteger(string: "123456")!,
    hex: returnData
) {
    print("红包创建者: \(packetInfo.creator)")
    print("红包金额: \(packetInfo.totalAmount.stringValue)")
}
```

### 通用 ABI 编码

```swift
// 编码地址
let addressEncoded = ABIEncoder.encodeAddress("0x1234...")

// 编码 uint256
let amount = JKBigInteger(string: "1000000000000000000")
let amountEncoded = ABIEncoder.encodeUInt256(amount!)

// 编码方法调用
let methodData = ABIEncoder.encodeMethodCall(
    method: "transfer(address,uint256)",
    params: [
        "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B", // 地址
        JKBigInteger(string: "1000")! // uint256
    ]
)
```

## 参考

- 合约 ABI 文档: `contract-api22.md`
- 合约源码: `RedPacketUpgradeable.sol`
- 项目网络层: `BlockchainHelper.swift`, `Provider.swift`
