"""Audit shipped literary passages for ordering and punctuation boundaries."""

import json
import sys
from pathlib import Path

from inspect_poetry_catalog import records

ROOT = Path(__file__).resolve().parents[1]
MARKS = set('，。！？；：、,.!?;:)]}）］｝】〕〉》」』”’…—')
FILES = sorted((ROOT / 'assets/data/culture_passages').glob('*.json'))


def readable_lines(content):
    result = []
    for line in content.replace('□', '〔原文缺字〕').splitlines():
        leading = 0
        while leading < len(line) and line[leading] in MARKS:
            leading += 1
        if not leading:
            result.append(line)
            continue
        previous = next((i for i in range(len(result) - 1, -1, -1) if result[i]), None)
        if previous is None:
            result.append('〔原文残缺〕' + line)
        else:
            result[previous] += line[:leading]
            if line[leading:]:
                result.append(line[leading:])
    return result


def main():
    total_passages = 0
    for file in FILES:
        passages = json.loads(file.read_text(encoding='utf-8'))
        total_passages += len(passages)
        bad = []
        for index, passage in enumerate(passages):
            for line in passage['original'].splitlines():
                if line and line[0] in MARKS:
                    bad.append((index, line[:30]))
        if bad:
            print(file.stem, 'leading punctuation', len(bad), bad[:5])
    print('literature:', len(FILES), 'books,', total_passages, 'passages')
    for catalog_name in ('poetry_items.wvp', 'poetry_items_full.wvp'):
        bad = []
        first = []
        total = 0
        visible_bad = 0
        for poem in records(ROOT / 'assets/data' / catalog_name):
            total += 1
            for line_index, line in enumerate(poem['content'].splitlines()):
                if line and line[0] in MARKS:
                    bad.append((poem['id'], poem['title'], line[:30]))
                    if line_index == 0:
                        first.append((poem['id'], poem['title'], line[:30]))
            visible_bad += sum(bool(line and line[0] in MARKS) for line in readable_lines(poem['content']))
        print(catalog_name, total, 'poems,', len(bad), 'leading punctuation')
        print('  initial text:', len(first), first[:10])
        print('  after line break:', len(bad) - len(first), bad[:10])
        print('  after display normalization:', visible_bad)
        assert visible_bad == 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
