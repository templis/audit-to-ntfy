#!/usr/bin/env bash
set -uo pipefail

source /etc/audit-alerts/ntfy.env

# requirements
command -v curl >/dev/null || exit 1

STATE="/var/lib/audit-log-to-ntfy.offset"
LOG="/var/log/audit/audit.log"
DEDUP="/var/lib/audit-log-to-ntfy.lastmsg"

mkdir -p /var/lib

[[ -f "$STATE" ]] || echo 0 > "$STATE"

OFF="$(cat "$STATE" 2>/dev/null || echo 0)"
SIZE="$(stat -c %s "$LOG" 2>/dev/null || echo 0)"

# rotation/truncation
if [[ "$OFF" -gt "$SIZE" ]]; then
  OFF=0
fi

NEW="$(dd if="$LOG" bs=1 skip="$OFF" status=none 2>/dev/null || true)"
echo "$SIZE" > "$STATE"
[[ -z "$NEW" ]] && exit 0

# Only interesting keys (no rootcmd!)
FILTERED="$(printf "%s" "$NEW" | grep -E ' key="(sshkeys|sudo-use|systemd|user-systemd|priv-esc)"' || true)"
[[ -z "$FILTERED" ]] && exit 0

# newest matching SYSCALL record
SYSCALL_LINE="$(printf "%s" "$FILTERED" | grep 'type=SYSCALL' | tail -n 1)"
[[ -z "$SYSCALL_LINE" ]] && exit 0

# dedup by audit msg id
MSGID="$(printf "%s\n" "$SYSCALL_LINE" | sed -n 's/.*msg=audit(\([0-9.]*:[0-9]*\)).*/\1/p')"
if [[ -n "$MSGID" ]] && [[ -f "$DEDUP" ]] && [[ "$MSGID" == "$(cat "$DEDUP")" ]]; then
  exit 0
fi
[[ -n "$MSGID" ]] && echo "$MSGID" > "$DEDUP"

# extract fields
key="$(printf "%s\n" "$SYSCALL_LINE" | sed -n 's/.* key="\([^"]*\)".*/\1/p')"
comm="$(printf "%s\n" "$SYSCALL_LINE" | sed -n 's/.* comm="\([^"]*\)".*/\1/p')"
exe="$(printf "%s\n" "$SYSCALL_LINE"  | sed -n 's/.* exe="\([^"]*\)".*/\1/p')"
auid="$(printf "%s\n" "$SYSCALL_LINE" | sed -n 's/.* auid=\([0-9]\+\).*/\1/p')"
uid="$(printf "%s\n" "$SYSCALL_LINE"  | sed -n 's/.* uid=\([0-9]\+\).*/\1/p')"
tty="$(printf "%s\n" "$SYSCALL_LINE"  | sed -n 's/.* tty=\([^ ]*\).*/\1/p')"

# map auid -> username if possible
AUSER=""
if [[ -n "${auid:-}" ]] && [[ "${auid:-}" != "4294967295" ]]; then
  AUSER="$(getent passwd "$auid" | cut -d: -f1 || true)"
fi

HOST="$(hostname)"
TITLE="🔐 Audit: ${key:-event} on ${HOST}"

BODY=$(
  printf "Key:  %s\n" "${key:-?}"
  printf "User: %s (AUID=%s)\n" "${AUSER:-unknown}" "${auid:-?}"
  printf "UID:  %s\n" "${uid:-?}"
  printf "Exe:  %s\n" "${exe:-?}"
  printf "Comm: %s\n" "${comm:-?}"
  printf "TTY:  %s\n" "${tty:-?}"
)

# keep body small
MAX=1200
if (( ${#BODY} > MAX )); then
  BODY="${BODY:0:MAX}"$'\n[truncated]'
fi

HTTP_CODE="$(printf "%s" "$BODY" | curl --config /dev/null -sS -o /tmp/audit-log-to-ntfy.last -w '%{http_code}' \
  -H "Authorization: Bearer ${NTFY_TOKEN}" \
  -H "Title: ${TITLE}" \
  -H "Priority: 4" \
  --data-binary @- \
  "${NTFY_URL%/}/${NTFY_TOPIC}" || true)"

# only log on failure (avoids self-noise)
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "202" ]]; then
  logger -t audit-log-to-ntfy "send failed http_code=${HTTP_CODE}"
  exit 1
fi
