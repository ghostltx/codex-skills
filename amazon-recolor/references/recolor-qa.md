# Recolor QA

## Coverage

Check that every source image in the first N images has exactly one intended output unless the user asked for variants.

Check for accidental duplicates:

- Same source image submitted twice.
- Different filenames showing the same layout.
- Output count matching N only because a duplicate hides a missing source.

## Product Scope

Recolor:

- Main product.
- Repeated product appearances.
- Folded or alternate-position views.
- Close-up feature panels.
- Lifestyle-scene product instances.
- Matching companion products such as side tables, paired chairs, folded versions, or thumbnails.
- Built-in product accessories such as cup holders.

Protect:

- Text, icons, borders, arrows, measurement lines, labels, and badges.
- People, faces, hair, clothing, shoes, phones, pillows, books, cups, drinks, plants, patio, house, sky, rugs, decor, and background.
- Metal screws, chains, hinges, and nameplates unless the user explicitly asks to change hardware.

## Color Quality

Reject outputs with:

- Original color remnants on product surfaces.
- Colored edge halos or anti-aliased borders.
- Reflected original color on product planes.
- Inconsistent target finish across images.
- Flat fill that erases wood grain, molded texture, seams, bevels, or water droplets.
- Reference layout or reference product geometry copied into the source image.

For pure white, reject:

- Cream, beige, gray-white, yellow-white, blue-white, dirty white, or off-white drift.
- Overexposed blank product surfaces with no visible texture.
- Background or props accidentally brightened to compensate for the white product.

For black, reject:

- Featureless black blocks with lost grain, seams, screws, bevels, or molded detail.
- Over-darkened recesses where product structure disappears.
- Blue, green, purple, or original-color edge contamination.
- Blackened hardware, labels, text, icons, props, or background objects that should remain unchanged.

For natural wood or walnut, reject:

- Random or wallpaper-like grain unrelated to board direction.
- Plastic-looking painted wood texture.
- Oversaturated orange, red, yellow, purple, or muddy brown drift not present in the reference.
- Recolored flooring, decking, background furniture, baskets, soil, or other non-product wood/brown objects.

For gray, reject:

- Unwanted blue, green, purple, yellow, or dirty color cast.
- Flat chalky gray with no material detail.
- Metallic silver behavior unless the reference is metallic.
- Recolored sky, clothing, shadows, props, text, or icons.

## Final Report

Report:

- Output folder.
- Which outputs map to which source image.
- Duplicate, failed, or timed-out tasks.
- Any visible quality risks that still need regeneration.
