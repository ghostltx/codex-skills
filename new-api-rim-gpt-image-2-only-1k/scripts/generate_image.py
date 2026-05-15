#!/usr/bin/env python3
"""Generate images through NewAPI's OpenAI-compatible image endpoint."""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_BASE_URL = "http://64.186.244.43:12001"
DEFAULT_MODEL = "「Rim」gpt-image-2"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate images with NewAPI.")
    parser.add_argument("--prompt", help="Image prompt.")
    parser.add_argument("--prompts-file", help="UTF-8 text file with one prompt per line for serial batch generation.")
    parser.add_argument("--output-dir", default=".", help="Directory for output files.")
    parser.add_argument("--model", default=os.getenv("NEWAPI_IMAGE_MODEL", DEFAULT_MODEL))
    parser.add_argument("--base-url", default=os.getenv("NEWAPI_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--api-key-env", default="NEWAPI_API_KEYS")
    parser.add_argument("--list-models", action="store_true", help="List models from /v1/models and exit.")
    parser.add_argument("--size", default=os.getenv("NEWAPI_IMAGE_SIZE", "1254x1254"))
    parser.add_argument("--n", type=int, default=1)
    parser.add_argument("--response-format", default="b64_json", choices=["auto", "b64_json", "url"])
    parser.add_argument("--quality", default=None)
    parser.add_argument("--style", default=None)
    parser.add_argument("--background", default=None)
    parser.add_argument("--moderation", default=None)
    parser.add_argument("--output-format", default=None)
    parser.add_argument("--user", default=None)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--batch-delay", type=float, default=60.0, help="Seconds to wait between prompts in batch mode.")
    parser.add_argument("--retries", type=int, default=2, help="Retries per prompt for recoverable platform errors.")
    parser.add_argument(
        "--memory-overload-wait",
        type=float,
        default=180.0,
        help="Seconds to pause after system_memory_overloaded before retrying.",
    )
    return parser.parse_args()


def clean_base_url(base_url: str) -> str:
    base_url = base_url.strip().rstrip("/")
    if base_url.endswith("/v1"):
        base_url = base_url[:-3].rstrip("/")
    return base_url


def safe_slug(text: str, max_len: int = 48) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return (slug or "image")[:max_len].strip("-") or "image"


def split_api_keys(value: str | None) -> list[str]:
    if not value:
        return []
    return [key.strip() for key in value.split(",") if key.strip()]


def load_api_keys(env_name: str) -> list[str]:
    keys = split_api_keys(os.getenv(env_name))
    if keys:
        return keys
    for fallback in ("NEWAPI_API_KEY", "NEW_API_KEY"):
        keys = split_api_keys(os.getenv(fallback))
        if keys:
            return keys
    return []


def request_json(url: str, api_key: str, payload: dict[str, Any], timeout: int) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
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


def get_json(url: str, api_key: str, timeout: int) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "Authorization": f"Bearer {api_key}",
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


def guess_extension(content_type: str | None, fallback: str = ".png") -> str:
    if not content_type:
        return fallback
    content_type = content_type.split(";", 1)[0].strip()
    return mimetypes.guess_extension(content_type) or fallback


def download_url(url: str, path_without_suffix: Path, timeout: int) -> Path:
    request = urllib.request.Request(url, headers={"User-Agent": "codex-newapi-imagegen/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        extension = guess_extension(response.headers.get("Content-Type"))
        output_path = path_without_suffix.with_suffix(extension)
        output_path.write_bytes(response.read())
        return output_path


def decode_b64(data: str, output_path: Path) -> Path:
    if "," in data and data.lstrip().startswith("data:"):
        data = data.split(",", 1)[1]
    output_path.write_bytes(base64.b64decode(data))
    return output_path


def build_payload(args: argparse.Namespace) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "model": args.model,
        "prompt": args.prompt,
        "n": args.n,
        "size": args.size,
    }
    if args.response_format != "auto":
        payload["response_format"] = args.response_format
    for key in ("quality", "style", "background", "moderation", "user"):
        value = getattr(args, key)
        if value:
            payload[key] = value
    if args.output_format:
        payload["output_format"] = args.output_format
    return payload


def load_prompts(args: argparse.Namespace) -> list[str]:
    prompts: list[str] = []
    if args.prompts_file:
        path = Path(args.prompts_file).expanduser()
        prompts.extend(line.strip() for line in path.read_text(encoding="utf-8-sig").splitlines() if line.strip())
    if args.prompt:
        prompts.append(args.prompt)
    return prompts


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


def save_response(args: argparse.Namespace, endpoint: str, payload: dict[str, Any], response: dict[str, Any], output_dir: Path) -> dict[str, Any]:
    data = response.get("data")
    if not isinstance(data, list) or not data:
        raise RuntimeError(f"NewAPI response did not contain image data: {json.dumps(response)[:1000]}")

    stamp = time.strftime("%Y%m%d-%H%M%S")
    slug = safe_slug(payload["prompt"])
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
        "request": payload,
        "outputs": outputs,
        "revised_prompts": revised_prompts,
        "created": response.get("created"),
        "response_keys": sorted(response.keys()),
    }
    metadata_path = output_dir / f"{stamp}-{slug}-metadata.json"
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"outputs": outputs, "metadata": str(metadata_path)}


def generate_one(args: argparse.Namespace, endpoint: str, api_keys: list[str], output_dir: Path, prompt: str) -> dict[str, Any]:
    args.prompt = prompt
    payload = build_payload(args)
    last_error: RuntimeError | None = None
    for attempt in range(args.retries + 1):
        try:
            response = try_keys(
                "Image generation",
                api_keys,
                lambda api_key: request_json(endpoint, api_key, payload, args.timeout),
            )
            result = save_response(args, endpoint, payload, response, output_dir)
            result["prompt"] = prompt
            result["size"] = args.size
            return result
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
    raise last_error or RuntimeError("Image generation failed.")


def main() -> int:
    args = parse_args()
    api_keys = load_api_keys(args.api_key_env)
    if not api_keys:
        print(
            f"Missing API key: set environment variable {args.api_key_env}, NEWAPI_API_KEY, or NEW_API_KEY.",
            file=sys.stderr,
        )
        return 2

    base_url = clean_base_url(args.base_url)
    if args.list_models:
        response = try_keys(
            "Model listing",
            api_keys,
            lambda api_key: get_json(f"{base_url}/v1/models", api_key, args.timeout),
        )
        print(json.dumps(response, ensure_ascii=False, indent=2))
        return 0

    prompts = load_prompts(args)
    if not prompts:
        print("Missing --prompt or --prompts-file for image generation.", file=sys.stderr)
        return 2

    endpoint = f"{base_url}/v1/images/generations"
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    results: list[dict[str, Any]] = []
    for index, prompt in enumerate(prompts, start=1):
        if index > 1 and args.batch_delay > 0:
            print(f"Waiting {args.batch_delay:g}s before batch item {index}/{len(prompts)}.", file=sys.stderr)
            time.sleep(args.batch_delay)
        results.append(generate_one(args, endpoint, api_keys, output_dir, prompt))

    if len(results) == 1:
        print(json.dumps({"outputs": results[0]["outputs"], "metadata": results[0]["metadata"]}, ensure_ascii=False, indent=2))
    else:
        summary_path = output_dir / f"{time.strftime('%Y%m%d-%H%M%S')}-batch-summary.json"
        summary_path.write_text(json.dumps({"results": results}, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps({"results": results, "summary": str(summary_path)}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
