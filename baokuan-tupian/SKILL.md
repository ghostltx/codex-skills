---
name: baokuan-tupian
description: Identify the main product in user-provided Amazon, ecommerce, or bestseller reference images, record all visible image content including titles, subtitles, labels, and other text, generate a premium high-converting ecommerce image prompt inspired by the fantui detail-page style, then use RH-GPT-IMAGE-2-I2I with the provided white-background product image to generate the final product image. Use when the user asks for 爆款图片, Amazon reference image analysis, product-image recognition, ecommerce prompt reverse engineering, white-background product image transformation, Fantui-style prompt generation, or RunningHub GPT Image 2 image-to-image generation from an uploaded product image.
---

# 爆款图片

Use this skill to turn a user-provided product image into a finished ecommerce visual through a fixed chain:

1. Identify the product subject.
2. Record everything visible in the image, especially title, subtitle, labels, icons, badges, and all readable text.
3. Treat the bestseller/style reference as a structure template: copy its people, scene elements, spatial relationships, composition hierarchy, and text layout while replacing only the product with the user's product.
4. Use `RH-GPT-IMAGE-2-I2I` to generate the image from the user's white-background product image.

## Required Inputs

- Product image: required. Prefer a white-background product image when generation is requested.
- Product name: optional. If the user did not provide a product name and the subject cannot be identified confidently, ask one short question for the product name before generation.
- Output intent: optional. If omitted, create one premium ecommerce hero/detail image.
- Aspect ratio: optional. If omitted, use the actual aspect ratio of the product image (`+1` / image 2). Fall back to `1:1` only when the product image ratio cannot be determined.

If no image is available, ask for the product image in one short Chinese sentence.

## Workflow

### 1. Inspect the image

Analyze the image visually before writing the prompt. Record:

- Product subject and likely category.
- Product shape, color, material, finish, texture, structure, and visible components.
- Packaging, accessories, props, background, surface, shadows, lighting, camera angle, and composition.
- People count, approximate age/gender presentation when visible, poses, interactions with the product, clothing style, and whether people are seated, standing, holding, using, or looking at the product.
- Physical scene relationships: where the product sits, what it touches, distances to hazards/edges/water/walls, ground plane, support points, shadows, and whether the layout is physically plausible.
- Title text, subtitle text, labels, icons, badges, callouts, small print, measurements, numbers, claims, and any other readable text.
- Unreadable or uncertain text as `疑似文字/无法确认`.

Do not invent specifications, certifications, brand claims, warranty promises, prices, rankings, or exact dimensions unless they are visible or provided by the user.
If the main reference image has no usable text, search comparable Amazon or equivalent ecommerce listings for the same product category and extract a title, subtitle, and 3-5 truthful feature callouts from those references instead of leaving the image without copy.

### 2. Build the image record

Before generation, maintain a concise record in Chinese using this structure:

```markdown
【图片识别记录】
- 产品主体：
- 产品名称：
- 类目判断：
- 可见外观：
- 材质/结构：
- 场景/背景：
- 人物/互动：
- 物理关系：
- 光影/构图：
- 标题文字：
- 副标题文字：
- 其他文字/标签：
- 不确定信息：
```

If the user only wants the generated image and not an analysis report, keep this record internally and only include the final prompt plus result summary.

When text is required, always prepare:

- Title
- Subtitle
- 3-5 feature callouts

If the style reference image contains readable text or layout text, reuse its hierarchy and placement style only. Do not copy its wording unless the user explicitly wants the same copy.

If the style reference image contains people, the generated image must also contain people. Preserve the reference image's people count as closely as practical, their general placement, interaction logic, and usage posture. People must be physically plausible in the scene and must not obscure the product's core selling structure.

### 3. Generate the ecommerce prompt

Write one final prompt suitable for RH image-to-image generation. The prompt must:

- Use the product as the visual hero.
- Preserve the product silhouette, proportions, physical volume, color, visible structure, and key design details from the reference image.
- Include camera angle, composition, scene, background, lighting, material treatment, commercial mood, and typography placement when text is requested.
- Copy the bestseller reference image's visible content structure: if it has people, include people; if it has a pool, patio, building, props, table setting, icons, badges, or foreground/background layers, include corresponding elements unless the user explicitly removes them.
- Keep scene physics correct: product contact points, ground plane, scale, shadows, seating positions, edge distances, water/pool boundaries, and human interaction must be believable. Do not place furniture on pool edges, in water, floating, clipping through objects, or in unsafe/impossible positions unless the reference itself clearly shows that exact setup.
- Incorporate truthful visible text from the image only when useful and readable.
- If the source image has no usable text, source the title, subtitle, and feature copy from comparable Amazon or equivalent marketplace listings for the same product category.
- Match the user's requested product name if provided.
- Default to a premium ecommerce hero/detail-page style inspired by `fantui`, but generate one image unless the user requests multiple.
- Include this constraint phrase in Chinese: `产品轮廓、比例与体量必须严格匹配参考白底图`.

Use this prompt template:

```markdown
【最终生图提示词】
基于参考白底图生成一张[比例]电商产品视觉，产品主体为[产品名称/产品主体]，产品轮廓、比例与体量必须严格匹配参考白底图。画面描述：[主体姿态、角度、构图]。[背景/场景]。[光影/材质/氛围]。[文字布局，如需要]。保留/强调：[可见核心特征]。避免：[不应改变或不应出现的内容]。
```

