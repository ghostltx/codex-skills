---
name: Amazon Images + Reviews
description: Use when the user provides an Amazon product page URL and asks to extract or download product images, Click to see full view images, main gallery images, or product reviews. Downloads only the current variant's Click to see full view gallery images by default, not variant/recommendation/A+ images, and can optionally export embedded reviews.
---

# Amazon Images + Reviews

Use this skill for Amazon product-page extraction.

## Default Behavior

- Input: one Amazon product page URL.
- Output folder: Desktop folder named by ASIN unless the user gives a folder name.
- Images: download only the current product variant's `Click to see full view` gallery images.
- Filenames: `01.jpg`, `02.jpg`, ...
- Do not save image link TXT/CSV files unless the user explicitly asks.
- Do not download hidden variant galleries, recommendation images, A+ content, comparison images, or other page assets.
- If the user says "评论", "reviews", or asks for comments/reviews, also export accessible embedded reviews.

## Workflow

1. Identify the ASIN from the URL.
2. Fetch the product detail page with a browser-like user agent.
3. Extract the current variant gallery from the page's `colorImages.initial` data.
4. Download exactly the `hiRes` URLs in `colorImages.initial`; this is the working source of truth for the `Click to see full view` image set and count.
   - Do not infer the count from the product-page thumbnail `+` label. That label can undercount or represent only hidden thumbnails.
   - Do not use a broad page-wide `hiRes`/`large` scan as the primary source because it may include variants, recommendation images, A+ images, and other assets.
   - Use browser clicking only as a verification fallback when `colorImages.initial` is missing or ambiguous.
   - If both `colorImages.initial` and browser verification are blocked, explain the limitation before falling back to leading page-gallery URLs.
5. Download images into the target folder.
6. If reviews are requested, export only accessible embedded product-page reviews and clearly label them as not guaranteed full corpus if Amazon review pagination is blocked.

## Recommended Script

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
