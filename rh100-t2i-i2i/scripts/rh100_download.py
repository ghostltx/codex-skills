#!/usr/bin/env python3
"""Poll submitted RH100 tasks and download every image result."""

import argparse
import json
import os
import re
import sys
import time
from http.client import RemoteDisconnected
from pathlib import Path
from urllib import error, parse, request


QUERY_URL = "https://www.runninghub.cn/openapi/v2/query"
HTTP_TIMEOUT_SECONDS = int(os.environ.get("RH100_HTTP_TIMEOUT_SECONDS", "60"))
DOWNLOAD_TIMEOUT_SECONDS = int(os.environ.get("RH100_DOWNLOAD_TIMEOUT_SECONDS", "120"))
TERMINAL_FAILURES = {"FAILED", "FAILURE", "CANCELLED", "CANCELED"}


def api_key():
    key = os.environ.get("RUNNINGHUB_API_KEY")
    if not key:
        raise RuntimeError("RUNNINGHUB_API_KEY is required.")
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


def query_task(task_id):
    req = request.Request(
        QUERY_URL,
        data=json.dumps({"taskId": task_id}).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
        },
    )
    return read_json(req)


def download_url(url, out_path):
    req = request.Request(url, method="GET")
    try:
        with request.urlopen(req, timeout=DOWNLOAD_TIMEOUT_SECONDS) as resp:
            content = resp.read()
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Download HTTP {exc.code}: {body}") from exc
    except (error.URLError, RemoteDisconnected) as exc:
        raise RuntimeError(f"Download failed: {exc}") from exc
    out_path.write_bytes(content)


def safe_name(value):
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", str(value)).strip("._")
    return cleaned or "task"


def result_extension(item):
    output_type = str(item.get("outputType") or "").lower().lstrip(".")
    if re.fullmatch(r"[a-z0-9]{1,8}", output_type):
        return output_type
    suffix = Path(parse.urlparse(item.get("url") or "").path).suffix.lower().lstrip(".")
    if re.fullmatch(r"[a-z0-9]{1,8}", suffix):
        return suffix
    return "bin"


def task_ids_from_job_file(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    return [str(job["taskId"]) for job in data.get("jobs", []) if job.get("taskId")]


def collect_task_ids(explicit_ids, job_file):
    values = list(explicit_ids)
    if job_file:
        values.extend(task_ids_from_job_file(job_file))
    unique = []
    seen = set()
    for task_id in values:
        task_id = str(task_id).strip()
        if task_id and task_id not in seen:
            seen.add(task_id)
            unique.append(task_id)
    return unique


def download_results(task_id, task_index, result, out_dir):
    outputs = result.get("results") or []
    urls = [item for item in outputs if item.get("url")]
    if not urls:
        raise RuntimeError(f"Task {task_id} succeeded but has no downloadable results.")
    downloaded = []
    for result_index, item in enumerate(urls, start=1):
        filename = (
            f"{task_index:03d}_{safe_name(task_id)}_"
            f"{result_index:02d}.{result_extension(item)}"
        )
        out_path = out_dir / filename
        download_url(item["url"], out_path)
        downloaded.append(str(out_path))
        print(f"Downloaded: {out_path}", flush=True)
    return downloaded


def poll_and_download(task_ids, out_dir, poll_seconds, max_wait_seconds):
    pending = list(task_ids)
    failures = {}
    downloaded = []
    started = time.monotonic()
    indexes = {task_id: index for index, task_id in enumerate(task_ids, start=1)}

    while pending:
        for task_id in list(pending):
            try:
                result = query_task(task_id)
                status = str(result.get("status") or "UNKNOWN").upper()
                print(f"taskId={task_id} status={status}", flush=True)
                if status == "SUCCESS":
                    downloaded.extend(
                        download_results(task_id, indexes[task_id], result, out_dir)
                    )
                    pending.remove(task_id)
                elif status in TERMINAL_FAILURES:
                    failures[task_id] = (
                        result.get("errorMessage") or result.get("errorCode") or status
                    )
                    pending.remove(task_id)
            except RuntimeError as exc:
                print(f"taskId={task_id} retryable-error={exc}", file=sys.stderr, flush=True)

        if not pending:
            break
        elapsed = time.monotonic() - started
        if max_wait_seconds > 0 and elapsed >= max_wait_seconds:
            for task_id in pending:
                failures[task_id] = f"Timed out after {max_wait_seconds}s"
            break
        time.sleep(poll_seconds)

    return downloaded, failures


def main():
    parser = argparse.ArgumentParser(
        description="Poll RH100 tasks and download all image results"
    )
    parser.add_argument("--task-id", action="append", default=[])
    parser.add_argument("--job-file", default="")
    parser.add_argument(
        "--output-root",
        default=str(Path.home() / "Desktop"),
        help="Parent directory; the first taskId is used as the child folder name",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Exact output directory; overrides --output-root/<first-taskId>",
    )
    parser.add_argument("--poll-seconds", type=int, default=10)
    parser.add_argument("--max-wait-seconds", type=int, default=1800)
    parser.add_argument("--api-key", default="")
    args = parser.parse_args()

    if args.api_key:
        os.environ["RUNNINGHUB_API_KEY"] = args.api_key
    if args.poll_seconds < 1:
        raise SystemExit("--poll-seconds must be at least 1.")

    task_ids = collect_task_ids(args.task_id, args.job_file)
    if not task_ids:
        raise SystemExit("Provide at least one --task-id or a --job-file containing task IDs.")

    out_dir = (
        Path(args.output_dir).expanduser()
        if args.output_dir
        else Path(args.output_root).expanduser() / safe_name(task_ids[0])
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output folder: {out_dir}", flush=True)
    downloaded, failures = poll_and_download(
        task_ids, out_dir, args.poll_seconds, args.max_wait_seconds
    )
    print(
        f"Complete: tasks={len(task_ids)} downloaded={len(downloaded)} "
        f"failed={len(failures)}",
        flush=True,
    )
    if failures:
        print(json.dumps(failures, ensure_ascii=False, indent=2), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, FileNotFoundError, json.JSONDecodeError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)

