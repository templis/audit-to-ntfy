#!/usr/bin/env bash
# audit-to-ntfy language file: English (en_US)
# This file doubles as the reference template for new translations.
# Copy it, rename it to <locale>.sh, and translate the values.

# Field labels
L_USER="User:"
L_UID="UID:"
L_TTY="TTY:"
L_COMMAND="Command:"
L_ACTION="Action:"
L_RESULT="Result:"
L_RESULT_FAILED="failed:"
L_VIA="Via:"
L_ESCALATION="Escalation:"
L_PATH="Path:"
L_EXE="Exe:"

# inspect_hint
L_INSPECT_HINT="How to inspect this exact event:"
L_INSPECT_CMD="sudo ausearch --event %s -i"

# Formatter summary format strings (%s placeholders, positional per formatter)
L_SSHKEYS_SUMMARY="write on: %s with: %s (%s)"
L_SUDO_SUMMARY="sudo via: %s (%s)"
L_SYSTEMD_CHANGE="%s systemd change on: %s"
L_SYSTEMD_SCOPE_SYSTEM="system"
L_SYSTEMD_SCOPE_USER="user"

# systemd action labels (mapped from syscall number)
L_SYSTEMD_ACT_RENAMED="renamed"
L_SYSTEMD_ACT_MKDIR="mkdir"
L_SYSTEMD_ACT_REMOVED="removed"
L_SYSTEMD_ACT_SYMLINKED="symlinked (enable)"

# systemd / generic result labels (mapped from exit code)
L_RESULT_OK="ok"
L_RESULT_NOT_FOUND="not found"
L_RESULT_PERM_DENIED="permission denied"
L_RESULT_ALREADY_EXISTS="already exists"
L_RESULT_NO_SPACE="no space"

# priv-esc exe labels (%s is replaced with EVENT_COMM where applicable)
L_PRIV_PAM="PAM password check (%s)"
L_PRIV_SU="switch user (su)"
L_PRIV_NEWGRP="new group (newgrp)"
L_PRIV_PKEXEC="polkit exec (pkexec)"
L_PRIV_PASSWD="password change (passwd)"
L_PRIV_CHUSER="change user info (%s)"
L_PRIV_MOUNT="mount operation (%s)"
