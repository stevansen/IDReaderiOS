# Bedienungshilfen

Was geprüft ist, wie es geprüft wurde, und was noch offen ist. Keine
Selbstauskunft aus dem Quelltext: alles unten ist am Simulator gesehen oder
gerechnet.

Geprüft am 22. August 2026, iPhone 17 Pro Max, iOS 26.

## Der Befund, der alles andere ausgelöst hat

`AppType` versprach im Kommentar, alle Schriftstile seien mit `relativeTo:` an
einen Textstil gebunden und wüchsen mit der Systemschrift mit. **Der Code tat es
nicht** — er benutzte `Font.system(size:)`, und das ist in SwiftUI eine feste
Größe.

Bei der größten Bedienungshilfen-Schrift war das Ergebnis kein Schönheitsfehler:

* Der Umschalter zeigte „ID | Passp… | Licence" — zwei von drei Dokumentarten
  waren nicht mehr zu lesen.
* Der Fehlerkasten zeigte „No NFC av… / This device h…" — **die Begründung, warum
  die App gerade nichts tun kann, war abgeschnitten.**
* Die Kartengrafik mit der abgebildeten CAN war auf einen Strich zusammengefallen.
* „Read card" lag halb unter dem Vorlaufzeichen daneben.
* Im Archiv hieß jeder Eintrag „ANITA…", „SEBAS…", „GIUSE…".
* Die Kopfzeile war über die Statusleiste gewachsen.

Wer die größte Schrift einstellt, tut das nicht aus Neugier. Genau dieser Person
verschwieg die App, was sie tut.

Eine Aussage im Kommentar, die der Code nicht einhält, ist dabei schlimmer als
keine: sie beendet die Suche an der Stelle, an der der Fehler liegt.

## Was geändert wurde

| | |
|---|---|
| **Schriftstile** | Jeder `AppType`-Stil ist jetzt ein **Textstil** statt einer Punktzahl. Die Entwurfsgrößen 11, 13, 15, 17, 20 sind genau die Vorgaben von `caption2`, `footnote`, `subheadline`, `body`, `title3` — bei normaler Systemschrift sieht deshalb nichts anders aus, bei jeder anderen wachsen alle Stile gemeinsam. |
| **Nichtproportionale Werte** | Ebenso, mit bis zu zwei Punkt Abweichung von den Entwurfsgrößen (14/16/18/24 → `footnote`/`callout`/`body`/`title2`). Der Preis dafür, dass eine Ziffernreihe nicht abgeschnitten wird. |
| **Glyphen** | Zeichen, die **neben Text** stehen, wachsen mit (die vier Sperrlisten-Zeichen im Archiv, das Schloss an der Archivzahl, der Haken im Teilen-Schirm, das Kamerazeichen). Reine Zierglyphen und alles, was die Kartengrafik proportional aufbaut, bleiben fest. |
| **Rollbereich** | Die Eingabemasken rollen **bei den Bedienungshilfen-Größen**. Bei normaler Schrift nicht — beide Schritte gleichzeitig sichtbar und der Ziffernblock unten festgesetzt ist eine Entscheidung der Android-Fassung und sie ist richtig: wer ein Dokument in der Hand hält, hat keine Hand zum Wischen. Sie hört nur bei großer Schrift auf zu funktionieren. |
| **Umschalter** | Bei den Bedienungshilfen-Größen stehen die drei Dokumentarten untereinander statt nebeneinander. |
| **Geteilter Leseknopf** | Ebenso zwei Knöpfe untereinander. Der schnelle Weg bekommt dabei seine Beschriftung in Worten — das Zeichen allein war nur neben dem breiten Knopf verständlich. |
| **Knopfbeschriftungen** | Kein `lineLimit(1)` mehr auf „Karte fotografieren" und „Karte lesen". Was ein Knopf tut, muss auf ihm stehen. |
| **Archivzeile** | Name und Sperrlistenzeile dürfen zweizeilig werden. |
| **Hinweis mit Knopf** | „Gespeicherte Fassung vom … " stand neben dem Knopf in einer Spalte von zwei Wörtern Breite. Bei großer Schrift steht der Knopf jetzt darunter. |
| **Ziffernkasten** | `frame(height: 56)` → `minHeight`. |

Die Grenze zieht überall `DynamicTypeSize/isAccessibilitySize` und nicht eine
geratene Punktzahl.

## Vorlesefunktion

* **Jedes Zeichen ohne Beschriftung hat eine.** Zurück, Menü, Archiv, Alles
  löschen, Rücktaste, der schnelle Leseweg, das Siegel, das Lichtbild.
