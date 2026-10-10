"""Regenerate daily cards and the complete idiom membership index.

Run after import_poetry.dart and import_words.dart. Word cards are read from
the WVD catalog at runtime, so this tool does not duplicate its definitions.
"""

import json
import struct
from pathlib import Path

from inspect_poetry_catalog import records


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"


def translated_poetry_cards():
    index = (DATA / "poetry_standard_index.wvi").read_bytes()
    if index[:8] != b"WUWESUB1":
        raise ValueError("Invalid standard poetry index")
    total, selected = struct.unpack_from("<II", index, 8)
    if len(index) != 16 + (total + 7) // 8:
        raise ValueError("Invalid standard poetry index length")
    bits = index[16:]
    cards = []
    seen = 0
    positions = 0
    for position, poem in enumerate(records(DATA / "poetry_items_full.wvp")):
        positions += 1
        if position >= total:
            raise ValueError("Poetry index and catalog have different lengths")
        if not bits[position >> 3] & (1 << (position & 7)):
            continue
        seen += 1
        if not poem["translation"]:
            continue
        lines = [line.strip() for line in poem["content"].splitlines() if line.strip()]
        if len(lines) < 2:
            raise ValueError(f"Translated poem has too little text: {poem['id']}")
        cards.append(
            {
                "id": poem["id"],
                "type": "verse",
                "title": lines[0],
                "summary": lines[1],
                "author": poem["author"],
                "sourceTitle": poem["title"],
                "sourceId": poem["source"],
            }
        )
    if positions != total or seen != selected:
        raise ValueError("Poetry catalog and standard index disagree")
    return sorted(cards, key=lambda card: card["id"])


def is_han_word(word):
    def is_han(character):
        value = ord(character)
        return any(
            start <= value <= end
            for start, end in (
                (0x3400, 0x4DBF),
                (0x4E00, 0x9FFF),
                (0xF900, 0xFAFF),
                (0x20000, 0x2EE5F),
                (0x2F800, 0x2FA1F),
                (0x30000, 0x323AF),
            )
        )

    return len(word) >= 2 and all(is_han(character) for character in word)


def idiom_words():
    source = json.loads(
        (ROOT / "Aatime/chinese-dictionary-main/idiom/idiom.json").read_text(
            encoding="utf-8"
        )
    )
    return {
        item["word"].strip()
        for item in source
        if isinstance(item.get("word"), str)
        and is_han_word(item["word"].strip())
        and str(item.get("pinyin") or "").strip()
        and str(item.get("explanation") or "").strip()
    }


def build_idiom_index():
    idioms = idiom_words()
    data = (DATA / "word_entries.wvd").read_bytes()
    if data[:8] != b"WUWEIWD1":
        raise ValueError("Invalid word catalog")
    count = struct.unpack_from("<I", data, 8)[0]
    offsets = struct.unpack_from(f"<{count + 1}I", data, 12)
    start = 12 + 4 * (count + 1)
    if start + offsets[-1] != len(data):
        raise ValueError("Invalid word catalog length")
    bits = bytearray((count + 7) // 8)
    found = 0
    for position in range(count):
        cursor = start + offsets[position]
        length = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        word = data[cursor : cursor + length].decode("utf-8")
        if word in idioms:
            bits[position >> 3] |= 1 << (position & 7)
            found += 1
    if found != len(idioms):
        raise ValueError(f"Only {found} of {len(idioms)} idioms exist in WVD")
    target = DATA / "idiom_positions.wvi"
    target.write_bytes(b"WUWEIDI1" + struct.pack("<II", count, found) + bits)
    return found, count


def main():
    target = DATA / "daily_content.json"
    current = json.loads(target.read_text(encoding="utf-8"))
    characters = [item for item in current if item["type"] == "character"]
    verses = translated_poetry_cards()
    idiom_count, word_count = build_idiom_index()
    cards = [*characters, *verses]
    if len({card["id"] for card in cards}) != len(cards):
        raise ValueError("Duplicate daily card ID")
    lines = [
        json.dumps(card, ensure_ascii=False, separators=(",", ":"))
        for card in cards
    ]
    target.write_text(
        "[\n" + ",\n".join("  " + line for line in lines) + "\n]\n",
        encoding="utf-8",
    )
    print(
        f"Daily catalog: {len(characters)} characters, {len(verses)} translated poems, "
        f"{word_count} words, {idiom_count} idioms"
    )


if __name__ == "__main__":
    main()
