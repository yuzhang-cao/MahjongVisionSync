# MahjongVisionSync 赛事规则、识别模型与 Equity 规格

## 1. 文档目的

本文档记录已经确认、必须先于代码改造落地的赛事系统需求。它是后续修改 `Recognizer.swift`、`Engine.swift` 或新增规则/识别模块之前的正式规格依据。

当前阶段只允许先完成规格、接口和数据契约设计；不得直接改造识别器或规则引擎来适配新规则。

## 2. 已确认需求

### 2.1 MCR 规则档案

系统必须支持 MCR（Mahjong Competition Rules，国标麻将）作为独立规则档案。

MCR 不得混入当前广东、四川规则逻辑，也不得通过在现有规则分支中追加零散条件实现。实现前必须先定义统一的规则档案接口，至少包含：

- 规则档案标识，例如 `mcr`。
- 牌型、番种或计分规则的独立描述方式。
- 起手、摸打、副露、和牌、计分和合法性校验所需的输入字段。
- 与赛事状态重建模块之间的最小数据交换结构。

MCR 的规则实现应位于规则档案边界之后，不能让 UI、识别器或状态融合模块直接依赖 MCR 内部判定细节。

### 2.2 M.League 风格 Riichi 规则档案

系统必须支持 M.League 风格 Riichi 作为独立规则档案。

该规则档案必须与 MCR 和地方中国麻将规则分离。M.League 风格 Riichi 至少需要在规格层预留：

- 规则档案标识，例如 `riichiMLeague`。
- 立直、役种、宝牌、赤宝牌、场风、自风、本场、供托、亲家和点棒环境。
- 流局、罚符或赛事展示所需的状态字段。
- 与观众展示指标和 equity 指标相关的计分上下文。

Riichi 相关规则不得通过复用 MCR 或广东/四川的胡牌路径来隐式实现。后续可以共享通用牌计数、可见牌统计和状态快照结构，但规则判定与计分必须通过规则档案接口隔离。

## 3. 双模型识别需求

系统必须支持双模型识别策略，并且在改造识别器之前先稳定输出契约。

第一版双模型按赛事视觉域划分：

- `mcrTileModel`：面向 MCR/国标比赛或中文麻将牌面风格。
- `riichiMLeagueTileModel`：面向 M.League 风格 Riichi 牌面、赤宝牌和日麻视觉风格。

两个模型可以采用不同训练数据、标签扩展和置信度校准方式。Windows RTX 4060 Ti 节点负责两套数据集的预处理、训练、评估和 ONNX 等可移植中间模型导出；Mac 负责将验收通过的模型转换或集成为 CoreML，并完成 Xcode、iOS 模拟器和真机验证。两个模型对系统其他模块必须暴露同一输出契约：

```swift
struct TileRecognitionCandidate: Codable {
    var tileCode: String
    var tileIndex: Int?
    var visualDomain: TileVisualDomain
    var confidence: Float
    var normalizedRect: CodableRect
    var sourceModelID: String
    var capturedAt: Date
}
```

要求：

- `tileCode` 必须稳定表达牌面身份，不能只依赖模型内部标签顺序。
- `tileIndex` 仅在可映射到当前规则档案的 34 类或扩展类别时填写。
- 赤宝牌、花牌或规则特有牌面必须通过 `tileCode` 和规则档案映射处理，不能破坏通用事件结构。
- 识别模型只产出候选结果，不直接修改牌局状态。
- 模型选择由比赛会话或视频源配置决定，不能在规则引擎中硬编码。
- 后续如果采用“检测模型 + 分类模型”的两阶段实现，也必须适配同一候选输出契约。

## 4. Equity 指标需求

系统必须支持 equity 指标，并将其与当前简化的“摸入有效牌概率”区分开。

`drawEffectiveProbability` 只表示剩余有效牌数量除以剩余未知牌数量。Equity 是面向观众、转播和赛后复盘的局面价值指标，应综合规则档案、可见牌、点数/番种环境、亲家或座位影响以及不确定性。

Equity 第一版可以是可解释的估计或趋势指标，不要求直接实现完整搜索或精确胜率引擎。但规格必须固定最小输入和输出。

最小输入：

