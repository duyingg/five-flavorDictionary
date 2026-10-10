"""Flag source sentences absent from shipped texts; candidates need review."""

import json
import re
from pathlib import Path

from audit_classic_pinyin import conversion_map, is_han

ROOT = Path(__file__).resolve().parents[1]
BOOKS = {
    'lunyu': 'sishu/lunyu',
    'mengzi': 'sishu/mengzi',
    'daxue': 'sishu/daxue',
    'zhongyong': 'sishu/zhongyong',
    'shangshu': 'wujing/shangshu',
    'liji': 'wujing/liji',
}


def main():
    mapping = conversion_map()

    def normalize(value):
        return ''.join(c for c in value if is_han(c)).translate(mapping)

    for book, source in BOOKS.items():
        app = json.loads((ROOT / f'assets/data/culture_passages/classic-{book}.json')
                         .read_text(encoding='utf-8'))
        app_text = normalize(''.join(p['original'] for p in app))
        reference = json.loads((ROOT / f'Aatime/chinese-classical-corpus-main/output/{source}.json')
                               .read_text(encoding='utf-8'))
        candidates = []
        checked = 0
        for chapter in reference:
            for sentence in re.split(r'[。！？；\n]', chapter['content']):
                text = normalize(sentence)
                if len(text) < 8:
                    continue
                checked += 1
                if text not in app_text:
                    candidates.append((chapter['chapter'], text))
        print(f'{book}\tchecked={checked}\tcandidates={len(candidates)}')
        for chapter, text in candidates[:25]:
            print(f'  {chapter}\t{text[:100]}')


if __name__ == '__main__':
    main()
