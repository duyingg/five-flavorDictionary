"""Print page links to discover further annotated works and author indexes."""
import sys
from html.parser import HTMLParser
from urllib.parse import urljoin
from collect_cngwzj_shijing import fetch


class PageLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.href = None
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            self.href = dict(attrs).get('href')
            self.parts = []

    def handle_data(self, data):
        if self.href:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == 'a' and self.href:
            print(urljoin(sys.argv[1], self.href), ''.join(self.parts).strip(), sep='\t')
            self.href = None


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    parser = PageLinks()
    parser.feed(fetch(sys.argv[1]))
