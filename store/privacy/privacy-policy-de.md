# Datenschutzerklärung — Deutsch

Quelltext der Seite, die für die iOS-Fassung veröffentlicht wird. Hier abgelegt,
damit sie sich vergleichen lässt: **eine Datenschutzerklärung muss zum Verhalten
der Fassung passen, die tatsächlich veröffentlicht ist.**

Diese Fassung ist aus der Android-Erklärung entstanden
(`apps/cie-reader/store/privacy-policy-de.md` im Android-Repository). Drei Dinge
mussten sich ändern, und alle drei betreffen Zusagen:

1. **Die Kamera-Berechtigung.** Die Android-Fassung fotografiert über die
   Kamera-App des Systems und verlangt deshalb keine. Auf iOS gibt es diesen Weg
   nicht — `NSCameraUsageDescription` ist unvermeidlich. Der Satz „verlangt keine
   Kamera-Berechtigung" wäre hier falsch, und zwar an genau der Stelle, an der die
   Erklärung ein Versprechen gibt.
2. **„Keine Internetberechtigung"** gibt es auf iOS nicht als Begriff — und die
   Zusage selbst gilt nicht mehr unverändert: seit der Sperrprüfung ruft die App
   eine öffentliche Sperrliste ab. Das ist die Änderung, die diesem Text am
   meisten abverlangt, und sie hat einen eigenen Abschnitt bekommen. Ein Text, der
   weiter „kein Netzzugriff" sagte, wäre nicht bloß veraltet, sondern falsch.
3. **Der Führerschein** kam nach der letzten Fassung dieses Textes dazu. Er hat
   keinen Chip; seine Angaben stammen aus einer Texterkennung, und das ist eine
   andere Art von Datum.
4. **Die Datenminimierung** kam später dazu: vier Felder werden angezeigt und
   nicht aufbewahrt, abschaltbar, vorbelegt eingeschaltet.

Wer diesen Text ändert, muss die veröffentlichte Seite anpassen und die
italienische und englische Fassung daneben.

**Vor der Veröffentlichung auszufüllen:** die mit `<<…>>` markierten Stellen.

Alles unterhalb der Linie ist der zu veröffentlichende Text.

---

## Datenschutzerklärung

**IDReader** liest die auf dem Chip eines Ausweisdokuments gespeicherten Daten
über NFC und prüft, ob das Dokument echt ist. Unterstützt werden die italienische
elektronische Identitätskarte (CIE 3.0) und Reisepässe nach ICAO 9303. Die
italienische Fahrerlaubnis hat keinen Chip; ihre Angaben werden aus einer
Fotografie gelesen — siehe den eigenen Abschnitt dazu.

### Welche Daten die App verarbeitet

Bei Identitätskarte und Reisepass ausschließlich die Daten, die auf dem Chip des
aufgelegten Dokuments stehen:

- Vor- und Nachname, Geburtsdatum, Geburtsort, Geschlecht, Staatsangehörigkeit
- Dokumentnummer, Ausstellungs- und Ablaufdatum, ausstellende Stelle
- Wohnsitz und Steuernummer
- Lichtbild, wenn der vollständige Lesemodus gewählt wird

Welche dieser Angaben tatsächlich vorhanden sind, entscheidet das Dokument. Auf
einem Reisepass fehlen Wohnsitz und Steuernummer in der Regel; Geburtsort,
ausstellende Stelle und Ausstellungsdatum können fehlen.

Fingerabdrücke werden **nicht** gelesen. Sie liegen in einer Datengruppe, die
durch Extended Access Control geschützt ist und ein Zertifikat einer
Inspektionsstelle voraussetzt. Die App hat keines und fragt nach keinem.

**Zum Lichtbild in dieser Fassung:** auf der italienischen Identitätskarte liegt
es als JPEG 2000 vor, und iOS bringt dafür keinen Decoder mit. Die App kann es
deshalb derzeit nicht anzeigen und speichert es auch nicht; sie zeigt an dieser
Stelle das erkannte Format an. Sobald ein Decoder eingebunden ist, wird das
Lichtbild wie beschrieben verarbeitet, und diese Erklärung wird vorher angepasst.

### Voraussetzung für jeden Lesevorgang

Der Chip gibt nichts heraus, solange er nicht mit einem Schlüssel geöffnet wird,
der auf dem Dokument selbst abgedruckt ist. Dieser Schlüssel wird eingegeben oder
vom Dokument abfotografiert:

- **Identitätskarte:** die sechsstellige CAN von der Kartenvorderseite.
- **Reisepass:** Passnummer, Geburtsdatum und Ablaufdatum von der Datenseite.

Ohne das Dokument in der Hand kann die App nichts auslesen. Der Schlüssel wird
nicht aufbewahrt, mit einer Ausnahme: die CAN wird zusammen mit dem Datensatz
gespeichert, damit dieselbe Karte wiedererkannt wird. Beim Reisepass entfällt das,
weil der Schlüssel dort aus Personendaten besteht.

