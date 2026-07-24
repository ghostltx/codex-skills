#!/usr/bin/env python3
"""Submit multiple G-2 text-to-image variants without polling or downloading."""
import argparse
import concurrent.futures
import json
import os
import webbrowser
from datetime import datetime
from pathlib import Path

import rh100_image_gen


BILL_TASK_URL = "https://www.runninghub.cn/call-api/bill-task"


def now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def submit_one(index, args):
    payload = {
        "prompt": args.prompt,
        "aspectRatio": args.aspect_ratio,
        "resolution": args.resolution,
    }
    if args.instance_type != "none":
        payload["instanceType"] = args.instance_type
    if args.webhook_url:
        payload["webhookUrl"] = args.webhook_url
    result = rh100_image_gen.json_post(rh100_image_gen.T2I_URL, payload)
    task_id = result.get("taskId")
    return {
        "name": f"variant-{index}",
        "variant": index,
        "taskId": task_id,
        "status": result.get("status") or ("SUBMITTED" if task_id else "SUBMIT_FAILED"),
        "submittedAt": now(),
        "response": result if not task_id else None,
    }


def main():
    parser = argparse.ArgumentParser(description="RunningHub G-2 text-to-image variant submitter")
    parser.add_argument("--prompt", default="")
    parser.add_argument("--prompt-file", default="")
    parser.add_argument("--variants", type=int, default=1)
    parser.add_argument("--concurrency", type=int, default=4)
    parser.add_argument("--aspect-ratio", default="16:9")
    parser.add_argument("--resolution", default="1k", choices=["1k", "2k", "4k"])
    parser.add_argument("--instance-type", default="default", choices=["default", "plus", "none"])
    parser.add_argument("--webhook-url", default="")
    parser.add_argument("--job-file", default="rh100_jobs.json")
    parser.add_argument("--api-key", default="")
    parser.add_argument("--open", action="store_true", help="Open the bill-task page (opt-in)")
    parser.add_argument("--no-open", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.api_key:
        os.environ["RUNNINGHUB_API_KEY"] = args.api_key
    if args.prompt_file:
        args.prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()
    if not args.prompt:
        raise SystemExit("--prompt or --prompt-file is required")
    if args.variants < 1:
        raise SystemExit("--variants must be at least 1")

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.concurrency)) as pool:
        futures = [pool.submit(submit_one, index, args) for index in range(1, args.variants + 1)]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"Submitted {result['name']} taskId={result['taskId']} status={result['status']}", flush=True)

    results.sort(key=lambda item: item["variant"])
    job_file = Path(args.job_file)
    job_file.parent.mkdir(parents=True, exist_ok=True)
    job_file.write_text(
        json.dumps({"createdAt": now(), "mode": "wenshengtu", "jobs": results}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    task_ids = [item["taskId"] for item in results if item.get("taskId")]
    if not task_ids:
        raise SystemExit("No task was submitted successfully.")
    print(f"First taskId: {task_ids[0]}", flush=True)
    print(f"Job file: {job_file}", flush=True)
    print(f"Task page: {BILL_TASK_URL}", flush=True)
    if args.open:
        webbrowser.open(BILL_TASK_URL, new=2)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, FileNotFoundError) as exc:
        print(str(exc), flush=True)
        raise SystemExit(1)
