# 个人 Codex Skills

这个仓库用于保存个人 Codex skills，并通过版本 Tag 支持回滚和跨设备同步。

## 版本说明

### v1.07

`v1.07` 修正了 `v1.06` 的同步范围问题，让仓库重新回到“只保存个人自建 skill”的边界：

- 从 Git 跟踪中移除了误上传的 OMX / 系统类 skill，例如 `analyze`、`team`、`creator-image2ppt` 等。
- 保留本地这些 skill 文件，不删除本机可用能力，只是不再纳入 `ghostltx/codex-skills` 仓库。
- 恢复 `.gitignore` 白名单，只保留个人仓库需要同步的 skill。
- 修正 `sync-skills-git` 规则：普通“同步”不再自动扫描所有包含 `SKILL.md` 的本地目录并加入白名单。
- 保留 `sync-skills-git` 的版本发布改进：默认使用递增的 `v1.xx` Tag，并可用 Git Credential Manager 凭据创建 Release。

简而言之，`v1.07` 是一次边界修复：仓库只同步个人 skill，不同步安装进本机的系统/OMX skill。

### v1.06

`v1.06` 尝试增强同步流程，但同步范围过宽：

- 修改 `sync-skills-git`，让默认同步使用 `v1.xx` 递增版本 Tag，而不是时间戳 Tag。
- 增加使用 Git Credential Manager 凭据创建 GitHub Release 的能力，解决没有 `gh` 或环境变量 token 时无法创建 Release 的问题。
- 误把所有本地包含 `SKILL.md` 的 ignored 目录自动加入 `.gitignore` 白名单，导致一批非个人 skill 被上传到仓库。

简而言之，`v1.06` 的版本发布方向是对的，但自动白名单规则过宽，已在 `v1.07` 修正。

### v1.05

`v1.05` 增加了 Amazon 产品图片提取相关能力，并补齐同步仓库中缺失的个人 skill：

- 新增 `amazon-images-reviews` skill。
- 支持从 Amazon 商品链接提取当前变体主图。
- 支持从页面 A+ 内容区域提取大尺寸 `premium-aplus` 图片。
- 明确 A+ 过滤规则：优先 `id="aplus"` 容器，保留 `premium-aplus` 大图，排除 `brand-story` / `apm-brand-story`。
- 要求产品图片目录只保存最终图片；manifest、链接表等中间文件如果必须生成，应放入临时目录。

简而言之，`v1.05` 让仓库包含 Amazon 主图和 A+ 图片提取 workflow。

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
