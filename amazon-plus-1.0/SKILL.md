---
name: amazon-plus-1.0
description: Unified Amazon US ecommerce product-image generation workflow. Use when the user provides product photos and asks for Amazon listing images, product main images, secondary images, detail-page images, A+ content, dimension images/尺寸图, 6-image sets, 10-image sets, built-in Image Gen generation, RunningHub RH-GPT-IMAGE-2-I2I batch generation, ZZ gpt-image-2 generation, or RunningHub GPT Image 2 Official Stable 4K generation. Always use Fantui planning and local line-art constraints before generation. Ask the user to choose A, B, C, or D when the generation method and resolution routing are not specified.
---

# Amazon Plus 1.0

## Goal

Create Amazon US ecommerce images from one product or same-product reference image set while preserving product identity, dimensions, and marketplace-appropriate conversion logic.

## Core Generation Rule

Local processing is only for preparing line-art constraints, organizing references, light QA, and file management. Do not replace final ecommerce image generation with local compositing, white-background layout boards, plain gradient panels, or PIL/HTML/CSS mockups unless the user explicitly asks for a layout mockup instead of generated images.

For Mode A, use the built-in Image Gen capability for final ecommerce images after local line-art constraints exist. For Mode B, use RH I2I for final ecommerce images. For Mode C, use the `zz-gpt-image2` skill / gpt-image-2 through the T8Star OpenAI-compatible API for final ecommerce images. For Mode D, use the RunningHub GPT Image 2 Image-to-Image Official Stable 4K workflow for final ecommerce images. Final secondary images and A+ modules should look like rich Amazon US ecommerce visuals with realistic backgrounds, scenes, product integration, and polished layout hierarchy, not simple cutout collages.

This skill merges the intended capabilities of `amazon-test-imagegen` and `amazon-batch-imagegen` into a new standalone workflow. Do not modify those original skills when using this skill.

## Required Generation Mode Question

Resolution routing takes priority over the normal generation-mode question:

- If the user explicitly mentions `zz-gpt-image2`, `ZZ gpt-image2`, `gpt-image-2`, or `T8Star`, automatically use Mode C / `zz-gpt-image2`. Do not ask the A, B, C, or D generation-mode question in that case.
- If the user's request or prompt explicitly mentions `1K` or `1k`, automatically use Mode A / built-in Image Gen. Do not ask the A, B, C, or D generation-mode question in that case.
- If the user's request or prompt explicitly mentions `2K` or `2k`, automatically use Mode B / RunningHub RH-GPT-IMAGE-2-I2I unless the user explicitly chooses Mode D / Official Stable. Do not ask the A, B, C, or D generation-mode question in that case.
- If the user's request or prompt explicitly mentions `4K` or `4k`, automatically use Mode D / RunningHub GPT Image 2 Image-to-Image Official Stable 4K workflow. Do not ask the A, B, C, or D generation-mode question in that case.
- If the user's request does not mention a resolution and does not specify a generation method, ask the A, B, C, or D generation-mode question before final image generation.

When the user has not already specified the generation method and the request does not trigger the ZZ/1K/2K/4K auto-routing rules above, ask exactly this one text question before final image generation:

```text
请选择生图方式：
A: Image Gen - (1K-free) Official Stable
B: RunningHub RH I2I - (2K-0.04/pic)
C: ZZ gpt-image-2 - (2K-0.04/pic)
D: RunningHub GPT Image 2 Official Stable - (2K-0.93/pic & 4K-1.37/pic)
直接回复 A、B、C 或 D。
```

Single-select enforcement:

- This step is single choice only.
- Accept only one token: `A` or `B` or `C` or `D`.
- Do not accept multi-select input such as `A+B`, `AB`, `A/B`, or comma-separated choices.
- If the user's reply is not a valid single choice, ask again with the same question and do not continue to generation.

Interpretations:

- A: use built-in Image Gen for final ecommerce image generation.
- B: use RunningHub RH-GPT-IMAGE-2-I2I for final ecommerce image generation.
- C / ZZ / gpt-image-2: use the `zz-gpt-image2` skill for final ecommerce image generation when explicitly requested.
- D / 2K / 4K / Official Stable: use the RunningHub GPT Image 2 Image-to-Image Official Stable workflow for final ecommerce image generation. Workflow id: `2052988540669177857`. Local workflow reference file: `C:\Users\Administrator\Desktop\GPT I2I Official Stable_api.json`. Pricing note: `2K = 0.93元/次`, `4K = 1.37元/次`.

