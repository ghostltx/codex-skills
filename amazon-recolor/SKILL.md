---
name: amazon-recolor-v1.03
description: Amazon Recolor v1.03. Recolor Amazon ecommerce listing image sets using source images plus color/material reference images. Supports N+M and +M shorthand, AI-identified color folder naming, and elapsed-time reporting for batch recolor runs.
---

# Amazon Recolor v1.03

## Core Convention

Interpret `N+M` as:

- `N` = first N source ecommerce images to edit.
- `N` also = the intended generation concurrency for this job, capped at 10 concurrent image edits by default.
- `M` = last M color/material reference images.

Interpret `+M` with no number before `+` as:

- Reuse the previous source-image set and previous source count from the last Amazon recolor batch in the current task/thread.
- Replace only the last M color/material reference image(s) with the newly provided reference image(s).
- Keep generation concurrency equal to the reused source count, capped at 10 concurrent edits by default.

Examples:

- `7+1` means the first 7 images are source images, the last 1 image is the target color/material reference, and generation should run with 7 concurrent source-image edits.
- `8+1` means the first 8 images are source images, the last 1 image is the target color/material reference, and generation should run with 8 concurrent source-image edits.
- `9+2` means the first 9 images are source images, the last 2 images are target color/material references, and generation should run with 9 concurrent source-image edits.
- `10+2` means the first 10 images are source images, the last 2 images are target color/material references, and generation should run with 10 concurrent source-image edits.
- `+1` means reuse the previous source-image set and source count, replace the reference side with 1 newly provided color/material reference image, and run with the reused source count as concurrency.

Use reference images only as color/material sources. Do not copy their layout, camera angle, background, product geometry, crop, or scene.

When the user gives local source images plus reference images and only provides `N+M`, infer the target product color/material from the reference image(s) with visual/AI judgment before running generation. Use the product color name in English, such as `gray`, `brown`, `white`, `black`, `teak`, or `navy`, as the default output folder name when the user does not provide an explicit output directory. Do not name the folder by the reference image index. If multiple references indicate the same finish, use one concise finish name; if they indicate combined finishes, join short English names with hyphens.

## Generation Routing

Default to the system built-in `imagegen` workflow for Amazon recolor tasks. Use built-in image editing at approximately 1k output unless the user explicitly requests another route or resolution.

Default generation settings:

- Route: system built-in `imagegen`.
- Size: approximately 1k, preserving each source image aspect ratio when possible.
- Inputs: for each edit, use one source image plus the last `M` color/material reference image(s).
- Outputs: one edited output per source image, saved with clear filenames that map back to the source.
- Concurrency: use the current built-in `imagegen` surface behavior. Do not assume RunningHub concurrency unless that route is explicitly selected.

When editing source images, submit each source ecommerce image with the target color/material reference image(s), one output per source image, using clear filenames that map back to the source.

Use RunningHub OpenAPI image-to-image only when the user explicitly includes or names `runninghub-openapi` for the current request. In that case, follow `runninghub-openapi` rules and run the batch by `N+M` concurrency: submit all `N` source-image modification tasks at the same time, each task receiving its own source image first and the same last `M` reference image(s) after it, then wait for all results and return them together. If RunningHub rejects the requested concurrency, report the error/limit and continue with the highest safe concurrency.

Use other RunningHub image-to-image skills only when the user explicitly asks to combine this skill with that specific RunningHub skill, names RunningHub/I2I as the desired route, or otherwise clearly requests the external I2I workflow for the current task.

## Workflow

1. Identify the source count and reference count from the user's `N+M` shorthand, `+M` shorthand, or explicit wording.
2. Treat the first N images as the only images that need generated outputs.
3. Treat the last M images as target finish references only.
4. Set generation concurrency to N, capped at 10 concurrent edits by default.
5. Recolor all sellable product surfaces and matching companion products in each source image.
6. Preserve all non-product elements: text, icons, dimensions, people, clothing, props, drinks, plants, background, graphic layout, and metal hardware unless the user explicitly asks to recolor them.
7. Generate one output per source image by default.
8. Use clear output names that map to the source image, not generic names that can hide duplicates.
9. Check for duplicate outputs, missing source coverage, color mismatch, reference layout leakage, damaged text, and leftover original color.
10. Track elapsed time from generation submission start until all outputs are received and saved; report the total elapsed time in the final response. When using the local PowerShell runner, read and report its `ELAPSED_SECONDS` / `ELAPSED` lines. When using RunningHub/RH100, report wall-clock generation time from first task submission to final download/final success summary, optionally also including upload-to-final time.
11. For paid API routes, include the returned cost fields in the final response. For RH100 specifically, report `usage.consumeMoney`, `usage.consumeCoins`, and `usage.thirdPartyConsumeMoney` totals when present; if `consumeMoney`/`consumeCoins` are null but `thirdPartyConsumeMoney` is present, show `consumeMoney=N/A`, `consumeCoins=N/A`, and the summed third-party consumed money instead of omitting the cost.

For detailed QA language, read `references/recolor-qa.md` when preparing final prompts or reviewing outputs.

## Dynamic English Prompt

Use this prompt template and replace `[SOURCE_COUNT]`, `[REFERENCE_COUNT]`, `[TARGET_PRODUCT]`, and `[TARGET_FINISH]` from the current request.

