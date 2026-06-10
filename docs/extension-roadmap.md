# 毕设项目扩展路线

## 项目定位

本项目建议作为毕业设计仓库使用，GitHub 仓库名建议为 `MahjongVisionSync`。中文题目建议为“基于多路视频分区感知的麻将赛事牌局状态识别与观众数据展示系统的设计与实现”。

当前代码已经完成单机麻将听牌分析、手动录入、相机采集、CoreML 识别和扫描结果确认。毕设扩展不应先重写现有逻辑，而应在现有能力上新增赛事数据系统模块。项目定位不是单纯识别麻将牌，也不是向选手提供实时决策建议，而是服务赛事工作人员、裁判、转播数据人员和观众。

## 推荐扩展顺序

### 1. 项目结构整理

先保留现有 `MahjongTing` App Target，新增面向比赛系统的目录，避免一次性重命名 Xcode 工程。

建议新增：

- `MahjongTing/Match/`：比赛会话、视频源、设备角色、牌桌区域模型
- `MahjongTing/VideoIngestion/`：公开视频切流、固定机位视频输入、抽帧与时间戳管理
- `MahjongTing/Networking/`：实时采集端发现、连接、消息收发
- `MahjongTing/Reconstruction/`：牌局状态重建、冲突融合、合法性校验
- `MahjongTing/Analysis/`：听牌、有效牌、剩余牌和观众展示指标分析
- `MahjongTing/Replay/`：事件保存、复盘数据读取

### 2. 多路视频会话

第一版优先使用网上比赛视频切分出的多路区域视频做原型。典型配置为四路选手手牌区视频，弃牌区如果公开视频无法稳定覆盖，可先使用人工录入或人工确认作为校正输入。后续实时部署时，再使用 `MultipeerConnectivity` 支持 2 到 3 台或更多 iPhone/iPad 的局域近场演示。

第一版只需要支持：

- 主控端创建比赛会话
- 多路视频源或采集端绑定负责区域
- 四路手牌区视频生成识别事件
- 弃牌区通过可选视频、人工录入或人工确认补充
- 主控端显示视频源状态、最近事件时间和区域识别质量

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

不要让识别模块直接修改全局牌局状态。每路视频源或采集端应发送“识别事件”，主控端再统一融合。这样系统重点就从“识别一张牌”转为“把比赛过程转换成可追溯的牌局事件流”。

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

这样后续可以同时服务赛事记录、观众展示、冲突处理和赛后复盘。

### 4. 牌局状态重建

主控端需要维护一个统一的 `MatchGameState`，来源不是用户手动录入，而是多端识别事件。

第一版只做可演示的基础状态：

- 四家当前手牌计数
- 弃牌区计数或人工确认弃牌事件
- 副露区计数
- 已见牌计数
- 每个区域最近一次识别时间
- 非法状态提示，例如同一张牌超过 4 张

融合策略先保持简单：

- 同一区域取最近 2 秒内置信度最高的一组结果
- 同设备连续识别结果做稳定化
- 总牌数超过 4 张时标记冲突，不自动强行修正
- UI 提供人工确认入口

### 5. 赛事展示指标扩展

现有 `Engine.swift` 已经可以支持听牌和有效牌分析。下一步应新增面向赛事工作人员和观众展示的包装层，而不是把所有概率逻辑塞回 `Engine.swift`。这些指标用于转播展示和复盘说明，不向参赛选手提供实时决策建议。

建议新增 `ProbabilityAnalyzer`：

- 输入：某一选手席位手牌、已见牌、副露、规则模式
- 输出：听牌列表、有效牌数量、剩余有效牌数量、摸入有效牌概率
- 保存每次状态变化后的快照，用于趋势图

概率第一版使用简化模型即可：

```text
摸入有效牌概率 = 剩余有效牌数量 / 剩余未知牌数量
```

这足够支撑毕设演示和论文说明，复杂胡牌概率可以作为扩展。

### 6. 工作人员/观众展示与复盘

新增一个比赛主控界面，和现有单机听牌界面分开。

建议界面模块：

- 会话视频源/设备列表
- 四家牌局状态概览
- 当前识别冲突提示
- 听牌、有效牌和剩余有效牌展示面板
- 面向观众的趋势图
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

最小可行版本建议只做五件事：

1. 新增比赛模式入口。
2. 支持四路手牌区视频输入或公开视频切流输入。
3. 每路视频生成带时间戳、区域和置信度的识别事件。
4. 弃牌区先支持人工录入或人工确认，避免公开视频遮挡导致系统闭环断开。
5. 主控端调用现有 `Engine.swift` 对四家手牌计算听牌、有效牌和剩余有效牌展示指标。

完成这五点后，项目就从“单机手牌分析基础能力”升级为“多路视频赛事数据原型系统”，能够支撑毕设核心演示，也为后续赛事合作展示打下基础。
