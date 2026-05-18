---
name: runninghub-generic-t2i
description: Generic RunningHub text-to-image workflow submitter. Use when Codex needs to send a prompt to any RunningHub 文生图 / text-to-image ComfyUI workflow by workflowId, optionally set negative prompt, aspect ratio, width, height, seed, steps, cfg, batch size, resolution, quality, poll task status, and download generated image results. Supports automatic node discovery from RunningHub workflow JSON and manual node overrides for custom workflows.
---

# RunningHub Generic T2I

Use this skill to submit a prompt to any RunningHub text-to-image workflow.

## Quick Start

Run the bundled script instead of hand-writing API calls:

```powershell
& "$env:USERPROFILE\.codex\skills\runninghub-generic-t2i\scripts\submit_t2i.ps1" `
  -WorkflowId "WORKFLOW_ID" `
  -Prompt "Create a premium ecommerce hero image..." `
  -OutputPath "$env:USERPROFILE\Desktop\rh_t2i.png"
```

Common parameters:

| Parameter | Required | Notes |
| --- | --- | --- |
| `-WorkflowId` | yes | RunningHub workflow ID. |
| `-Prompt` | yes | Positive prompt. Chinese or English is fine. |
| `-NegativePrompt` | no | Negative prompt if the workflow exposes one. |
| `-OutputPath` | no | Output file path. Defaults to desktop. |
| `-AspectRatio` | no | `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`; optional. |
| `-Resolution` | no | Supports `1k`, `2k`, and `4k` when the workflow exposes `resolution`. |
| `-Width` / `-Height` | no | For workflows using pixel dimensions instead of aspect ratio. |
| `-Seed` | no | Defaults to `0`; pass a fixed seed for reproducibility. |
| `-Steps` | no | For sampler nodes exposing `steps`. |
| `-Cfg` | no | For sampler nodes exposing `cfg` or `cfg_scale`. |
| `-BatchSize` | no | For latent/image nodes exposing `batch_size`. |
| `-Quality` | no | Optional if workflow exposes `quality`. |
| `-PromptNodeId` | no | Manual positive prompt node ID. |
| `-PromptFieldName` | no | Defaults to workflow-detected text field. |
| `-NegativePromptNodeId` | no | Manual negative prompt node ID. |
| `-GenerationNodeId` | no | Manual node for `resolution/aspectRatio/seed/quality`. |
| `-SizeNodeId` | no | Manual node for `width/height/batch_size`. |
| `-SamplerNodeId` | no | Manual node for `seed/steps/cfg`. |
| `-PollDelays` | no | Defaults to 480 seconds total. Extend for slow jobs. |

## Workflow

1. Fetch workflow JSON via `/api/openapi/getJsonApiFormat` when nodes are not provided.
2. Detect:
   - positive prompt node: text-like node with `text`, `positive`, `prompt`, or `编辑文本` input
   - negative prompt node: text-like node with negative class/title/field hints
   - generation node: node exposing `resolution`, `aspectRatio`, `seed`, or `quality`
   - size node: node exposing `width`, `height`, or `batch_size`
   - sampler node: node exposing `seed`, `steps`, `cfg`, or `cfg_scale`
3. Create task via `/task/openapi/create`.
4. Poll `/openapi/v2/query`.
5. If `query.results` is empty, try `/task/openapi/outputs`.
6. Download the first result URL to `-OutputPath`.

## Rules

- Prefer auto-discovery first for unknown workflows. Use manual node parameters only when auto-detection picks the wrong nodes.
- Pass `-AspectRatio` / `-Resolution` for GPT Image-style workflows; pass `-Width` / `-Height` for SD/ComfyUI-style workflows.
- `-Resolution` supports `1k`, `2k`, and `4k`; use `2k` as the normal default when the user does not specify a resolution.
- If the workflow has both generation and sampler nodes, the script sends seed to both when relevant. This is intentional for broad compatibility.
- Treat polling status deterministically:
  - `SUCCESS`: stop polling, fetch the result URL, download the image, and report `TASK_ID`, `STATUS=SUCCESS`, `OUTPUT_PATH`, and `IMAGE_URL`.
  - `FAILED`: stop immediately, report `TASK_ID`, `STATUS=FAILED`, and include returned failure details when available.
  - live statuses such as queued, pending, running, created, or processing: keep polling until `-PollDelays` are exhausted.
  - `TIMEOUT`: do not treat as a generation failure. Preserve and report `TASK_ID` so the same task can be queried again later.
  - `SUCCESS_NO_URL`: the task completed but no API-visible image URL was returned. Inspect workflow output/save-image exposure before rerunning.
  - `SUCCESS_DOWNLOAD_FAILED`: the task completed and returned a URL, but local download failed. Preserve `IMAGE_URL` and retry download instead of regenerating.
- Use unique output paths for parallel jobs.
- Only run up to 3 unfinished RunningHub T2I tasks in parallel. For larger batches, use a rolling window of 3: start at most 3 tasks, then submit the next task only after one finishes with `SUCCESS` or `FAILED`.
- Do not submit 4 or more T2I tasks at the same time. If a task reaches local `TIMEOUT` while still running, it still occupies one of the 3 parallel slots until it reaches `SUCCESS` or `FAILED`.
- If `TASK_QUEUE_MAXED` appears, reduce concurrency or stagger task creation by 8-15 seconds.

## Reference

Read `references/runninghub-api-notes.md` when changing the script or debugging workflow-specific behavior.
