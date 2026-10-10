"""Read character-aligned pinyin from Baidu Hanyu poem detail pages."""

import hashlib
import html
import json
import urllib.request
from html.parser import HTMLParser

from audit_classic_pinyin import is_han
from collect_cngwzj_shijing import ROOT, decode_reading


class _PoemData(HTMLParser):
    def __init__(self):
        super().__init__()
        self.inside = False
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag == 'textarea' and dict(attrs).get('id') == 'j_poem-body-content-value':
            self.inside = True

    def handle_endtag(self, tag):
        if tag == 'textarea':
            self.inside = False

    def handle_data(self, value):
        if self.inside:
            self.parts.append(value)


def parse_work(url, mapping, inventory):
    cache = ROOT / 'tool/source_cache' / (hashlib.sha256(url.encode()).hexdigest() + '.html')
    if cache.exists():
        page = cache.read_text(encoding='utf-8')
    else:
        request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(request, timeout=15) as response:
            page = response.read().decode('utf-8', 'replace')
        cache.write_text(page, encoding='utf-8')
    parser = _PoemData()
    parser.feed(page)
    if not parser.parts:
        raise ValueError('Baidu page has no poem detail data')
    data = json.loads(html.unescape(''.join(parser.parts)))
    works = data.get('ret_array', [])
    if not works:
        raise ValueError('Baidu page has no works')
    source = []
    readings = []
    for line in works[0].get('poemlines', []):
        chars = ''.join(c for c in line.get('name', '') if is_han(c)).translate(mapping)
        if not chars:
            continue
        tokens = line.get('pinyin', '').split()
        source.extend(chars)
        if len(tokens) != len(chars):
            readings.extend([None] * len(chars))
            continue
        readings.extend(
            decode_reading(token, char, inventory)
            for char, token in zip(chars, tokens)
        )
    if not source:
        raise ValueError('Baidu page has no annotated lines')
    return ''.join(source), readings