- `MatchGameState`：四家手牌、弃牌、副露、已见牌、冲突和时间戳。
- `RulesProfile`：MCR、M.League 风格 Riichi 或其他规则档案。
- `ScoringContext`：局况、座位、点棒或番种环境；Riichi 需包含宝牌、本场、供托等字段。
- `RecognitionUncertainty`：低置信度区域、模型来源和人工确认状态。

最小输出：

- 每名选手的 equity 值或归一化 equity 指数。
- 指标版本和计算方法标识。
- 置信度或不确定性说明。
- 影响因素摘要，例如有效牌、可见牌、得点潜力或规则档案因素。
- 可保存到复盘时间线的 `EquitySnapshot`。

Equity 结果不得在比赛现场向选手提供实时决策建议。UI 和导出文案必须标记为赛事工作人员、转播、观众或复盘用途。

## 5. 模块边界

后续实现必须先建立以下边界，再修改识别器或规则引擎：

| 边界 | 职责 | 不应承担 |
| --- | --- | --- |
| `RulesProfile` | 描述规则档案、合法动作、计分上下文和牌面映射 | 图像识别、UI 展示、模型选择 |
| `RecognitionModelProfile` | 描述模型 ID、视觉域、标签映射和输出契约 | 牌局状态修改、规则判定 |
| `TileRecognitionEvent` | 记录带时间戳、区域、模型来源和候选牌面的识别事件 | 直接覆盖全局状态 |
| `MatchGameState` | 表达融合后的牌局状态和冲突 | 识别模型推理、复杂规则内部实现 |
| `EquityAnalyzer` | 根据状态、规则和不确定性产生观众指标 | 直接读取相机帧或修改手牌 |

## 6. 平台与构建边界

平台职责按“训练与可移植模型”和“iOS/CoreML 集成验证”拆分：

- Windows 远程节点不能执行原生 iOS/Xcode/CoreML 构建、模拟器测试、签名检查或 Vision/CoreML 运行验证。
- Windows RTX 4060 Ti 节点负责 MCR 与 M.League Riichi 两套数据集的预处理、训练、评估、指标汇总和 ONNX 等可移植中间模型导出。
- Mac/Xcode 是 iOS App、CoreML 转换或集成、设备相机、SwiftUI、模拟器和真机验证的可信环境。
- Windows 训练任务必须先通过只读环境审计、数据集位置和格式确认、依赖清单审查、训练脚本/配置审查和小样本 smoke 训练计划审查。
- 当前未批准安装训练依赖，也未批准启动实际训练；依赖安装和训练执行必须在数据集到位、依赖清单审查后单独批准。
- 任何 Windows 任务都不能把 Xcode 工程作为构建目标；Windows 产物应以数据集清单、训练日志、评估报告、ONNX 或其他可移植模型为交接边界。

2026-07-11 首轮只读核验已确认 Windows 节点具备 RTX 4060 Ti、NVIDIA 驱动、Python 3.11、PyTorch CUDA 12.1 可用环境，以及充足的 D/E 盘空间；但 `onnx`、`onnxruntime` 和 `ultralytics` 尚未安装，Windows 仓库副本也落后于 Mac 当前工作副本。该核验不等于批准训练。

## 7. 实施顺序

必须按以下顺序推进：

1. 完成本规格和相关系统设计文档确认。
2. 定义 `RulesProfile`、`RecognitionModelProfile`、识别事件、状态快照和 equity 快照的数据契约。
3. 为数据契约准备固定样例和测试输入。
4. 基于已完成的 Windows 训练环境只读审计，补齐数据集格式定义、仓库同步计划和依赖清单审查。
5. 在规则档案边界内实现 MCR 与 M.League 风格 Riichi，不直接污染现有广东/四川逻辑。
6. 在识别模型边界内训练、评估和导出双模型，不让模型输出直接修改牌局状态。
7. 在 Mac 端转换或集成验收通过的模型为 CoreML，并完成 Xcode、iOS 模拟器和真机验证。
8. 在展示和复盘层接入 equity 指标，并保留不确定性说明。

在第 1 至第 4 步完成前，不应改造 `Recognizer.swift`、`Engine.swift` 或启动实际训练。
