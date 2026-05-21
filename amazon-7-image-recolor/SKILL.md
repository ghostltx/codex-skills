---
name: amazon-7-image-recolor
description: Recolor Amazon seven-image listing sets to match a target product reference image. Use when the user provides Amazon product images and a target product color/material reference, and asks to change product color, generate same-color variants, match a target product color, or keep material, texture, structure, layout, text, props, and lighting unchanged while recoloring the main and companion products.
---

# Amazon 7 Image Recolor

## Core Rule

Use the target product reference as the color and material source, not as a layout source. Recolor every matching product and companion product in the Amazon seven-image set to the target product's visible finish while preserving the original seven images.

Preserve structure, geometry, camera angle, crop, text, icons, dimensions, background, people, props, shadows, highlights, hardware, labels, and existing product texture. Do not redesign, regenerate, simplify, or restyle the listing.

## Required Inputs

Before generating or editing, identify:

- The seven source listing images.
- The target product reference image.
- Which objects are part of the sellable product set.
- Which objects must not change.
- Output format, size, naming, and save location if the user specifies them.

If the user does not specify the sellable product set, infer it from the listing context and state the assumption briefly. For furniture sets, recolor the main product and all matching companion products such as side tables, paired chairs, folded versions, and thumbnail-scene duplicates.

## Workflow

1. Inspect the seven source images and list all product appearances, including close-ups, folded views, lifestyle scenes, thumbnails, multiple chairs, and companion items.
2. Inspect the target reference image and infer its finish: dominant color, undertone, highlight behavior, dark areas, texture visibility, grain contrast, surface sheen, and material variation.
3. Build an edit instruction that applies the target finish only to product surfaces from the source images.
4. If changing a blue product to black, explicitly require removal of all blue paint, blue edge highlights, blue reflected light, and blue anti-aliased product edges. This is a common failure mode.
5. Preserve non-target elements exactly: text, icons, dimension lines, people, clothing, pillows, cups, plants, background scenes, screws, chains, metal badges, transparent glass, and drinks.
6. Generate or edit the full set consistently so every product appearance uses the same target finish.
7. Review results for color consistency, texture retention, structural drift, text damage, background contamination, blue highlight remnants, and over-darkening or flat recolor.

For detailed QA language and prompt blocks, read `references/recolor-spec.md`.

## Prompt Pattern

Use this structure when preparing an image-generation or image-editing prompt:

```text
Use the target product reference image only as the color and material reference.
Recolor all sellable product surfaces and companion product surfaces in the provided Amazon listing image to match the target product's finish.
Preserve the source image composition, product structure, geometry, wood-look texture, grain direction, lighting, highlights, shadows, hardware, text, icons, dimension lines, people, props, background, and layout.
Do not alter non-product elements. Do not redraw the product. Do not flatten the material into a solid color. Keep realistic texture, grain contrast, surface sheen, and light/dark variation from the source image.
```

Adapt "product surfaces" to the actual product, such as Adirondack chair surfaces, matching side table surfaces, folded chair surfaces, or close-up slats.

For blue-to-black product recolors, add:

```text
Remove every blue paint remnant, blue edge highlight, blue reflection, and blue anti-aliased product edge from the product surfaces only.
Do not recolor blue non-product elements such as denim, icons, text, sky, glass reflections, or background decor.
```

## Color Matching Guidance

Match the target reference's visual finish rather than a single sampled color. For black wood-grain products, avoid pure black fill. Keep visible charcoal-black and gray-black wood grain, edge highlights, darker recesses, realistic sheen, and the source image's existing texture.

For bright pale aqua / baby-blue turquoise plastic-wood furniture, avoid letting the recolor become dark teal, peacock blue, navy-leaning cyan, gray-blue, dusty blue, or heavily contrasted blue. Describe and generate the finish as a bright, airy, high-value pale aqua blue with soft white-tinted highlights, low-contrast shadows, and very pale whitish wood-grain lines. The visible board faces should be lighter and cleaner than the recessed grooves. Wood grain must read as subtle white-tinted highlight grain, not dark blue grain, gray grain, aged painted wood, or rough weathered texture. Recessed grooves and edges may be slightly deeper aqua, but they should not become dark blue. Keep the finish clean, sunlit, smooth, lightly saturated, and closer to a bright light sky-aqua plastic-wood product photo than a saturated cyan paint job.

For black-over-blue furniture, prefer a semantic image-editing or image-to-image workflow when local pixel recolor leaves blue highlights or when the product overlaps people, clothing, text, icons, or props. Pixel masking is acceptable for simple isolated product shots, but do not ship outputs with visible blue remnants on sellable surfaces.

When the target reference shows a material finish, transfer:

- Overall color family and undertone.
- Highlight and shadow behavior.
- Grain or texture contrast.
- Surface sheen and roughness.
- Variation across boards, panels, folds, and curved edges.

For pale aqua targets, add prompt language like:

```text
Recolor the product surfaces to match the reference chair's bright pale aqua blue finish. Use a main board-face color around RGB(105-115, 185-195, 215-225), centered near RGB(109, 189, 220) / HSV hue about 196 degrees. The finish is a light baby-blue turquoise / sky-aqua plastic-wood color with high brightness, clean saturation, soft low-contrast shadows, and very pale whitish wood-grain lines. The grain should look slightly lighter than the base color, like soft white highlight grain, not darker blue/gray texture. Recessed grooves and slat gaps may be deeper aqua around RGB(55-90, 135-170, 165-200), but broad board faces must remain bright and clean. Keep the finish airy, smooth, and sunlit. Avoid dark teal, saturated cyan, gray-blue, dusty blue, navy undertones, washed-out white pastel, heavy contrast, rough weathered texture, or overly deep shadows.
```

Do not transfer the target image's camera angle, product shape, text, background, crop, or scene.

## Output Expectations

Generate one recolored output per source image unless the user asks for more variants. Keep original dimensions by default. Name outputs clearly by target finish and source order, for example `black-woodgrain-01.png` through `black-woodgrain-07.png`.

When multiple target references are supplied, process each target finish as a separate full seven-image set and keep naming distinct.
