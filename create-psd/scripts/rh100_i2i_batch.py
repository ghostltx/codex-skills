#!/usr/bin/env python3
import argparse
import concurrent.futures
import json
import os
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import rh100_i2i  # noqa: E402


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
        tmp = path.with_name(f"{path.name}.{os.getpid()}.{threading.get_ident()}.tmp")
        content = json.dumps(data, ensure_ascii=False, indent=2)
        last_error = None
        for attempt in range(10):
            try:
                tmp.write_text(content, encoding="utf-8")
                tmp.replace(path)
                return
            except PermissionError as exc:
                last_error = exc
                time.sleep(0.2 * (attempt + 1))
        try:
            path.write_text(content, encoding="utf-8")
            if tmp.exists():
                tmp.unlink()
        except PermissionError as exc:
            raise last_error or exc


def log_line(log_path, message):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(f"[{now()}] {message}\n")


def upload_path(path):
    url, _ = rh100_i2i.upload_file(str(path))
    return str(path), url


def submit_job(job, args, log_path):
    submit = rh100_i2i.submit_task(
        image_urls=job["imageUrls"],
        prompt=args.prompt,
        aspect_ratio=args.aspect_ratio,
        resolution=args.resolution,
        instance_type=args.instance_type,
    )
    task_id = submit.get("taskId")
    if not task_id:
        job["status"] = "SUBMIT_FAILED"
        job["error"] = submit
        log_line(log_path, f"submit failed {job['name']}: {submit.get('errorCode')} {submit.get('errorMessage')}")
        return job
    job["taskId"] = task_id
    job["status"] = submit.get("status") or "RUNNING"
    job["submittedAt"] = now()
    log_line(log_path, f"submitted {job['name']} taskId={task_id}")
    return job


def poll_job(job, out_dir, log_path):
    task_id = job.get("taskId")
    if not task_id:
        return job

    result = rh100_i2i.query_task(task_id)
    status = result.get("status") or "UNKNOWN"
    job["status"] = status
    job["lastQueryAt"] = now()
    if result.get("usage") is not None:
        job["usage"] = result.get("usage")

    if status == "SUCCESS":
        outputs = result.get("results") or []
        saved = job.get("saved") or []
        if saved:
            return job
        for index, item in enumerate(outputs, start=1):
            url = item.get("url")
            if not url:
                continue
            ext = item.get("outputType") or "png"
            out_path = out_dir / f"{job['name']}_{index}.{ext}"
            rh100_i2i.download(url, out_path)
            saved.append(str(out_path))
        job["saved"] = saved
        job["finishedAt"] = now()
        log_line(log_path, f"downloaded {job['name']} files={len(saved)} usage={format_usage(job.get('usage'))}")
    elif status == "FAILED":
        job["error"] = result
        job["finishedAt"] = now()
        log_line(log_path, f"failed {job['name']}: {result.get('errorCode')} {result.get('errorMessage')}")

    return job


def ensure_uploads(data, paths, concurrency, job_file, log_path):
    uploads = data.setdefault("uploads", {})
    missing = [Path(p) for p in paths if str(Path(p)) not in uploads]
    if not missing:
        return

    log_line(log_path, f"uploading {len(missing)} files")
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = [pool.submit(upload_path, path) for path in missing]
        for future in concurrent.futures.as_completed(futures):
            path, url = future.result()
            uploads[path] = url
            save_jobs(job_file, data)
    log_line(log_path, f"uploaded {len(missing)} files")


def build_jobs(data, args):
    if data.get("jobs"):
        return

    uploads = data["uploads"]
    references = [uploads[str(Path(p))] if Path(p).exists() else p for p in args.reference]
    jobs = []
    for target in args.image:
        target_path = Path(target)
        target_url = uploads[str(target_path)] if target_path.exists() else target
        for variant in range(1, args.variants + 1):
            jobs.append(
                {
                    "name": f"{target_path.stem}_v{variant}",
                    "target": str(target_path),
                    "variant": variant,
                    "imageUrls": [target_url] + references,
                    "status": "PENDING",
                }
            )
    data["jobs"] = jobs


