#!/usr/bin/env bash
set -euo pipefail

SYSCALL_LINE="${SYSCALL_LINE:-}"
EVENT_LINES="${EVENT_LINES:-}"
EVENT_KEY="${EVENT_KEY:-}"
EVENT_EXE="${EVENT_EXE:-}"
EVENT_COMM="${EVENT_COMM:-}"
EVENT_AUID="${EVENT_AUID:-}"
EVENT_UID="${EVENT_UID:-}"
EVENT_EUID="${EVENT_EUID:-}"
EVENT_TTY="${EVENT_TTY:-}"
SERIAL="${SERIAL:-}"
AUDIT_HOST="${AUDIT_HOST:-$(hostname 2>/dev/null || echo unknown-host)}"
HOME_USER="${HOME_USER:-}"
HOME_DIR="${HOME_DIR:-}"
FORMATTERS_DIR="${FORMATTERS_DIR:-/etc/audit-alerts/formatters.d}"
RULESETS_DIR="${RULESETS_DIR:-/etc/audit-alerts/rules.d}"
ALERT_LANG="${ALERT_LANG:-}"
LANG_DIR="${LANG_DIR:-/etc/audit-alerts/lang}"

# Source language file before setting defaults so it can override them.
if [[ -n "$ALERT_LANG" ]]; then
  _lang_file="${LANG_DIR%/}/${ALERT_LANG}.sh"
  if [[ -f "$_lang_file" ]]; then
    # shellcheck disable=SC1090
    source "$_lang_file"
  fi
fi

# i18n string defaults (English). Any variable already set by a language
# file is left untouched thanks to the ${var:-default} pattern.

# Field labels
L_USER="${L_USER:-User:}"
L_UID="${L_UID:-UID:}"
L_TTY="${L_TTY:-TTY:}"
L_COMMAND="${L_COMMAND:-Command:}"
L_ACTION="${L_ACTION:-Action:}"
L_RESULT="${L_RESULT:-Result:}"
L_RESULT_FAILED="${L_RESULT_FAILED:-failed:}"
L_VIA="${L_VIA:-Via:}"
L_ESCALATION="${L_ESCALATION:-Escalation:}"
L_PATH="${L_PATH:-Path:}"
L_EXE="${L_EXE:-Exe:}"

# inspect_hint strings
L_INSPECT_HINT="${L_INSPECT_HINT:-How to inspect this exact event:}"
L_INSPECT_CMD="${L_INSPECT_CMD:-sudo ausearch --event %s -i}"

# Formatter summary format strings (%s placeholders, positional per formatter)
L_SSHKEYS_SUMMARY="${L_SSHKEYS_SUMMARY:-write on: %s with: %s (%s)}"
L_SUDO_SUMMARY="${L_SUDO_SUMMARY:-sudo via: %s (%s)}"
L_SYSTEMD_CHANGE="${L_SYSTEMD_CHANGE:-%s systemd change on: %s}"
L_SYSTEMD_SCOPE_SYSTEM="${L_SYSTEMD_SCOPE_SYSTEM:-system}"
L_SYSTEMD_SCOPE_USER="${L_SYSTEMD_SCOPE_USER:-user}"

# systemd action labels (mapped from syscall number)
L_SYSTEMD_ACT_RENAMED="${L_SYSTEMD_ACT_RENAMED:-renamed}"
L_SYSTEMD_ACT_MKDIR="${L_SYSTEMD_ACT_MKDIR:-mkdir}"
L_SYSTEMD_ACT_REMOVED="${L_SYSTEMD_ACT_REMOVED:-removed}"
L_SYSTEMD_ACT_SYMLINKED="${L_SYSTEMD_ACT_SYMLINKED:-symlinked (enable)}"

