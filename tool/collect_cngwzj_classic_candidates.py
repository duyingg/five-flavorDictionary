"""Align selected CNGWZJ annotated prose pages to app classic passages."""

import argparse
import difflib
import json
import sys
from collections import defaultdict
from pathlib import Path

from audit_classic_pinyin import ASSETS, conversion_map, is_han
from collect_cngwzj_shijing import ROOT, parse_work
from collect_baidu_pinyin import parse_work as parse_baidu_work


def normalize(text, mapping):
    return "".join(char for char in text if is_han(char)).translate(mapping)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(fromfile_prefix_chars='@')
    parser.add_argument("source", nargs="+", help="classic-id=url")
    args = parser.parse_args()
    mapping = conversion_map()
    inventory = json.loads((ASSETS / "pinyin_readings.json").read_text(encoding="utf-8"))
    items = json.loads((ASSETS / "culture_items_v2.json").read_text(encoding="utf-8"))
    assets = {item["id"]: item.get("passagesAsset") for item in items
              if item.get("id", "").startswith("classic-") and item.get("passagesAsset")}
    passages = {}
    for classic_id, path in assets.items():
        source_path = ROOT / path
        passages[classic_id] = [normalize(item.get("original", ""), mapping)
                                for item in json.loads(source_path.read_text(encoding="utf-8"))]

    rows = {}
    conflicts = set()
    for specification in args.source:
        classic_id, url = specification.split("=", 1)
        if classic_id not in passages:
            raise SystemExit(f"Unknown classic id: {classic_id}")
        try:
            source, readings = (
                parse_baidu_work(url, mapping, inventory)
                if 'hanyu.baidu.com/shici/detail' in url
                else parse_work(url, mapping, inventory)
            )
        except Exception as error:
            print(f"FETCH_ERROR\t{classic_id}\t{url}\t{error}", file=sys.stderr)
            continue
        targets = passages[classic_id]
        offsets = []
        pieces = []
        cursor = 0
        for target in targets:
            start = cursor
            pieces.append(target)
            cursor += len(target)
            offsets.append((start, cursor))
            pieces.append("\uffff")
            cursor += 1
        joined = "".join(pieces)
        matcher = difflib.SequenceMatcher(None, source, joined, autojunk=True)
        chars_added = matches = 0
        block_ranges = [(block.a, block.b, block.size)
                        for block in matcher.get_matching_blocks() if block.size >= 4]
        passage_index = 0
        for source_start, target_start, size in block_ranges:
            target_end = target_start + size
            while passage_index < len(offsets) and offsets[passage_index][1] <= target_start:
                passage_index += 1
            index = passage_index
            while index < len(offsets) and offsets[index][0] < target_end:
                passage_start, passage_end = offsets[index]
                left = max(target_start, passage_start)
                right = min(target_end, passage_end)
                if right - left >= 4:
                    source_left = source_start + left - target_start
                    run_start = None
                    for offset in range(right - left + 1):
                        valid = offset < right - left and readings[source_left + offset] is not None
                        if valid and run_start is None:
                            run_start = offset
                        if not valid and run_start is not None:
                            if offset - run_start >= 4:
                                text = joined[left + run_start:left + offset]
                                pinyin = " ".join(readings[source_left + run_start:source_left + offset])
                                previous = rows.get(text)
                                if previous is not None and previous != pinyin:
                                    conflicts.add(text)
                                    rows.pop(text, None)
                                elif text not in conflicts:
                                    rows.setdefault(text, pinyin)
                                chars_added += len(text)
                                matches += 1
                            run_start = None
                index += 1
        print(f"PAGE\t{classic_id}\t{matches}\t{chars_added}/{len(source)}\t{url}", file=sys.stderr)

    for text in sorted(conflicts):
        print(f"CONFLICT\t{text}", file=sys.stderr)
    for text, pinyin in rows.items():
        print(f"{text}\t{pinyin}")
    print(f"SUMMARY\trows={len(rows)}\tconflicts={len(conflicts)} "
          f"chars={sum(len(text) for text in rows)}", file=sys.stderr)


if __name__ == "__main__":
    main()
