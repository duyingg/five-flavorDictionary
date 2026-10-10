"""Find long spans in independent public-domain texts absent from app originals."""

import difflib
import json
from collections import defaultdict
from pathlib import Path

from audit_classic_pinyin import conversion_map, is_han

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
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

    for book, source in SOURCES.items():
        app = json.loads((ROOT / f'assets/data/culture_passages/classic-{book}.json')
                         .read_text(encoding='utf-8'))
        chapters = defaultdict(list)
        heading = ''
        for passage in app:
            if passage['heading']:
                if book == 'shangshu':
                    heading = passage['heading']
                else:
                    heading = passage['heading'].split(' · ')[0].replace('章句', '').removesuffix('篇')
            chapters[heading].append(passage['original'])
        if book in ('daxue', 'zhongyong'):
            chapters = {book: [p['original'] for p in app]}
        elif book == 'shangshu':
            chapters = {
                key.replace(' · ', ' '): value for key, value in chapters.items()
            }
        elif book == 'liji':
            combined = defaultdict(list)
            for key, value in chapters.items():
                combined[key.removesuffix('上').removesuffix('下')].extend(value)
            chapters = combined
        reference = json.loads((ROOT / f'Aatime/chinese-classical-corpus-main/output/{source}.json')
                               .read_text(encoding='utf-8'))
        print(book)
        for chapter in reference:
            key = book if book in ('daxue', 'zhongyong') else chapter['chapter']
            if book == 'shangshu':
                key = key.rsplit('第', 1)[0]
            if key not in chapters:
                print('  NO_CHAPTER', key)
                continue
            app_text = normalize(''.join(chapters[key]))
            ref_text = normalize(chapter['content'])
            matcher = difflib.SequenceMatcher(None, app_text, ref_text, autojunk=False)
            for tag, a0, a1, r0, r1 in matcher.get_opcodes():
                if tag not in ('insert', 'replace') or r1 - r0 < 8:
                    continue
                ref_span = ref_text[r0:r1]
                app_span = app_text[a0:a1]
                if len(app_span) > len(ref_span) * .6:
                    continue
                print(f'  {key}\t{tag}\tapp={app_span[:50]}\tref={ref_span[:100]}\t'
                      f'around={ref_text[max(0,r0-12):min(len(ref_text),r1+12)]}')


if __name__ == '__main__':
    main()
