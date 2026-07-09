---
name: 文生图
description: Use this skill when the user wants to call RunningHub RH100 / enterprise text-to-image API endpoint rhart-image-n-g31-flash/text-to-image, including prompt-based image generation, task polling, result download, webhook notes, 100-concurrency guidance, or 文生图-specific scripts. Supports 文生图, 文字生成图片, RunningHub 文生图, and nano-banana2 Gemini 3.1 Flash text-to-image requests.
---

# 文生图

RunningHub enterprise text-to-image API helper for the `rhart-image-n-g31-flash/text-to-image` endpoint.

## Default Fast Path

When the user provides a prompt and asks for text-to-image generation, do not spend time on prompt analysis, planning, or extended reasoning unless the user explicitly asks for prompt optimization, variants, or strategy.

Default action:

1. Run the bundled script immediately with the provided prompt.
2. Submit the task and print/report the `taskId` and status.
3. If the submit response already includes `results[].url`, download the files immediately.
4. If the task is asynchronous, keep a short foreground poll by default so completed images are downloaded.
5. Stop polling only after success/download, failure, or the configured foreground wait limit.

Use this minimal command shape by default:

```powershell
python C:\Users\ghost\.codex\skills\文生图\scripts\rh100_t2i.py `
  --prompt "<USER_PROMPT>" `
  --aspect-ratio "1:1" `
  --resolution "2k" `
  --instance-type "default" `
  --wait `
  --poll-seconds 10 `
  --max-wait-seconds 120 `
  --out-dir ".\outputs"
```

Use `--no-wait` only when the user explicitly asks for submit-only behavior. Only rewrite or enrich the prompt when the user asks for prompt engineering.

## Core Workflow

1. Submit a text-to-image task with `prompt`, `aspectRatio`, `resolution`, and enterprise shared `instanceType`.
2. Read `taskId` from the submission response.
3. Poll `POST https://www.runninghub.cn/openapi/v2/query` by default for a short foreground window so result URLs can be downloaded.
4. For automatic no-poll result delivery, pass `webhookUrl`; RunningHub will POST the final task payload to that endpoint when supported.
5. Download every `results[].url` immediately; result URLs expire in 24 hours.

## Script

Use the bundled script for one-off tasks. By default, keep a short poll so the generated image can be downloaded:

```powershell
python C:\Users\ghost\.codex\skills\文生图\scripts\rh100_t2i.py `
  --prompt "一幅精美的明代国漫风格插画，一位穿着飞鱼服的锦衣卫站在古老城墙上，俯瞰京城夜景。" `
  --aspect-ratio "1:1" `
  --resolution "2k" `
  --instance-type "default" `
  --wait `
  --poll-seconds 10 `
  --max-wait-seconds 120 `
  --out-dir ".\outputs"
```

If RunningHub returns a completed submit response with `results[].url`, the script downloads the files immediately. Most RH100 image tasks are asynchronous, so normal submit responses are `QUEUED` or `RUNNING` with `results: null`; keep `--wait` unless the user explicitly requests submit-only behavior.

Use `--no-wait` for submit-only mode. Poll every 10 seconds by default with `--poll-seconds 10`. `--wait` defaults to a 120-second maximum foreground wait unless `--max-wait-seconds` is provided.

```powershell
python C:\Users\ghost\.codex\skills\文生图\scripts\rh100_t2i.py `
  --prompt "高端电商海报风格，一套户外庭院桌椅，白色背景，柔和自然光。" `
  --aspect-ratio "1:1" `
  --resolution "2k" `
  --wait `
  --out-dir "C:\Users\ghost\Desktop\文生图"
```

The script does not contain a built-in API key. Set `RUNNINGHUB_API_KEY` before use. For a dedicated key, set `RH100_T2I_API_KEY`; it takes precedence over `RUNNINGHUB_API_KEY`. `--api-key` is available only for one-off tests and should not be saved in prompts or files.

## API Facts

- Submit endpoint: `POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/text-to-image`
- Query endpoint: `POST https://www.runninghub.cn/openapi/v2/query`
- API doc page: `https://www.runninghub.cn/call-api/api-detail/2027192837726294017`
- Model display name in local RunningHub capability data: `全能图片V2-文生图-低价渠道版`
- `prompt`: required, string, up to 20000 characters when documented
- `aspectRatio`: optional, script default `1:1`
- `resolution`: required, enum `1k`, `2k`, `4k`, script default `2k`
- `webhookUrl`: optional
- Enterprise shared key usage requires `instanceType`: `default` for Standard, `plus` for Plus.
- Lite uses system auto-scheduling; omit `instanceType`.
- Generated result URLs expire in 24 hours.

Aspect ratio enum:

```text
1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, 5:4, 4:5,
21:9, 1:4, 4:1, 1:8, 8:1
```

## Batch Cadence

For many prompts, submit tasks first, then poll in short windows rather than keeping one long foreground stream open. Recommended Codex cadence:

1. Submit all tasks.
2. Wait about 60 seconds before the first poll.
3. Run up to 2 additional short polls at about 30-second intervals.
4. Stop after these 3 poll checks total if some tasks are still running.
5. Report completed downloads, remaining task count, job file path, elapsed time, and usable cost fields.

## Reporting

When tasks finish, report:

- Download directory.
- Wall-clock elapsed time.
- `usage.thirdPartyConsumeMoney` when present.
- `usage.consumeMoney`, `usage.consumeCoins`, and `usage.taskCostTime` only when useful or explicitly requested.

If a field is absent or `null`, show `N/A` in raw summaries rather than guessing. In normal user-facing updates, omit noisy `N/A` billing fields when a usable cost field is present.

## References

Read `references/api.md` when field details, response examples, webhook behavior, or integration notes are needed.
