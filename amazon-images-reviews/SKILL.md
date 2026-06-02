---
name: Amazon Images + Reviews
description: Use when the user provides an Amazon ASIN or product page URL and asks to collect Amazon listing assets, main gallery images, A+ images, Click to see full view images, or product reviews. Creates a Desktop folder named by ASIN, downloads current-variant main images and A+ images, and can export full SellerSprite reviews to Excel.
---

# Amazon Images + Reviews

Use this skill for Amazon product-page extraction and ASIN collection packages.

## Default Behavior

- Input: one Amazon ASIN or product page URL.
- Output folder: Desktop folder named by ASIN unless the user gives a folder name.
- Parent ASIN mode: when collecting variants, create a parent folder and one child-ASIN subfolder per variant.
- Main images: download only the current product variant's `Click to see full view` gallery images into `main-images`.
- A+ images: download only large horizontal A+ / enhanced brand content images into `aplus-images`.
  - Keep A+ images only when image width is greater than `1000px`.
  - Keep horizontal A+ images only: width must be greater than height.
  - Typical valid A+ image size is around `1460x600`.
  - Do not save small icons, thumbnails, square images, comparison-table badges, spacer images, or other small A+ assets.
- Reviews: export full SellerSprite reviews to Excel as `<ASIN>-reviews.xlsx` when a SellerSprite secret key is available.
- On successful SellerSprite review export, report the SellerSprite MCP review call count.
- Do not create manifest JSON files by default.
- Do not save image link TXT/CSV files unless the user explicitly asks.
- Do not download hidden variant galleries, recommendation images, comparison images, or unrelated page assets.
- If SellerSprite is unavailable, optionally export accessible embedded product-page reviews and label them as partial.

## Workflow

1. Identify the ASIN from the input. If the user gives only an ASIN, build `https://www.amazon.com/dp/<ASIN>`.
2. Fetch the product detail page with a browser-like user agent.
3. Extract the current variant gallery from the page's `colorImages.initial` data.
4. Download exactly the `hiRes` URLs in `colorImages.initial`; this is the working source of truth for the `Click to see full view` image set and count.
   - Do not infer the count from the product-page thumbnail `+` label. That label can undercount or represent only hidden thumbnails.
   - Do not use a broad page-wide `hiRes`/`large` scan as the primary source because it may include variants, recommendation images, A+ images, and other assets.
   - Use browser clicking only as a verification fallback when `colorImages.initial` is missing or ambiguous.
   - If both `colorImages.initial` and browser verification are blocked, explain the limitation before falling back to leading page-gallery URLs.
5. Extract A+ images from the product-page A+ / enhanced brand content regions, then filter by real image dimensions before saving.
   - Save only large horizontal images with width greater than `1000px`.
   - Require width greater than height, so square images such as `2000x2000` are not treated as A+ banners.
   - Treat small images as noise even if they are inside the A+ container.
6. Fetch all SellerSprite reviews through direct MCP HTTP `tools/call` and export them to Excel.
   - Count one MCP call for each `review` tool page request.
   - Include the MCP call count in the terminal success JSON and in the Excel `Summary` sheet.
7. If SellerSprite is not authorized or missing a key, continue image export and report the review blocker.

## Parent ASIN / Variant Workflow

When the user gives a parent ASIN and wants every color or variant collected separately, use this folder structure:

```text
C:\Users\ghost\Desktop\<父ASIN>\
  <子ASIN-1>\
    main-images\
    aplus-images\
    <子ASIN-1>-reviews.xlsx

  <子ASIN-2>\
    main-images\
    aplus-images\
    <子ASIN-2>-reviews.xlsx

  <子ASIN-3>\
    main-images\
    aplus-images\
    <子ASIN-3>-reviews.xlsx
```

Rules:

- The parent ASIN folder is only a container.
- Each child ASIN gets its own folder.
- Do not mix images from multiple child ASINs.
- Do not merge multiple child ASIN reviews into one Excel file.
- Do not create `manifest.json` files by default.
- Final reply must list each child ASIN with main image count, A+ image count, Excel review count, and MCP review call count.

Use `--parent-asin` plus one or more `--child-asin` values when the child ASIN list is known:

```powershell
python C:\Users\ghost\.codex\skills\amazon-images-reviews\scripts\collect_asin_package.py --parent-asin B0PARENT123 --child-asin B0CHILD001 --child-asin B0CHILD002 --secret-key "SELLERSPRITE_KEY"
```

Automatic child-ASIN discovery should be used only when the ASIN list can be verified from Amazon page data or a SellerSprite endpoint. If child ASIN discovery is incomplete, report the blocker instead of guessing.

## Recommended Script

Use `scripts/collect_asin_package.py` for the future default ASIN workflow.

Examples:

```powershell
python C:\Users\ghost\.codex\skills\amazon-images-reviews\scripts\collect_asin_package.py B0C9STFGW1 --secret-key "SELLERSPRITE_KEY"
```

Using an environment variable:

```powershell
$env:SELLERSPRITE_SECRET_KEY="SELLERSPRITE_KEY"
python C:\Users\ghost\.codex\skills\amazon-images-reviews\scripts\collect_asin_package.py B0C9STFGW1
```

Output:

```text
C:\Users\ghost\Desktop\<ASIN>\
  main-images\
  aplus-images\
  <ASIN>-reviews.xlsx
```

Use `--skip-reviews` for image-only collection, `--skip-aplus` for gallery-only collection, `--max-review-pages` for a quick review sample, and `--save-manifest` only when the user explicitly asks for a manifest.

## Legacy Script

Use `scripts/extract_amazon.py` for repeatable extraction.

Examples:

```powershell
python C:\Users\ghost\.codex\skills\amazon-images-reviews\scripts\extract_amazon.py "https://www.amazon.com/dp/B0B8FXBHJ9" --out "C:\Users\ghost\Desktop\B0B8FXBHJ9" --count 7
```

With embedded reviews:

```powershell
python C:\Users\ghost\.codex\skills\amazon-images-reviews\scripts\extract_amazon.py "https://www.amazon.com/dp/B0B8FXBHJ9" --out "C:\Users\ghost\Desktop\B0B8FXBHJ9" --count 7 --reviews
```

Notes:

- `--count` is optional, but use it when the user has confirmed the full-view count.
- The script does not write link-list files by default.
- Use `--save-links` only when the user explicitly requests a link list.
