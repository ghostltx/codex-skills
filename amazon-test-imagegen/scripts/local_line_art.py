#!/usr/bin/env python3
"""Create a deterministic local line-art constraint image from a product photo."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps


def make_line_art(input_path: Path, output_path: Path, threshold: int = 38) -> None:
    image = Image.open(input_path).convert("RGB")

    # Smooth small texture first so wood grain does not dominate the constraint.
    gray = ImageOps.grayscale(image)
    smooth = gray.filter(ImageFilter.MedianFilter(size=5))
    edges = smooth.filter(ImageFilter.FIND_EDGES)
    edges = ImageOps.autocontrast(edges)

    # FIND_EDGES gives bright strokes on dark ground. Invert to black strokes on white.
    inverted = ImageOps.invert(edges)
    line_art = inverted.point(lambda px: 0 if px < 255 - threshold else 255, mode="1")
    line_art = line_art.convert("RGB")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    line_art.save(output_path, quality=95)


def main() -> int:
    parser = argparse.ArgumentParser(description="Create local line-art constraints.")
    parser.add_argument("input", type=Path, help="Source product image")
    parser.add_argument("output", type=Path, help="Output line-art image")
    parser.add_argument(
        "--threshold",
        type=int,
        default=38,
        help="Edge threshold, higher values keep fewer lines",
    )
    args = parser.parse_args()

    make_line_art(args.input, args.output, args.threshold)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
