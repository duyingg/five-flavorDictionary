"""Export the currently bundled reading corpus for human translation/review.

Uses only the Python standard library. Does not modify application resources.
"""

import argparse
import hashlib
import json
import mmap
import re
import struct
import zipfile
from collections import Counter
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_string(data, cursor, end):
    if cursor + 4 > end:
        raise ValueError("Truncated string length")
    length = struct.unpack_from("<I", data, cursor)[0]
    cursor += 4
    if cursor + length > end:
        raise ValueError("Truncated string")
    return data[cursor:cursor + length].decode("utf-8"), cursor + length


def poetry_records(path, subset):
    with path.open("rb") as stream, mmap.mmap(
        stream.fileno(), 0, access=mmap.ACCESS_READ
    ) as data:
        if data[:8] != b"WUWEIPO2" or subset[:8] != b"WUWESUB1":
            raise ValueError("Unsupported corpus format")
        count, shared_count = struct.unpack_from("<II", data, 8)
        total, selected = struct.unpack_from("<II", subset, 8)
        if count != total or len(subset) != 16 + (total + 7) // 8:
            raise ValueError("Standard membership index disagrees with full corpus")
        cursor = 16
        shared = []
        for _ in range(shared_count):
            text, cursor = read_string(data, cursor, len(data))
            shared.append(text)
        offsets_at = cursor
        cursor += 4 * (count + 1)
        if struct.unpack_from("<I", data, cursor)[0] != count:
            raise ValueError("Invalid ordering index")
        order_at = cursor + 4
        records_at = order_at + 4 * count
        if records_at + struct.unpack_from("<I", data, offsets_at + 4 * count)[0] != len(data):
            raise ValueError("Record boundary disagrees with source size")
        seen = bytearray(count)
        standard_count = 0
        for ordinal in range(count):
            index = struct.unpack_from("<I", data, order_at + 4 * ordinal)[0]
            if index >= count or seen[index]:
                raise ValueError("Ordering index is not a permutation")
            seen[index] = 1
            start, end = struct.unpack_from("<II", data, offsets_at + 4 * index)
            start += records_at
            end += records_at
            if start + 40 > end:
                raise ValueError("Invalid record bounds")
            fields = struct.unpack_from("<10I", data, start)
            cursor = start + 40
            strings = []
            for _ in range(7):
                text, cursor = read_string(data, cursor, end)
                strings.append(text)
            if cursor != end:
                raise ValueError("Unconsumed record bytes")
            standard = bool(subset[16 + (index >> 3)] & (1 << (index & 7)))
            standard_count += standard
            source = dict(zip(
                ("id", "title", "searchText", "content", "notes", "translation", "appreciation"),
                strings,
            ))
            source.update(sequence=fields[0], shuffleKey=fields[1])
            source.update({key: shared[fields[position]] for position, key in enumerate(
                ("author", "normalizedAuthor", "dynasty", "form", "style", "theme", "emotion", "sourceId"), 2
            )})
            yield source, index, standard
        if standard_count != selected:
            raise ValueError("Standard membership count disagrees with source index")


def task(kind, source, original, key, **metadata):
    return {
        "recordKey": key,
        "kind": kind,
        "originalSha256": hashlib.sha256(original.encode("utf-8")).hexdigest(),
        **metadata,
        "source": source,
        "revision": {
            "translation": "", "notes": "", "appreciation": "",
            "alignment": [], "reviewer": "", "status": "",
        },
    }


def fenced(text):
    longest = max((len(match[0]) for match in re.finditer(r"`+", text)), default=0)
    fence = "`" * max(3, longest + 1)
    return f"{fence}text\n{text}\n{fence}\n"


