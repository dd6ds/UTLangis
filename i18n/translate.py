#!/usr/bin/env python3
"""Fills i18n/ubsignal_<lang>.ts with the translations below.

Workflow when texts change:
  1. lupdate (see README, "Translations") to refresh the .ts files
  2. add the new English texts to every language below
  3. python3 i18n/translate.py   - fails and lists any text still missing

English is the source language and has no translation file.
"""
import sys
import xml.etree.ElementTree as ET

# Long English texts, written once and used as keys in every language.
INTRO = ("ubSignal becomes the Signal app for your number on this phone. Signal on "
         "another phone with the same number will be signed out.")
REGLOCK = ("If you set a Signal PIN with registration lock, turn the lock off in your "
           "old Signal app first.")
CONTACTS_ASK = ("ubSignal would like to read your address book so you can pick the "
                "person to write to.")
CONTACTS_PRIVACY = ("Your contacts stay on this phone. Only the number you choose is "
                    "looked up at Signal. You can change this later in Settings.")
BACKGROUND = ("Ubuntu Touch pauses apps in the background, so new messages arrive when "
              "ubSignal is open. To be notified while it is in the background, prevent "
              "app suspension for ubSignal (e.g. with UT Tweak Tool).")

DE = {
    "Close": "Schließen",
    "Audio could not be recorded or played: %1": "Audio konnte nicht aufgenommen oder abgespielt werden: %1",
    "Discard recording": "Aufnahme verwerfen",
    "Play voice message": "Sprachnachricht abspielen",
    "Record voice message": "Sprachnachricht aufnehmen",
    "Recording %1": "Aufnahme %1",
    "Recording too short": "Aufnahme zu kurz",
    "Stop": "Stopp",
    "Delete message?": "Nachricht löschen?",
    "Delete for me": "Für mich löschen",
    "Delete for everyone": "Für alle löschen",
    "Cancel": "Abbrechen",
    "Back": "Zurück",
    "OK": "OK",
    "Settings": "Einstellungen",
    "Starting...": "Wird gestartet...",
    "Unknown contact": "Unbekannter Kontakt",
    "Phone number, e.g. +491701234567": "Telefonnummer, z. B. +491701234567",
    "Language": "Sprache",
    "Appearance": "Darstellung",
    "Like the phone": "Wie das Telefon",
    "Light": "Hell",
    "Dark": "Dunkel",
    "Set up Signal": "Signal einrichten",
    INTRO: "ubSignal wird auf diesem Telefon die Signal-App für deine Nummer. Signal "
           "auf einem anderen Telefon mit derselben Nummer wird abgemeldet.",
    REGLOCK: "Falls du eine Signal-PIN mit Registrierungssperre hast, schalte die "
             "Sperre vorher in deiner alten Signal-App aus.",
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
    "Your name": "Dein Name",
    "This name is shown to the people you write to.":
        "Diesen Namen sehen die Leute, denen du schreibst.",
    "Name": "Name",
    "Profile name saved": "Profilname gespeichert",
    "Change profile name": "Profilnamen ändern",
    "Connected": "Verbunden",
    "Not connected": "Nicht verbunden",
    "New chat": "Neuer Chat",
    "No chats yet. Tap + to write to a phone number.":
        "Noch keine Chats. Tippe auf +, um einer Telefonnummer zu schreiben.",
    "Choose from contacts": "Aus Kontakten wählen",
    "or enter a phone number": "oder Telefonnummer eingeben",
    "Looking up...": "Wird gesucht...",
    "Start chat": "Chat starten",
    "This number does not use Signal.": "Diese Nummer nutzt kein Signal.",
    "Access contacts?": "Zugriff auf Kontakte?",
    CONTACTS_ASK: "ubSignal möchte dein Adressbuch lesen, damit du auswählen kannst, "
                  "wem du schreibst.",
    CONTACTS_PRIVACY: "Deine Kontakte bleiben auf diesem Telefon. Nur die Nummer, die du "
                      "auswählst, wird bei Signal nachgeschlagen. Du kannst das später "
                      "in den Einstellungen ändern.",
    "Allow": "Erlauben",
    "Don't allow": "Nicht erlauben",
    "Access to contacts is off. You can allow it in Settings.":
        "Der Zugriff auf Kontakte ist aus. Du kannst ihn in den Einstellungen erlauben.",
    "Allow access to contacts": "Zugriff auf Kontakte erlauben",
    "Contacts": "Kontakte",
    "Search": "Suchen",
    "No contacts found.": "Keine Kontakte gefunden.",
    "Message": "Nachricht",
    "Send": "Senden",
    "Attach photo": "Foto anhängen",
    "Remove photo": "Foto entfernen",
    "Send a photo from": "Foto senden aus",
    "Attachment": "Anhang",
    "New message": "Neue Nachricht",
    "Registered number: %1": "Registrierte Nummer: %1",
    BACKGROUND: "Ubuntu Touch pausiert Apps im Hintergrund, daher kommen neue "
                "Nachrichten an, wenn ubSignal geöffnet ist. Um auch im Hintergrund "
                "benachrichtigt zu werden, verhindere das Pausieren für ubSignal "
                "(z. B. mit dem UT Tweak Tool).",
}

