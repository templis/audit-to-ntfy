#!/usr/bin/env bash
set -euo pipefail

NTFY_ENV_FILE="${NTFY_ENV_FILE:-/etc/audit-alerts/ntfy.env}"
CONF_FILE="${AUDIT_ALERTS_CONF_FILE:-/etc/audit-alerts/audit-alerts.conf}"
FORMAT_DISPATCHER="${FORMAT_DISPATCHER:-/etc/audit-alerts/format.sh}"
AUDIT_LOG_FILE="${AUDIT_LOG_FILE:-/var/log/audit/audit.log}"
STATE_FILE="${STATE_FILE:-/var/lib/audit-log-to-ntfy.offset}"
DEDUP_FILE="${DEDUP_FILE:-/var/lib/audit-log-to-ntfy.lastmsg}"
HTTP_OUT_FILE="${HTTP_OUT_FILE:-/tmp/audit-log-to-ntfy.last}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

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

if (( EUID != 0 )); then
  echo "This script must run as root." >&2
  exit 1
fi

for required in curl dd grep sed stat logger hostname getent; do
  if ! require_cmd "$required"; then
    logger -t audit-log-to-ntfy "missing dependency: $required"
    exit 1
  fi
done

if [[ ! -f "$NTFY_ENV_FILE" ]]; then
  logger -t audit-log-to-ntfy "missing config file: $NTFY_ENV_FILE"
  exit 1
fi

if [[ ! -f "$CONF_FILE" ]]; then
  logger -t audit-log-to-ntfy "missing config file: $CONF_FILE"
  exit 1
fi

if [[ ! -x "$FORMAT_DISPATCHER" ]]; then
  logger -t audit-log-to-ntfy "formatter dispatcher not executable: $FORMAT_DISPATCHER"
  exit 1
fi

# shellcheck disable=SC1090
source "$NTFY_ENV_FILE"
# shellcheck disable=SC1090
source "$CONF_FILE"

ALERT_KEYS_REGEX="${ALERT_KEYS_REGEX:- key=\"(sshkeys|sudo-use|priv-esc|systemd|user-systemd)\"}"
MAX_BODY="${MAX_BODY:-1200}"
FORMATTERS_DIR="${FORMATTERS_DIR:-/etc/audit-alerts/formatters.d}"
RULESETS_DIR="${RULESETS_DIR:-/etc/audit-alerts/rules.d}"
ALERT_LANG="${ALERT_LANG:-}"
LANG_DIR="${LANG_DIR:-/etc/audit-alerts/lang}"
HOME_USER="${HOME_USER:-}"
HOME_DIR="${HOME_DIR:-}"

if [[ -z "${NTFY_URL:-}" || -z "${NTFY_TOPIC:-}" || -z "${NTFY_TOKEN:-}" ]]; then
  logger -t audit-log-to-ntfy "NTFY_URL, NTFY_TOPIC, and NTFY_TOKEN must be set"
  exit 1
fi

if [[ ! "$MAX_BODY" =~ ^[0-9]+$ ]]; then
  logger -t audit-log-to-ntfy "MAX_BODY must be numeric, got: $MAX_BODY"
  exit 1
fi

if [[ -n "$HOME_USER" && -z "$HOME_DIR" ]]; then
  HOME_DIR="$(getent passwd "$HOME_USER" | awk -F: 'NR==1 {print $6}')"
fi

mkdir -p "$(dirname "$STATE_FILE")"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "0" >"$STATE_FILE"
fi

offset="$(cat "$STATE_FILE" 2>/dev/null || echo "0")"
if [[ ! "$offset" =~ ^[0-9]+$ ]]; then
  offset="0"
fi

size="$(stat -c %s "$AUDIT_LOG_FILE" 2>/dev/null || echo "0")"
if [[ ! "$size" =~ ^[0-9]+$ ]]; then
  size="0"
fi

if (( offset > size )); then
  offset=0
fi

new_bytes="$(dd if="$AUDIT_LOG_FILE" bs=1 skip="$offset" status=none 2>/dev/null || true)"
echo "$size" >"$STATE_FILE"

if [[ -z "$new_bytes" ]]; then
  exit 0
fi

