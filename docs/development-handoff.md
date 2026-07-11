# MahjongVisionSync 开发交接与多 Agent 运行说明

最后更新：2026-07-11（Windows 训练节点职责更新后）

## 1. 项目目标

`MahjongVisionSync` 是软件工程毕业设计。现有基础是 iOS `MahjongTing` 应用：手牌录入、听牌/胡牌计算、相机扫描和 CoreML 牌面识别。后续目标是在**不重写现有 iOS 能力**的前提下，逐步扩展为面向赛事工作人员、转播人员、裁判和赛后复盘的系统：多路视频输入、识别事件化、牌局状态重建、数据展示与回放。

项目定位不是给比赛选手提供实时决策建议。

## 2. 必须遵守的协作架构

始终采用以下结构：

```text
用户 -> 持久核心 Agent（Mac） -> 固定执行 Agent -> 代码、测试与报告
                                      |
                                      +-> Windows 训练/构建节点（SSH）
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

### Windows（训练与构建执行端）

- 主机：`WIN-8N401EAPS0V`
- SSH 登录身份：`win-8n401eaps0v\\administrator`
- 独立工作副本：`C:\\Users\\Administrator\\codex-workspaces\\MahjongVisionSync`
- 已验证与 Mac 同步的初始化基线提交：`8a36407`。交接文档提交 `725feca` 创建在此之后；下一项 Windows 远程任务开始前必须先 `git fetch origin` 并快进到 `origin/main`。
- 已有工具：Git 2.54、Python 3.11（另有 `py` 3.13）、Node 18/npm 10、NVIDIA GeForce RTX 4060 Ti。
- 当前缺少：CMake、Visual Studio/MSBuild、FFmpeg、.NET SDK。
- 已通过的 Windows 任务：在独立副本执行 `py -3.11 -m compileall -q tools`。
- 已确认职责更新：Windows RTX 4060 Ti 节点必须承担 MCR 与 M.League Riichi 两套数据集的预处理、训练、评估、指标汇总和 ONNX 等可移植中间模型导出。
- 2026-07-11 核心直接只读训练环境核验：`winpc` 可达，Windows 10 64 位，内存约 16 GB；NVIDIA GeForce RTX 4060 Ti 16 GB，驱动 560.94，`nvidia-smi` 显示 CUDA 12.6，`nvcc` 未安装；Python 3.11.5 和 3.13.1 可用；Python 3.11 下 `torch 2.5.1+cu121`、`torchvision 0.20.1+cu121`、`torchaudio 2.5.1+cu121`、`opencv-python 4.13.0.92`、`Pillow 11.3.0`、`numpy 2.3.3`、`pandas 2.3.2`、`tqdm 4.67.1` 已存在，`onnx`、`onnxruntime`、`ultralytics` 未安装；`torch.cuda.is_available()` 为 true，设备为 RTX 4060 Ti。
- 同次核验的磁盘空闲空间：C 约 501 GB、D 约 2496 GB、E 约 2612 GB、G 约 79 GB。Windows 独立仓库仍在 `8a36407`，未执行 `fetch`、`pull` 或远程文件修改。

### 跨平台边界

当前 `MahjongTing.xcodeproj` 是 Swift/iOS/Xcode 工程，且识别路径依赖 Vision/CoreML。因此：

- iOS App 构建、Xcode 测试、CoreML 转换/集成、CoreML 运行验证、模拟器和真机验证必须在 Mac 上完成；不要派给 Windows。
- Windows 负责训练侧工作：数据集预处理、训练环境审计、GPU 训练、评估、ONNX 或其他可移植中间模型导出，以及跨平台 Python/OpenCV/ONNX 工具链。
- Mac 与 Windows **绝不能共用同一个 Git 工作目录**。两端通过 Git 分支、提交和 `fetch/pull` 交接。
- 当前未批准安装任何 Windows 训练依赖，也未批准启动实际训练。必须先完成只读训练环境审计、数据集位置/格式确认和依赖清单审查，再由核心向用户申请安装或训练授权。

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
- `windows-builder` / `windows-training-builder`：通过 `ssh winpc` 执行 Windows 训练节点任务；负责 MCR 与 M.League Riichi 数据集预处理、训练环境审计、GPU 训练、评估和 ONNX 等可移植模型导出；无管理权限；默认不得安装软件、启动训练或执行破坏性操作。

运行时备注：旧 `windows-builder` 成员因职责替换被标记 inactive 后，当前管理运行时不允许复用同一 id 重新添加；本轮新增 `windows-training-builder` 执行同一 Windows 训练节点职责。对外职责仍可简称为 Windows builder。

切换到新对话后，先在 Mac 终端执行：

```bash
codex-team status /Users/caoyuzhang/Desktop/MahjongVisionSync
codex-team tasks /Users/caoyuzhang/Desktop/MahjongVisionSync
codex-team chat /Users/caoyuzhang/Desktop/MahjongVisionSync
```

最后一条命令会恢复同一个核心线程及成员线程。终端关闭会暂停当前工作；再次运行 `chat` 可恢复，不要重新建团队。

## 5. 目前正在执行的任务

当前没有必须继续等待的旧只读兼容性任务。此前 Windows 兼容性审计已确认 Windows 不能验证原生 iOS/Xcode/CoreML 运行环境，但 Windows 的训练侧职责已经按本文件更新。

首轮 Windows 训练环境只读核验已经由核心直接完成，因为 `windows-training-builder` 同范围任务已耗尽 3 次尝试且无可用报告。不要再创建同范围 Agent 任务。

后续 Windows 任务应等待数据集位置/格式和依赖清单明确后再派发；在获得用户授权前，不安装软件、不启动训练、不改动数据集、不改动远程仓库。

## 6. 建议的下一阶段（须由核心根据审计报告确认）

1. 基于已完成的 Windows 训练环境只读核验，确认 MCR 与 M.League Riichi 两套数据集的位置、许可、格式、标签映射和划分策略。
2. 审查 Windows 仓库同步方案、依赖清单和环境方案，再单独请求安装授权，例如 Python 虚拟环境、PyTorch/CUDA 适配包、OpenCV、Pillow、numpy、ONNX/ONNX Runtime、数据标注或转换工具。
3. 批准后由 Windows 训练节点执行小样本 smoke 预处理、训练、评估和 ONNX 导出；通过后再扩大到正式训练。
4. Mac 端只接收验收通过的可移植模型，负责 CoreML 转换/集成以及 Xcode、iOS 模拟器和真机验证。
5. 核心执行集成验证：训练产物记录 + Windows 训练/导出报告 + Mac CoreML/Xcode/iOS 验证 + Git 状态检查。

## 7. 新对话的启动指令

把下面这段发给新对话即可：

```text
继续 /Users/caoyuzhang/Desktop/MahjongVisionSync 的毕业设计开发。

