# MahjongVisionSync

基于多 iOS 终端协同感知的麻将比赛牌局状态识别与实时概率分析系统。

当前代码来自 `MahjongTing`，已经具备单机麻将手牌录入、听牌/胡牌计算、相机扫描和 CoreML 牌面识别基础。后续毕设扩展重点是把单机识别能力扩展为比赛场景下的多终端同步、牌局状态重建、概率趋势分析和复盘记录系统。

> Xcode 工程和 App Target 暂保留 `MahjongTing` 命名，避免在迁移阶段引入工程引用风险。仓库展示名称建议使用 `MahjongVisionSync`。

iOS 麻将听牌与扫描辅助应用。
ps：为什么不上架呢，因为要交年费。

支持广东 / 四川规则，支持手动录入、听牌与胡牌计算、碰 / 杠管理，以及相机扫描识别。

## 当前内容

- 规则计算：广东、四川；支持七对；广东支持十三幺；四川支持定缺
- 手牌操作：图形化点牌、删牌、清空、碰、杠、暗杠、明杠
- 扫描入口：AVCapture 相机扫描页面，接入 CoreML 整排识别
- 测试工具：开发期数据集导出代码已移到根目录 `TestCode.swift`

## 项目结构

- `App.swift`：应用入口与方向控制
- `MainView.swift`：主界面与交互
- `ViewModel.swift`：手牌状态与计算调度
- `Engine.swift`：听牌 / 胡牌 / 副露计算
- `ScanView.swift`、`Camera.swift`、`CameraPreview.swift`：扫描界面与相机采集
- `Recognizer.swift`：CoreML 识别
- `TestCode.swift`：开发 / 测试期工具，不参与 App 运行逻辑

## 模型与识别

当前仓库包含 `TileModel.mlpackage`，扫描页默认通过 `Recognizer.swift` 加载 `TileModel.mlmodelc`。

当前单牌分类映射为 34 类，见 `CATEGORY_MAPPING.md`。

## 数据与引用

数据来源、第三方项目、模型权重说明、清洗 / 标注 / 重构记录见 `THIRD_PARTY_NOTICES.md`。

## 后续改进

- 多终端会话：采集端加入同一比赛会话，主控端接收识别结果
- 状态重建：将手牌、弃牌、副露、已见牌统一建模并校验合法性
- 识别融合：结合设备区域、时间戳和置信度融合多端识别结果
- 概率分析：补充剩余有效牌、摸入概率和趋势快照
- 复盘记录：保存关键事件并支持赛后回放

详细扩展路线见 `docs/extension-roadmap.md`。

## License

本仓库使用 `CC BY 4.0`，见根目录 `LICENSE`。
