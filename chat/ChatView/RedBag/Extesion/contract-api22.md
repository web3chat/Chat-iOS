# RedPacketUpgradeable 合约 API 说明

本文档描述 `RedPacketUpgradeable.sol` 的**公开方法**、**参数**、**返回值**及**错误**，便于前端/移动端对接与联调。

---

## 一、类型与结构体

### 1.1 RedPacketType（枚举）

| 值 | 名称   | 说明           |
|----|--------|----------------|
| 0  | Fixed  | 固定金额红包   |
| 1  | Random | 随机金额红包   |

### 1.2 RedPacketInfo（结构体，仅用于理解返回值）

| 字段           | 类型        | 说明                         |
|----------------|-------------|------------------------------|
| creator        | address     | 红包发起人地址               |
| token          | address     | 代币地址，`0` 表示原生代币   |
| ptype          | RedPacketType | 红包类型（Fixed / Random） |
| totalAmount    | uint256     | 总金额（最小单位）           |
| totalCount     | uint256     | 总份数                       |
| claimedCount   | uint256     | 已领取份数                   |
| expireAt       | uint256     | 过期时间戳（秒）             |
| whitelistCount | uint256     | 白名单地址数量               |
| amountPerShare | uint256     | 固定红包时每份金额；随机为 0 |
| withdrawn      | bool        | 发起人是否已取回剩余         |

### 1.3 红包 ID 规则

- 公式：`id = dayIndex * 1e6 + sequence`
- `dayIndex`：自 Unix 纪元起的天数（`block.timestamp / 1 days`）
- `sequence`：当日创建顺序，从 1 递增
- 可用 `getRedPacketIdParts(id)` 解析为 `(dayIndex, sequence)` 用于展示

### 1.4 ClaimRecord（领取记录，链上数组元素）

| 字段   | 类型    | 说明 |
|--------|---------|------|
| user   | address | 领取者地址 |
| amount | uint256 | 本次领取金额（最小单位） |

仅 **claim 成功** 后追加一条；顺序与链上领取先后一致。

---

## 二、事件（Events）

| 事件名           | 参数说明 |
|------------------|----------|
| **RedPacketCreated** | `id`(indexed), `creator`(indexed), `token`, `tokenSymbolKey`(indexed), `ptype`, `totalAmount`, `totalCount`, `expireAt`, `whitelistCount` |
| **Claimed**      | `id`(indexed), `user`(indexed), `amount` |
| **Withdrawn**    | `id`(indexed), `creator`(indexed), `amount` |

**说明**：`tokenSymbolKey` 为创建时写入的展示/筛选用符号键（`bytes32`）；原生币或无法从 ERC20 读取/编码 symbol 时可为全零。

---

## 三、写方法（需发送交易、消耗 Gas）

### 3.1 createFixedRedPacket — 创建固定金额红包

每人领取金额相同，总金额须能被份数整除。

**签名**

```
createFixedRedPacket(address token, uint256 totalAmount, uint256 totalCount, uint256 expireAt, address[] allowedAddresses) returns (uint256 id)
```

**参数**

| 参数名            | 类型        | 说明 |
|-------------------|-------------|------|
| token             | address     | 代币地址。**原生代币**传 `0x0000000000000000000000000000000000000000`；ERC20 传合约地址。 |
| totalAmount       | uint256     | 红包总金额（最小单位）。原生币与 `msg.value` 一致；ERC20 为 `amount * 10^decimals`。 |
| totalCount        | uint256     | 红包份数，须 > 0。 |
| expireAt          | uint256     | 过期时间（Unix 秒级时间戳），必须大于当前时间。 |
| allowedAddresses  | address[]   | 白名单地址数组。**空数组 `[]`** 表示人人可领；非空则仅此列表内地址可领取。 |

**返回值**

| 名称 | 类型    | 说明     |
|------|---------|----------|
| id   | uint256 | 新创建的红包 ID。 |

**交易 value**

- **原生代币红包**：调用时 `msg.value` 必须等于 `totalAmount`。
- **ERC20 红包**：调用时 `msg.value` 必须为 0，且创建前需对本合约 `approve(redPacketContract, totalAmount)`。

**可能错误（revert）**

