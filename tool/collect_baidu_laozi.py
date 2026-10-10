"""Collect Baidu Hanyu Laozi chapter candidates for manual review.

The page exposes per-line hanzi/pinyin pairs in an embedded JSON block. This
script only emits rows matching an app passage verbatim after punctuation is
removed. It never changes the shipped assets.
"""

import html
import json
import re
import sys
import urllib.request
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = "247de09646ac9b265ae504216168e3f0"
BASE = "https://hanyu.baidu.com/shici/detail?pid="


def han(text):
    return "".join(c for c in text if "\u3400" <= c <= "\u9fff")


def fetch(sid):
    request = urllib.request.Request(BASE + sid, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        page = response.read().decode("utf-8")
    match = re.search(r'<textarea id="j_poem-body-content-value"[^>]*>(.*?)</textarea>', page, re.S)
    if not match:
        raise ValueError(f"No embedded poem data for {sid}")
    return json.loads(html.unescape(match.group(1)))


def chapter_name(title):
    match = re.search(r"第([一二三四五六七八九十百]+)章", title)
    return match.group(1) if match else None


def main():
    passages = json.loads((ROOT / "assets/data/culture_passages/classic-laozi.json").read_text(encoding="utf-8"))
    by_chapter = {}
    chapter = None
    for passage in passages:
        chapter = chapter_name(passage["heading"]) or chapter
        if chapter:
            by_chapter.setdefault(chapter, []).append(passage["original"])

    queue = deque([sys.argv[1] if len(sys.argv) > 1 else SEED])
    seen = set()
    rows = {}
    reviewed = []
    while queue and len(seen) < 100:
        sid = queue.popleft()
        if sid in seen:
            continue
        seen.add(sid)
        try:
            data = fetch(sid)
        except Exception as exc:
            print(f"FETCH_ERROR\t{sid}\t{exc}", file=sys.stderr)
            continue
        for related in data.get("related_poems", []):
            if "道德经" in related.get("name", "") and related["sid"] not in seen:
                queue.append(related["sid"])
        poem = data["ret_array"][0]
        title = poem["display_name"][0]
        key = chapter_name(title)
        if not key or key not in by_chapter:
            continue
        source = ""
        pinyin = []
        valid = True
        for line in poem.get("poemlines", []):
            text = han(line["name"])
            syllables = line["pinyin"].split()
            if len(text) != len(syllables):
                valid = False
                break
            source += text
            pinyin.extend(syllables)
        if not valid:
            print(f"LENGTH_MISMATCH\t{title}\t{sid}", file=sys.stderr)
            continue
        hits = 0
        misses = []
        for passage in by_chapter[key]:
            original = han(passage)
            start = source.find(original)
            if start < 0 or source.find(original, start + 1) >= 0:
                misses.append(passage[:80])
                continue
            row = " ".join(pinyin[start:start + len(original)])
            if len(row.split()) != len(original):
                raise ValueError(f"Bad slicing: {title}")
            rows[original] = row
            hits += len(original)
        reviewed.append((title, sid, hits, len(source)))
        for passage in misses:
            print(f"VERSION_MISMATCH\t{title}\t{passage}", file=sys.stderr)
    for title, sid, hits, total in reviewed:
        print(f"CHAPTER\t{title}\t{hits}/{total}\t{BASE + sid}", file=sys.stderr)
    for original, pinyin in rows.items():
        print(f"{original}\t{pinyin}")


if __name__ == "__main__":
    main()
