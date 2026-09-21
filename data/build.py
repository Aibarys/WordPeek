"""Merge the word-part files into words.json and validate every entry.

Run:  python data/build.py
"""
import json, glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REQUIRED = ("id", "word", "ipa", "pos", "level", "ru", "def_en", "note_ru",
            "example", "example_ru", "topic")
LEVELS = ("A2", "B1", "B2", "C1")

CYRILLIC = re.compile("[Ѐ-ӿ]")

# Every character an entry may legitimately contain. Written as escapes rather
# than literals: the ranges include combining marks and invisible punctuation,
# which are impossible to review — or to edit safely — as raw characters.
#
# Anything outside this set is a slip of generation. Such a character survives
# proofreading precisely because it sits inside otherwise-correct text: a CJK
# character glued to the front of a Russian word reads as a rendering artefact,
# not as a typo.
ALLOWED = re.compile(
    "^["
    " -~"      # ASCII printable
    " -ɏ"      # Latin-1 supplement, Latin Extended-A and B
    "ɐ-˿"      # IPA extensions, spacing modifiers (ˈ ˌ ə ʃ ʒ)
    "̀-ͯ"      # combining diacritics
    "βθχγ"  # Greek letters the IPA borrows (β θ χ γ)
    "Ѐ-ӿ"      # Cyrillic
    "‐-›"      # dashes, quotation marks, ellipsis
    "₠-₿"      # currency symbols
    "]*$"
)


def load_parts():
    words, seen_id, seen_word = [], {}, {}
    errors = []
    for path in sorted(glob.glob(os.path.join(HERE, "_part_*.json"))):
        part = os.path.basename(path)
        for entry in json.load(open(path, encoding="utf-8")):
            wid = entry.get("id", "?")
            for field in REQUIRED:
                if not entry.get(field):
                    errors.append(f"{part}:{wid} - empty field '{field}'")
            if entry.get("level") not in LEVELS:
                errors.append(f"{part}:{wid} - bad level {entry.get('level')!r}")
            # The headword and the English fields must not contain Cyrillic.
            for field in ("word", "def_en", "example"):
                if CYRILLIC.search(entry.get(field, "")):
                    errors.append(f"{part}:{wid} - Cyrillic in English field '{field}'")
            # The Russian fields must contain Cyrillic.
            for field in ("ru", "note_ru", "example_ru"):
                if not CYRILLIC.search(entry.get(field, "")):
                    errors.append(f"{part}:{wid} - no Cyrillic in Russian field '{field}'")
            # No field may contain characters from an unexpected script.
            for field in REQUIRED:
                value = entry.get(field, "")
                if isinstance(value, str) and not ALLOWED.match(value):
                    stray = sorted({c for c in value if not ALLOWED.match(c)})
                    names = " ".join(f"U+{ord(c):04X}" for c in stray)
                    errors.append(f"{part}:{wid} - stray character(s) {names} in '{field}'")
            # Every entry carries 1-2 extra examples beyond the primary one,
            # validated with the same script rules as the primary pair.
            extras = entry.get("examples_extra")
            if not isinstance(extras, list) or not 1 <= len(extras) <= 2:
                errors.append(f"{part}:{wid} - examples_extra must hold 1-2 items")
            else:
                for n, pair in enumerate(extras):
                    en, ru = pair.get("en", ""), pair.get("ru", "")
                    if not en or not ru:
                        errors.append(f"{part}:{wid} - examples_extra[{n}] has an empty side")
                    if CYRILLIC.search(en):
                        errors.append(f"{part}:{wid} - Cyrillic in examples_extra[{n}].en")
                    if not CYRILLIC.search(ru):
                        errors.append(f"{part}:{wid} - no Cyrillic in examples_extra[{n}].ru")
                    for side, value in (("en", en), ("ru", ru)):
                        if not ALLOWED.match(value):
                            stray = sorted({c for c in value if not ALLOWED.match(c)})
                            names = " ".join(f"U+{ord(c):04X}" for c in stray)
                            errors.append(f"{part}:{wid} - stray character(s) {names} in examples_extra[{n}].{side}")
            if wid in seen_id:
                errors.append(f"{part}:{wid} - duplicate id, first seen in {seen_id[wid]}")
            seen_id[wid] = part
            key = entry.get("word", "").lower()
            if key in seen_word:
                errors.append(f"{part}:{wid} - duplicate headword {key!r}, first seen in {seen_word[key]}")
            seen_word[key] = part
            words.append(entry)
    return words, errors


def main():
    # The Windows console defaults to a codepage that cannot print IPA, and a
    # UnicodeEncodeError while reporting an error would hide the error itself.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    words, errors = load_parts()
    if errors:
        print(f"FAILED - {len(errors)} problem(s):")
        for e in errors:
            print("  -", e)
        return 1

    words.sort(key=lambda w: (LEVELS.index(w["level"]), w["id"]))
    out = {
        "version": 1,
        "sourceLanguage": "en",
        "targetLanguage": "ru",
        "count": len(words),
        "words": words,
    }
    dest = os.path.join(HERE, "words.json")
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write("\n")

    by_level = {lvl: sum(1 for w in words if w["level"] == lvl) for lvl in LEVELS}
    print(f"OK - {len(words)} words -> {dest}")
    print("   by level:", ", ".join(f"{k}={v}" for k, v in by_level.items()))
    print(f"   size: {os.path.getsize(dest)/1024:.1f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
