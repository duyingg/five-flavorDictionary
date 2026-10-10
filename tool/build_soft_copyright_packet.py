"""Build the reproducible source and manual PDFs for the local application."""

from __future__ import annotations

import hashlib
import math
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output/pdf/wuwei_software_copyright_20261002"
FONT = "NotoSC"
FONT_PATH = Path("C:/Windows/Fonts/NotoSansSC-Regular.ttf")
TITLE = "五味字典软件 V1.1.0"


def setup() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(TTFont(FONT, str(FONT_PATH)))


def source_files() -> list[Path]:
    main = ROOT / "lib/main.dart"
    return [main] + [path for path in sorted((ROOT / "lib").rglob("*.dart"))
                     if path != main]


def code_font(char: str) -> str:
    return FONT if ord(char) > 127 else "Courier"


def wrapped_code(value: str, max_width: float, size: float) -> list[str]:
    value = value.expandtabs(2)
    if not value:
        return [""]
    out, part, width = [], "", 0.0
    for char in value:
        char_width = pdfmetrics.stringWidth(char, code_font(char), size)
        if part and width + char_width > max_width:
            out.append(part)
            part, width = "", 0.0
        part += char
        width += char_width
    out.append(part)
    return out


def draw_mixed(c: canvas.Canvas, x: float, y: float, value: str, size: float) -> None:
    run, font, xpos = "", None, x
    for char in value + "\0":
        next_font = code_font(char) if char != "\0" else None
        if run and next_font != font:
            c.setFont(font, size)
            c.drawString(xpos, y, run)
            xpos += pdfmetrics.stringWidth(run, font, size)
            run = ""
        if char != "\0":
            run += char
            font = next_font


def source_rows() -> tuple[list[tuple[str, int, str]], list[tuple[str, int, str]]]:
    rows = []
    manifest = []
    for path in source_files():
        raw = path.read_bytes()
        lines = raw.decode("utf-8-sig").splitlines()
        relative = path.relative_to(ROOT).as_posix()
        manifest.append((relative, len(lines), hashlib.sha256(raw).hexdigest()))
        rows.extend((relative, number, value) for number, value in enumerate(lines, 1))
    return rows, manifest


def paginate_source(rows: list[tuple[str, int, str]]) -> list[list[tuple[str, int, str]]]:
    pages, page, nonblank = [], [], 0
    for row in rows:
        page.append(row)
        nonblank += bool(row[2].strip())
        if nonblank == 50:
            pages.append(page)
            page, nonblank = [], 0
    if page:
        pages.append(page)
    return pages


