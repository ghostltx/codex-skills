---
name: amazon-test-imagegen
description: Amazon US ecommerce product-image generation workflow for designers. Use when the user says "测试生图", asks to test image generation for Amazon product listings, provides multiple white-background product photos from different angles, needs dimension images/尺寸图 for Amazon visuals, or needs Codex to use the built-in imagegen tool to create product-consistent Amazon secondary images, lifestyle images, detail images, or A+ visual concepts.
---

# Amazon Test Imagegen

## Core Workflow

Use local image processing for line-art constraint images. Do not use `imagegen` to generate line-art constraints.

Use the built-in `imagegen` capability only for final ecommerce image generation or image editing tasks after local line-art constraints exist.

## Required Intake Before Generation

Before generating final ecommerce images, confirm the following with the user when it is not already provided in the conversation or obvious from the supplied files:

- What the product is.
- Where or in what scenario the product is used.
- Product dimensions, preferably in inches for Amazon US outputs.
- For dimension images/尺寸图: which product-dimension skill to use.

When the image set includes a dimension image/尺寸图, ask the user which dimension/specification skill should supply the measurements before generating that image, unless the user has already named a specific dimension skill or exact dimensions in the same conversation. The user may keep product-specific dimensions in separate skills, such as `工具桌`. Use that named skill as the source of truth for measurements and dimension-image cautions.

If the user names a product that is covered by another skill, load that skill before making the dimension image. For example, when the user says `工具桌-水槽款` or `工具桌-基础款`, use the `工具桌` skill for the recorded dimensions/specifications. Do not guess or back-calculate missing measurements when the dimension skill says a value is unconfirmed.

For dimension images, every measurement label must name what is being measured. Do not place a bare number such as `37.4 in` without a label. For `工具桌-水槽款`, the full product length label must read `Overall Length 51.2 in` and span the entire product including the right-side extension. The `37.4 in` value must be labeled `Upper Rail Length 37.4 in` and must not be visually or textually presented as the overall length.

If the user only says "测试生图" or gives product photos without enough context, ask for the missing product identity, usage scenario, and dimensions before generating final listing images. Do not invent product scale for scene images with people when dimensions are missing.

For dimensions, ask for any available values:

- Overall width
- Overall depth
- Overall height
- Main functional height, such as tabletop/seat/shelf height when relevant
- Expanded or folded size when the product changes shape
- Key component size when relevant, such as sink, drawer, basket, cushion, tabletop, or shelf size

If the user does not know exact dimensions, ask for approximate dimensions or a comparable real-world scale reference. Use these dimensions in prompts for lifestyle, scale, dimension, and assembly images so people and products appear proportionally believable.

When the user says "测试生图" and provides product photos:

1. Identify every supplied white-background product image and keep the original product as the source of truth.
2. For each original image, first create a clean line-art constraint image locally from the same file. Do not use `imagegen` for this step.
3. Save each line-art image in the same folder as its original image as `{original-file-stem}-01.jpg`.
   - Example: `0.jpg` -> `0-01.jpg`
   - Example: `front.png` -> `front-01.jpg`
4. Use each original image plus its matching line-art image as a pair for later image generation. Do not mix line art from one angle with a different source angle.
5. Keep product size, proportions, geometry, color, material, visible accessories, hardware count, hardware placement, and angle consistent across generated outputs.
6. Create an `output` folder in the current project directory for final generated ecommerce images.
7. Save final generated images inside the current project directory's `output` folder.
8. Build image concepts around Amazon US listing conversion logic, not domestic ecommerce poster styling.

## Line-Art Constraint Requirements

Generate line art locally before producing final ecommerce images. Do not use AI image generation for this step.

Preferred local method:

```bash
python scripts/local_line_art.py input.jpg output-01.jpg
```

If the bundled script is unavailable, use a local deterministic edge-detection or contour-extraction process with standard image tooling. The line-art step must be derived from the supplied image file, not hallucinated or redrawn by a generative model.

The line art must:

- Preserve the product silhouette, proportions, angle, structure, and visible components from the source image.
- Use a white background.
- Use clean black or dark gray contour lines.
- Avoid decorative styling, shadows, labels, dimensions, icons, text, scene elements, or added accessories.
- Be suitable as a structural constraint image for later generation.

## Product Fidelity Lock

Before final image generation, inspect the source product images and write a short product-detail lock in the working notes or prompt. This lock must include visible detail counts, material cues, and positions that often drift during generation.

For each generated image:

- Use the source photo and its same-angle local line-art constraint together when the image is based on a specific angle.
- Preserve visible hardware count, finish, and placement. Example: if the product has four metal hooks with metallic gray/silver finish under the upper rail, do not generate five hooks or change them to black painted hooks.
- Preserve wheel count and placement, side-extension hinge/brace geometry, sink position, shelf count, leg positions, rail height, visible screws, and wood-grain color family.
- Do not add, remove, recolor, or reposition functional components unless the user explicitly requests a variant.
- If a generated image visibly changes key product details, regenerate or mark it as rejected; do not include it in the final set.

## Amazon Listing Image Set

Default to secondary images plus A+ modules. Do not generate a white-background main hero image unless the user explicitly asks for one.

Default set:

- Secondary images: 6 core Amazon secondary images.
- A+ modules: 5 wide A+ images.

Use these default export standards:

- Secondary images: must be generated natively at `1600 x 2000 px`
- A+ image modules: use the correct wide A+ aspect ratio; preserving the original imagegen output size is acceptable when the ratio is correct
- Format: prefer `JPG`

The generated image itself must be in the required pixel dimensions. Do not accept a smaller or differently shaped generated image and add white margins afterward. White-border padding is not a valid fix because it shrinks the selling content.

