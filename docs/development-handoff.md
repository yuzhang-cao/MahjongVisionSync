# MahjongVisionSync 开发交接与多 Agent 运行说明

最后更新：2026-07-10（切换 Codex 对话前的运行快照）

## 1. 项目目标

`MahjongVisionSync` 是软件工程毕业设计。现有基础是 iOS `MahjongTing` 应用：手牌录入、听牌/胡牌计算、相机扫描和 CoreML 牌面识别。后续目标是在**不重写现有 iOS 能力**的前提下，逐步扩展为面向赛事工作人员、转播人员、裁判和赛后复盘的系统：多路视频输入、识别事件化、牌局状态重建、数据展示与回放。

项目定位不是给比赛选手提供实时决策建议。

## 2. 必须遵守的协作架构

始终采用以下结构：

```text
用户 -> 持久核心 Agent（Mac） -> 固定执行 Agent -> 代码、测试与报告
                                      |
                                      +-> Windows 构建节点（SSH）
```

- **只有核心 Agent** 可以调用 `delegate_task`、`send_followup`、`inspect_agent`、`wait_for_agents`、`integrate_changes`、`add_agent` 等管理工具。
- 成员 Agent 可以使用正常的项目工具（读写自己工作树内的文件、运行测试、提交 Git），但不能创建成员、派发任务或合并别人的变更。
- 开发顺序固定为：核心派单 -> 成员在隔离工作树完成工作并提交 -> 核心审查/测试 -> 核心集成到 `main`。
- 每完成一项可验收任务或一批有意义的代码，必须验证并提交一次；不要堆积大批未保存改动。
- 不要用临时子 Agent 取代持久成员团队。

## 3. 本机与 Windows 节点

### Mac（核心调度端）

- 项目路径：`/Users/caoyuzhang/Desktop/MahjongVisionSync`
- Git 分支：`main`
- 远程仓库：`https://github.com/yuzhang-cao/MahjongVisionSync.git`
- Mac SSH 别名：`winpc`
- 已验证：`ssh -o BatchMode=yes winpc "hostname && whoami"` 能免密登录 Windows。

### Windows（构建执行端）

- 主机：`WIN-8N401EAPS0V`
- SSH 登录身份：`win-8n401eaps0v\\administrator`
- 独立工作副本：`C:\\Users\\Administrator\\codex-workspaces\\MahjongVisionSync`
- 已验证与 Mac 同步的基线提交：`8a36407`
- 已有工具：Git 2.54、Python 3.11（另有 `py` 3.13）、Node 18/npm 10、NVIDIA GeForce RTX 4060 Ti。
- 当前缺少：CMake、Visual Studio/MSBuild、FFmpeg、.NET SDK。
- 已通过的 Windows 任务：在独立副本执行 `py -3.11 -m compileall -q tools`。

### 跨平台边界

当前 `MahjongTing.xcodeproj` 是 Swift/iOS/Xcode 工程，且识别路径依赖 Vision/CoreML。因此：

- iOS App 构建、Xcode 测试、CoreML 推理必须在 Mac 上完成；不要派给 Windows。
- Windows 适合后续的跨平台服务、Python 视频预处理、OpenCV/FFmpeg 管线、ONNX 推理/模型验证、GPU 批处理和 Windows 兼容的 API/数据模块。
- Mac 与 Windows **绝不能共用同一个 Git 工作目录**。两端通过 Git 分支、提交和 `fetch/pull` 交接。
- 当前未批准安装任何 Windows 软件包。先由核心审查方案，再明确决定安装何种工具。

## 4. 持久团队运行状态

项目已运行：

```bash
codex-team init /Users/caoyuzhang/Desktop/MahjongVisionSync
```

当前核心线程和团队状态已保存在项目内 `.codex-team/`。**不要删除 `.codex-team/state.json`，不要强制重置成员分支，也不要再次运行 `init`。**

默认成员：