All modes must use local line-art constraints. For Mode B, send the original product image(s) plus the matching local line-art image(s) to RH I2I together as reference inputs. For Mode C, include the original product image and matching line-art constraint in the prompt context when reference-image upload is not available, and preserve the same product-fidelity lock and QA rules. For Mode D, send the original product image(s) plus the matching local line-art image(s) to the Official Stable 4K image-to-image workflow as reference inputs whenever the workflow invocation supports multiple reference images.

## Required Intake

Before final image generation, make sure these are known:

- Product image(s): first try to discover product images in the current working directory. If the current directory contains image files, inspect the filenames and use them as the default product reference set unless the user supplied attachments or explicit paths that override them. If the current directory contains no images and the user has not supplied attachments or paths, ask the user for product images before continuing. Multiple same-product angles/details should be treated as one product identity reference set.
- Current-folder line-art detection: when scanning the current directory, look for existing line-art files that follow the local rule `{original-file-stem}-01.{jpg|jpeg|png|webp}` next to the source image. Example: `1.png` pairs with `1-01.jpg`, and `front.jpg` pairs with `front-01.jpg`. Treat `*-01` files as candidate line art, not source product photos, when the matching original exists.
- Existing line-art validation: before reusing a candidate `*-01` file, quickly inspect it visually or with local image heuristics. It should be a white-background black/dark-gray contour drawing derived from the matching source image, preserving the same product angle and structure, with no scene, text, props, labels, dimension marks, decorative styling, or hallucinated details. If it passes, reuse it and do not regenerate that pair. If it fails or is mismatched, regenerate the line-art file from the matching source image.
- Product identity/category: infer from images only when visually clear; otherwise ask.
- Usage scenario: required for lifestyle, scale, assembly, or A+ scene planning when not obvious.
- Product dimensions: required for dimension images, scale images, assembly images, and realistic lifestyle scenes.
- Generation mode: A, B, C, or D.
- Count/layout: use the user's requested count; otherwise default to a full Amazon visual set made of 9 generated secondary images plus 9 generated A+ modules.
- Main image source: do not copy or generate a white-background main image by default. Generate or include a main image only when the user explicitly asks for a main image, white-background image, or full listing set that includes image 1.

If dimensions are missing and the image set needs dimension/scale truthfulness, ask the user for them before generation. Ask for any available values:

- Overall width
- Overall depth
- Overall height
- Main functional height, such as tabletop/seat/shelf height
- Expanded or folded size when relevant
- Key component size, such as sink, drawer, basket, cushion, tabletop, rail, shelf, or hardware size

If the user names a product covered by another skill, load that dimension/specification skill directly and use it as the source of truth. Do not ask the user for values already present in the corresponding product skill. Do not guess or back-calculate missing measurements when the product skill says a value is unconfirmed.

## Mandatory Fantui Planning

Always invoke or follow `$fantui` before final generation, regardless of whether the user wants 6 images, 10 images, secondary images, A+ images, a main image, or dimension images.

Invoke or follow Fantui in its Amazon Plus compatibility mode when using the default full visual set, so the planning output is already organized as 9 Amazon secondary images plus 9 A+ modules. Use Fantui output as the creative planning base, then adapt it to Amazon US listing standards and the requested image count.

When Fantui produces a 9-secondary plus 9-A+ plan, treat each secondary image and each A+ module as an individual generation task. If Fantui is used standalone and produces a legacy 10-scene plan, adapt it into the requested set structure before generation rather than following the legacy count directly. For every image or module, choose the most suitable product reference image(s) based on the scene content, product angle, visible feature, and required detail. Upload/use those selected original product image(s) together with their own matching local line-art image(s) for that scene. Do not use one generic reference bundle for all scenes when a more relevant product angle exists.