| 错误信息           | 原因 |
|--------------------|------|
| `count must > 0`   | totalCount 为 0。 |
| `expire must be future` | expireAt 不大于当前时间。 |
| `amount not divisible`  | totalAmount 不能被 totalCount 整除。 |
| `value mismatch`   | 原生币时 msg.value ≠ totalAmount。 |
| `no value for ERC20` | ERC20 时 msg.value ≠ 0。 |
| `transfer failed`  | ERC20 未 approve 或余额不足。 |

**币种展示 symbol（无需入参）**

- **ERC20**：创建时合约会调用代币的 `symbol()`（见 `IERC20Symbol`），将可读字符串规范为链上 `bytes32` 键并写入，供 `getRedPacketTokenSymbol`、`getMyRedPacketIds` 的 `symbolFilter` 等使用；`symbol()` revert、返回空串或含非可展示 ASCII / 超长等无法编码时，链上存空键。
- **原生币**（`token` 为零地址）：无 ERC20 合约可读，链上 symbol 为空字符串 / 空键。

---

### 3.2 createRandomRedPacket — 创建随机金额红包

每份金额在领取时链上随机，总金额与份数在创建时确定。

**签名**

```
createRandomRedPacket(address token, uint256 totalAmount, uint256 totalCount, uint256 expireAt, address[] allowedAddresses) returns (uint256 id)
```

**参数**（与 `createFixedRedPacket` 相同）

| 参数名            | 类型      | 说明 |
|-------------------|-----------|------|
| token             | address   | 同 3.1。 |
| totalAmount       | uint256   | 同 3.1。 |
| totalCount        | uint256   | 同 3.1。 |
| expireAt          | uint256   | 同 3.1。 |
| allowedAddresses  | address[] | 同 3.1。 |

**返回值**

| 名称 | 类型    | 说明     |
|------|---------|----------|
| id   | uint256 | 新创建的红包 ID。 |

**交易 value / 错误**：与 3.1 相同（原生币须带 value，ERC20 须 approve，无“整除”校验）。

**币种 symbol**：与 3.1 相同，创建时自动从 ERC20 `symbol()` 读取；原生币为空。

---

### 3.3 claim — 领取红包

**签名**

```
claim(uint256 id) returns (uint256 amount)
```

**参数**

| 参数名 | 类型    | 说明     |
|--------|---------|----------|
| id     | uint256 | 红包 ID。 |

**返回值**

| 名称   | 类型    | 说明           |
|--------|---------|----------------|
| amount | uint256 | 本次领取的金额。 |

**可能错误（revert）**

| 错误信息        | 原因 |
|-----------------|------|
| `invalid id`    | 该 id 对应红包不存在（creator 为 0）。 |
| `expired`       | 已过 expireAt。 |
| `already claimed` | 当前地址已领过该红包。 |
| `all claimed`   | 该红包已被领完。 |
| `not in whitelist` | 该红包有白名单且当前地址不在白名单中。 |

**说明**：每人每个红包仅可领取一次；领取后代币/原生币会转入调用者地址。

---

### 3.4 withdraw — 取回未领完金额（仅发起人、过期后）

**签名**

```
withdraw(uint256 id)
```

**参数**

| 参数名 | 类型    | 说明     |
|--------|---------|----------|
| id     | uint256 | 红包 ID。 |

**返回值**：无。

**可能错误（revert）**

| 错误信息          | 原因 |
|-------------------|------|
| `not creator`     | 调用者不是该红包发起人。 |
| `not expired`     | 未过 expireAt，不允许取回。 |
| `already withdrawn` | 该红包已被发起人取回过。 |

**说明**：仅红包 **creator** 在 **过期后** 可调用一次，将剩余未领取金额收回己方地址。

---

## 四、只读方法（view / pure，不消耗 Gas）

### 4.1 getRedPacket — 查询红包完整信息

**签名**

```
getRedPacket(uint256 id) view returns (
  address creator,
  address token,
  RedPacketType ptype,
  uint256 totalAmount,
  uint256 totalCount,
  uint256 claimedCount,
  uint256 expireAt,
  uint256 whitelistCount,
  uint256 amountPerShare,
  bool withdrawn
)
```

**参数**

| 参数名 | 类型    | 说明     |
|--------|---------|----------|
| id     | uint256 | 红包 ID。 |