- `architect`：架构、接口、模块边界和技术风险。
- `frontend`：iOS/前端展示与用户体验。
- `backend`：服务、数据、API 与跨平台计算模块。
- `tester`：测试策略、验收和回归审查。
- `windows-builder`：通过 `ssh winpc` 执行 Windows 兼容的构建/测试任务；无管理权限；默认不得安装软件或执行破坏性操作。

切换到新对话后，先在 Mac 终端执行：

```bash
codex-team status /Users/caoyuzhang/Desktop/MahjongVisionSync
codex-team tasks /Users/caoyuzhang/Desktop/MahjongVisionSync
codex-team chat /Users/caoyuzhang/Desktop/MahjongVisionSync
```

最后一条命令会恢复同一个核心线程及成员线程。终端关闭会暂停当前工作；再次运行 `chat` 可恢复，不要重新建团队。

## 5. 目前正在执行的任务

以下任务在交接时为 `running`，均为只读审计，不会改动代码或安装软件：

1. `windows-builder`：审计当前 Swift/iOS/Xcode/CoreML 工程中哪些任务可在 Windows 远程节点构建、测试或验证；识别工具链、路径、模型包与多 Agent 构建流水线风险；提出最小的 Windows 构建目标。
2. `architect`：审计现有 Swift 源码与文档，提出从单端扫描/手牌计算演进到多路赛事事件系统的最小模块边界，且不破坏既有 iOS App。
3. `tester`：在上述两份报告完成后，由核心派发可行性复核任务。

新对话不要重复派发这两项工作。先执行 `codex-team tasks ...`，让核心检查、等待并汇总现有任务；仅在任务失败或核心明确决定重试时再用 `send_followup` 或新任务处理。

## 6. 建议的下一阶段（须由核心根据审计报告确认）

1. 核心审查两个审计报告，并让 tester 给出“首个 Windows 目标是否可行”的证据。
2. 确定第一个可交付的跨平台模块边界。推荐优先考虑独立的“赛事识别事件/牌局状态数据契约与离线验证工具”，而不是立刻重写 iOS UI 或 CoreML 识别。
3. 在明确语言、接口和 Windows 工具链需求后，再批准并记录安装（例如 Python 虚拟环境、FFmpeg、OpenCV、ONNX Runtime 或服务端运行时）。
4. 核心分派实现任务给 backend/windows-builder，分派 iOS 接口任务给 frontend，分派验收任务给 tester；每个成员提交独立小批次。
5. 核心执行集成验证：Mac 端 iOS/Swift 检查 + Windows 端远程构建或测试 + Git 状态检查。

## 7. 新对话的启动指令

把下面这段发给新对话即可：

```text
继续 /Users/caoyuzhang/Desktop/MahjongVisionSync 的毕业设计开发。

必须使用已有的持久多 Agent 调度器：用户 -> 核心 Agent -> 固定成员 Agent；只有核心拥有管理工具。先阅读 docs/development-handoff.md，然后执行 codex-team status、codex-team tasks，并通过 codex-team chat 恢复已有核心线程。不要重新 init，不要删除 .codex-team 状态，不要重复派发当前 running 的两项只读审计。

Mac 是核心调度端；Windows 通过 ssh winpc 作为独立构建节点，工作副本在 C:\\Users\\Administrator\\codex-workspaces\\MahjongVisionSync。不能把 iOS/Xcode/CoreML 构建派给 Windows。先等待、审查并复核当前审计报告，再由核心确定并派发第一个跨平台实现任务。所有代码任务都要小批次验证、提交，并由核心集成。
```

## 8. 关键安全与运行要求

- 不在文档、提交或聊天中复制 SSH 私钥、口令、令牌或其他密钥。
- Windows 目前以 `Administrator` SSH 登录仅用于初始化；在开始长期自动化前，核心应规划专用的低权限构建账户。
- 远程构建命令必须使用明确的工作目录，并输出命令、结果、提交 SHA 与风险。
- 安装软件、删除文件、覆盖远程分支、推送公开仓库或改变产品方向，必须先由核心向用户说明影响并获得授权。
