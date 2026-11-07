#!/usr/bin/env python3
"""Fills i18n/utlangis_<lang>.ts with the translations below.

Workflow when texts change:
  1. lupdate (see README, "Translations") to refresh the .ts files
  2. add the new English texts to every language below
  3. python3 i18n/translate.py   - fails and lists any text still missing

English is the source language and has no translation file.
"""
import sys
import xml.etree.ElementTree as ET

# Long English texts, written once and used as keys in every language.
LINK_INTRO = 'Use the Signal account of your other phone on this one as well, like Signal Desktop. Both stay signed in.'
SCAN = 'On your other phone, open Signal → Settings → Linked devices, tap + and scan this code.'
LINKED = 'This phone is a linked device. The profile is managed on the phone the account was registered with.'
INTRO = ("UT Langis becomes the Signal app for your number on this phone. Signal on "
         "another phone with the same number will be signed out.")
REGLOCK = ("If you set a Signal PIN with registration lock, turn the lock off in your "
           "old Signal app first.")
BACKGROUND = ("Ubuntu Touch pauses apps in the background, so new messages arrive when "
              "UT Langis is open. To be notified while it is in the background, prevent "
              "app suspension for UT Langis (e.g. with UT Tweak Tool).")

DE = {
    "%1 / %2": "%1 / %2",
    "Edit": "Bearbeiten",
    "Edit message": "Nachricht bearbeiten",
    "edited": "bearbeitet",
    "Choose a contact from": "Kontakt auswählen aus",
    "Choose a number": "Nummer auswählen",
    "This contact has no phone number.": "Dieser Kontakt hat keine Telefonnummer.",
    "Phone number": 'Telefonnummer',
    "Link device": 'Gerät koppeln',
    LINK_INTRO: 'Nutze das Signal-Konto deines anderen Telefons auch auf diesem, wie Signal Desktop. Beide bleiben angemeldet.',
    "Show QR code": 'QR-Code anzeigen',
    SCAN: 'Öffne auf deinem anderen Telefon Signal → Einstellungen → Verknüpfte Geräte, tippe auf + und scanne diesen Code.',
    LINKED: 'Dieses Telefon ist ein verknüpftes Gerät. Das Profil wird auf dem Telefon verwaltet, mit dem das Konto registriert wurde.',
    "React with %1": "Mit %1 reagieren",
    "Keyboard": "Tastatur",
    "Emoji": "Emoji",
    "Rename": "Umbenennen",
    "Leave empty to use the name from the person's Signal profile.":
        "Leer lassen, um den Namen aus dem Signal-Profil der Person zu verwenden.",
    "Notifications": "Benachrichtigungen",
    "Notification sound": "Benachrichtigungston",
    "Phone default": "Standard des Telefons",
    "No sound": "Kein Ton",
    "Unmute": "Stummschaltung aufheben",
    "Mute": "Stummschalten",
    "Chat muted": "Chat stummgeschaltet",
    "Chat unmuted": "Stummschaltung aufgehoben",
    "Read": "Gelesen",
    "Delivered": "Zugestellt",
    "Sent": "Gesendet",
    "Send read receipts": "Lesebestätigungen senden",
    "Reply": "Antworten",
    "You": "Du",
    "Cancel reply": "Antwort abbrechen",
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
    INTRO: "UT Langis wird auf diesem Telefon die Signal-App für deine Nummer. Signal "
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
    "Message": "Nachricht",
    "Send": "Senden",
    "Attach photo": "Foto anhängen",
    "Remove photo": "Foto entfernen",
    "Send a photo from": "Foto senden aus",
    "Attachment": "Anhang",
    "New message": "Neue Nachricht",
    "Registered number: %1": "Registrierte Nummer: %1",
    BACKGROUND: "Ubuntu Touch pausiert Apps im Hintergrund, daher kommen neue "
                "Nachrichten an, wenn UT Langis geöffnet ist. Um auch im Hintergrund "
                "benachrichtigt zu werden, verhindere das Pausieren für UT Langis "
                "(z. B. mit dem UT Tweak Tool).",
}

