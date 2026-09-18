---
name: synthetic-performer-label
description: Add the XMP metadata keyword `contains-synthetic-performer` to user-provided image files and save a marked copy with the Chinese suffix `???` before the extension. Use whenever the user uploads or references an image and asks to add the AI-generated-person or synthetic-performer label.
---

# Synthetic Performer Label

Add the standard XMP keyword `contains-synthetic-performer` to user-provided images and save a marked copy.

## Workflow

1. Prefer the local path supplied by the user; do not convert images to base64.
2. Run `scripts/add_synthetic_performer.py` for each explicitly supplied image.
3. Append the Chinese suffix `???` before the extension: `photo.png` becomes `photo???.png`.
4. Never overwrite the source. Stop if the target already exists.
5. Verify that the output exists and contains the exact keyword `contains-synthetic-performer`.
6. Return the absolute output path and state that the source is unchanged.

## Command

```powershell
python scripts/add_synthetic_performer.py "C:\path\to\image.png"
```

Optional output path:

```powershell
python scripts/add_synthetic_performer.py "C:\path\to\image.png" --output "C:\path\to\custom-name.png"
```

## Rules

- Supports PNG and JPEG/JPG using embedded XMP metadata.
- Does not add visible text, watermarks, or pixel changes.
- Creates a new marked copy even if the source already has the keyword.
- Stops with a clear error for missing files, unsupported formats, or existing targets.

## Verification

Use `--verify` to validate:

```powershell
python scripts/add_synthetic_performer.py "C:\path\to\image???.png" --verify
```