def render_source(rows: list[tuple[str, int, str]], manifest: list[tuple[str, int, str]]) -> None:
    all_pages = paginate_source(rows)
    if len(all_pages) <= 60:
        selected = list(enumerate(all_pages, 1))
    else:
        selected = list(enumerate(all_pages[:30], 1)) + list(
            enumerate(all_pages[-30:], len(all_pages) - 29)
        )
    path = OUT / "02_源程序鉴别材料_前后各30页.pdf"
    c = canvas.Canvas(str(path), pagesize=A4, pageCompression=1)
    c.setTitle(f"{TITLE} 源程序鉴别材料")
    page_width, page_height = A4
    for output_index, (original_index, page) in enumerate(selected, 1):
        c.setFont(FONT, 10)
        c.drawString(34, page_height - 31, f"{TITLE} · 源程序鉴别材料")
        c.setFont(FONT, 7.2)
        c.drawRightString(page_width - 34, page_height - 31,
                          f"第 {output_index}/60 页")
        c.setStrokeColor(colors.HexColor("#999999"))
        c.line(34, page_height - 39, page_width - 34, page_height - 39)
        label = "前连续30页" if output_index <= 30 else "后连续30页"
        c.setFont(FONT, 7)
        c.drawString(34, page_height - 53,
                     f"{label}  |  全量源码页序 {original_index}/{len(all_pages)}")

        visual = []
        last_file = None
        for relative, line_number, code in page:
            if relative != last_file:
                visual.append(("file", relative, 0, ""))
                last_file = relative
            parts = wrapped_code(code, page_width - 95, 8.2)
            for part_index, part in enumerate(parts):
                visual.append(("code", relative, line_number if part_index == 0 else 0, part))
        max_rows = math.floor((page_height - 62 - 44) / 11.1)
        if len(visual) > max_rows:
            raise RuntimeError(f"Source page {output_index} overflows: {len(visual)} > {max_rows}")
        y = page_height - 66
        for kind, relative, line_number, value in visual:
            if kind == "file":
                c.setFillColor(colors.HexColor("#eeeeee"))
                c.rect(34, y - 2, page_width - 68, 11.1, fill=1, stroke=0)
                c.setFillColor(colors.black)
                c.setFont(FONT, 7.5)
                c.drawString(38, y, relative)
            else:
                if line_number:
                    c.setFillColor(colors.HexColor("#555555"))
                    c.setFont("Courier", 7.5)
                    c.drawRightString(69, y, str(line_number))
                c.setFillColor(colors.black)
                draw_mixed(c, 76, y, value, 8.2)
            y -= 11.1
        c.setFont(FONT, 7)
        c.setFillColor(colors.HexColor("#555555"))
        c.drawString(34, 27, "仅项目 lib/ 下的应用 Dart 源码；不含第三方依赖与数据资源")
        c.drawRightString(page_width - 34, 27, f"{output_index}")
        c.showPage()
    c.save()

    total_lines = sum(item[1] for item in manifest)
    nonblank_lines = sum(bool(row[2].strip()) for row in rows)
    lines = [
        "# 源程序取样与文件清单",
        "",
        f"软件：{TITLE}。本地源码文件数：{len(manifest)}；非空源码行数：{nonblank_lines:,}；物理源代码行数（含空行）：{total_lines:,}。",
        f"按以下顺序串联为一份源程序，共 {len(all_pages)} 页；每页至多延续到第 50 条非空源代码行，空行与原文件顺序均保留。PDF 抽取前 30 页、后 30 页，中间页不交存。",
        "PDF 中的灰色文件路径行是定位标记，不计入源代码行数；左侧数字是原文件行号。",
        "当前源码来自未提交的工作区状态，文件 SHA-256 用于后续核对快照。",
        "",
        "| 顺序 | 文件 | 物理行数 | SHA-256 |",
        "|---:|---|---:|---|",
    ]
    for index, (relative, count, digest) in enumerate(manifest, 1):
        lines.append(f"| {index} | `{relative}` | {count} | `{digest}` |")
    (OUT / "02_源程序取样清单.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"source: files={len(manifest)} nonblank_lines={nonblank_lines} physical_lines={total_lines} pages={len(all_pages)} submitted={len(selected)}")


def wrap_manual(value: str, max_width: float, size: float) -> list[str]:
    if not value:
        return [""]
    lines, part = [], ""
    for char in value:
        if part and pdfmetrics.stringWidth(part + char, FONT, size) > max_width:
            lines.append(part)
            part = ""
        part += char
    if part:
        lines.append(part)
    return lines


def manual_lines(path: Path) -> list[tuple[str, str]]:
    result = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        kind = "heading" if raw.startswith("#") else "body"
        value = re.sub(r"^#+\s*", "", raw)
        value = value.replace("`", "")
        for part in wrap_manual(value, A4[0] - 78, 9.8):
            result.append((kind, part))
    return result


def render_manual() -> None:
    lines = manual_lines(OUT / "03_软件使用说明书.md")
    page_count = max(1, math.ceil(len(lines) / 40))
    while page_count > 1 and len(lines) / page_count < 30:
        page_count -= 1
    base, extra = divmod(len(lines), page_count)
    sizes = [base + (1 if i < extra else 0) for i in range(page_count)]
    if min(sizes) < 30:
        raise RuntimeError(f"Document has too few lines per page: {sizes}")
    if max(sizes) > 50:
        raise RuntimeError(f"Document pages too dense: {sizes}")
    path = OUT / "03_软件使用说明书.pdf"
    c = canvas.Canvas(str(path), pagesize=A4, pageCompression=1)
    c.setTitle(f"{TITLE} 使用说明书")
    width, height = A4
    position = 0
    for page_no, count in enumerate(sizes, 1):
        c.setFillColor(colors.black)
        c.setFont(FONT, 10)
        c.drawString(38, height - 32, f"{TITLE} · 使用说明书")
        c.setFont(FONT, 7.4)
        c.drawRightString(width - 38, height - 32, f"第 {page_no}/{page_count} 页")
        c.setStrokeColor(colors.HexColor("#999999"))
        c.line(38, height - 41, width - 38, height - 41)
        y = height - 65
        for kind, value in lines[position:position + count]:
            c.setFillColor(colors.black)
            c.setFont(FONT, 10.4 if kind == "heading" else 9.8)
            c.drawString(39, y, value)
            y -= 18.1
        if y < 44:
            raise RuntimeError(f"Manual page {page_no} overflows")
        c.setFont(FONT, 7.2)
        c.setFillColor(colors.HexColor("#555555"))
        c.drawString(39, 27, "著作权人：杜英吉  |  文档版本：V1.1.0")
        c.drawRightString(width - 39, 27, str(page_no))
        c.showPage()
        position += count
    c.save()
    print(f"manual: wrapped_lines={len(lines)} pages={page_count} lines_per_page={sizes}")


def main() -> None:
    setup()
    rows, manifest = source_rows()
    render_source(rows, manifest)
    render_manual()


if __name__ == "__main__":
    main()