def submit_pending(data, args, job_file, log_path):
    pending = [job for job in data["jobs"] if job.get("status") == "PENDING"]
    if not pending:
        return
    log_line(log_path, f"submitting {len(pending)} jobs")
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        futures = [pool.submit(submit_job, job, args, log_path) for job in pending]
        for future in concurrent.futures.as_completed(futures):
            updated = future.result()
            for index, job in enumerate(data["jobs"]):
                if job["name"] == updated["name"]:
                    data["jobs"][index] = updated
                    break
            save_jobs(job_file, data)


def poll_loop(data, args, job_file, log_path):
    deadline = time.time() + args.max_poll_seconds
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    while True:
        active = [job for job in data["jobs"] if job.get("status") in ("QUEUED", "RUNNING", "UNKNOWN")]
        if not active:
            return
        if time.time() >= deadline:
            log_line(log_path, "poll window ended; rerun poll to continue")
            return

        with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as pool:
            futures = [pool.submit(poll_job, job, out_dir, log_path) for job in active]
            for future in concurrent.futures.as_completed(futures):
                updated = future.result()
                for index, job in enumerate(data["jobs"]):
                    if job["name"] == updated["name"]:
                        data["jobs"][index] = updated
                        break
                save_jobs(job_file, data)

        log_line(log_path, "summary " + build_status_line(data))
        remaining = deadline - time.time()
        if remaining <= 0:
            log_line(log_path, "poll window ended; rerun poll to continue")
            return
        time.sleep(min(args.poll_seconds, remaining))


def as_float(value):
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def format_seconds(seconds):
    if seconds is None:
        return "N/A"
    seconds = int(round(seconds))
    minutes, sec = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}h{minutes}m{sec}s"
    if minutes:
        return f"{minutes}m{sec}s"
    return f"{sec}s"


def collect_usage(data):
    total_seconds = 0.0
    has_seconds = False
    total_money = 0.0
    has_money = False
    total_coins = 0.0
    has_coins = False
    total_third_party_money = 0.0
    has_third_party_money = False
    submitted_times = []
    finished_times = []

    for job in data.get("jobs", []):
        usage = job.get("usage") or {}
        seconds = as_float(usage.get("taskCostTime"))
        if seconds is not None:
            total_seconds += seconds
            has_seconds = True
        money = as_float(usage.get("consumeMoney"))
        if money is not None:
            total_money += money
            has_money = True
        coins = as_float(usage.get("consumeCoins"))
        if coins is not None:
            total_coins += coins
            has_coins = True
        third_party_money = as_float(usage.get("thirdPartyConsumeMoney"))
        if third_party_money is not None:
            total_third_party_money += third_party_money
            has_third_party_money = True
        if job.get("submittedAt"):
            submitted_times.append(job["submittedAt"])
        if job.get("finishedAt"):
            finished_times.append(job["finishedAt"])

    wall_seconds = None
    if submitted_times and finished_times:
        try:
            started = datetime.strptime(min(submitted_times), "%Y-%m-%d %H:%M:%S")
            finished = datetime.strptime(max(finished_times), "%Y-%m-%d %H:%M:%S")
            wall_seconds = max(0.0, (finished - started).total_seconds())
        except ValueError:
            wall_seconds = None

    return {
        "seconds": total_seconds if has_seconds else None,
        "money": total_money if has_money else None,
        "coins": total_coins if has_coins else None,
        "third_party_money": total_third_party_money if has_third_party_money else None,
        "wall_seconds": wall_seconds,
    }


def format_usage(usage):
    usage = usage or {}
    seconds = as_float(usage.get("taskCostTime"))
    money = as_float(usage.get("consumeMoney"))
    coins = as_float(usage.get("consumeCoins"))
    third_party_money = as_float(usage.get("thirdPartyConsumeMoney"))
    parts = [f"time={format_seconds(seconds)}"]
    parts.append(f"money=CNY{money:.6f}" if money is not None else "money=N/A")
    parts.append(f"coins={coins:.6f}" if coins is not None else "coins=N/A")
    parts.append(
        f"third_party_money=CNY{third_party_money:.6f}"
        if third_party_money is not None
        else "third_party_money=N/A"
    )
    return " ".join(parts)