def markdown_record(record):
    source = record["source"]
    title = source.get("title", source.get("heading", "")) or "无题 / 无段落标题"
    original = source.get("original", source.get("content", ""))
    heading = title.replace("\n", " ")
    result = [f"## {heading}\n\n", f"- 回填编号：`{record['recordKey']}`\n",
              f"- 原文校验：`{record['originalSha256']}`\n"]
    for key, label in (("dynasty", "朝代"), ("author", "作者"), ("sourceId", "来源")):
        if source.get(key):
            result.append(f"- {label}：{source[key]}\n")
    if "passageNumber" in record:
        result.append(f"- 典籍：{record['bookTitle']}；原始段号：{record['passageNumber']}\n")
    result.append("\n### 原文（保持原样）\n\n" + fenced(original))
    for key, label in (("translation", "现有译文"), ("notes", "现有注释"), ("appreciation", "现有赏析")):
        if source.get(key, "").strip():
            result.append(f"\n### {label}（供校对）\n\n" + fenced(source[key]))
    result.append("\n### 修订译文\n\n<!-- 在此填写新译文，保留原文段落和换行 -->\n"
                  "\n### 修订注释\n\n<!-- 在此填写注释 -->\n"
                  "\n### 修订赏析\n\n<!-- 在此填写赏析；可留空 -->\n"
                  "\n### 逐句对应（可选）\n\n<!-- 逐条填写：原文句段 → 译文；不要按行数猜测对应关系 -->\n"
                  "\n### 译者与校对状态\n\n<!-- 译者姓名；待翻译 / 待校对 / 已校对 -->\n\n---\n\n")
    return "".join(result)


