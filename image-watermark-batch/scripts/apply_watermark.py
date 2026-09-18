#!/usr/bin/env python3
"""Batch-apply a transparent PNG watermark to image files."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageOps


SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".bmp"}


def iter_images(input_dir: Path, recursive: bool) -> Iterable[Path]:
    pattern = "**/*" if recursive else "*"
    for path in sorted(input_dir.glob(pattern)):
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
            yield path


def iter_input_paths(paths: list[Path], recursive: bool) -> Iterable[Path]:
    seen: set[Path] = set()
    for path in paths:
        if path.is_dir():
            candidates = iter_images(path, recursive)
        elif path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
            candidates = [path]
        else:
            candidates = []

        for candidate in candidates:
            resolved = candidate.resolve()
            if resolved not in seen:
                seen.add(resolved)
                yield candidate


def output_path_for(src: Path, output_dir: Path | None, suffix: str, output_format: str) -> Path:
    base_dir = output_dir if output_dir is not None else src.parent
    extension = ".png" if output_format == "png" else src.suffix
    return base_dir / f"{src.stem}{suffix}{extension}"


def composite_watermark(src: Path, watermark: Image.Image, dst: Path, padding: int, output_format: str) -> None:
    with Image.open(src) as original:
        original = ImageOps.exif_transpose(original)
        original_mode = original.mode
        base = original.convert("RGBA")

        x = max(base.width - watermark.width - padding, 0)
        y = max(base.height - watermark.height - padding, 0)
        base.alpha_composite(watermark, (x, y))

        dst.parent.mkdir(parents=True, exist_ok=True)
        if output_format == "png" or dst.suffix.lower() == ".png":
            base.save(dst, format="PNG", compress_level=0)
        elif dst.suffix.lower() in {".jpg", ".jpeg"}:
            base.convert("RGB").save(dst, quality=100, subsampling=0)
        else:
            save_image = base if "A" in original_mode or dst.suffix.lower() == ".webp" else base.convert("RGB")
            save_image.save(dst)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply a PNG watermark to every image in a directory.")
    parser.add_argument("paths", nargs="*", type=Path, help="Image files or directories, useful for drag-and-drop scripts.")
    parser.add_argument("--watermark", required=True, type=Path, help="Transparent PNG watermark path.")
    parser.add_argument("--input-dir", type=Path, help="Directory containing source images.")
    parser.add_argument("--output-dir", type=Path, help="Optional output directory. Defaults to source directory.")
    parser.add_argument("--padding", type=int, default=20, help="Right and bottom padding in pixels.")
    parser.add_argument("--suffix", default="-ai generated", help="Filename suffix inserted before extension.")
    parser.add_argument(
        "--output-format",
        choices=["png", "original"],
        default="original",
        help="original keeps the source extension. png saves without additional lossy compression.",
    )
    parser.add_argument("--recursive", action="store_true", help="Process subdirectories too.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing generated output files.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.padding < 0:
        raise SystemExit("--padding must be 0 or greater")
    if not args.watermark.is_file():
        raise SystemExit(f"Watermark not found: {args.watermark}")
    if args.input_dir and not args.input_dir.is_dir():
        raise SystemExit(f"Input directory not found: {args.input_dir}")
    if not args.input_dir and not args.paths:
        raise SystemExit("Provide --input-dir or drag image files/folders onto the launcher.")

    watermark = Image.open(args.watermark).convert("RGBA")

    processed = 0
    skipped = 0
    failed: list[tuple[Path, str]] = []

    input_paths = list(args.paths)
    if args.input_dir:
        input_paths.append(args.input_dir)

    for src in iter_input_paths(input_paths, args.recursive):
        if src.stem.endswith(args.suffix):
            skipped += 1
            continue

        dst = output_path_for(src, args.output_dir, args.suffix, args.output_format)
        if dst.exists() and not args.overwrite:
            skipped += 1
            continue

        try:
            composite_watermark(src, watermark, dst, args.padding, args.output_format)
            processed += 1
            print(f"OK {src} -> {dst}")
        except Exception as exc:  # Keep batch work moving while surfacing failures.
            failed.append((src, str(exc)))

    print(f"processed={processed} skipped={skipped} failed={len(failed)}")
    for src, message in failed:
        print(f"FAILED {src}: {message}")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