If the final image needs text, append the exact title and subtitle in the prompt and specify where they should appear. Use concise English by default unless the user requests another language.

### 4. Pairing rule for two-image jobs

When the user writes `1+1`, interpret it as:

- `1` = the imitation/style reference image
- `+1` = the product image to be preserved and generated

If the user does not explicitly write `1+1`, default to the first two attached images in order.

Aspect ratio rule for `1+1`: the final generated image must follow the product image (`+1` / image 2) aspect ratio, not the style reference image (`1`). Image `1` controls bestseller structure, people, scene, composition, text hierarchy, and mood. Image `2` controls product identity, product geometry, product structure, material, quantity, and final canvas ratio. If image `2` is `1:1`, generate `1:1`; if it is landscape or portrait, choose the closest supported workflow aspect ratio to image `2`.

For `1+1` jobs, image `1` is the bestseller structure template, not merely a loose style reference. The final image should reproduce the reference's major visible elements and relationships:

- People: if image `1` has people, include people in the generated image; keep their count, placement, pose category, and product-use logic as close as practical.
- Scene: preserve the type and role of key scene elements such as patio, pool, home exterior, wall, floor, table props, icons, badges, foreground water, background architecture, and text zones.
- Composition: keep the same broad layout hierarchy, camera viewpoint, foreground/midground/background layering, negative space, and text placement logic.
- Physics: ensure the substituted product sits in a believable location with correct scale, support, contact shadows, and safe distance from edges/water/hazards.

When preserving the product with product image + line art prevents passing the style image into the workflow, encode the full structure-template record from image `1` explicitly in the prompt. Do not drop people or key scene elements just because image `1` is not sent as an input image.

If the style reference image has no usable text, search comparable Amazon listings or equivalent market references for the product's selling points and five core bullets, then use those to decide the title, subtitle, icons, and layout hierarchy.

If the user supplies another image after a previous attempt, treat that new image as a correction or replacement reference and re-run the pairing with the latest images instead of reusing an older product interpretation.

To protect the product shape, always use the product image together with a line-art version of the same product image when the generation workflow allows only two image inputs. Do not merge them into one collage by default. Instead, create a separate local line-art file beside the source image using the same `{original-file-stem}-01.{jpg|jpeg|png|webp}` naming rule, validate it, and pass both files together to the workflow.

When the chosen product image has no visible text, do not invent copy from the style reference. Use the product's own Amazon category and comparable listings to derive the most persuasive selling points, then build:

- Title
- Subtitle
- 3-5 icon callouts
- spacing and hierarchy

Keep the style reference's people, scene, color mood, physical relationships, and layout logic, but keep the product shape, thickness, quantity, and structure controlled by the product image plus line art.

Do not copy or reuse the style reference's existing wording as the final copy. Use it only as a layout or composition reference. The actual title, subtitle, and feature copy must come from the user's provided text if present; if the user does not provide text, source the copy from Amazon or equivalent marketplace selling points for the product in image 2.

## Generation With RH-GPT-IMAGE-2-I2I

For generation, load and follow:

`C:\Users\ghost\.codex\skills\RH-GPT-IMAGE-2-I2I\SKILL.md`

Use the verified default workflow unless the user specifies another workflow:

```powershell
& "$env:USERPROFILE\.codex\skills\RH-GPT-IMAGE-2-I2I\scripts\submit_i2i.ps1" `
  -WorkflowId "2047956784060567554" `
  -ImagePaths "C:\path\input.png" `
  -Prompt "<最终生图提示词>" `
  -AspectRatio "1:1" `
  -Resolution "2k"
```

Rules:

- Use `-Resolution 2k` by default.
- Use the user's requested ratio if provided. Otherwise, for two-image jobs, use the product image (`+1` / image 2) aspect ratio. Fall back to `1:1` only when the product image ratio cannot be determined.
- Use unique output paths for each generated image.
- For batches, keep at most 3 unfinished RunningHub tasks at once.
- Poll long enough for real jobs; GPT Image 2 I2I often takes 10-12+ minutes.
- If polling times out while status is still running, preserve and report the task ID rather than treating it as a failed generation.

## Local Line-Art Constraint Workflow

Use local image processing for line-art constraint images before final generation.

Preferred local method:

```powershell
python "$env:USERPROFILE\.codex\skills\amazon-plus-1.0\scripts\local_line_art.py" "input.jpg" "input-01.jpg"
```

Use `$env:USERPROFILE` instead of hard-coding a Windows username so the command works on the current computer account.

For each source image:

1. Check whether a matching `{original-file-stem}-01.{jpg|jpeg|png|webp}` file already exists beside the source image.
2. If it exists, quickly validate that it is a white-background black/dark-gray contour drawing derived from the same product angle and structure.
3. Reuse valid line art; regenerate invalid or mismatched line art from the matching source image.
4. Keep the source image and its own matching line-art image paired together. Do not mix line art from a different angle.

Line art must preserve product silhouette, proportions, angle, structure, and visible components. It must not contain scene elements, props, labels, dimensions, icons, text, decorative styling, shadows, or hallucinated details.

## Output

Reply in Chinese. Include:

- A brief product recognition summary.
- The final prompt used.
- The saved output path when generation succeeds.
- The RunningHub task ID if available.
- Any uncertainty or generation timeout clearly and briefly.

Do not explain hidden reasoning. Do not include generic prompt-writing advice.
