# Datenschutz

Übernommen aus dem Abschnitt „Data protection" des Android-Originals und dort
angepasst, wo iOS andere Mittel hat. Keine Rechtsberatung.

## Was die App tut, damit die unangenehmen Fragen kurze Antworten haben

**Nichts verlässt das Gerät von selbst.** Es gibt keinen Netzzugriff im
Quelltext — auch nicht in der fremden Lesebibliothek unter `ThirdParty/`, die das
Skript unten mitprüft. Das ist dort keine Nebensache: die Bibliothek nimmt für die
Kettenprüfung eine `URL`, und eine `URL` kann auch ins Netz zeigen. Übergeben wird
ihr das mitgelieferte PEM-Bündel auf der Platte.
Unter Android trug diese Zusage das Manifest, das die `INTERNET`-Berechtigung
ausdrücklich wieder entfernte — weil eine Bibliothek sie stillschweigend
hinzufügen könnte und damit eine Aussage im Store-Eintrag aufheben würde, ohne
dass irgendwo im Code steht, dass etwas übertragen wird. iOS kennt keine solche
Berechtigung. Also übernimmt `Scripts/check-no-network.sh` die Rolle: er sucht
nach allem, womit sich senden ließe, und schlägt fehl, wenn er etwas findet.

**Vier Felder werden angezeigt und nicht aufbewahrt.** Wohnsitz, Steuernummer,
Beruf und Telefon. Die Frage dahinter: braucht ein Anwendungsfall dieses Feld,
nachdem das Dokument aus der Hand ist? Für diese vier lautet die Antwort nein —
und „der Chip hatte es" ist kein Zweck. Wer eine Anschrift braucht, sieht sie
einmal und schreibt sie ab; danach ist sie weg.

Der Datensatz merkt sich dabei, **welche** Felder es gab, nicht ihren Inhalt. Das
ist nicht Beiwerk: sonst stünde später bei einer fehlenden Anschrift „nicht im
Dokument", und das wäre eine Aussage über das Dokument, die niemand treffen darf.
Ein Reisepass, der nie einen Wohnsitz führte, sagt weiter „nicht im Dokument".

Ein Feld hing daran: die Steuernummer war der Personenschlüssel des Archivs — sie
überlebt einen Kartenwechsel und hält die Regel „ein Eintrag pro Person". An ihre
Stelle tritt ein **Abdruck** unter einem Schlüssel, der aus dem Archivschlüssel
abgeleitet ist und das Gerät nicht verlässt. Dieselbe Person wird wiedererkannt,
und eine Steuernummer steht nirgends mehr. Ein nackter Hash hätte das nicht
geleistet: sechzehn Stellen mit starrem Aufbau sind durchzuprobieren.

**Was gespeichert wird, und wie lange.** Datensätze liegen mit AES-256-GCM
verschlüsselt, der Schlüssel im Schlüsselbund mit
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: er wird nie gesichert, nie auf ein
anderes Gerät übertragen und ist nur bei entsperrtem Gerät zu haben. Die Datei
wird atomar geschrieben (daneben, dann austauschen), trägt Dateischutz der Klasse
A und ist von iCloud- und Rechnersicherung ausgenommen. Ein vorübergehender
Lesefehler räumt nichts weg — nur ein tatsächlich fehlgeschlagenes Entschlüsseln,
denn verschlüsselter Datenmüll wird nie wieder lesbar. Gelöscht wird nach
`DocumentArchive.retentionDays` (30), geprüft bei jedem Lesen.

**Kein Abbild im App-Umschalter.** Dort läge sonst der zuletzt gezeigte Datensatz
samt Lichtbild als Schnappschuss im Systemspeicher. Bewusst **kein** vollständiges
Blenden: das verböte auch das absichtliche Bildschirmfoto, mit dem Tester Fehler
melden — der Schnappschuss hingegen entsteht ungefragt.

**Fingerabdrücke werden nie angefasst.** Gelesen werden DG1, DG2 (das Lichtbild),
DG11, DG12 und DG14. DG3 — die Fingerabdrücke — ist durch Extended Access Control
geschützt und braucht ein Inspektionssystem-Zertifikat; die App hat keines und
fragt nach keinem.

