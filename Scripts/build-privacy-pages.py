#!/usr/bin/env python3
"""
Baut die Datenschutzseiten für GitHub Pages.

    python3 Scripts/build-privacy-pages.py

Liest `store/privacy/privacy-policy-{de,en,it}.md`, wirft den internen Kopf über
der Linie weg und schreibt eigenständige HTML-Seiten nach `docs/privacy/`.

## Warum ein Skript und nicht drei HTML-Dateien

Weil eine Datenschutzerklärung zum veröffentlichten Verhalten passen muss. Der
Text lebt in einer Datei, die sich vergleichen lässt; die Seite wird daraus
erzeugt. Wer den Text ändert und die Seite vergisst, hat eine Erklärung
veröffentlicht, die nicht mehr stimmt.

## Der Riegel

Das Skript **bricht ab**, solange im Text noch `<<…>>` steht. Diese Marken sind
die Stellen, die vor dem Veröffentlichen auszufüllen sind — Name und Mailadresse
des Verantwortlichen. Eine Datenschutzerklärung mit einer Lücke an der Stelle, an
der steht, wer verantwortlich ist, wäre schlimmer als keine.
"""

import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).parent.parent
SOURCE = ROOT / "store" / "privacy"
TARGET = ROOT / "docs" / "privacy"

LANGUAGES = {
    "de": ("Deutsch", "Datenschutzerklärung"),
    "en": ("English", "Privacy policy"),
    "it": ("Italiano", "Informativa sulla privacy"),
}

STYLE = """
:root { color-scheme: light dark; }
body {
  font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  max-width: 42rem; margin: 0 auto; padding: 2rem 1.25rem 5rem;
  color: #1c1c1e; background: #fbfcff;
}
@media (prefers-color-scheme: dark) {
  body { color: #e2e2e6; background: #0a1420; }
  a { color: #a1c9ff; }
  nav { border-color: #414b57; }
  code { background: #16202c; }
}
h1 { font-size: 1.6rem; margin: 0 0 .25rem; }
h2 { font-size: 1.2rem; margin: 2rem 0 .5rem; }
h3 { font-size: 1rem; margin: 1.5rem 0 .4rem; }
a { color: #0b5cb0; }
nav { margin: 0 0 2rem; padding-bottom: 1rem; border-bottom: 1px solid #c4c8d0; font-size: .9rem; }
nav a { margin-right: .75rem; }
nav strong { margin-right: .75rem; }
ul { padding-left: 1.2rem; }
li { margin: .3rem 0; }
code { background: #edf0f7; padding: .1em .35em; border-radius: 4px; font-size: .9em; }
footer { margin-top: 3rem; font-size: .85rem; opacity: .7; }
"""


def body_of(markdown: str) -> str:
    """Alles unterhalb der ersten waagerechten Linie — der Kopf ist intern."""
    parts = markdown.split("\n---\n", 1)
    if len(parts) != 2:
        raise SystemExit("Kein '---' gefunden; der interne Kopf ist nicht abgetrennt.")
    return parts[1].strip()


def inline(text: str) -> str:
    """Fett, Code und Links. Absichtlich nur das — mehr steht im Text nicht."""
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    text = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)
    return text


def to_html(markdown: str) -> str:
    """Ein kleiner Wandler für genau die Zeichen, die in diesen Texten vorkommen."""
    out: list[str] = []
    in_list = False

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for line in markdown.split("\n"):
        stripped = line.strip()
        if not stripped:
            close_list()
            continue
        if stripped.startswith("### "):
            close_list()
            out.append(f"<h3>{inline(stripped[4:])}</h3>")
        elif stripped.startswith("## "):
            close_list()
            out.append(f"<h2>{inline(stripped[3:])}</h2>")
        elif stripped.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(stripped[2:])}</li>")
        elif in_list:
            # Fortsetzungszeile eines Listenpunkts.
            out[-1] = out[-1][:-len("</li>")] + " " + inline(stripped) + "</li>"
        elif out and out[-1].startswith("<p>") and out[-1].endswith("</p>"):
            out[-1] = out[-1][:-len("</p>")] + " " + inline(stripped) + "</p>"
        else:
            out.append(f"<p>{inline(stripped)}</p>")

    close_list()
    return "\n".join(out)


def page(lang: str, title: str, content: str) -> str:
    others = "".join(
        f'<strong>{name}</strong>' if code == lang
        else f'<a href="{code}.html">{name}</a>'
        for code, (name, _) in LANGUAGES.items()
    )
    return f"""<!DOCTYPE html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index, follow">
<title>IDReader — {html.escape(title)}</title>
<style>{STYLE}</style>
</head>
<body>
<nav>{others}</nav>
{content}
<footer>IDReader für iOS · <a href="https://github.com/stevansen/IDReaderiOS">Quelltext</a></footer>
</body>
</html>
"""


def main() -> None:
    TARGET.mkdir(parents=True, exist_ok=True)

    for lang, (name, title) in LANGUAGES.items():
        source = SOURCE / f"privacy-policy-{lang}.md"
        if not source.exists():
            raise SystemExit(f"FEHLT: {source}")

        markdown = source.read_text(encoding="utf-8")
        # Nur im zu veroeffentlichenden Teil suchen. Der interne Kopf erwaehnt die
        # Marken absichtlich und darf deshalb nicht selbst den Riegel auslösen.
        publishable = body_of(markdown)
        if "<<" in publishable:
            holes = sorted(set(re.findall(r"<<[^>]*>>", publishable)))
            print(f"ABBRUCH: {source.name} enthält noch Platzhalter: {', '.join(holes)}")
            print()
            print("Diese Stellen sind vor dem Veröffentlichen auszufüllen. Eine")
            print("Datenschutzerklärung mit einer Lücke an der Stelle, an der steht,")
            print("wer verantwortlich ist, wäre schlimmer als keine.")
            sys.exit(1)

        (TARGET / f"{lang}.html").write_text(
            page(lang, title, to_html(publishable)), encoding="utf-8"
        )
        print(f"geschrieben: docs/privacy/{lang}.html ({name})")

    # Die deutsche Fassung ist die Vorgabe; die Sprachwahl steht auf jeder Seite.
    (TARGET / "index.html").write_text(
        '<!DOCTYPE html><meta charset="utf-8">'
        '<meta http-equiv="refresh" content="0; url=de.html">'
        '<title>IDReader — Datenschutz</title>'
        '<a href="de.html">Datenschutzerklärung</a>\n',
        encoding="utf-8",
    )
    # Ohne diese Datei schiebt GitHub Pages alles durch Jekyll.
    (TARGET.parent / ".nojekyll").write_text("", encoding="utf-8")
    print("geschrieben: docs/privacy/index.html, docs/.nojekyll")


if __name__ == "__main__":
    main()
