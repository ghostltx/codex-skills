#!/usr/bin/env python3
import argparse
from http.client import RemoteDisconnected
import json
import os
import sys
import time
from pathlib import Path
from urllib import error, request


BASE_URL = "https://www.runninghub.cn/openapi/v2"
SUBMIT_URL = f"{BASE_URL}/rhart-image-n-g31-flash/text-to-image"
QUERY_URL = f"{BASE_URL}/query"
HTTP_TIMEOUT_SECONDS = int(os.environ.get("RH100_T2I_HTTP_TIMEOUT_SECONDS", "60"))
DOWNLOAD_TIMEOUT_SECONDS = int(os.environ.get("RH100_T2I_DOWNLOAD_TIMEOUT_SECONDS", "120"))


def api_key():
    key = os.environ.get("RH100_T2I_API_KEY") or os.environ.get("RUNNINGHUB_API_KEY")
    if not key:
        raise RuntimeError("RH100_T2I_API_KEY or RUNNINGHUB_API_KEY is required.")
    return key


def read_text_file(path):
    return Path(path).read_text(encoding="utf-8").strip()


def read_json(req):
    try:
        with request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"Request failed: {exc}") from exc
    except RemoteDisconnected as exc:
        raise RuntimeError("Request failed: remote end closed connection without response") from exc

    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Non-JSON response: {raw}") from exc


def json_post(url, payload):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
        },
    )
    return read_json(req)


def submit_task(prompt, aspect_ratio, resolution, instance_type=None, webhook_url=None):
    payload = {
        "prompt": prompt,
        "aspectRatio": aspect_ratio,
        "resolution": resolution,
    }
    if instance_type:
        payload["instanceType"] = instance_type
    if webhook_url:
        payload["webhookUrl"] = webhook_url
    return json_post(SUBMIT_URL, payload)


def query_task(task_id):
    return json_post(QUERY_URL, {"taskId": task_id})


def download(url, out_path):
    req = request.Request(url, method="GET")
    try:
        with request.urlopen(req, timeout=DOWNLOAD_TIMEOUT_SECONDS) as resp:
            content = resp.read()
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Download HTTP {exc.code}: {body}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"Download failed: {exc}") from exc

    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_bytes(content)


def result_filename(result, index):
    ext = result.get("outputType") or "bin"
    node_id = result.get("nodeId") or index
    return f"rh100_t2i_{int(time.time())}_node{node_id}_{index}.{ext}"


def main():
    parser = argparse.ArgumentParser(description="RH100-T2I RunningHub text-to-image client")
    prompt_group = parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt", help="Prompt text")
    prompt_group.add_argument("--prompt-file", help="UTF-8 file containing prompt text")
    parser.add_argument("--aspect-ratio", default="1:1")
    parser.add_argument("--resolution", default="2k", choices=["1k", "2k", "4k"])
    parser.add_argument(
        "--instance-type",
        default="default",
        choices=["default", "plus", "none"],
        help="Enterprise shared instance type; use none for Lite auto-scheduling",
    )
    parser.add_argument("--webhook-url", default="")
    parser.add_argument("--out-dir", default="outputs")
    parser.add_argument("--poll-seconds", type=int, default=10)
    parser.add_argument("--max-wait-seconds", type=int, default=60)
    parser.add_argument("--api-key", default="", help="Use this key for this run instead of environment variables")
    parser.add_argument("--wait", action="store_true", help="Poll briefly after submitting")
    parser.add_argument("--no-wait", action="store_true", help="Submit only; do not poll")
    parser.add_argument("--print-json", action="store_true", help="Print full JSON responses")
    args = parser.parse_args()

    if args.api_key:
        os.environ["RH100_T2I_API_KEY"] = args.api_key

    prompt = args.prompt if args.prompt is not None else read_text_file(args.prompt_file)
    if not prompt:
        raise SystemExit("Prompt must not be empty.")

    instance_type = None if args.instance_type == "none" else args.instance_type
    submit = submit_task(
        prompt=prompt,
        aspect_ratio=args.aspect_ratio,
        resolution=args.resolution,
        instance_type=instance_type,
        webhook_url=args.webhook_url,
    )
    if args.print_json:
        print(json.dumps(submit, ensure_ascii=False, indent=2))

    task_id = submit.get("taskId")
    status = submit.get("status")
    print(f"Submitted taskId={task_id} status={status}", flush=True)

    if not task_id:
        error_code = submit.get("errorCode") or "UNKNOWN"
        error_message = submit.get("errorMessage") or "Submit response has no taskId."
        raise SystemExit(f"Submit failed: {error_code} {error_message}")

    if args.no_wait or not args.wait:
        return

    start = time.time()
    while True:
        if time.time() - start > args.max_wait_seconds:
            raise SystemExit(f"Timeout waiting for taskId={task_id}")

        time.sleep(args.poll_seconds)
        result = query_task(task_id)
        status = result.get("status")
        elapsed = int(time.time() - start)
        print(f"[{elapsed}s] status={status}", flush=True)

        if args.print_json:
            print(json.dumps(result, ensure_ascii=False, indent=2))

        if status == "SUCCESS":
            outputs = result.get("results") or []
            if not outputs:
                raise SystemExit("Task succeeded but results is empty.")

            for index, item in enumerate(outputs, start=1):
                url = item.get("url")
                text = item.get("text")
                if text:
                    print(text)
                if url:
                    out_path = Path(args.out_dir) / result_filename(item, index)
                    download(url, out_path)
                    print(f"Downloaded: {out_path}", flush=True)
            return

        if status == "FAILED":
            print(json.dumps(result, ensure_ascii=False, indent=2), file=sys.stderr)
            raise SystemExit(
                f"Task failed: {result.get('errorCode')} {result.get('errorMessage')}"
            )


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