**Ein Lichtbild ist nicht automatisch ein biometrisches Datum.** Nach Art. 4 Nr. 14
DSGVO und Erwägungsgrund 51 gilt eine Fotografie erst dann als biometrisch, wenn
sie mit spezifischen technischen Mitteln zur eindeutigen Identifizierung
verarbeitet wird. Die App zeigt und speichert das Bild; sie vergleicht es nicht.

**Geprüft und ungeprüft sehen nie gleich aus.** Ein Chip-Datensatz, der die
Prüfung bestanden hat, trägt das grüne Siegel. Ein Datensatz aus einem Foto trägt
gar keins — kein graues, kein durchgestrichenes —, sondern den Vorbehalt in
Worten, ein rotes Zeichen und „ungeprüft". Ein durchgestrichenes Siegel liest sich
als „hat die Prüfung nicht bestanden", und genau hier gab es nie eine Prüfung. Ein
Chip-Datensatz, der wirklich durchgefallen ist, behält das durchgestrichene
Siegel: dort ist es ein Urteil.

**Die Kamera.** Eine Berechtigung mehr als das Original, und nicht zu vermeiden:
die Android-Fassung fotografiert über die Kamera-App des Systems, die ihre eigene
Berechtigung mitbringt, und bleibt dadurch bei NFC als einziger. Auf iOS gibt es
diesen Weg nicht. Was bleibt: die Aufnahme geht nie in die Fotobibliothek und nie
auf die Platte — sie lebt im Speicher, bis die Erkennung durch ist.

**Was hinausgeht, wird gesagt und nicht eingestellt.** Der Teilen-Schirm rechnet
je Datensatz auf, was ihn verlässt, und nennt den Umfang als zwei Aussagen. Die
Schalter, die dort einmal standen, sind weg: sie verlangten eine Entscheidung, die
im Einsatz niemand treffen will. Das Lichtbild reist **nur per Mail**, und nur mit
der lesbaren Fassung — dort ist der Empfänger benannt und die Nachricht
adressiert, was von der Zwischenablage und von einem Teilen-Dialog mit
nachträglich gewähltem Ziel nicht gilt. Jeder andere Weg trägt den Vermerk „Ohne
Lichtbild". Der Eintrag in der Zwischenablage verfällt nach zwei Minuten.

## Was die App nicht entscheiden kann

Diese Fragen gehören dem, der sie einsetzt, und der Hinweis beim ersten Start sagt
das, statt es zu verschweigen:

* **Die Rechtsgrundlage.** Die App lädt jeder, der sie laden kann, nicht nur
  Behörden. Sie weiß also nicht, unter welchen Regeln ein bestimmter Leser
  arbeitet — in Italien kann das die DSGVO sein oder `D.lgs. 51/2018`, wo eine
  zuständige Behörde für Zwecke des Strafrechts verarbeitet. Der Hinweis benennt
  deshalb die Verantwortung und nicht die Norm.
* **Die Unterrichtung der betroffenen Person.** Diese Pflicht läuft auf die Person
  zu, deren Dokument gelesen wird. Nur der Bediener, der vor ihr steht, kann sie
  erfüllen; der Hinweis erinnert ihn daran.
* **Die Aufbewahrungsdauer.** Dreißig Tage sind eine Vorgabe, kein Befund. Eine
  Befugnis, ein Dokument zu **prüfen**, ist nicht schon eine Befugnis, es zu
  **behalten**: im April 2026 hat der Garante für Hotels festgestellt, dass die
  gesetzliche Pflicht die Übermittlung der Daten umfasst, nicht ihre Speicherung,
  und dass jede weitere Kopie nach Erfüllung der Pflicht ohne Rechtsgrundlage ist
  (Doc-Web 10244289). Wer diese App einsetzt, braucht seine eigene Antwort, und
  `DocumentArchive.retentionDays` ist die Stelle, an die sie gehört.

## Was noch zu erwägen wäre

Der Durchgang zur Datenminimierung hat vier Felder erledigt. Zwei liegen in
derselben Kategorie und sind es nicht:

* **Angaben zur Person** (Größe, Augenfarbe) und **weitere Dokumentnummern** aus
  DG11. Auf den allermeisten Dokumenten steht dort nichts, weshalb es nie
  aufgefallen ist — aber wenn etwas steht, gilt dieselbe Frage: braucht das ein
  Anwendungsfall, nachdem das Dokument aus der Hand ist? Bisher nicht gestellt.
