"""Find exact app poetry lines in Baidu Hanyu's annotated poem pages.

Run with one or more Baidu Hanyu poem IDs. Writes candidate TSV rows to stdout
and a match report to stderr. Human review is required before import.
"""

import sys
from difflib import SequenceMatcher
from pathlib import Path

from audit_classic_pinyin import conversion_map, is_han
from collect_baidu_laozi import BASE, fetch
from inspect_poetry_catalog import records

ROOT = Path(__file__).resolve().parents[1]


def normalize(text, mapping):
    return "".join(c for c in text if is_han(c)).translate(mapping)


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python tool/collect_baidu_poetry.py poem-id ...")
    mapping = conversion_map()
    catalog = list(records(ROOT / "assets/data/poetry_items.wvp"))
    output = {}
    for sid in sys.argv[1:]:
        data = fetch(sid)["ret_array"][0]
        title = data["display_name"][0]
        author = data["literature_author"][0]["display_name"][0]
        source = ""
        readings = []
        for line in data.get("poemlines", []):
            original = normalize(line["name"], mapping)
            syllables = line["pinyin"].split()
            if len(original) != len(syllables):
                raise ValueError(f"Source length mismatch: {title} {sid}")
            source += original
            readings.extend(syllables)
        source_title = normalize(title, mapping)
        matches = [item for item in catalog
                   if normalize(item["author"], mapping) == normalize(author, mapping)
                   and (source_title in normalize(item["title"], mapping)
                        or (len(normalize(item["title"], mapping)) >= 3
                            and normalize(item["title"], mapping) in source_title)
                        or (len(source) >= 20
                            and source in normalize(item["content"], mapping)))]
        hit_count = 0
        for item in matches:
            target = normalize(item["content"], mapping)
            matcher = SequenceMatcher(None, target, source, autojunk=False)
            for block in matcher.get_matching_blocks():
                if block.size < 4:
                    continue
                original = target[block.a:block.a + block.size]
                row = " ".join(readings[block.b:block.b + block.size])
                if len(row.split()) != len(original):
                    raise ValueError(f"Candidate length mismatch: {title}")
                output.setdefault(original, row)
                hit_count += len(original)
        print(f"SOURCE\t{title}\t{author}\t{hit_count}/{len(source)}\t{BASE + sid}", file=sys.stderr)
    for original, pinyin in output.items():
        print(f"{original}\t{pinyin}")


if __name__ == "__main__":
    main()