FR = {
    "Close": "Fermer",
    'Audio could not be recorded or played: %1': "Impossible d'enregistrer ou de lire l'audio : %1",
    'Discard recording': "Supprimer l'enregistrement",
    "Play voice message": "Écouter le message vocal",
    "Record voice message": "Enregistrer un message vocal",
    "Recording %1": "Enregistrement %1",
    "Recording too short": "Enregistrement trop court",
    "Stop": "Arrêter",
    "Delete message?": "Supprimer le message ?",
    "Delete for me": "Supprimer pour moi",
    "Delete for everyone": "Supprimer pour tout le monde",
    "Cancel": "Annuler",
    "Back": "Retour",
    "OK": "OK",
    "Settings": "Paramètres",
    "Starting...": "Démarrage...",
    "Unknown contact": "Contact inconnu",
    "Phone number, e.g. +491701234567": "Numéro de téléphone, p. ex. +33612345678",
    "Language": "Langue",
    "Appearance": "Apparence",
    "Like the phone": "Comme le téléphone",
    "Light": "Clair",
    "Dark": "Sombre",
    "Set up Signal": "Configurer Signal",
    INTRO: "ubSignal devient l'application Signal de votre numéro sur ce téléphone. "
           "Signal sera déconnecté sur tout autre téléphone utilisant le même numéro.",
    REGLOCK: "Si vous avez défini un code PIN Signal avec verrou d'inscription, "
             "désactivez d'abord le verrou dans votre ancienne application Signal.",
    "Call me instead of sending an SMS": "M'appeler au lieu d'envoyer un SMS",
    "Continue": "Continuer",
    "Captcha": "Captcha",
    "or paste the signalcaptcha:// link": "ou collez le lien signalcaptcha://",
    "Enter the code Signal sent to %1.": "Saisissez le code que Signal a envoyé au %1.",
    "Verification code": "Code de vérification",
    "Confirm": "Confirmer",
    "Request a new code": "Demander un nouveau code",
    "Enter the code": "Saisir le code",
    "Signal asks for a captcha. Please solve it again.":
        "Signal demande un captcha. Veuillez le résoudre à nouveau.",
    "Signal does not send a code right now. Try again later or ask for a call.":
        "Signal n'envoie pas de code pour le moment. Réessayez plus tard ou demandez "
        "un appel.",
    "The code was not accepted. Please request a new one.":
        "Le code n'a pas été accepté. Veuillez en demander un nouveau.",
    "Please enter the number in international format, e.g. +491701234567.":
        "Veuillez saisir le numéro au format international, p. ex. +33612345678.",
    "Your name": "Votre nom",
    "This name is shown to the people you write to.":
        "Ce nom est affiché aux personnes à qui vous écrivez.",
    "Name": "Nom",
    "Profile name saved": "Nom de profil enregistré",
    "Change profile name": "Modifier le nom de profil",
    "Connected": "Connecté",
    "Not connected": "Non connecté",
    "New chat": "Nouvelle conversation",
    "No chats yet. Tap + to write to a phone number.":
        "Aucune conversation. Touchez + pour écrire à un numéro de téléphone.",
    "Choose from contacts": "Choisir dans les contacts",
    "or enter a phone number": "ou saisir un numéro de téléphone",
    "Looking up...": "Recherche...",
    "Start chat": "Démarrer la conversation",
    "This number does not use Signal.": "Ce numéro n'utilise pas Signal.",
    "Access contacts?": "Accéder aux contacts ?",
    CONTACTS_ASK: "ubSignal souhaite lire votre carnet d'adresses pour que vous puissiez "
                  "choisir la personne à qui écrire.",
    CONTACTS_PRIVACY: "Vos contacts restent sur ce téléphone. Seul le numéro choisi est "
                      "recherché auprès de Signal. Vous pourrez modifier cela plus tard "
                      "dans les paramètres.",
    "Allow": "Autoriser",
    "Don't allow": "Ne pas autoriser",
    "Access to contacts is off. You can allow it in Settings.":
        "L'accès aux contacts est désactivé. Vous pouvez l'autoriser dans les paramètres.",
    "Allow access to contacts": "Autoriser l'accès aux contacts",
    "Contacts": "Contacts",
    "Search": "Rechercher",
    "No contacts found.": "Aucun contact trouvé.",
    "Message": "Message",
    "Send": "Envoyer",
    "Attach photo": "Joindre une photo",
    "Remove photo": "Retirer la photo",
    "Send a photo from": "Envoyer une photo depuis",
    "Attachment": "Pièce jointe",
    "New message": "Nouveau message",
    "Registered number: %1": "Numéro enregistré : %1",
    BACKGROUND: "Ubuntu Touch met les applications en pause en arrière-plan : les "
                "nouveaux messages arrivent quand ubSignal est ouvert. Pour être "
                "notifié en arrière-plan, empêchez la mise en pause d'ubSignal "
                "(p. ex. avec UT Tweak Tool).",
}

