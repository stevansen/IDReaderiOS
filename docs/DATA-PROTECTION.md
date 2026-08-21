# Datenschutz

Übernommen aus dem Abschnitt „Data protection" des Android-Originals und dort
angepasst, wo iOS andere Mittel hat. Keine Rechtsberatung.

## Was die App tut, damit die unangenehmen Fragen kurze Antworten haben

**Ein Netzzugriff, an einer benannten Stelle.** Bis zur Sperrprüfung stand hier,
es gebe keinen. Jetzt gibt es genau einen:
[`App/Revocation/RevocationDownloader.swift`](../App/Revocation/RevocationDownloader.swift)
holt die öffentliche Sperrliste der Ausweisbehörde. Was dabei hinausgeht, ist die
Anfrage — kein Datum aus einem Dokument, keine Gerätekennung, keine Angabe
darüber, dass überhaupt gelesen wurde. Geholt wird beim Starten und auf
ausdrückliche Anforderung, **nie während eines Lesevorgangs**: der Zeitpunkt einer
Anfrage wäre sonst selbst eine Mitteilung. Abschaltbar in den Einstellungen; aus
ist die App vollständig offline.

Genau deshalb CRL und nicht OCSP. Bei OCSP geht die Seriennummer des gerade
geprüften Zertifikats mit hinaus, also ein Hinweis darauf, welches Dokument
jemand in der Hand hält. Eine CRL wird als Ganzes geholt und danach **offline**
abgeglichen — auch beim zwanzigsten Dokument an einem Tag ohne Empfang.

Was hereinkommt, gilt erst nach Prüfung: die Signatur der Liste gegen dieselben
neun CSCA-Zertifikate, die die Passive Authentication verankern. Eine
untergeschobene leere Liste würde sonst jeden gesperrten Signierer wieder gültig
aussehen lassen — und die App würde dazu „geprüft am, Liste vom" anzeigen.

Alles Übrige bleibt ohne Netz, auch die fremde Lesebibliothek unter `ThirdParty/`.
Das ist dort keine Nebensache: die Bibliothek nimmt für die Kettenprüfung eine
`URL`, und eine `URL` kann auch ins Netz zeigen. Übergeben wird ihr das
mitgelieferte PEM-Bündel auf der Platte.

Unter Android trug diese Zusage das Manifest, das die `INTERNET`-Berechtigung
ausdrücklich wieder entfernte. iOS kennt keine solche Berechtigung. Also übernimmt
`Scripts/check-no-network.sh` die Rolle, und in seiner heutigen Fassung setzt er
die engere und darum überprüfbare Zusage durch: Netzzugriff **nur** in dieser
einen Datei, und dort ohne festen Rechnernamen — die Adresse kommt aus den
Zertifikaten.

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

**Abschaltbar ist es, vorbelegt nicht.** In den Einstellungen steht ein Schalter
„Alle Felder aufbewahren". Aus ist er, und aus bleibt er, solange ihn niemand
umlegt — die Vorgabe ist die Aussage. Wer ihn einschaltet, bekommt vorher eine
Rückfrage, die keine Formalität ist: sie sagt, dass Daten zu behalten, die man
nicht braucht, eine App nicht für ihn rechtfertigen kann, dass er den Zweck der
zusätzlichen Felder benennen können muss und dafür einsteht. „Könnte mal nützlich
sein" ist keiner. Beim Ausschalten fragt nichts — zurück zur Vorgabe braucht
niemand eine Begründung.

Der Schalter wirkt **ab jetzt**: was schon weggelassen wurde, ist weg und kommt
nicht zurück. Der Personenabdruck entsteht in beiden Stellungen, damit die Regel
„ein Eintrag pro Person" nicht von einer Einstellung abhängt.

**Die Sperrprüfung sagt, was sie prüft.** Geprüft wird das Zertifikat, mit dem
das Dokument signiert wurde — nicht, ob dieses Dokument als verloren oder
gestohlen gemeldet ist. Wer „Sperrliste" liest, denkt zuerst an das Zweite;
solche Fahndungsbestände (für Reisedokumente die SLTD von Interpol) stehen keiner
öffentlichen App offen. Dieser Satz steht deshalb im Ergebnis, im Archiv und in
den Einstellungen, und nicht nur hier.

Am Datensatz steht **wann** geprüft wurde und **welche Liste** dabei vorlag. Zwei
Angaben statt einer, weil „geprüft" allein nichts aussagt: eine Prüfung von heute
gegen eine Liste von vor zwei Jahren ist etwas anderes als eine von vor zwei
Wochen gegen die Liste von damals. Die Bewertung bleibt bei dem, der hinsieht.

Lag beim Lesen keine Liste vor — kein Empfang, Auffrischung aus —, bleibt die
Prüfung **offen** und wird nachgeholt, sobald eine da ist. „Offen" sieht nie aus
wie „nicht gesperrt". Aufbewahrt werden dafür zwei Angaben über den Signierer:
seine Seriennummer und der Abdruck seines Ausstellernamens. Beide sagen nichts
über die Person — ein Signierer signiert zehntausende Dokumente.

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
