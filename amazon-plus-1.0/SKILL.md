---
name: amazon-plus-1.0
description: Unified Amazon US ecommerce product-image generation workflow. Use when the user provides product photos and asks for Amazon listing images, product main images, secondary images, detail-page images, A+ content, dimension images/尺寸图, 6-image sets, 10-image sets, built-in Image Gen generation, or RunningHub RH-GPT-IMAGE-2-I2I batch generation. Always use Fantui planning and local line-art constraints before generation. Ask the user to choose A = built-in Image Gen or B = RunningHub RH I2I when the generation method is not specified.
---

# Amazon Plus 1.0

## Goal

Create Amazon US ecommerce images from one product or same-product reference image set while preserving product identity, dimensions, and marketplace-appropriate conversion logic.

This skill merges the intended capabilities of `amazon-test-imagegen` and `amazon-batch-imagegen` into a new standalone workflow. Do not modify those original skills when using this skill.

## Required Generation Mode Question

When the user has not already specified the generation method, ask exactly this one question before final image generation:

```text
请选择生图方式：A = 内置 Image Gen；B = RunningHub RH I2I。直接回复 A 或 B。
```

Interpretations:

- A: use built-in Image Gen for final ecommerce image generation.
- B: use RunningHub RH-GPT-IMAGE-2-I2I for final ecommerce image generation.

Both modes must use local line-art constraints. For Mode B, send the original product image(s) plus the matching local line-art image(s) to RH I2I together as reference inputs.

## Required Intake

Before final image generation, make sure these are known:

- Product image(s): use attached images or local paths supplied by the user. Multiple same-product angles/details should be treated as one product identity reference set.
- Product identity/category: infer from images only when visually clear; otherwise ask.
- Usage scenario: required for lifestyle, scale, assembly, or A+ scene planning when not obvious.
- Product dimensions: required for dimension images, scale images, assembly images, and realistic lifestyle scenes.
- Generation mode: A or B.
- Count/layout: use the user's requested count; otherwise default to a 10-image Amazon listing set made of 1 user-provided white-background main image plus 9 generated secondary images.
- Main image source: for 10-image listing sets, treat the user's provided white-background product image as image 1/main image by default. Do not generate the main image unless the user explicitly asks for a new main image.

If dimensions are missing and the image set needs dimension/scale truthfulness, ask the user for them before generation. Ask for any available values:

- Overall width
- Overall depth
- Overall height
- Main functional height, such as tabletop/seat/shelf height
- Expanded or folded size when relevant
- Key component size, such as sink, drawer, basket, cushion, tabletop, rail, shelf, or hardware size

If the user names a product covered by another skill, load that dimension/specification skill directly and use it as the source of truth. For example, when the user says `工具桌-水槽款` or `工具桌-基础款`, load the `工具桌` skill and use its recorded dimensions/specifications. Do not ask the user for values already present in the corresponding product skill. Do not guess or back-calculate missing measurements when the product skill says a value is unconfirmed.

## Mandatory Fantui Planning

Always invoke or follow `$fantui` before final generation, regardless of whether the user wants 6 images, 10 images, secondary images, A+ images, a main image, or dimension images.

Use Fantui output as the creative planning base, then adapt it to Amazon US listing standards and the requested image count.

## Local Line-Art Constraint Workflow

Use local image processing for line-art constraint images before final generation in both Mode A and Mode B. Do not use AI image generation to create line-art constraints.

Preferred local method:

```bash
python C:\Users\ghost\.codex\skills\amazon-test-imagegen\scripts\local_line_art.py input.jpg output-01.jpg
```

If that script is unavailable, use a local deterministic edge-detection or contour-extraction process with standard image tooling. The line-art step must be derived from the supplied product image file, not hallucinated or redrawn by a generative model.

For each product source image:

1. Create a clean line-art constraint image from the same file.
2. Save it beside the source image as `{original-file-stem}-01.jpg`.
3. Pair each source image only with its own matching line-art image.
4. Do not mix line art from one angle with a different product angle.

Line art must:

- Preserve product silhouette, proportions, angle, structure, and visible components.
- Use a white background.
- Use clean black or dark gray contour lines.
- Avoid decorative styling, shadows, labels, dimensions, icons, text, scene elements, or added accessories.

## Product Fidelity Lock

Before final generation, inspect all product references and write a short product-detail lock in the prompt or working notes. Include visible detail counts, material cues, component positions, colors, texture, hardware count, wheel count, seams, stitching, rail positions, buttons, ports, packaging cues, and any details likely to drift.

For every generated image:

- Keep the real product as the hero.
- Preserve visible structure, color, material, key proportions, silhouette, distinctive details, hardware placement, and accessories.
- Do not invent new variants, colors, logos, shapes, buttons, holes, stitching, accessories, packaging, certifications, exact specs, warranties, rankings, or performance claims.
- If a generated image changes key product details, reject or regenerate it.

## Mode A: Built-In Image Gen

Use Mode A when the user chooses `A` or explicitly asks for built-in Image Gen.

Generation references:

- Include the original product image(s).
- Include matching local line-art image(s).
- Explicitly state that the line art is a structural constraint and the original image is the product appearance reference.

Default output standards:

- Secondary images: native `1600 x 2000 px`, 4:5 vertical canvas.
- A+ modules: wide Amazon A+ banner ratio; exact `1464 x 600 px` is optional when the generated ratio and quality are acceptable.
- Main image: only generate when requested; use `2000 x 2000 px`, pure white `#FFFFFF`, no text, no props, no watermark.