ES = {
    "Close": "Cerrar",
    "Audio could not be recorded or played: %1": "No se pudo grabar o reproducir el audio: %1",
    "Discard recording": "Descartar grabación",
    "Play voice message": "Reproducir mensaje de voz",
    "Record voice message": "Grabar mensaje de voz",
    "Recording %1": "Grabando %1",
    "Recording too short": "Grabación demasiado corta",
    "Stop": "Detener",
    "Delete message?": "¿Eliminar mensaje?",
    "Delete for me": "Eliminar para mí",
    "Delete for everyone": "Eliminar para todos",
    "Cancel": "Cancelar",
    "Back": "Atrás",
    "OK": "Aceptar",
    "Settings": "Ajustes",
    "Starting...": "Iniciando...",
    "Unknown contact": "Contacto desconocido",
    "Phone number, e.g. +491701234567": "Número de teléfono, p. ej. +34612345678",
    "Language": "Idioma",
    "Appearance": "Apariencia",
    "Like the phone": "Como el teléfono",
    "Light": "Claro",
    "Dark": "Oscuro",
    "Set up Signal": "Configurar Signal",
    INTRO: "ubSignal se convierte en la app de Signal de tu número en este teléfono. "
           "Signal se cerrará en cualquier otro teléfono con el mismo número.",
    REGLOCK: "Si tienes un PIN de Signal con bloqueo de registro, desactiva primero el "
             "bloqueo en tu antigua app de Signal.",
    "Call me instead of sending an SMS": "Llamarme en lugar de enviar un SMS",
    "Continue": "Continuar",
    "Captcha": "Captcha",
    "or paste the signalcaptcha:// link": "o pega el enlace signalcaptcha://",
    "Enter the code Signal sent to %1.": "Introduce el código que Signal envió al %1.",
    "Verification code": "Código de verificación",
    "Confirm": "Confirmar",
    "Request a new code": "Solicitar un código nuevo",
    "Enter the code": "Introducir el código",
    "Signal asks for a captcha. Please solve it again.":
        "Signal pide un captcha. Resuélvelo de nuevo.",
    "Signal does not send a code right now. Try again later or ask for a call.":
        "Signal no envía ningún código ahora mismo. Inténtalo más tarde o pide una "
        "llamada.",
    "The code was not accepted. Please request a new one.":
        "El código no fue aceptado. Solicita uno nuevo.",
    "Please enter the number in international format, e.g. +491701234567.":
        "Introduce el número en formato internacional, p. ej. +34612345678.",
    "Your name": "Tu nombre",
    "This name is shown to the people you write to.":
        "Este nombre lo ven las personas a las que escribes.",
    "Name": "Nombre",
    "Profile name saved": "Nombre de perfil guardado",
    "Change profile name": "Cambiar nombre de perfil",
    "Connected": "Conectado",
    "Not connected": "Sin conexión",
    "New chat": "Nuevo chat",
    "No chats yet. Tap + to write to a phone number.":
        "Aún no hay chats. Toca + para escribir a un número de teléfono.",
    "Choose from contacts": "Elegir de los contactos",
    "or enter a phone number": "o introduce un número de teléfono",
    "Looking up...": "Buscando...",
    "Start chat": "Iniciar chat",
    "This number does not use Signal.": "Este número no usa Signal.",
    "Access contacts?": "¿Acceder a los contactos?",
    CONTACTS_ASK: "ubSignal quiere leer tu agenda para que puedas elegir a quién "
                  "escribir.",
    CONTACTS_PRIVACY: "Tus contactos se quedan en este teléfono. Solo se consulta en "
                      "Signal el número que elijas. Puedes cambiarlo más tarde en "
                      "Ajustes.",
    "Allow": "Permitir",
    "Don't allow": "No permitir",
    "Access to contacts is off. You can allow it in Settings.":
        "El acceso a los contactos está desactivado. Puedes permitirlo en Ajustes.",
    "Allow access to contacts": "Permitir el acceso a los contactos",
    "Contacts": "Contactos",
    "Search": "Buscar",
    "No contacts found.": "No se encontraron contactos.",
    "Message": "Mensaje",
    "Send": "Enviar",
    "Attach photo": "Adjuntar foto",
    "Remove photo": "Quitar foto",
    "Send a photo from": "Enviar una foto desde",
    "Attachment": "Adjunto",
    "New message": "Nuevo mensaje",
    "Registered number: %1": "Número registrado: %1",
    BACKGROUND: "Ubuntu Touch pausa las apps en segundo plano, así que los mensajes "
                "nuevos llegan cuando ubSignal está abierta. Para recibir avisos en "
                "segundo plano, impide que ubSignal se pause (p. ej. con UT Tweak "
                "Tool).",
}

