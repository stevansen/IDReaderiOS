# Informativa sulla privacy — Italiano

Testo di origine della pagina pubblicata per la versione iOS. Conservato qui per
poterlo confrontare: **un'informativa sulla privacy deve corrispondere al
comportamento della versione effettivamente pubblicata.**

Adattata dall'informativa Android (`apps/cie-reader/store/privacy-policy-it.md`
nel repository Android). Tre cose sono dovute cambiare, e tutte tre sono promesse:

1. **L'autorizzazione alla fotocamera.** La versione Android fotografa tramite
   l'app fotocamera di sistema e quindi non ne ha bisogno. Su iOS questa strada
   non esiste — `NSCameraUsageDescription` è inevitabile. La frase «non richiede
   l'autorizzazione alla fotocamera» sarebbe falsa qui, esattamente nel punto in
   cui l'informativa fa una promessa.
2. **«Nessuna autorizzazione a internet»** non è un concetto su iOS. La promessa
   resta la stessa, la sua motivazione è diversa.
3. **La patente di guida** è stata aggiunta dopo l'ultima revisione di questo
   testo. Non ha chip; i suoi dati provengono dal riconoscimento del testo, che è
   un dato di natura diversa.

Chi modifica questo testo deve aggiornare la pagina pubblicata e accanto a essa le
versioni tedesca e inglese.

**Nessun segnaposto residuo.** Il testo è completo; perché non contenga un
indirizzo di contatto è argomentato nella sezione sul titolare.

Tutto ciò che segue la linea è il testo da pubblicare.

---

## Informativa sulla privacy

**IDReader** legge i dati memorizzati sul chip di un documento di identità via NFC
e verifica che il documento sia autentico. Sono supportate la carta di identità
elettronica italiana (CIE 3.0) e i passaporti secondo ICAO 9303. La patente di
guida italiana non ha chip; i suoi dati vengono letti da una fotografia — si veda
la sezione dedicata.

### Quali dati tratta l'app

Per la carta di identità e il passaporto esclusivamente i dati presenti sul chip
del documento appoggiato:

- Nome e cognome, data di nascita, luogo di nascita, sesso, cittadinanza
- Numero del documento, date di emissione e scadenza, ente di emissione
- Residenza e codice fiscale
- La fotografia, se si sceglie la lettura completa

Quali di questi dati siano effettivamente presenti lo decide il documento. Un
passaporto di norma non riporta né residenza né codice fiscale; luogo di nascita,
ente di emissione e data di emissione possono mancare.

Le impronte digitali **non** vengono lette. Si trovano in un gruppo di dati
protetto da Extended Access Control, che richiede il certificato di un sistema di
ispezione. L'app non ne ha e non ne chiede.

**Sulla fotografia:** sulla carta di identità italiana e nel passaporto è in
**JPEG 2000**. iOS 26 sa leggere questo formato; l'app mostra l'immagine e la
conserva cifrata come gli altri campi. Se un formato non è leggibile, l'app mostra
al suo posto il formato rilevato, invece di non mostrare nulla in silenzio.

La fotografia lascia il dispositivo **soltanto** con l'invio per e-mail della
versione leggibile, e per questo viene ridimensionata e convertita in un normale
JPEG. Non è mai contenuta in una copia negli appunti né nella versione JSON.

### Presupposto di ogni lettura

Il chip non rilascia nulla finché non viene aperto con una chiave stampata sul
documento stesso. Questa chiave viene digitata oppure fotografata dal documento:

- **Carta di identità:** il CAN di sei cifre sul fronte della carta.
- **Passaporto:** numero, data di nascita e data di scadenza dalla pagina dei
  dati.

Senza il documento in mano l'app non può leggere nulla. La chiave non viene
conservata, con un'eccezione: il CAN viene salvato insieme al record affinché la
stessa carta venga riconosciuta. Per il passaporto questo non avviene, perché lì
la chiave è composta da dati personali.

### Quando si fotografa

Invece di digitare la chiave, si può leggerla dal documento: sulla carta di
identità le sei cifre in basso a destra sul fronte, sul passaporto le due righe in
basso sulla pagina dei dati. Per la patente la fotografia è l'unica fonte. Per
tutti questi casi:

- L'app necessita dell'**autorizzazione alla fotocamera**. A differenza della
  versione Android, che fotografa tramite l'app di sistema, su iOS non è
  evitabile. Senza l'autorizzazione resta la digitazione.
- L'immagine **non viene conservata**. Resta in memoria finché il riconoscimento
  non è terminato e poi viene abbandonata. Non entra nella libreria foto e non
  tocca mai il disco.
