---
name: amazon-lovart-1.0
description: Amazon Lovart 1.0 product image set design workflow using the built-in image_gen tool by default. Use when the user asks for 亚马逊产品套图, Amazon listing images, main image plus secondary images, product infographics, lifestyle/detail/angle images, or A+ Brand Content modules. Guides output scope, marketplace compliance, visual consistency, and conversion-focused image planning or generation.
---

# Amazon Lovart 1.0

## Purpose

Plan, generate, review, or iterate Amazon product image sets for product detail pages and A+ Brand Content. Optimize for Amazon compliance, product fidelity, mobile readability, and conversion.

## Generation Tool

Use the built-in `image_gen` tool for final image generation and image editing by default.

Do not ask the user to choose a generation provider unless they explicitly request a different provider. When product reference images are available, use them as visual references for product identity, proportions, color, material, and detail consistency.

For multi-image sets, generate in this order:

1. Main image with strict Amazon compliance.
2. Secondary images using the approved or latest main image as the visual baseline.
3. A+ modules after the product image set style is established.

If a generated image drifts from the supplied product reference, iterate with `image_gen` and explicitly reinforce the product fidelity lock in the prompt.

## Trigger Phrases

Use this skill for requests such as:

- 亚马逊产品套图
- 亚马逊主图 / 副图 / A+ 页面
- Amazon product images / listing images
- Product infographic, lifestyle image, detail image, angle image
- A+ Brand Content module design
- Complete Amazon image set

## Core Deliverables

Default deliverables depend on the user's requested scope:

| Scope | Deliverables |
| --- | --- |
| Complete set | 1 main image + 6 secondary images + 8 A+ modules |
| Product image set only | 1 main image + 6 secondary images |
| A+ only | 8 A+ modules |
| Vague request | Start with the main image, then recommend secondary-image options |

Generation order:

1. Confirm scope and image count.
2. Generate or plan the main image first as the visual baseline.
3. Generate or plan secondary images from the main-image reference.
4. Generate or plan A+ modules when requested.
5. Review consistency, compliance, readability, and conversion clarity.

## Intake Checklist

Before final generation, make sure these are known or inferable:

- Product image or clear product description.
- Product category and marketplace context.
- Desired scope: complete set, product images only, A+ only, or specific image types.
- Core selling points for infographics.
- Target user and usage context for lifestyle images.
- Product dimensions when scale, size reference, or dimension images are requested.
- Brand colors, typography, logo, or style references when A+ or branded modules are requested.

If missing details block truthful output, ask the smallest necessary question. If the request is only mildly vague, proceed with a reasonable default and state the assumption.

## Universal Image Requirements

- Minimum size: 1000 px by 1000 px.
- Standard product-image ratio: 1:1 unless the user requests a platform-specific module.
- Mobile-readable embedded text: at least 30 pt.
- Keep one core message per image.
- Use clear hierarchy, high contrast, clean composition, and concise copy.
- Preserve product color, material, proportions, hardware, accessories, and visible details across all images.

## Main Image Rules

Main images are strict compliance assets.

Must include:

- Pure white background: RGB(255,255,255).
- Product occupying at least 85% of the image area.
- Real product photo appearance, centered and fully visible.
- Clean, even lighting with no distracting shadows.
- Only the actual product and truthful included components.

Must not include:

- Text, labels, badges, descriptions, icons, or callouts.
- Brand logos, watermarks, borders, color blocks, or decorative graphics.
- Misleading accessories, props, packaging, or non-included items.
- Illustration-only or obviously artificial rendering when a real product-photo style is required.
- Human model for clothing main images unless Amazon category rules allow the specific presentation.

Clothing-specific cautions:

- Use a standing real model or flat lay when appropriate.
- Avoid mannequins or noncompliant body-only presentations when the category disallows them.

## Secondary Image Types

Choose a balanced mix based on product category and user goals:

