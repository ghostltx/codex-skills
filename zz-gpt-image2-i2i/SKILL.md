---
name: zz-gpt-image2-i2i
description: Use this skill when the user asks to use ZZ gpt-image-2 for image-to-image, image editing, reference-image editing, or async image edits through the T8Star OpenAI-compatible API at https://ai.t8star.cn/v1. Supports /v1/images/edits and /v1/images/edits?async=true with local image uploads.
---

# ZZ gpt-image2 I2I

Use the bundled PowerShell scripts for gpt-image-2 image editing / image-to-image through the T8Star OpenAI-compatible API.

## Requirements

- Use `scripts/edit-image.ps1` for a single edit.
- Use `scripts/batch-edit-manifest.ps1` for batches; it submits async tasks first, writes a manifest, uses one shared poller, downloads successes, and retries failed indexes.
- The script has a default `-ApiKey` parameter configured like the existing `zz-gpt-image2` skill, and also falls back to `$env:T8STAR_API_KEY` if that parameter is empty.
- Default base URL: `https://ai.t8star.cn/v1`.
- Default model: `gpt-image-2`.
- Default output size: `2048x2048` (2K square) unless the user specifies another size or aspect ratio.
- Do not print or reveal the API key.

## Mode Selection

Default to async edits unless the user explicitly asks for sync:

- Sync edits: `POST /v1/images/edits`
- Async edits: `POST /v1/images/edits?async=true`, then poll `GET /v1/images/tasks/{task_id}`

Use sync only when the user explicitly asks for synchronous editing, a quick single-image test, or no polling. Prefer async for 2K, 4K, batch work, concurrent work, or when sync requests timeout.

## Batch Manifest Mode

For more than one output, prefer manifest mode instead of launching many PowerShell jobs that each submit, poll, and download independently. Independent pollers are noisy and were observed to cause `502`, `system error`, and timeout failures.

Manifest mode workflow:

1. Submit all async edit tasks quickly and store each `task_id`.
2. Save a manifest with `Index`, `TaskId`, `Prompt`, `OutputPath`, `Status`, `Saved`, and `Failure`.
3. Poll all task ids from one loop.
4. Download successful images.
5. Detect failed or missing indexes.
6. Retry only failed/missing indexes with the original prompt, size, and output filename.
7. Stop when the requested output count exists or `-MaxRetryRounds` is reached.

Use this script for batch work:

```powershell
& "$env:USERPROFILE\.codex\skills\zz-gpt-image2-i2i\scripts\batch-edit-manifest.ps1" `
  -ImagePath "C:\path\input.png" `
  -PromptsPath "C:\path\prompts.json" `
  -OutputDir "C:\Users\ghost\Desktop\batch-output" `
  -Size "1632x2048" `
  -MaxRetryRounds 3
```

`PromptsPath` must be a JSON array. Each item may contain:

```json
{
  "name": "optional_slug",
  "prompt": "full edit prompt"
}
```

Recommended batch sizes and behavior from tests:

- `816x1024` 1K 4:5, 10-task manifest batch: `10/10` succeeded.
- `1152x1440`, 10-task manifest batch: `10/10` succeeded in one test, but this is not full 2K.
- `1632x2048` true 2K 4:5, 10-task manifest batch: `9/10` first pass, `10/10` after retry.
- For 20 outputs, prefer two 10-task manifest batches or one manifest run with retries, not 20 independent pollers.
- Do not use 10-second staggered independent jobs for I2I; repeated `bad response status code 502` failures were observed.

## Image Edit

Run with one input image:

```powershell
& "$env:USERPROFILE\.codex\skills\zz-gpt-image2-i2i\scripts\edit-image.ps1" `
  -ImagePath "C:\path\input.png" `
  -Prompt "Edit instruction"
```

Run with multiple reference/edit images:

```powershell
& "$env:USERPROFILE\.codex\skills\zz-gpt-image2-i2i\scripts\edit-image.ps1" `
  -ImagePaths @("C:\path\a.png", "C:\path\b.png") `
  -Prompt "Use both images as references and generate the edited result"
```

## Size Rules

Docs say `gpt-image-2` accepts any `size` that satisfies these constraints:

- Longest edge must be `<= 3840`.
- Width and height must both be divisible by `16`.
- Long-edge to short-edge ratio must be `<= 3:1`.
- Total pixels must be from `655360` through `8294400`.

Common valid sizes:

- `1024x1024`
- `1536x1024`
- `1024x1536`
- `2048x2048`
- `2048x1152`
- `1152x2048` (2K 9:16 portrait)
- `816x1024` (1K 4:5 portrait)
- `1632x2048` (true 2K 4:5 portrait)
- `3840x2160`
- `2160x3840`
- `auto`

Interpret shorthand as:

- `1K`: `1024x1024` unless the user specifies an aspect ratio.
- `2K`: `2048x2048` by default; use `1152x2048` for 9:16 portrait.
- `2K 4:5`: use `1632x2048`.
- `1K 4:5`: use `816x1024`.
- `4K`: `3840x2160` for landscape 16:9, or `2160x3840` for portrait 9:16.

Invalid examples:

- `4096x4096`: invalid because the longest edge exceeds `3840`.
- `3840x3840`: invalid because total pixels exceed the pixel budget.

## Options

- `-ImagePath`: one local input image.
- `-ImagePaths`: one or more local input images.
- `-Prompt`: edit instruction.
- `-MaskPath`: optional local mask image if supported by the backend.
- `-OutputPath`: local save path. Defaults to desktop `zz_gpt_image2_i2i_时间戳.png`.
- `-Size`: output size request, defaults to `2048x2048`.
- `-Async`: submit async edit and poll task status. Async is already the default; this flag is accepted for explicitness.
- `-Sync`: use synchronous `/v1/images/edits` without task polling.
- `-SkipModelCheck`: skip `/models` when generation should start immediately.
- `-PollIntervalSec`: async polling interval, defaults to `10`.
- `-MaxPollSec`: max async polling time, defaults to `1200`.
- `-Model`: override model name.
- `-BaseUrl`: override API base URL.

Batch script options:

- `-ImagePath`: one local input image.
- `-ImagePaths`: one or more local input/reference images.
- `-PromptsPath`: JSON array of prompt objects or strings.
- `-OutputDir`: output folder.
- `-Size`: output size request, defaults to `2048x2048`.
- `-PollIntervalSec`: shared polling interval, defaults to `10`.
- `-MaxPollSec`: max polling time per round, defaults to `1800`.
- `-MaxRetryRounds`: retry rounds for failed/missing indexes, defaults to `3`.
- `-FilePrefix`: output filename prefix, defaults to `zz_gpt_image2_i2i_batch`.

## Reporting

Summarize whether the edit was sync or async, the task id when async, whether a URL or base64 result was returned, and the saved output path.
