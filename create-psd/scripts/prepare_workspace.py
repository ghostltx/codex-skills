#!/usr/bin/env python3
"""Prepare an ASCII workspace for Create PSD jobs."""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-dir", required=True)
    parser.add_argument("--input", action="append", required=True)
    parser.add_argument("--target-long-edge", type=int, default=4800)
    return parser.parse_args()


def target_size(width: int, height: int, long_edge: int) -> tuple[int, int]:
    if width >= height:
        scale = long_edge / width
    else:
        scale = long_edge / height
    return round(width * scale), round(height * scale)


def main() -> None:
    args = parse_args()
    job_dir = Path(args.job_dir)
    inputs_dir = job_dir / "inputs"
    for name in ("inputs", "prompts", "stage1", "assets", "scripts", "qa"):
        (job_dir / name).mkdir(parents=True, exist_ok=True)

    records = []
    for index, source_text in enumerate(args.input, start=1):
        source = Path(source_text)
        suffix = source.suffix.lower() or ".png"
        target = inputs_dir / f"input_{index:02d}{suffix}"
        shutil.copy2(source, target)
        with Image.open(target) as image:
            tw, th = target_size(image.width, image.height, args.target_long_edge)
            records.append(
                {
                    "source": str(source),
                    "path": str(target),
                    "width": image.width,
                    "height": image.height,
                    "mode": image.mode,
                    "targetWidth": tw,
                    "targetHeight": th,
                }
            )
    (job_dir / "source_info.json").write_text(
        json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(records, ensure_ascii=True))


if __name__ == "__main__":
    main()
