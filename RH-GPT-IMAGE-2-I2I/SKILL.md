---
name: RH-GPT-IMAGE-2-I2I
description: RunningHub 图生图 Skill，通过 GPT Image 2.0 工作流基于 1-10 张本地参考图片生成新图片并默认保存到桌面。支持图生图、图片生成图片、以图生图、风格转换、角色参考、多图产品参考、图片参考，可指定提示词和输出路径。
description_zh: RunningHub 图生图 Skill，基于本地图片生成并默认放到桌面
description_en: RunningHub image-to-image skill that saves generated images to the desktop by default
---

# RunningHub 图生图

用 RunningHub GPT Image 2.0 工作流基于 1-10 张本地图片生成新图。默认生成后下载到当前用户桌面。这个 skill 只有一个执行入口：`scripts/img2img.ps1`。

## 快速使用

优先运行 bundled 脚本，不要手写 API 请求：

```powershell
& "C:\Users\ghost\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\img2img.ps1" `
  -ImagePaths "C:\path\to\front.png","C:\path\to\side.png" `
  -Prompt "English or Chinese prompt"
```

兼容旧单图写法：

```powershell
& "C:\Users\ghost\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\img2img.ps1" `
  -ImagePath "C:\path\to\input.png" `
  -Prompt "English or Chinese prompt"
```

