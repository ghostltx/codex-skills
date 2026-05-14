---
name: zz-gpt-image2-i2i
description: Use this skill when the user asks to use ZZ gpt-image-2 for image-to-image, image editing, reference-image editing, or async image edits through the T8Star OpenAI-compatible API at https://ai.t8star.cn/v1. Supports /v1/images/edits and /v1/images/edits?async=true with local image uploads.
---

# ZZ gpt-image2 I2I

Use the bundled PowerShell script for gpt-image-2 image editing / image-to-image through the T8Star OpenAI-compatible API.

## Requirements

- Use `scripts/edit-image.ps1`.
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
- `3840x2160`
- `2160x3840`
- `auto`

Interpret shorthand as:

- `1K`: `1024x1024` unless the user specifies an aspect ratio.
- `2K`: `2048x2048` by default; use `1152x2048` for 9:16 portrait.
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

## Reporting

Summarize whether the edit was sync or async, the task id when async, whether a URL or base64 result was returned, and the saved output path.
