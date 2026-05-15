---
name: RH-GPT-IMAGE-2-T2I
description: RunningHub 文生图 Skill，通过 GPT Image 2.0 工作流生成图片并默认保存到桌面。支持文生图、生成图片、AI画图、runninghub、图片生成，可指定宽高比、种子和输出路径。
description_zh: RunningHub 文生图 Skill，生成图片并默认放到桌面
description_en: RunningHub Text-to-Image skill that saves generated images to the desktop by default
---

# RunningHub 文生图

用 RunningHub GPT Image 2.0 工作流生成图片。默认生成后下载到当前用户桌面。

## 快速使用

优先运行 bundled 脚本，不要手写 API 请求。默认使用前先让用户选择画幅比例和分辨率；如果用户已明确指定比例/分辨率，或明确说“自动选择/直接生成”，再直接执行：

```powershell
& "$env:USERPROFILE\.codex\skills\RH-GPT-IMAGE-2-T2I\scripts\generate_image.ps1" -Prompt "提示词" -AspectRatio "3:4"
```

常用参数：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-Prompt` | 必填 | 图片提示词，中文可直接传入 |
| `-AspectRatio` | `1:1` | `3:2`, `1:1`, `2:3`, `5:4`, `4:5`, `16:9`, `9:16`, `21:9`, `3:4`, `4:3` |
| `-Resolution` | `2k` | 生成分辨率，默认传入工作流节点 `resolution=2k` |
| `-Seed` | 随机 | 指定后便于复现 |
| `-OutputPath` | 桌面 `runninghub_t2i_时间戳.png` | 自定义保存位置 |
| `-PollDelays` | `30` 后每 `5` 秒查询一次，总计约 `200` 秒 | 快轮询：提交后 30 秒开始查，之后每 5 秒查一次；200 秒未出图则提示最后状态和 taskId |
| `-RequestRetries` | `3` | 创建任务、下载结果遇到网络 EOF/断连时的重试次数 |
| `-RetryDelaySeconds` | `8` | 网络重试和队列重试的等待秒数 |
| `-Interactive` | 关闭 | 手动运行脚本时用编号菜单选择比例和分辨率 |

示例：

```powershell
& "$env:USERPROFILE\.codex\skills\RH-GPT-IMAGE-2-T2I\scripts\generate_image.ps1" `
  -Prompt "竖版中式艺术海报，米白宣纸背景，大留白，黑色手写字" `
  -AspectRatio "3:4"
```

## 执行规则

- 默认保存到桌面；用户说“放桌面”时不需要额外复制。
- 默认先让用户选择参数：画幅比例从 `3:2`, `1:1`, `2:3`, `5:4`, `4:5`, `16:9`, `9:16`, `21:9`, `3:4`, `4:3` 中单选；分辨率从 `1k`, `2k` 中单选，默认推荐 `2k`。只有用户已明确指定比例/分辨率，或明确说“自动选择/直接生成/按默认生成”时，才跳过选择。
- 手动交互运行时使用 `-Interactive`，脚本会提供比例和分辨率编号菜单；自动任务运行时直接传 `-AspectRatio` 和 `-Resolution`。
- 如果用户指定文件名或路径，传 `-OutputPath`；脚本会自动创建父目录。
- 竖版海报优先用 `3:4` 或 `4:5`，电商/信息图竖版优先用 `4:5`，手机壁纸优先用 `9:16`，横版图优先用 `16:9`，超宽横幅优先用 `21:9`。
- 生成主节点默认参数包含 `resolution=2k`；除非用户明确要求低分辨率，不要省略或降为 `1k`。
- 脚本会提交任务、30 秒后开始查询，之后每 5 秒查询一次；任何任务一旦 `SUCCESS` 就立即下载图片。约 200 秒未出图时会输出 `TIMEOUT`、最后状态和 `TASK_ID`，可稍后补拉。
- 批量生成多张图时，最多同时提交 3 个 RunningHub T2I 任务。若 3 个任务同时提交时出现 `TASK_QUEUE_MAXED`、创建请求 EOF 或下载 EOF，优先使用 5-10 秒错峰提交同一批 3 个任务。
- 创建任务和下载结果已内置重试，默认最多 3 次，每次间隔 8 秒。
- 成功输出包含 `TASK_ID=...`、`STATUS=SUCCESS`、`OUTPUT_PATH=...`、`IMAGE_URL=...`，最终回复用户时给出本地路径。

## 网络与权限

RunningHub 是外部 API。若沙箱内出现 `Authentication failed`、TLS、DNS、连接失败或下载失败，应按权限规则用同一命令请求联网执行权限后重试。

## API 常量

- Base URL: `https://www.runninghub.cn`
- Workflow ID: `2047717286877863938`
- Generation node: `nodeId=1`, `resolution=2k`, `aspectRatio`, `seed`
- Create: `POST /task/openapi/create`
- Query: `POST /openapi/v2/query`

API key 已在脚本默认参数中配置；只有用户明确要求轮换密钥时才改脚本。
