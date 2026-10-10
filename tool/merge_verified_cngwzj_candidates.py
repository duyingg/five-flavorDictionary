"""Merge reviewed CNGWZJ snippets into the app's verified classic pinyin TSV."""

from pathlib import Path
import argparse

from audit_classic_pinyin import ASSETS

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATES = ROOT / "tool/cngwzj_reaudit_candidates.tsv"
DEFAULT_TARGET = ASSETS / "verified_classic_pinyin_20260929.tsv"


def load_rows(path):
    rows = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        text, pinyin = line.split("\t", 1)
        rows[text] = " ".join(pinyin.split())
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", type=Path, default=DEFAULT_CANDIDATES)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    args = parser.parse_args()
    existing = load_rows(args.target)
    candidates = load_rows(args.candidates)
    conflicts = {text for text, pinyin in candidates.items()
                 if text in existing and existing[text] != pinyin}
    additions = {text: pinyin for text, pinyin in candidates.items()
                 if text not in existing and text not in conflicts}
    if conflicts:
        for text in sorted(conflicts):
            print(f"CONFLICT\t{text}\t{existing[text]}\t{candidates[text]}")
    with args.target.open("a", encoding="utf-8", newline="\n") as output:
        for text, pinyin in additions.items():
            output.write(f"{text}\t{pinyin}\n")
    print(f"candidate_rows={len(candidates)} existing_rows={len(existing)} "
          f"added_rows={len(additions)} added_chars="
          f"{sum(len(text) for text in additions)} conflicts={len(conflicts)}")


if __name__ == "__main__":
    main()
