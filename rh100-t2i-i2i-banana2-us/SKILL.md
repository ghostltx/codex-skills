---
name: rh100-t2i-i2i-banana2-us
description: RunningHub US Nano Banana 2 (Gemini 3.1 Flash Image) text-to-image and image-to-image generation with optional result download. Use when Codex should generate or edit images through the RunningHub Banana2 US API, including local reference-image uploads, multiple reference images, and batch jobs.
---

# RH100 Banana2 US

Use the bundled scripts to call the RunningHub Nano Banana 2 official-stable Model API.

## Routing

- Without `--image` or `--image-url`, call text-to-image.
- With one or more `--image` or `--image-url`, call image-to-image.
- For a conversation-uploaded image, use its local path when available.
- Image-to-image accepts up to 14 reference images.

The API key comes from `RUNNINGHUB_API_KEY_US`; `--api-key` is available only for one-off runs.

## Submit

Text-to-image:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i-banana2-us\scripts\rh100_banana2_image_gen.py `
  --prompt "白底高端电商产品图，柔和影棚光" `
  --aspect-ratio "1:1" `
  --resolution "1k"
```

Image-to-image:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i-banana2-us\scripts\rh100_banana2_image_gen.py `
  --image "C:\path\to\product.png" `
  --prompt "保留产品结构，制作高级户外场景图" `
  --aspect-ratio "4:5" `
  --resolution "2k"
```

The script uploads local files, submits exactly one task, prints the first `taskId`, and opens `https://www.runninghub.ai/call-api/bill-task`. It does not query status or download results during submission. Use `--no-open` in headless or test runs.

## Download confirmation

After every successful submission, report the first `taskId` and ask exactly:

`任务已提交，是否下载全部图片？请回复“是”或“否”。`

Never poll before the user answers yes. If the user answers yes, run:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i-banana2-us\scripts\rh100_download.py `
  --task-id "<TASK_ID>"
```

For multiple tasks, repeat `--task-id` or pass a saved `rh100_jobs.json`. The downloader saves all returned result images in `C:\Users\ghost\Desktop\<first-taskId>`.

## Batch image-to-image

For multiple source images or variants:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i-banana2-us\scripts\rh100_i2i_batch.py submit `
  --image "C:\path\to\image-1.jpg" `
  --image "C:\path\to\image-2.jpg" `
  --variants 2 `
  --prompt-file "C:\path\to\prompt.txt" `
  --job-file "C:\path\to\rh100_jobs.json"
```

Read [references/api.md](references/api.md) for the endpoint IDs, fields, limits, and public documentation links.
