---
name: create-psd
description: Rebuild an uploaded/product/reference image as a layered Photoshop PSD using a JSON Bridge workflow. Use when the user asks to create, reconstruct, rebuild, or output a layered PSD/Photoshop file from an image, including editable text layers, isolated visual element layers, transparent PNG intermediates, SVG text reconstruction, manifest.json, and final PSD delivery. Default image-generation route is RH100-I2I / RunningHub enterprise image-to-image, default resolution is 4k, and final delivery should be a single PSD unless the user requests otherwise.
---

# Create PSD

Use this skill to rebuild an input image into a layered Photoshop PSD. Default to `RH100-I2I` for all image-generation / image-editing steps and default to `4k` output.

## Integrated RH100-I2I Runtime

This skill contains its own RH100-I2I instructions and client scripts. Do not require a separate skill invocation.

### API Facts

- Submit endpoint: `POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/image-to-image`
- Query endpoint: `POST https://www.runninghub.cn/openapi/v2/query`
- Upload endpoint: `POST https://www.runninghub.cn/openapi/v2/media/upload/binary`
- Auth: `Authorization: Bearer <RUNNINGHUB_API_KEY>`
- `imageUrls`: required, max 10 images, each image max 30 MB
- `prompt`: required, 1 to 20000 characters
- `resolution`: required, enum `1k`, `2k`, `4k`; default to `4k`
- `aspectRatio`: optional but should match the source image (`1:1`, `3:4`, `4:5`, `9:16`, etc.)
- `instanceType`: use `default` for Standard unless user requests `plus`; Lite omits `instanceType`
- Result URLs expire in 24 hours; download immediately when `SUCCESS`

### RH100-I2I Execution Contract

For local inputs:

1. Upload each local image with `scripts/rh100_i2i.py --image`.
2. Submit the task with uploaded `imageUrls`, prompt text, `aspectRatio`, `resolution`, and `instanceType`.
3. Read `taskId` from the submit response.
4. Poll `POST /query` until `SUCCESS` or `FAILED`.
5. Download every `results[].url` immediately into the job folder.

Use single-task script for one-off generation:

```powershell
python C:\Users\ghost\.codex\skills\create-psd\scripts\rh100_i2i.py `
  --image "C:\path\to\input.png" `
  --prompt "ASCII English prompt text" `
  --aspect-ratio "3:4" `
  --resolution "4k" `
  --instance-type "default" `
  --out-dir "C:\path\to\job\stage1" `
  --wait `
  --poll-seconds 10 `
  --max-wait-seconds 120
```

Use batch script when generating multiple PSD element layers:

```powershell
python C:\Users\ghost\.codex\skills\create-psd\scripts\rh100_i2i_batch.py submit `
  --image "C:\path\to\input.png" `
  --prompt-file "C:\path\to\prompt.txt" `
  --variants 1 `
  --concurrency 4 `
  --resolution "4k" `
  --instance-type "default" `
  --out-dir "C:\path\to\job\stage1" `
  --job-file "C:\path\to\job\rh100_jobs.json"

python C:\Users\ghost\.codex\skills\create-psd\scripts\rh100_i2i_batch.py poll `
  --job-file "C:\path\to\job\rh100_jobs.json" `
  --out-dir "C:\path\to\job\stage1" `
  --max-poll-seconds 60
```

Default Codex cadence for batches:

- Submit all tasks first.
- Wait about 60 seconds before first poll.
- Run up to 2 additional short polls at about 30-second intervals.
- If still incomplete, report partial progress and resume later with the same `rh100_jobs.json`; do not restart jobs.

### RH100-I2I Billing Notes

- Lite: ¥0.4/hour, system auto-scheduled; omit `instanceType`.
- Standard: ¥4/hour, 24 GB VRAM; set `instanceType` to `default`.
- Plus: ¥6/hour, 48 GB VRAM; set `instanceType` to `plus`.
- Billing is based on accumulated task runtime across concurrent tasks, not wall-clock duration.
- If responses include `thirdPartyConsumeMoney`, treat it as the usable cost field when official `consumeMoney` / `consumeCoins` are null.

## Speed Defaults

Default to a fast 4K PSD rebuild unless the user explicitly asks for ultra-detailed layer separation.

- Cap Stage 1 RH100-I2I calls at 4 by default: `background_clean`, `primary_subject_group`, `foreground_object_group`, and `icons_or_logo_group` when present.
- Treat repeated objects, small decorations, shadows, highlights, water, plants, and hard-to-isolate details as part of the nearest group or background.
- Generate all Stage 1 prompts first and submit them as a batch when there is more than one RH task.
- Retry only critical failed layers. Do not retry minor drift, small pollution, or details that can be locally masked from RH output.
- Skip OCR entirely when the source has no non-logo text.
- Use manual text transcription from visible source text when there are only a few obvious lines; use OCR only for dense or uncertain text.
- Install `ag-psd` / `canvas` only if missing in the job folder or current workspace.
- Keep one preview/contact sheet for QA; do not make multiple review sheets unless a failure is visible.
- Prefer “good editable PSD quickly” over perfect atomized reconstruction unless the user requests maximum fidelity.

Use detailed mode only when the user says: `精细分层`, `所有元素单独`, `尽量每个元素`, `高保真PSD`, `不要省步骤`, or similar.

## Non-Negotiable Defaults

- Use the bundled RH100-I2I client scripts inside this skill for generation steps; do not load or call the separate `RH100-I2I` skill.
- Use `resolution "4k"` unless the user explicitly asks for another resolution.
- Use JSON Bridge mode:
  1. RH100-I2I generates non-text element white-background images.
  2. Python handles local copy, transparency, OCR/inspection, validation, and UTF-8 `manifest.json`.
  3. Node.js reads only `manifest.json` to compose the PSD.