**返回值**：与 `RedPacketInfo` 字段一一对应（见 1.2）。无效 id 会返回全零/默认值（creator 为 0 表示不存在）。

---

### 4.2 getClaimedCount — 已领取份数

**签名**

```
getClaimedCount(uint256 id) view returns (uint256)
```

**参数**：`id`（uint256）  
**返回**：该红包已被领取的份数。

---

### 4.3 getClaimedAmount — 已领取总金额

**签名**

```
getClaimedAmount(uint256 id) view returns (uint256)
```

**参数**：`id`（uint256）  
**返回**：该红包已被领取的金额总和（最小单位）。

---

### 4.4 isClaimed — 某用户是否已领取

**签名**

```
isClaimed(uint256 id, address user) view returns (bool)
```

**参数**

| 参数名 | 类型    | 说明       |
|--------|---------|------------|
| id     | uint256 | 红包 ID。   |
| user   | address | 用户地址。 |

**返回**：该用户是否已领取该红包。

---

### 4.5 isExpired — 是否已过期

**签名**

```
isExpired(uint256 id) view returns (bool)
```

**参数**：`id`（uint256）  
**返回**：当前时间是否 ≥ 该红包的 `expireAt`。

---

### 4.6 getRemainingAmount — 剩余未领取金额

**签名**

```
getRemainingAmount(uint256 id) view returns (uint256)
```

**参数**：`id`（uint256）  
**返回**：`totalAmount - getClaimedAmount(id)`。

---

### 4.7 hasWhitelist — 是否启用白名单

**签名**

```
hasWhitelist(uint256 id) view returns (bool)
```

**参数**：`id`（uint256）  
**返回**：该红包创建时是否传入了非空白名单（whitelistCount > 0）。

---

### 4.8 isInWhitelist — 某地址是否在白名单内

**签名**

```
isInWhitelist(uint256 id, address account) view returns (bool)
```

**参数**

| 参数名  | 类型    | 说明       |
|---------|---------|------------|
| id      | uint256 | 红包 ID。   |
| account | address | 要查询的地址。 |

**返回**：该地址是否在该红包的白名单中。

---

### 4.9 getRedPacketIdParts — 解析红包 ID 为日期与序号

**签名**

```
getRedPacketIdParts(uint256 id) pure returns (uint256 dayIndex, uint256 sequence)
```

**参数**：`id`（uint256）  
**返回**：

| 名称      | 类型    | 说明 |
|-----------|---------|------|
| dayIndex  | uint256 | 自 Unix 纪元起的天数，可用于换算日期。 |
| sequence  | uint256 | 当日创建顺序（从 1 开始）。 |

---

### 4.10 getRedPacketIdsByCreator — 按发起人查红包 ID 列表

**签名**

```
getRedPacketIdsByCreator(address creator) view returns (uint256[])
```

**参数**：`creator`（address）— 发起人地址。  
**返回**：该发起人创建的所有红包 ID 数组（按创建时间从早到晚）。

---

### 4.11 getClaimRecords — 按红包 ID 查领取记录列表

**签名**

```
getClaimRecords(uint256 id) view returns (ClaimRecord[] memory)
```

**参数**：`id`（uint256）— 红包 ID。  
**返回**：该红包全部领取记录（先领取在前）。无领取时返回空数组。

---

### 4.12 getClaimRecordCount — 领取记录条数

**签名**

```
getClaimRecordCount(uint256 id) view returns (uint256)
```

**参数**：`id`（uint256）  
**返回**：`getClaimRecords(id)` 的长度，便于分页或与事件对照。

---

### 4.13 getRedPacketIdsReceivedBy — 某地址领过的红包 ID（全量）

**签名**

```
getRedPacketIdsReceivedBy(address user) view returns (uint256[] memory)
```

**参数**：`user`（address）  
**返回**：该地址 **成功 claim** 过的红包 ID 列表（按领取先后追加），**无**年月 / symbol 筛选。

---

### 4.14 getMyRedPacketIds — 按地址 + 收发方向 + 年月 + symbol 筛选

**签名**

```
getMyRedPacketIds(
  address account,
  bool asReceiver,
  uint256 year,
  uint256 month,
  string calldata symbolFilter
) view returns (uint256[] memory)
```

