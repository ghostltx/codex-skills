---
name: openlux
description: 通过 OpenLux API（OpenAI Images 兼容）调用 gpt-image-2.5-sunburst-c 文生图、改图。用户要求画图、生成图片、改图时使用。
---

# OpenLux 绘图

## 连接信息
- Base URL：`https://api.openlux.ai/v1`
- 认证：`Authorization: Bearer <key>`，key 从环境变量 `openlux` 读取（兼容 `OPENLUX_KEY`）。**只检查是否存在，绝不打印、记录或写入文件。**
- 文生图：`POST /images/generations`（JSON）
- 改图：`POST /images/edits`（multipart；单图字段 `image`，多图字段 `image[]`，可选 `mask`）
- 官方文档：https://doc.openlux.ai/en/reference/v1/images/generations 、https://doc.openlux.ai/en/reference/v1/images/edits

## 脚本（只用 Python 标准库，Windows / macOS / Linux 通用）
```
python openlux_image.py --prompt "提示词"
python openlux_image.py --prompt-file prompt.txt --size 3840x2160
python openlux_image.py --prompt-file prompt.txt --size 2560x1440   # 2K 横版
python openlux_image.py --prompt-file prompt.txt --image ref.png            # 改图
python openlux_image.py --prompt-file prompt.txt --image a.png --image b.png --mask m.png
python openlux_image.py --prompt "test" --dry-run                           # 不发请求，只看参数和 key 是否存在
python openlux_image.py --prompt "test" --response-format b64_json      # 手动指定 Base64 返回
```
参数：`--model`（默认 `gpt-image-2.5-sunburst-c`；只有用户明确要求时切换 `gpt-image-2.6-sunburst-c`）、`--size`（默认 auto）、`--n`（默认 1）、`--quality`（默认 high）、`--output-format`（默认 png）、`--response-format`（默认 auto，可选 url / b64_json）、`--out-dir`（默认当前目录下 openlux-output）、`--timeout`（默认 900 秒）。

`auto` 模式下，2.5 默认使用 URL 并立即下载；2.6 默认使用 Base64，规避当前 2.6 返回 CDN URL 的 403 问题。输出：图片保存到 `<out-dir>/openlux_时间戳/image_1.png`（同一秒并发会自动加 `_2`、`_3` 后缀，不会互相覆盖），并打印 JSON：`mode`、`model`、`size`、`response_format`、`request_seconds`、`download_seconds`、`total_seconds`、`saved`、`usage`。

## 尺寸规则
- `auto`：文生图 2880x2880；改图按第一张参考图宽高比，在约 8.29MP（2880×2880）像素预算内计算。
- 像素预算为 `2880×2880 = 8,294,400`（约 830 万）像素，最长边不超过 3840。
- 1:1 → 2880x2880；16:9 → 3840x2160；9:16 → 2160x3840；4:9 → 1712x3840；3:4 → 2480x3312。
- 宽高必须是 16 的倍数，单边 ≤ 3840。
- 实测可用：2560x1440（2K 横版）、2880x2880、3840x2160、1424x3840、1712x3840。

## 规则
- 生成是付费的（2.5-c 约 0.0118/张，2.6-c 约 0.0147/张，按次计费），只在用户要求时调用，不为测试生成，失败不要自动重试。
- 请求可能需要 30 秒到几分钟。
- 报错时原样说明 HTTP 状态码和错误信息（不含 key）。
- `<lora:...>` 这类 Stable Diffusion 标签接口不认，脚本发送前会自动删掉。
- AI 生成的中文小字容易出错，含文字的图交付前要逐字校对。
