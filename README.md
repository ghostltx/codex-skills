# 个人 Codex Skills

这个仓库用于保存个人 Codex skills，并通过版本 Tag 支持回滚和跨设备同步。

## 版本说明

### v1.26

`v1.26` 发布了 `RH100` 的稳定批量执行和成本汇总升级，并以当前大写 `RH100/` 目录作为仓库里的唯一最新 RH100 skill：

- `RH100/scripts/rh100.py` 默认改为提交即返回，只有显式加 `--wait` 才进行前台短轮询，避免单任务调用长时间占用 Codex 会话。
- `RH100/scripts/rh100_batch.py` 默认轮询窗口收紧到 60 秒，长任务通过同一个 `rh100_jobs.json` 继续 `poll`，不重复提交任务。
- 批量轮询会在窗口结束前安全退出并写入日志，减少长时间前台运行造成的流中断风险。
- 新增 `RH100_HTTP_TIMEOUT_SECONDS` 和 `RH100_DOWNLOAD_TIMEOUT_SECONDS` 环境变量，可分别调整 API 请求和下载超时。
- `RH100/scripts/rh100_batch.py` 新增 `wall_time`，根据最早提交时间和最晚完成时间计算真实等待耗时。
- 新增 `third_party_money` 汇总，读取 RunningHub 返回的 `usage.thirdPartyConsumeMoney`，避免 `consumeMoney` / `consumeCoins` 为空时漏报可用费用。
- 单任务日志的 `usage` 输出也会显示 `third_party_money`，便于排查每张图的实际消耗。
- 金额输出统一使用 ASCII 的 `CNY` 前缀，避免 Windows PowerShell/GBK 控制台打印 `¥` 时出现编码错误。
- RH100 最终报告规则升级：必须报告墙钟生成时间、接口 `taskCostTime`、`consumeMoney`、`consumeCoins`，以及 `thirdPartyConsumeMoney` 汇总；当主金额字段为 `N/A` 时，也保留第三方金额这个可用成本信号。
- `amazon-recolor` 删除 T8Star / `gpt-image-2-all` / NewAPI 路由说明，避免继续把已停用路线作为默认或备选；外部批量路线改为按显式 RunningHub/RH100 请求触发。
- 仓库中不再保留或发布小写 `rh100` 入口；以后以 `RH100/` 为最新版本和同步对象。

简而言之，`v1.26` 让 RH100 更适合在 Codex 里做高并发图生图：短前台、可恢复、可追踪，最终汇报能稳定写成“总时长多少、共消耗多少钱”。

### v1.25

`v1.25` 清理了个人 skills 仓库中不再需要的 NewAPI、ZZ gpt-image-2 和通用 RunningHub 辅助 skill：

- 删除 `new-api-rim-gpt-image-2-only-1k`。
- 删除 `NEWAPI-TEST`。
- 删除 `runninghub-generic-i2i`。
- 删除 `runninghub-generic-t2i`。
- 删除 `runninghub-openapi`。
- 删除 `zz-gpt-image2-i2i`。
- 删除 `zz-gpt-image2-T2I`。
- 同步从 `.gitignore` 白名单移除这些目录，避免后续重新被仓库跟踪。

简而言之，`v1.25` 精简仓库，只保留当前仍在使用的个人 skills，减少无用文件和重复工具链。

### v1.24

`v1.24` 新增并发布了 `RH100` skill，用于 RunningHub 企业级 `rhart-image-n-g31-flash/image-to-image` 批量图生图工作流：

- 将 `RH100/` 加入仓库白名单，纳入个人 skills 同步和版本管理。
- 新增前台单任务脚本 `RH100/scripts/rh100.py`，支持本地图片上传、任务提交、轮询和结果下载。
- 新增静默批量脚本 `RH100/scripts/rh100_batch.py`，支持多图、多变体、高并发提交，保存 `rh100_jobs.json`，可断点续查和下载。
- 批量脚本默认减少终端刷屏，避免 Codex 会话流在高并发任务中被长 URL 和频繁状态输出冲断。
- 任务结束后汇总状态、累计用时、消耗金额和消耗 coins；接口返回空值时显示 `N/A`。
- 明确 `instanceType` 计费和机型选择：Lite 省略参数、Standard 使用 `default`、Plus 使用 `plus`。
- 所有脚本均改为通过 `RUNNINGHUB_API_KEY` 环境变量或显式 `--api-key` 获取密钥，不提交测试 Key。
- 更新 `sync-skills-git` 说明：以后说“发布”即表示更新 README、提交推送、创建并推送版本 Tag、创建 GitHub Release 的完整发布流程。

