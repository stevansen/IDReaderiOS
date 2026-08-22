# Arbeitsauftrag: den Lesekern der App auf DH-PACE umbauen

Dieser Auftrag ist das Gegenstück zu [`MIGRATION_PROMPT.md`](MIGRATION_PROMPT.md).
Der lautete „portiere die Android-App". Dieser lautet: **bring das Lesen zum
Laufen, und zwar für die Dokumente, die es wirklich zu lesen gibt.**

Grundlage sind [`docs/EU-EID-STANDARDS.md`](docs/EU-EID-STANDARDS.md) (Recherche
und Messungen) und [`docs/NFC-PACE.md`](docs/NFC-PACE.md) (der Weg dorthin, samt
meiner Irrwege). Wer diesen Auftrag ausführt, sollte beide gelesen haben — vor
allem die Irrwege, damit sie nicht wiederholt werden.

---

## Der Stand, in vier Sätzen

Italienische Karte **und** Reisepass verlangen
`id-PACE-DH-GM-3DES-CBC-CBC`, Parametersatz 2 (DH über 2048 Bit), Generic
Mapping. Sie bieten in `EF.CardAccess` nichts anderes an. Schritt 1 und 2 von
PACE laufen inzwischen durch — Schritt 2 aber nur mit einem **selbst gebauten**
erweiterten APDU, weil `NFCISO7816APDU(…, expectedResponseLength:)` für
Datenfelder über 255 Byte etwas erzeugt, das die Karte mit `6C00` abweist.
Schritt 3 und 4 haben in der vendorierten Lesebibliothek **keinen DH-Zweig** und
scheitern mit „Failed to generate EC key".

---

## Auftrag 1: den DH-Zweig in PACE fertigstellen

**Das ist die einzige Aufgabe, die das Lesen freischaltet. Alles andere in diesem
Papier ist nachrangig.**

In `ThirdParty/NFCPassportReaderCAN/Sources/PACEHandler.swift`:

* `doStep3KeyExchange` erzeugt bedingungslos ein `EC_KEY` aus
  `EVP_PKEY_get0_EC_KEY(ephemeralParams)`. Bei DH ist das `NULL`. Es braucht
  einen zweiten Zweig: aus den abgebildeten Domänenparametern (die
  `doDHMappingAgreement` schon als `EVP_PKEY` vom Typ DH/DHX zurückgibt) ein
  DH-Schlüsselpaar erzeugen, den öffentlichen Teil mit **Tag `0x83`** senden und
  den des Chips unter **Tag `0x84`** auspacken.
* `doStep4KeyAgreement` ebenso: `DH_compute_key` statt `ECDH_compute_key`, und
  der Authentisierungstoken über den öffentlichen Schlüssel des Chips, kodiert
  wie in `encodePublicKey` — dort ist der DH-Fall (Tag `0x84`) **schon**
  behandelt, das ist ein Anhaltspunkt für die Kodierung.

Prüfsteine, alle am Gerät ablesbar:

| Erwartung | Wo sie im Protokoll steht |
|---|---|
| Schritt 3 sendet `7C … 83 82 01 00 <256B>` | `→ 10 86 00 00 7C8201048382…` |
| Chip antwortet `7C … 84 82 01 00 <256B>` | `← SW 9000 7C820104 8482…` |
| Schritt 4 sendet den Token mit Tag `0x85`, 8 Byte | `→ 00 86 00 00 7C0A8508…` |
| Chip antwortet mit Tag `0x86` | `← SW 9000 7C0A8608…` |
| danach `· PACE erfolgreich` | Wegmarke |

**Nicht raten.** Es gibt jetzt ein APDU-Protokoll in der App (Einstellungen →
Diagnose); jede Vermutung ist dort in einem Kartenkontakt zu prüfen. Ich habe an
dieser Stelle fünfmal danebengelegen, weil ich je Bau eine Vermutung ausgeliefert
habe statt zu messen.

## Auftrag 2: das erweiterte APDU aufräumen

`TagReader.rawExtended` baut die Bytes selbst, und das ist **bewiesen richtig**.
Die sechs Übertragungsformen und die Probierschleife in `doPACE` waren ein
Messinstrument, kein Entwurf.

* Die Probierschleife entfernen. Es bleibt: Datenfeld > 255 Byte → selbst
  gebautes erweitertes APDU (Fall 4E, mit `00 00` als Le). Das ist die Form, die
  geantwortet hat.
* `TagReader.Oversized` und die fünf unterlegenen Formen löschen — samt der
  Verkettung, die `6A80` bekam. Was gemessen wurde, gehört in
  `docs/NFC-PACE.md`, nicht in den Code.
* Prüfen, ob **jedes** APDU über 255 Byte diesen Weg nimmt, nicht nur PACE
  Schritt 2. Beim Lesen von DG2 (Lichtbild) kommen große Antworten, nicht große
  Befehle — aber Chip Authentication sendet ebenfalls öffentliche Schlüssel.

## Auftrag 3: die vier Fehler in der Lesebibliothek nach oben melden

`ThirdParty/NFCPassportReaderCAN/UPSTREAM.md` hält sie fest. Es sind Fehler in
`AndyQ/NFCPassportReader`, nicht in unserem Gebrauch davon:

