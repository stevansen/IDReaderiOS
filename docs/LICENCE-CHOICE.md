# Welche Lizenz für diese App

**Entschieden: Apache-Lizenz 2.0.** Umgestellt am 21. August 2026 — siehe
[`../LICENSE`](../LICENSE) und [`../NOTICE`](../NOTICE). Dieses Papier bleibt
stehen, weil eine Lizenzwahl ohne ihre Begründung in einem Jahr wie eine Laune
aussieht. Keine Rechtsberatung.

**Offen ist noch eine Zustimmung.** [`../COPYRIGHT`](../COPYRIGHT) hält fest,
dass keiner der beiden Rechteinhaber allein umstellen darf. Stefan Hellwegers
Zustimmung liegt in dieser Änderung; Christian Auers gehört schriftlich in
`COPYRIGHT` nachgetragen. Bis dahin steht im Repository eine Lizenz, auf die
sich ein Leser verlässt und die nur halb vereinbart ist — ein Grund, das zu
erledigen, nicht ein Grund, es zurückzunehmen: eine erteilte Apache-Lizenz lässt
sich für das Veröffentlichte nicht mehr einsammeln.

## Der Stand davor

Der Quelltext war **öffentlich**, aber nicht **offen**: das Repository lesbar,
`LICENSE` gewährte keine Rechte. Ein gültiger Zustand mit einem Namen —
*source-available* — und der einzige, aus dem alle anderen noch erreichbar
waren. Genau deshalb war die Reihenfolge richtig: erst die Wahl begründen, dann
sie treffen.

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

## Die Wahl: Apache-2.0

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
| Weiter „alle Rechte vorbehalten" | War keine schlechte Wahl, solange niemand mitarbeiten sollte. Aber ein öffentliches Repository ohne Lizenz lädt zu Beiträgen ein, die niemand annehmen kann. |

## Die Handgriffe, und was daraus wurde

| | |
|---|---|
| **1. Christian Auers Zustimmung** | **Offen.** Eine Zeile in `COPYRIGHT` oder im Ticket genügt, aber sie muss existieren. |
| **2. `LICENSE` ersetzen** | Erledigt, mit dem **unveränderten** Text. Nicht abgeschrieben, sondern aus einer echten Apache-2.0-Auslieferung im Abhängigkeitsbaum übernommen (`OpenSSL-Package/LICENSE`) und Abschnitt für Abschnitt gegengelesen. Eine umgeschriebene Apache-Lizenz wäre keine mehr. |
| **3. Den Rest umziehen** | Erledigt. Was das alte `LICENSE` mehr sagte als eine Lizenz, steht jetzt dort, wo es hingehört: die gemeinsame Inhaberschaft und die Regel zum Umlizenzieren in `COPYRIGHT`, die Herkunft und der Satz „ein Urteil ‚echt' heißt nicht, dass die Person vor Ihnen die des Dokuments ist" in `NOTICE`. Letzteres mit Absicht in `NOTICE`: Abschnitt 4(d) lässt diese Datei mitreisen, den Rest des Repositories nicht. |
| **4. Lizenzkopf in jede Datei** | **Bewusst nicht.** Apache-2.0 verlangt keinen. Die Dateien hier beginnen mit dem Dokumentkommentar, der erklärt, *warum* sie so aussehen — das ist der eigentliche Wert im Quelltext, und ein Rechtsblock davor schiebt ihn unter die erste Bildschirmseite. Welche Dateien aus der Android-Fassung stammen, steht ohnehin genauer in `COPYRIGHT`, als ein Kopf es sagen könnte. |
| **5. Dieselbe Änderung in `cauer71/AndroidDev`** | **Offen**, und nicht von hier aus zu machen. Siehe Punkt 3 der Einschränkungen. |
| **6. `THIRD-PARTY-NOTICES.md`** | Unverändert. Die Lizenz des eigenen Codes ändert nichts an denen der fremden. |
| **7. Ausfuhrunterlagen** | Nachgetragen: dass der Quelltext jetzt öffentlich lizenziert ist, ist für die Einordnung von Verschlüsselungssoftware kein Nebenpunkt. Siehe [EXPORT-COMPLIANCE-DOSSIER.md](EXPORT-COMPLIANCE-DOSSIER.md), Abschnitt 6. |

Stand: 21. August 2026.
