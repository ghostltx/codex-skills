import argparse
import csv
import html
import json
import re
import sys
import urllib.request
from pathlib import Path
from urllib.parse import urlparse


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 Chrome/120 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=40) as resp:
        return resp.read()


def text_fetch(url: str) -> str:
    return fetch(url).decode("utf-8", errors="replace")


def asin_from_url(url: str) -> str:
    patterns = [
        r"/dp/([A-Z0-9]{10})",
        r"/gp/aw/d/([A-Z0-9]{10})",
        r"/gp/product/([A-Z0-9]{10})",
        r"[/&?]pd_rd_i=([A-Z0-9]{10})",
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    raise ValueError("Could not identify ASIN from URL")


def clean_text(value: str) -> str:
    if not value:
        return ""
    value = re.sub(r"<br\s*/?>", "\n", value)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    value = value.replace("\\u002F", "/").replace("\\/", "/")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def first_group(text: str, pattern: str) -> str:
    match = re.search(pattern, text, re.S)
    return clean_text(match.group(1)) if match else ""


def extract_image_urls(page: str) -> list[str]:
    initial_urls = extract_color_images_initial(page)
    if initial_urls:
        return initial_urls

    urls: list[str] = []
    for pattern in [
        r'"hiRes":"(https:[^"]+)"',
        r'"large":"(https:[^"]+)"',
        r'data-old-hires="([^"]+)"',
    ]:
        for match in re.finditer(pattern, page):
            url = match.group(1).replace("\\u002F", "/").replace("\\/", "/")
            if "m.media-amazon.com/images/I/" in url and url not in urls:
                urls.append(url)
    return urls


def extract_color_images_initial(page: str) -> list[str]:
    marker = "'colorImages': { 'initial': "
    start = page.find(marker)
    if start < 0:
        return []
    pos = start + len(marker)
    if pos >= len(page) or page[pos] != "[":
        return []
    depth = 0
    in_str = False
    esc = False
    end = None
    for index, char in enumerate(page[pos:], start=pos):
        if in_str:
            if esc:
                esc = False
            elif char == "\\":
                esc = True
            elif char == '"':
                in_str = False
        else:
            if char == '"':
                in_str = True
            elif char == "[":
                depth += 1
            elif char == "]":
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
    if end is None:
        return []
    try:
        gallery = json.loads(page[pos:end])
    except json.JSONDecodeError:
        return []
    urls: list[str] = []
    for item in gallery:
        if not isinstance(item, dict):
            continue
        url = item.get("hiRes") or item.get("large")
        if url and "m.media-amazon.com/images/I/" in url and url not in urls:
            urls.append(url)
    return urls


def download_images(urls: list[str], out_dir: Path) -> list[dict]:
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, url in enumerate(urls, start=1):
        suffix = Path(urlparse(url).path).suffix or ".jpg"
        if suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
            suffix = ".jpg"
        path = out_dir / f"{index:02d}{suffix}"
        data = fetch(url)
        path.write_bytes(data)
        rows.append({"index": index, "file": path.name, "url": url, "bytes": len(data)})
    return rows


def extract_reviews(page: str) -> list[dict]:
    review_divs = list(re.finditer(r'<div id="(R[A-Z0-9]+)"[^>]*data-hook="review"', page))
    reviews = []
    for index, match in enumerate(review_divs):
        review_id = match.group(1)
        start = match.start()
        if index < len(review_divs) - 1:
            end = review_divs[index + 1].start()
        else:
            footer = page.find("reviews-medley-footer", start)
            end = footer if footer > start else min(len(page), start + 22000)
        block = page[start:end]
        plain = clean_text(block)
        name = first_group(block, r'<span class="a-profile-name">([\s\S]*?)</span>')
        rating = first_group(block, r'<span class="a-icon-alt">([0-9.]+ out of 5 stars)</span>')
        date = first_group(block, r"(Reviewed in [\s\S]*? on [A-Za-z]+ \d{1,2}, \d{4})")
        variant = first_group(
            block,
            r'data-hook="product-variation-attributes"[^>]*>([\s\S]*?)(?:Verified Purchase|</div>)',
        )
        title = ""
        if name and rating and date:
            prefix = r"^\s*" + re.escape(name) + r"\s+" + re.escape(rating) + r"\s+(.*?)\s+" + re.escape(date)
            title = first_group(plain, prefix)
        if not title:
            title = first_group(block, r'data-hook="review-title"[\s\S]*?</i>\s*([\s\S]*?)\s*</a>')
        body = first_group(
            plain,
            r"Full content visible, double tap to read brief content\.\s*(.*?)\s*Read more Read less",
        )
        if not body:
            body = first_group(plain, r"Verified Purchase\s*(.*?)\s*Read more Read less")
        if review_id or name or title or body:
            reviews.append(
                {
                    "ReviewId": review_id,
                    "Reviewer": name,
                    "Rating": rating,
                    "Title": title,
                    "Date": date,
                    "Variant": variant,
                    "VerifiedPurchase": "Verified Purchase" in plain,
                    "Body": body,
                }
            )
    return reviews


def write_reviews(reviews: list[dict], out_dir: Path, asin: str) -> None:
    csv_path = out_dir / f"{asin}_reviews_embedded.csv"
    json_path = out_dir / f"{asin}_reviews_embedded.json"
    txt_path = out_dir / f"{asin}_reviews_embedded.txt"
    fields = ["ReviewId", "Reviewer", "Rating", "Title", "Date", "Variant", "VerifiedPurchase", "Body"]
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(reviews)
    json_path.write_text(json.dumps(reviews, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        f"ASIN: {asin}",
        "Source: Amazon product detail page embedded Top reviews block.",
        "Note: This is not guaranteed full corpus if Amazon review pagination is blocked.",
        f"Count: {len(reviews)}",
        "",
    ]
    for index, review in enumerate(reviews, start=1):
        lines.append(f"--- Review {index:02d} ---")
        for field in fields:
            lines.append(f"{field}: {review.get(field, '')}")
        lines.append("")
    txt_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Download Amazon full-view gallery images and optional embedded reviews.")
    parser.add_argument("url", help="Amazon product page URL")
    parser.add_argument("--out", help="Output directory. Defaults to Desktop/<ASIN>.")
    parser.add_argument("--count", type=int, help="Number of full-view gallery images to keep.")
    parser.add_argument("--reviews", action="store_true", help="Export accessible embedded reviews.")
    parser.add_argument("--save-links", action="store_true", help="Save image URL list. Use only if requested.")
    args = parser.parse_args()

    asin = asin_from_url(args.url)
    out_dir = Path(args.out) if args.out else Path.home() / "Desktop" / asin
    page = text_fetch(f"https://www.amazon.com/dp/{asin}?th=1")
    image_urls = extract_image_urls(page)
    if args.count is not None:
        image_urls = image_urls[: args.count]
    if not image_urls:
        raise RuntimeError("No Amazon gallery image URLs found")
    rows = download_images(image_urls, out_dir)
    if args.save_links:
        (out_dir / f"{asin}_image_urls.txt").write_text(
            "\n".join(f"{row['index']:02d}. {row['url']}" for row in rows),
            encoding="utf-8",
        )
    review_count = 0
    if args.reviews:
        reviews = extract_reviews(page)
        write_reviews(reviews, out_dir, asin)
        review_count = len(reviews)
    print(json.dumps({"asin": asin, "folder": str(out_dir), "images": len(rows), "reviews": review_count}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