class Bundle:
    def __init__(self, archive):
        self.archive = archive
        self.files = []

    def write(self, name, data, records=None):
        encoded = data.encode("utf-8")
        self.archive.writestr(name, encoded)
        self.files.append({"path": name, "bytes": len(encoded),
                           "sha256": hashlib.sha256(encoded).hexdigest(),
                           **({"records": records} if records is not None else {})})

    def batch(self, folder, number, records):
        stem = f"{folder}/分册_{number:04d}"
        self.write(stem + ".jsonl", "".join(
            json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n"
            for record in records
        ), len(records))
        self.write(stem + ".md", "# 翻译与校对分册\n\n" + "".join(
            markdown_record(record) for record in records
        ), len(records))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", default=date.today().isoformat())
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    destination = args.output or ROOT / "导出" / f"诗词典籍翻译包_{args.date}.zip"
    destination = destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise FileExistsError(f"Export already exists: {destination}")
    # A partially written package is never exposed as the final deliverable.
    partial = destination.with_suffix(".zip.partial")
    if partial.exists():
        raise FileExistsError(f"Partial export already exists: {partial}")
    catalog_path = DATA / "culture_items_v2.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    subset_path = DATA / "poetry_standard_index.wvi"
    subset = subset_path.read_bytes()
    sources = [DATA / "poetry_items_full.wvp", subset_path, catalog_path]
    totals = Counter()
    books = []
    poem_ids = set()
    with zipfile.ZipFile(partial, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        bundle = Bundle(archive)
        buffer = []
        batch = 1
        for source, index, standard in poetry_records(sources[0], subset):
            if source["id"] in poem_ids:
                raise ValueError(f"Duplicate poem ID: {source['id']}")
            poem_ids.add(source["id"])
            totals["poetry"] += 1
            totals["standardPoetry"] += standard
            totals["poetryWithTranslation"] += bool(source["translation"].strip())
            totals["poetryWithNotes"] += bool(source["notes"].strip())
            totals["poetryWithAppreciation"] += bool(source["appreciation"].strip())
            buffer.append(task("poetry", source, source["content"], f"poetry/{source['id']}",
                               physicalRecordIndex=index, inStandardLibrary=standard))
            if len(buffer) == 500:
                bundle.batch("诗词", batch, buffer)
                buffer.clear()
                batch += 1
            if totals["poetry"] % 20000 == 0:
                print(f"poetry exported: {totals['poetry']}", flush=True)
        if buffer:
            bundle.batch("诗词", batch, buffer)
        culture_tasks = []
        for item in catalog:
            if not item.get("passagesAsset"):
                culture_tasks.append(task("culture", item, item.get("content", ""), f"culture/{item['id']}"))
                continue
            source_path = (ROOT / item["passagesAsset"]).resolve()
            source_path.relative_to(DATA.resolve())
            sources.append(source_path)
            passages = json.loads(source_path.read_text(encoding="utf-8"))
            records = []
            for index, passage in enumerate(passages, 1):
                records.append(task("classicPassage", passage, passage["original"],
                                    f"classic/{item['id']}/{index:06d}",
                                    bookId=item["id"], bookTitle=item["title"], passageNumber=index))
                totals["classicPassages"] += 1
                totals["classicPassagesWithTranslation"] += bool(passage.get("translation", "").strip())
            for offset in range(0, len(records), 200):
                bundle.batch(f"典籍/{item['id']}", offset // 200 + 1, records[offset:offset + 200])
            books.append({"id": item["id"], "title": item["title"], "passages": len(records),
                          "source": item["passagesAsset"]})
        bundle.batch("文化文章", 1, culture_tasks)
        totals["cultureArticles"] = len(culture_tasks)
        totals["cultureCatalogEntries"] = len(catalog)
        totals["classicBooks"] = len(books)
        bundle.write("原始文化目录.json", json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
        readme = f"""# 五味字典：诗词、典籍与文化文章翻译包

导出日期：{args.date}。本包直接读取当前应用资源，未做简繁转换、纠错、合并或删改原文。

## 收录范围

- 全量诗词 {totals['poetry']:,} 首/篇；包括标准库 {totals['standardPoetry']:,} 首/篇，标准库是全量库的子集，不重复导出。
- 其中已有译文 {totals['poetryWithTranslation']:,} 条、注释 {totals['poetryWithNotes']:,} 条、赏析 {totals['poetryWithAppreciation']:,} 条；现有内容供校对，不代表已经审核正确。
- 当前典籍 {len(books)} 部、原始段落 {totals['classicPassages']:,} 段；现有译文 {totals['classicPassagesWithTranslation']:,} 段。
- 其他文化文章/条目 {len(culture_tasks)} 项；完整文化目录 {len(catalog)} 项另附。
- 不包含已从应用目录移除的典籍、未打包的旧诗词库、字词字典释义及用户个人收藏/查询记录。每日诗句来自同一诗词库，未重复作为作品导出。

## 给译者

每个分册同时提供 `.md` 和 `.jsonl`：直接编辑 Markdown 的“修订译文 / 修订注释 / 修订赏析”即可；愿意处理结构化数据时可编辑 JSONL 的 `revision`。每个 JSONL 物理行是一条完整记录，正文换行使用 JSON 转义，读取后恢复。

1. 按分册分配任务，保留“回填编号”和原文校验值；不要修改原文。诗词每册至多 500 条，典籍每册至多 200 段。
2. 已有译文、注释、赏析位于“现有…”区和 `source`，请将修订结果写入新区，不要覆盖原始资料。
3. 尽量保持原文自然句段的分段；若多句共用一段译文，请明确列出对应原文。不要把“原文行数相同”当作语义对应。
4. 可填写 JSONL 的 `revision.alignment`，例如 `[{{"original":"原文句段","translation":"对应译文","notes":"可选注释"}}]`；整篇赏析可留在 `revision.appreciation`。
5. 空白修订字段表示“未填写”，不表示要求删除现有资料。请填写译者和校对状态，返回修改过的分册即可。

## 给回填人员

诗词以 `source.id` 定位；典籍以 `bookId` 和从 1 开始的原始 `passageNumber` 定位。段号严格来自资源文件，未套用界面的段落合并。`recordKey` 全包唯一；`originalSha256` 是原文 UTF-8 字节的 SHA-256，用于确认回填时原文没有变化。

原始文化目录保留典籍整体注释、赏析及其他元数据。`manifest.json` 记录源文件、源文件 SHA-256、分册数量和内容校验；统计按作品或段落计，不按句数。包内不是自动导入程序，回填时需核对编号和原文校验，再合并修订字段。

## 典籍目录

"""
        readme += "\n".join(f"- {book['title']}（{book['id']}）：{book['passages']:,} 段" for book in books) + "\n"
        bundle.write("请先阅读.md", readme)
        manifest = {"schemaVersion": 1, "exportDate": args.date, "counts": dict(totals),
                    "books": books, "sources": [{"path": path.relative_to(ROOT).as_posix(),
                    "bytes": path.stat().st_size, "sha256": sha256(path)} for path in sources],
                    "files": bundle.files}
        archive.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8"))
    partial.replace(destination)
    digest = sha256(destination)
    destination.with_suffix(".zip.sha256").write_text(f"{digest}  {destination.name}\n", encoding="utf-8")
    print(json.dumps({"output": str(destination), "bytes": destination.stat().st_size,
                      "sha256": digest, "counts": dict(totals)}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