**参数**

| 参数名        | 类型    | 说明 |
|---------------|---------|------|
| account       | address | 要查询的钱包地址。 |
| asReceiver    | bool    | `true`：该地址 **收到** 的红包（成功领取过的 ID）；`false`：该地址 **发出** 的红包（与 `getRedPacketIdsByCreator` 同源）。 |
| year          | uint256 | 公历年，≥ 1970（UTC）。 |
| month         | uint256 | `1`–`12` 表示该月；`0` 表示 **整年**。 |
| symbolFilter  | string  | **空字符串** 表示不按 symbol 筛选；非空时与创建时存储的符号键比对（**小写 a–z 会先规范为大写**再比较，与链上存储规则一致）。 |

**时间口径**：按红包 **ID 内嵌的创建日** `dayIndex = id / 1e6`（UTC）落在 `year`/`month` 范围内筛选，**不是**领取时间、也不是 `expireAt`。

**symbol 说明**：链上存 `bytes32` 键；原生币或读 symbol 失败时键为 0，此时用非空 `symbolFilter` **无法**筛到这些红包（需结合 `getRedPacket(id).token` 等区分）。

---

### 4.15 getRedPacketTokenSymbol — 查询红包展示用 symbol 字符串

**签名**

```
getRedPacketTokenSymbol(uint256 id) view returns (string memory)
```

**参数**：`id`（uint256）  
**返回**：创建时写入的符号可读字符串；无符号时返回空字符串 `""`。

---

### 4.16 getRedPacketTokenSymbolKey — 查询红包 symbol 原始键

**签名**

```
getRedPacketTokenSymbolKey(uint256 id) view returns (bytes32)
```

**参数**：`id`（uint256）  
**返回**：与事件 `RedPacketCreated` 中 `tokenSymbolKey` 及筛选逻辑一致的 `bytes32` 键。

---

## 五、公开状态变量（可直接读取）

| 名称           | 类型/含义 | 说明 |
|----------------|-----------|------|
| redPackets(id) | 见 ABI    | 同 `getRedPacket(id)` 的映射形式。 |
| whitelist(id, account) | bool | 同 `isInWhitelist(id, account)`。 |
| hasClaimed(id, user)   | bool | 同 `isClaimed(id, user)`。 |
| claimedAmount(id)      | uint256 | 同 `getClaimedAmount(id)`。 |
| nextSeqInDay(dayIndex) | uint256 | 某天的下一个序号（多为内部/展示用）。 |

---

## 六、管理/升级相关（仅 owner）

| 方法                 | 说明 |
|----------------------|------|
| initialize()         | 代理部署后仅可调用一次，设置 owner。 |
| transferOwnership(newOwner) | 转移合约 owner。 |
| renounceOwnership()  | 放弃 owner（慎用）。 |
| upgradeToAndCall(newImplementation, data) | UUPS 升级逻辑，仅 owner 可调。 |

前端/移动端一般只需对接**二、三、四**节的写方法与只读方法即可；管理方法多由部署方在后台或脚本中调用。

---

## 七、快速对照表

| 需求           | 推荐方法 |
|----------------|----------|
| 创建固定红包   | createFixedRedPacket |
| 创建随机红包   | createRandomRedPacket |
| 用户领红包     | claim |
| 过期后发起人取回 | withdraw |
| 查红包详情     | getRedPacket |
| 是否已领/是否过期/剩余金额 | isClaimed / isExpired / getRemainingAmount |
| 白名单判断     | hasWhitelist / isInWhitelist |
| 解析 ID 展示   | getRedPacketIdParts |
| 查某人发的红包 | getRedPacketIdsByCreator |
| 查某人领过的红包（全量 ID） | getRedPacketIdsReceivedBy |
| 按年月 + symbol 筛「收到/发出」红包 ID | getMyRedPacketIds |
| 某红包领取明细列表 | getClaimRecords / getClaimRecordCount |
| 某红包展示用 symbol | getRedPacketTokenSymbol / getRedPacketTokenSymbolKey |

以上方法名、参数、返回值与 `sol/RedPacketUpgradeable.abi` 一致，可直接用于 ABI 编码与交易构造。
