---
name: rh100-banana-pro-us
description: RunningHub US Nano Banana Pro text-to-image plus the user-specified composition image-to-image API, with optional result download. Use when Codex should generate Banana Pro images from prompts or transform local reference images while preserving or changing composition.
---

# RH100 Banana PRO US

Use the bundled scripts with `RUNNINGHUB_API_KEY_US`.

## Routing

- Without `--image` or `--image-url`, use the Banana PRO text-to-image endpoint.
- With one or more images, use the user-specified composition image-to-image endpoint.
- Local conversation images must be passed by their local path.
- The composition endpoint supports up to 14 reference images.

## Submit

Text-to-image:

```powershell
python C:\Users\ghost\.codex\skills\rh100-banana-pro-us\scripts\rh100_banana_pro_image_gen.py `
  --prompt "高端写实室内摄影，柔和电影光影" `
  --aspect-ratio "4:5" `
  --resolution "2k"
```

Composition image-to-image:

```powershell
python C:\Users\ghost\.codex\skills\rh100-banana-pro-us\scripts\rh100_banana_pro_image_gen.py `
  --image "C:\path\to\reference.png" `
  --prompt "保留主体，按照描述调整画面构图和氛围" `
  --aspect-ratio "4:5" `
  --resolution "2k"
```

The script uploads local files, submits one task, prints the first `taskId`, and opens `https://www.runninghub.ai/call-api/bill-task`. It never polls or downloads during submission. Use `--no-open` for headless runs.

## Download confirmation

After a successful submission, report the first task ID and ask exactly:

`任务已提交，是否下载全部图片？请回复“是”或“否”。`

Never poll before the user answers yes. If yes, run:

```powershell
python C:\Users\ghost\.codex\skills\rh100-banana-pro-us\scripts\rh100_download.py `
  --task-id "<TASK_ID>"
```

The downloader saves all returned images to `C:\Users\ghost\Desktop\<first-taskId>`.

## Batch composition

For multiple reference images or variants, use the bundled `rh100_i2i_batch.py submit` runner. It saves task IDs to a job file and still waits for explicit download confirmation before polling.

Read [references/api.md](references/api.md) for the exact user-provided API pages and endpoint mapping.