FR = {
    "%1 / %2": "%1 / %2",
    "Edit": "Modifier",
    "Edit message": "Modifier le message",
    "edited": "modifié",
    "Choose a contact from": "Choisir un contact dans",
    "Choose a number": "Choisir un numéro",
    'This contact has no phone number.': "Ce contact n'a pas de numéro de téléphone.",
    "Phone number": 'Numéro de téléphone',
    "Link device": 'Associer un appareil',
    LINK_INTRO: 'Utilisez aussi sur ce téléphone le compte Signal de votre autre téléphone, comme Signal Desktop. Les deux restent connectés.',
    "Show QR code": 'Afficher le code QR',
    SCAN: 'Sur votre autre téléphone, ouvrez Signal → Paramètres → Appareils associés, touchez + et scannez ce code.',
    LINKED: 'Ce téléphone est un appareil associé. Le profil est géré sur le téléphone avec lequel le compte a été enregistré.',
    "React with %1": "Réagir avec %1",
    "Keyboard": "Clavier",
    "Emoji": "Emoji",
    "Rename": "Renommer",
    "Leave empty to use the name from the person's Signal profile.":
        "Laissez vide pour utiliser le nom du profil Signal de la personne.",
    "Notifications": "Notifications",
    "Notification sound": "Son de notification",
    "Phone default": "Son par défaut du téléphone",
    "No sound": "Aucun son",
    "Unmute": "Réactiver le son",
    "Mute": "Mettre en sourdine",
    "Chat muted": "Conversation en sourdine",
    "Chat unmuted": "Son réactivé",
    "Read": "Lu",
    "Delivered": "Distribué",
    "Sent": "Envoyé",
    "Send read receipts": "Envoyer les confirmations de lecture",
    "Reply": "Répondre",
    "You": "Vous",
    "Cancel reply": "Annuler la réponse",
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
    INTRO: "UT Langis devient l'application Signal de votre numéro sur ce téléphone. "
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
    "Message": "Message",
    "Send": "Envoyer",
    "Attach photo": "Joindre une photo",
    "Remove photo": "Retirer la photo",
    "Send a photo from": "Envoyer une photo depuis",
    "Attachment": "Pièce jointe",
    "New message": "Nouveau message",
    "Registered number: %1": "Numéro enregistré : %1",
    BACKGROUND: "Ubuntu Touch met les applications en pause en arrière-plan : les "
                "nouveaux messages arrivent quand UT Langis est ouvert. Pour être "
                "notifié en arrière-plan, empêchez la mise en pause d'UT Langis "
                "(p. ex. avec UT Tweak Tool).",
}

