#!/usr/bin/env python3
"""Drag-and-drop Windows app entry point with bundled watermark asset."""

from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path

from apply_watermark import main as watermark_main


def bundled_resource_path(name: str) -> Path:
    bundle_dir = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return bundle_dir / name


def pause() -> None:
    try:
        input("Press Enter to exit...")
    except EOFError:
        pass


def run() -> int:
    if len(sys.argv) < 2:
        print("Drag image files or folders onto this EXE.")
        print("Rule: bottom-right watermark, 20px right/bottom padding, append -ai generated.")
        pause()
        return 1

    bundled_watermark = bundled_resource_path("ai_generated_watermark.png")
    if not bundled_watermark.is_file():
        print(f"Bundled watermark not found: {bundled_watermark}")
        pause()
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        watermark = Path(tmp) / "ai_generated_watermark.png"
        shutil.copyfile(bundled_watermark, watermark)

        sys.argv = [
            sys.argv[0],
            "--watermark",
            str(watermark),
            "--padding",
            "20",
            "--output-format",
            "original",
            *sys.argv[1:],
        ]
        code = watermark_main()

    print()
    pause()
    return code


if __name__ == "__main__":
    raise SystemExit(run())