必须使用已有的持久多 Agent 调度器：用户 -> 核心 Agent -> 固定成员 Agent；只有核心拥有管理工具。先阅读 docs/development-handoff.md，然后执行 codex-team status、codex-team tasks，并通过 codex-team chat 恢复已有核心线程。不要重新 init，不要删除 .codex-team 状态，不要重复派发已失败的同范围 Windows 训练环境审计；如需复核环境，由核心直接执行最小只读 SSH 探针。

Mac 是核心调度端；Windows 通过 ssh winpc 作为独立训练/构建节点，工作副本在 C:\\Users\\Administrator\\codex-workspaces\\MahjongVisionSync。不能把 iOS/Xcode/CoreML 构建或 CoreML 运行验证派给 Windows；Windows 负责 MCR 与 M.League Riichi 数据集预处理、训练、评估和 ONNX 等可移植模型导出。训练依赖安装和实际训练必须等数据集到位、依赖清单审查并获得用户授权后再执行。所有代码任务都要小批次验证、提交，并由核心集成。
```

## 8. 关键安全与运行要求

- 不在文档、提交或聊天中复制 SSH 私钥、口令、令牌或其他密钥。
- Windows 目前以 `Administrator` SSH 登录仅用于初始化；在开始长期自动化前，核心应规划专用的低权限构建账户。
- 远程训练或构建命令必须使用明确的工作目录，并输出命令、结果、提交 SHA、数据集版本、模型产物路径与风险。
- 安装软件、删除文件、覆盖远程分支、推送公开仓库或改变产品方向，必须先由核心向用户说明影响并获得授权。
