"""Count Han characters covered by exact pinyin rows in culture passages.

Usage: python tool/audit_classic_pinyin.py [classic-id ...]
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "data"
PINYIN_FILES = (
    ASSETS / "online_annotated_pinyin.tsv",
    ASSETS / "verified_classic_pinyin_20260929.tsv",
)


def is_han(char):
    code = ord(char)
    return 0x3400 <= code <= 0x9FFF or 0x20000 <= code <= 0x323AF


def conversion_map():
    result = {}
    for line in (ASSETS / "opencc" / "TSCharacters.txt").read_text(
        encoding="utf-8"
    ).splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        source, targets = line.split("\t", 1)
        if len(source) == 1:
            result[ord(source)] = targets.split()[0]
    return result


def exact_patterns(mapping):
    patterns = defaultdict(set)
    for path in PINYIN_FILES:
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "\t" not in line:
                raise ValueError(f"{path.name}:{line_number}: missing tab")
            original, readings = line.split("\t", 1)
            if not original or len(original) != len(readings.split()):
                raise ValueError(f"{path.name}:{line_number}: pinyin length mismatch")
            text = original.translate(mapping)
            patterns[text[0]].add(text)
    return {key: sorted(values, key=len, reverse=True) for key, values in patterns.items()}


def coverage(passages, patterns, mapping):
    covered = total = 0
    for passage in passages:
        text = "".join(char for char in passage["original"] if is_han(char)).translate(mapping)
        total += len(text)
        locks = bytearray(len(text))
        for start, char in enumerate(text):
            if locks[start]:
                continue
            for pattern in patterns.get(char, ()):
                end = start + len(pattern)
                if end <= len(text) and text.startswith(pattern, start) and not any(locks[start:end]):
                    locks[start:end] = b"\x01" * len(pattern)
                    covered += len(pattern)
                    break
    return covered, total


def main():
    mapping = conversion_map()
    patterns = exact_patterns(mapping)
    items = json.loads((ASSETS / "culture_items_v2.json").read_text(encoding="utf-8"))
    requested = set(sys.argv[1:])
    for item in items:
        classic_id = item["id"]
        if not classic_id.startswith("classic-") or (requested and classic_id not in requested):
            continue
        asset = item.get("passagesAsset")
        if not asset:
            continue
        passages = json.loads((ROOT / asset).read_text(encoding="utf-8"))
        covered, total = coverage(passages, patterns, mapping)
        print(f"{classic_id}\t{covered}/{total}\t{covered / total * 100:.2f}%")


if __name__ == "__main__":
    main()
