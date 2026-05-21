---
name: merge-split-layers-into-psd
description: Rebuild a Photoshop-editable PSD from split layer images, preserving the original canvas size, per-layer alignment, element size, filename or manifest z-order, and independent full-canvas RGBA raster layers. Use when the user provides an original reference image plus all split layer images and asks to merge, restore, reconstruct, combine, or package them into a layered PSD with edge-connected white background removal and Photoshop compatibility.
---

# Merge Split Layers Into PSD

## Overview

Use this skill to convert a set of already-split layer images into one layered PSD. The output must keep every input image as a separate editable full-canvas RGBA raster layer and must composite back to the original reference image as closely as possible.

## Required Inputs

- Original reference image: defines RGB canvas width and height, and is used for visual validation.
- Split layer images: one image per intended PSD layer.
- Layer order source: use a manifest with `z_index` when present; otherwise sort by numeric filename index. Interpret order as bottom to top.
- Optional layer names: use manifest names when present; otherwise use input filenames without destructive renaming.

If the layer order cannot be inferred from filenames or a manifest, stop and ask for exactly that missing ordering information.

## PSD Construction Rules

- Create an RGB PSD with canvas size exactly matching the original reference image.
- Add one independent RGBA raster layer for each split layer image.
- Keep every layer at full canvas size. Do not trim bounds, crop, resize, reposition, flatten, or bake fake transparency.
- Preserve the relative position and element size from the input layer images.
- Preserve z-order from bottom to top using manifest `z_index` or numeric filename fallback.
- Name PSD layers from manifest names or input filenames.
- Ensure the result opens in Photoshop or Photopea with layers individually movable, hideable, scalable, and adjustable.

## White Background Removal

When background removal is requested or implied by this skill:

- Treat the source background as solid white.
- Remove only white pixels connected to the canvas edges.
- Use a white threshold of 248 by default.
- Preserve internal white details, highlights, white text, and enclosed white shapes.
- Apply light edge softening to avoid harsh cutouts, without expanding or shifting layer content.
- Do not remove isolated interior whites merely because they are near-white.

Implementation hint: use flood fill or connected-component masking from the four image edges over pixels where all RGB channels are at or above the threshold; convert only that connected mask to alpha.

## Workflow

1. Inspect the original reference dimensions and color mode.
2. Collect all split layer images and any manifest.
3. Sort layers bottom to top by manifest `z_index`; if absent, sort by numeric filename index.
4. Normalize every layer image to RGBA, but do not resize or reposition it.
5. Verify each layer image already matches the reference canvas size. If a layer differs, do not silently scale it; report the mismatch.
6. Remove edge-connected white background from each layer while preserving internal whites.
7. Write a layered PSD with full-canvas layer bounds and original layer order.
8. Export or render a composite preview and compare it against the original reference.

## Validation

Before claiming completion, verify:

- PSD canvas size equals the original image size.
- Layer count equals the number of split layer images.
- Each PSD layer is a separate raster layer with full-canvas dimensions.
- No layer offset, resize, trim, or accidental flattening occurred.
- Edge-connected white backgrounds are transparent; internal whites remain visible.
- Composite preview visually matches the original reference as closely as the split layers allow.

## Common User Requests

- "combine these split layers into a PSD"
- "rebuild an editable PSD from split layers by filename order"
- "remove white backgrounds but preserve white text and highlights"
- "use the original image size for the layered PSD"
- "merge split layer images into Photoshop PSD"
