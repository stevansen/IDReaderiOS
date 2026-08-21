# Privacy policy — English

Source text for the page published for the iOS version. Kept here so it can be
diffed: **a privacy policy has to match the behaviour of the version actually
published.**

Adapted from the Android policy (`apps/cie-reader/store/privacy-policy-en.md` in
the Android repository). Three things had to change, and all three are promises:

1. **The camera permission.** The Android version photographs through the system
   camera app and therefore needs none. On iOS that route does not exist —
   `NSCameraUsageDescription` is unavoidable. "Requires no camera permission"
   would be false here, at exactly the point where the policy makes a promise.
2. **"No internet permission"** is not a concept on iOS. The promise stays the
   same; its justification is different.
3. **The driving licence** was added after the last revision of this text. It has
   no chip; its fields come from text recognition, which is a different kind of
   datum.

Anyone changing this text must update the published page and the German and
Italian versions alongside it.

**To fill in before publishing:** the places marked `<<…>>`.

Everything below the rule is the text to publish.

---

## Privacy policy

**IDReader** reads the data stored on the chip of an identity document over NFC
and verifies that the document is genuine. It supports the Italian electronic
identity card (CIE 3.0) and passports under ICAO 9303. The Italian driving licence
has no chip; its fields are read from a photograph — see the separate section.

### What data the app processes

For the identity card and the passport, only the data held on the chip of the
document presented:

- Given names and surname, date of birth, place of birth, sex, nationality
- Document number, dates of issue and expiry, issuing authority
- Residence and codice fiscale
- The facial image, if the full read mode is chosen

Which of these are actually present is decided by the document. A passport
usually carries neither residence nor codice fiscale; place of birth, issuing
authority and date of issue may be absent.

Fingerprints are **not** read. They sit in a data group protected by Extended
Access Control, which requires an inspection-system certificate. The app has none
and asks for none.

**On the facial image in this version:** on the Italian identity card it is JPEG
2000, and iOS ships no decoder for it. The app therefore cannot display it at
present and does not store it; it shows the detected format instead. Once a
decoder is in place the image will be processed as described, and this policy will
be updated before that happens.

### A precondition for every read

The chip releases nothing until it is opened with a key printed on the document
itself. That key is typed, or photographed off the document:

- **Identity card:** the six-digit CAN on the front of the card.
- **Passport:** passport number, date of birth and date of expiry from the data
  page.

Without the document in hand the app can read nothing. The key is not retained,
with one exception: the CAN is stored alongside the record so that the same card
is recognised again. For the passport this does not apply, because there the key
consists of personal data.

### When a photograph is taken

Instead of typing the key it can be read off the document: on the identity card
the six digits at the bottom right of the front, on the passport the two lines at
the bottom of the data page. For the driving licence the photograph is the only
source. For all of these:

- The app needs the **camera permission**. Unlike the Android version, which
  photographs through the system camera app, this cannot be avoided on iOS.
  Without the permission, typing remains.
- The image is **not stored**. It lives in memory until recognition is done and is
  then dropped. It does not enter the photo library and never touches disk.
- **Text recognition runs on the device**, using the operating system's own image
  recognition. Nothing is downloaded and nothing is transmitted.
- For the identity card and the passport, only the access key is taken from the
  recognised text. Everything else that might have been legible in the image is
  discarded.

Typing remains fully available. Nobody has to photograph anything.

### The driving licence is different

It has no chip, no machine readable zone and no check digit. Its fields — name,
date and place of birth, dates of issue and expiry, number, categories and issuing
authority — come solely from text recognition of a photograph and are **not
confirmed**: neither the values, nor the document, nor that such a document was
photographed at all.

That is why every field can be edited, and why such a record carries, in the app
and in every export, the caveat that nothing here has been checked. Everything
else in this policy applies to these fields as well: they stay on the device,
encrypted, and delete themselves after 30 days.

### What is shown and not kept

Four items are shown for as long as the record is on screen and are **not written
to the archive**: residence, codice fiscale, profession and telephone. The question
behind this is whether any use case still needs the field once the document is out
of your hand; for these four the answer is no. Whoever needs an address reads it
once and writes it down.

The record remembers **which** of these fields the document carried, not their
contents. That is why it later says "read, not stored" rather than "not in the
document" — the latter would be a statement about the document that is not true.

So that the same person stays a single entry even after a document is reissued, a
**digest** is derived from the codice fiscale using a key derived from the archive
key, which never leaves the device. The codice fiscale itself is not stored and
cannot be recovered from the digest.

This minimisation can be **switched off** in the settings ("Retain every field");
the four fields are then stored and exported along with the rest. It is **on by
default**, and when switching it off the app points out that whoever keeps
everything must be able to name the purpose the extra fields serve and answer for
it — data minimisation is an obligation on the controller, not a setting in a
program. The change takes effect from the next read; what was already left out is
gone.

### Where the data stays

The data read stays **on the device only**. It is encrypted with AES-256; the key
sits in the device's keychain, is confined to this device, is never included in a
backup, and can only be used while the device is unlocked.

The archive file itself is excluded from iCloud and computer backups and carries
the operating system's file protection.

**30 days** after the read the data is deleted automatically. Before that it can
be deleted in the app at any time.

No snapshot of the last record shown appears in the app switcher.

### No transmission

The app **does not access the network**. There is no network connection in its
source, and a check at build time fails if one appears. It transmits nothing —
neither to the developers nor to third parties. There is no analytics, no
advertising and no tracking.

The authenticity check also runs entirely offline, against certificates bundled
with the app; no directory and no revocation list is consulted. The libraries used
are part of the app and likewise do not talk outward.

### When data leaves the app

Only when the user explicitly exports it, and only to the destination chosen at
that moment.

- When **sharing**, when **copying** to the clipboard, and in the **JSON form**,
  the facial image is never included. Text copied to the clipboard expires by
  itself after two minutes.
- When the **readable form is sent by e-mail** the facial image travels with it:
  embedded in the HTML body and as an attachment. It is not written to disk for
  this; the message receives the image data directly.

Where such a message goes, and what the mail application does with it, is outside
the control of this app.

### Permissions

The app asks for two:

- **NFC**, to read the chip.
- **Camera**, to photograph the document. Anyone who types the key and captures no
  driving licence does not need it.

It asks for no access to location, contacts, microphone, photo library, calendar
or health data.

### Controller

<<Name>>
<<E-mail>>

### Rights of the data subject

Because the data never leaves the device and is not accessible to the developers,
access, correction or deletion can only be carried out by the person operating the
device. Deletion happens in the app or automatically after 30 days.

Responsibility for the lawfulness of an identity check, and for the handling of the
data collected in the process, rests with the organisation or person deploying the
app. The app cannot take that responsibility on; it says so on first launch, and
it names there that informing the data subject is the operator's duty and that 30
days is a default, not a finding.

### Changes

This policy describes the state as of 21 August 2026 and applies from version 1.8
of the iOS release. It will be updated when the behaviour of the app changes.