# systemd / generic result labels (mapped from exit code)
L_RESULT_OK="${L_RESULT_OK:-ok}"
L_RESULT_NOT_FOUND="${L_RESULT_NOT_FOUND:-not found}"
L_RESULT_PERM_DENIED="${L_RESULT_PERM_DENIED:-permission denied}"
L_RESULT_ALREADY_EXISTS="${L_RESULT_ALREADY_EXISTS:-already exists}"
L_RESULT_NO_SPACE="${L_RESULT_NO_SPACE:-no space}"

# priv-esc exe labels (%s is replaced with EVENT_COMM where applicable)
L_PRIV_PAM="${L_PRIV_PAM:-PAM password check (%s)}"
L_PRIV_SU="${L_PRIV_SU:-switch user (su)}"
L_PRIV_NEWGRP="${L_PRIV_NEWGRP:-new group (newgrp)}"
L_PRIV_PKEXEC="${L_PRIV_PKEXEC:-polkit exec (pkexec)}"
L_PRIV_PASSWD="${L_PRIV_PASSWD:-password change (passwd)}"
L_PRIV_CHUSER="${L_PRIV_CHUSER:-change user info (%s)}"
L_PRIV_MOUNT="${L_PRIV_MOUNT:-mount operation (%s)}"

extract_quoted_field() {
  local field="$1"
  local line="$2"
  sed -n "s/.* ${field}=\"\\([^\"]*\\)\".*/\\1/p" <<<"$line" | head -n 1
}

extract_numeric_field() {
  local field="$1"
  local line="$2"
  sed -n "s/.* ${field}=\\([0-9]\\+\\).*/\\1/p" <<<"$line" | head -n 1
}

shorten_home_path() {
  local path="$1"
  if [[ -n "$HOME_DIR" && "$path" == "$HOME_DIR"* ]]; then
    echo "~${path#"$HOME_DIR"}"
    return
  fi
  echo "$path"
}

extract_target_path() {
  local raw_path
  raw_path="$(
    sed -n 's/.*type=PATH .* name="\([^"]*\)".*/\1/p' <<<"$EVENT_LINES" \
      | grep -v '^$' \
      | grep -v '^(null)$' \
      | head -n 1
  )"

  if [[ -z "$raw_path" ]]; then
    echo ""
    return
  fi

  shorten_home_path "$raw_path"
}

extract_proctitle_hex() {
  sed -n 's/.* proctitle=\([0-9A-Fa-f]\+\).*/\1/p' <<<"$EVENT_LINES" | head -n 1
}

extract_proctitle_text() {
  # Proctitle in audit.log is either hex (null-separated args) or a quoted
  # plain string (when all chars are printable ASCII). Try hex first.
  local hex
  hex="$(extract_proctitle_hex)"
  if [[ -n "$hex" ]]; then
    decode_proctitle "$hex"
    return
  fi
  # Fall back to quoted form: proctitle="sudo pacman -Syu"
  sed -n 's/.*[[:space:]]proctitle="\([^"]*\)".*/\1/p' <<<"$EVENT_LINES" | head -n 1
}

decode_proctitle() {
  local hex="$1"
  local escaped
  local cleaned

  if [[ -z "$hex" ]]; then
    echo ""
    return
  fi

  cleaned="$(sed 's/00/20/g' <<<"$hex")"
  escaped="$(sed 's/../\\x&/g' <<<"$cleaned")"
  printf '%b' "$escaped" 2>/dev/null | tr -s ' ' || true
}

inspect_hint() {
  printf "%s\n" "$L_INSPECT_HINT"
  # shellcheck disable=SC2059
  printf "${L_INSPECT_CMD}\n" "${SERIAL:-?}"
}

auid_to_user() {
  local auid="$1"
  if [[ -z "$auid" || "$auid" == "4294967295" ]]; then
    echo "unknown"
    return
  fi
  getent passwd "$auid" | awk -F: 'NR==1 {print $1}'
}

source_ruleset_if_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC1090
    source "$file"
  fi
}

