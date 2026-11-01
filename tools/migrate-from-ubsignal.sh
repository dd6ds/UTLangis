#!/bin/sh
# One-time move from the app's old name (package "ubsignal") to "utlangis" on
# a phone connected over adb: installs UT Langis, copies the Signal account,
# chats, attachments and settings into its folders and removes the old app.
#
# Run from the project folder after building:  sh tools/migrate-from-ubsignal.sh
# The old folders stay as a backup until you delete them (printed at the end).
set -e

PHONE_HOME=/home/phablet

adb get-state >/dev/null

echo "Installing UT Langis"
clickable install

echo "Copying data"
adb shell "set -e
  lomiri-app-stop ubsignal_ubsignal 2>/dev/null || true
  lomiri-app-stop utlangis_utlangis 2>/dev/null || true
  if test -d $PHONE_HOME/.local/share/ubsignal; then
    mkdir -p $PHONE_HOME/.local/share/utlangis $PHONE_HOME/.config/utlangis
    cp -a $PHONE_HOME/.local/share/ubsignal/. $PHONE_HOME/.local/share/utlangis/
    if test -f $PHONE_HOME/.config/ubsignal/ubSignal.conf; then
      cp -a $PHONE_HOME/.config/ubsignal/ubSignal.conf $PHONE_HOME/.config/utlangis/UTLangis.conf
    fi
  else
    echo 'No ubsignal data on this phone.'
  fi"

# pkcon (PackageKit) removes clicks without root, but newer Ubuntu Touch
# images do not ship it; then the user removes the old app by hand.
echo "Removing the old app"
OLD=$(adb shell "click list --user=phablet" | awk '/^ubsignal/{print $2}' | tr -d '\r')
if test -n "$OLD" && adb shell "command -v pkcon >/dev/null"; then
  adb shell "pkcon remove 'ubsignal;$OLD;all;local:click' -y" >/dev/null
elif test -n "$OLD"; then
  echo "  Please remove the old app 'ubSignal' on the phone yourself:"
  echo "  OpenStore -> Installed apps -> ubSignal -> Remove."
fi

echo
echo "Done. Start UT Langis and check your chats, then delete the old copy:"
echo "  adb shell rm -rf $PHONE_HOME/.local/share/ubsignal $PHONE_HOME/.config/ubsignal $PHONE_HOME/.cache/ubsignal"