filtered_lines="$(grep -E "$ALERT_KEYS_REGEX" <<<"$new_bytes" || true)"
if [[ -z "$filtered_lines" ]]; then
  exit 0
fi

syscall_line="$(grep 'type=SYSCALL' <<<"$filtered_lines" | tail -n 1 || true)"
if [[ -z "$syscall_line" ]]; then
  exit 0
fi

msgid="$(sed -n 's/.*msg=audit(\([0-9]\+\.[0-9]\+:[0-9]\+\)).*/\1/p' <<<"$syscall_line" | head -n 1)"
if [[ -z "$msgid" ]]; then
  exit 0
fi

serial="${msgid##*:}"
if [[ -z "$serial" || ! "$serial" =~ ^[0-9]+$ ]]; then
  exit 0
fi

if [[ -f "$DEDUP_FILE" ]] && [[ "$msgid" == "$(cat "$DEDUP_FILE" 2>/dev/null)" ]]; then
  exit 0
fi

event_lines="$(grep "msg=audit(${msgid})" <<<"$new_bytes" || true)"
if [[ -z "$event_lines" ]]; then
  event_lines="$syscall_line"
fi

event_key="$(extract_quoted_field "key" "$syscall_line")"
event_exe="$(extract_quoted_field "exe" "$syscall_line")"
event_comm="$(extract_quoted_field "comm" "$syscall_line")"
event_auid="$(extract_numeric_field "auid" "$syscall_line")"
event_uid="$(extract_numeric_field "uid" "$syscall_line")"
event_euid="$(extract_numeric_field "euid" "$syscall_line")"
event_tty="$(sed -n 's/.* tty=\([^ ]*\).*/\1/p' <<<"$syscall_line" | head -n 1)"
audit_host="$(hostname 2>/dev/null || echo "unknown-host")"

format_output="$(
  EVENT_KEY="$event_key" \
  AUDIT_HOST="$audit_host" \
  SYSCALL_LINE="$syscall_line" \
  EVENT_LINES="$event_lines" \
  SERIAL="$serial" \
  EVENT_AUID="$event_auid" \
  EVENT_UID="$event_uid" \
  EVENT_EUID="$event_euid" \
  EVENT_EXE="$event_exe" \
  EVENT_COMM="$event_comm" \
  EVENT_TTY="$event_tty" \
  HOME_USER="$HOME_USER" \
  HOME_DIR="$HOME_DIR" \
  FORMATTERS_DIR="$FORMATTERS_DIR" \
  RULESETS_DIR="$RULESETS_DIR" \
  ALERT_LANG="$ALERT_LANG" \
  LANG_DIR="$LANG_DIR" \
  "$FORMAT_DISPATCHER"
)"

title="$(sed -n '1s/^TITLE=//p' <<<"$format_output")"
body="$(awk 'found {print} /^__BODY__$/ {found=1}' <<<"$format_output")"

if [[ -z "$title" ]]; then
  title="🔐 Audit: ${event_key:-event} on ${audit_host}"
fi

if [[ -z "$body" ]]; then
  body="$(
    printf "User: unknown (AUID=%s)\n" "${event_auid:-?}"
    printf "UID: %s\n" "${event_uid:-?}"
    printf "Exe: %s (%s)\n" "${event_exe:-?}" "${event_comm:-?}"
    printf "\nHow to inspect this exact event:\n"
    printf "sudo ausearch --event %s -i\n" "$serial"
  )"
fi

if (( ${#body} > MAX_BODY )); then
  body="${body:0:MAX_BODY}"$'\n[truncated]'
fi

echo "$msgid" >"$DEDUP_FILE"

http_code="$(
  printf "%s" "$body" | curl --config /dev/null -sS -o "$HTTP_OUT_FILE" -w '%{http_code}' \
    -H "Authorization: Bearer ${NTFY_TOKEN}" \
    -H "Title: ${title}" \
    -H "Priority: 4" \
    --data-binary @- \
    "${NTFY_URL%/}/${NTFY_TOPIC}" || true
)"

if [[ "$http_code" != "200" && "$http_code" != "202" ]]; then
  logger -t audit-log-to-ntfy "send failed http_code=${http_code} serial=${serial} key=${event_key:-unknown}"
  exit 1
fi

exit 0