ES = {
    "%1 / %2": "%1 / %2",
    "Edit": "Editar",
    "Edit message": "Editar mensaje",
    "edited": "editado",
    "Choose a contact from": "Elegir un contacto de",
    "Choose a number": "Elegir un número",
    "This contact has no phone number.": "Este contacto no tiene número de teléfono.",
    "Phone number": 'Número de teléfono',
    "Link device": 'Vincular dispositivo',
    LINK_INTRO: 'Usa también en este teléfono la cuenta de Signal de tu otro teléfono, como Signal Desktop. Ambos siguen conectados.',
    "Show QR code": 'Mostrar código QR',
    SCAN: 'En tu otro teléfono, abre Signal → Ajustes → Dispositivos vinculados, toca + y escanea este código.',
    LINKED: 'Este teléfono es un dispositivo vinculado. El perfil se gestiona en el teléfono con el que se registró la cuenta.',
    "React with %1": "Reaccionar con %1",
    "Keyboard": "Teclado",
    "Emoji": "Emoji",
    "Rename": "Cambiar nombre",
    "Leave empty to use the name from the person's Signal profile.":
        "Déjalo vacío para usar el nombre del perfil de Signal de la persona.",
    "Notifications": "Notificaciones",
    "Notification sound": "Sonido de notificación",
    "Phone default": "Predeterminado del teléfono",
    "No sound": "Sin sonido",
    "Unmute": "Activar sonido",
    "Mute": "Silenciar",
    "Chat muted": "Chat silenciado",
    "Chat unmuted": "Chat con sonido",
    "Read": "Leído",
    "Delivered": "Entregado",
    "Sent": "Enviado",
    "Send read receipts": "Enviar confirmaciones de lectura",
    "Reply": "Responder",
    "You": "Tú",
    "Cancel reply": "Cancelar respuesta",
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
    INTRO: "UT Langis se convierte en la app de Signal de tu número en este teléfono. "
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
    "Message": "Mensaje",
    "Send": "Enviar",
    "Attach photo": "Adjuntar foto",
    "Remove photo": "Quitar foto",
    "Send a photo from": "Enviar una foto desde",
    "Attachment": "Adjunto",
    "New message": "Nuevo mensaje",
    "Registered number: %1": "Número registrado: %1",
    BACKGROUND: "Ubuntu Touch pausa las apps en segundo plano, así que los mensajes "
                "nuevos llegan cuando UT Langis está abierta. Para recibir avisos en "
                "segundo plano, impide que UT Langis se pause (p. ej. con UT Tweak "
                "Tool).",
}

IT = {
    "%1 / %2": "%1 / %2",
    "Edit": "Modifica",
    "Edit message": "Modifica messaggio",
    "edited": "modificato",
    "Choose a contact from": "Scegli un contatto da",
    "Choose a number": "Scegli un numero",
    "This contact has no phone number.": "Questo contatto non ha un numero di telefono.",
    "Phone number": 'Numero di telefono',
    "Link device": 'Collega dispositivo',
    LINK_INTRO: "Usa anche su questo telefono l'account Signal dell'altro telefono, come Signal Desktop. Entrambi restano connessi.",
    "Show QR code": 'Mostra codice QR',
    SCAN: "Sull'altro telefono apri Signal → Impostazioni → Dispositivi collegati, tocca + e scansiona questo codice.",
    LINKED: "Questo telefono è un dispositivo collegato. Il profilo si gestisce sul telefono con cui è stato registrato l'account.",
    "React with %1": "Reagisci con %1",
    "Keyboard": "Tastiera",
    "Emoji": "Emoji",
    "Rename": "Rinomina",
    "Leave empty to use the name from the person's Signal profile.":
        "Lascia vuoto per usare il nome del profilo Signal della persona.",
    "Notifications": "Notifiche",
    "Notification sound": "Suono di notifica",
    "Phone default": "Predefinito del telefono",
    "No sound": "Nessun suono",
    "Unmute": "Riattiva audio",
    "Mute": "Silenzia",
    "Chat muted": "Chat silenziata",
    "Chat unmuted": "Audio riattivato",
    "Read": "Letto",
    "Delivered": "Consegnato",
    "Sent": "Inviato",
    "Send read receipts": "Invia conferme di lettura",
    "Reply": "Rispondi",
    "You": "Tu",
    "Cancel reply": "Annulla risposta",
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
    INTRO: "UT Langis diventa l'app Signal del tuo numero su questo telefono. Signal "
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
    "Message": "Messaggio",
    "Send": "Invia",
    "Attach photo": "Allega foto",
    "Remove photo": "Rimuovi foto",
    "Send a photo from": "Invia una foto da",
    "Attachment": "Allegato",
    "New message": "Nuovo messaggio",
    "Registered number: %1": "Numero registrato: %1",
    BACKGROUND: "Ubuntu Touch mette in pausa le app in background, quindi i nuovi "
                "messaggi arrivano quando UT Langis è aperta. Per ricevere notifiche in "
                "background, impedisci la sospensione di UT Langis (ad es. con UT "
                "Tweak Tool).",
}

