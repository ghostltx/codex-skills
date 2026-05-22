# 个人 Codex Skills

这个仓库用于保存个人 Codex skills，并通过版本 Tag 支持回滚和跨设备同步。

## 版本说明

### v1.15

`v1.15` 更新了 `sync-skills-git` 的同步发布流程，防止只推送代码但漏掉版本发布：

- 明确 `同步` 必须完成 commit、push、创建并推送 Tag、创建 GitHub Release 的完整流程。
- 当本地仓库太脏、需要改用临时干净 clone 推送时，也必须补齐 Tag 和 Release，不能只推 `main`。
- 拉取覆盖前必须先列出远端 Tags，让用户选择具体版本后再覆盖本地。
- 脚本支持 `-TagName`、`-ListTags`、`-ReleaseTitle`、`-ReleaseNotes`，方便指定版本和发布说明。
- 如果 GitHub Release 创建失败，必须明确报告是缺少 `gh`、`GH_TOKEN` 或 `GITHUB_TOKEN` 等阻塞原因。

简而言之，`v1.15` 把“同步后必须发布版本说明”写进规则和脚本，避免再出现只有 Tag 没有 Release 的情况。

### v1.14

`v1.14` 新增了 `NEWAPI-TEST` skill，用于测试 NewAPI key 能访问哪些模型：

- 默认测试地址为 `http://64.186.244.43:12001/v1`，API key 由用户每次临时提供，不写入仓库。
- 自动拉取 `/models` 模型列表，并逐个测试 `/responses` 是否可用于新版 Codex。
- 额外测试 `/chat/completions`，列出“普通可连通并能返回内容”的模型。
- 输出两张表：Codex 可用模型表，以及普通连通可返回模型表。
- 适合快速判断某个分组 key 是否能配置到 Codex，或者只能用于 Chat Completions 客户端。

简而言之，`v1.14` 把 NewAPI 模型连通性和 Codex 兼容性检测做成了可复用 skill。

### v1.13

`v1.13` 新增了 `故事板` skill，用于把产品图片或产品概念整理成 15 秒 6 宫格广告故事板提示词：

- 默认输出中文版和英文版各一套完整故事板提示词。
- 固定 15 秒短视频节奏，6 个分镜面板，每格包含画面、镜头、画面文字和转场。
- 保留产品概念、整体情绪、目标人群、色彩、灯光、材质重点和底部时间轴。
- 适合根据用户图片生成品牌广告感的商业 storyboard，不再只输出简单时间表。

简而言之，`v1.13` 把“15 秒 6 宫格中英文广告故事板”做成可复用 skill。

### v1.12

`v1.12` 更新了 `amazon-images-reviews` 的用户可见进度回复规则：

- 当触发 `Amazon Images + Reviews` skill 时，第一句进度回复结尾固定追加 `👌月婷请稍等⏳`。
- 该规则用于让 ASIN 采集任务开始时的提示语保持一致。

简而言之，`v1.12` 增加了 Amazon 图片与评论采集 skill 的固定开场提示。

### v1.11

`v1.11` 修正了 `amazon-images-reviews` 的 A+ 图片筛选规则：

- 明确 A+ 只保留横向大图，宽度必须大于 `1000px`。
- 将典型 A+ 尺寸 `1460x600` 写入 skill 规则。
- 脚本按图片真实尺寸过滤，排除小图、缩略图、图标和方图。
- 新增图片下载重试，降低 Amazon 图片偶发 SSL 断连导致采集中断的概率。

简而言之，`v1.11` 把 A+ 下载规则收紧为“只要横向大图，不要小图和方图”。

### v1.10

`v1.10` 升级了 `amazon-images-reviews` 的 ASIN 一键采集能力：

- 支持用户只提供 ASIN，即可在桌面创建同名文件夹。
- 新增 `collect_asin_package.py`，自动下载当前变体主图到 `main-images`。
- 自动提取并下载 A+ / Enhanced Brand Content 图片到 `aplus-images`。
- 集成 SellerSprite MCP 评论拉取，导出完整评论 Excel 到 `<ASIN>-reviews.xlsx`。
- 生成 `<ASIN>-manifest.json`，记录主图、A+ 图片、评论文件、数量和错误信息。
- 保留旧的 `extract_amazon.py`，用于只下载主图或嵌入式评论的轻量场景。

简而言之，`v1.10` 让 Amazon ASIN 采集从“单项图片下载”升级为“主图 + A+ + 评论 Excel”的桌面资料包。

### v1.09

`v1.09` 将 README 更新要求写入 `sync-skills-git` 的同步规则：

- 明确规定更新 skill、同步规则或仓库行为并发布版本时，必须同步更新 `README.md` 的版本说明。
- 只有在用户明确要求不更新 README 时，才可以跳过版本说明。
- Push 流程中新增 README 检查步骤，要求在 staging 前补齐下一版 `v1.xx` 的更新内容。

简而言之，`v1.09` 让“同步时 README 必须说明更新内容”成为固定规则。

### v1.08

`v1.08` 补齐了近期版本的 README 说明：

- 补写 `v1.05` 的 Amazon 主图和 A+ 图片提取能力说明。
- 补写 `v1.06` 的同步脚本增强和误上传问题说明。
- 补写 `v1.07` 的个人仓库边界修复说明。

简而言之，`v1.08` 修复了 release 已发布但 README 没解释更新内容的问题。

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
