---
name: RH-GPT-IMAGE-2-I2I
description: RunningHub image-to-image skill. Use when Codex needs to upload one or more local reference images, send a prompt, create a RunningHub 图生图 / image-to-image workflow task by workflowId, poll task status, and download generated image results. Supports variable image counts, automatic node discovery from RunningHub workflow JSON, manual node overrides, and verified workflow 2047956784060567554 with 1k/2k/4k output.
---

# RH-GPT-IMAGE-2-I2I

Use this skill to submit local images plus a prompt to a RunningHub image-to-image workflow.

Use `scripts/submit_i2i.ps1` for explicit workflow submissions. `scripts/img2img.ps1` is the short convenience entrypoint with default workflow `2047956784060567554`.

## Quick Start

Default verified workflow:

```powershell
& "$env:USERPROFILE\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\submit_i2i.ps1" `
  -WorkflowId "2047956784060567554" `
  -ImagePaths "C:\path\input.png" `
  -Prompt "Create an ecommerce product image..." `
  -AspectRatio "1:1"
```

Multiple reference images:

```powershell
& "$env:USERPROFILE\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\submit_i2i.ps1" `
  -WorkflowId "2047956784060567554" `
  -ImagePaths "C:\path\front.jpg","C:\path\side.jpg","C:\path\detail.jpg" `
  -Prompt "Use all references to generate a consistent product image" `
  -OutputPath "$env:USERPROFILE\Desktop\rh_i2i.png"
```

Common parameters:

| Parameter | Required | Notes |
| --- | --- | --- |
| `-WorkflowId` | yes for `submit_i2i.ps1`; optional for `img2img.ps1` | RunningHub workflow ID. Verified/default: `2047956784060567554`. |
| `-ImagePaths` | yes | One or more local `.png/.jpg/.jpeg/.webp` files. |
| `-Prompt` | yes | Text prompt. Chinese or English is fine. |
| `-OutputPath` | no | Output file path. Defaults to desktop. |
| `-AspectRatio` | no | `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`; default `4:5`. |
| `-Resolution` | no | Defaults to `2k`; use `1k` for faster checks or `4k` for high-resolution output when supported. |
| `-Quality` | no | Optional if workflow exposes `quality`. |
| `-Seed` | no | Optional if workflow exposes `seed`. |
| `-ImageNodeIds` | no | Manual image LoadImage node IDs in order. |
| `-PromptNodeId` | no | Manual text node ID. |
| `-GenerationNodeId` | no | Manual generation node ID for `resolution/aspectRatio/seed/quality`. |
| `-PromptFieldName` | no | Defaults to workflow-detected prompt field. |
| `-PollDelays` | no | Defaults to fast polling: start after 30 seconds, then query every 5 seconds for about 300 seconds. Extend for slow 4K jobs. |

## Workflow

1. Upload local files via `/openapi/v2/media/upload/binary`.
2. Use uploaded `data.fileName` for ComfyUI `LoadImage.image` node values.
3. Fetch workflow JSON via `/api/openapi/getJsonApiFormat` when nodes are not provided.
4. Detect image nodes, prompt node, and generation node from workflow graph connections.
5. Create task via `/task/openapi/create`.
6. Poll `/openapi/v2/query`.
7. If `query.results` is empty, try `/task/openapi/outputs`.
8. Download the first result URL to `-OutputPath`.

## Rules

- Use `scripts/submit_i2i.ps1` when specifying a workflow explicitly.
- Use `scripts/img2img.ps1` for the default verified workflow or single-image `-ImagePath` convenience calls.
- Default to `-Resolution 2k` unless the user asks for `1k` or `4k`.
- Default polling starts 30 seconds after create, then checks every 5 seconds. If no image is returned after about 300 seconds, report the last status and task ID so the result can be downloaded later.
- Verified workflow `2047956784060567554` supports `1k`, `2k`, and `4k`; use `2k` as the normal default.
- For unused image slots, pass empty strings to remaining detected image nodes to prevent default `example.png` references from affecting generation.
- Use unique output paths for parallel jobs.
- For batch generation, submit up to 3 parallel tasks, then wait for all 3 to return `SUCCESS` and download before starting the next group of 3.
- If any task reaches local `TIMEOUT` with last status `RUNNING`, do not submit the next group yet. Save the `TASK_ID`, query/download it later, and continue only after the previous group has finished or freed the queue.
- When batching 9 images, run 3 at a time: tasks 1-3, wait/download; then 4-6, wait/download; then 7-9.
- If `TASK_QUEUE_MAXED` appears, reduce concurrency temporarily or stagger task creation by 12-20 seconds.
- If the task returns `SUCCESS_NO_URL`, the workflow likely lacks an API-visible Save Image output or RunningHub is not exposing outputs for that workflow.

## Reference

Read `references/runninghub-api-notes.md` when changing the script or debugging workflow-specific behavior.