IT = {
    "Close": "Chiudi",
    'Audio could not be recorded or played: %1': "Impossibile registrare o riprodurre l'audio: %1",
    "Discard recording": "Scarta registrazione",
    "Play voice message": "Riproduci messaggio vocale",
    "Record voice message": "Registra messaggio vocale",
    "Recording %1": "Registrazione %1",
    "Recording too short": "Registrazione troppo breve",
    "Stop": "Ferma",
    "Delete message?": "Eliminare il messaggio?",
    "Delete for me": "Elimina per me",
    "Delete for everyone": "Elimina per tutti",
    "Cancel": "Annulla",
    "Back": "Indietro",
    "OK": "OK",
    "Settings": "Impostazioni",
    "Starting...": "Avvio...",
    "Unknown contact": "Contatto sconosciuto",
    "Phone number, e.g. +491701234567": "Numero di telefono, ad es. +393401234567",
    "Language": "Lingua",
    "Appearance": "Aspetto",
    "Like the phone": "Come il telefono",
    "Light": "Chiaro",
    "Dark": "Scuro",
    "Set up Signal": "Configura Signal",
    INTRO: "ubSignal diventa l'app Signal del tuo numero su questo telefono. Signal "
           "verrà disconnesso su qualsiasi altro telefono con lo stesso numero.",
    REGLOCK: "Se hai impostato un PIN di Signal con blocco della registrazione, "
             "disattiva prima il blocco nella tua vecchia app Signal.",
    "Call me instead of sending an SMS": "Chiamami invece di inviare un SMS",
    "Continue": "Continua",
    "Captcha": "Captcha",
    "or paste the signalcaptcha:// link": "oppure incolla il link signalcaptcha://",
    "Enter the code Signal sent to %1.": "Inserisci il codice che Signal ha inviato al %1.",
    "Verification code": "Codice di verifica",
    "Confirm": "Conferma",
    "Request a new code": "Richiedi un nuovo codice",
    "Enter the code": "Inserisci il codice",
    "Signal asks for a captcha. Please solve it again.":
        "Signal richiede un captcha. Risolvilo di nuovo.",
    "Signal does not send a code right now. Try again later or ask for a call.":
        "Signal al momento non invia codici. Riprova più tardi o richiedi una "
        "chiamata.",
    "The code was not accepted. Please request a new one.":
        "Il codice non è stato accettato. Richiedine uno nuovo.",
    "Please enter the number in international format, e.g. +491701234567.":
        "Inserisci il numero in formato internazionale, ad es. +393401234567.",
    "Your name": "Il tuo nome",
    "This name is shown to the people you write to.":
        "Questo nome viene mostrato alle persone a cui scrivi.",
    "Name": "Nome",
    "Profile name saved": "Nome del profilo salvato",
    "Change profile name": "Cambia nome del profilo",
    "Connected": "Connesso",
    "Not connected": "Non connesso",
    "New chat": "Nuova chat",
    "No chats yet. Tap + to write to a phone number.":
        "Ancora nessuna chat. Tocca + per scrivere a un numero di telefono.",
    "Choose from contacts": "Scegli dai contatti",
    "or enter a phone number": "oppure inserisci un numero di telefono",
    "Looking up...": "Ricerca...",
    "Start chat": "Avvia chat",
    "This number does not use Signal.": "Questo numero non usa Signal.",
    "Access contacts?": "Accedere ai contatti?",
    CONTACTS_ASK: "ubSignal vorrebbe leggere la tua rubrica per permetterti di scegliere "
                  "a chi scrivere.",
    CONTACTS_PRIVACY: "I tuoi contatti restano su questo telefono. Solo il numero che "
                      "scegli viene cercato su Signal. Puoi cambiare questa scelta più "
                      "tardi nelle impostazioni.",
    "Allow": "Consenti",
    "Don't allow": "Non consentire",
    "Access to contacts is off. You can allow it in Settings.":
        "L'accesso ai contatti è disattivato. Puoi consentirlo nelle impostazioni.",
    "Allow access to contacts": "Consenti l'accesso ai contatti",
    "Contacts": "Contatti",
    "Search": "Cerca",
    "No contacts found.": "Nessun contatto trovato.",
    "Message": "Messaggio",
    "Send": "Invia",
    "Attach photo": "Allega foto",
    "Remove photo": "Rimuovi foto",
    "Send a photo from": "Invia una foto da",
    "Attachment": "Allegato",
    "New message": "Nuovo messaggio",
    "Registered number: %1": "Numero registrato: %1",
    BACKGROUND: "Ubuntu Touch mette in pausa le app in background, quindi i nuovi "
                "messaggi arrivano quando ubSignal è aperta. Per ricevere notifiche in "
                "background, impedisci la sospensione di ubSignal (ad es. con UT "
                "Tweak Tool).",
}

LANGUAGES = {"de": DE, "fr": FR, "es": ES, "it": IT}


def translate(code, texts):
    path = f"i18n/ubsignal_{code}.ts"
    tree = ET.parse(path)
    missing = []
    for message in tree.iter("message"):
        source = message.find("source").text
        translation = message.find("translation")
        if source in texts:
            translation.text = texts[source]
            translation.attrib.pop("type", None)  # drop type="unfinished"
        else:
            missing.append(source)
    tree.write(path, encoding="utf-8", xml_declaration=True)
    return path, missing


failed = False
for code, texts in LANGUAGES.items():
    path, missing = translate(code, texts)
    if missing:
        failed = True
        print(f"{path}: missing translations:")
        for text in sorted(set(missing)):
            print("  ", repr(text))
    else:
        print(f"{path}: all texts translated")
sys.exit(1 if failed else 0)
