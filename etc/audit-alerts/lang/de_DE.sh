#!/usr/bin/env bash
# audit-to-ntfy Sprachdatei: Deutsch (de_DE)
# Kopiere diese Datei nicht – sie wird von install.sh verwaltet.
# Eigene Übersetzungen bitte in eine separate Datei auslagern.

# Feldbezeichner
L_USER="Benutzer:"
L_UID="UID:"
L_TTY="Terminal:"
L_COMMAND="Befehl:"
L_ACTION="Aktion:"
L_RESULT="Ergebnis:"
L_RESULT_FAILED="fehlgeschlagen:"
L_VIA="Via:"
L_ESCALATION="Eskalation:"
L_PATH="Pfad:"
L_EXE="Programm:"

# Ereignis-Hinweis
L_INSPECT_HINT="Ereignis genauer untersuchen:"
L_INSPECT_CMD="sudo ausearch --event %s -i"

# Formatter-Zusammenfassungen (printf-Formatstrings, Argumente je nach Formatter)
L_SSHKEYS_SUMMARY="Schreibzugriff auf: %s durch: %s (%s)"
L_SUDO_SUMMARY="sudo via: %s (%s)"
L_SYSTEMD_CHANGE="%s systemd-Änderung an: %s"
L_SYSTEMD_SCOPE_SYSTEM="System"
L_SYSTEMD_SCOPE_USER="Benutzer"

# systemd-Aktionen (aus Syscall-Nummer)
L_SYSTEMD_ACT_RENAMED="umbenannt"
L_SYSTEMD_ACT_MKDIR="Verzeichnis erstellt"
L_SYSTEMD_ACT_REMOVED="entfernt"
L_SYSTEMD_ACT_SYMLINKED="Symlink erstellt (aktiviert)"

# Ergebnisse (aus Exit-Code)
L_RESULT_OK="erfolgreich"
L_RESULT_NOT_FOUND="nicht gefunden"
L_RESULT_PERM_DENIED="keine Berechtigung"
L_RESULT_ALREADY_EXISTS="existiert bereits"
L_RESULT_NO_SPACE="kein Speicherplatz"

# priv-esc Bezeichner (%s wird durch EVENT_COMM ersetzt)
L_PRIV_PAM="PAM-Passwortprüfung (%s)"
L_PRIV_SU="Benutzerwechsel (su)"
L_PRIV_NEWGRP="neue Gruppe (newgrp)"
L_PRIV_PKEXEC="Polkit-Ausführung (pkexec)"
L_PRIV_PASSWD="Passwortänderung (passwd)"
L_PRIV_CHUSER="Benutzerinfo ändern (%s)"
L_PRIV_MOUNT="Einhängevorgang (%s)"

# dir-watch Zusammenfassung (%1$s = Aktion, %2$s = Pfad)
L_DIRWATCH_SUMMARY="%s an: %s"

# dir-watch Aktionen (aus Syscall-Nummer)
L_DIRWATCH_ACT_WRITE="geändert"
L_DIRWATCH_ACT_RENAMED="umbenannt"
L_DIRWATCH_ACT_MKDIR="Verzeichnis erstellt"
L_DIRWATCH_ACT_RMDIR="Verzeichnis entfernt"
L_DIRWATCH_ACT_DELETED="gelöscht"
L_DIRWATCH_ACT_SYMLINKED="Symlink erstellt"
L_DIRWATCH_ACT_LINKED="Hardlink erstellt"
L_DIRWATCH_ACT_CHMOD="Berechtigungen geändert"
L_DIRWATCH_ACT_CHOWN="Eigentümer geändert"
L_DIRWATCH_ACT_EXEC="ausgeführt"
