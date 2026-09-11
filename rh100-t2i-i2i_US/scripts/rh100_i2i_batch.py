#!/usr/bin/env python3
"""Concurrent RH100 US image-to-image submitter.

This runner uploads and submits only. It never queries task status or downloads results.
"""
import argparse
import concurrent.futures
import json
import os
import threading
import webbrowser
from datetime import datetime
from pathlib import Path

import rh100_i2i


BILL_TASK_URL = "https://www.runninghub.ai/call-api/bill-task"
SAVE_LOCK = threading.Lock()


def now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def load_jobs(path):
    if not path.exists():
        return {"createdAt": now(), "uploads": {}, "jobs": []}
    return json.loads(path.read_text(encoding="utf-8"))


def save_jobs(path, data):
    with SAVE_LOCK:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def upload_one(path):
    url, _ = rh100_i2i.upload_file(path)
    return str(path), url


def ensure_uploads(data, paths, concurrency):
    uploads = data.setdefault("uploads", {})
    missing = [Path(path) for path in paths if str(Path(path)) not in uploads]
    if not missing:
        return
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        for future in concurrent.futures.as_completed([pool.submit(upload_one, path) for path in missing]):
            path, url = future.result()
            uploads[path] = url


def build_jobs(data, args):
    if data.get("jobs"):
        return
    uploads = data["uploads"]
    references = [uploads[str(Path(path))] if Path(path).exists() else path for path in args.reference]
    for target in args.image:
        target_path = Path(target)
        target_url = uploads[str(target_path)] if target_path.exists() else target
        for variant in range(1, args.variants + 1):
            data["jobs"].append(
                {
                    "name": f"{target_path.stem}_v{variant}",
                    "imageUrls": [target_url] + references,
                    "variant": variant,
                    "status": "PENDING",
                }
            )


def submit_one(job, args):
    result = rh100_i2i.submit_task(
        image_urls=job["imageUrls"],
        prompt=args.prompt,
        aspect_ratio=args.aspect_ratio,
        resolution=args.resolution,
        background=args.background,
        quality=args.quality,
        output_format=args.output_format,
        edit_mode=args.edit_mode,
        webhook_url=args.webhook_url or None,
    )
    task_id = result.get("taskId")
    job["taskId"] = task_id
    job["status"] = result.get("status") or ("SUBMIT_FAILED" if not task_id else "SUBMITTED")
    if not task_id:
        job["error"] = result
    job["submittedAt"] = now()
    return job


def submit_pending(data, args):
    pending = [job for job in data["jobs"] if job.get("status") == "PENDING"]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        futures = [pool.submit(submit_one, job, args) for job in pending]
        for future in concurrent.futures.as_completed(futures):
            updated = future.result()
            for index, job in enumerate(data["jobs"]):
                if job["name"] == updated["name"]:
                    data["jobs"][index] = updated
                    break


def print_status(data):
    counts = {}
    for job in data.get("jobs", []):
        status = job.get("status", "UNKNOWN")
        counts[status] = counts.get(status, 0) + 1
    summary = " ".join(f"{key}={value}" for key, value in sorted(counts.items())) or "no jobs"
    print(summary)


def main():
    parser = argparse.ArgumentParser(description="RH100 concurrent image-to-image submitter")
    parser.add_argument("command", choices=["submit", "status"])
    parser.add_argument("--image", action="append", default=[])
    parser.add_argument("--reference", action="append", default=[])
    parser.add_argument("--edit-mode", default="precision", choices=["precision", "fast"])
    parser.add_argument("--prompt", default="")
    parser.add_argument("--prompt-file", default="")
    parser.add_argument("--job-file", default="")
    parser.add_argument("--variants", type=int, default=1)
    parser.add_argument("--concurrency", type=int, default=14)
    parser.add_argument("--aspect-ratio", default="1:1")
    parser.add_argument("--resolution", default="2k", choices=["1k", "2k", "4k"])
    parser.add_argument("--background", default="auto", choices=["auto", "transparent", "opaque"])
    parser.add_argument("--quality", default="high", choices=["auto", "low", "medium", "high", "xhigh", "max"])
    parser.add_argument("--output-format", default="png", choices=["jpeg", "png", "webp"])
    parser.add_argument("--webhook-url", default="")
    parser.add_argument("--api-key", default="")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()
    if args.api_key:
        os.environ["RUNNINGHUB_API_KEY_US"] = args.api_key
    if args.prompt_file:
        args.prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()
    job_file = Path(args.job_file) if args.job_file else Path.cwd() / "rh100_jobs.json"
    data = load_jobs(job_file)

    if args.command == "status":
        print_status(data)
        return
    if not args.image:
        raise SystemExit("--image is required for submit")
    if not args.prompt:
        raise SystemExit("--prompt or --prompt-file is required for submit")
    if len(args.reference) > 15:
        raise SystemExit("A batch edit supports one target plus at most 15 reference images.")

    local_paths = [path for path in args.image + args.reference if Path(path).exists()]
    ensure_uploads(data, local_paths, args.concurrency)
    build_jobs(data, args)
    submit_pending(data, args)
    save_jobs(job_file, data)
    print_status(data)
    print(f"Job file: {job_file}")
    task_ids = [job.get("taskId") for job in data.get("jobs", []) if job.get("taskId")]
    if task_ids:
        print(f"First taskId: {task_ids[0]}")
    if not args.no_open:
        opened = webbrowser.open(BILL_TASK_URL, new=2)
        print(f"Opened: {BILL_TASK_URL} (success={opened})")


if __name__ == "__main__":
    main()
