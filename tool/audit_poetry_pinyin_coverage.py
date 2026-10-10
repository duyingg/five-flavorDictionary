"""Measure exact-line pronunciation coverage in the on-device poetry catalogs."""

import sys
import json
from pathlib import Path

from audit_classic_pinyin import ASSETS, ROOT, conversion_map, coverage, exact_patterns, is_han
from inspect_poetry_catalog import records


def patterns_to_trie(patterns):
    root = {}
    for values in patterns.values():
        for value in values:
            node = root
            for char in value:
                node = node.setdefault(char, {})
            node[None] = True
    return root


def context_phrase_trie(patterns, mapping):
    """Combine verified lines with the app's validated contextual phrases."""
    root = patterns_to_trie(patterns)

    inventory = json.loads((ASSETS / "pinyin_readings.json").read_text(encoding="utf-8"))
    accepted = rejected = 0
    for line in (ASSETS / "phrase_pinyin.txt").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or ": " not in line:
            continue
        original, raw_readings = line.rsplit(": ", 1)
        text = "".join(char for char in original if is_han(char)).translate(mapping)
        readings = raw_readings.split()
        if len(text) < 2 or len(text) != len(readings) or any(
            char in inventory and reading not in inventory[char]
            for char, reading in zip(text, readings)
        ):
            rejected += 1
            continue
        node = root
        for char in text:
            node = node.setdefault(char, {})
        node[None] = True
        accepted += 1
    return root, accepted, rejected


def trie_coverage(passages, trie, mapping):
    covered = total = 0
    for passage in passages:
        text = "".join(char for char in passage.get("original", passage.get("content", "")) if is_han(char)).translate(mapping)
        total += len(text)
        locks = bytearray(len(text))
        index = 0
        while index < len(text):
            if locks[index]:
                index += 1
                continue
            node = trie
            cursor = index
            best_end = index
            while cursor < len(text) and text[cursor] in node:
                node = node[text[cursor]]
                cursor += 1
                if node.get(None) and not any(locks[index:cursor]):
                    best_end = cursor
            if best_end > index:
                locks[index:best_end] = b"\x01" * (best_end - index)
                covered += best_end - index
                index = best_end
            else:
                index += 1
    return covered, total


def runtime_coverage(item, exact_trie, phrase_trie, mapping):
    """Mirror exact-line locks and punctuation-preserving phrase matching."""
    original = item['content'].translate(mapping)
    positions = [i for i, char in enumerate(original) if is_han(char)]
    han = ''.join(original[i] for i in positions)
    locked = bytearray(len(original))
    direct = 0
    index = 0
    while index < len(han):
        node, cursor, best = exact_trie, index, index
        while cursor < len(han) and han[cursor] in node:
            node = node[han[cursor]]
            cursor += 1
            if node.get(None):
                best = cursor
        if best > index:
            for offset in positions[index:best]:
                locked[offset] = 1
            direct += best - index
            index = best
        else:
            index += 1
    combined = direct
    index = 0
    while index < len(original):
        if locked[index] or not is_han(original[index]):
            index += 1
            continue
        node, cursor, best = phrase_trie, index, index
        while cursor < len(original) and not locked[cursor] and original[cursor] in node:
            node = node[original[cursor]]
            cursor += 1
            if node.get(None):
                best = cursor
        if best > index:
            combined += best - index
            index = best
        else:
            index += 1
    return direct, combined, len(han)


def main():
    catalog_name = "poetry_items_full.wvp" if "--full" in sys.argv else "poetry_items.wvp"
    mapping = conversion_map()
    patterns = exact_patterns(mapping)
    include_phrases = "--include-context-phrases" in sys.argv
    trie = None
    if include_phrases:
        trie, accepted, rejected = context_phrase_trie({}, mapping)
        print(f"context-phrases\taccepted={accepted}\trejected={rejected}")
    if trie is not None:
        direct_trie = patterns_to_trie(patterns)
        total = direct = combined = records_count = 0
        for item in records(ASSETS / catalog_name):
            text = item["content"]
            if not any(is_han(char) for char in text):
                continue
            direct_count, combined_count, size = runtime_coverage(item, direct_trie, trie, mapping)
            direct += direct_count
            combined += combined_count
            total += size
            records_count += 1
        print(f"{catalog_name}\tpoems={records_count}\t{direct}/{total}\t{direct/total*100:.2f}%")
        print(f"{catalog_name}+context_phrases\tpoems={records_count}\t{combined}/{total}\t{combined/total*100:.2f}%")
    else:
        total = matched = records_count = 0
        for item in records(ASSETS / catalog_name):
            text = item["content"]
            han_count = sum(1 for char in text if is_han(char))
            if not han_count:
                continue
            count, size = coverage([{"original": text}], patterns, mapping)
            matched += count
            total += size
            records_count += 1
        percent = matched / total * 100 if total else 0
        print(f"{catalog_name}\tpoems={records_count}\t{matched}/{total}\t{percent:.2f}%")


if __name__ == "__main__":
    main()
