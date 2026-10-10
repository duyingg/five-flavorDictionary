"""Collect character-aligned pinyin from CNGWZJ annotated collections.

Masked Greek letters are resolved from at least three distinct single-reading
character anchors on the same page, with 97% consensus. Unresolved or
mismatching annotations are omitted.
"""

import html
import hashlib
import difflib
import unicodedata
import re
import sys
import time
import urllib.request
import json
import argparse
from collections import Counter, OrderedDict
from html.parser import HTMLParser
from pathlib import Path

from audit_classic_pinyin import conversion_map, is_han
from inspect_poetry_catalog import records

ROOT = Path(__file__).resolve().parents[1]
INDEX = "https://www.cngwzj.com/tangshi300/1099.html"
BASE = "https://www.cngwzj.com"
MASKED = set("βγωαι")
PINYIN = re.compile(r"^[a-züāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+$")
_LOCAL_PAGES = None


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href", "")
            if "/pygushi/" in href:
                self.hrefs.append(href)


class Text(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, value):
        self.parts.append(value)


def fetch(url):
    cached = ROOT / "tool" / "source_cache" / (hashlib.sha256(url.encode()).hexdigest() + ".html")
    if cached.exists():
        return cached.read_text(encoding="utf-8")
    global _LOCAL_PAGES
    if _LOCAL_PAGES is None:
        _LOCAL_PAGES = {}
        for path in (ROOT / "tool" / "source_cache").glob("*.html"):
            page = path.read_text(encoding="utf-8", errors="replace")
            # Only use the page's own mobile-agent/redirect URL. Mining every
            # href incorrectly assigns linked neighboring pages to this page.
            own_urls = re.findall(
                r"(?:mobile-agent[^>]*?url=|window\.location\.href\s*=\s*)['\"]?"
                r"(https?://m\.cngwzj\.com/pygushi/[^\"'<> ;]+)",
                page,
                re.I,
            )
            for found in own_urls:
                normalized = found.replace("m.cngwzj.com", "www.cngwzj.com").rstrip("/")
                if normalized not in _LOCAL_PAGES or page.count('<span>') > _LOCAL_PAGES[normalized].count('<span>'):
                    _LOCAL_PAGES[normalized] = page
    page = _LOCAL_PAGES.get(url.rstrip("/"))
    if page is not None:
        return page
    cached.parent.mkdir(exist_ok=True)
    error = None
    for attempt in range(2):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=10) as response:
                raw = response.read()
            page = raw.decode("utf-8", "replace")
            cached.write_text(page, encoding="utf-8")
            time.sleep(0.25)
            return page
        except Exception as exc:
            error = exc
            time.sleep(0.5)
    raise error


def plain(fragment):
    parser = Text()
    parser.feed(fragment)
    return html.unescape("".join(parser.parts)).strip()


def canonical_pinyin(value):
    # The source sometimes uses IPA script g instead of Latin g.
    return unicodedata.normalize("NFC", value.lower().replace("ɡ", "g"))


def decode_reading(raw, char, inventory, mask_mapping=None):
    pinyin = canonical_pinyin(plain(raw))
    # Validate masked glyphs before resolving them against known readings.
    # Rejecting Greek glyphs here used to make the resolution below unreachable.
    if not PINYIN.fullmatch(''.join('a' if letter in MASKED else letter for letter in pinyin)):
        return None
    options = [canonical_pinyin(item) for item in inventory.get(char, ())]
    if any(letter in MASKED for letter in pinyin):
        # The page uses one substitution per glyph. Resolve it from several
        # independent unambiguous annotations on this page, never by guessing
        # a masked character's pronunciation in isolation.
        mask_mapping = mask_mapping or {}
        if any(letter in MASKED and letter not in mask_mapping for letter in pinyin):
            return None
        pinyin = ''.join(mask_mapping.get(letter, letter) for letter in pinyin)
    if options:
        return pinyin if pinyin in options else None
    # Rare characters missing from the app inventory may use the source's
    # explicitly written reading; masked forms are never guessed.
    return pinyin


def page_mask_mapping(pairs, mapping, inventory):
    votes = {letter: Counter() for letter in MASKED}
    seen_anchors = set()
    for raw_pinyin, raw_char in pairs:
        char = ''.join(c for c in plain(raw_char) if is_han(c)).translate(mapping)
        raw = canonical_pinyin(plain(raw_pinyin))
        if len(char) != 1 or not any(letter in MASKED for letter in raw):
            continue
        options = set(canonical_pinyin(item) for item in inventory.get(char, ()))
        if len(options) != 1:
            continue
        reading = next(iter(options))
        if len(reading) != len(raw) or not all(a in MASKED or a == b for a, b in zip(raw, reading)):
            continue
        for source, target in zip(raw, reading):
            if source in MASKED and (source, char, target) not in seen_anchors:
                votes[source][target] += 1
                seen_anchors.add((source, char, target))
    result = {}
    for letter, counts in votes.items():
        if not counts:
            continue
        replacement, count = counts.most_common(1)[0]
        if count >= 3 and count / sum(counts.values()) >= 0.97:
            result[letter] = replacement
    return result