简而言之，`v1.24` 把 RH100 高并发改色/图生图流程做成可同步、可恢复、低刷屏的个人 skill，并把“发布”这个口令固定为完整版本发布流程。

### v1.23

`v1.23` 更新了 `runninghub-openapi` 的下游调用说明，把本次实测通过的 RunningHub 双参考图 image-to-image 工作流写成固定用法：

- 明确 image-to-image 修图/重生成时，第一张图作为构图和排版主参考，后续图片作为结构、颜色或风格参考。
- 要求下游 skill 显式传入 `aspectRatio` 和 `resolution` 参数，例如 `aspectRatio=1:1`、`resolution=2k`，避免电商方图被接口默认值影响。
- 强化任务完成证据：成功后应向用户报告 `TASK_ID:`、`OUTPUT_FILE:`、`COST:` 和 `ELAPSED:`。
- 本次已用 `rhart-image-n-g31-flash/image-to-image` 完成双图参考重生成实测，输出 `2048x2048` 方图，并成功回传费用和耗时。

简而言之，`v1.23` 让 `runninghub-openapi` 更适合被其他电商图片 skill 复用：能稳定表达多参考图、固定比例分辨率，并保留可追踪的任务结果。

### v1.22

`v1.22` 修正并强化了 `amazon-recolor-v1.03` 的 T8Star 改色执行链路，让默认行为和实测结果保持一致：

- 默认模型统一改回已实测稳定的 `gpt-image-2-all`，包括 `SKILL.md`、agent 元数据和内置 runner。
- API key 只读取 `T8STAR_API_KEY` 或显式 `-ApiKey` 参数，不再读取 `NEWAPI_API_KEY`，避免变量名混淆。
- 新增可随 skill 分发的 `amazon-recolor/scripts/run_amazon_recolor_gptimage2.ps1`，替代依赖用户桌面私有路径的本地脚本。
- 新 runner 默认接口为 `https://ai.t8star.org/v1`、模型为 `gpt-image-2-all`，`-ApiKey` 默认留空；如果没有环境变量，会在运行时提示输入 key。
- 参考图目录从固定 `颜色\N.jpg` 改为可配置 `-ReferenceDir`，也支持直接传 `-ReferencePaths`。
- 未指定 `-OutputDir` 时，在当前运行目录创建颜色名文件夹，例如 `brown`，不再强绑到源图目录。
- 已用 `1+1` 图片编辑任务完成连通测试，`gpt-image-2-all` 成功返回并保存改色结果。

简而言之，`v1.22` 把 Amazon 改色 runner 做成可分发、可配置、不含密钥的版本，并把默认模型恢复为 `gpt-image-2-all`。

### v1.21

`v1.21` 发布了 `amazon-recolor-v1.03`，把 Amazon 改色批处理从“只按编号跑图”升级为更贴近实际工作流的版本：

- 新增 `+M` 简写规则：例如 `+1` 会复用上一批源图和源图数量，只替换新的颜色/材质参考图。
- 明确要求先用视觉/AI 判断参考图里的产品颜色，再把英文颜色名传给本地 runner。
- 未指定输出目录时，默认用颜色英文命名文件夹，例如 `gray`、`blue`、`brown`，不再用参考图编号命名。
- 本地 runner 示例支持传入 `-SourceDir`、显式 `-ReferencePaths`、`-ColorName` 和 `-TargetFinish`，适配参考图编号不连续或用户单独追加参考图的场景。
- `amazon-recolor/scripts/run-gpt-image2-recolor.ps1` 支持 `+M` 解析，并在生成结束后输出 `ELAPSED_SECONDS` 和 `ELAPSED`。
- 最终汇报要求包含生成耗时，方便比较不同批次和不同颜色的生成效率。

简而言之，`v1.21` 让 Amazon 改色流程支持“继续上一批换一个颜色参考图”，并自动用 AI 判断的颜色名管理输出目录和耗时结果。

### v1.20

`v1.20` 发布了 `amazon-recolor-v1.02`，把 Amazon 改色套图里的 `N+M` 规则固定成可执行契约：