For each planned image, write a short reference-pair note before generation using exact filenames, such as `Scene 04 uses 0.jpg + 0-01.jpg because this scene shows the tabletop and basin angle.` Keep every source image paired only with its matching line art.

## Local Line-Art Constraint Workflow

Use local image processing for line-art constraint images before final generation in both Mode A and Mode B. Do not use AI image generation to create line-art constraints.

Preferred local method:

```powershell
python "$env:USERPROFILE\.codex\skills\amazon-plus-1.0\scripts\local_line_art.py" "input.jpg" "input-01.jpg"
```

Use `$env:USERPROFILE` instead of hard-coding a Windows username so the command works on the current computer account.

If that script is unavailable, use a local deterministic edge-detection or contour-extraction process with standard image tooling. The line-art step must be derived from the supplied product image file, not hallucinated or redrawn by a generative model.

For each product source image:

1. First check whether a matching `{original-file-stem}-01.{jpg|jpeg|png|webp}` line-art file already exists in the same folder and passes the existing line-art validation rules above.
2. If valid line art already exists, reuse it and keep the exact source-to-line-art pairing.
3. If no valid line art exists, create a clean line-art constraint image from the same file.
4. Save each generated line-art image in the same folder as its original image as `{original-file-stem}-01.jpg`.
   - Example: `0.jpg` -> `0-01.jpg`
   - Example: `front.png` -> `front-01.jpg`
5. Pair each source image only with its own matching line-art image using the exact filename rule above. If a scene uses `0.jpg`, upload/use `0.jpg` and `0-01.jpg` together. If a scene uses `front.png`, upload/use `front.png` and `front-01.jpg` together.
6. Do not mix line art from one angle with a different product angle.

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
- For structural products such as tables, carts, shelving units, benches, cabinets, racks, folding furniture, sinks, tool stations, or products with visible hardware, product geometry is higher priority than lifestyle richness. If a scene prompt causes the model to redraw shelves, braces, fasteners, wheels, hinges, hooks, panels, seams, labels, or surface openings incorrectly, reject the image rather than accepting it as a creative variation.
- Do not allow AI to invent or replace brand labels/logos. Preserve a source-visible logo only when it remains accurate; otherwise hide, crop, blur, or omit that region. Reject images with hallucinated third-party brands, misspelled labels, fake badges, or unprovided logos.
- Check physical plausibility for props and use scenes. Reject impossible interactions such as soil leaking through an intact flowerpot, floating dirt, broken containers, unsupported boards, tools fused into hooks, hands passing through product parts, or props resting on nonexistent shelves.

## Product-Preservation Escalation

Use this stricter workflow when the user identifies product drift, when the product has precise structural details, or when previous generated drafts changed the product:

- Prefer source-product-preserving compositions over full product redraws. Keep the original product render/photo as the structural source of truth and use generation mainly for background, atmosphere, light styling, props, or layout.
- For RH I2I, use one primary product angle plus its matching line art per task whenever possible. Avoid mixing multiple product angles in one generation if the model might average structures or invent new parts.
- Keep people, props, and lifestyle complexity secondary until the product body is proven accurate. If exact scale or structure is at risk, use hands-only, partial-user context, or no person.
- For detail images, use the clearest source detail photo and matching line art only. Do not use a wide multi-angle bundle for hardware close-ups.
- Treat line art in RH I2I as a soft constraint, not a guarantee. Final QA must decide whether the product is accurate.

## Mode A: Built-In Image Gen

Use Mode A when the user chooses `A` or explicitly asks for built-in Image Gen.

Mode A final images must be generated with built-in Image Gen. Use local tools only to create line-art constraints and organize/verify outputs; do not create final Mode A secondary images or A+ modules by pasting product cutouts onto plain local backgrounds.

Generation references:

- Include the original product image(s).
- Include matching local line-art image(s).
- Explicitly state that the line art is a structural constraint and the original image is the product appearance reference.
- For default full visual sets, adapt Fantui planning into 9 secondary images and 9 A+ modules. Generate each image or module with the scene-matched original product reference image(s) plus the matching line-art constraint image(s). The selected product photo defines color, material, surface texture, hardware, and visible details; the paired line art constrains outline, structure, component positions, proportions, and angle.

Scene and layout requirements:

