import re
import urllib.request
from html.parser import HTMLParser


class Anchors(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.href = None
        self.text = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.href = dict(attrs).get("href")
            self.text = []

    def handle_data(self, data):
        if self.href:
            self.text.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self.href:
            self.links.append((self.href, "".join(self.text).strip()))
            self.href = None


def main():
    page = open("tool/source_cache/homepage_full.html", encoding="utf-8").read()
    collections = list(dict.fromkeys(re.findall(r"https://www\.cngwzj\.com/tangshi300/\d+\.html", page)))
    for url in collections:
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            html = urllib.request.urlopen(request, timeout=10).read().decode("utf-8", "replace")
            parser = Anchors()
            parser.feed(html)
            title = re.search(r"<title>(.*?)</title>", html, re.S)
            title = re.sub(r"<[^>]+>", "", title.group(1)).strip() if title else ""
            relevant = [(href, text) for href, text in parser.links if "/pygushi/" in href]
            if any(term in title for term in ("礼记", "孟子", "荀子", "墨子", "韩非", "诗经", "战国策", "尚书")):
                print(f"COLLECTION\t{title}\t{url}\t{len(relevant)}")
                for href, text in relevant:
                    print(f"ITEM\t{href.replace('m.cngwzj.com', 'www.cngwzj.com')}\t{text}")
        except Exception as exc:
            print(f"ERROR\t{url}\t{exc}")


if __name__ == "__main__":
    main()
