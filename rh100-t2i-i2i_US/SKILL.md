---
name: rh100-t2i-i2i_US
description: RunningHub US GPT-Image-2.5 text-to-image plus Sunburst precision editing and Flare fast editing with optional result download. Use when generation should call the US official Token endpoints and read `RUNNINGHUB_API_KEY_US`.
---

# RH100-T2I/I2I_US

Use this US variant for RunningHub US GPT-Image-2.5 through the official Token routes. It supports three modes and submits once, prints the first `taskId`, opens the RunningHub US task page, and exits immediately.

Configured endpoints:

- Text-to-image: Sunburst, `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2.5-official-token/sunburst/text-to-image`
- High-precision image edit: Sunburst, `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2.5-official-token/sunburst/edit`
- High-speed image edit: Flare, `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2.5-official-token/flare/edit`

Routing rule:

- If no `--image` or `--image-url` is provided, use Sunburst text-to-image.
- If an image is provided, use high-precision Sunburst edit by default.
- Use high-speed Flare edit only when the user explicitly requests Flare or a high-speed edit. In all other cases, do not infer speed requirements; keep `--edit-mode precision`.
- For uploaded conversation images, pass the local file path when one is available.

## Submit

Text-to-image:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i_US\scripts\rh100_image_gen.py `
  --prompt "白底高端电商产品图" `
  --aspect-ratio "1:1" `
  --resolution "1k" `
  --quality "high"
```

High-precision image edit with a local file (Sunburst, default):

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i_US\scripts\rh100_image_gen.py `
  --image "C:\path\to\product.png" `
  --prompt "保留产品外形，制作高级户外场景图"
```

High-speed image edit with a public URL (Flare):

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i_US\scripts\rh100_image_gen.py `
  --image-url "https://example.com/product.png" `
  --edit-mode "fast" `
  --prompt "制作电商详情页主图" `
  --aspect-ratio "16:9" `
  --resolution "1k" `
  --background "opaque" `
  --output-format "png"
```

After a successful submission, open `https://www.runninghub.ai/call-api/bill-task`. The submit script must not query task status or download results. Use `--no-open` only for headless or test runs. Set `RUNNINGHUB_API_KEY_US`. `--api-key` is for one-off runs only.

## Download confirmation

After every successful submission, report the first `taskId` and ask exactly:

`任务已提交，是否下载全部图片？请回复“是”或“否”。`

- If the user answers no, stop without polling or downloading.
- If the user answers yes, run the downloader immediately without asking another question.
- Never start polling before the user answers yes.
- The downloader creates `C:\Users\ghost\Desktop\<first-taskId>` and saves every image returned by every submitted task into that folder.

For one submitted task:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i_US\scripts\rh100_download.py `
  --task-id "<TASK_ID>"
```

For multiple explicit task IDs, repeat `--task-id` in submission order. For batch submissions, use the saved job file:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i_US\scripts\rh100_download.py `
  --job-file "C:\path\to\rh100_jobs.json"
```

The downloader polls until all tasks reach a terminal state or the 30-minute default wait limit. It keeps successful downloads when another task fails and reports the failed task IDs.

Defaults are `edit-mode=precision`, `1:1`, `2k`, `background=auto`, `quality=high`, and `outputFormat=png`. `--image` and `--image-url` accept up to 16 total reference images for either edit mode.

## Batch mode

For many source images or multiple variants, use the bundled batch runner. It concurrently uploads and submits either precision Sunburst edits or fast Flare edits, stores task IDs in `rh100_jobs.json`, prints the first `taskId`, opens the same bill-task page, and stops. It never polls or downloads results until the user confirms.

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i_US\scripts\rh100_i2i_batch.py submit `
  --image "C:\path\to\image-1.jpg" `
  --image "C:\path\to\image-2.jpg" `
  --edit-mode "fast" `
  --variants 2 `
  --prompt-file "C:\path\to\prompt.txt" `
  --job-file "C:\path\to\rh100_jobs.json" `
  --quality "high" `
  --webhook-url "https://example.com/runninghub-webhook" `
  --concurrency 14
```

Read [references/api.md](references/api.md) for endpoint fields and known limits.
