---
name: amazon-batch-imagegen
description: Combine product identification, Amazon competitor image research, Fantui product-image reverse prompting, and RunningHub RH I2I batch generation for Amazon ecommerce creatives, with support for multiple same-product reference angles to improve consistency. Use when the user provides or references one or more product images and asks to generate Amazon ecommerce images, Amazon listing images, product main images, detail-page images, A+ content, or 10 selling-point images from those images. Default generation is RH-GPT-IMAGE-2-I2I, not built-in Image Gen; RH I2I supports 3 parallel tasks, so submit up to 3 image-generation tasks at a time. Keep image 1 as a compliant no-text main image; images 2-10 must include English titles, subtitles, selling-point labels, feature icons, and size/spec layout text when useful and truthful. Lifestyle/use-scenario images should include people by default, and may include animals when category-appropriate, realistic, and helpful for conversion.
---

# Amazon Batch Imagegen

## Goal

Turn one product or same-product reference image set into 10 Amazon-ready ecommerce image concepts, optimize them against current Amazon competitor image patterns, then generate 10 raster images while preserving product consistency.

## Required Inputs

- Product image(s): use the attached image(s) or load the local image path(s) if the user provides paths. Support multiple same-product angle/detail references.
- Target: default to Amazon ecommerce images when the user does not specify marketplace details.
- Count: default to 10 images.
- Sizes/ratios: image 1 is the no-text Amazon main image and should be `1:1` square when generated; images 2-10 are vertical ecommerce images and should use RH I2I defaults: `4:5`, `high`, `2k`.
- Project name: use the user's provided project name when available; otherwise derive a short safe project name from the product category or visible product identity.
- Output location: create a project-named folder on the Desktop and save all final images there unless the user names another folder.

Ask one concise question only if the product image is missing. Otherwise proceed.

## Workflow

1. Invoke or follow `$fantui` first on the product image.
2. Identify the product category from the user's description and image. If the user did not name the product, infer the strongest likely product type from the image.
3. Search Amazon for same-category products and review about 10 leading/comparable sellers' image sets.
4. Analyze competitor image strengths and weaknesses, then convert the insights into better 10-image creative briefs.
5. Convert Fantui's 10-screen plan plus competitor insights into 10 Amazon ecommerce selling-point image briefs.
6. Keep the real product as the hero in every image. Preserve visible structure, color, material, key proportions, and distinctive details from the full reference image set.
7. Remove unsupported claims: do not invent certifications, exact specs, rankings, warranties, prices, or brand history unless the user provides them or they are visible in the image.
8. Treat image 1 as the only no-text Amazon main image. For images 2-10, plan concise English information design by default: title, subtitle, selling-point tags, feature icons, callouts, and size/spec layout blocks are allowed when they improve conversion clarity.
9. For lifestyle and use-scenario images, include believable people by default: hands using the product, a model wearing or holding it, a family/home user, an outdoor user, or another category-appropriate human presence. Add animals only when it naturally fits the category and scene, such as pet, home, outdoor, travel, farm, or family-use products; keep animals secondary to the product and realistic.
10. Generate one image per brief with `$RH-GPT-IMAGE-2-I2I` in batches of up to 3 parallel tasks by default.
11. Enforce the internal output ratio intent in every prompt: `1:1 square` for image 1, and `4:5 vertical` for images 2-10.
12. Submit RH I2I generation in parallel groups: for 10 images, submit image 1 first if needed, then submit images 2-10 as three batches of 3 tasks (`2-4`, `5-7`, `8-10`). If the user asks for 9 non-main images, submit three batches of 3 tasks. Save files with stable numbered names. Use `-AspectRatio "4:5"`, `-Quality "high"`, and `-Resolution "2k"` for images 2-10.
13. Save every final image inside the Desktop project folder.
14. Report the 10 saved paths and a compact prompt summary.

## RunningHub I2I Batch Generation

Default to `$RH-GPT-IMAGE-2-I2I` for all image generation in this skill. Temporarily do not use built-in Image Gen unless the user explicitly asks to switch back.

RH I2I supports 3 tasks in parallel:

