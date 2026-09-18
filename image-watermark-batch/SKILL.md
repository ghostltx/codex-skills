---
name: image-watermark-batch
description: Batch apply a transparent PNG watermark to every image in a directory, especially for AI-generated disclosure marks. Use when the user provides a watermark PNG and a folder of images, asks to place the watermark at the bottom-right with padding, and wants output filenames to append "-ai generated".
---

# Image Watermark Batch

## Workflow

Use `scripts/apply_watermark.py` for deterministic batch processing.

Default behavior:
- Reads a transparent PNG watermark.
- Processes image files in one target directory, non-recursively.
- Places the watermark at the bottom-right.
- Uses 20px right and bottom padding unless the user specifies another padding.
- Writes new files next to the originals.
- Appends `-ai generated` before the extension.
- Keeps the original file extension by default.
- Skips files whose stem already ends with `-ai generated`.
- Does not overwrite existing output files unless `--overwrite` is passed.

Run:

```powershell
python "C:\Users\ghost\.codex\skills\image-watermark-batch\scripts\apply_watermark.py" --watermark "C:\path\to\watermark.png" --input-dir "C:\path\to\images"
```

For Windows drag-and-drop, use `C:\Users\ghost\Desktop\拖拽图片加AI水印.bat`; drag image files or folders onto it.

Useful options:
- `--padding 20`
- `--suffix "-ai generated"`
- `--output-dir "C:\path\to\output"` to write elsewhere.
- `--output-format original` to keep original extensions, or `--output-format png` for no additional lossy compression.
- `--overwrite` to replace existing generated outputs.
- `--recursive` only when the user explicitly asks for subfolders.

## Verification

After running, report:
- Number of processed, skipped, and failed files.
- Output path pattern.
- One or two sample output filenames.

For a visual spot check, open or inspect at least one generated file when practical.
