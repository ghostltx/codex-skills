#!/usr/bin/env python3
"""OpenLux GPT-Image client (stdlib only). Text-to-image: /images/generations; edit: /images/edits.
Key from env "openlux" (falls back to OPENLUX_KEY). Never prints the key."""
import argparse, base64, json, math, mimetypes, os, re, sys, time, uuid, urllib.request, urllib.error
from pathlib import Path

BASE = "https://api.openlux.ai/v1"
MODEL = "gpt-image-2.5-sunburst-c"
BUDGET = 2880 * 2880  # ~8.29 MP
MAX_SIDE = 3840
FORMATS = {"png", "jpeg", "webp"}
RE_LORA = re.compile(r"<lora:[^>]*>", re.IGNORECASE)

def auto_size(w, h):
    r = w / h
    W = math.sqrt(BUDGET * r); H = W / r
    s = min(1.0, MAX_SIDE / max(W, H)); W *= s; H *= s
    W = max(16, int(W // 16) * 16); H = max(16, int(H // 16) * 16)
    return f"{W}x{H}"

def image_dims(p):
    d = Path(p).read_bytes()[:65536]
    if d[:8] == b"\x89PNG\r\n\x1a\n":
        return int.from_bytes(d[16:20], "big"), int.from_bytes(d[20:24], "big")
    if d[:4] == b"RIFF" and d[8:12] == b"WEBP":
        c = d[12:16]
        if c == b"VP8X": return 1 + int.from_bytes(d[24:27], "little"), 1 + int.from_bytes(d[27:30], "little")
        if c == b"VP8 ": return int.from_bytes(d[26:28], "little") & 0x3FFF, int.from_bytes(d[28:30], "little") & 0x3FFF
        if c == b"VP8L":
            b = int.from_bytes(d[21:25], "little"); return (b & 0x3FFF) + 1, ((b >> 14) & 0x3FFF) + 1
    if d[:2] == b"\xff\xd8":
        data = Path(p).read_bytes(); i = 2
        while i < len(data):
            if data[i] != 0xFF: i += 1; continue
            m = data[i + 1]
            if m in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                return int.from_bytes(data[i + 7:i + 9], "big"), int.from_bytes(data[i + 5:i + 7], "big")
            i += 2 + int.from_bytes(data[i + 2:i + 4], "big")
    return None

def multipart(fields, files):
    b = uuid.uuid4().hex; out = bytearray()
    for k, v in fields.items():
        out += f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    for k, p in files:
        mt = mimetypes.guess_type(p)[0] or "application/octet-stream"
        out += f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{Path(p).name}\"\r\nContent-Type: {mt}\r\n\r\n".encode()
        out += Path(p).read_bytes() + b"\r\n"
    out += f"--{b}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={b}"

def validate_size(size):
    if size == "auto":
        return
    m = re.fullmatch(r"(\d+)x(\d+)", size)
    if not m:
        raise ValueError("--size must be auto or WIDTHxHEIGHT")
    w, h = map(int, m.groups())
    if w % 16 or h % 16:
        raise ValueError("width and height must be multiples of 16")
    if w < 16 or h < 16 or w > MAX_SIDE or h > MAX_SIDE:
        raise ValueError(f"each side must be between 16 and {MAX_SIDE}")
    if not (1 / 3 <= w / h <= 3):
        raise ValueError("aspect ratio must be between 1:3 and 3:1")
    if not (655360 <= w * h <= BUDGET):
        raise ValueError(f"pixel count must be between 655360 and {BUDGET}")

def main():
    try: sys.stdout.reconfigure(encoding="utf-8")
    except Exception: pass
    ap = argparse.ArgumentParser(description="OpenLux image generate/edit")
    ap.add_argument("--prompt"); ap.add_argument("--prompt-file")
    ap.add_argument("--image", action="append", default=[], help="local reference image(s) -> edit mode")
    ap.add_argument("--mask", default="")
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--size", default="auto", help="WxH; 'auto' = match first image ratio at ~8.29MP, or 2880x2880 for t2i")
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--quality", default="high")
    ap.add_argument("--output-format", default="png")
    ap.add_argument("--response-format", choices=("auto", "url", "b64_json"), default="auto", help="auto uses b64_json for gpt-image-2.6-sunburst-c and url otherwise")
    ap.add_argument("--out-dir", default=str(Path.cwd() / "openlux-output"))
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--dry-run", action="store_true", help="show request without sending")
    a = ap.parse_args()
    prompt = a.prompt or (Path(a.prompt_file).read_text(encoding="utf-8") if a.prompt_file else None)
    if not prompt: ap.error("--prompt or --prompt-file required")
    size = a.size
    if size == "auto":
        dims = image_dims(a.image[0]) if a.image else None
        size = auto_size(*dims) if dims else "2880x2880"
    validate_size(size)
    if a.output_format not in FORMATS:
        ap.error(f"--output-format must be one of: {', '.join(sorted(FORMATS))}")
    if not 1 <= a.n <= 10:
        ap.error("--n must be between 1 and 10")
    key = (os.environ.get("openlux") or os.environ.get("OPENLUX") or os.environ.get("OPENLUX_KEY") or "").strip()
    prompt = RE_LORA.sub("", prompt).strip()
    response_format = a.response_format
    if response_format == "auto":
        response_format = "b64_json" if a.model == "gpt-image-2.6-sunburst-c" else "url"
    fields = {"model": a.model, "prompt": prompt, "n": str(a.n), "size": size, "quality": a.quality, "output_format": a.output_format, "response_format": response_format}
    mode = "edit" if a.image else "generate"
    if a.dry_run:
        print(json.dumps({"mode": mode, "fields": {**fields, "prompt": prompt[:80]}, "images": a.image, "key_set": bool(key)}, ensure_ascii=False, indent=1)); return
    if not key: sys.exit("API key not set: define environment variable openlux")
    if mode == "edit":
        files = [("image[]" if len(a.image) > 1 else "image", p) for p in a.image]
        if a.mask: files.append(("mask", a.mask))
        body, ct = multipart(fields, files); url = BASE + "/images/edits"
    else:
        f = dict(fields); f["n"] = a.n
        body, ct = json.dumps(f).encode(), "application/json"; url = BASE + "/images/generations"
    req = urllib.request.Request(url, data=body, headers={"Authorization": "Bearer " + key, "Content-Type": ct}, method="POST")
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=a.timeout) as r: res = json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read()[:800].decode('utf-8', 'replace')}")
    request_seconds = time.perf_counter() - started
    base = Path(a.out_dir) / time.strftime("openlux_%Y%m%d_%H%M%S"); out = base; k = 2
    while True:
        try: out.mkdir(parents=True, exist_ok=False); break
        except FileExistsError: out = Path(f"{base}_{k}"); k += 1
    saved = []
    download_started = time.perf_counter()
    for i, d in enumerate(res.get("data") or []):
        p = out / f"image_{i + 1}.{a.output_format}"
        if d.get("b64_json"): p.write_bytes(base64.b64decode(d["b64_json"]))
        elif d.get("url"):
            with urllib.request.urlopen(d["url"], timeout=300) as r: p.write_bytes(r.read())
        else: continue
        saved.append(str(p))
    download_seconds = time.perf_counter() - download_started
    total_seconds = time.perf_counter() - started
    print(json.dumps({"mode": mode, "model": a.model, "size": size, "response_format": response_format, "request_seconds": round(request_seconds, 1), "download_seconds": round(download_seconds, 1), "total_seconds": round(total_seconds, 1), "seconds": round(total_seconds, 1), "saved": saved, "usage": res.get("usage")}, ensure_ascii=False, indent=1))
    if not saved: sys.exit("No image in response: " + json.dumps(res)[:800])

if __name__ == "__main__": main()
