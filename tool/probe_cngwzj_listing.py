import re
import urllib.request

u = "https://www.cngwzj.com/pygushi/"
with urllib.request.urlopen(u, timeout=20) as response:
    page = response.read().decode("utf-8", "replace")
print("length", len(page))
for line in page.splitlines():
    if "pygushi" in line or "下一页" in line or "总页" in line or "页码" in line:
        print(line[:1000])
