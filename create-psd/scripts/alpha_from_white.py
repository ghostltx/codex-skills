#!/usr/bin/env python3
"""Transparentize edge-connected white background from RH100-I2I white-canvas layers."""
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--threshold", type=int, default=246)
    parser.add_argument("--defringe", action="store_true")
    return parser.parse_args()


def edge_white_to_alpha(image: Image.Image, threshold: int) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    queue: deque[tuple[int, int]] = deque()
    seen = bytearray(width * height)

    def is_white(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        return alpha > 0 and red >= threshold and green >= threshold and blue >= threshold

    def push(x: int, y: int) -> None:
        index = y * width + x
        if not seen[index] and is_white(x, y):
            seen[index] = 1
            queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= next_x < width and 0 <= next_y < height:
                push(next_x, next_y)

    for y in range(height):
        for x in range(width):
            if seen[y * width + x]:
                red, green, blue, alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    return image


def defringe_white_matte(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    edge_min = alpha.filter(ImageFilter.MinFilter(9))
    pixels = image.load()
    edge_pixels = edge_min.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha_value = pixels[x, y]
            if alpha_value == 0 or edge_pixels[x, y] >= 250:
                continue
            max_channel = max(red, green, blue)
            min_channel = min(red, green, blue)
            average = (red + green + blue) / 3
            saturation = max_channel - min_channel
            if average > 205 and saturation < 38:
                factor = max(0.0, min(1.0, (255 - average) / 55.0))
                new_alpha = int(alpha_value * factor)
                if new_alpha < 16:
                    pixels[x, y] = (red, green, blue, 0)
                else:
                    target = int(max(125, min(185, average - 35)))
                    pixels[x, y] = (min(red, target), min(green, target), min(blue, target), new_alpha)
            elif average > 185 and saturation < 32:
                target = int(average - 22)
                pixels[x, y] = (min(red, target), min(green, target), min(blue, target), alpha_value)
    return image


def main() -> None:
    args = parse_args()
    image = Image.open(args.input).convert("RGBA").resize((args.width, args.height), Image.Resampling.LANCZOS)
    image = edge_white_to_alpha(image, args.threshold)
    if args.defringe:
        image = defringe_white_matte(image)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)


if __name__ == "__main__":
    main()