apply_ruleset_overrides() {
  local title_prefix="${RULE_TITLE_PREFIX:-}"
  local title_override="${RULE_TITLE_OVERRIDE:-}"
  local body_prepend="${RULE_BODY_PREPEND:-}"
  local body_append="${RULE_BODY_APPEND:-}"

  if [[ -n "$title_override" ]]; then
    FORMAT_TITLE="$title_override"
  elif [[ -n "$title_prefix" ]]; then
    FORMAT_TITLE="${title_prefix}${FORMAT_TITLE}"
  fi

  if [[ -n "$body_prepend" ]]; then
    FORMAT_BODY="${body_prepend}"$'\n'"${FORMAT_BODY}"
  fi

  if [[ -n "$body_append" ]]; then
    FORMAT_BODY="${FORMAT_BODY}"$'\n'"${body_append}"
  fi
}

if [[ -z "$EVENT_KEY" ]]; then
  EVENT_KEY="$(extract_quoted_field "key" "$SYSCALL_LINE")"
fi
if [[ -z "$EVENT_EXE" ]]; then
  EVENT_EXE="$(extract_quoted_field "exe" "$SYSCALL_LINE")"
fi
if [[ -z "$EVENT_COMM" ]]; then
  EVENT_COMM="$(extract_quoted_field "comm" "$SYSCALL_LINE")"
fi
if [[ -z "$EVENT_AUID" ]]; then
  EVENT_AUID="$(extract_numeric_field "auid" "$SYSCALL_LINE")"
fi
if [[ -z "$EVENT_UID" ]]; then
  EVENT_UID="$(extract_numeric_field "uid" "$SYSCALL_LINE")"
fi
if [[ -z "$EVENT_EUID" ]]; then
  EVENT_EUID="$(extract_numeric_field "euid" "$SYSCALL_LINE")"
fi
if [[ -z "$EVENT_TTY" ]]; then
  EVENT_TTY="$(sed -n 's/.* tty=\([^ ]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"
fi
if [[ -n "$HOME_USER" && -z "$HOME_DIR" ]]; then
  HOME_DIR="$(getent passwd "$HOME_USER" | awk -F: 'NR==1 {print $6}')"
fi

source_ruleset_if_exists "${RULESETS_DIR%/}/common.rules.sh"
if [[ -n "$EVENT_KEY" ]]; then
  source_ruleset_if_exists "${RULESETS_DIR%/}/${EVENT_KEY}.rules.sh"
fi

EVENT_USER="$(auid_to_user "${EVENT_AUID:-}")"

FORMAT_TITLE=""
FORMAT_BODY=""

formatter="${FORMATTERS_DIR%/}/${EVENT_KEY}.sh"
if [[ ! -f "$formatter" ]]; then
  formatter="${FORMATTERS_DIR%/}/default.sh"
fi

if [[ ! -f "$formatter" ]]; then
  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-event} on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s %s\n" "$L_UID" "${EVENT_UID:-?}"
    printf "%s %s (%s)\n" "$L_EXE" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
    printf "\n"
    inspect_hint
  )"
else
  # shellcheck disable=SC1090
  source "$formatter"
  if declare -F formatter_render >/dev/null 2>&1; then
    formatter_render
  else
    FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-event} on ${AUDIT_HOST}"
    FORMAT_BODY="$(
      printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
      printf "%s %s\n" "$L_UID" "${EVENT_UID:-?}"
      printf "%s %s (%s)\n" "$L_EXE" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
      printf "\n"
      inspect_hint
    )"
  fi
fi

if [[ -z "$FORMAT_TITLE" ]]; then
  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-event} on ${AUDIT_HOST}"
fi
if [[ -z "$FORMAT_BODY" ]]; then
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "\n"
    inspect_hint
  )"
fi

apply_ruleset_overrides

printf "TITLE=%s\n" "$FORMAT_TITLE"
printf "__BODY__\n"
printf "%s\n" "$FORMAT_BODY"
