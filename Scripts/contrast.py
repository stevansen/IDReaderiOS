#!/usr/bin/env python3
"""Rechnet die WCAG-Kontrastverhaeltnisse der sechs Paletten aus.

    python3 Scripts/contrast.py

Liest die Hexwerte direkt aus App/Support/AppTheme.swift. Kein zweiter Ort, an
dem Farben stehen - eine Tabelle, die man von Hand nachfuehrt, ist nach der
ersten Farbaenderung falsch und behauptet trotzdem weiter, alles sei geprueft.

Schwellen nach WCAG 2.1 AA: 4.5:1 fuer Text, 3:1 fuer grossen Text und fuer
Bedienelemente wie Rahmen.
"""
import re
import sys
import pathlib

SRC = pathlib.Path(__file__).resolve().parent.parent / "App/Support/AppTheme.swift"

PAIRS = [
    ("onSurface", "surface", "Fliesstext auf Flaeche", True),
    ("onSurfaceVariant", "surface", "Nebentext auf Flaeche", True),
    ("onBackground", "background", "Text auf Grund", True),
    ("primary", "surface", "Akzenttext auf Flaeche", True),
    ("onPrimary", "primary", "Knopfschrift", True),
    ("onPrimaryContainer", "primaryContainer", "Kopfzeile", True),
    ("onSecondaryContainer", "secondaryContainer", "getoenter Kasten", True),
    ("onTertiaryContainer", "tertiaryContainer", "Hinweiskasten", True),
    ("onErrorContainer", "errorContainer", "Fehlerkasten", True),
    ("error", "surface", "Fehlertext auf Flaeche", True),
    # Rahmen ist kein Text: fuer Bedienelemente gilt 3:1.
    ("outline", "surface", "Rahmen auf Flaeche", False),
]


def channel(value: int) -> float:
    c = value / 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hexval: str) -> float:
    r, g, b = (int(hexval[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def ratio(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def palettes(source: str) -> dict[str, dict[str, str]]:
    found = {}
    for match in re.finditer(
        r"static let (\w+) = DocumentPalette\((.*?)\n    \)", source, re.S
    ):
        fields = dict(
            re.findall(r"(\w+):\s*\.hex\(0x([0-9A-Fa-f]{6})\)", match.group(2))
        )
        if fields:
            found[match.group(1)] = fields
    return found


def main() -> int:
    found = palettes(SRC.read_text())
    if not found:
        print(f"FEHLER: keine Palette in {SRC} gefunden.")
        return 2

    problems = []
    for name in sorted(found):
        print(f"\n{name}")
        for foreground, background, what, is_text in PAIRS:
            if foreground not in found[name] or background not in found[name]:
                continue
            value = ratio(found[name][foreground], found[name][background])
            need = 4.5 if is_text else 3.0
            mark = "ok " if value >= need else "FEHLT"
            print(f"  {mark} {what:26} {value:6.2f} : 1   (verlangt {need})")
            if value < need:
                problems.append((name, what, value, need))

    print()
    if problems:
        print("Unterschritten:")
        for name, what, value, need in problems:
            print(f"  {name} / {what}: {value:.2f} statt {need}")
        return 1
    print(f"Alle Paare erfuellen ihre Schwelle ({len(found)} Paletten).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
