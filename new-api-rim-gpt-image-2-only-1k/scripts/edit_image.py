#!/usr/bin/env python3
"""Edit images through NewAPI's OpenAI-compatible image edit endpoint."""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import secrets
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_BASE_URL = "http://64.186.244.43:12001"
DEFAULT_MODEL = "「Rim」gpt-image-2"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Edit images with NewAPI.")
    parser.add_argument("--image", required=True, help="Input PNG image path.")
    parser.add_argument("--prompt", help="Edit prompt.")
    parser.add_argument("--prompts-file", help="UTF-8 text file with one edit prompt per line.")
    parser.add_argument("--output-dir", default=".", help="Directory for output files.")
    parser.add_argument("--model", default=os.getenv("NEWAPI_IMAGE_MODEL", DEFAULT_MODEL))
    parser.add_argument("--base-url", default=os.getenv("NEWAPI_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--api-key-env", default="NEWAPI_API_KEYS")
    parser.add_argument("--size", default=os.getenv("NEWAPI_IMAGE_SIZE", "1024x1024"))
    parser.add_argument("--n", type=int, default=1)
    parser.add_argument("--response-format", default="b64_json", choices=["auto", "b64_json", "url"])
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--batch-delay", type=float, default=60.0)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--memory-overload-wait", type=float, default=180.0)
    return parser.parse_args()


def clean_base_url(base_url: str) -> str:
    base_url = base_url.strip().rstrip("/")
    if base_url.endswith("/v1"):
        base_url = base_url[:-3].rstrip("/")
    return base_url


def safe_slug(text: str, max_len: int = 48) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return (slug or "edit")[:max_len].strip("-") or "edit"


def split_api_keys(value: str | None) -> list[str]:
    if not value:
        return []
    return [key.strip() for key in value.split(",") if key.strip()]


def load_api_keys(env_name: str) -> list[str]:
    for name in (env_name, "NEWAPI_API_KEY", "NEW_API_KEY"):
        keys = split_api_keys(os.getenv(name))
        if keys:
            return keys
    return []


def load_prompts(args: argparse.Namespace) -> list[str]:
    prompts: list[str] = []
    if args.prompts_file:
        prompts.extend(
            line.strip()
            for line in Path(args.prompts_file).read_text(encoding="utf-8-sig").splitlines()
            if line.strip()
        )
    if args.prompt:
        prompts.append(args.prompt)
    return prompts


def multipart_body(fields: dict[str, str], files: dict[str, Path]) -> tuple[bytes, str]:
    boundary = f"----codex-newapi-{secrets.token_hex(16)}"
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.append(f"--{boundary}\r\n".encode("utf-8"))
        chunks.append(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("utf-8"))
        chunks.append(str(value).encode("utf-8"))
        chunks.append(b"\r\n")
    for name, path in files.items():
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        chunks.append(f"--{boundary}\r\n".encode("utf-8"))
        chunks.append(
            (
                f'Content-Disposition: form-data; name="{name}"; filename="{path.name}"\r\n'
                f"Content-Type: {content_type}\r\n\r\n"
            ).encode("utf-8")
        )
        chunks.append(path.read_bytes())
        chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(chunks), boundary