def build_status_line(data):
    counts = {}
    for job in data.get("jobs", []):
        counts[job.get("status", "UNKNOWN")] = counts.get(job.get("status", "UNKNOWN"), 0) + 1
    status = " ".join(f"{k}={v}" for k, v in sorted(counts.items())) or "no jobs"
    usage = collect_usage(data)
    money = usage["money"]
    coins = usage["coins"]
    third_party_money = usage["third_party_money"]
    money_text = f"CNY{money:.6f}" if money is not None else "N/A"
    coins_text = f"{coins:.6f}" if coins is not None else "N/A"
    third_party_money_text = (
        f"CNY{third_party_money:.6f}" if third_party_money is not None else "N/A"
    )
    return (
        f"{status} total_time={format_seconds(usage['seconds'])} "
        f"wall_time={format_seconds(usage['wall_seconds'])} "
        f"consume_money={money_text} consume_coins={coins_text} "
        f"third_party_money={third_party_money_text}"
    )


def print_status(data):
    print(build_status_line(data))


def read_prompt(args):
    if args.prompt_file:
        return Path(args.prompt_file).read_text(encoding="utf-8")
    return args.prompt


def main():
    parser = argparse.ArgumentParser(description="RH100 quiet resumable batch runner")
    parser.add_argument("command", choices=["submit", "poll", "status"])
    parser.add_argument("--image", action="append", default=[], help="Target local image path or public URL")
    parser.add_argument("--reference", action="append", default=[], help="Reference local image path or public URL")
    parser.add_argument("--prompt", default="", help="Prompt text")
    parser.add_argument("--prompt-file", default="", help="UTF-8 prompt text file")
    parser.add_argument("--job-file", default="", help="Defaults to .\\rh100_jobs.json")
    parser.add_argument("--out-dir", default="", help="Defaults to the --job-file directory")
    parser.add_argument("--log-file", default="", help="Defaults to <out-dir>\\rh100_run.log")
    parser.add_argument("--variants", type=int, default=1)
    parser.add_argument("--concurrency", type=int, default=14)
    parser.add_argument("--aspect-ratio", default="1:1")
    parser.add_argument("--resolution", default="2k", choices=["1k", "2k", "4k"])
    parser.add_argument("--instance-type", default="default", choices=["default", "plus"])
    parser.add_argument("--api-key", default="", help="Use this key for this run instead of RUNNINGHUB_API_KEY")
    parser.add_argument("--poll-seconds", type=int, default=15)
    parser.add_argument("--max-poll-seconds", type=int, default=60)
    args = parser.parse_args()

    if args.api_key:
        os.environ["RUNNINGHUB_API_KEY"] = args.api_key
    if not os.environ.get("RUNNINGHUB_API_KEY"):
        raise SystemExit("RUNNINGHUB_API_KEY is required. Set the environment variable or pass --api-key.")
    args.prompt = read_prompt(args)

    job_file = Path(args.job_file) if args.job_file else Path.cwd() / "rh100_jobs.json"
    out_dir = Path(args.out_dir) if args.out_dir else job_file.parent
    log_path = Path(args.log_file) if args.log_file else out_dir / "rh100_run.log"
    out_dir.mkdir(parents=True, exist_ok=True)

    data = load_jobs(job_file)

    if args.command == "status":
        print_status(data)
        return

    if args.command == "submit":
        if not args.image:
            raise SystemExit("--image is required for submit")
        if not args.prompt:
            raise SystemExit("--prompt or --prompt-file is required for submit")

        local_paths = [p for p in args.image + args.reference if Path(p).exists()]
        ensure_uploads(data, local_paths, args.concurrency, job_file, log_path)
        build_jobs(data, args)
        save_jobs(job_file, data)
        submit_pending(data, args, job_file, log_path)

    if args.command == "poll":
        poll_loop(data, args, job_file, log_path)

    print_status(load_jobs(job_file))


if __name__ == "__main__":
    main()
