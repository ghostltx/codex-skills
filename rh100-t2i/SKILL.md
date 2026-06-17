---
name: rh100-t2i
description: Use this skill when the user wants to call RunningHub RH100 / enterprise text-to-image API endpoint rhart-image-n-g31-flash/text-to-image, including prompt-based image generation, task polling, result download, webhook notes, 100-concurrency guidance, or RH100-T2I-specific scripts. Supports 文生图, 文字生成图片, RunningHub 文生图, and nano-banana2 Gemini 3.1 Flash text-to-image requests.
---

# RH100-T2I

RunningHub enterprise text-to-image API helper for the `rhart-image-n-g31-flash/text-to-image` endpoint.

## Core Workflow

1. Submit a text-to-image task with `prompt`, `aspectRatio`, `resolution`, and enterprise shared `instanceType`.
2. Read `taskId` from the submission response.
3. Poll `POST https://www.runninghub.cn/openapi/v2/query` until `SUCCESS` or `FAILED`.
4. Download every `results[].url` immediately; result URLs expire in 24 hours.

## Script

Use the bundled script for one-off tasks. By default it submits only and exits, which keeps Codex streams short:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i\scripts\rh100_t2i.py `
  --prompt "一幅精美的明代国漫风格插画，一位穿着飞鱼服的锦衣卫站在古老城墙上，俯瞰京城夜景。" `
  --aspect-ratio "1:1" `
  --resolution "2k" `
  --instance-type "default" `
  --out-dir ".\outputs"
```

Only add `--wait` for quick manual tests. `--wait` defaults to a 60-second maximum foreground wait and should not be used for batches or long generations.

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i\scripts\rh100_t2i.py `
  --prompt "高端电商海报风格，一套户外庭院桌椅，白色背景，柔和自然光。" `
  --aspect-ratio "1:1" `
  --resolution "2k" `
  --wait `
  --out-dir "C:\Users\ghost\Desktop\rh100-t2i"
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