| Type | Purpose | Design Notes |
| --- | --- | --- |
| Infographic | Explain key benefits or feature comparisons | 4-6 selling points, short phrases, icons, callout lines pointing to real features |
| Multi-angle | Show product from different views | Consistent lighting and clean background, usually 1-2 images |
| Detail close-up | Show material, craft, texture, mechanism, or finish | Macro-style product fidelity, quality emphasis |
| Lifestyle | Show real usage context | Target user, realistic scene, believable product scale, usually 1-2 images |
| Variant display | Show colors, sizes, styles, or bundles | Unified arrangement and accurate labels |
| Unboxing | Show package contents | All included components visible and truthful |
| Size reference | Show actual scale | Use dimensions or familiar objects only when truthful |

Secondary-image principles:

- One image, one message.
- Text must remain readable on mobile.
- Keep product appearance consistent with the main image.
- Avoid clutter, excessive copy, and unsupported claims.
- For infographics, prioritize the most important benefit first and use direct callout lines or arrows.

## A+ Module Plan

Use these defaults unless the user provides a custom layout:

| Module | Ratio | Size | Content |
| --- | --- | --- | --- |
| 1. Brand banner | 21:9 | 2388 x 1024 | Hero banner |
| 2. Pain point or scenario | 3:2 | 1536 x 1024 | Pain points / scenarios |
| 3. Selling point matrix | 3:2 | 1536 x 1024 | Key benefits / features |
| 4. Ingredients or technology | 3:2 | 1536 x 1024 | Materials, components, technology, or mechanism |
| 5. Data or comparison | 3:2 | 1536 x 1024 | Efficacy data, product comparison, or before/after when truthful |
| 6. How to use | 3:2 | 1536 x 1024 | Steps, setup, usage, care, or assembly |
| 7. Variants or family shot | 3:2 | 1536 x 1024 | Product family, colors, sizes, compatible products |
| 8. Brand endorsement | 21:9 | 2388 x 1024 | Brand story, assurance, certifications, or trust signals |

A+ design rules:

- Embedded text must be larger than 30 pt because Amazon compresses images.
- Keep key content away from the outer 5% safe-margin area.
- Maintain narrative continuity across modules.
- Use one coherent visual system for colors, fonts, icons, and image treatment.
- Do not invent certifications, data, awards, ingredients, or performance claims.

## Conversion Heuristics

Use these as prioritization heuristics, not guaranteed outcomes:

- Lifestyle scenes often improve shopper understanding and purchase confidence.
- Infographics help communicate benefits quickly on mobile.
- Detail close-ups help convey quality and reduce uncertainty.
- A fuller 7-image set generally outperforms sparse 3-4 image sets when images are clear and non-repetitive.

Do not present conversion percentages as factual guarantees unless the user provides a verified source.

## Consistency Rules

- Main image first: establish product identity and baseline appearance.
- Reference the main image for all secondary images.
- Keep product color, material, shape, proportions, details, and accessories consistent.
- Keep design style, background approach, palette, typography, and icon style unified.
- Do not add unprovided product features, bundle items, or claims.

## User Alignment Prompts

Use concise questions only when needed:

- "您需要完整套图（主图+副图+A+），还是仅产品图或仅A+页面？"
- "请提供产品图片或描述，我会先建立主图视觉基准。"
- "产品的核心卖点是什么？我会据此设计信息图。"
- "目标用户和使用场景是什么？我会据此设计场景图。"
- "主图已完成，接下来优先做信息图、场景图、细节图，还是尺寸图？"

## Iteration Prompts

When the user is dissatisfied, diagnose with targeted questions:

- "需要调整主图还是副图？"
- "信息图中的卖点文字需要改成哪些表达？"
- "场景图的使用环境是否符合目标用户？"
- "是否有竞品图或品牌参考图可以对齐风格？"

## Final Review Checklist

Before presenting completion, verify:

- Main image follows pure-white, no-text, product-only rules.
- Product identity is consistent across all images.
- Text is mobile-readable and not crowded.
- Claims are truthful and supported by provided information.
- A+ modules use safe margins and coherent storytelling.
- Image count and output scope match the user's request.
