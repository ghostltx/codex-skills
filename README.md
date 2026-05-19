# 个人 Codex Skills

这个仓库用于保存个人 Codex skills，并通过版本 Tag 支持回滚和跨设备同步。

## 版本说明

### v1.04

`v1.04` 将仓库 README 改为中文，并补齐历史版本说明的中文描述：

- 将仓库标题、简介和版本说明整体中文化。
- 中文化 `v1.03`、`v1.01`、`v1.0` 的历史版本说明。
- 保留必要的英文技术名词、模型名、平台名和脚本参数，例如 `Codex`、`GitHub`、`Tag`、`Release`、`-TagName`、`GH_TOKEN`。
- 该版本只调整文档展示，不改变任何 skill 行为或同步脚本逻辑。

简而言之，`v1.04` 让仓库主页 README 更适合中文阅读，同时保留技术名称的准确性。

### v1.03

`v1.03` 升级了个人 skills 同步流程，重点是加入版本化发布能力：

- 上传/同步时会创建版本 Tag、推送到 GitHub，并基于该 Tag 创建 GitHub Release。
- 下载/拉取时会先列出远端 Tag，并要求选择一个 Tag 版本后，再覆盖本地已跟踪的 skill 文件。
- 新增脚本参数：
  - `-TagName`：指定明确的版本 Tag。
  - `-ListTags`：列出远端 Tag，便于选择下载版本。
  - `-ReleaseTitle` 和 `-ReleaseNotes`：设置 GitHub Release 的标题和说明。
- 创建 Release 时优先使用 `gh`；如果本机没有 `gh`，则通过 `GH_TOKEN` 或 `GITHUB_TOKEN` 调用 GitHub API。
- 按 Tag 拉取时使用隔离的远端 Tag 引用，避免本地旧 Tag 与远端同名 Tag 冲突导致无法选择版本。

简而言之，`v1.03` 让 skills 同步具备版本意识：上传会变成带 Tag 的 Release，下载会变成明确选择版本后的恢复。

### v1.01

`v1.01` 基于 `v1.0`，包含一次更新提交：

- 提交：`cb3b57c` - `Update personal skills for v1.01`
- 变更文件：
  - `amazon-plus-1.0/SKILL.md`
  - `fantui/SKILL.md`
- Diff 规模：
  - `41` 行新增
  - `12` 行删除

#### amazon-plus-1.0

- 将生图路由从两种模式扩展为四种模式：
  - `A` = 内置 Image Gen
  - `B` = RunningHub RH-GPT-IMAGE-2-I2I
  - `C` = ZZ gpt-image-2 / T8Star
  - `D` = RunningHub GPT Image 2 Official Stable
- 增加对 `ZZ gpt-image-2` / `T8Star` 的明确支持。
- 增加对 RunningHub GPT Image 2 Official Stable 的明确支持。
- 更新分辨率路由规则：
  - `1K` 路由到模式 A
  - `2K` 默认路由到模式 B，除非明确选择模式 D
  - `4K` 路由到模式 D
  - `ZZ`、`gpt-image-2` 或 `T8Star` 路由到模式 C

#### fantui

- 将详情页图片默认比例从 `3:4` 改为 `1:1`。
- 新增必填的 `【亚马逊5大点】` 区块。
- 要求 10 屏详情页方案回应并视觉化亚马逊五点描述。
- 强化线稿约束措辞，要求提示词保留产品轮廓、比例和物理体积。

简而言之，`v1.01` 改进了 Amazon 图片生成在多供应商之间的路由，并让 Fantui 输出更适配 Amazon 方图和五点描述逻辑。

### v1.0

`v1.0` 是 `v1.01` 更新之前的基线上传版本。
