"""Export poetry characters that still lack a single-character fallback reading."""

import json
from collections import Counter

from audit_classic_pinyin import ASSETS, conversion_map, is_han
from inspect_poetry_catalog import records


def missing_counts(path, readings, mapping):
    counts = Counter()
    total = 0
    for item in records(path):
        text = item.get("content", "")
        for char in text:
            if is_han(char):
                total += 1
                char = char.translate(mapping)
                if not readings.get(char):
                    counts[char] += 1
    return counts, total


def main():
    readings = json.loads((ASSETS / "pinyin_readings.json").read_text(encoding="utf-8"))
    mapping = conversion_map()
    standard, standard_total = missing_counts(ASSETS / "poetry_items.wvp", readings, mapping)
    full, full_total = missing_counts(ASSETS / "poetry_items_full.wvp", readings, mapping)
    output = ASSETS / "unresolved_poetry_pinyin.tsv"
    lines = ["字\t标准库出现次数\t全量库出现次数"]
    for char, full_count in sorted(full.items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"{char}\t{standard.get(char, 0)}\t{full_count}")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(
        f"standard_missing={sum(standard.values())}/{standard_total} chars={len(standard)}; "
        f"full_missing={sum(full.values())}/{full_total} chars={len(full)}; file={output}"
    )


if __name__ == "__main__":
    main()