- Il **riconoscimento del testo avviene sul dispositivo**, con il riconoscimento
  di immagini del sistema operativo. Nulla viene scaricato e nulla trasmesso.
- Per la carta di identità e il passaporto dal testo riconosciuto viene estratta
  soltanto la chiave di accesso. Tutto il resto che fosse leggibile nell'immagine
  viene scartato.

La digitazione resta pienamente possibile. Chi non vuole fotografare non deve.

### La patente è diversa

Non ha chip, non ha zona a lettura ottica, non ha cifra di controllo. I suoi dati —
nome, data e luogo di nascita, date di emissione e scadenza, numero, categorie ed
ente di emissione — provengono esclusivamente dal riconoscimento del testo di una
fotografia e **non sono confermati**: né i valori, né il documento, né che sia
stato fotografato un documento di questo tipo.

Per questo tutti i campi sono modificabili, e per questo un record di questo tipo
riporta, nell'app e in ogni esportazione, la riserva che qui nulla è stato
verificato. Per questi dati vale tutto il resto di questa informativa: restano sul
dispositivo, cifrati, e si cancellano dopo 30 giorni.

### Cosa viene mostrato e non conservato

Quattro dati sono mostrati finché il record è sullo schermo e **non vengono scritti
nell'archivio**: residenza, codice fiscale, professione e telefono. La domanda alla
base è se un caso d'uso abbia ancora bisogno del campo dopo che il documento è
tornato al titolare; per questi quattro la risposta è no. Chi ha bisogno di un
indirizzo lo legge una volta e lo trascrive.

Il record ricorda **quali** di questi campi il documento riportava, non il loro
contenuto. Per questo più tardi si legge «letto, non conservato» e non «non nel
documento»: quest'ultima sarebbe un'affermazione sul documento che non è vera.

Perché la stessa persona resti un'unica voce anche dopo il rilascio di un nuovo
documento, dal codice fiscale si ricava un'**impronta**, con una chiave derivata
da quella dell'archivio che non lascia il dispositivo. Il codice fiscale stesso non
viene conservato e non è ricavabile dall'impronta.

Questa minimizzazione si può **disattivare** nelle impostazioni («Conservare tutti
i campi»): in tal caso i quattro campi vengono conservati ed esportati. È
**attiva per impostazione predefinita**, e al momento di disattivarla l'app
avverte che chi conserva tutto deve poter indicare la finalità dei campi
aggiuntivi e risponderne — la minimizzazione dei dati è un obbligo del titolare,
non un'impostazione di un programma. La modifica vale dalla lettura successiva;
quanto già omesso è cancellato.

### Dove restano i dati

I dati letti restano **esclusivamente sul dispositivo**. Sono cifrati con AES-256;
la chiave si trova nel portachiavi del dispositivo, è limitata a questo
dispositivo, non viene inclusa in alcun backup e può essere usata solo a
dispositivo sbloccato.

Il file dell'archivio stesso è escluso dal backup iCloud e da quello sul computer e
porta la protezione file del sistema operativo.

**30 giorni** dopo la lettura i dati vengono cancellati automaticamente. Prima
possono essere cancellati nell'app in qualsiasi momento.

Nel commutatore delle app non compare alcuna immagine dell'ultimo record mostrato.

### L'unico accesso alla rete: la lista di revoca

L'app non trasmette **alcun dato personale** — né agli sviluppatori né a terzi.
Non c'è alcuno strumento di analisi, nessuna pubblicità e nessun tracciamento, e
nessun server degli sviluppatori con cui l'app comunichi.

Un accesso alla rete lo fa, e soltanto questo: scarica la **lista di revoca
pubblica** dei certificati presso l'ente che la pubblica — per i documenti
italiani il Ministero dell'Interno. L'indirizzo è indicato nei certificati
inclusi nell'app. Al riguardo:

- **Non esce nulla sul documento.** Viene scaricato un file pubblico, come si
  carica una pagina web. Nessun dato del documento, nessun identificativo del
  dispositivo, nessuna indicazione che sia stata fatta una lettura.
- **Mai durante una lettura.** Lo scaricamento avviene all'avvio dell'app e
  quando lo richiedete nelle impostazioni. Altrimenti il momento della richiesta
  sarebbe esso stesso un'informazione.
- **Il confronto avviene offline.** La lista viene scaricata per intero e
  confrontata sul dispositivo. Per questo una lista di revoca e non OCSP: con
  OCSP uscirebbe una richiesta per ogni singolo documento verificato.
- **Si può disattivare.** Nelle impostazioni. Disattivato, l'app non accede a
  nulla; le liste già scaricate restano utilizzabili, non ne arrivano di nuove.
- Quello che il gestore del punto di distribuzione vede, come per qualsiasi
  scaricamento, è l'indirizzo IP del dispositivo e l'orario.