* **Das Archivzeichen sagt den ganzen Satz.** Sichtbar ist nur die Anzahl — wer
  die App aufmacht, soll nicht sofort sehen, wessen Ausweise gelesen wurden.
  Vorgelesen wird „3 Scans öffnen".
* **Die Ergebniskacheln sind je ein Element** (`accessibilityElement(children:
  .combine)`). Sonst hört man beim ersten Wischen „Geburtsdatum" und beim
  zweiten „07.04.1968" — bei sechzehn Kacheln muss man sich die Bezeichnung
  merken, während man zum Wert wischt, und das ist keine Auskunft mehr. Dasselbe
  für die Zeilen des Echtheitsblatts.
* **Die Kartengrafik ist versteckt** (`accessibilityHidden(true)`). Sie zeigt,
  *wo* auf der Karte die CAN steht; vorgelesen wäre sie eine Folge sinnloser
  Rechtecke. Was sie sagt, sagt der Untertitel des Schritts in Worten.

## Nicht nur Farbe

Das Urteil über die Echtheit hängt an keiner Stelle allein an der Farbe:

* Bestanden → grünes Siegel **und** „geprüft".
* Durchgefallen → durchgestrichenes Siegel **und** „nicht bestanden".
* Aus einem Foto, also nie geprüft → **gar kein** Siegel, sondern der Vorbehalt
  in Worten und „ungeprüft". Ein durchgestrichenes Siegel hieße „hat die Prüfung
  nicht bestanden", und hier gab es nie eine.

Im Archiv steht bei einem solchen Datensatz das Wort „ungeprüft" neben der
Zeile — nachgesehen, nicht angenommen.

## Kontrast

Gerechnet über alle sechs Paletten (Karte / Pass / Führerschein, hell und
dunkel), WCAG-2.1-Formel, aus den Hexwerten in `App/Support/AppTheme.swift`.
Elf Farbpaare je Palette, 66 Werte.

**Alle Textpaare bestehen AA (4.5:1)**, die meisten deutlich:

| Paar | schlechtester Wert | wo |
|---|---|---|
| Fließtext auf Fläche | 14.32 : 1 | passportDark |
| Nebentext auf Fläche | 8.69 : 1 | cardLight |
| Knopfschrift auf Knopf | 5.91 : 1 | passportLight |
| Fehlertext auf Fläche | 6.24 : 1 | licenceLight |
| Akzenttext auf Fläche | 5.73 : 1 | passportLight |

Drei Werte liegen unter 4.5, alle drei sind **kein Text**: `outline` auf
`surface` in den drei hellen Paletten (4.21 – 4.33). Für Rahmen und andere
Bedienelemente verlangt AA 3:1; das ist erfüllt. Nachrechnen:

```bash
python3 Scripts/contrast.py
```

## Zielgrößen

Jedes Zeichen, das man treffen muss, sitzt in mindestens 44 × 44 Punkt: Zurück,
Menü, Kamera, Rücktaste, der schnelle Leseweg. Der Ziffernblock der CAN-Maske
hat 48 Punkt Mindesthöhe je Taste über die ganze Spaltenbreite.

Die Ausnahme ist gewollt: der Umschalter hat 40 Punkt Höhe. Er ist über die
ganze Zeilenbreite geteilt, jede Hälfte also weit über 44 Punkt breit, und
Apples eigener segmentierter Umschalter ist genauso hoch.

## Was offen ist

1. ~~Am Gerät mit eingeschaltetem VoiceOver durchgesprochen~~ — **erledigt am
   23. August 2026**, an Bau 22, und dabei **ein Dokument gelesen**. Das ist die
   Prüfung, auf die es bei Apples Angabe ankommt: dort heißt „VoiceOver", dass die
   *wesentlichen* Funktionen benutzbar sind, und die wesentliche Funktion dieser
   App ist der Lesevorgang. `supportsVoiceover` steht seither auf `true`.
2. ~~Die Rückmeldungen während des Lesens sollten gesprochen werden~~ —
   **eingebaut.** `AccessibilityNotification.Announcement` bei jedem Wechsel der
   **Stufe**, nicht des Schritts: es sind vier Stufen und ein Dutzend Schritte,
   und wer bei jedem Datengruppenwechsel etwas hört, hört am Ende nichts mehr.
   Wer ein Dokument an die Rückseite hält, sieht den Bildschirm nicht — das gilt
   für jeden, und mit eingeschalteter Vorlesefunktion ist es die einzige
   Rückmeldung, die ankommt.
