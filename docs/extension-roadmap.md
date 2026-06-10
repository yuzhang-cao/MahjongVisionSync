# 毕设项目扩展路线

## 项目定位

本项目建议作为毕业设计仓库使用，GitHub 仓库名建议为 `MahjongVisionSync`。中文题目为“基于多 iOS 终端协同感知的麻将比赛牌局状态识别与实时概率分析系统的设计与实现”。

当前代码已经完成单机麻将听牌分析、手动录入、相机采集、CoreML 识别和扫描结果确认。毕设扩展不应先重写现有逻辑，而应在现有能力上新增比赛场景模块。

## 推荐扩展顺序

### 1. 项目结构整理

先保留现有 `MahjongTing` App Target，新增面向比赛系统的目录，避免一次性重命名 Xcode 工程。

建议新增：

- `MahjongTing/Match/`：比赛会话、设备角色、牌桌区域模型
- `MahjongTing/Networking/`：多 iOS 终端发现、连接、消息收发
- `MahjongTing/Reconstruction/`：牌局状态重建、冲突融合、合法性校验
- `MahjongTing/Analysis/`：有效牌、剩余牌和概率趋势分析
- `MahjongTing/Replay/`：事件保存、复盘数据读取

### 2. 多终端会话

优先使用 `MultipeerConnectivity` 做原型，因为它适合 2 到 3 台 iPhone/iPad 的局域近场演示，不需要额外服务器。

第一版只需要支持：

- 主控端创建比赛会话
- 采集端发现并加入会话
- 设备上报编号、角色和负责区域
- 采集端发送识别结果
- 主控端显示设备在线状态和最近上报时间

核心数据结构建议：

```swift
struct MatchDevice: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var role: DeviceRole
    var zone: TableZone
    var lastSeenAt: Date
}

enum DeviceRole: String, Codable {
    case host
    case capture
}

enum TableZone: String, Codable {
    case playerHandEast
    case playerHandSouth
    case playerHandWest
    case playerHandNorth
    case discardArea
    case meldArea
    case fullTable
}
```

### 3. 识别结果事件化

不要让识别模块直接修改全局牌局状态。采集端应发送“识别事件”，主控端再统一融合。

建议事件格式：

```swift
struct TileRecognitionEvent: Identifiable, Codable {
    let id: UUID
    let matchID: UUID
    let deviceID: UUID
    let zone: TableZone
    let capturedAt: Date
    let tiles: [RecognizedTile]
}

struct RecognizedTile: Identifiable, Codable {
    let id: UUID
    let tileIndex: Int
    let confidence: Float
    let normalizedRect: CodableRect
}
```

这样后续可以同时服务实时展示、冲突处理和赛后复盘。

### 4. 牌局状态重建

主控端需要维护一个统一的 `MatchGameState`，来源不是用户手动录入，而是多端识别事件。

第一版只做可演示的基础状态：

- 四家当前手牌计数
- 弃牌区计数
- 副露区计数
- 已见牌计数
- 每个区域最近一次识别时间
- 非法状态提示，例如同一张牌超过 4 张

融合策略先保持简单：

- 同一区域取最近 2 秒内置信度最高的一组结果
- 同设备连续识别结果做稳定化
- 总牌数超过 4 张时标记冲突，不自动强行修正
- UI 提供人工确认入口

### 5. 概率分析扩展

现有 `Engine.swift` 已经可以支持听牌和有效牌分析。下一步应新增面向比赛展示的包装层，而不是把所有概率逻辑塞回 `Engine.swift`。

建议新增 `ProbabilityAnalyzer`：

- 输入：某玩家手牌、已见牌、副露、规则模式
- 输出：听牌列表、有效牌数量、剩余有效牌数量、摸入有效牌概率
- 保存每次状态变化后的快照，用于趋势图

概率第一版使用简化模型即可：

```text
摸入有效牌概率 = 剩余有效牌数量 / 剩余未知牌数量
```

这足够支撑毕设演示和论文说明，复杂胡牌概率可以作为扩展。

### 6. 展示与复盘

新增一个比赛主控界面，和现有单机听牌界面分开。

建议界面模块：

- 会话设备列表
- 四家牌局状态概览
- 当前识别冲突提示
- 听牌和有效牌分析面板
- 概率趋势图
- 事件时间线

复盘第一版使用本地 JSON 保存即可，结构清晰比数据库更重要。后续数据量增加再考虑 SQLite 或 CoreData。

### 7. 测试和论文验证

毕设验收需要可量化结果。建议准备以下测试：

- 单机听牌算法测试：固定手牌输入，验证听牌输出
- 牌面识别测试：固定图片集，统计识别数量和类别准确率
- 通信延迟测试：采集端发送事件到主控端显示的耗时
- 状态合法性测试：输入超过 4 张同类牌，验证冲突提示
- 复盘完整性测试：保存事件后重新加载，验证状态一致

## 近期最小可行版本

最小可行版本建议只做四件事：

1. 新增比赛模式入口。
2. 用 `MultipeerConnectivity` 实现一台主控端和一台采集端通信。
3. 采集端发送当前扫描出的牌面数组，主控端显示并保存事件。
4. 主控端调用现有 `Engine.swift` 对某一家的手牌计算听牌和剩余有效牌概率。

完成这四点后，项目就从“单机麻将听牌工具”升级为“多 iOS 终端协同感知原型系统”，已经能支撑毕设核心演示。