常用参数：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-ImagePaths` | 必填，或使用 `-ImagePath` | 1-10 张本地图片路径，支持 `.png`, `.jpg`, `.jpeg`, `.webp` |
| `-ImagePath` | 兼容旧参数 | 单张本地图片路径；新任务优先使用 `-ImagePaths` |
| `-Prompt` | 必填 | 图生图提示词 |
| `-OutputPath` | 桌面 `runninghub_i2i_时间戳.png` | 自定义保存位置 |
| `-AspectRatio` | `4:5` | `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9` |
| `-Quality` | 空/`medium` | 默认 1K 工作流不传；`2k`/`4k` Official Stable 工作流支持 `low`, `medium`, `high`，未指定时用 `medium` |
| `-Resolution` | `1k` | 默认走 1K 工作流；用户明确指定 `2k` 或 `4k` 时走 Official Stable 工作流 |
| `-Seed` | `0` | 传入生成主节点；`0` 表示沿用工作流默认/随机逻辑 |
| `-GenerationNodeId` | 自动 | 1K 工作流为 `15`；Official Stable 工作流为 `1` |
| `-PollDelays` | `60,30,30,60,60,60,60,60,60` | 查询等待节奏，总计 480 秒 |
| `-MaxUploadBytes` | `4194304` | 单张参考图超过该大小时，先在临时目录压缩为上传用 JPG |
| `-MaxUploadEdge` | `2048` | 上传用 JPG 的最长边上限 |
| `-JpegQuality` | `90` | 上传用 JPG 质量 |
| `-RequestRetries` | `3` | 上传、创建任务、下载结果遇到网络 EOF/断连时的重试次数 |
| `-RetryDelaySeconds` | `8` | 网络重试和队列重试的等待秒数 |
| `-DisableTempCopies` | 关闭 | 默认先复制临时参考图再上传；只有调试时才关闭 |

成功输出包含：

```text
TASK_ID=...
STATUS=SUCCESS
OUTPUT_PATH=...
IMAGE_URL=...
```

## 执行规则

- 默认保存到桌面；用户说“放桌面”时不需要额外复制。
- 用户只给聊天附件时，若没有可上传路径，先在桌面/图片/下载等常见目录查找匹配图片；能合理确认就直接用本地路径，不能确认再问路径。
- 支持 1-10 张参考图。多图产品参考时，第 1 张作为主身份参考，后续图片作为角度、细节、包装、尺寸、材质、结构参考。
- 默认分辨率为 `1k`，走 1K I2I 工作流 `workflowId=2047956784060567554`；除非用户明确写 `2k` 或 `4k`，不要自动切到高分工作流。
- 用户明确写 `2k` 或 `4k` 时，走 Official Stable I2I 工作流 `workflowId=2052988540669177857`，支持 `quality=low|medium|high`；如果用户未指定 quality，默认用 `medium`。
- 画幅比例支持：`1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`。
- 1K 工作流图片节点顺序：第 1 张 -> `nodeId=2`，第 2 张 -> `nodeId=5`，第 3 张 -> `nodeId=6`，第 4 张 -> `nodeId=7`，第 5 张 -> `nodeId=8`，第 6 张 -> `nodeId=11`，第 7 张 -> `nodeId=9`，第 8 张 -> `nodeId=12`，第 9 张 -> `nodeId=14`，第 10 张 -> `nodeId=13`。字段名均为 `image`。
- Official Stable 工作流图片节点顺序：第 1 张 -> `nodeId=3`，第 2 张 -> `nodeId=4`，第 3 张 -> `nodeId=5`，第 4 张 -> `nodeId=6`，第 5 张 -> `nodeId=7`，第 6 张 -> `nodeId=9`，第 7 张 -> `nodeId=10`，第 8 张 -> `nodeId=11`，第 9 张 -> `nodeId=12`，第 10 张 -> `nodeId=8`。字段名均为 `image`。
- 如果用户提供少于工作流可用图片节点数量，实际提供的图片节点传入上传后的图片 URL；未使用的默认 `example.png` 图片节点必须显式传空字符串，避免默认参考图参与生成。
- 1K 工作流提示词传入文本节点：`nodeId=10`，字段名为 `编辑文本`；生成主节点默认参数：`nodeId=15`，`resolution=1k`，`aspectRatio=4:5`，`seed=0`，不传 `quality`。
- Official Stable 工作流提示词传入文本节点：`nodeId=13`，字段名为 `编辑文本`；生成主节点默认参数：`nodeId=1`，`resolution=2k/4k`，`quality=medium` 或用户指定值，`aspectRatio=4:5`，`seed=0`。
- 用户给出产品图并要求“广告图/亚马逊图/英文输出”时，自行分析产品功能，写英文电商广告提示词。
- 如果用户指定文件名或路径，传 `-OutputPath`；脚本会自动创建父目录。
- 批量生成多张图时，最多同时提交 3 个 RunningHub I2I 任务。3 路并行已实测可用；默认按 3 个一组并行提交，超过 3 张时完成一批再继续下一批。
- 若 3 个任务同时提交时出现 `TASK_QUEUE_MAXED`、创建请求 EOF 或下载 EOF，优先使用 5-10 秒错峰提交同一批 3 个任务。不要立刻判定工作流失败。
- 多任务并行时，每个任务都调用一次 `scripts/img2img.ps1`，为每张结果设置唯一 `-OutputPath`，不要让多个任务写同一个输出文件。
- 脚本默认会为输入图片创建本次任务专用临时副本再上传，避免 3 路并行时多个进程同时读取同一源图导致文件占用。
- 大 PNG 或大尺寸参考图上传前会自动准备临时 JPG 上传副本，默认超过 4MB 时压缩到最长边 2048px、质量 90。原图不会被修改。
- 上传必须使用 `multipart/form-data` 的 `file` 字段；不要使用裸二进制 body。
- 任务查询使用 `/openapi/v2/query`，成功图片 URL 在 `results[0].url`。
- 若轮询结束仍未完成，不要重新提交同一任务；可先扩大 `-PollDelays` 重新运行或临时用任务 ID 查询同一任务。

## 网络与权限

RunningHub 是外部 API。若沙箱内出现 `Authentication failed`、TLS、DNS、连接失败、上传失败或下载失败，应按权限规则用同一命令请求联网执行权限后重试。

## API 常量

- Base URL: `https://www.runninghub.cn`
- Default 1K Workflow ID: `2047956784060567554`
- Default 1K generation node: `nodeId=15`, `resolution=1k`, `aspectRatio=4:5`, `seed=0`, no `quality`
- Default 1K prompt node: `nodeId=10`, `fieldName=编辑文本`
- Default 1K image nodes: `nodeId=2,5,6,7,8,11,9,12,14,13`, `fieldName=image`
- Official Stable Workflow ID: `2052988540669177857`
- Official Stable generation node: `nodeId=1`, `resolution=2k|4k`, `quality=low|medium|high`, `aspectRatio=4:5`, `seed=0`
- Official Stable prompt node: `nodeId=13`, `fieldName=编辑文本`
- Official Stable image nodes: `nodeId=3,4,5,6,7,9,10,11,12,8`, `fieldName=image`
- Upload: `POST /openapi/v2/media/upload/binary`
- Create: `POST /task/openapi/create`
- Query: `POST /openapi/v2/query`

API key 已在脚本默认参数中配置；只有用户明确要求轮换密钥时才改脚本。
