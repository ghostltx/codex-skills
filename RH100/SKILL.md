---
name: rh100
description: Use this skill when the user wants to call or integrate the RunningHub enterprise image-to-image OpenAPI endpoint rhart-image-n-g31-flash/image-to-image, including local image upload, public image URL submission, task polling, result download, webhook notes, 100-concurrency guidance, or RH100-specific scripts.
---

# RH100

RunningHub enterprise image-to-image API helper for the `rhart-image-n-g31-flash/image-to-image` endpoint.

## When To Use

Use this skill when the user mentions RH100, RunningHub enterprise API, the 100-concurrency image-to-image API, `rhart-image-n-g31-flash/image-to-image`, or asks to upload images, submit a generation task, query task status, download results, or build code around this API.

## Core Workflow

1. For local files, upload each image with `scripts/rh100.py --image`.
2. Submit image-to-image task with `imageUrls`, `prompt`, `aspectRatio`, `resolution`, and enterprise shared `instanceType`.
3. Read `taskId` from the submission response.
4. Poll `POST https://www.runninghub.cn/openapi/v2/query` until `SUCCESS` or `FAILED`.
5. Download every `results[].url` immediately; result URLs expire in 24 hours.

## Script

For one-off single tasks, use the bundled script to submit only, then check status separately. By default `rh100.py` does not wait after submission, which keeps Codex streams short:

```powershell
python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100.py `
  --image "C:\path\to\input.png" `
  --prompt "将这张线稿转换为明代水墨武侠风格的精细彩图。" `
  --aspect-ratio "9:16" `
  --resolution "1k" `
  --instance-type "default" `
  --out-dir ".\outputs"
```

Only add `--wait` for quick manual tests. `--wait` defaults to a 60-second maximum foreground wait and should not be used for batches or long generations.

For public URLs:

```powershell
python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100.py `
  --image-url "https://example.com/input.png" `
  --prompt "将这张线稿转换为明代水墨武侠风格的精细彩图。" `
  --aspect-ratio "9:16" `
  --resolution "1k"
```

The script currently contains a temporary test API key, but `RUNNINGHUB_API_KEY` overrides it. Prefer setting the environment variable before production use.

## Quiet Batch Runner

For concurrent batches, prefer `scripts/rh100_batch.py`. It saves upload URLs, task IDs, task status, usage, errors, and downloaded result paths to a local JSON file, writes detailed logs to disk, and prints only a short status summary. This avoids flooding the Codex conversation stream with long URLs and frequent polling output.

Keep Codex foreground runs short. The batch runner defaults to a 60-second polling window (`--max-poll-seconds 60`) so a long generation does not hold one Codex stream open for several minutes. If work is still running, resume with `poll` against the same `rh100_jobs.json`; do not restart the job. Avoid foreground waits longer than 60 seconds in Codex.

Recommended pattern:

```powershell
python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100_batch.py run `
  --image "C:\path\to\image-1.jpg" `
  --image "C:\path\to\image-2.jpg" `
  --reference "C:\path\to\reference.jpg" `
  --prompt-file "C:\path\to\prompt.txt" `
  --variants 2 `
  --concurrency 14 `
  --resolution "2k" `
  --instance-type "default" `
  --out-dir "C:\Users\Administrator\Desktop\灰色" `
  --job-file "C:\Users\Administrator\Desktop\灰色\rh100_jobs.json"
```

To check or resume:

```powershell
python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100_batch.py status `
  --job-file "C:\Users\Administrator\Desktop\灰色\rh100_jobs.json"

python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100_batch.py poll `
  --job-file "C:\Users\Administrator\Desktop\灰色\rh100_jobs.json" `
  --out-dir "C:\Users\Administrator\Desktop\灰色"
```

If Codex shows `stream disconnected before completion: Upstream request failed`, treat it as a Codex/tool transport interruption, not necessarily an RH100 task failure. Resume by running `status` or `poll` against the saved `rh100_jobs.json`.

For especially large batches, use `submit` first, then run short `poll` calls:

```powershell
python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100_batch.py submit `
  --image "C:\path\to\image-1.jpg" `
  --prompt-file "C:\path\to\prompt.txt" `
  --job-file "C:\path\to\rh100_jobs.json" `
  --out-dir "C:\path\to\outputs"

python C:\Users\Administrator\.codex\skills\RH100\scripts\rh100_batch.py poll `
  --job-file "C:\path\to\rh100_jobs.json" `
  --out-dir "C:\path\to\outputs" `
  --max-poll-seconds 60
```

When tasks finish, report the final status summary and cost/time evidence from the saved job file:

- `total_time`: accumulated API task runtime from `usage.taskCostTime`.
- `wall_time`: elapsed wall-clock time from the earliest `submittedAt` to the latest `finishedAt`; use this when `usage.taskCostTime` is missing or returns `0`.
- `consume_money`: accumulated `usage.consumeMoney` when the API returns it.
- `consume_coins`: accumulated `usage.consumeCoins` when the API returns it.
- `third_party_money`: accumulated `usage.thirdPartyConsumeMoney` when present. Some enterprise image-to-image responses return `consumeMoney: null`, `consumeCoins: null`, `taskCostTime: "0"`, but include `thirdPartyConsumeMoney`; in that case report the third-party money as the usable cost field and explain the null official billing fields briefly.

If upload time is useful, also mention the inclusive time from upload start to final download. Do not confuse wall-clock generation time with `usage.taskCostTime`.

If a field is absent or `null`, show `N/A` rather than guessing. If `consume_money` is `N/A` but `third_party_money` is present, report both fields so the user still sees the usable cost signal returned by RunningHub.

## API Facts

- Submit endpoint: `POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/image-to-image`
- Query endpoint: `POST https://www.runninghub.cn/openapi/v2/query`
- Upload endpoint: `POST https://www.runninghub.cn/openapi/v2/media/upload/binary`
- API concurrency: 100
- `imageUrls`: required, max 10 images, each image max 30 MB
- `prompt`: required, 1 to 20000 characters
- `resolution`: required, enum `1k`, `2k`, `4k`
- `aspectRatio`: optional, see `references/api.md`
- `webhookUrl`: optional
- Enterprise shared key usage requires `instanceType`: `default` for Standard, `plus` for Plus.
- Lite uses system auto-scheduling; omit `instanceType`.
- Uploaded media links expire in 1 day
- Generated result URLs expire in 24 hours

## Instance Types And Billing

All instance types are billed by seconds. When multiple tasks run concurrently, billing is based on the accumulated runtime of all tasks, not the wall-clock concurrent duration.

- Lite: ¥0.4 / hour, system auto-scheduled. Omit `instanceType`.
- Standard: ¥4 / hour, 24 GB VRAM. Set `instanceType` to `default`.
- Plus: ¥6 / hour, 48 GB VRAM. Set `instanceType` to `plus`.

## References

Read `references/api.md` when the user needs field details, response examples, webhook behavior, known gaps, or integration notes.