**Cosa dice la lista di revoca:** se il certificato con cui il documento è stato
firmato è stato ritirato. **Non** se questo documento è stato segnalato come
perduto o rubato — banche dati di quel tipo non sono accessibili a un'app
pubblica. Su ogni record è indicato quando è stata fatta la verifica e quale lista
era disponibile.

La verifica di autenticità in sé continua a svolgersi interamente sul
dispositivo, con i certificati inclusi. Le librerie utilizzate non comunicano
verso l'esterno; un controllo in fase di compilazione fallisce se un accesso alla
rete compare al di fuori dell'unico punto previsto.
### Quando i dati escono dall'app

Solo quando l'utente li esporta esplicitamente, e solo verso la destinazione che
sceglie in quel momento.

- Nella **condivisione**, nella **copia** negli appunti e nella versione **JSON**
  la fotografia non è mai inclusa. Un testo copiato negli appunti scade da sé dopo
  due minuti.
- Nell'**invio per e-mail della versione leggibile** la fotografia viene inviata:
  incorporata nel testo HTML e come allegato. Per questo non viene scritta sul
  disco; il messaggio riceve i dati dell'immagine direttamente.

Dove arrivi un messaggio così inviato e come lo tratti il programma di posta è
fuori dal controllo di questa app.

### Il registro diagnostico

In Impostazioni → Diagnostica si trova il registro dell'ultima lettura: i comandi
inviati al chip e le sue risposte. Risiede **solo nella memoria di lavoro**, viene
sovrascritto a ogni nuova lettura, non compare in alcun file né in alcun backup e
si perde alla chiusura dell'app.

Non contiene **dati personali**, e non per intenzione ma per un bivio collocato
nell'unico punto attraversato da ogni comando: finché la connessione al chip non è
protetta, vi compare l'intero traffico — selezione dell'applet, identificativi di
protocollo, chiavi effimere e valori casuali. Da quando è protetta, restano solo
intestazione del comando, lunghezze e parole di stato. È lì che passano i dati
personali. Vi compaiono inoltre i nomi dei **certificati** coinvolti: sono enti
emittenti, non persone.

Il registro lascia il dispositivo solo se lo copia e lo invia lei stesso.

### Autorizzazioni

L'app richiede due autorizzazioni:

- **NFC**, per leggere il chip.
- **Fotocamera**, per fotografare il documento. Chi digita la chiave e non
  acquisisce patenti non ne ha bisogno.

Non richiede accesso a posizione, contatti, microfono, libreria foto, calendario o
dati sulla salute.

### Titolare del trattamento

**Non lo sviluppatore.** I dati letti non lasciano il dispositivo; non esiste
alcun server dello sviluppatore, nessuno strumento di analisi e nessuna
trasmissione a terzi. Lo sviluppatore non tratta quindi alcun dato personale
proveniente da quest'app e non ha accesso ad alcuno di essi, nemmeno su richiesta.

Titolare del trattamento ai sensi del Regolamento generale sulla protezione dei
dati è l'ente o la persona **che utilizza l'app** per leggere un documento.
Determina finalità e mezzi del trattamento, informa l'interessato e risponde alle
richieste di accesso, rettifica e cancellazione.

Per questo qui **non compare un indirizzo di contatto per i diritti
dell'interessato**: un indirizzo in questo punto affermerebbe una competenza che
non esiste e allontanerebbe la richiesta da chi può rispondervi. Chi ha esibito il
documento si rivolge a chi lo ha letto.

Le domande sull'app stessa e su questa informativa vanno al registro delle
segnalazioni del repository del codice sorgente:
<https://github.com/stevansen/IDReaderiOS/issues>.

### Diritti dell'interessato

Poiché i dati non lasciano il dispositivo e non sono accessibili agli
sviluppatori, l'accesso, la rettifica o la cancellazione possono essere effettuati
soltanto dalla persona che utilizza il dispositivo. La cancellazione avviene
nell'app o automaticamente dopo 30 giorni.

La responsabilità della liceità di un accertamento di identità e del trattamento
dei dati così raccolti spetta all'ente o alla persona che impiega l'app. L'app non
può assumersi questa responsabilità; lo dice al primo avvio, e lì indica anche che
l'informazione all'interessato spetta a chi la utilizza e che 30 giorni sono un
valore predefinito e non un accertamento.

### Modifiche

Questa informativa descrive lo stato al 22 agosto 2026 e vale dalla versione 1.8
della release iOS. Sarà aggiornata in caso di modifiche al comportamento dell'app —
da ultimo per la minimizzazione dei dati, per lo scaricamento della lista di
revoca e per il registro diagnostico.
