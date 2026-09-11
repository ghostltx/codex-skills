#!/usr/bin/env python3
import argparse
import json
import mimetypes
import os
import sys
import uuid
import webbrowser
from http.client import RemoteDisconnected
from pathlib import Path
from urllib import error, request


BASE_URL = "https://www.runninghub.ai/openapi/v2"
T2I_URL = f"{BASE_URL}/rhart-image-g-2.5-official-token/sunburst/text-to-image"
EDIT_URLS = {
    "precision": f"{BASE_URL}/rhart-image-g-2.5-official-token/sunburst/edit",
    "fast": f"{BASE_URL}/rhart-image-g-2.5-official-token/flare/edit",
}
CREATE_TASK_URL = "https://www.runninghub.ai/call-api/bill-task"
UPLOAD_URL = f"{BASE_URL}/media/upload/binary"
HTTP_TIMEOUT_SECONDS = int(os.environ.get("RH100_HTTP_TIMEOUT_SECONDS", "60"))


def api_key():
    key = os.environ.get("RUNNINGHUB_API_KEY_US")
    if not key:
        raise RuntimeError("RUNNINGHUB_API_KEY_US is required.")
    return key


def read_json(req):
    try:
        with request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc
    except (error.URLError, RemoteDisconnected) as exc:
        raise RuntimeError(f"Request failed: {exc}") from exc
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Non-JSON response: {raw}") from exc


def json_post(url, payload):
    req = request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
        },
    )
    return read_json(req)


def upload_file(path):
    file_path = Path(path)
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")
    boundary = f"----rh100-{uuid.uuid4().hex}"
    mime = mimetypes.guess_type(str(file_path))[0] or "application/octet-stream"
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="file"; filename="{file_path.name}"\r\n'.encode("utf-8"),
            f"Content-Type: {mime}\r\n\r\n".encode(),
            file_path.read_bytes(),
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    req = request.Request(
        UPLOAD_URL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        },
    )
    result = read_json(req)
    if result.get("code") not in (0, "0", None):
        raise RuntimeError(f"Upload failed: {json.dumps(result, ensure_ascii=False)}")
    url = (result.get("data") or {}).get("download_url")
    if not url:
        raise RuntimeError(f"Upload response has no data.download_url: {result}")
    return url


def open_bill_task_page():
    opened = webbrowser.open(CREATE_TASK_URL, new=2)
    print(f"Opened: {CREATE_TASK_URL} (success={opened})", flush=True)


def main():
    parser = argparse.ArgumentParser(
        description="RH100 US submit client for GPT-Image-2.5 Sunburst text-to-image and Sunburst/Flare image editing"
    )
    prompt_group = parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt")
    prompt_group.add_argument("--prompt-file")
    parser.add_argument("--image", action="append", default=[], help="Local image; selects image-to-image")
    parser.add_argument("--image-url", action="append", default=[], help="Image URL; selects image-to-image")
    parser.add_argument(
        "--edit-mode",
        default="precision",
        choices=["precision", "fast"],
        help="Image editing mode: precision=Sunburst, fast=Flare",
    )
    parser.add_argument("--aspect-ratio", default="1:1")
    parser.add_argument("--resolution", default="2k", choices=["1k", "2k", "4k"])
    parser.add_argument("--background", default="auto", choices=["auto", "transparent", "opaque"])
    parser.add_argument("--quality", default="high", choices=["auto", "low", "medium", "high", "xhigh", "max"])
    parser.add_argument("--output-format", default="png", choices=["jpeg", "png", "webp"])
    parser.add_argument("--webhook-url", default="")
    parser.add_argument("--api-key", default="", help="One-off key; prefer environment variables")
    parser.add_argument("--print-json", action="store_true")
    parser.add_argument("--no-open", action="store_true", help="Do not open the bill-task page")
    args = parser.parse_args()

    if args.api_key:
        os.environ["RUNNINGHUB_API_KEY_US"] = args.api_key
    args.prompt = (
        args.prompt
        if args.prompt is not None
        else Path(args.prompt_file).read_text(encoding="utf-8").strip()
    )
    if not args.prompt:
        raise SystemExit("Prompt must not be empty.")

    image_urls = list(args.image_url)
    for image_path in args.image:
        print(f"Uploading: {image_path}", flush=True)
        image_urls.append(upload_file(image_path))
    if len(image_urls) > 16:
        raise SystemExit("imageUrls supports at most 16 images.")

    payload = {
        "prompt": args.prompt,
        "aspectRatio": args.aspect_ratio,
        "resolution": args.resolution,
        "background": args.background,
        "quality": args.quality,
        "outputFormat": args.output_format,
    }
    if image_urls:
        payload["imageUrls"] = image_urls
        endpoint = EDIT_URLS[args.edit_mode]
        mode = f"tushengtu_US_gpt_image_2_5_{args.edit_mode}"
    else:
        endpoint = T2I_URL
        mode = "wenshengtu_US_gpt_image_2_5_sunburst"
    if args.webhook_url:
        payload["webhookUrl"] = args.webhook_url

    submit = json_post(endpoint, payload)
    if args.print_json:
        print(json.dumps(submit, ensure_ascii=False, indent=2))
    task_id = submit.get("taskId")
    if not task_id:
        raise SystemExit(
            f"Submit failed: {submit.get('errorCode') or 'UNKNOWN'} "
            f"{submit.get('errorMessage') or 'no taskId'}"
        )
    print(f"Submitted mode={mode} taskId={task_id} status={submit.get('status')}", flush=True)
    print(f"First taskId: {task_id}", flush=True)
    if not args.no_open:
        open_bill_task_page()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, FileNotFoundError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)

