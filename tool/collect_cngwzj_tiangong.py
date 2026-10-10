"""Find exact app Tian Gong Kai Wu passages in the supplied annotated page.

The page replaces three Latin pinyin characters with Greek lookalikes. Their
substitution is checked against the opening passage before emitting candidates.
Candidates still require human review before importing into shipped assets.
"""

import html
import json
import re
import sys
import urllib.request
from pathlib import Path

from audit_classic_pinyin import conversion_map, is_han

ROOT = Path(__file__).resolve().parents[1]
URL = "https://www.cngwzj.com/pygushi/MingDai/90385/"
SUBSTITUTIONS = str.maketrans({"β": "h", "γ": "é", "ω": "ǔ"})


def strip_tags(text):
    return html.unescape(re.sub(r"<[^>]*>", "", text))


def main():
    request = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=25) as response:
        page = response.read().decode("utf-8", "replace")
    match = re.search(r'<div class="strbox t-l" id="gsbox"><div class="g_box">(.*?)</div></div>', page, re.S)
    if not match:
        raise ValueError("Annotated content block not found")
    body = match.group(1)
    pairs = re.findall(r"<span>(.*?)<br>(.*?)</span>", body, re.S)
    mapping = conversion_map()
    source = ""
    syllables = []
    for raw_pinyin, raw_text in pairs:
        text = "".join(c for c in strip_tags(raw_text) if is_han(c)).translate(mapping)
        if not text:
            continue
        pinyin = strip_tags(raw_pinyin).translate(SUBSTITUTIONS).strip()
        if len(text) != 1 or not re.fullmatch(r"[a-züāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+", pinyin):
            raise ValueError(f"Bad source pair: {raw_pinyin!r}, {raw_text!r}")
        source += text
        syllables.append(pinyin)
    opening = "凡治铁成器取已炒熟铁为之先铸铁成砧以为受锤之地"
    expected = "fán zhì tiě chéng qì qǔ yǐ chǎo shú tiě wéi zhī xiān zhù tiě chéng zhēn yǐ wéi shòu chuí zhī dì"
    start = source.find(opening)
    if start < 0 or " ".join(syllables[start:start + len(opening)]) != expected:
        raise ValueError("Source substitutions failed opening passage check")
    passages = json.loads((ROOT / "assets/data/culture_passages/classic-tiangong-kaiwu.json").read_text(encoding="utf-8"))
    hits = 0
    for index, passage in enumerate(passages):
        original = "".join(c for c in passage["original"] if is_han(c)).translate(mapping)
        start = source.find(original)
        if start < 0 or source.find(original, start + 1) >= 0:
            continue
        row = " ".join(syllables[start:start + len(original)])
        if len(original) != len(row.split()):
            raise ValueError(f"Bad passage slicing: {index}")
        print(f"{original}\t{row}")
        hits += len(original)
        print(f"MATCH\t{index}\t{len(original)}\t{passage['original'][:50]}", file=sys.stderr)
    print(f"SOURCE\t{hits}/{len(source)}\t{URL}", file=sys.stderr)


if __name__ == "__main__":
    main()