### Wenn fotografiert wird

Statt den Schlüssel zu tippen, lässt er sich vom Dokument ablesen: bei der
Identitätskarte die sechs Ziffern unten rechts auf der Vorderseite, beim Reisepass
die zwei Zeilen unten auf der Datenseite. Bei der Fahrerlaubnis ist die Fotografie
die einzige Quelle. Dafür gilt:

- Die App braucht dafür die **Kamera-Berechtigung**. Anders als die
  Android-Fassung, die über die Kamera-App des Systems fotografiert, ist das auf
  iOS nicht zu vermeiden. Ohne die Berechtigung bleibt das Tippen.
- Die Aufnahme wird **nicht gespeichert**. Sie liegt im Arbeitsspeicher, bis die
  Erkennung durch ist, und wird dann fallen gelassen. Sie gelangt nicht in die
  Fotobibliothek und nicht auf den Datenträger.
- Die **Texterkennung läuft auf dem Gerät**, mit der Bilderkennung des
  Betriebssystems. Es wird nichts nachgeladen und nichts übertragen.
- Bei Identitätskarte und Reisepass wird aus dem erkannten Text ausschließlich der
  Zugangsschlüssel entnommen. Alles andere, was auf dem Bild zu lesen gewesen
  wäre, wird verworfen.

Das Tippen bleibt vollständig möglich. Wer nicht fotografieren will, muss es
nicht.

### Die Fahrerlaubnis ist etwas anderes

Sie hat keinen Chip, keine maschinenlesbare Zone und keine Prüfziffer. Ihre
Angaben — Name, Geburtsdatum und -ort, Ausstellungs- und Ablaufdatum,
Nummer, Klassen und ausstellende Stelle — stammen ausschließlich aus der
Texterkennung einer Fotografie und sind **nicht bestätigt**: weder die Werte noch
das Dokument, noch dass überhaupt ein solches fotografiert wurde.

Deshalb sind alle Felder frei bearbeitbar, und deshalb trägt ein solcher Datensatz
in der App und in jeder Ausgabe den Vorbehalt, dass hier nichts geprüft ist. Auch
für diese Angaben gilt alles Übrige dieser Erklärung: sie bleiben auf dem Gerät,
verschlüsselt, und löschen sich nach 30 Tagen.

### Was angezeigt und nicht aufbewahrt wird

Vier Angaben werden gezeigt, solange der Datensatz auf dem Bildschirm steht, und
**nicht in das Archiv übernommen**: Wohnsitz, Steuernummer, Beruf und Telefon. Die
Frage dahinter ist, ob ein Anwendungsfall das Feld noch braucht, nachdem das
Dokument aus der Hand ist; für diese vier ist die Antwort nein. Wer eine Anschrift
braucht, sieht sie einmal und schreibt sie ab.

Der Datensatz merkt sich, **welche** dieser Felder das Dokument geführt hat, nicht
deren Inhalt. Deshalb steht später „gelesen, nicht gespeichert" und nicht „nicht
im Dokument" — letzteres wäre eine Aussage über das Dokument, die nicht zutrifft.

Damit dieselbe Person auch nach einer Neuausstellung ein Eintrag bleibt, wird aus
der Steuernummer ein **Abdruck** gebildet, mit einem aus dem Archivschlüssel
abgeleiteten Schlüssel, der das Gerät nicht verlässt. Die Steuernummer selbst wird
dabei nicht gespeichert und ist aus dem Abdruck nicht zurückzurechnen.