- Secondary images should use authentic American lifestyle scenes, backyard, patio, garden, garage, kitchen, home, or outdoor contexts according to the product category.
- Scene-based secondary images should include realistic people, hands, or family/user interaction when appropriate so the image feels lived-in and relatable. Keep people secondary to the product and do not block key product structure.
- Prefer natural light, believable materials, real proportions, full-frame composition, and restrained premium composition.
- Use clean functional breakdowns with restrained English text only when useful, such as dimensions, feature labels, installation callouts, or concise benefit headlines.
- Avoid crowded domestic marketplace poster layouts. Keep the visual language realistic, premium, minimal, cozy, clean, and natural.
- Do not replace rich ecommerce/lifestyle image generation with plain white-background layout boards, gradient panels, or local cutout compositions just to satisfy dimensions.

Default output standards:

- Secondary images: native `1600 x 2000 px`, 4:5 vertical canvas.
- A+ modules: wide Amazon A+ banner ratio; exact `1464 x 600 px` is optional when the generated ratio and quality are acceptable.
- Main image: only generate when requested; use `2000 x 2000 px`, pure white `#FFFFFF`, no text, no props, no watermark.

Reject or regenerate any Mode A final secondary image whose original generated dimensions are not exactly `1600 x 2000 px`. Do not upscale, pad, or cover-resize secondary images to fake compliance.

If Image Gen cannot return a native `1600 x 2000 px` secondary image, treat that image as a failed draft and regenerate with a stricter prompt. Do not accept a local post-processed substitute that destroys scene richness.

## Mode B: RunningHub RH I2I

Use Mode B when the user chooses `B`, explicitly asks for RunningHub/RH I2I, or explicitly requests `2K` or `2k` output anywhere in the prompt. A 2K request is an automatic RH-GPT-IMAGE-2-I2I routing signal and must not trigger an A, B, or C question. Do not treat `4K` / `4k` as an automatic Mode B routing signal in this Amazon workflow.

For every RH I2I task, pass both the product source image(s) and the matching local line-art constraint image(s) with `-ImagePaths`. The prompt must say the original image(s) define product color/material/detail, and the line-art image(s) constrain silhouette, structure, proportions, and angle.

Mode B final images should also be rich scene-based ecommerce visuals, not local cutout collages. The RH I2I prompt should explicitly request realistic backgrounds, authentic American lifestyle scenes, natural light, product integration, full-frame composition, concise English ecommerce text when useful, and realistic people/hands/user interaction when appropriate. Use the same scene and layout standards as Mode A unless the user asks for a pure product-only or white-background image.

For RH I2I secondary images, include wording such as `4:5 Amazon US secondary image, realistic backyard/patio/garden/home scene, natural light, believable product scale, realistic person or hands when useful, clean premium ecommerce layout, concise English headline and feature callouts`. For RH I2I A+ modules, include wording such as `wide Amazon A+ banner, full-frame lifestyle or brand atmosphere composition, realistic scene background, clean hierarchy, concise English copy`.

RH I2I supports 1-10 reference images per task. Curate references if there are too many files, but keep at least the primary source image and its matching line art.

For structure-sensitive products, do not assume RH I2I will obey line art strongly enough. In those cases:

- Use the most relevant single source angle and its exact matching line art rather than a broad multi-angle bundle.
- Add negative constraints for every likely drift point: no extra shelves, no extra braces, no changed hardware, no invented holes, no fake logos, no altered fasteners, no broken boards, no impossible props.
- Generate fewer scene elements per image and inspect the product before continuing to the next batch.
- If two consecutive RH drafts for the same slot change critical product structure, stop using full-scene product redraw for that slot and switch to a source-preserving layout or post-production approach.

Use this command shape:

```powershell
& "C:\Users\ghost\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\img2img.ps1" `
  -ImagePaths "<source-image>","<matching-line-art>" `
  -Prompt "<Amazon ecommerce prompt>" `
  -OutputPath "<output-folder>\amazon_02_lifestyle_hero_4x5.png" `
  -AspectRatio "4:5"
```

Batching:

