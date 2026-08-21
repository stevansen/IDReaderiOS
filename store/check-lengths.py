#!/usr/bin/env python3
"""
Prüft die Store-Texte gegen die Feldgrenzen von App Store Connect.

    python3 store/check-lengths.py

Der Grund für dieses Skript: die Grenzen sind hart, und App Store Connect
schneidet nicht ab, sondern lehnt ab. Wer einen Satz einfügt, soll das hier
merken und nicht im Formular.

Gezählt wird ohne den abschließenden Zeilenumbruch. App Store Connect zählt
gelegentlich etwas anders, deshalb warnt das Skript schon ab 95 Prozent.
"""

import pathlib
import sys

LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional-text.txt": 170,
    "description.txt": 4000,
    "whats-new.txt": 4000,
}

root = pathlib.Path(__file__).parent
failed = False

for locale in sorted(p for p in root.iterdir() if p.is_dir() and "-" in p.name or p.name == "it"):
    if not any(locale.glob("*.txt")):
        continue
    print(f"\n{locale.name}")
    for name, limit in LIMITS.items():
        path = locale / name
        if not path.exists():
            print(f"  {name:22} FEHLT")
            failed = True
            continue
        length = len(path.read_text(encoding="utf-8").rstrip("\n"))
        if length > limit:
            mark, note = "ZU LANG", f"um {length - limit}"
            failed = True
        elif length > limit * 0.95:
            mark, note = "knapp", f"{limit - length} übrig"
        else:
            mark, note = "ok", ""
        print(f"  {name:22} {length:5d} / {limit:5d}  {mark:8} {note}")

if failed:
    print("\nMindestens ein Feld passt nicht.")
    sys.exit(1)
print("\nAlle Felder passen.")
