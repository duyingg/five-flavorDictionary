"""Build the offline classical lookup index from the app's existing passages."""

import json
import gzip
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'assets' / 'data'


def main():
    items = json.loads((DATA / 'culture_items_v2.json').read_text(encoding='utf-8'))
    rows = []
    for item in items:
        asset = item.get('passagesAsset')
        if not asset or not item.get('id', '').startswith('classic-'):
            continue
        passages = json.loads((ROOT / asset).read_text(encoding='utf-8'))
        heading = ''
        for passage in passages:
            heading = passage.get('heading') or heading
            original = passage.get('original', '').strip()
            if original:
                rows.append([
                    item['id'], item['title'], heading, original,
                    passage.get('translation', '').strip(),
                ])
    target = DATA / 'classical_lookup_index.json.gz'
    payload = json.dumps(rows, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    target.write_bytes(gzip.compress(payload, compresslevel=9, mtime=0))
    print(f'passages={len(rows)} books={len({row[0] for row in rows})} '
          f'bytes={target.stat().st_size}')


if __name__ == '__main__':
    main()
