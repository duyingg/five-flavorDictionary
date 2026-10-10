"""Refresh audit figures in the pronunciation progress note."""

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "注音校准进度_2026-09-29.md"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--date', default='20260930', help='Audit filename date, YYYYMMDD')
    args = parser.parse_args()
    items = json.loads((ROOT / "assets/data/culture_items_v2.json").read_text(encoding="utf-8"))
    titles = {item["id"]: item["title"] for item in items if item["id"].startswith("classic-")}
    metrics = {}
    classic_path = ROOT / f'tool/audit_classic_pinyin_{args.date}_after.txt'
    if not classic_path.exists():
        classic_path = ROOT / f'tool/audit_classic_pinyin_{args.date}.txt'
    audit = classic_path.read_text(encoding="utf-8")
    for line in audit.splitlines():
        match = re.fullmatch(r"(classic-[^\t]+)\t(\d+)/(\d+)\t([\d.]+)%", line)
        if match:
            metrics[titles[match[1]]] = (int(match[2]), int(match[3]), match[4])
    if len(metrics) != 30:
        raise RuntimeError(f"Expected 30 classic metrics, got {len(metrics)}")

    text = DOC.read_text(encoding="utf-8")
    start = text.index("## 古籍可靠整句覆盖率")
    end = text.index("## 用户可优先协助寻找的版本", start)
    block = text[start:end]
    for title, (covered, total, percent) in metrics.items():
        pattern = r"(^\| " + re.escape(title) + r" \| )[^|]+( \| )[^|]+( \| [^\n]*$)"

        def replace(match):
            shown = percent + "%"
            if percent == "100.00":
                shown = "100%（仅摘录）" if title == "心经" else "100%（应用正文）"
            return match[1] + f"{covered:,}/{total:,}" + match[2] + shown + match[3]

        block, count = re.subn(pattern, replace, block, count=1, flags=re.M)
        if count != 1:
            raise RuntimeError(f"Missing table row: {title}")
    text = text[:start] + block + text[end:]

    poetry = (ROOT / f'tool/audit_poetry_full_{args.date}.txt').read_text(encoding="utf-8")
    standard = (ROOT / f'tool/audit_poetry_standard_{args.date}.txt').read_text(encoding="utf-8")
    for report, prefix in ((standard, "标准诗词库"), (poetry, "全量诗词库")):
        for line in report.splitlines():
            match = re.fullmatch(r"([^\t]+)\tpoems=(\d+)\t(\d+)/(\d+)\t([\d.]+)%", line)
            if not match:
                continue
            context = "+context_phrases" in match[1]
            suffix = "加上下文词组" if context else "逐篇注音"
            pattern = r"(^\| " + prefix + r"（" + f"{int(match[2]):,}" + r" 首），" + suffix + r" \| )[^|]+( \| )[^|]+( \|$)"
            replacement = match[3] + "/" + match[4] + match[5] + "%"
            text, count = re.subn(pattern, lambda m: m[1] + f"{int(match[3]):,}/{int(match[4]):,}" + m[2] + match[5] + "%" + m[3], text, count=1, flags=re.M)
            if count != 1:
                raise RuntimeError(f"Missing poetry row: {prefix} {suffix}")

    verified = ROOT / "assets/data/verified_classic_pinyin_20260929.tsv"
    rows = sum(1 for _ in verified.open(encoding="utf-8"))
    text, count = re.subn(r"当前可靠整句资源共 [\d,]+ 条，其中原有记录 4,140 条，补充资源文件 [\d,]+ 条", f"当前可靠整句资源共 {rows + 4140:,} 条，其中原有记录 4,140 条，补充资源文件 {rows:,} 条", text, count=1)
    if count != 1:
        raise RuntimeError("Missing resource summary")
    DOC.write_text(text, encoding="utf-8")
    print(f"Updated {len(metrics)} classic rows and poetry coverage; verified rows={rows}")


if __name__ == "__main__":
    main()
