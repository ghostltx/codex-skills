---
name: rh100-t2i-i2i
description: RunningHub G-2 text-to-image/image-to-image generation and optional result download skill. Submit first, report the RunningHub task page link without opening it, ask whether to download, and only after confirmation poll all submitted tasks and save every result under a Desktop folder named with the first taskId.
---

# RunningHub G-2 文生图/图生图

Use the unified script for all normal RH100 image generation requests. It submits once, prints the first `taskId` and task page link, and exits immediately without opening a browser:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_image_gen.py `
  --prompt "高端电商产品场景图"
```

The routing rule is deterministic:

- If `--image` or `--image-url` is present, use `POST https://www.runninghub.cn/openapi/v2/rhart-image-g-2/image-to-image`.
- If no image is provided, use `POST https://www.runninghub.cn/openapi/v2/rhart-image-g-2/text-to-image`.
- A prompt that merely mentions an image does not count as an image input.
- For uploaded conversation images, pass the local file path when one is available.

Both endpoints accept `prompt`, `aspectRatio`, `resolution`, `instanceType`, and optional `webhookUrl`; the image-to-image endpoint additionally requires `imageUrls`.

## Unified script

```powershell
# Text-to-image
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_image_gen.py `
  --prompt "白底高端电商产品图"

# Image-to-image with a local file
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_image_gen.py `
  --image "C:\path\to\product.png" `
  --prompt "保留产品外形，制作高级户外场景图"

# Image-to-image with a public URL
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_image_gen.py `
  --image-url "https://example.com/product.png" `
  --prompt "制作电商详情页主图"
```

After a successful submission, report `https://www.runninghub.cn/call-api/bill-task` in the conversation. The submit script must not open the browser, query task status, or download results. Use `--open` only when the user explicitly requests automatic opening. Set `RUNNINGHUB_API_KEY`. `--api-key` is for one-off runs only.

## Download confirmation

After every successful submission, report the first `taskId` and ask exactly:

`任务已提交，是否下载全部图片？请回复“是”或“否”。`

- If the user answers no, stop without polling or downloading.
- If the user answers yes, run the downloader immediately without asking another question.
- Never start polling before the user answers yes.
- The downloader creates `C:\Users\ghost\Desktop\<first-taskId>` and saves every image returned by every submitted task into that folder.

For one submitted task:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_download.py `
  --task-id "<TASK_ID>"
```

For multiple explicit task IDs, repeat `--task-id` in submission order. For batch submissions, use the saved job file:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_download.py `
  --job-file "C:\path\to\rh100_jobs.json" `
  --output-dir "C:\Users\ghost\Desktop\12345"
```

The downloader polls until all tasks reach a terminal state or the 30-minute default wait limit. It keeps successful downloads when another task fails and reports the failed task IDs.

Use `--output-dir` when the user specifies an exact destination folder; otherwise the default remains `Desktop/<first-taskId>`.

Defaults are `1:1` and `2k`. Use `--instance-type default` for Standard, `plus` for Plus, or `none` for Lite auto-scheduling.

## Batch mode

For multiple text-to-image variants, use the dedicated batch runner. It submits all variants through the G-2 text-to-image endpoint, saves task IDs, reports the task page link, and never opens, polls, or downloads results:

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_t2i_batch.py `
  --variants 4 `
  --prompt-file "C:\path\to\prompt.txt" `
  --job-file "C:\path\to\rh100_t2i_jobs.json"
```

For many source images or multiple variants, use the bundled batch runner. It concurrently uploads and submits tasks, stores task IDs in `rh100_jobs.json`, prints the first `taskId` and bill-task link, and stops. It never opens, polls, or downloads results until the user confirms.

```powershell
python C:\Users\ghost\.codex\skills\rh100-t2i-i2i\scripts\rh100_i2i_batch.py submit `
  --image "C:\path\to\image-1.jpg" `
  --image "C:\path\to\image-2.jpg" `
  --variants 2 `
  --prompt-file "C:\path\to\prompt.txt" `
  --job-file "C:\path\to\rh100_jobs.json" `
  --concurrency 14
```

Read [references/api.md](references/api.md) for endpoint fields and known limits.