```text
Use the last [REFERENCE_COUNT] image(s) only as the color and material reference.
Recolor all [TARGET_PRODUCT] surfaces in the first [SOURCE_COUNT] source image(s) to match the target reference finish.

The first [SOURCE_COUNT] image(s) are the original ecommerce listing images that must be edited.
The last [REFERENCE_COUNT] image(s) are reference images for the desired product color/material only.
Do not copy the layout, camera angle, background, product shape, crop, or composition from the reference images.

Recolor only the sellable product surfaces and matching companion product surfaces in each source image.
Keep the original composition, layout, camera angle, product structure, proportions, lighting, shadows, texture, text, icons, dimension lines, people, props, plants, drinks, background, and all non-product elements exactly unchanged.

The final product color must match the reference image(s) as closely as possible, with strong consistency across all edited source images.
No unwanted color cast, no uneven color shift, no leftover original color, no edge contamination, no reflected color residue.

Preserve realistic material texture, grain direction, surface detail, edge highlights, seams, screws, metal hardware, labels, and natural shadow behavior.
Do not redesign, restyle, simplify, regenerate, add, remove, or rearrange any elements.
```

## Pure White Add-On

When the target finish is pure white, append:

```text
The target finish must be clean pure white, not cream, beige, gray-white, yellow-white, blue-white, dirty white, or off-white.
Remove every trace of the original product color from product surfaces only, including colored edge highlights, colored reflections, rim light, and anti-aliased product edges.
Keep visible wood grain, molded detail, surface sheen, realistic highlights, and natural shadows so the white product does not become a flat blank fill.
```

## Pure Black Add-On

When the target finish is black, charcoal black, or matte black, append:

```text
The target finish must be a realistic black product finish, not a flat featureless black fill.
Preserve visible wood grain, molded texture, bevels, seams, screw holes, water droplets, surface sheen, and edge highlights.
Keep shadow areas dark but readable, with subtle gray-black texture variation and natural highlight behavior.
Remove every trace of the original product color from product surfaces only, including colored edge highlights, colored reflections, rim light, and anti-aliased product edges.
Do not over-darken the product until details disappear. Do not turn metal hardware, labels, text, icons, props, or background elements black.
```

## Natural Wood Add-On

When the target finish is natural wood, oak, teak, acacia, cedar, or another wood tone, append:

```text
The target finish must look like realistic natural wood, matching the reference image color family, undertone, grain contrast, and surface sheen.
Preserve the source product's original geometry, board boundaries, slat spacing, bevels, seams, screw positions, and lighting.
Keep wood grain direction coherent with each board or molded surface. Do not create random swirls, painted stripes, plastic-looking grain, or repeated wallpaper texture.
Avoid oversaturated orange, red, yellow, or muddy brown color casts unless the reference clearly shows that tone.
Do not change non-product wooden props, flooring, decking, tables, or background surfaces unless they are part of the sellable product set.
```

## Gray Add-On

When the target finish is gray, slate, stone gray, silver gray, or weathered gray, append:

```text
The target finish must be a clean, realistic gray matching the reference image, with no unintended blue, green, purple, yellow, or dirty color cast.
Preserve visible product texture, grain, molded detail, bevels, seams, edge highlights, and realistic shadow behavior.
Keep gray variation subtle and material-aware; do not make the product flat, chalky, muddy, or metallic unless the reference is metallic.
Remove every trace of the original product color from product surfaces only, including colored edge highlights, colored reflections, rim light, and anti-aliased product edges.
Protect gray or blue-gray non-product elements such as sky, shadows, clothing, props, flooring, text, and icons.
```

## Brown / Walnut Add-On

When the target finish is brown, walnut, espresso, mahogany, or dark wood, append:

```text
The target finish must match the reference brown or walnut material, including undertone, highlight warmth, shadow depth, grain contrast, and surface sheen.
Preserve visible wood grain, molded texture, board direction, bevels, seams, screws, labels, and natural lighting.
Avoid oversaturated orange, red, purple, or muddy black color shifts unless the reference clearly requires them.
Keep dark recesses detailed and readable. Do not make the product a flat brown fill or a glossy plastic surface unless the reference shows glossy plastic.
Do not recolor unrelated brown objects such as flooring, decor, soil, baskets, furniture, hair, leather, drinks, or background wood.
```

## Custom Color Add-On

When the target finish is any other user-provided color or material reference, append:

```text
Infer the target finish from the reference image(s): dominant color family, undertone, highlight color, shadow color, texture contrast, surface sheen, and material behavior.
Apply that finish consistently to the sellable product surfaces across all source images.
Do not reduce the finish to a single flat sampled color unless the user explicitly asks for a flat solid color.
Remove original product color remnants from product surfaces only, including edge contamination, reflected color residue, rim light, and anti-aliased borders.
Protect all non-product elements, even if they contain colors similar to the original product or target reference.
```

## Multi-Reference Guidance

When `M` is greater than 1:

- Use all reference images to infer the same target finish.
- Prioritize the most product-relevant reference if references conflict.
- Match color family, undertone, highlight behavior, shadow behavior, grain contrast, and surface sheen rather than a single sampled pixel.
- Do not blend different finishes into an unintended new color unless the user asks for a blend.

## RunningHub I2I Notes

Use this section only when RunningHub image-to-image was explicitly requested for the current task.

- Submit each source image with the target reference image(s) whenever the workflow is intended to edit one source at a time.
- Use unique output paths that include the source index or source filename stem.
- Reduce concurrency when RunningHub returns `TASK_QUEUE_MAXED` or rate-limit errors.
- If a task times out, query the task ID before resubmitting.
- Do not delete failed or duplicate files unless the user explicitly asks; label them in the final report instead.