- Submit RH I2I tasks in parallel groups of up to 3.
- For default full visual sets, generate 9 secondary images in three batches (`secondary 1-3`, `secondary 4-6`, `secondary 7-9`) and 9 A+ modules in three batches (`A+ 1-3`, `A+ 4-6`, `A+ 7-9`).
- For 6-image or other custom sets, still use groups of up to 3.
- Main image should not be copied or generated by default. If the user explicitly requests a generated main image, it should be `1:1` square and no text.
- Secondary images should usually be `4:5` and omit `-Resolution`, so RH I2I uses its default workflow. A+ modules should use wide banner aspect ratio such as `16:9` or `21:9` when supported by the selected mode. Pass `-Resolution 2k` and optional `-Quality low|medium|high` when the user explicitly requests 2K output. If the user only requests `1K` / `1k`, use Mode A / built-in Image Gen by default.

## Amazon Image Planning

Use the user's requested set structure when provided. Otherwise:

- Default full visual set: 18 generated images total, with 9 Amazon secondary images plus 9 A+ modules.
- Main white-background image: do not copy or generate by default. Generate or include a main image only when the user explicitly requests it.

Suggested default 9 secondary image structure:

1. Hero lifestyle: premium usage context with a believable person when appropriate.
2. Core USP: one clear buyer pain point solved visually.
3. Feature/structure: callouts, exploded view, or functional detail.
4. Material/craft: macro texture, finish, touch, durability, or workmanship.
5. Size/scale: dimension or human-context scale visualization using only known dimensions.
6. Use scenario 1: realistic everyday use.
7. Use scenario 2: aspirational or gift/lifestyle scene.
8. Detail macro: strongest visible quality detail.
9. Trust/service: included items, care, support, or brand reassurance without fake guarantees.

Suggested default 9 A+ module structure:

1. Brand/lifestyle banner: wide hero scene that establishes category and product positioning.
2. Problem/solution banner: show the main buyer pain point being solved.
3. Feature system banner: visual breakdown of the product's key functional zones.
4. Material/detail banner: premium texture, finish, hardware, or craftsmanship proof.
5. Size/use-fit banner: scale, footprint, storage, or space-planning context using known dimensions only.
6. Scenario/story banner: realistic use environment with product integrated into the buyer's routine.
7. Comparison/fit banner: show why this product form factor fits the target use case without naming or copying competitors.
8. Care/included-use banner: show cleaning, storage, maintenance, included parts, or everyday setup only when truthful from visible or user-provided facts.
9. Closing/trust banner: clean final brand atmosphere, care/use summary, included-use context, or support reassurance without unsupported guarantees.

For images with text:

- Use concise English ecommerce copy by default unless the user requests another language.
- Use only visible or user-provided facts.
- Generic truthful labels are allowed when exact facts are unknown, such as `Compact Size`, `Easy to Use`, `Premium Finish`, or `Detail View`.
- Do not add text to main images.

Lifestyle and use-scenario images should include believable people by default when appropriate. Add animals only when naturally relevant to the product category and scene; keep them secondary to the product.

For lifestyle, scale, and use-scenario images with people, use fixed human-height anchors to keep product scale realistic against known product dimensions. If the person is male, plan scale using `178 cm` height. If the person is female, plan scale using `165 cm` height. Mention this scale anchor in prompts when the person's full body, torso, arm reach, sitting posture, or standing posture affects perceived product size.

## Prompting Guidance

When generating final prompts or images:

