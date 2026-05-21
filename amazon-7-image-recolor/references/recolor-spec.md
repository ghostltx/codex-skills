# Recolor Specification

## Product Detection

Treat all repeated sellable-product appearances as target surfaces:

- Main hero product.
- Folded or alternate-position product views.
- Close-up feature panels.
- Lifestyle-scene product instances.
- Thumbnail-scene product instances.
- Paired products and matching companion products.
- Accessories that are permanently integrated into the product body, such as attached cup holders.

Do not recolor independent props unless the user explicitly asks:

- Drinks, glass cups, pillows, books, plants, rugs, flooring, house exteriors, people, clothing, phones, fire pits, umbrellas, and decor.
- Text, icons, borders, arrows, measurement lines, labels, and badges printed as graphic layout elements.
- Metal hardware such as screws, chains, hinges, and nameplates unless the user says the hardware should change too.

Blue source products need special handling when the target is black:

- Treat blue-painted highlights, pale blue reflected light, blue rim light, and blue anti-aliased edges on the sellable product as product color that must be changed.
- Do not treat blue non-product elements as product color, especially denim, blue graphic icons, blue text, sky, glass reflections, and background decor.
- In lifestyle scenes where the product overlaps people or clothing, use a semantic edit/image-to-image workflow instead of broad pixel thresholds if local masking creates artifacts.

## Target Finish Analysis

Infer the target finish from the target product image:

- Dominant product color and undertone.
- Bright highlight color on edges and broad planes.
- Deepest shadow color in recesses.
- Grain, weave, speckle, or surface pattern contrast.
- Gloss, matte, satin, plastic, wood-look, metal, fabric, or painted finish behavior.
- Whether the finish needs visible texture after recoloring.

Avoid reducing the target finish to a flat HEX color unless the user explicitly asks for flat color.

## Strong Prompt Add-Ons

Use these lines for strict preservation tasks:

```text
Keep the original source image pixel layout and graphic design intact.
Only change the visible color/material finish of the sellable product and matching companion products.
Preserve all existing material texture, grain direction, molded detail, bevels, seams, screw positions, label positions, shadows, highlights, reflections, and occlusions.
Leave all text, icons, measurement graphics, backgrounds, people, props, drinks, pillows, plants, and metal hardware unchanged.
```

Use these lines when matching a black wood-grain target:

```text
Match a realistic charcoal black wood-grain finish, with visible gray-black grain lines, satin surface sheen, subtle edge highlights, dark recessed shadows, and the same underlying source texture.
Do not create pure featureless black. Do not erase wood grain. Do not over-darken the product until details disappear.
```

Use these lines when converting a blue product to black:

```text
Remove every blue paint remnant, blue highlight, blue reflection, blue rim light, and blue anti-aliased product edge from the sellable product surfaces only.
Protect all blue non-product elements: denim, blue text, blue icons, sky, glass reflections, shadows on props, and background decor must remain unchanged.
```

For lifestyle images with people or close product-prop overlap, add object-specific protection:

```text
Preserve the person, face, hair, clothing, blue jeans, shoes, phone, pillows, books, cups, drinks, plants, patio, house, and background exactly. Do not recolor jeans or props.
```

## Negative Prompt Concepts

Reject these failure modes in the prompt or QA pass:

- Flat solid recolor.
- Lost wood grain or blurred texture.
- Changed chair shape, slat count, cup holder shape, folded mechanism, or table structure.
- Damaged English text, icons, dimension numbers, or measurement lines.
- Recolored cups, pillows, people, plants, rugs, wall, floor, or background.
- Recolored denim or other blue non-product elements while trying to remove blue product highlights.
- Remaining blue product paint, blue edge highlights, blue reflections, or blue anti-aliased edges after a blue-to-black recolor.
- Recolored metal screws, chains, hinges, or nameplates when not requested.
- Inconsistent finish between source images.
- Target reference geometry copied into the source scene.
- New props, new product parts, extra legs, missing boards, or warped edges.
- Mask artifacts such as blocky patches, gray smears, or dark halos around people, books, plants, glass, or other props.

## QA Checklist

Review every output image:

- The product and all companion products match the target reference finish.
- The original source composition, crop, and layout are unchanged.
- Wood grain, texture, highlights, shadows, and surface sheen remain visible.
- No blue product highlights, blue paint, blue reflections, or blue edge halos remain when the target finish is black.
- Screws, chains, badges, cup glass, drinks, pillows, people, and backgrounds are not unintentionally recolored.
- Blue non-product elements such as denim, blue icons, and blue text are preserved.
- Text and icons remain readable and unchanged.
- Multiple product instances in the same image share one consistent finish.
- The seven-image set reads as one coherent color variant.