DEVICE_TEXTS = [('The camera is not available: %1', 'Die Kamera ist nicht verfügbar: %1', 'La caméra n’est pas disponible : %1', 'La cámara no está disponible: %1', 'La fotocamera non è disponibile: %1'), ('The device was linked.', 'Das Gerät wurde gekoppelt.', 'L’appareil a été relié.', 'El dispositivo se ha vinculado.', 'Il dispositivo è stato collegato.'), ('Back', 'Zurück', 'Retour', 'Atrás', 'Indietro'), ('Linking the device …', 'Gerät wird gekoppelt …', 'Liaison de l’appareil …', 'Vinculando el dispositivo …', 'Collegamento del dispositivo …'), ('Point the camera at the QR code shown by Signal Desktop ("Link new device").', 'Richte die Kamera auf den QR-Code, den Signal Desktop anzeigt („Neues Gerät koppeln“).', 'Pointez la caméra vers le code QR affiché par Signal Desktop (« Relier un nouvel appareil »).', 'Apunta la cámara al código QR que muestra Signal Desktop («Vincular nuevo dispositivo»).', 'Inquadra il codice QR mostrato da Signal Desktop («Collega nuovo dispositivo»).'), ('Hold the phone still, with the code filling the white frame.', 'Halte das Telefon ruhig, sodass der Code den weißen Rahmen ausfüllt.', 'Tenez le téléphone immobile, le code remplissant le cadre blanc.', 'Mantén el teléfono quieto, con el código llenando el marco blanco.', 'Tieni fermo il telefono, con il codice che riempie la cornice bianca.'), ('Turn camera sound off', 'Kameraton ausschalten', 'Couper le son de l’appareil photo', 'Desactivar el sonido de la cámara', 'Disattiva il suono della fotocamera'), ('Turn camera sound on', 'Kameraton einschalten', 'Activer le son de l’appareil photo', 'Activar el sonido de la cámara', 'Attiva il suono della fotocamera'), ('Camera sound when scanning QR codes', 'Kameraton beim Scannen von QR-Codes', 'Son de l’appareil photo lors du scan de codes QR', 'Sonido de la cámara al escanear códigos QR', 'Suono della fotocamera durante la scansione dei codici QR'), ('The photo could not be edited.', 'Das Foto konnte nicht bearbeitet werden.', 'La photo n’a pas pu être modifiée.', 'No se pudo editar la foto.', 'Impossibile modificare la foto.'), ('Crop', 'Zuschneiden', 'Recadrer', 'Recortar', 'Ritaglia'), ('Turn left', 'Nach links drehen', 'Tourner à gauche', 'Girar a la izquierda', 'Ruota a sinistra'), ('Turn right', 'Nach rechts drehen', 'Tourner à droite', 'Girar a la derecha', 'Ruota a destra'), ('Reset', 'Zurücksetzen', 'Réinitialiser', 'Restablecer', 'Ripristina'), ('Done', 'Fertig', 'Terminé', 'Listo', 'Fatto'), ('Crop photo', 'Foto zuschneiden', 'Recadrer la photo', 'Recortar la foto', 'Ritaglia la foto'), ('Crop and send', 'Zuschneiden und senden', 'Recadrer et envoyer', 'Recortar y enviar', 'Ritaglia e invia'), ('📞 Incoming video call', '📞 Eingehender Videoanruf', '📞 Appel vidéo entrant', '📞 Videollamada entrante', '📞 Videochiamata in arrivo'), ('📞 Incoming call', '📞 Eingehender Anruf', '📞 Appel entrant', '📞 Llamada entrante', '📞 Chiamata in arrivo'), ('📞 Missed video call', '📞 Verpasster Videoanruf', '📞 Appel vidéo manqué', '📞 Videollamada perdida', '📞 Videochiamata persa'), ('📞 Missed call', '📞 Verpasster Anruf', '📞 Appel manqué', '📞 Llamada perdida', '📞 Chiamata persa'), ('Missed video call', 'Verpasster Videoanruf', 'Appel vidéo manqué', 'Videollamada perdida', 'Videochiamata persa'), ('Missed call', 'Verpasster Anruf', 'Appel manqué', 'Llamada perdida', 'Chiamata persa'), ('Declined video call', 'Abgelehnter Videoanruf', 'Appel vidéo refusé', 'Videollamada rechazada', 'Videochiamata rifiutata'), ('Declined call', 'Abgelehnter Anruf', 'Appel refusé', 'Llamada rechazada', 'Chiamata rifiutata'), ('Call answered on another device', 'Anruf auf einem anderen Gerät angenommen', 'Appel pris sur un autre appareil', 'Llamada respondida en otro dispositivo', 'Chiamata accettata su un altro dispositivo'), ('Call declined on another device', 'Anruf auf einem anderen Gerät abgelehnt', 'Appel refusé sur un autre appareil', 'Llamada rechazada en otro dispositivo', 'Chiamata rifiutata su un altro dispositivo'), ('Video call', 'Videoanruf', 'Appel vidéo', 'Videollamada', 'Videochiamata'), ('Call', 'Anruf', 'Appel', 'Llamada', 'Chiamata'), ('Incoming video call', 'Eingehender Videoanruf', 'Appel vidéo entrant', 'Videollamada entrante', 'Videochiamata in arrivo'), ('Incoming call', 'Eingehender Anruf', 'Appel entrant', 'Llamada entrante', 'Chiamata in arrivo'), ('UT Langis cannot answer calls yet. Answer it on another device (e.g. Signal Desktop) or decline it.', 'UT Langis kann Anrufe noch nicht annehmen. Nimm ihn auf einem anderen Gerät an (z. B. Signal Desktop) oder lehne ihn ab.', 'UT Langis ne peut pas encore répondre aux appels. Répondez sur un autre appareil (p. ex. Signal Desktop) ou refusez l’appel.', 'UT Langis aún no puede responder llamadas. Respóndela en otro dispositivo (p. ej. Signal Desktop) o recházala.', 'UT Langis non può ancora rispondere alle chiamate. Rispondi su un altro dispositivo (es. Signal Desktop) o rifiutala.'), ('Decline', 'Ablehnen', 'Refuser', 'Rechazar', 'Rifiuta'), ('Let it ring', 'Weiterklingeln lassen', 'Laisser sonner', 'Dejar sonar', 'Lascia squillare'), ('Open or save with', 'Öffnen oder speichern mit', 'Ouvrir ou enregistrer avec', 'Abrir o guardar con', 'Apri o salva con'), ('The video cannot be played: %1', 'Das Video kann nicht abgespielt werden: %1', 'La vidéo ne peut pas être lue : %1', 'No se puede reproducir el vídeo: %1', 'Impossibile riprodurre il video: %1'), ('Open or save with another app', 'Mit einer anderen App öffnen oder speichern', 'Ouvrir ou enregistrer avec une autre app', 'Abrir o guardar con otra app', 'Apri o salva con un’altra app'), ('Pause', 'Pause', 'Pause', 'Pausa', 'Pausa'), ('Play', 'Abspielen', 'Lire', 'Reproducir', 'Riproduci'), ('Video', 'Video', 'Vidéo', 'Vídeo', 'Video'), ('Play video', 'Video abspielen', 'Lire la vidéo', 'Reproducir vídeo', 'Riproduci video'), ('Today', 'Heute', 'Aujourd’hui', 'Hoy', 'Oggi'), ('Yesterday', 'Gestern', 'Hier', 'Ayer', 'Ieri'), ('No chats yet. Tap ✎ to start one.', 'Noch keine Chats. Tippe auf ✎, um einen zu beginnen.', 'Aucune conversation pour l’instant. Touchez ✎ pour en commencer une.', 'Aún no hay chats. Toca ✎ para empezar uno.', 'Ancora nessuna chat. Tocca ✎ per iniziarne una.'), ('Stop recording', 'Aufnahme beenden', 'Arrêter l’enregistrement', 'Detener la grabación', 'Interrompi la registrazione'), ('Listen to recording', 'Aufnahme anhören', 'Écouter l’enregistrement', 'Escuchar la grabación', 'Ascolta la registrazione'), ('Quieter', 'Leiser', 'Plus bas', 'Más bajo', 'Più basso'), ('Louder', 'Lauter', 'Plus fort', 'Más alto', 'Più alto'), ('quieter', 'leiser', 'plus bas', 'más bajo', 'più basso'), ('louder', 'lauter', 'plus fort', 'más alto', 'più alto'), ('Microphone gain for voice messages', 'Mikrofon-Verstärkung für Sprachnachrichten', 'Gain du micro pour les messages vocaux', 'Ganancia del micrófono para mensajes de voz', 'Guadagno del microfono per i messaggi vocali'), ('Volume of voice messages', 'Lautstärke von Sprachnachrichten', 'Volume des messages vocaux', 'Volumen de los mensajes de voz', 'Volume dei messaggi vocali'), ('Reply', 'Antworten', 'Répondre', 'Responder', 'Rispondi'), ('React with %1', 'Mit %1 reagieren', 'Réagir avec %1', 'Reaccionar con %1', 'Reagisci con %1'), ('Join with another chat', 'Mit anderem Chat zusammenführen', 'Fusionner avec une autre conversation', 'Unir con otro chat', 'Unisci a un’altra chat'), ("This chat was started with a phone number. If the person's replies appear in another chat, pick it: both chats become one.", 'Dieser Chat wurde mit einer Telefonnummer begonnen. Wenn die Antworten der Person in einem anderen Chat landen, wähle ihn aus: Beide Chats werden zu einem.', 'Cette conversation a été commencée avec un numéro de téléphone. Si les réponses de la personne apparaissent dans une autre conversation, choisissez-la : les deux n’en feront plus qu’une.', 'Este chat se inició con un número de teléfono. Si las respuestas de la persona aparecen en otro chat, elígelo: ambos chats se unirán.', 'Questa chat è stata avviata con un numero di telefono. Se le risposte della persona compaiono in un’altra chat, sceglila: le due chat diventeranno una.'), ('Answer', 'Annehmen', 'Répondre', 'Contestar', 'Rispondi'), ('Calling …', 'Anruf wird aufgebaut …', 'Appel en cours …', 'Llamando …', 'Chiamata in corso …'), ('Ringing …', 'Klingelt …', 'Ça sonne …', 'Sonando …', 'Squilla …'), ('Connecting …', 'Verbinde …', 'Connexion …', 'Conectando …', 'Connessione …'), ('Call ended', 'Anruf beendet', 'Appel terminé', 'Llamada finalizada', 'Chiamata terminata'), ('Microphone on', 'Mikrofon an', 'Micro activé', 'Micrófono activado', 'Microfono attivo'), ('Microphone off', 'Mikrofon aus', 'Micro coupé', 'Micrófono desactivado', 'Microfono disattivato'), ('Hang up', 'Auflegen', 'Raccrocher', 'Colgar', 'Riaggancia'), ('Loudspeaker on', 'Lautsprecher an', 'Haut-parleur activé', 'Altavoz activado', 'Altoparlante attivo'), ('Loudspeaker off', 'Lautsprecher aus', 'Haut-parleur désactivé', 'Altavoz desactivado', 'Altoparlante disattivato'), ('Microphone gain (voice messages and calls)', 'Mikrofon-Verstärkung (Sprachnachrichten und Anrufe)', 'Gain du micro (messages vocaux et appels)', 'Ganancia del micrófono (mensajes de voz y llamadas)', 'Guadagno del microfono (messaggi vocali e chiamate)'), ('Video call', 'Videoanruf', 'Appel vidéo', 'Videollamada', 'Videochiamata'), ('Camera off', 'Kamera aus', 'Caméra désactivée', 'Cámara desactivada', 'Fotocamera spenta'), ('Camera on', 'Kamera an', 'Caméra activée', 'Cámara activada', 'Fotocamera accesa'), ('Link device?', 'Gerät koppeln?', 'Relier l’appareil ?', '¿Vincular el dispositivo?', 'Collegare il dispositivo?'), ('The other device will be able to read and send your messages. Only link devices that belong to you.', 'Das andere Gerät kann deine Nachrichten lesen und senden. Kopple nur Geräte, die dir gehören.', 'L’autre appareil pourra lire et envoyer vos messages. Ne reliez que des appareils qui vous appartiennent.', 'El otro dispositivo podrá leer y enviar tus mensajes. Vincula solo dispositivos que te pertenezcan.', 'L’altro dispositivo potrà leggere e inviare i tuoi messaggi. Collega solo dispositivi che ti appartengono.'), ('Linked devices', 'Gekoppelte Geräte', 'Appareils reliés', 'Dispositivos vinculados', 'Dispositivi collegati'), ('Link new device (scan QR code)', 'Neues Gerät koppeln (QR-Code scannen)', 'Relier un nouvel appareil (scanner le code QR)', 'Vincular nuevo dispositivo (escanear código QR)', 'Collega nuovo dispositivo (scansiona codice QR)'), ('Loading …', 'Wird geladen …', 'Chargement …', 'Cargando …', 'Caricamento …'), ('This phone', 'Dieses Telefon', 'Ce téléphone', 'Este teléfono', 'Questo telefono'), ('Device %1', 'Gerät %1', 'Appareil %1', 'Dispositivo %1', 'Dispositivo %1'), ('Last active: %1', 'Zuletzt aktiv: %1', 'Dernière activité : %1', 'Última actividad: %1', 'Ultima attività: %1'), ('Unlink', 'Entkoppeln', 'Délier', 'Desvincular', 'Scollega'), ('Unlink device?', 'Gerät entkoppeln?', 'Délier l’appareil ?', '¿Desvincular el dispositivo?', 'Scollegare il dispositivo?'), ('The device will no longer receive or send your messages.', 'Das Gerät kann dann keine Nachrichten mehr empfangen oder senden.', 'L’appareil ne recevra ni n’enverra plus vos messages.', 'El dispositivo ya no recibirá ni enviará tus mensajes.', 'Il dispositivo non riceverà né invierà più i tuoi messaggi.'), ('Linked devices (e.g. Signal Desktop)', 'Gekoppelte Geräte (z. B. Signal Desktop)', 'Appareils reliés (p. ex. Signal Desktop)', 'Dispositivos vinculados (p. ej. Signal Desktop)', 'Dispositivi collegati (es. Signal Desktop)'), ('This QR code is not a Signal code for linking a device.', 'Dieser QR-Code ist kein Signal-Code zum Koppeln eines Geräts.', 'Ce code QR n’est pas un code Signal pour relier un appareil.', 'Este código QR no es un código de Signal para vincular un dispositivo.', 'Questo codice QR non è un codice Signal per collegare un dispositivo.')]

# Linked devices (QR scanner).
for _src, *_tr in DEVICE_TEXTS:
    DE.setdefault(_src, _tr[0])
for _src, *_tr in DEVICE_TEXTS:
    FR.setdefault(_src, _tr[1])
for _src, *_tr in DEVICE_TEXTS:
    ES.setdefault(_src, _tr[2])
for _src, *_tr in DEVICE_TEXTS:
    IT.setdefault(_src, _tr[3])

LANGUAGES = {"de": DE, "fr": FR, "es": ES, "it": IT}


def translate(code, texts):
    path = f"i18n/utlangis_{code}.ts"
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
