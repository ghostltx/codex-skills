---
name: runninghub-generic-i2i
description: Generic RunningHub image-to-image workflow submitter. Use when Codex needs to upload one or more local reference images, send a prompt, create a RunningHub 图生图 / image-to-image workflow task by workflowId, poll task status, and download generated image results. Supports variable image counts, automatic node discovery from RunningHub workflow JSON, and manual node overrides for custom workflows.
---

# RunningHub Generic I2I

Use this skill to submit local images plus a prompt to any RunningHub image-to-image workflow.

## Quick Start

Run the bundled script instead of hand-writing API calls:

```powershell
& "$env:USERPROFILE\.codex\skills\runninghub-generic-i2i\scripts\submit_i2i.ps1" `
  -WorkflowId "WORKFLOW_ID" `
  -ImagePaths "C:\path\front.jpg","C:\path\side.jpg" `
  -Prompt "Create an ecommerce product image..." `
  -OutputPath "$env:USERPROFILE\Desktop\rh_i2i.png"
```

Common parameters:

| Parameter | Required | Notes |
| --- | --- | --- |
| `-WorkflowId` | yes | RunningHub workflow ID. |
| `-ImagePaths` | yes | One or more local `.png/.jpg/.jpeg/.webp` files. |
| `-Prompt` | yes | Text prompt. Chinese or English is fine. |
| `-OutputPath` | no | Output file path. Defaults to desktop. |
| `-AspectRatio` | no | `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`; default `4:5`. |
| `-Resolution` | no | Defaults to `2k`; use `1k` for faster/lower-cost checks or `4k` for high-resolution output when the workflow supports it. |
| `-Quality` | no | Optional if workflow exposes `quality`. |
| `-Seed` | no | Optional if workflow exposes `seed`. |
| `-ImageNodeIds` | no | Manual image LoadImage node IDs in order. |
| `-PromptNodeId` | no | Manual text node ID. |
| `-GenerationNodeId` | no | Manual generation node ID for `resolution/aspectRatio/seed/quality`. |
| `-PromptFieldName` | no | Defaults to `编辑文本`; auto-detection may override. |
| `-MaxImages` | no | Defaults to workflow-detected image nodes. |
| `-PollDelays` | no | Defaults to 480 seconds total. Extend for slow jobs. |

## Workflow

1. Upload local files via `/openapi/v2/media/upload/binary`.
2. Use uploaded `data.fileName` for ComfyUI `LoadImage.image` node values.
3. Fetch workflow JSON via `/api/openapi/getJsonApiFormat` when nodes are not provided.
4. Detect:
   - image nodes: `LoadImage` nodes with `image` input
   - prompt node: text-like node with `编辑文本` or `text` input
   - generation node: node exposing `resolution`, `aspectRatio`, `seed`, or `quality`
5. Create task via `/task/openapi/create`.
6. Poll `/openapi/v2/query`.
7. If `query.results` is empty, try `/task/openapi/outputs`.
8. Download the first result URL to `-OutputPath`.

## Rules

- Prefer auto-discovery first for unknown workflows. Use manual node parameters only when auto-detection picks the wrong nodes.
- Default to `-Resolution 2k` unless the user asks for `1k` or `4k`.
- Verified workflow `2047956784060567554` supports `1k`, `2k`, and `4k`; use `2k` as the normal default for this workflow.
- Treat polling status deterministically:
  - `SUCCESS`: stop polling, fetch the result URL, download the image, and report `TASK_ID`, `STATUS=SUCCESS`, `OUTPUT_PATH`, and `IMAGE_URL`.
  - `FAILED`: stop immediately, report `TASK_ID`, `STATUS=FAILED`, and include the returned `failedReason` when available.
  - Any other live query status, such as queued, pending, running, created, or processing states: keep polling until the configured `-PollDelays` are exhausted.
  - `TIMEOUT`: do not treat as a generation failure. Preserve and report the `TASK_ID` so the same task can be queried again later.
  - `SUCCESS_NO_URL`: the task completed but no API-visible image URL was returned. Do not blindly rerun; inspect workflow output/save-image exposure or query outputs manually.
  - `SUCCESS_DOWNLOAD_FAILED`: the task completed and returned a URL, but local download failed. Preserve `IMAGE_URL` and retry download instead of regenerating.
- For workflows with unused image slots, explicitly pass empty strings to remaining detected image nodes to prevent default `example.png` references from affecting generation.
- Use unique output paths for parallel jobs.
- For 3-way parallel jobs, create per-task temp copies or let the script do it; do not make multiple upload processes read the same original file directly.
- If the task returns `SUCCESS_NO_URL`, the workflow likely lacks an API-visible Save Image output or RunningHub is not exposing outputs for that workflow. In that case, inspect the workflow JSON and RunningHub web workflow output settings.
- If `TASK_QUEUE_MAXED` appears, reduce concurrency or stagger task creation by 8-15 seconds.

## Reference

Read `references/runninghub-api-notes.md` when changing the script or debugging workflow-specific behavior.