- For 10-image sets: generate image 1 as the main image, then generate images 2-10 in three parallel batches of 3 tasks: `2-4`, `5-7`, `8-10`.
- For 9-image non-main sets: submit exactly three batches of 3 tasks.
- Each RH I2I task should include the product reference image set, the exact per-image prompt, target output path, and target size/aspect intent.
- RH I2I supports 1-10 reference images per task. Pass the same curated product reference set with `-ImagePaths` to every generated image unless a specific image brief should focus on one detail angle.
- Use `-AspectRatio "4:5"`, `-Quality "high"`, and `-Resolution "2k"` for images 2-10.
- Do not wait to submit images one-by-one when a 3-task batch can be submitted in parallel.
- Images 2-10 should include English ecommerce layout elements by default: title, subtitle, selling-point labels, feature icons, callouts, and size/spec panels, while avoiding unsupported facts.
- Built-in `$imagegen` is disabled for this skill by default. Use it only if the user explicitly requests built-in Image Gen or RH I2I is unavailable and the fallback is reported.

## Amazon Image Set Strategy

Use this default 10-image mix unless the product category suggests a stronger structure:

1. Main image: clean product on pure white background, full product visible, no text.
2. Hero lifestyle: premium usage context with the product as the obvious focal point, including a believable person interacting with or benefiting from the product.
3. Core USP: one clear buyer pain point solved visually.
4. Feature/structure: exploded view, cutaway, callout composition, or functional detail.
5. Material/craft: macro texture, finish, touch, durability, or workmanship.
6. Size/scale: dimensional or human-context scale visualization without fake exact measurements.
7. Use scenario 1: realistic everyday use with a person, hand model, wearer, homeowner, driver, parent, athlete, worker, or other category-appropriate user in the scene.
8. Use scenario 2: aspirational or gift/lifestyle scene with a person present; include animals only when they fit the product category and make the scene more persuasive.
9. Detail macro: close-up of the strongest visible quality detail.
10. Trust/service: packaging, included items, care, support, or brand reassurance without fake guarantees.

Images 2-10 text/layout rule:

- Use English copy by default for all non-main images unless the user requests another language.
- Add polished ecommerce layout elements: headline/title, short subtitle, 2-4 selling-point tags, feature icons, arrows/callout lines, comparison labels, dimensional guide blocks, or spec-style panels.
- Keep text concise, readable, and premium. Prefer short phrases over sentences.
- Use only visible or user-provided facts for dimensions, specs, materials, compatibility, certifications, warranty, performance, and included items. If exact data is unknown, use generic truthful labels such as `Compact Size`, `Easy to Use`, `Premium Finish`, or `Detail View` instead of fake numbers.
- Do not add in-image text to image 1.

Adjust by category:

- Apparel: prioritize model fit, size guide, fabric macro, colorways, and wearing scenes.
- Consumer tech: prioritize ports, structure, feature callouts, specs placeholders, and device-in-use scenes.
- Home/outdoor: prioritize room or patio context, scale, material, weather/use scenes, and close details.
- Beauty/FMCG: prioritize texture, ingredient-style scene without fake ingredient claims, routine usage, pack shot, and sensory macro.
- Pet/animal-adjacent products: include the relevant animal when useful, but keep the product legible and do not imply veterinary, safety, or performance claims unless provided.
- Products unrelated to animals: avoid adding animals unless the brief has a natural lifestyle reason and the animal does not distract from the product.

## Amazon Competitor Research

Use current Amazon research when network/browser access is available or explicitly requested. Search by the user's product name first; if missing, search by the inferred product category and core attributes from the image.

Review about 10 leading or comparable seller listings. Prefer organic top results when distinguishable, but include sponsored results only when they clearly represent strong category image patterns. Amazon rankings vary by region, account, advertising, and time; treat "top 10" as current reference material, not a permanent ranking claim.

For each competitor image set, evaluate:

- Main image cleanliness: white background, product size, angle, cropping, shadow, and marketplace compliance.
- Gallery structure: whether it covers hero lifestyle, core USP, feature callouts, material/detail, size/scale, use cases, and trust/packaging.
- Visual quality: lighting, realism, premium feel, composition, depth, color harmony, and product legibility.
- Conversion clarity: whether the buyer can understand the product benefit within 2 seconds.
- Text quality: whether in-image copy is concise, readable, and not visually cheap.
- Trust signals: packaging, included items, service, care, compatibility, or proof points without unsupported claims.
- Missing opportunities: scenes, details, scale cues, use cases, or differentiators competitors fail to show.

Translate competitor research into prompt improvements:

- Keep competitor strengths that match Amazon conversion patterns.
- Avoid weak patterns such as cluttered text, tiny product scale, overdecorated backgrounds, fake badges, unrealistic lifestyle scenes, and inconsistent product rendering.
- Use gaps in competitor galleries to strengthen the 10-image plan.
- Do not copy competitor brand names, logos, layouts, slogans, exact packaging, or proprietary claims.
- When competitor evidence is unavailable, proceed from Fantui plus general Amazon image best practices and state the research gap in the final response.