- `N+M` 中 `N` 代表前 N 张源图，也是本次生成并发数。
- `M` 代表最后 M 张颜色/材质参考图，只用于参考产品颜色和材质，不复制构图、背景或角度。
- 默认 T8Star 路线更新为 `gpt-image-2`，按源图比例选择合法输出尺寸，减少方图强制裁切。
- 新增 `amazon-recolor/scripts/run-gpt-image2-recolor.ps1`，可直接传入 `-Count "N+M"`、图片路径数组和输出目录批量并发改色。
- runner 默认并发为 `N`，硬上限 10；例如 `8+1` 会并发 8 张，`10+2` 会并发 10 张。
- 发布版脚本保留 `-ApiKey` 参数和 `T8STAR_API_KEY` / `NEWAPI_API_KEY` 环境变量读取，不把真实密钥提交到仓库。

简而言之，`v1.20` 让 Amazon 改色从“理解 N+M”升级成“按 N+M 自动分源图、分参考图、按 N 并发生成”的稳定流程。

### v1.19

`v1.19` 发布了 `amazon-recolor-v1.01`，把 Amazon 改色 workflow 的默认生图路线切到已经实测可用的 `gpt-image-2-all`：

- `amazon-recolor` 的内部 skill 名称更新为 `amazon-recolor-v1.01`，显示名更新为 `Amazon Recolor v1.01`。
- 默认生图路线改为 T8Star OpenAI-compatible API，模型固定为 `gpt-image-2-all`。
- 默认尺寸固定为 `1254x1254`、`1:1`，适配 Amazon 方图改色输出。
- 默认最多 10 张源图并行处理，方便 `7+1`、`9+2`、`10+2` 等套图改色任务批量生成。
- 保留显式覆盖规则：只有用户明确要求内置 `imagegen` 或 RunningHub 时才切换路线。

简而言之，`v1.19` 让 Amazon 改色 skill 进入 `v1.01`，默认使用 `gpt-image-2-all` 进行 10 并行方图生图。

### v1.18

`v1.18` 同时发布了 `amazon-images-reviews` 的父/子 ASIN 采集升级，并补充说明 `baokuan-tupian` 已作为个人 skill 白名单项保存在仓库中：

- `amazon-images-reviews` 新增 Parent ASIN / Variant Workflow，可用父 ASIN 文件夹承载多个子 ASIN。
- 每个子 ASIN 会独立生成 `main-images`、`aplus-images` 和评论 Excel，避免不同颜色或变体素材混在一起。
- `collect_asin_package.py` 新增 `--parent-asin` 和可重复传入的 `--child-asin` 参数，用于批量采集已知子 ASIN。
- 图片下载增加对 `IncompleteRead`、`RemoteDisconnected` 和单张图片失败的容错，降低 Amazon 图片偶发断连导致整批中断的概率。
- `baokuan-tupian` 已明确保留在 `.gitignore` 白名单中，仓库会同步 `baokuan-tupian/SKILL.md` 和 `baokuan-tupian/agents/openai.yaml`，方便在 GitHub 页面和跨设备同步时直接看到。

简而言之，`v1.18` 让 Amazon 变体资料包采集更稳、更清晰，也把“爆款图片”skill 的仓库可见性写进版本说明。

### v1.17

`v1.17` 进一步强化了 `sync-skills-git` 的发布硬规则，专门防止“只上传文件夹、但忘记 README / Tag / Release”的情况：

- 明确用户说 `同步`、`推送`、`上传`、`提交 skill` 时，都必须按完整发布流程执行。
- 新增 Mandatory Publish Checklist，要求提交文件、更新 README、创建 Tag、推送 Tag、创建 Release、填写 Release 更新说明全部完成。
- 明确写入“Tag 不等于 Release”，只推 Tag 不算完成。
- Push Workflow 中把更新 `README.md` 放到 staging 前，要求说明哪个 skill 改了、实际效果是什么。
- Release 正文必须包含有用更新说明，不能是空白或默认占位内容。

简而言之，`v1.17` 把你要求的“上传 skill 时必须带版本和更新说明”写成硬性检查清单。

### v1.16

`v1.16` 是版本说明补丁，补齐了 GitHub README 和 Release 页面里缺失的 `v1.14` / `v1.15` 更新内容：

- README 新增 `v1.14` 的 `NEWAPI-TEST` 说明。
- README 新增 `v1.15` 的 `sync-skills-git` 发布流程修复说明。
- 更新 `v1.14` 和 `v1.15` 的 GitHub Release 正文。
- 新建 `v1.16` Release，记录这次文档补丁。

简而言之，`v1.16` 修复“有 Tag / Release，但主页看不到更新内容”的问题。

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
