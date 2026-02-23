#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="audit-to-ntfy"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

SRC_BIN="$SCRIPT_DIR/bin/audit-log-to-ntfy.sh"
SRC_ETC="$SCRIPT_DIR/etc/audit-alerts"
SRC_SYSTEMD="$SCRIPT_DIR/etc/systemd"

DST_BIN="/usr/local/bin/audit-log-to-ntfy.sh"
DST_ETC_DIR="/etc/audit-alerts"
DST_FORMATTERS_DIR="$DST_ETC_DIR/formatters.d"
DST_SYSTEMD_DIR="/etc/systemd/system"

DST_NTFY_ENV="$DST_ETC_DIR/ntfy.env"
DST_NTFY_ENV_EXAMPLE="$DST_ETC_DIR/ntfy.env.example"
DST_CONF="$DST_ETC_DIR/audit-alerts.conf"
DST_CONF_EXAMPLE="$DST_ETC_DIR/audit-alerts.conf.example"

if (( EUID != 0 )); then
  echo "Run as root: sudo ./install.sh" >&2
  exit 1
fi

for cmd in install systemctl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if [[ ! -f "$SRC_BIN" ]]; then
  echo "Missing source file: $SRC_BIN" >&2
  exit 1
fi

echo "Installing $PROJECT_NAME..."

install -d -m 755 "$DST_ETC_DIR"
install -d -m 755 "$DST_FORMATTERS_DIR"
install -d -m 755 "$DST_SYSTEMD_DIR"

install -m 755 "$SRC_BIN" "$DST_BIN"
install -m 755 "$SRC_ETC/format.sh" "$DST_ETC_DIR/format.sh"

install -m 644 "$SRC_ETC/formatters.d/default.sh" "$DST_FORMATTERS_DIR/default.sh"
install -m 644 "$SRC_ETC/formatters.d/sshkeys.sh" "$DST_FORMATTERS_DIR/sshkeys.sh"
install -m 644 "$SRC_ETC/formatters.d/sudo-use.sh" "$DST_FORMATTERS_DIR/sudo-use.sh"
install -m 644 "$SRC_ETC/formatters.d/systemd.sh" "$DST_FORMATTERS_DIR/systemd.sh"

install -m 644 "$SRC_ETC/ntfy.env.example" "$DST_NTFY_ENV_EXAMPLE"
install -m 644 "$SRC_ETC/audit-alerts.conf.example" "$DST_CONF_EXAMPLE"

if [[ ! -f "$DST_NTFY_ENV" ]]; then
  install -m 600 "$SRC_ETC/ntfy.env.example" "$DST_NTFY_ENV"
  echo "Created $DST_NTFY_ENV from example."
else
  chmod 600 "$DST_NTFY_ENV"
  echo "Keeping existing $DST_NTFY_ENV"
fi

if [[ ! -f "$DST_CONF" ]]; then
  install -m 644 "$SRC_ETC/audit-alerts.conf.example" "$DST_CONF"
  echo "Created $DST_CONF from example."
else
  chmod 644 "$DST_CONF"
  echo "Keeping existing $DST_CONF"
fi

chown root:root "$DST_BIN" \
  "$DST_ETC_DIR/format.sh" \
  "$DST_FORMATTERS_DIR/default.sh" \
  "$DST_FORMATTERS_DIR/sshkeys.sh" \
  "$DST_FORMATTERS_DIR/sudo-use.sh" \
  "$DST_FORMATTERS_DIR/systemd.sh" \
  "$DST_NTFY_ENV_EXAMPLE" \
  "$DST_CONF_EXAMPLE" \
  "$DST_NTFY_ENV" \
  "$DST_CONF"

install -m 644 "$SRC_SYSTEMD/audit-log-to-ntfy.service" "$DST_SYSTEMD_DIR/audit-log-to-ntfy.service"
install -m 644 "$SRC_SYSTEMD/audit-log-to-ntfy.timer" "$DST_SYSTEMD_DIR/audit-log-to-ntfy.timer"
chown root:root "$DST_SYSTEMD_DIR/audit-log-to-ntfy.service" "$DST_SYSTEMD_DIR/audit-log-to-ntfy.timer"

systemctl daemon-reload
systemctl enable --now audit-log-to-ntfy.timer

cat <<'POST_INSTALL'
Install complete.

Next steps:
1. Edit ntfy credentials with vi:
   sudo vi /etc/audit-alerts/ntfy.env
2. Optional: tune alert behavior:
   sudo vi /etc/audit-alerts/audit-alerts.conf
3. Manual test run:
   sudo /usr/local/bin/audit-log-to-ntfy.sh
4. Check service logs:
   journalctl -u audit-log-to-ntfy.service -n 50 --no-pager
POST_INSTALL
