"""Save annotated item URLs from one CNGWZJ collection page."""

import argparse
from pathlib import Path
from urllib.parse import urljoin

from collect_cngwzj_shijing import Links, fetch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    links = Links()
    links.feed(fetch(args.url))
    urls = list(dict.fromkeys(urljoin("https://www.cngwzj.com", href).replace("m.cngwzj.com", "www.cngwzj.com") for href in links.hrefs))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(urls) + "\n", encoding="utf-8")
    print(f"{len(urls)}\t{args.output}")


if __name__ == "__main__":
    main()
