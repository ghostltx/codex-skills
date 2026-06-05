#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

BASE_URL = "https://www.runninghub.cn/openapi/v2"
ACCOUNT_STATUS_URL = "https://www.runninghub.cn/uc/openapi/accountStatus"
UPLOAD_ENDPOINT = "/media/upload/binary"
POLL_ENDPOINT = "/query"
MAX_POLL_SECONDS = 1200
POLL_INTERVAL_SECONDS = 5

SCRIPT_DIR = Path(__file__).resolve().parent
REFERENCE_DIR = SCRIPT_DIR.parent / "references"
ENDPOINTS_PATH = REFERENCE_DIR / "endpoints.json"


def load_endpoints() -> dict:
    if not ENDPOINTS_PATH.exists():
        return {"endpoints": []}
    with ENDPOINTS_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def find_endpoint(endpoint: str) -> dict | None:
    for item in load_endpoints().get("endpoints", []):
        if item.get("endpoint") == endpoint:
            return item
    return None


def resolve_api_key(provided: str | None) -> str | None:
    if provided and provided.strip() and provided.strip() not in {"RUNNINGHUB_API_KEY", "<api-key>", "your_api_key_here"}:
        return provided.strip()
    env_key = os.environ.get("RUNNINGHUB_API_KEY", "").strip()
    if env_key:
        return env_key
    return None


def require_api_key(provided: str | None) -> str:
    key = resolve_api_key(provided)
    if key:
        return key
    print(json.dumps({
        "error": "NO_API_KEY",
        "message": "Missing RunningHub API key. Set RUNNINGHUB_API_KEY or pass --api-key at runtime. Do not store the key in the skill.",
    }, ensure_ascii=False))
    sys.exit(1)


def curl_post_json(url: str, payload: dict, headers: dict, timeout: int = 60) -> subprocess.CompletedProcess:
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False)
        payload_path = handle.name
    try:
        command = ["curl", "-s", "-S", "--fail-with-body", "-X", "POST", url, "--max-time", str(timeout), "-d", f"@{payload_path}"]
        for key, value in headers.items():
            command += ["-H", f"{key}: {value}"]
        return subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    finally:
        try:
            os.unlink(payload_path)
        except OSError:
            pass


