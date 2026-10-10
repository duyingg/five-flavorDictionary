"""Recheck cached annotated pages against the current app poetry catalog.

Keep character-exact spans only. Masked syllables require the per-page anchor
evidence checked by parse_page. Record each accepted span's URL for review.
"""

import argparse
import difflib
import html
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

from audit_classic_pinyin import ASSETS, ROOT, conversion_map, is_han
from collect_cngwzj_shijing import parse_page
from inspect_poetry_catalog import records


def normalized(text, mapping):
    return ''.join(c for c in text if is_han(c)).translate(mapping)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'tool/cngwzj_poetry_20261001.tsv')
    args = parser.parse_args()
    mapping = conversion_map()
    inventory = json.loads((ASSETS / 'pinyin_readings.json').read_text(encoding='utf-8'))
    poems = []
    by_title, by_prefix = defaultdict(list), defaultdict(list)
    for poem in records(ASSETS / 'poetry_items.wvp'):
        title = normalized(poem['title'], mapping)
        body = normalized(poem['content'], mapping)
        index = len(poems)
        poems.append((poem['id'], body))
        by_title[title].append(index)
        if len(body) >= 8:
            by_prefix[body[:8]].append(index)
    rows, conflicts, provenance = {}, set(), defaultdict(set)
    seen, parsed, matched, rejected = set(), 0, 0, 0
    for file in sorted((ROOT / 'tool/source_cache').glob('*.html')):
        page = file.read_text(encoding='utf-8', errors='replace')
        own = re.search(r'(?:mobile-agent[^>]*?url=|window\.location\.href\s*=\s*)[\'\"]?(https?://m\.cngwzj\.com/pygushi/[^\"\'<> ;]+)', page, re.I)
        if not own:
            continue
        url = own[1].replace('m.cngwzj.com', 'www.cngwzj.com').rstrip('/')
        if url in seen:
            continue
        title_tag = re.search(r'<title>(.*?)</title>', page, re.S | re.I)
        title_match = re.search(r'《(.*?)》', html.unescape(title_tag[1])) if title_tag else None
        title = normalized(title_match[1], mapping) if title_match else ''
        try:
            source, readings = parse_page(page, mapping, inventory, url)
        except ValueError:
            rejected += 1
            continue
        seen.add(url)
        parsed += 1
        potential = set(by_title.get(title, ()))
        # The source includes its title and author; examine the first 100
        # characters to find matching openings when app titles differ.
        for start in range(min(100, len(source) - 7)):
            potential.update(by_prefix.get(source[start:start + 8], ()))
        hits = 0
        for index in potential:
            poem_id, target = poems[index]
            if not target:
                continue
            blocks = difflib.SequenceMatcher(None, target, source, autojunk=False).get_matching_blocks()
            shared = sum(block.size for block in blocks)
            if shared < min(len(target), len(source)) * 0.65:
                continue
            for block in blocks:
                if block.size < 4:
                    continue
                run = None
                for offset in range(block.size + 1):
                    valid = offset < block.size and readings[block.b + offset] is not None
                    if valid and run is None:
                        run = offset
                    if not valid and run is not None:
                        if offset - run >= 4:
                            text = target[block.a + run:block.a + offset]
                            pinyin = ' '.join(readings[block.b + run:block.b + offset])
                            if text in rows and rows[text] != pinyin:
                                conflicts.add(text)
                                rows.pop(text)
                            elif text not in conflicts:
                                rows[text] = pinyin
                                provenance[text].add((url, poem_id))
                                hits += len(text)
                        run = None
        matched += bool(hits)
        if parsed % 100 == 0:
            print(f'PROGRESS pages={parsed} matched={matched} rows={len(rows)}', flush=True)
    args.output.write_text(''.join(f'{text}\t{pinyin}\n' for text, pinyin in rows.items()), encoding='utf-8')
    args.output.with_suffix('.sources.tsv').write_text(''.join(
        f'{text}\t{url}\t{poem_id}\n' for text in rows for url, poem_id in sorted(provenance[text])
    ), encoding='utf-8')
    args.output.with_suffix('.conflicts.txt').write_text('\n'.join(sorted(conflicts)), encoding='utf-8')
    print(f'SUMMARY pages={parsed} matched={matched} rows={len(rows)} chars={sum(map(len, rows))} conflicts={len(conflicts)} rejected_pages={rejected}')


if __name__ == '__main__':
    main()
