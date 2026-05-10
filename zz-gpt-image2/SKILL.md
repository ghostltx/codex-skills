---
name: zz-gpt-image2
description: Use this skill when the user asks to use ZZ-gpt-image2, gpt-image-2, or the T8Star OpenAI-compatible image API at https://ai.t8star.cn/v1 to test connectivity, verify model availability, or generate images. Supports PowerShell-based API checks and image generation through /v1/images/generations using T8STAR_API_KEY.
---

# ZZ gpt-image2

Use the bundled PowerShell script to test and generate images with the T8Star OpenAI-compatible API.

## Requirements

- Use `scripts/test-t8star.ps1`.
- Read the API key from `$env:T8STAR_API_KEY`; do not hard-code keys into skill files or generated scripts.
- Default base URL: `https://ai.t8star.cn/v1`.
- Default model: `gpt-image-2`.

## Connectivity Test

Run this before generation when the user asks whether the service works:

```powershell
$env:T8STAR_API_KEY='sk-...'
.\scripts\test-t8star.ps1
```

The script calls `/models`, verifies authentication, and confirms the model exists.

## Image Generation

Use `-Generate` for a real generation request:

```powershell
$env:T8STAR_API_KEY='sk-...'
.\scripts\test-t8star.ps1 -Generate -Prompt 'A compact stainless steel outdoor prep table in a bright studio, realistic product photo'
```

If the API returns `b64_json`, the script saves the file. If it returns a URL, report that URL to the user.

## Size Rules

For `gpt-image-2`, validate requested sizes against these official-style API limits before calling:

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
- `3840x2160`
- `2160x3840`
- `auto`

Interpret user shorthand as:

- `1K`: `1024x1024` unless the user specifies an aspect ratio.
- `2K`: use the user's previously requested `2048x2048` unless they specify another aspect ratio.
- `4K`: use the user's previously requested `3840x2160` for landscape 16:9, or `2160x3840` for portrait 9:16.

Invalid examples:

- `4096x4096`: invalid because the longest edge exceeds `3840`.
- `3840x3840`: invalid because total pixels exceed the pixel budget.

Known outcomes:

- `1024x1024`: works synchronously.
- `2048x2048`: works in async mode; synchronous calls may timeout or disconnect.
- `2048x2048` batch: 5 concurrent async tasks were tested successfully; all 5 completed and downloaded.
- `3840x2160`: works in async mode and is the largest tested 16:9 4K size.
- `3840x2160` batch: single-task generation works, but 5 concurrent async tasks failed with backend processing errors; use concurrency `1` or `2` for 4K.
- `2160x3840`: expected to satisfy the same documented limits for portrait 4K.

When the user asks for 4K, prefer `3840x2160` for landscape or `2160x3840` for portrait unless they explicitly ask for a square image.
When the user asks for 2K batch generation, `2048x2048` with 5 concurrent async tasks is a known-good setting.

For large images or requests that time out synchronously, use async mode. The API docs specify:

- Submit with `POST /v1/images/generations?async=true`.
- The response returns `task_id`.
- Poll with `GET /v1/images/tasks/{task_id}` until status is `SUCCESS` or `FAILURE`.

```powershell
$env:T8STAR_API_KEY='sk-...'
.\scripts\test-t8star.ps1 -Generate -Async -Size '2048x2048' -Prompt '...'
```

Prefer async mode for any size larger than `1024x1024`.
For batch work, prefer concurrency `5` for 2K and concurrency `1-2` for 4K. Polling can intermittently return SSL/EOF errors; retry polling instead of treating one transient polling error as task failure.

## Options

- `-Prompt`: image prompt.
- `-OutputPath`: local save path for base64 image responses.
- `-Size`: image size request, defaults to `1024x1024`.
- `-TimeoutSec`: generation request timeout, defaults to `180`.
- `-Async`: submit async image generation and poll task status.
- `-SkipModelCheck`: skip `/models` when the model is already known and only generation should be tested.
- `-PollIntervalSec`: async polling interval, defaults to `10`.
- `-MaxPollSec`: max async polling time, defaults to `900`.
- `-Model`: override model name.
- `-BaseUrl`: override API base URL.

## Reporting

Summarize whether `/models` connected, whether `gpt-image-2` was found, and whether generation returned a URL or saved file. Do not print or reveal the API key back to the user.
