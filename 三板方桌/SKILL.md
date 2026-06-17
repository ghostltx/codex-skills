---
name: 三板方桌
description: Use when the user mentions 三板方桌, 单层方桌, 双层方桌, 三板单层方桌, 三板双层方桌, or needs the recorded product specs, material, load capacity, dimensions, texture, or ecommerce/image-generation prompt rules for this HIPS three-plank square side table product.
---

# 三板方桌 Product Category Specs

`三板方桌` is a product category, not one single product/SKU.
This category has two product types:

- `三板单层方桌`
- `三板双层方桌`

When the user says `三板方桌`, treat it as the parent category and ask/use the relevant sub-type if needed.
When the user says `三板单层方桌` or `单层方桌`, use the single-layer version.
When the user says `三板双层方桌` or `双层方桌`, use the double-layer version.

## Asset Usage

- Reference images are stored in `assets/`.
- Before generating prompts, judging generated images, recoloring, or resolving visual details for this product, inspect the relevant asset images first when visual tools are available.
- Treat written rules in this file as hard constraints. Use asset images as visual references for color, structure, proportions, screw placement, texture, and rail placement.
- Do not rely on external temporary source paths when the same image exists in `assets/`; use the copied asset file instead.

## Shared Product Facts

- Product family/category: 三板方桌 / three-plank square side table category.
- Product category contains two types: 三板单层方桌 and 三板双层方桌.
- Material: HIPS.
- Shared top design: both 三板单层方桌 and 三板双层方桌 have exactly three parallel planks on the top surface.
- Overall dimensions from current images: 16.1 x 12.2 x 16.7 in.
- Load capacity from current images: 200 lbs.
- Confirmed color set: 6 colors total: white, black, deep blue, gray, lake blue / hulan, and teak / youmu.
- Approximate color values from current reference renders, for prompts and visual matching only:
  - White: `#DADADA`
  - Black: `#191919`
  - Deep blue: `#193E6E`
  - Gray: `#757575`
  - Lake blue / hulan: `#65A6B6`
  - Teak / youmu: `#AB7A40`
- Treat these HEX values as approximate render references, not factory color-card values.
- Fasteners shown: visible round silver screw/bolt heads on the side posts.
- Structure: four straight legs/posts, rectangular rail frame, square/rectangular tabletop proportions.
- Texture lock: use an irregular fine raised-and-recessed stripe texture, like subtle uneven linear HIPS grain. The texture is not smooth flat plastic, not wood knots, not woven rattan, not marble, and not a regular perfectly uniform ribbed pattern.
- Three-plank tabletop lock: keep exactly 3 wide top planks with two narrow recessed grooves between them. Do not add extra tabletop boards or merge the top into one flat slab unless the user explicitly changes the design.
- Short-side rail lock: for every three-plank board layer, the short sides have a horizontal rail directly below the planks; the long sides do not have a horizontal rail directly below that board layer. Do not add a long-side apron/rail along the long edge under the top board or lower shelf board.

## 三板单层方桌

- Product type: single-layer version / no lower shelf.
- Category relationship: one of the two products under the 三板方桌 category.
- Overall dimensions: 16.1 in length x 12.2 in depth x 16.7 in height.
- Load capacity: 200 lbs.
- Structure: one top tier only, with lower side rails/crossbars for support but no usable second shelf.
- Do not describe or render a storage shelf in the middle/lower area for the single-layer version.
- The six color/detail images supplied after skill creation are single-layer方桌 references only.
- Single-layer confirmed colors: white, black, deep blue, gray, lake blue / hulan, and teak / youmu.
- Single-layer structure detail: under the top planks, include horizontal support rails on the short sides only. Keep the long sides open directly under the tabletop with no long horizontal apron/rail below the planks.

## 三板双层方桌

- Product type: double-layer version / lower shelf version.
- Category relationship: one of the two products under the 三板方桌 category.
- Overall dimensions: 16.1 in length x 12.2 in depth x 16.7 in height.
- Load capacity: 200 lbs.
- Structure: same as the single-layer方桌 except it has one additional lower three-plank board layer.
- Lower shelf: three-plank style shelf aligned with the product frame, placed above the lower rails and between the legs.
- Both board layers follow the same rail rule: short sides have horizontal rails below the planks, long sides do not have horizontal rails below the planks.
- Do not add a long-side apron/rail directly under either the top tabletop or the lower shelf.
- Do not render the double-layer version as a fully closed cabinet, drawer unit, basket shelf, mesh shelf, or solid one-piece lower slab.

## Image Prompt Guidance

- For product generation, preserve the HIPS three-plank square table structure and the irregular raised/recessed fine stripe texture on tabletop, legs, and rails.
- For color-specific single-layer images, use one of the 6 confirmed colors: white, black, deep blue, gray, lake blue / hulan, or teak / youmu.
- For dimension images, use inch labels from current references: `16.1"`, `12.2"`, `16.7"`, and load callout `200 LBS`.
- For lifestyle scale images, keep the table at small side-table/stool height: 16.7 in high. Do not scale it to dining-table, counter-height, or tall workbench proportions.
- For the single-layer version, keep the space below the tabletop visibly open aside from support rails.
- For the single-layer version, do not place a horizontal rail directly below the tabletop on the long side. Only the short side beneath the tabletop has the upper horizontal rail.
- For the double-layer version, include one lower three-plank shelf and keep it visually distinct from the top tier.
- For the double-layer version, the top layer and lower shelf layer both have short-side rails only. Keep both long edges open with no long-side horizontal apron/rail directly under the planks.
- Reject generated images if they show: incorrect board count on the tabletop; missing HIPS fine stripe texture; wood-knot texture; smooth featureless plastic; rattan/wicker weave; shelf added to the single-layer version; missing shelf on the double-layer version; long-side horizontal apron/rail directly under the tabletop; missing short-side upper rail; altered dimensions; load capacity other than 200 lbs; or a table height that visually reads much taller than 16.7 in.

## Current Reference Images

- Single-layer white dimension reference: `assets/single-layer-white-dimension.jpg`
- Double-layer white dimension reference: `assets/double-layer-white-dimension.jpg`
- Texture reference: user-provided image #3 in the creation thread; irregular raised/recessed fine stripe HIPS texture.
- Single-layer black reference: `assets/single-layer-black.jpg`
- Single-layer deep blue reference: `assets/single-layer-deepblue.jpg`
- Single-layer gray reference: `assets/single-layer-gray.jpg`
- Single-layer lake blue / hulan reference: `assets/single-layer-hulan.jpg`
- Single-layer teak / youmu reference: `assets/single-layer-youmu.jpg`
- Single-layer short-side upper rail detail reference: `assets/single-layer-hulan-short-side-rail.jpg`
- Double-layer teak generated reference: `assets/double-layer-youmu.jpg`

## Response Guidance

- If the user asks for known specs, answer with the recorded dimensions, material, load capacity, type, and texture.
- If the user asks for ecommerce copy, treat both variants as the same size and load-bearing capacity unless newer user data updates the skill.
- If the user provides new data later, update this skill directly and keep the newest user-provided values as authoritative.