- Treat the product reference photos and same-angle line-art constraints as non-negotiable.
- State the intended image slot before generating: lifestyle, feature, dimension, detail, multi-scene, assembly, brand atmosphere, or A+ module.
- Use the phrase `native 1600 x 2000 px, 4:5 vertical canvas, full-frame Amazon US secondary image` for every secondary image prompt.
- Use the phrase `wide Amazon A+ banner canvas, full-frame composition` for every A+ prompt.
- Say that the original product image defines color, material, finish, hardware, and visible details, while the matching line-art image constrains silhouette, structure, proportions, component positions, and angle.
- For lifestyle, multi-scene, scale, and assembly images, include a realistic person, hands, or user context whenever it improves realism and conversion value.
- When dimensions are available, include them in prompts and describe the expected relationship to a realistic person, hand, patio, deck, countertop, floor, or garden setting.
- For table, bench, workstation, cart, cabinet, shelf, sink, appliance, or tool-surface products, place the person in a natural user position at the main usable/front side of the product unless the scene specifically requires a side or rear view. The person's body should stay outside the product footprint and should not be squeezed behind side extensions, side frames, doors, legs, wheels, braces, posts, drawers, or other structural parts. Hands should reach naturally to the usable surface or control point without blocking the product's key structure.
- When a product-specific skill provides human-scale anchor rules, copy those scale rules into the final image prompt exactly enough to preserve the product's real-world size. Keep product-specific scale wording in the product skill, and keep general model/person-placement rules in this Amazon workflow.
- Prefer natural light, believable materials, real proportions, restrained composition, cozy premium backgrounds, and clear product visibility.
- Use English text only when the image type benefits from text, such as dimensions, feature labels, or installation callouts.
- Keep text concise and conversion-focused. Do not add fake certifications, awards, warranties, rankings, or unsupported performance claims.

## Dimension Image Rules

For dimension images, every measurement label must name what is being measured. Do not place a bare number such as `37.4 in` without a label.

When a product-specific skill provides dimension-image cautions, copy those cautions into the dimension prompt exactly enough to avoid mislabeling or mismeasuring the product.

Dimension images should label product dimensions only. Do not label a model/person's height unless the user explicitly asks for a human-height comparison. If a person is used for scale, keep their height as an internal prompt anchor only and do not print `Model Height`, `5.4 ft`, `164 cm`, or similar text in the final image.

If the user requests inches, inch-only, Amazon US sizing, or says they only want `inch`, use inch labels only. Do not include centimeters in visible dimension text, A+ modules, or callouts unless the user explicitly asks for dual-unit labels.

For Amazon US dimension images, avoid oversized marketing headings such as `A+ Module 03` inside the image unless the user asks for internal module names. Use buyer-facing labels such as `Dimensions`, `Overall Length`, `Tabletop Depth`, and `Basin Depth`.

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

For explicit multi-platform stability tests, such as a user asking to generate one set each with A, B, and C, create separate mode folders under one test deliverable folder, such as `mode-a-imagegen/`, `mode-b-rh-i2i/`, and `mode-c-zz-gpt-image2/`. This is a request-specific test workflow only and does not change the default behavior: normally generate with the single chosen or routed mode, and ask the generation-mode question when no mode or resolution route is specified.

For default full visual sets:

- Create one deliverable folder with separate `secondary/` and `a-plus/` folders.
- Generate 9 secondary images and place them in `secondary/`.
- Generate 9 A+ modules and place them in `a-plus/`.
- Do not copy the user-provided white-background source image into the final deliverable by default. Keep source images in `source/` only when useful for organization or QA.
- Use filenames that preserve set order, such as `secondary_01_lifestyle_hero_4x5.png` through `secondary_09_trust_service_4x5.png`, and `a-plus_01_brand_lifestyle_banner.png` through `a-plus_09_closing_trust_banner.png`.
- Ensure the user can open the final folder and see 18 generated deliverables organized as 9 secondary images plus 9 A+ modules.

Before final delivery:

- Verify every final image path exists.
- For default full visual sets, verify the final deliverable contains exactly 9 secondary images and 9 A+ modules, with no default copied white-background main image mixed into the generated deliverables.
- Report original generated pixel dimensions when available.
- State which mode was used: A built-in Image Gen, B RunningHub RH-GPT-IMAGE-2-I2I, C zz-gpt-image2, or D RunningHub GPT Image 2 Official Stable.
- Mention any known gap, such as text not verified, competitor research unavailable, or dimensions missing.
- Perform visual QA on every generated image before presenting it as usable. For each product, use the product-specific skill's reject list when available. At minimum check: product structure, hardware count and shape, fastener type, shelves/panels/braces, wheels/legs, holes/openings, logo/label accuracy, visible text spelling, measurement units, human/product scale, impossible props, and whether any scene element rests on nonexistent geometry.
- If QA finds product drift, mark the image as rejected and regenerate or explain that the image is not suitable. Do not present failed drafts as a completed Amazon-ready set.

Reply in Chinese and keep the final concise.