3. **„Bewegung reduzieren" wirkt jetzt** — und die Zählung im alten Text war
   falsch: die App hat **zwei** Bewegungen, nicht eine. Der Übergang zwischen den
   Masken (0,22 s) und die pulsierenden Ringe des Lesescreens, die dauerhaft
   laufen und genau dort stehen, wo man länger hinsieht als anderswo. Beide
   weichen ganz, statt schneller zu werden.

   **„Fette Schrift" und „Kontrast erhöhen"** sind weiterhin nicht geprüft.
4. **Das iPad.** Der Bau läuft dort auch — `CFBundleIcons~ipad` ist gesetzt —,
   geprüft wurde nichts. Deshalb gibt es für das iPad **keine**
   Bedienungshilfen-Angabe im Store: eine, die von einer nicht geprüften
   Geräteklasse behauptet, was auf einer anderen geprüft wurde, wäre genau der
   Fehler, den dieses Papier oben anderen vorwirft. Ein erster Lauf hatte sie
   angelegt; sie ist wieder gelöscht.

## Was im App Store steht

Gesetzt über `swift Scripts/asc.swift accessibility`, **als Entwurf** — das
Veröffentlichen ist eine öffentliche Zusage und braucht `--publish`.

Angekreuzt, weil belegt:

| Angabe | Belegt durch |
|---|---|
| Größerer Text | Alle drei Masken, Archiv und Ergebnis bei der größten Bedienungshilfen-Schrift, hell und dunkel, am Simulator durchgesehen |
| Ausreichender Kontrast | `Scripts/contrast.py`, 66 Werte über sechs Paletten |
| Nicht nur Farbe | Das Echtheitsurteil steht in Worten neben jedem Zeichen |
| Dunkle Oberfläche | Drei dunkle Paletten, am Simulator gesehen |

Nicht angekreuzt, und zwar bewusst: **Vorlesefunktion** (Beschriftungen sind da,
am Gerät mit eingeschaltetem VoiceOver ist nichts durchgesprochen),
**Sprachsteuerung** (ungeprüft), **Bewegung reduzieren** (nicht gebaut),
**Untertitel** und **Audiodeskription** (die App hat keine Medien).

Eine falsche Angabe dort wäre nicht ein Haken zu viel: sie steht im Store, und
jemand richtet sich danach.

## Warum die Angabe im Store trotzdem Entwurf ist

Nicht aus Vorsicht, sondern weil es nicht geht: **veröffentlichen lässt sich eine
Bedienungshilfen-Angabe nur für Geräte, für die eine Fassung live im App Store
ist.** IDReader war nie veröffentlicht — es gibt kein Produktblatt, auf dem die
Angabe stehen könnte.

Beide Wege über die Schnittstelle sind probiert, beide werden abgewiesen:

```
PATCH accessibilityDeclarations/<id>   { "state": "PUBLISHED" }
  → The attribute 'state' can not be included in a 'UPDATE' operation
POST  accessibilityDeclarations        { "state": "PUBLISHED", … }
  → The attribute 'state' can not be included in a 'CREATE' operation
```

`Scripts/asc.swift accessibility --publish` sagt das jetzt selbst, statt an einer
Fehlermeldung zu scheitern, die nach einem Fehler im Werkzeug aussieht. Der
Entwurf bleibt gespeichert; nach der ersten Freigabe genügt derselbe Befehl.

## Was in welchem Bau steckt

Eine Angabe im Store beschreibt das Programm, das der Leser herunterlädt — nicht
den Quelltext. Deshalb:

| Angabe | Stand | belegt durch |
|---|---|---|
| Größerer Text, Kontrast, nicht nur Farbe, dunkle Oberfläche | `true` | Simulator, alle Masken, hell und dunkel |
| **VoiceOver** | `true` | Gerät, Bau 22, mit gelesenem Dokument |
| **Bewegung reduzieren** | `true` | eingebaut in Bau 24, und **erst mit Bau 24 gesetzt** — vorher wäre es eine Zusage über ein Programm gewesen, das es nicht tut |
| Sprachsteuerung, Untertitel, Audiodeskription | `false` | nicht geprüft bzw. nicht zutreffend |

Die dritte Zeile ist der Grund für diese Tabelle. Sie stand einen halben Tag auf
`false`, obwohl die Änderung geschrieben, geprüft und festgeschrieben war — weil
sie in keinem Bau steckte, den jemand installieren kann. Erst als Bau 24 an der
Fassung hing, wurde sie umgestellt. Eine Angabe im Store beschreibt das Programm,
das der Leser herunterlädt, und nicht den Quelltext; wer die beiden verwechselt,
gibt eine Zusage über etwas, das es noch nicht gibt.