def api_post(api_key: str, url: str, payload: dict, timeout: int = 60) -> dict:
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}
    result = curl_post_json(url, payload, headers, timeout)
    if result.returncode != 0:
        raw = result.stdout or result.stderr
        try:
            error = json.loads(raw)
            code = str(error.get("code", ""))
            message = str(error.get("msg", raw))
        except (json.JSONDecodeError, TypeError):
            code = ""
            message = str(raw)
        combined = f"{code} {message}".lower()
        if any(token in combined for token in ("auth", "401", "403", "token", "key")):
            kind = "AUTH_FAILED"
        elif any(token in combined for token in ("balance", "insufficient", "余额", "credit")):
            kind = "INSUFFICIENT_BALANCE"
        else:
            kind = "API_ERROR"
        print(json.dumps({"error": kind, "message": message[:1000]}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        print(json.dumps({"error": "API_ERROR", "message": result.stdout[:1000]}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)


def check_account(args) -> None:
    key = require_api_key(args.api_key)
    response = api_post(key, ACCOUNT_STATUS_URL, {"apikey": key}, timeout=15)
    if response.get("code") != 0:
        print(json.dumps({"status": "invalid_key", "message": response.get("msg", "API key verification failed")}, ensure_ascii=False))
        return
    data = response.get("data", {})
    print(json.dumps({
        "status": "ready",
        "balance": data.get("remainMoney"),
        "currency": data.get("currency", "CNY"),
        "coins": data.get("remainCoins"),
        "running_tasks": data.get("currentTaskCounts"),
        "api_type": data.get("apiType"),
    }, ensure_ascii=False))


def list_endpoints(args) -> None:
    endpoints = load_endpoints().get("endpoints", [])
    if args.task:
        endpoints = [item for item in endpoints if item.get("task") == args.task]
    if args.type:
        endpoints = [item for item in endpoints if item.get("output_type") == args.type]
    print(json.dumps({"count": len(endpoints), "endpoints": endpoints}, ensure_ascii=False, indent=2))


def show_info(args) -> None:
    endpoint = find_endpoint(args.info)
    if not endpoint:
        print(json.dumps({"endpoint": args.info, "known": False, "message": "No bundled schema. The runner can still submit with generic prompt/image/param mapping."}, ensure_ascii=False, indent=2))
        return
    print(json.dumps(endpoint, ensure_ascii=False, indent=2))


def image_to_data_uri(path: str) -> str:
    mime_type = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as handle:
        return f"data:{mime_type};base64,{base64.b64encode(handle.read()).decode('ascii')}"


def upload_file(api_key: str, path: str) -> str:
    url = f"{BASE_URL}{UPLOAD_ENDPOINT}"
    command = ["curl", "-s", "-S", "--fail-with-body", "-X", "POST", url, "-H", f"Authorization: Bearer {api_key}", "-F", f"file=@{path}", "--max-time", "120"]
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        print(json.dumps({"error": "UPLOAD_FAILED", "message": (result.stdout or result.stderr)[:1000]}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    response = json.loads(result.stdout)
    if response.get("code") == 0 and response.get("data", {}).get("download_url"):
        return response["data"]["download_url"]
    print(json.dumps({"error": "UPLOAD_FAILED", "message": response}, ensure_ascii=False), file=sys.stderr)
    sys.exit(1)


def resolve_media(api_key: str, media_path: str, force_upload: bool) -> str:
    if media_path.startswith(("http://", "https://", "data:")):
        return media_path
    path = Path(media_path)
    if not path.exists():
        print(json.dumps({"error": "FILE_NOT_FOUND", "message": str(path)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    if force_upload or path.stat().st_size > 5 * 1024 * 1024:
        return upload_file(api_key, str(path))
    return image_to_data_uri(str(path))


def coerce_value(value: str):
    lowered = value.lower()
    if lowered in ("true", "false"):
        return lowered == "true"
    try:
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        return value


def parse_params(raw_params: list[str] | None) -> dict:
    parsed = {}
    for item in raw_params or []:
        if "=" not in item:
            print(json.dumps({"error": "BAD_PARAM", "message": f"Expected key=value, got {item}"}, ensure_ascii=False), file=sys.stderr)
            sys.exit(1)
        key, value = item.split("=", 1)
        parsed[key] = coerce_value(value)
    return parsed


def build_payload(endpoint_def: dict | None, args, api_key: str) -> dict:
    payload = parse_params(args.param)
    params = endpoint_def.get("params", []) if endpoint_def else []
    prompt_keys = [item.get("key") for item in params if item.get("key") in ("prompt", "text")]
    if args.prompt:
        payload[prompt_keys[0] if prompt_keys else "prompt"] = args.prompt

    image_paths = args.image or []
    if image_paths:
        image_params = [item for item in params if item.get("type") == "IMAGE"]
        if len(image_paths) > 1:
            multi = next((item for item in image_params if item.get("multiple")), None)
            if multi:
                payload[multi["key"]] = [resolve_media(api_key, path, True) for path in image_paths]
            elif len(image_params) >= len(image_paths):
                for path, param in zip(image_paths, image_params):
                    payload[param["key"]] = resolve_media(api_key, path, True)
            else:
                payload["imageUrls"] = [resolve_media(api_key, path, True) for path in image_paths]
        else:
            key = image_params[0]["key"] if image_params else "imageUrl"
            if image_params and image_params[0].get("multiple"):
                payload[key] = [resolve_media(api_key, image_paths[0], False)]
            else:
                payload[key] = resolve_media(api_key, image_paths[0], False)

    for item in params:
        key = item.get("key")
        if key and key not in payload and item.get("required") and "default" in item:
            payload[key] = item["default"]
    return payload


def poll_task(api_key: str, task_id: str) -> dict:
    print(f"TASK_ID:{task_id}")
    start = time.time()
    while time.time() - start < MAX_POLL_SECONDS:
        time.sleep(POLL_INTERVAL_SECONDS)
        response = api_post(api_key, f"{BASE_URL}{POLL_ENDPOINT}", {"taskId": task_id}, timeout=30)
        status = response.get("status")
        if status == "SUCCESS":
            return response
        if status == "FAILED":
            print(json.dumps({"error": "TASK_FAILED", "task_id": task_id, "message": response.get("errorMessage", "Unknown error")}, ensure_ascii=False), file=sys.stderr)
            sys.exit(1)
        print(".", end="", flush=True)
    print(json.dumps({"error": "TIMEOUT", "task_id": task_id, "message": f"Task exceeded {MAX_POLL_SECONDS}s"}, ensure_ascii=False), file=sys.stderr)
    sys.exit(1)


def download_file(url: str, output_path: str) -> str:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(["curl", "-s", "-S", "-L", "-o", str(output), "--max-time", "300", url], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        print(json.dumps({"error": "DOWNLOAD_FAILED", "message": (result.stdout or result.stderr)[:1000]}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    return str(output.resolve())


def execute(args) -> None:
    if not args.endpoint:
        print(json.dumps({"error": "NO_ENDPOINT", "message": "--endpoint is required for execution"}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    key = require_api_key(args.api_key)
    endpoint_def = find_endpoint(args.endpoint)
    payload = build_payload(endpoint_def, args, key)
    submit_url = f"{BASE_URL}/{args.endpoint}"
    started = time.time()
    response = api_post(key, submit_url, payload, timeout=60)
    task_id = response.get("taskId")
    if not task_id:
        print(json.dumps({"error": "API_ERROR", "message": "No taskId in submit response", "response": response}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    final = response if response.get("status") == "SUCCESS" and response.get("results") else poll_task(key, task_id)
    results = final.get("results") or []
    if not results:
        print(json.dumps({"error": "TASK_FAILED", "task_id": task_id, "message": "No results returned"}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)

    first = results[0]
    result_url = first.get("url") or first.get("outputUrl")
    text = first.get("text") or first.get("content") or first.get("output")
    if result_url:
        output_path = args.output or str(Path.cwd() / "runninghub-result")
        output_type = first.get("outputType")
        if output_type:
            output_path = str(Path(output_path).with_suffix(f".{output_type}"))
        print(f"OUTPUT_FILE:{download_file(result_url, output_path)}")
    elif text:
        print(text)
    else:
        print(json.dumps({"error": "TASK_FAILED", "task_id": task_id, "message": "Result has no URL or text"}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)

    usage = final.get("usage") or {}
    cost = usage.get("consumeMoney") or usage.get("thirdPartyConsumeMoney")
    duration = usage.get("taskCostTime")
    if cost is not None:
        print(f"COST:¥{cost}")
    if duration and str(duration) != "0":
        print(f"DURATION:{duration}s")
    print(f"ELAPSED:{time.time() - started:.1f}s")


def main() -> None:
    parser = argparse.ArgumentParser(description="RunningHub OpenAPI reusable runner")
    parser.add_argument("--check", action="store_true", help="Check key and account status")
    parser.add_argument("--list", action="store_true", help="List bundled endpoint schemas")
    parser.add_argument("--info", help="Show bundled schema for an endpoint")
    parser.add_argument("--endpoint", "-e", help="RunningHub endpoint path")
    parser.add_argument("--prompt", "-p", help="Prompt text")
    parser.add_argument("--image", "-i", action="append", help="Input image path or URL; repeatable")
    parser.add_argument("--param", action="append", help="Extra endpoint parameter as key=value; repeatable")
    parser.add_argument("--output", "-o", help="Output file path")
    parser.add_argument("--api-key", "-k", help="Runtime API key; prefer RUNNINGHUB_API_KEY")
    parser.add_argument("--type", help="Filter --list by output type")
    parser.add_argument("--task", help="Filter --list by task")
    args = parser.parse_args()

    if args.check:
        check_account(args)
    elif args.list:
        list_endpoints(args)
    elif args.info:
        show_info(args)
    else:
        execute(args)


if __name__ == "__main__":
    main()
