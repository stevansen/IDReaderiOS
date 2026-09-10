# Verteilung über ein MDM, ohne den App Store

Stand vom 10. September 2026. Alles unten ist über die App Store Connect API
nachgesehen, nicht aus der Erinnerung.

## Was dieses Konto kann, und was nicht

| Zertifikat im Konto | vorhanden |
|---|---|
| `DEVELOPMENT` | ja |
| `DISTRIBUTION` | ja |
| `DEVELOPER_ID_APPLICATION` | ja |
| `MAC_INSTALLER_DISTRIBUTION` | ja |
| **In-House (Enterprise)** | **nein** |

Unter `profiles` steht ausschließlich `*_APP_STORE`, kein `IOS_APP_INHOUSE`. Das
Konto ist ein gewöhnliches **Apple Developer Program** auf eine natürliche
Person, kein Enterprise-Programm.

Daraus folgt die eine Antwort, die man ungern gibt:

> **Eine `.ipa`, die sich auf beliebige iPhones legen lässt, gibt es hier nicht.**
> Das kann nur das Apple Developer Enterprise Program, und Apple vergibt es
> restriktiv: eigene Rechtsform, D-U-N-S-Nummer, und die Auflage, damit
> ausschließlich eigene Mitarbeiter zu versorgen.

Was bleibt, sind zwei Wege — und der zweite ist für eine Behörde der richtige.

## Weg 1 — Ad hoc: geht heute, aber nur auf benannten Geräten

```bash
Scripts/archive.sh --adhoc 27
# → build/export-adhoc/IDReader.ipa
```

Die Datei lässt sich über jedes MDM verteilen, das den Upload eigener Programme
kennt. Sie installiert sich aber **nur auf Geräten, deren UDID im Konto
registriert ist** — höchstens hundert iPhones je Mitgliedsjahr, und die Zahl
setzt sich erst mit der jährlichen Verlängerung zurück. Auf jedem anderen Gerät
bricht die Installation ab, auch über ein MDM.

Heute registriert: **ein Gerät, und das ist ein iPad.** Die App ist auf iPhone
beschränkt (`TARGETED_DEVICE_FAMILY = 1`), ein Ad-hoc-Bau liefe also derzeit auf
keinem einzigen Gerät.

Damit er läuft, braucht es je iPhone die **UDID**. Sie steht in den
Geräteinformationen des MDM, oder ohne MDM: iPhone an einen Mac, im Finder in der
Geräteleiste auf die Zeile unter dem Namen klicken, bis die UDID erscheint.

Ohne Manifest (`itms-services`) ist die Datei absichtlich: eine öffentliche
Adresse, unter der eine App zum Lesen von Ausweisen liegt, ist keine gute Idee.
Für ein MDM braucht es sie auch nicht.

## Weg 2 — Custom App über Apple Business Manager: der richtige für eine Behörde

Ein normales Entwicklerprogramm darf eine App **nicht öffentlich**, sondern nur
an benannte Organisationen ausliefern. Die Organisation bekommt sie in ihr Apple
Business Manager und verteilt sie über ihr MDM — ohne UDIDs, ohne Gerätegrenze,
mit Aktualisierungen wie bei jeder Store-App.

Der Weg dorthin:

1. In App Store Connect die App als **Custom App** anlegen (eigene
   Verfügbarkeit: nicht öffentlich, sondern „nur bestimmte Organisationen").
2. Die **Organisations-ID** der Empfängerin eintragen. Die Vigili del Fuoco
   müssten sie aus ihrem Apple Business Manager nennen; sie ist neunstellig und
   steht dort unter *Einstellungen → Registrierungsinformationen*.
3. Die App durchläuft die normale App-Prüfung.
4. Die Organisation kauft sie zum Preis null und verteilt sie über ihr MDM.

Das ist mehr Vorlauf als eine Datei, aber es ist der Weg, der trägt: keine
hundert UDIDs zu pflegen, kein Ablauf nach einem Jahr, und die Empfängerin
verwaltet die Installation selbst.

## Was jetzt zu entscheiden ist

| Frage | wer beantwortet sie |
|---|---|
| Welche iPhones sollen den Ad-hoc-Bau bekommen? | Sie — UDIDs nennen, dann ist es ein Befehl |
| Oder gleich Custom App? | Sie, zusammen mit der Empfängerin — es braucht deren Organisations-ID |

Vorbereitet ist beides: `Config/ExportOptions-AdHoc.plist` und
`Scripts/archive.sh --adhoc` liegen bereit, und sie brauchen nur registrierte
Geräte, um etwas Brauchbares zu erzeugen.
