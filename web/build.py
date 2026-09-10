"""Inject data/words.json into web/template.html and write web/index.html.

Keeps the dictionary single-sourced: the iOS bundle and the web prototype are
built from the same file.

Run:  python web/build.py
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PLACEHOLDER = "/*__WORDS__*/"


def main():
    words_path = os.path.join(ROOT, "data", "words.json")
    if not os.path.exists(words_path):
        print("Run `python data/build.py` first — data/words.json is missing.")
        return 1

    with open(words_path, encoding="utf-8") as f:
        payload = json.load(f)

    template = open(os.path.join(HERE, "template.html"), encoding="utf-8").read()
    if PLACEHOLDER not in template:
        print(f"template.html no longer contains {PLACEHOLDER}")
        return 1

    # Separators without spaces keep the embedded payload compact; the page has
    # to carry the whole dictionary inline because it must work offline.
    compact = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    # `</script>` inside a string literal would end the script block early.
    compact = compact.replace("</", "<\\/")

    out = template.replace(PLACEHOLDER, compact)
    dest = os.path.join(HERE, "index.html")
    with open(dest, "w", encoding="utf-8") as f:
        f.write(out)

    print(f"OK — {payload['count']} words embedded -> {dest}")
    print(f"   size: {os.path.getsize(dest)/1024:.1f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
