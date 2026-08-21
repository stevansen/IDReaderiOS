# Welche Lizenz für diese App

Eine Empfehlung, keine Entscheidung. Entscheiden müssen sie **beide
Rechteinhaber gemeinsam** — [`../COPYRIGHT`](../COPYRIGHT) hält fest, warum, und
[`../LICENSE`](../LICENSE) sagt, dass niemand allein umstellen darf. Keine
Rechtsberatung.

## Der Stand heute

Der Quelltext ist **öffentlich**, aber nicht **offen**: das Repository ist
lesbar, `LICENSE` gewährt keine Rechte. Das ist ein gültiger Zustand mit einem
Namen — *source-available* —, und es ist der einzige, aus dem alle anderen noch
erreichbar sind. Eine erteilte Lizenz lässt sich nicht zurücknehmen; eine noch
nicht erteilte jederzeit erteilen. Wer unsicher ist, wartet richtig.

## Was die Wahl einschränkt

Vier Umstände, und drei davon schließen etwas aus:

1. **Der App Store.** Die GPL-Familie (GPL-2.0, GPL-3.0, AGPL) gilt weithin als
   unvereinbar mit Apples Nutzungsbedingungen: die FSF sieht darin zusätzliche
   Beschränkungen, die die GPL verbietet. Für eine App, die im Store liegen
   soll, fällt diese Familie damit praktisch aus — es sei denn, man vergibt zwei
   Lizenzen und nimmt die eigene Auslieferung von der GPL aus. Das ist Aufwand
   ohne Gegenwert für ein Werkzeug von zwei Leuten.
2. **Die mitgelieferten Bibliotheken.** NFCPassportReader liegt unter MIT,
   OpenSSL unter Apache-2.0 — siehe
   [`../THIRD-PARTY-NOTICES.md`](../THIRD-PARTY-NOTICES.md). Beide passen unter
   jede permissive Lizenz und unter MPL. Unter GPL entstünden zusätzliche
   Verträglichkeitsfragen.
3. **Die Android-Fassung ist die Mutter.** Diese Portierung ist abgeleitetes
   Werk: Datenmodell, Parser samt ihrer Begründungen, Ausgabeformat, alle
   Wortlaute. Sie **allein** unter eine Lizenz zu stellen wäre der Anfang von
   zwei auseinanderlaufenden Rechtslagen für ein Werk. Was gewählt wird, gehört
   in beide Repositories.
4. **Es ist eine Ausweislese-App.** Wer sie forkt, kann die Echtheitsprüfung
   entschärfen und das Ergebnis trotzdem „geprüft" nennen. Keine Lizenz
   verhindert das. Marken- und Namensrecht schon eher — deshalb ist es kein
   Nebenpunkt, dass die Lizenz keine Namensrechte mitgibt.

## Empfehlung: Apache-2.0

Für den Quelltext, in beiden Repositories, mit `NOTICE` daneben.

* **Ausdrückliche Patentlizenz** (§3). Für eine App, die PACE, Secure Messaging
  und Kettenprüfung rechnet, ist das der Unterschied zwischen einer Zusage und
  einer Vermutung. MIT und BSD schweigen dazu.
* **Namen bleiben draußen** (§6): keine Marken-, Namens- oder Produktrechte.
  Genau die Trennung, die Punkt 4 oben braucht — ein Fork darf den Code nehmen
  und nicht „IDReader" heißen.
* **Zuschreibung bleibt Pflicht** (§4): Lizenz, Urhebervermerk und `NOTICE`
  reisen mit. Damit ist die Zuschreibungsforderung aus `COPYRIGHT` nicht mehr
  eine Bitte, sondern eine Bedingung.
* **Verträglich** mit MIT und mit Apache-2.0 — also mit allem, was schon im
  Bundle liegt. Keine Prüfung nötig.
* **Store-verträglich.** Kein Streit über zusätzliche Beschränkungen.
* **Keine Durchsetzungslast.** Niemand muss beobachten, ob Forks ihre Änderungen
  veröffentlichen — bei zwei Rechteinhabern ohne Rechtsabteilung ist das der
  entscheidende praktische Punkt.

Was Apache-2.0 **nicht** leistet: es verpflichtet niemanden, Verbesserungen
zurückzugeben. Wem das wichtig ist, gehört zur Alternative.

## Alternative, wenn Forks offen bleiben sollen: MPL-2.0

Die Mozilla Public License 2.0 ist der brauchbare Mittelweg und der einzige
Copyleft, der hier ohne Verrenkungen funktioniert:

* Copyleft **je Datei**: wer eine Datei dieses Projekts ändert, muss diese Datei
  offenlegen — nicht sein ganzes Programm.
* Kombinierbar mit proprietärem Code, und **store-verträglich**, weil ihr die
  Klausel fehlt, an der die GPL scheitert.
* Auch sie hat eine Patentlizenz.

Der Preis: weniger verbreitet, also mehr Erklärung, wenn jemand den Code
einsetzen will. Für eine Behörde als Nutzerin ist Apache-2.0 die Lizenz, die
keine Rückfrage auslöst.

## Was nicht empfohlen wird

| Lizenz | Warum nicht |
|---|---|
| MIT / BSD-2 | Wie Apache-2.0, nur ohne Patentlizenz und ohne `NOTICE`-Pflicht. Es gibt keinen Grund, hier weniger zu nehmen. |
| GPL-3.0 / AGPL-3.0 | Siehe Punkt 1. Für eine Store-App ein Widerspruch, den man dauerhaft erklären müsste. |
| Creative-Commons-Lizenzen | Nicht für Quelltext gedacht; CC selbst rät davon ab. |
| Eine eigene Lizenz | Niemand kennt sie, jede Prüfstelle liest sie von vorn, und Fehler darin fallen erst auf, wenn es darauf ankommt. |
| Weiter „alle Rechte vorbehalten" | Keine schlechte Wahl, solange niemand mitarbeiten soll. Aber ein öffentliches Repository ohne Lizenz lädt zu Beiträgen ein, die niemand annehmen kann. |

## Wenn Apache-2.0 gewählt wird: die Handgriffe

1. Christian Auer stimmt schriftlich zu — eine Zeile im Repository oder im
   Ticket genügt, aber sie muss existieren. `LICENSE` verlangt das ausdrücklich,
   und `COPYRIGHT` sagt, warum.
2. `LICENSE` wird durch den unveränderten Apache-2.0-Text ersetzt. **Nicht
   umschreiben** — eine geänderte Apache-Lizenz ist keine Apache-Lizenz mehr.
3. Der heutige Inhalt von `LICENSE`, soweit er mehr sagt als die Lizenz — die
   gemeinsame Inhaberschaft, der Hinweis auf das abgeleitete Werk, der
   Haftungsausschluss für die Ausweislesung —, wandert nach `NOTICE` und
   `COPYRIGHT`.
4. Dateikopf: Apache-2.0 verlangt keinen, aber ein einheitlicher Zweizeiler
   erleichtert die Herkunft. Ohne Jahreszahlen, die veralten.
5. Dieselbe Änderung in `cauer71/AndroidDev` — siehe Punkt 3 der
   Einschränkungen.
6. `THIRD-PARTY-NOTICES.md` bleibt, wie es ist. Die Lizenz des eigenen Codes
   ändert nichts an denen der fremden.

Stand: 21. August 2026. Offen, weil noch niemand zugestimmt hat.
