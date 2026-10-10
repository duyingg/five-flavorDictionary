"""Apply independently checked omissions to the packaged classic passages.

Only exact, unique anchors are accepted. Re-running the script is safe.
The same correction manifest is consumed by import_culture.dart on regeneration.
"""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tool/classic_text_corrections_20261002.json"
PASSAGES = ROOT / "assets/data/culture_passages"


def main() -> None:
    corrections = json.loads(MANIFEST.read_text(encoding="utf-8"))
    changes = 0
    for book in sorted({entry["book"] for entry in corrections}):
        path = PASSAGES / f"classic-{book}.json"
        passages = json.loads(path.read_text(encoding="utf-8"))
        for correction in (item for item in corrections if item["book"] == book):
            if "replace" in correction:
                rule = correction["replace"]
                count = sum(item["original"].count(rule["from"]) for item in passages)
                if count == 0:
                    continue
                if count != rule["count"]:
                    raise ValueError(f"{book}: expected {rule['count']} typo occurrences, got {count}")
                for item in passages:
                    item["original"] = item["original"].replace(rule["from"], rule["to"])
                changes += count
                continue
            indices = [i for i, item in enumerate(passages)
                       if item["original"] == correction["anchor"]]
            if len(indices) != 1:
                raise ValueError(f"{book}: anchor found {len(indices)} times: {correction['anchor']}")
            index = indices[0]
            inserts = correction["insert"]
            found = [item["original"] for item in passages[index + 1:index + 1 + len(inserts)]]
            if found == inserts:
                continue
            if any(text in (item["original"] for item in passages) for text in inserts):
                raise ValueError(f"{book}: partial or misplaced correction at {index}")
            new_rows = [{"heading": "", "original": text, "translation": ""}
                        for text in inserts]
            if correction.get("moveHeadingFromNext"):
                heading = passages[index + 1]["heading"]
                if not heading:
                    raise ValueError(f"{book}: missing chapter heading after {index}")
                new_rows[0]["heading"] = heading
                passages[index + 1]["heading"] = ""
            passages[index + 1:index + 1] = new_rows
            changes += len(new_rows)
        path.write_text(json.dumps(passages, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Inserted {changes} verified passages")


if __name__ == "__main__":
    main()