If the image generation tool returns a wrong size:

- For secondary images, treat any non-`1600 x 2000 px` output as a failed draft. Regenerate with a stricter prompt that explicitly says imagegen must output a native `1600 x 2000 px` canvas. Do not upscale, enlarge, pad, or cover-resize secondary images to fake compliance.
- For A+ modules, accept the imagegen original output when it has the requested wide A+ ratio and visual quality, even if the exact pixel dimensions are larger or slightly different than `1464 x 600 px`. Do not downscale A+ images unless the user explicitly asks for exact module pixels.
- Do not include a final secondary image whose original imagegen pixel dimensions differ from `1600 x 2000 px`.
- Do not replace rich ecommerce/lifestyle image generation with plain white-background layout boards just to satisfy dimensions. Dimension compliance must not destroy Amazon secondary/A+ visual quality.

For detailed structure and visual standards, read `references/amazon-us-image-structure.md`.

## Main Image Rules

Only create a main image when the user explicitly requests it.

When creating a main image:

- Export at `2000 x 2000 px`.
- Use pure white background `#FFFFFF`.
- Make the product occupy about 80% or more of the frame when appropriate for the category.
- Prefer `JPG` output.
- Emphasize real product appeal through lighting, material, composition, and realism.
- Do not add large copy, logos, watermarks, icons, borders, fake scenes, or unprovided gifts.
- Keep the image clean and compliant for Amazon US main-image expectations.

## Secondary Image Direction

Export secondary images at `1600 x 2000 px` by default.

For secondary images, prefer:

- Authentic American lifestyle scenes.
- For scene-based secondary images, prefer including realistic people, hands, or family/user interaction when appropriate so the image feels lived-in and relatable.
- Clean functional breakdowns with restrained text only when useful.
- Inch-based dimensions and human or space references for scale.
- Material and detail close-ups that create a premium feeling.
- Multi-use scenarios that help the customer imagine ownership.
- Installation, packaging, hardware, or setup images when relevant.

For every secondary-image prompt, explicitly request that imagegen output a native `1600 x 2000 px`, 4:5 vertical canvas and full-frame composition. After generation, inspect the original imagegen pixel dimensions before accepting the image. Do not use post-processing enlargement for secondary images.

Avoid crowded domestic marketplace poster layouts. Keep the visual language realistic, premium, minimal, cozy, clean, and natural. When people appear, make them authentic and secondary to the product; avoid fake posing, blocked product structure, misleading accessories, or unclear ownership of included items.

## A+ Image Direction

Generate 5 A+ images at the correct wide A+ aspect ratio by default unless the user specifies a different module count or size. Exact `1464 x 600 px` export is optional; preserving the original imagegen output is acceptable when the ratio is correct.

For A+ visuals:

- Build brand and lifestyle value instead of repeating the secondary-image set.
- Use wide banner composition with clean hierarchy.
- Keep product accuracy anchored to the original product images and line-art constraints.
- Prefer `JPG` output.

For every A+ prompt, explicitly request a wide A+ banner canvas and full-frame composition. After generation, inspect and report the original pixel dimensions. Keep the original imagegen file when the ratio and quality are acceptable; do not shrink it by default.

## Prompting Guidance

When generating prompts or images:

- Treat the product reference photos and same-angle line-art constraints as non-negotiable.
- State the intended image slot before generating: lifestyle, feature, dimension, detail, multi-scene, assembly, brand atmosphere, or A+ module.
- Use American home, backyard, kitchen, office, bedroom, garage, or outdoor contexts according to the product category.
- For lifestyle, multi-scene, scale, and assembly images, include a person, hand interaction, or family/user context whenever it improves realism and conversion value.
- When product dimensions are available, explicitly include them in prompts and describe the expected relationship to a realistic person, hand, room, patio, countertop, floor, or other scale reference.
- Prefer natural light, believable materials, real proportions, and restrained composition.
- Use English text only when the image type benefits from text, such as dimensions, feature labels, or installation callouts.
- Keep text concise and conversion-focused.

## Output Discipline

Before final generation, confirm:

- Product category
- Target customer and usage context
- Product dimensions or approximate scale reference
- Secondary image count and A+ image count
- Whether the current task is only line-art preparation or a full listing image set

Save outputs consistently:

- Line-art constraints: same folder as each original source image.
- Final generated ecommerce images: `output` folder under the current project directory.
- Prefer clear filenames that identify the slot, such as `secondary-01-lifestyle.jpg`, `secondary-02-dimensions.jpg`, or `a-plus-01-brand-banner.jpg`.
- Put the final selected deliverables together in one clearly named final folder. Do not leave the user to collect final images across multiple process folders such as `v2`, `v3`, `v4`, or `drafts`.
- The final folder must contain at least `secondary/`, `a-plus/`, `source/`, and `line-art/` when a full set is generated.
- Do not generate a final preview/contact-sheet image unless the user explicitly asks for one.
- Process folders and drafts may exist for traceability, but the final answer must point to the single final folder and identify it as the official deliverable.

Before final delivery, verify and report the original generated pixel dimensions of every final image. Reject or regenerate any secondary image whose original imagegen output is not exactly `1600 x 2000 px`. For A+ modules, report the original dimensions and keep them at the generated size when the wide A+ ratio is acceptable. Also distinguish original generated dimensions from final exported dimensions when any post-processing was used; do not imply a post-processed image was generated natively at the target size.

If the user says they are testing or says "测试生图", default to six Amazon US secondary images and five A+ modules after required intake is complete: create or verify the local line-art constraints first, then generate secondary images and A+ modules. Generate a main white-background hero image only when the user explicitly asks for it.
