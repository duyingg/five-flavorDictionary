"""Fetch a CNGWZJ URL list into the existing source cache with bounded concurrency."""

import argparse
import hashlib
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "tool" / "source_cache"


def fetch_one(url):
    path = CACHE / (hashlib.sha256(url.encode()).hexdigest() + ".html")
    if path.exists():
        return "cached", url
    error = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=20) as response:
                page = response.read().decode("utf-8", "replace")
            if 'id="gsbox"' not in page or "<span>" not in page:
                raise ValueError("annotated body missing")
            path.write_text(page, encoding="utf-8")
            return "fetched", url
        except Exception as exc:
            error = exc
            time.sleep(attempt + 1)
    return f"error: {error}", url


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("url_list")
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()
    urls = list(dict.fromkeys((ROOT / args.url_list).read_text(encoding="utf-8-sig").splitlines()))
    counts = {"cached": 0, "fetched": 0, "error": 0}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = [pool.submit(fetch_one, url) for url in urls]
        for index, future in enumerate(as_completed(jobs), 1):
            state, url = future.result()
            key = "error" if state.startswith("error") else state
            counts[key] += 1
            if key == "error":
                print(f"ERROR\t{url}\t{state}", flush=True)
            if index % 25 == 0 or index == len(urls):
                print(f"PROGRESS\t{index}/{len(urls)}\t{counts}", flush=True)


if __name__ == "__main__":
    main()