def parse_work(url, mapping, inventory):
    page = fetch(url)
    return parse_page(page, mapping, inventory, url)


def parse_page(page, mapping, inventory, url='cached page'):
    match = re.search(r'<div class="strbox t-l" id="gsbox">\s*<div class="g_box">(.*?)</div>', page, re.S)
    if not match:
        raise ValueError(f"Annotated body missing: {url}")
    pairs = re.findall(r"<span>(.*?)<br>(.*?)</span>", match.group(1), re.S)
    mask_mapping = page_mask_mapping(pairs, mapping, inventory)
    chars, readings = [], []
    for raw_pinyin, raw_char in pairs:
        char = "".join(c for c in plain(raw_char) if is_han(c)).translate(mapping)
        # The HTML encodes some tone vowels as decomposed base+combining mark.
        if not char:
            continue
        if len(char) != 1:
            # Rare glyphs may be printed as two components, or a source span
            # may contain two characters but only one syllable. Keep their
            # positions unannotated and continue checking the rest of the page.
            chars.extend(char)
            readings.extend([None] * len(char))
            continue
        chars.append(char)
        readings.append(decode_reading(raw_pinyin, char, inventory, mask_mapping))
    return "".join(chars), readings


def title_for(url):
    match = re.search(r"<title>(.*?)</title>", fetch(url), re.S | re.I)
    if not match:
        return ""
    title = html.unescape(re.sub(r"<[^>]+>", "", match.group(1)))
    match = re.search(r"《(.*?)》", title)
    return match.group(1) if match else ""


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="strict")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", default=INDEX)
    parser.add_argument("--url-cache", default="tool/source_cache/shijing_urls.txt")
    args = parser.parse_args()
    mapping = conversion_map()
    inventory = json.loads((ROOT / "assets/data/pinyin_readings.json").read_text(encoding="utf-8"))
    urls_file = ROOT / args.url_cache
    urls = urls_file.read_text(encoding="utf-8").splitlines() if urls_file.exists() else []
    if not urls:
        links = Links()
        links.feed(fetch(args.index))
        urls = list(OrderedDict.fromkeys(link if link.startswith("http") else BASE + link for link in links.hrefs))
        urls_file.write_text("\n".join(urls), encoding="utf-8")
    catalog = list(records(ROOT / "assets/data/poetry_items.wvp"))
    normalized, by_title = [], {}
    for item in catalog:
        normalized.append("".join(c for c in item["content"] if is_han(c)).translate(mapping))
        title = "".join(c for c in item["title"] if is_han(c)).translate(mapping)
        if title:
            by_title.setdefault(title, []).append(len(normalized) - 1)
    candidates = {}
    conflicts = set()
    matched_sources = 0
    for index, url in enumerate(urls, 1):
        try:
            source, readings = parse_work(url, mapping, inventory)
        except Exception as exc:
            print(f"FETCH_ERROR\t{url}\t{exc}", file=sys.stderr)
            continue
        hits = 0
        title = "".join(c for c in title_for(url) if is_han(c)).translate(mapping)
        potential = by_title.get(title, ())
        for record_index in potential:
            target = normalized[record_index]
            if not target:
                continue
            matcher = difflib.SequenceMatcher(None, target, source, autojunk=False)
            for block in matcher.get_matching_blocks():
                if block.size < 4:
                    continue
                original = target[block.a:block.a + block.size]
                run_start = None
                for offset in range(block.size + 1):
                    valid = offset < block.size and readings[block.b + offset] is not None
                    if valid and run_start is None:
                        run_start = offset
                    if not valid and run_start is not None:
                        if offset - run_start >= 4:
                            segment = original[run_start:offset]
                            row = " ".join(readings[block.b + run_start:block.b + offset])
                            existing = candidates.get(segment)
                            if existing is not None and existing != row:
                                conflicts.add(segment)
                                candidates.pop(segment, None)
                            elif segment not in conflicts:
                                candidates.setdefault(segment, row)
                            hits += len(segment)
                        run_start = None
        if hits:
            matched_sources += 1
        print(f"WORK\t{index}/{len(urls)}\t{hits}\t{url}", file=sys.stderr)
    print(f"SUMMARY\tworks={len(urls)}\tmatched={matched_sources}\trows={len(candidates)}\tconflicts={len(conflicts)}", file=sys.stderr)
    for original, row in candidates.items():
        print(f"{original}\t{row}")


if __name__ == "__main__":
    main()