## Reference Image Handling

When the user provides multiple images of the same product, treat them as one product identity reference set:

- Image 1 or the clearest front/hero image is the primary identity reference.
- Side, back, bottom, top, packaging, and detail photos are supporting references.
- Use supporting references to lock thickness, silhouette, back structure, base shape, ports, seams, stitching, buttons, hardware, texture, color, finish, packaging, and scale cues.
- Do not treat different angles as different product variants unless the user explicitly says they are variants.
- If references conflict, prioritize the clearest primary identity image and visible repeated details.

For every generated image, include a consistency instruction:

```text
Input images: same-product reference set. Image 1 is the primary identity reference; all other images are supporting angle/detail references. Preserve the same product design, silhouette, proportions, color, material, visible seams, hardware, texture, distinctive details, and packaging cues across all generated images. Do not invent new variants, colors, logos, shapes, buttons, holes, stitching, accessories, or packaging.
```

## Prompt Construction

For each generated image, use this shape:

```text
Use case: product-mockup
Asset type: Amazon ecommerce image <number>/10
Target ratio: <1:1 square for image 1; 4:5 vertical for images 2-10>
Input images: same-product reference set; preserve product structure, color, material, proportions, silhouette, texture, hardware, seams, distinctive details, and packaging cues
Competitor insight: <specific improvement learned from Amazon competitor image review>
Primary request: <selling-point visual brief>
Scene/backdrop: <background or environment>
Subject: the referenced product as the visual hero; for lifestyle/use-scenario images, include believable people interacting with, wearing, holding, using, gifting, or living around the product as appropriate; include animals only when the category and scene make them natural and helpful
Composition/framing: Amazon-ready composition, product fully legible, strong negative space where needed
Lighting/mood: premium commercial lighting, realistic shadows, polished catalog quality
Text: <image 1: no text; images 2-10: concise English title/subtitle/selling-point tags/feature labels/icons/size or spec layout text by default, using only visible or user-provided facts>
Constraints: no logo unless visible on product, no watermark, no fake certification, no fake dimensions, no unsupported claim, keep product identity consistent with all references
Avoid: distorted product, extra product variants, wrong material, invented colors, invented accessories, altered silhouette, cropped product, unreadable text, distracting or unrealistic people, distracting or unrelated animals
```

Main image constraints:

```text
Pure white background, full product centered, realistic soft studio shadow, no text, no props, no logo overlays, no watermark, product occupies most of the frame while staying fully inside the canvas.
Final canvas must be 2000x2000 square.
```

## RH I2I Command Shape

Use this command shape for each generated image:

```powershell
& "C:\Users\ghost\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\img2img.ps1" `
  -ImagePaths "<reference-1>","<reference-2>" `
  -Prompt "<Amazon ecommerce prompt>" `
  -OutputPath "<Desktop project folder>\amazon_02_lifestyle_hero_4x5.png" `
  -AspectRatio "4:5" `
  -Quality "high" `
  -Resolution "2k"
```

For 3-task parallel batches, call this command once per target image with a unique `-OutputPath`.

## Output Naming

Create the output folder before generation:

```text
Desktop/<project-name>/
```

Normalize `<project-name>` for filesystem safety: keep it short, remove path separators, and replace unsafe punctuation with hyphens. If the user does not provide a project name, use a concise product/category-derived name such as `amazon-chair-images` or `amazon-skincare-images`.

Use stable filenames inside that folder:

```text
amazon_01_main_white_2000x2000.png
amazon_02_lifestyle_hero_4x5.png
amazon_03_core_usp_4x5.png
amazon_04_feature_structure_4x5.png
amazon_05_material_macro_4x5.png
amazon_06_size_scale_4x5.png
amazon_07_use_scene_1_4x5.png
amazon_08_use_scene_2_4x5.png
amazon_09_detail_macro_4x5.png
amazon_10_trust_package_4x5.png
```

If a file already exists, create a sibling version such as `amazon_01_main_white_2000x2000_v2.png`.

## Final Response

Reply in Chinese. Include:

- 生成数量
- 保存路径
- 使用的生成方式: RunningHub RH-GPT-IMAGE-2-I2I
- Any known gaps, such as text not being verified or a fallback being used

Keep the final concise.
