"""Print local poetry records matching title fragments in a .wvp catalog."""

import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_string(data, position):
    length = struct.unpack_from("<I", data, position)[0]
    position += 4
    return data[position:position + length].decode("utf-8"), position + length


def records(path):
    data = path.read_bytes()
    if data[:8] != b"WUWEIPO2":
        raise ValueError("Invalid poetry catalog")
    count, shared_count = struct.unpack_from("<II", data, 8)
    position = 16
    shared = []
    for _ in range(shared_count):
        value, position = read_string(data, position)
        shared.append(value)
    offsets = struct.unpack_from(f"<{count + 1}I", data, position)
    position += 4 * (count + 1)
    ordered_count = struct.unpack_from("<I", data, position)[0]
    if ordered_count != count:
        raise ValueError("Invalid poetry index")
    position += 4 + 4 * count
    for index in range(count):
        start = position + offsets[index]
        fields = struct.unpack_from("<10I", data, start)
        cursor = start + 40
        strings = []
        for _ in range(7):
            value, cursor = read_string(data, cursor)
            strings.append(value)
        yield {
            "author": shared[fields[2]],
            "source": shared[fields[9]],
            "id": strings[0],
            "title": strings[1],
            "content": strings[3],
        }


def main():
    terms = sys.argv[1:]
    if not terms:
        raise SystemExit("Usage: python tool/inspect_poetry_catalog.py title-fragment ...")
    path = ROOT / "assets/data/poetry_items.wvp"
    for item in records(path):
        if any(term in item["title"] for term in terms):
            print(f"{item['id']}\t{item['title']}\t{item['author']}\t{item['source']}")
            print(item["content"][:500].replace("\n", "\\n"))


if __name__ == "__main__":
    main()
