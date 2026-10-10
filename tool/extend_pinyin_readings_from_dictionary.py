"""Extend the poetry fallback inventory from the app's reviewed character dictionary.

Only adds missing single-Han entries. Existing pypinyin readings are preserved.
Entries with no overlap against the existing phrase-pinyin data are skipped when
the character is attested there, since that signals a likely source disagreement.
"""

import json
import re
from collections import defaultdict
from pathlib import Path

from audit_classic_pinyin import ASSETS, conversion_map, is_han

ROOT = Path(__file__).resolve().parents[1]
ENTRY_FILE = ASSETS / "chinese_entries_v3.json"
READING_FILE = ASSETS / "pinyin_readings.json"
PHRASE_FILE = ASSETS / "phrase_pinyin.txt"

PINYIN = re.compile(
    r"^[a-züāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ]+$"
)

# Cross-checked against independent character dictionaries for rare corpus forms.
CURATED_READINGS = {
    "㑩": ["luó"],
    "砢": ["luǒ", "kē"],
    "𬣙": ["xū", "xǔ"],
    "𥮾": ["zān", "cēn", "cǎn"],
    "肸": ["xī", "xì"],
    "𬬻": ["lú"],
    "㶉": ["xī"],
    "䌷": ["chōu", "chóu"],
    "䜩": ["yàn"],
    "䕷": ["mí"],
    "䍠": ["lí"],
    "㶁": ["guó", "huò"],
    "䅉": ["yà"],
    "䆉": ["bà"],
    "磈": ["wěi", "kuǐ"],
    "𬯀": ["jī"],
    "𬘘": ["dǎn"],
    "蟇": ["má"],
    "𪾢": ["xiàn"],
    "𬘡": ["yīn"],
    "㧑": ["huī", "wéi"],
    "𣂏": ["jū"],
    "䯄": ["guā"],
    "𧥄": ["jí"],
    "𡏖": ["ài"],
    "䔩": ["sù"],
    "𫓧": ["fū"],
    "𫗧": ["sù"],
    "𬊈": ["xún"],
    "䲡": ["qiū"],
    "㦸": ["jǐ"],
    "𫘝": ["jué", "kuài"],
    "蠙": ["pín"],
    "䌸": ["juàn"],
    "𩕳": ["nǐng"],
    "𫇭": ["wěi"],
    "𤃩": ["líng"],
    "轇": ["jiū", "jiāo"],
    "㲲": ["dié", "yì"],
    "䆗": ["yǎo", "jiào"],
    "𨁝": ["bó"],
    "䨴": ["duì"],
    "𤱶": ["quǎn"],
    "𩍐": ["dèng"],
    "㦬": ["luò"],
    "䙰": ["lí"],
    "侁": ["shēn"],
    "𪟝": ["jì"],
}


def canonical(value):
    return value.strip().lower().replace("u:", "ü").replace("v", "ü").replace("ɡ", "g")


def phrase_readings():
    readings = defaultdict(set)
    mapping = conversion_map()
    for line in PHRASE_FILE.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or ": " not in line:
            continue
        text, raw = line.rsplit(": ", 1)
        text = "".join(char for char in text if is_han(char)).translate(mapping)
        syllables = [canonical(value) for value in raw.split()]
        if len(text) == len(syllables):
            for char, syllable in zip(text, syllables):
                readings[char].add(syllable)
    return readings


def main():
    readings = json.loads(READING_FILE.read_text(encoding="utf-8"))
    entries = json.loads(ENTRY_FILE.read_text(encoding="utf-8"))
    phrases = phrase_readings()
    additions = {}
    malformed = 0
    conflicts = set()

    for entry in entries:
        char = entry.get("character", "")
        if len(char) != 1 or not is_han(char) or char in readings:
            continue
        values = []
        for raw in entry.get("pinyin", ()):
            value = canonical(raw)
            if not value:
                continue
            if not PINYIN.fullmatch(value):
                malformed += 1
                continue
            if value not in values:
                values.append(value)
        if not values:
            continue
        phrase_values = phrases.get(char, set())
        if phrase_values and not phrase_values.intersection(values):
            conflicts.add(char)
            continue
        additions[char] = values

    for char, values in CURATED_READINGS.items():
        if char not in readings:
            additions.setdefault(char, values)

    readings.update(additions)
    READING_FILE.write_text(
        json.dumps(readings, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"added={len(additions)} conflicts_skipped={len(conflicts)} "
        f"malformed_readings_skipped={malformed} total={len(readings)}"
    )


if __name__ == "__main__":
    main()
