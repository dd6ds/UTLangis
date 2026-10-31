#!/usr/bin/env python3
"""Fills i18n/ubsignal_de.ts with the German translations below.

Workflow when texts change:
  1. lupdate (see README, "Translations") to refresh the .ts file
  2. add the new English texts to DE below
  3. python3 i18n/translate_de.py   - fails and lists any text still missing
"""
import sys
import xml.etree.ElementTree as ET

DE = {
    # --- common --------------------------------------------------------------
    "Back": "Zurück",
    "OK": "OK",
    "Settings": "Einstellungen",
    "Starting...": "Wird gestartet...",
    "Unknown contact": "Unbekannter Kontakt",
    "Phone number, e.g. +491701234567": "Telefonnummer, z. B. +491701234567",
    # --- appearance ----------------------------------------------------------
    "Appearance": "Darstellung",
    "Like the phone": "Wie das Telefon",
    "Light": "Hell",
    "Dark": "Dunkel",
    # --- registration --------------------------------------------------------
    "Set up Signal": "Signal einrichten",
    "ubSignal becomes the Signal app for your number on this phone. Signal on another "
    "phone with the same number will be signed out.":
        "ubSignal wird auf diesem Telefon die Signal-App für deine Nummer. Signal auf "
        "einem anderen Telefon mit derselben Nummer wird abgemeldet.",
    "If you set a Signal PIN with registration lock, turn the lock off in your old "
    "Signal app first.":
        "Falls du eine Signal-PIN mit Registrierungssperre hast, schalte die Sperre "
        "vorher in deiner alten Signal-App aus.",
    "Call me instead of sending an SMS": "Anrufen statt SMS senden",
    "Continue": "Weiter",
    "Captcha": "Captcha",
    "or paste the signalcaptcha:// link": "oder den signalcaptcha://-Link einfügen",
    "Enter the code Signal sent to %1.": "Gib den Code ein, den Signal an %1 gesendet hat.",
    "Verification code": "Bestätigungscode",
    "Confirm": "Bestätigen",
    "Request a new code": "Neuen Code anfordern",
    "Enter the code": "Code eingeben",
    "Signal asks for a captcha. Please solve it again.":
        "Signal verlangt ein Captcha. Bitte löse es noch einmal.",
    "Signal does not send a code right now. Try again later or ask for a call.":
        "Signal sendet gerade keinen Code. Versuche es später noch einmal oder lass "
        "dich anrufen.",
    "The code was not accepted. Please request a new one.":
        "Der Code wurde nicht angenommen. Bitte fordere einen neuen an.",
    "Please enter the number in international format, e.g. +491701234567.":
        "Bitte gib die Nummer im internationalen Format ein, z. B. +491701234567.",
    # --- profile -------------------------------------------------------------
    "Your name": "Dein Name",
    "This name is shown to the people you write to.":
        "Diesen Namen sehen die Leute, denen du schreibst.",
    "Name": "Name",
    "Profile name saved": "Profilname gespeichert",
    "Change profile name": "Profilnamen ändern",
    # --- chats ---------------------------------------------------------------
    "Connected": "Verbunden",
    "Not connected": "Nicht verbunden",
    "New chat": "Neuer Chat",
    "No chats yet. Tap + to write to a phone number.":
        "Noch keine Chats. Tippe auf +, um einer Telefonnummer zu schreiben.",
    "Looking up...": "Wird gesucht...",
    "Start chat": "Chat starten",
    "This number does not use Signal.": "Diese Nummer nutzt kein Signal.",
    "Choose from contacts": "Aus Kontakten wählen",
    "or enter a phone number": "oder Telefonnummer eingeben",
    # --- contacts ------------------------------------------------------------
    "Access contacts?": "Zugriff auf Kontakte?",
    "ubSignal would like to read your address book so you can pick the person to "
    "write to.":
        "ubSignal möchte dein Adressbuch lesen, damit du auswählen kannst, wem du "
        "schreibst.",
    "Your contacts stay on this phone. Only the number you choose is looked up at "
    "Signal. You can change this later in Settings.":
        "Deine Kontakte bleiben auf diesem Telefon. Nur die Nummer, die du auswählst, "
        "wird bei Signal nachgeschlagen. Du kannst das später in den Einstellungen "
        "ändern.",
    "Allow": "Erlauben",
    "Don't allow": "Nicht erlauben",
    "Access to contacts is off. You can allow it in Settings.":
        "Der Zugriff auf Kontakte ist aus. Du kannst ihn in den Einstellungen erlauben.",
    "Allow access to contacts": "Zugriff auf Kontakte erlauben",
    "Contacts": "Kontakte",
    "Search": "Suchen",
    "No contacts found.": "Keine Kontakte gefunden.",
    # --- chat ----------------------------------------------------------------
    "Message": "Nachricht",
    "Send": "Senden",
    "Attach photo": "Foto anhängen",
    "Remove photo": "Foto entfernen",
    "Send a photo from": "Foto senden aus",
    "Attachment": "Anhang",
    "New message": "Neue Nachricht",
    # --- settings ------------------------------------------------------------
    "Registered number: %1": "Registrierte Nummer: %1",
    "Ubuntu Touch pauses apps in the background, so new messages arrive when ubSignal "
    "is open. To be notified while it is in the background, prevent app suspension "
    "for ubSignal (e.g. with UT Tweak Tool).":
        "Ubuntu Touch pausiert Apps im Hintergrund, daher kommen neue Nachrichten an, "
        "wenn ubSignal geöffnet ist. Um auch im Hintergrund benachrichtigt zu werden, "
        "verhindere das Pausieren für ubSignal (z. B. mit dem UT Tweak Tool).",
}

TS = "i18n/ubsignal_de.ts"
tree = ET.parse(TS)
missing = []
for msg in tree.iter("message"):
    src = msg.find("source").text
    tr = msg.find("translation")
    if src in DE:
        tr.text = DE[src]
        tr.attrib.pop("type", None)        # drop type="unfinished"
    else:
        missing.append(src)

if missing:
    print("Missing German translations:")
    for m in sorted(set(missing)):
        print("  ", repr(m))
    sys.exit(1)

tree.write(TS, encoding="utf-8", xml_declaration=True)
print(f"{TS}: all texts translated")
