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
| `-AspectRatio` | `4:5` | 工作流默认画幅比例 |
| `-Quality` | `high` | 工作流默认清晰度/质量 |
| `-Resolution` | `2k` | 工作流默认分辨率 |
| `-PollDelays` | `60,15,15,30,30` | 查询等待节奏，总计 150 秒 |
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
- 多图按顺序传入 RunningHub 图片节点：第 1 张 -> `nodeId=2`，第 2 张 -> `nodeId=5`，第 3 张 -> `nodeId=6`，第 4 张 -> `nodeId=7`，第 5 张 -> `nodeId=8`，第 6 张 -> `nodeId=9`，第 7 张 -> `nodeId=11`，第 8 张 -> `nodeId=12`，第 9 张 -> `nodeId=14`，第 10 张 -> `nodeId=13`。字段名均为 `image`。
- 如果用户提供少于工作流可用图片节点数量，只传入实际提供的图片节点；未提供的图片节点不写入 `nodeInfoList`，保持空/未覆盖。
- 提示词传入文本节点：`nodeId=10`，字段名为 `编辑文本`。
- 生成主节点默认参数：`nodeId=1`，`resolution=2k`，`quality=high`，`aspectRatio=4:5`，`seed=0`。
- 用户给出产品图并要求“广告图/亚马逊图/英文输出”时，自行分析产品功能，写英文电商广告提示词。
- 如果用户指定文件名或路径，传 `-OutputPath`；脚本会自动创建父目录。
- 批量生成多张图时，最多同时提交 3 个 RunningHub I2I 任务。3 路并行已实测可用；默认按 3 个一组并行提交，超过 3 张时完成一批再继续下一批。
- 多任务并行时，每个任务都调用一次 `scripts/img2img.ps1`，为每张结果设置唯一 `-OutputPath`，不要让多个任务写同一个输出文件。
- 脚本默认会为输入图片创建本次任务专用临时副本再上传，避免 3 路并行时多个进程同时读取同一源图导致文件占用。
- 上传必须使用 `multipart/form-data` 的 `file` 字段；不要使用裸二进制 body。
- 任务查询使用 `/openapi/v2/query`，成功图片 URL 在 `results[0].url`。
- 若 150 秒仍未完成，不要重新提交同一任务；可先扩大 `-PollDelays` 重新运行或临时用任务 ID 查询同一任务。

## 网络与权限

RunningHub 是外部 API。若沙箱内出现 `Authentication failed`、TLS、DNS、连接失败、上传失败或下载失败，应按权限规则用同一命令请求联网执行权限后重试。

## API 常量

- Base URL: `https://www.runninghub.cn`
- Workflow ID: `2047956784060567554`
- Generation node: `nodeId=1`, `resolution=2k`, `quality=high`, `aspectRatio=4:5`, `seed=0`
- Prompt node: `nodeId=10`, `fieldName=编辑文本`
- Image nodes: `nodeId=2,5,6,7,8,9,11,12,14,13`, `fieldName=image`
- Upload: `POST /openapi/v2/media/upload/binary`
- Create: `POST /task/openapi/create`
- Query: `POST /openapi/v2/query`

API key 已在脚本默认参数中配置；只有用户明确要求轮换密钥时才改脚本。