1. Statusprüfung `if rep.sw1 != 0x90 && rep.sw2 != 0x00` — ein **Und** statt
   eines Oder. Jedes Statuswort mit `00` als zweitem Byte rutschte durch.
2. `6C xx` wird nicht behandelt, nur `61 xx`.
3. Der PACE-Fehler wird abgefangen und verworfen; bei einer CAN, die keinen
   BAC-Rückfall hat, bleibt danach keine Auskunft übrig.
4. PACE Schritt 3 und 4 ohne DH-Zweig, obwohl Schritt 2 einen hat.

**Einen Pull Request aufmachen.** Nicht aus Höflichkeit: solange das ein Fork
ist, trägt dieses Repository die Wartung, und `UPSTREAM.patch` wächst mit jeder
fremden Fassung. Punkt 1 und 2 sind klein, allgemein richtig und ohne unseren
Sonderfall verständlich — die haben die besten Aussichten.

## Auftrag 4: die Diagnose behalten, aber einordnen

Das Protokoll (`App/NFC/ReadLog.swift`, `ReadTrail.swift`) hat diese Suche
entschieden und **bleibt**. Aber es ist jetzt gebaut, um einen Fehler zu finden,
und sollte gebaut sein, um einen zu berichten:

* Der Puffer hält zwei Läufe. Für einen gelungenen Lesevorgang ist das viel; für
  eine Fehlersuche wenig. Ein Schalter „ausführliches Protokoll" wäre besser als
  eine feste Grenze — **Vorgabe aus.**
* Die Weiche in `TagReader.send` (vor der gesicherten Verbindung alles, danach
  nur Längen) ist der Kern der Zusage und darf **nicht** verwässert werden.
  Wer sie ändert, ändert eine Aussage in der Datenschutzerklärung.
* Ein Protokoll, das per Zwischenablage geht, ist für Tester richtig und für
  Benutzer falsch. Vor einer öffentlichen Freigabe gehört es hinter eine
  Absicht — nicht in die erste Ebene der Einstellungen.

## Auftrag 5: was nach dem Lesen zu prüfen ist

Sobald PACE durchläuft, ist **nichts** von der übrigen Kette am echten Chip
belegt. Alles darunter wurde nur gegen erfundene Datensätze getestet:

* Passive Authentication gegen die neun mitgelieferten CSCA-Zertifikate. Trifft
  das Dokumentenzertifikat der CIE eines davon?
* Chip Authentication mit DH — dieselbe Falle wie bei PACE, dieselbe Bibliothek.
* DG2, das Lichtbild: **JPEG 2000**, und iOS bringt keinen Decoder mit. Bis
  OpenJPEG eingebunden ist, zeigt die App das erkannte Format. Der erste echte
  Lesevorgang wird das sichtbar machen.
* Die Sperrprüfung gegen `CRL_CSCA.crl` — bisher nur mit erfundenen
  Ausstellerabdrücken geprüft.
* Der Personenabdruck aus der Steuernummer und die Regel „ein Eintrag pro
  Person" — an echten Daten nie gelaufen.

## Was nicht Teil des Auftrags ist

* **Keine eigene Kryptografie.** Die Begründung steht in `docs/NFC-PACE.md` und
  gilt unverändert.
* **Kein Umbau auf die EUDI Wallet.** Sie ist der Weg der EU und löst genau das
  Problem, an dem der Chip scheitert (selektive Offenlegung), aber eine App, die
  ein vorgelegtes Dokument prüft, braucht 2026 den Chip. Der Zusammenhang gehört
  in die Dokumentation, nicht in diese Fassung.
* **Keine neuen Datenfelder.** Die Datenminimierung ist eine Entscheidung, nicht
  ein Zwischenstand.

## Die Arbeitsweise, um die ich bitte

Aus siebzehn Bauten gelernt, und teuer bezahlt:

1. **Erst messen, dann ändern.** Eine Vermutung je Bau kostete jeweils Bauen,
   Hochladen, Verarbeiten, einen Kartenkontakt und eine Rückmeldung. Sechs
   Formen in einem Kontakt zu probieren hat die Frage in einem Durchgang
   entschieden. Wenn eine Frage offen ist, baue das Instrument, nicht die
   Antwort.
2. **Release bauen, nicht nur Debug.** Ein `#if DEBUG` an der falschen Stelle
   übersetzt im Debug-Bau und im Release nicht. `Scripts/archive.sh` hat dafür
   jetzt einen eigenen Schritt.
3. **Aus dem signierten Bau prüfen**, nicht aus dem Quelltext schließen.
   Entitlement, AIDs, Fassungsnummer, Sprachdateien — alles stand schon einmal
   anders im Bundle als im Projekt.
4. **Was die App über sich sagt, steht an zwölf Stellen.** Drei Mal ist hier eine
   Zusage geändert worden und zwei Stellen blieben falsch stehen — einmal
   sogar bis in den Store. Wer eine Zusage ändert, sucht nicht nach dem Wort,
   sondern nach jeder Stelle, an der die App über sich spricht.
5. **Einen Irrweg aufschreiben, nicht wegräumen.** `docs/NFC-PACE.md` nennt jede
   falsche Vermutung samt Statuswort. Das hat mehr Zeit gespart als jede
   richtige.