In den Einstellungen lässt sich diese Minimierung **abschalten** („Alle Felder
aufbewahren"); dann werden die vier Felder mitgespeichert und mit ausgegeben.
Vorbelegt ist sie **eingeschaltet**, und beim Abschalten weist die App darauf hin,
dass wer alles aufbewahrt, den Zweck der zusätzlichen Felder benennen können muss
und dafür einsteht — Datenminimierung ist eine Pflicht des Verantwortlichen und
keine Einstellung in einem Programm. Die Änderung wirkt ab dem nächsten
Lesevorgang; bereits weggelassene Angaben sind gelöscht.

### Wo die Daten bleiben

Die gelesenen Daten liegen **ausschließlich auf dem Gerät**. Sie werden mit
AES-256 verschlüsselt; der Schlüssel liegt im Schlüsselbund des Geräts, ist auf
dieses Gerät beschränkt, wird nicht in eine Sicherung aufgenommen und ist nur bei
entsperrtem Gerät verwendbar.

Die Archivdatei selbst ist von der iCloud- und der Rechnersicherung ausgenommen
und trägt den Dateischutz des Betriebssystems.

**30 Tage** nach dem Lesevorgang werden die Daten automatisch gelöscht. Vorher
lassen sie sich jederzeit in der App löschen.

Im App-Umschalter erscheint kein Abbild des zuletzt gezeigten Datensatzes.

### Der einzige Netzzugriff: die Sperrliste

Die App überträgt **keine personenbezogenen Daten** — weder an die Entwickler noch
an Dritte. Es gibt kein Analysewerkzeug, keine Werbung und kein Tracking, und
keinen Server der Entwickler, mit dem die App spricht.

Einen Netzzugriff macht sie, und nur diesen einen: sie ruft die **öffentliche
Sperrliste** (Certificate Revocation List) bei der Stelle ab, die sie ausgibt —
für italienische Dokumente das Innenministerium. Die Adresse dafür steht in den
mitgelieferten Zertifikaten. Dazu gilt:

- **Es geht nichts über das Dokument hinaus.** Abgerufen wird eine öffentliche
  Datei, so wie man eine Webseite lädt. Keine Angabe aus dem Dokument, keine
  Gerätekennung, keine Mitteilung darüber, dass überhaupt gelesen wurde.
- **Nie während eines Lesevorgangs.** Abgerufen wird beim Starten der App und
  wenn Sie es in den Einstellungen anfordern. Der Zeitpunkt einer Anfrage wäre
  sonst selbst eine Mitteilung.
- **Der Abgleich läuft offline.** Die Liste wird als Ganzes geholt und danach auf
  dem Gerät verglichen. Deshalb eine Sperrliste und nicht OCSP: bei OCSP ginge zu
  jedem geprüften Dokument eine eigene Anfrage hinaus.
- **Abschaltbar.** In den Einstellungen. Abgeschaltet greift die App auf nichts
  zu; bereits geholte Listen bleiben nutzbar, neue kommen keine dazu.
- Was der Betreiber der Verteilstelle dabei wie bei jedem Abruf sieht, ist die
  IP-Adresse des Geräts und der Zeitpunkt.

**Was die Sperrliste aussagt:** ob das Zertifikat, mit dem das Dokument signiert
wurde, zurückgezogen ist. **Nicht**, ob dieses Dokument als verloren oder
gestohlen gemeldet ist — solche Fahndungsbestände stehen keiner öffentlichen App
offen. Am Datensatz steht, wann geprüft wurde und welche Liste dabei vorlag.

Die Echtheitsprüfung selbst läuft weiter vollständig auf dem Gerät, gegen
mitgelieferte Zertifikate. Die verwendeten Programmbibliotheken sprechen nicht
nach außen; ein Prüfschritt beim Bauen bricht ab, wenn außerhalb der einen dafür
vorgesehenen Stelle ein Netzzugriff hinzukommt.

### Wann Daten die App verlassen

Nur, wenn der Benutzer sie ausdrücklich ausgibt, und nur an das Ziel, das er
dabei auswählt.

- Beim **Teilen** und beim **Kopieren** in die Zwischenablage sowie in der
  **JSON-Fassung** ist das Lichtbild nie enthalten. Ein in die Zwischenablage
  kopierter Text verfällt nach zwei Minuten von selbst.
- Beim **E-Mail-Versand der lesbaren Fassung** wird das Lichtbild mitgeschickt:
  eingebettet in den HTML-Text und als Anhang. Es wird dafür nicht auf den
  Datenträger geschrieben; die Nachricht erhält die Bilddaten unmittelbar.

Wohin eine so verschickte Nachricht gelangt und wie das Mailprogramm damit
umgeht, liegt außerhalb des Einflussbereichs dieser App.

### Berechtigungen

Die App verlangt zwei Berechtigungen:

- **NFC**, um den Chip zu lesen.
- **Kamera**, um das Dokument zu fotografieren. Wer den Schlüssel eintippt und
  keine Fahrerlaubnis erfasst, braucht sie nicht.

Sie verlangt keinen Zugriff auf Standort, Kontakte, Mikrofon, Fotobibliothek,
Kalender oder Gesundheitsdaten.

### Verantwortlich für die Datenverarbeitung

<<Name>>
<<E-Mail>>

### Rechte der betroffenen Person

Da die Daten das Gerät nicht verlassen und den Entwicklern nicht zugänglich sind,
kann Auskunft, Berichtigung oder Löschung nur durch die Person erfolgen, die das
Gerät bedient. Die Löschung erfolgt in der App oder automatisch nach 30 Tagen.

Verantwortlich für die Rechtmäßigkeit einer Identitätsfeststellung und für den
Umgang mit den dabei erhobenen Daten ist die Stelle oder die Person, die die App
einsetzt. Die App kann diese Verantwortung nicht übernehmen; sie sagt das beim
ersten Start und benennt dort auch, dass die Unterrichtung der betroffenen Person
dem Bediener obliegt und dass 30 Tage eine Vorgabe und kein Befund sind.

### Änderungen

Diese Erklärung beschreibt den Stand vom 21. August 2026 und gilt ab
Version 1.8 der iOS-Fassung. Bei Änderungen am Verhalten der App wird sie
angepasst — zuletzt für die Datenminimierung und für den Abruf der Sperrliste.