Reject or regenerate any Mode A final secondary image whose original generated dimensions are not exactly `1600 x 2000 px`. Do not upscale, pad, or cover-resize secondary images to fake compliance.

## Mode B: RunningHub RH I2I

Use Mode B when the user chooses `B` or explicitly asks for RunningHub/RH I2I.

For every RH I2I task, pass both the product source image(s) and the matching local line-art constraint image(s) with `-ImagePaths`. The prompt must say the original image(s) define product color/material/detail, and the line-art image(s) constrain silhouette, structure, proportions, and angle.

RH I2I supports 1-10 reference images per task. Curate references if there are too many files, but keep at least the primary source image and its matching line art.

Use this command shape:

```powershell
& "C:\Users\ghost\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\img2img.ps1" `
  -ImagePaths "<source-image>","<matching-line-art>" `
  -Prompt "<Amazon ecommerce prompt>" `
  -OutputPath "<output-folder>\amazon_02_lifestyle_hero_4x5.png" `
  -AspectRatio "4:5" `
  -Quality "high" `
  -Resolution "2k"
```

Batching:

- Submit RH I2I tasks in parallel groups of up to 3.
- For 10-image listing sets, copy the user-provided white-background main image as image 1, then generate only images 2-10 as `2-4`, `5-7`, `8-10`.
- For 6-image or other custom sets, still use groups of up to 3.
- Image 1/main image should be the copied user-provided white-background source image unless the user explicitly requests a generated main image. It should be `1:1` square and no text when generated.
- Non-main images should usually be `4:5`, `high`, `2k`.

## Amazon Image Planning

Use the user's requested set structure when provided. Otherwise:

- Batch/listing default: 10 images total, with 1 copied user-provided white-background main image plus 9 generated secondary images.
- Main white-background image: do not generate by default. Copy the user's provided white-background product image into the final deliverable folder as image 1/main image. Generate a new main image only when the user explicitly requests it.

Suggested 10-image structure:

1. Main image: copied from the user's provided white-background product image, no generated changes.
2. Hero lifestyle: premium usage context with a believable person when appropriate.
3. Core USP: one clear buyer pain point solved visually.
4. Feature/structure: callouts, exploded view, or functional detail.
5. Material/craft: macro texture, finish, touch, durability, or workmanship.
6. Size/scale: dimension or human-context scale visualization using only known dimensions.
7. Use scenario 1: realistic everyday use.
8. Use scenario 2: aspirational or gift/lifestyle scene.
9. Detail macro: strongest visible quality detail.
10. Trust/service: packaging, included items, care, support, or brand reassurance without fake guarantees.

For images with text:

- Use concise English ecommerce copy by default unless the user requests another language.
- Use only visible or user-provided facts.
- Generic truthful labels are allowed when exact facts are unknown, such as `Compact Size`, `Easy to Use`, `Premium Finish`, or `Detail View`.
- Do not add text to main images.

Lifestyle and use-scenario images should include believable people by default when appropriate. Add animals only when naturally relevant to the product category and scene; keep them secondary to the product.

## Dimension Image Rules

For dimension images, every measurement label must name what is being measured. Do not place a bare number such as `37.4 in` without a label.

For `工具桌-水槽款`:

- The full product length label must read `Overall Length 51.2 in`.
- It must span the entire product including the right-side extension.
- `37.4 in` must be labeled `Upper Rail Length 37.4 in`.
- `37.4 in` must not be visually or textually presented as the overall length.

## Competitor Research

When network/browser access is available, search Amazon for same-category products and review about 10 leading or comparable seller image sets. Use the findings to improve the Fantui-based image plan.

Evaluate main image cleanliness, gallery structure, visual quality, conversion clarity, text quality, trust signals, and missing opportunities. Do not copy competitor brand names, logos, layouts, slogans, exact packaging, or proprietary claims.

If competitor evidence is unavailable, proceed from Fantui plus Amazon US ecommerce best practices and state the research gap in the final response.

## Output Discipline

Create one final deliverable folder. Prefer clear filenames, such as:

```text
amazon_01_main_white_2000x2000.png
amazon_02_lifestyle_hero_4x5.png
amazon_03_core_usp_4x5.png
secondary-01-lifestyle.jpg
a-plus-01-brand-banner.jpg
```

For full sets, keep final deliverables organized with `source/`, `line-art/`, and image-set folders such as `secondary/`, `a-plus/`, or `final/`.

For default 10-image listing sets:

- Create a final folder containing exactly 10 visible listing images.
- Copy the user-provided white-background main image into that final folder as image 1; do not alter it except for filename normalization unless the user asks for resizing or cleanup.
- Generate 9 secondary images and place them in the same final folder as images 2-10.
- Use filenames that preserve listing order, such as `amazon_01_main_user_white.png`, `amazon_02_lifestyle_hero_4x5.png`, through `amazon_10_trust_service_4x5.png`.
- Ensure the user can open the final folder and see all 10 listing images together: 1 copied source main image plus 9 generated images.

Before final delivery:

- Verify every final image path exists.
- For default 10-image listing sets, verify the final folder contains 10 listing images total and that image 1 is copied from the user-provided source main image.
- Report original generated pixel dimensions when available.
- State which mode was used: A built-in Image Gen or B RunningHub RH-GPT-IMAGE-2-I2I.
- Mention any known gap, such as text not verified, competitor research unavailable, or dimensions missing.

Reply in Chinese and keep the final concise.