- Do not pass Chinese strings through PowerShell arguments, pipes, or inline command arguments. Put prompts, layer names, and text into UTF-8 files or JSON, then read those files.
- Preserve user-uploaded local image paths when available. Do not base64-encode images unless no local path is available or a tool requires it.
- Final user-facing deliverable goes under `C:/Users/ghost/Documents/Codex/2026-07-03/w/outputs` or the active thread `outputs` directory.
- Intermediate files stay under `work/<job-name>/` and are not final deliverables.

## Workflow

### 1. Set Up Workspace

- Create `work/create_psd_<slug>/` with subfolders: `inputs/`, `prompts/`, `stage1/`, `assets/`, `scripts/`, `qa/`.
- Copy the source image(s) into `inputs/` using ASCII filenames.
- Record source size and target 4K canvas in `source_info.json`.
- If the user asks final PSD to remain original size, do so; otherwise default final PSD canvas to the RH100-I2I 4K output size.

### 2. Split Non-Text Elements

Default fast mode: list no more than 4 independent non-text visual elements. Detailed mode: list no more than 10. Prefer meaningful movable groups:

- Background / scene without editable text.
- Primary subject group, including attached shadows/reflections when separating them would add RH calls.
- Foreground object group when it has independent movement value.
- Logos, trademarks, wordmarks, icon groups, badges, frames, and UI panels as grouped image elements; do not OCR logo-internal text.
- Treat repeated, symmetric, small, decorative, or hard-to-isolate elements as one group or part of the background.

### 3. Stage 1 RH100-I2I Generation

For each selected non-text group, create an English prompt file in `prompts/`. Submit using this skill's bundled RH100-I2I scripts with:

- Source image as the first image.
- Optional reference images after the source image when requested.
- `--resolution "4k"`.
- Aspect ratio matching the source image.
- `--instance-type "default"` unless user asks otherwise.
- Full-canvas output, never cropped element output.

Prompt requirements:

- For background: keep the full canvas and remove editable text plus separately layered foreground elements.
- For element isolation: preserve only the target element in its original absolute position, scale, perspective, orientation, visual center, and rough bounding box; replace everything else with pure white background.
- For replacement/edit tasks: keep all untargeted image content unchanged and replace only the named target.

Use prompt files instead of Chinese command arguments. For 2+ RH tasks, prefer `rh100_i2i_batch.py --prompt-file` so uploads/polls are coordinated. Use single-task `rh100_i2i.py` only for one generation or a targeted retry.

### 4. Stage 1 Validation

Create one contact sheet and inspect it before proceeding:

- White-background element images must contain only the target element.
- Background must remove editable text and separately layered elements.
- Canvas must match the 4K aspect ratio and not be cropped.
- Position/scale should remain close enough for absolute-coordinate composition.
- Retry only critical layers whose failure prevents a usable PSD.
- Do not retry minor drift, small background pollution, or imperfections that can be locally cropped/masked from the RH-generated output without using the original image as the segmentation source.

### 5. Local Transparency And OCR

- Transparentize RH white-background element layers locally.
- Remove only edge-connected pure white background by default.
- Protect white/bright subject details, highlights, packaging, steam, smoke, and translucent edges.
- For white matte fringe, apply a defringe/decontamination pass before PSD composition.
- If the source has visible non-logo text, transcribe obvious short text manually first; use local OCR only for dense, uncertain, or many-line text.
- Save each text line as an independent SVG `<text>` node and an independent PSD Type Layer.
- Store true Unicode in `manifest.json` and `text_layers.svg` using UTF-8.
- Stop text flow if `?`, replacement characters, mojibake, squares, or missing glyphs appear.

### 6. Manifest Contract

`manifest.json` must include at minimum:

```json
{
  "canvas": { "width": 3584, "height": 4800, "colorMode": "RGB" },
  "source": "absolute/source/path.png",
  "layers": [
    { "type": "image", "name": "背景_完整场景", "path": "absolute/path.png", "x": 0, "y": 0, "width": 3584, "height": 4800, "opacity": 255 }
  ],
  "texts": [
    { "name": "文字_标题_Example", "kind": "title", "content": "Example", "x": 100, "y": 120, "fontSize": 80, "font": "Arial-BoldMT", "color": "#111111", "weight": "bold" }
  ]
}
```

Layer names should be Simplified Chinese. Text layers must use `文字_类型_具体内容`.

### 7. PSD Composition

- Node.js must read `manifest.json` and compose the PSD.
- Use `ag-psd` + `canvas` when available; install locally in the job folder if missing.
- PSD layer order: full background at bottom, transparent element layers above, then editable text layers.
- Keep all layers in absolute canvas coordinates.
- Provide one composite preview for internal QA, but deliver only the PSD unless user asks for more.

### 8. Final QA

Before final response, verify:

- PSD opens/readbacks with expected width/height.
- PSD includes background, multiple non-text image layers, and each text line as an editable Type Layer.
- SVG text nodes correspond one-to-one with PSD Type Layers.
- No replacement characters or mojibake in layer names/text.
- Transparent layers do not have obvious white fringe, accidental holes, or deleted subject whites.
- Final `outputs` contains only intended user-facing deliverable(s).

## Useful Bundled Scripts

- `scripts/prepare_workspace.py`: copy local inputs into an ASCII job folder and write `source_info.json`.
- `scripts/alpha_from_white.py`: transparentize edge-connected white backgrounds and optional defringe.
- `scripts/build_psd_from_manifest.js`: compose a PSD from `manifest.json` using `ag-psd` and `canvas`.

Copy these scripts into the job folder or run them from the skill folder with explicit paths.

