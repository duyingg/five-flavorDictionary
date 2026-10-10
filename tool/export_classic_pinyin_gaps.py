"""Export actual unfilled app passages, with chapter and stable passage index."""

import argparse
import csv
import json
from pathlib import Path

from audit_classic_pinyin import ASSETS, ROOT, conversion_map, exact_patterns
from audit_poetry_pinyin_coverage import patterns_to_trie, runtime_coverage


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'tool/unresolved_classic_pinyin_20261001.tsv')
    args = parser.parse_args()
    mapping = conversion_map()
    trie = patterns_to_trie(exact_patterns(mapping))
    items = json.loads((ASSETS / 'culture_items_v2.json').read_text(encoding='utf-8'))
    missing_passages = missing_chars = 0
    with args.output.open('w', encoding='utf-8', newline='') as output:
        writer = csv.writer(output, delimiter='\t')
        writer.writerow(['book_id', 'title', 'chapter', 'passage_index_1based', 'covered_han', 'total_han', 'original'])
        for item in items:
            if not item['id'].startswith('classic-') or not item.get('passagesAsset'):
                continue
            passages = json.loads((ROOT / item['passagesAsset']).read_text(encoding='utf-8'))
            chapter = ''
            for index, passage in enumerate(passages, 1):
                chapter = passage.get('heading') or chapter
                covered, _, total = runtime_coverage({'content': passage['original']}, trie, {}, mapping)
                if covered < total:
                    missing_passages += 1
                    missing_chars += total - covered
                    writer.writerow([item['id'], item['title'], chapter, index, covered, total, passage['original']])
    print(f'missing_passages={missing_passages} missing_chars={missing_chars} output={args.output}')


if __name__ == '__main__':
    main()