def request_edit(url: str, api_key: str, fields: dict[str, str], image_path: Path, timeout: int) -> dict[str, Any]:
    body, boundary = multipart_body(fields, {"image": image_path})
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from NewAPI: {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Could not reach NewAPI: {exc}") from exc


def is_recoverable_platform_error(message: str) -> bool:
    lowered = message.lower()
    return (
        "system_memory_overloaded" in lowered
        or "没有可用token" in message
        or "no available token" in lowered
        or "http 500" in lowered
        or "http 502" in lowered
        or "http 503" in lowered
        or "bad gateway" in lowered
        or "service unavailable" in lowered
    )


def try_keys(operation: str, keys: list[str], call: Any) -> dict[str, Any]:
    errors: list[str] = []
    for index, api_key in enumerate(keys, start=1):
        try:
            response = call(api_key)
            if index > 1:
                print(f"{operation} succeeded with API key #{index}.", file=sys.stderr)
            return response
        except RuntimeError as exc:
            message = str(exc)
            errors.append(f"key #{index}: {message}")
            if "HTTP 401" not in message and "HTTP 403" not in message and "quota" not in message.lower():
                raise
            print(f"{operation} failed with API key #{index}; trying next key if available.", file=sys.stderr)
    raise RuntimeError(f"{operation} failed with all configured API keys. " + " | ".join(errors))


def guess_extension(content_type: str | None, fallback: str = ".png") -> str:
    if not content_type:
        return fallback
    content_type = content_type.split(";", 1)[0].strip()
    return mimetypes.guess_extension(content_type) or fallback


def download_url(url: str, path_without_suffix: Path, timeout: int) -> Path:
    request = urllib.request.Request(url, headers={"User-Agent": "codex-newapi-imagegen/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        output_path = path_without_suffix.with_suffix(guess_extension(response.headers.get("Content-Type")))
        output_path.write_bytes(response.read())
        return output_path


def decode_b64(data: str, output_path: Path) -> Path:
    if "," in data and data.lstrip().startswith("data:"):
        data = data.split(",", 1)[1]
    output_path.write_bytes(base64.b64decode(data))
    return output_path


def save_response(args: argparse.Namespace, endpoint: str, fields: dict[str, str], response: dict[str, Any], output_dir: Path) -> dict[str, Any]:
    data = response.get("data")
    if not isinstance(data, list) or not data:
        raise RuntimeError(f"NewAPI response did not contain image data: {json.dumps(response)[:1000]}")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    slug = safe_slug(fields["prompt"])
    outputs: list[str] = []
    revised_prompts: list[str] = []
    for index, item in enumerate(data, start=1):
        if not isinstance(item, dict):
            continue
        path_base = output_dir / f"{stamp}-{slug}-{index:02d}"
        if item.get("b64_json"):
            output_path = decode_b64(item["b64_json"], path_base.with_suffix(".png"))
        elif item.get("url"):
            output_path = download_url(item["url"], path_base, args.timeout)
        else:
            raise RuntimeError(f"Image item had neither b64_json nor url: {item}")
        outputs.append(str(output_path))
        if item.get("revised_prompt"):
            revised_prompts.append(str(item["revised_prompt"]))
    metadata = {
        "endpoint": endpoint,
        "request": fields,
        "source_image": str(Path(args.image).resolve()),
        "outputs": outputs,
        "revised_prompts": revised_prompts,
        "created": response.get("created"),
        "response_keys": sorted(response.keys()),
    }
    metadata_path = output_dir / f"{stamp}-{slug}-metadata.json"
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"outputs": outputs, "metadata": str(metadata_path), "prompt": fields["prompt"], "size": fields.get("size")}


def edit_one(args: argparse.Namespace, endpoint: str, api_keys: list[str], output_dir: Path, image_path: Path, prompt: str) -> dict[str, Any]:
    fields = {
        "model": args.model,
        "prompt": prompt,
        "n": str(args.n),
        "size": args.size,
    }
    if args.response_format != "auto":
        fields["response_format"] = args.response_format
    last_error: RuntimeError | None = None
    for attempt in range(args.retries + 1):
        try:
            response = try_keys(
                "Image edit",
                api_keys,
                lambda api_key: request_edit(endpoint, api_key, fields, image_path, args.timeout),
            )
            return save_response(args, endpoint, fields, response, output_dir)
        except RuntimeError as exc:
            last_error = exc
            message = str(exc)
            if attempt >= args.retries or not is_recoverable_platform_error(message):
                raise
            wait = args.memory_overload_wait if "system_memory_overloaded" in message.lower() else args.batch_delay
            print(
                f"Recoverable platform error on attempt {attempt + 1}/{args.retries + 1}; waiting {wait:g}s before retry.",
                file=sys.stderr,
            )
            time.sleep(wait)
    raise last_error or RuntimeError("Image edit failed.")


def main() -> int:
    args = parse_args()
    api_keys = load_api_keys(args.api_key_env)
    if not api_keys:
        print(f"Missing API key: set {args.api_key_env}, NEWAPI_API_KEY, or NEW_API_KEY.", file=sys.stderr)
        return 2
    prompts = load_prompts(args)
    if not prompts:
        print("Missing --prompt or --prompts-file.", file=sys.stderr)
        return 2
    image_path = Path(args.image).expanduser().resolve()
    if not image_path.exists():
        print(f"Image not found: {image_path}", file=sys.stderr)
        return 2
    endpoint = f"{clean_base_url(args.base_url)}/v1/images/edits"
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    results: list[dict[str, Any]] = []
    for index, prompt in enumerate(prompts, start=1):
        if index > 1 and args.batch_delay > 0:
            print(f"Waiting {args.batch_delay:g}s before batch item {index}/{len(prompts)}.", file=sys.stderr)
            time.sleep(args.batch_delay)
        results.append(edit_one(args, endpoint, api_keys, output_dir, image_path, prompt))

    if len(results) == 1:
        print(json.dumps({"outputs": results[0]["outputs"], "metadata": results[0]["metadata"]}, ensure_ascii=False, indent=2))
    else:
        summary_path = output_dir / f"{time.strftime('%Y%m%d-%H%M%S')}-edit-batch-summary.json"
        summary_path.write_text(json.dumps({"results": results}, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps({"results": results, "summary": str(summary_path)}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
