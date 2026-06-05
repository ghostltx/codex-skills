---
name: runninghub-openapi
description: Reusable RunningHub OpenAPI client skill for image generation, image-to-image editing, media upload, task polling, result download, account checks, and endpoint inspection. Use when another skill needs to call RunningHub OpenAPI directly, generate images through RunningHub, submit an endpoint such as rhart-image-n-g31-flash/image-to-image, or verify a RUNNINGHUB_API_KEY without storing API keys in skill files.
---

# RunningHub OpenAPI

## Purpose

Use this skill as the shared low-level RunningHub OpenAPI bridge for other skills. It keeps API keys outside the skill and provides bundled scripts for account checks, endpoint inspection, task submission, polling, result download, and cost reporting.

## Key Rules

- Never write API keys into this skill, scripts, logs, examples, or generated files.
- Read the API key from `RUNNINGHUB_API_KEY` by default.
- If `RUNNINGHUB_API_KEY` is missing, ask the user to provide it or pass `-ApiKey` / `--api-key` at runtime.
- Prefer this skill's bundled scripts over copying API code into downstream skills.
- Pass explicit RunningHub endpoint IDs from the calling skill. Do not guess a premium endpoint when the caller already specifies one.
- Preserve and report `OUTPUT_FILE:`, `COST:`, `DURATION:`, `TASK_ID:`, and `ELAPSED:` lines from script output when present.

## Scripts

Primary Python runner:

```powershell
python "$env:USERPROFILE\.codex\skills\runninghub-openapi\scripts\runninghub_openapi.py" --check
```

Windows wrapper:

```powershell
& "$env:USERPROFILE\.codex\skills\runninghub-openapi\scripts\Invoke-RunningHubOpenApi.ps1" -Check
```

## Common Calls

Image-to-image/editing:

```powershell
& "$env:USERPROFILE\.codex\skills\runninghub-openapi\scripts\Invoke-RunningHubOpenApi.ps1" `
  -Endpoint "rhart-image-n-g31-flash/image-to-image" `
  -Prompt "Edit only the product color and preserve layout, text, props, background, and geometry." `
  -ImagePaths @("C:\path\source.jpg", "C:\path\reference.jpg") `
  -Param @("aspectRatio=1:1", "resolution=2k") `
  -Output "C:\path\output.jpg"
```

Text-to-image:

```powershell
python "$env:USERPROFILE\.codex\skills\runninghub-openapi\scripts\runninghub_openapi.py" `
  --endpoint "rhart-image-g-2/text-to-image" `
  --prompt "A studio product photo on a clean white background" `
  --param aspectRatio=1:1 `
  --param resolution=2k `
  --output "C:\path\result.png"
```

Endpoint inspection:

```powershell
python "$env:USERPROFILE\.codex\skills\runninghub-openapi\scripts\runninghub_openapi.py" --info "rhart-image-n-g31-flash/image-to-image"
```

## API Details

The bundled script writes these constants internally:

- OpenAPI base: `https://www.runninghub.cn/openapi/v2`
- Account status: `https://www.runninghub.cn/uc/openapi/accountStatus`
- Media upload: `/media/upload/binary`
- Task query: `/query`

Authentication header:

```text
Authorization: Bearer <api key>
Content-Type: application/json
```

## Downstream Skill Pattern

When another skill needs generation, call this skill's script and pass:

- `--endpoint` / `-Endpoint`
- `--prompt` / `-Prompt`
- one or more `--image` / `-ImagePaths` values when needed
- repeated `--param key=value` / `-Param @("key=value")`
- `--output` / `-Output`

For local image inputs, the script sends small files as data URIs and uploads files larger than 5 MB. Multiple image inputs are assigned according to the endpoint parameter schema when known; if the endpoint is unknown, the script falls back to `imageUrls`.

For image-to-image correction or regeneration tasks, pass the composition image first and any structural, color, or style references after it. Keep aspect ratio and resolution explicit with `-Param`, such as `aspectRatio=1:1` and `resolution=2k`, so downstream skills can preserve ecommerce layout sizes instead of relying on endpoint defaults.

After a successful task, report the emitted `TASK_ID:`, `OUTPUT_FILE:`, `COST:`, and `ELAPSED:` lines to the user. These lines are the preferred completion evidence for publishable image-generation workflows.

## Failure Handling

- `NO_API_KEY`: ask the user to set `RUNNINGHUB_API_KEY` or provide a runtime key.
- `AUTH_FAILED`: ask the user to check the key in RunningHub.
- `INSUFFICIENT_BALANCE`: tell the user the RunningHub wallet needs recharge.
- `TASK_FAILED` or timeout: report the task ID if available and avoid blind resubmission unless the calling skill explicitly allows retry.
