# Hilfe / Support / Assistenza

**IDReader** liest den Chip italienischer Identitätskarten (CIE 3.0) und von
Reisepässen über NFC und prüft, ob das Dokument echt ist. Der italienische
Führerschein wird aus einem Foto erfasst.

Fragen und Fehlermeldungen: **[ein Issue in diesem Repository](https://github.com/stevansen/IDReaderiOS/issues)**.

---

## Deutsch

### Was Sie brauchen

Ein iPhone mit NFC — **iPhone 7 oder neuer** — und iOS 17. Für den Chip eine
**CIE 3.0** oder einen Reisepass mit dem Chipsymbol auf dem Einband. Ausweise in
Papierform haben keinen Chip und lassen sich nicht lesen.

### Häufige Fälle

**„Kein NFC verfügbar"** — das Gerät hat keine NFC-Hardware. Im Simulator steht
diese Meldung immer; das ist richtig.

**„CAN stimmt nicht"** — die sechs Ziffern stehen auf der **Vorderseite unten
rechts**. Sie haben keine Prüfziffer, ein Tippfehler fällt also erst beim Lesen
auf. Die CAN ist ein nicht sperrendes Passwort: ein Fehlversuch kostet nichts als
den Fehlversuch.

**„Verbindung unterbrochen"** — die Karte muss während des ganzen Vorgangs
ruhig liegen. Legen Sie das Telefon flach hin und die Karte darauf. Die
NFC-Antenne sitzt bei den meisten iPhones im oberen Drittel der Rückseite. Mit
Lichtbild dauert das Lesen 10 bis 20 Sekunden.

**„Diese Karte unterstützt PACE nicht"** — dann ist es keine CIE 3.0.

**Das Lichtbild bleibt leer.** Bekannt und noch offen: auf der italienischen Karte
liegt es als JPEG 2000 vor, und iOS bringt dafür keinen Decoder mit. Die App zeigt
an dieser Stelle das erkannte Format an, statt stillschweigend nichts zu zeigen.

**Die Erkennung liest ein Feld falsch.** Beim Führerschein sind alle Felder frei
bearbeitbar, und das ist Absicht: es gibt dort keine Prüfziffer und keinen Chip,
der widerspricht. Halten Sie jedes Feld gegen das Dokument.

### Was die App nicht tut

Sie überträgt nichts. Es gibt keinen Netzzugriff, kein Analysewerkzeug, keine
Werbung, kein Tracking. Gelesene Daten liegen verschlüsselt auf dem Gerät und
löschen sich nach 30 Tagen.

---

## English

### What you need

An iPhone with NFC — **iPhone 7 or later** — and iOS 17. For the chip, a
**CIE 3.0** or a passport with the chip symbol on the cover. Paper documents have
no chip and cannot be read.

### Common cases

**"No NFC available"** — the device has no NFC hardware. In the simulator this
message always appears, and it is correct.

**"Wrong CAN"** — the six digits are at the **bottom right of the front**. They
carry no check digit, so a typo only shows when the card is read. The CAN is a
non-blocking password: a failed attempt costs nothing but the attempt.

**"Connection interrupted"** — the card must stay still throughout. Lay the phone
flat and the card on top. On most iPhones the NFC antenna sits in the upper third
of the back. Reading with the photograph takes 10 to 20 seconds.

**"This card does not support PACE"** — then it is not a CIE 3.0.

**The facial image stays empty.** Known and still open: on the Italian card it is
JPEG 2000, and iOS ships no decoder for it. The app shows the detected format
instead of silently showing nothing.

**Recognition misreads a field.** On the driving licence every field can be
edited, deliberately: there is no check digit and no chip to contradict it. Check
each field against the document.

### What the app does not do

It transmits nothing. There is no network access, no analytics, no advertising, no
tracking. Data read stays encrypted on the device and deletes itself after 30 days.

---

## Italiano

### Cosa serve

Un iPhone con NFC — **iPhone 7 o successivo** — e iOS 17. Per il chip, una
**CIE 3.0** o un passaporto con il simbolo del chip sulla copertina. I documenti
cartacei non hanno chip e non possono essere letti.

### Casi frequenti

**«NFC non disponibile»** — il dispositivo non ha hardware NFC. Nel simulatore
questo messaggio compare sempre, ed è corretto.

**«CAN errato»** — le sei cifre sono **in basso a destra sul fronte**. Non hanno
cifra di controllo, quindi un errore di battitura si vede solo alla lettura. Il CAN
è una password che non blocca: un tentativo fallito non costa altro che il
tentativo.

**«Connessione interrotta»** — la carta deve restare ferma per tutta la lettura.
Appoggi il telefono in piano e la carta sopra. Sulla maggior parte degli iPhone
l'antenna NFC si trova nel terzo superiore del retro. Con la fotografia la lettura
richiede da 10 a 20 secondi.

**«Questa carta non supporta PACE»** — allora non è una CIE 3.0.

**La fotografia resta vuota.** Noto e ancora aperto: sulla carta italiana è in
JPEG 2000, e iOS non dispone di un decodificatore. L'app mostra il formato
rilevato invece di non mostrare nulla in silenzio.

**Il riconoscimento sbaglia un campo.** Sulla patente tutti i campi sono
modificabili, ed è voluto: non c'è cifra di controllo né chip che contraddica.
Confronti ogni campo con il documento.

### Cosa l'app non fa

Non trasmette nulla. Nessun accesso alla rete, nessuno strumento di analisi,
nessuna pubblicità, nessun tracciamento. I dati letti restano cifrati sul
dispositivo e si cancellano dopo 30 giorni.
