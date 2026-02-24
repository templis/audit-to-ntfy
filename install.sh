#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="audit-to-ntfy"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

SRC_BIN="$SCRIPT_DIR/bin/audit-log-to-ntfy.sh"
SRC_UPDATE="$SCRIPT_DIR/update.sh"
SRC_ETC="$SCRIPT_DIR/etc/audit-alerts"
SRC_SYSTEMD="$SCRIPT_DIR/etc/systemd"
SRC_RULESETS="$SRC_ETC/rules.d"

DST_BIN="/usr/local/bin/audit-log-to-ntfy.sh"
DST_UPDATE="/usr/local/bin/audit-to-ntfy-update.sh"
DST_ETC_DIR="/etc/audit-alerts"
DST_FORMATTERS_DIR="$DST_ETC_DIR/formatters.d"
DST_RULESETS_DIR="$DST_ETC_DIR/rules.d"
DST_LANG_DIR="$DST_ETC_DIR/lang"
DST_SYSTEMD_DIR="/etc/systemd/system"

DST_NTFY_ENV="$DST_ETC_DIR/ntfy.env"
DST_NTFY_ENV_EXAMPLE="$DST_ETC_DIR/ntfy.env.example"
DST_CONF="$DST_ETC_DIR/audit-alerts.conf"
DST_CONF_EXAMPLE="$DST_ETC_DIR/audit-alerts.conf.example"

INSTALL_CONTEXT="${INSTALL_CONTEXT:-install}"

FORMATTER_FILES=(
  "default.sh"
  "priv-esc.sh"
  "sshkeys.sh"
  "sudo-use.sh"
  "systemd.sh"
)

RULESET_FILES=(
  "common.rules.sh"
  "default.rules.sh"
  "sshkeys.rules.sh"
  "sudo-use.rules.sh"
  "systemd.rules.sh"
  "user-systemd.rules.sh"
  "priv-esc.rules.sh"
)

LANG_FILES=(
  "de_DE.sh"
)

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

if [[ ! -f "$SRC_UPDATE" ]]; then
  echo "Missing source file: $SRC_UPDATE" >&2
  exit 1
fi

for formatter_file in "${FORMATTER_FILES[@]}"; do
  if [[ ! -f "$SRC_ETC/formatters.d/$formatter_file" ]]; then
    echo "Missing formatter source: $SRC_ETC/formatters.d/$formatter_file" >&2
    exit 1
  fi
done

for ruleset_file in "${RULESET_FILES[@]}"; do
  if [[ ! -f "$SRC_RULESETS/$ruleset_file" ]]; then
    echo "Missing ruleset source: $SRC_RULESETS/$ruleset_file" >&2
    exit 1
  fi
done

for lang_file in "${LANG_FILES[@]}"; do
  if [[ ! -f "$SRC_ETC/lang/$lang_file" ]]; then
    echo "Missing lang source: $SRC_ETC/lang/$lang_file" >&2
    exit 1
  fi
done

echo "Installing $PROJECT_NAME..."

install -d -m 755 "$DST_ETC_DIR"
install -d -m 755 "$DST_FORMATTERS_DIR"
install -d -m 755 "$DST_RULESETS_DIR"
install -d -m 755 "$DST_LANG_DIR"
install -d -m 755 "$DST_SYSTEMD_DIR"

install -m 755 "$SRC_BIN" "$DST_BIN"
install -m 755 "$SRC_UPDATE" "$DST_UPDATE"
install -m 755 "$SRC_ETC/format.sh" "$DST_ETC_DIR/format.sh"

for formatter_file in "${FORMATTER_FILES[@]}"; do
  install -m 644 "$SRC_ETC/formatters.d/$formatter_file" "$DST_FORMATTERS_DIR/$formatter_file"
done

for lang_file in "${LANG_FILES[@]}"; do
  install -m 644 "$SRC_ETC/lang/$lang_file" "$DST_LANG_DIR/$lang_file"
done

for ruleset_file in "${RULESET_FILES[@]}"; do
  if [[ ! -f "$DST_RULESETS_DIR/$ruleset_file" ]]; then
    install -m 644 "$SRC_RULESETS/$ruleset_file" "$DST_RULESETS_DIR/$ruleset_file"
    echo "Created $DST_RULESETS_DIR/$ruleset_file"
  else
    echo "Keeping existing $DST_RULESETS_DIR/$ruleset_file"
  fi
done

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

install -m 644 "$SRC_SYSTEMD/audit-log-to-ntfy.service" "$DST_SYSTEMD_DIR/audit-log-to-ntfy.service"
install -m 644 "$SRC_SYSTEMD/audit-log-to-ntfy.timer" "$DST_SYSTEMD_DIR/audit-log-to-ntfy.timer"

systemctl daemon-reload
if ! systemctl is-enabled --quiet audit-log-to-ntfy.timer 2>/dev/null; then
  systemctl enable audit-log-to-ntfy.timer
fi
systemctl start audit-log-to-ntfy.timer

if [[ "$INSTALL_CONTEXT" == "update" ]]; then
  echo "Files updated. Timer reloaded."
else
  cat <<'POST_INSTALL'
Install complete.

Next steps:
1. Edit ntfy credentials:
   sudo vi /etc/audit-alerts/ntfy.env
2. Optional: tune alert behavior:
   sudo vi /etc/audit-alerts/audit-alerts.conf
3. Manual test run:
   sudo /usr/local/bin/audit-log-to-ntfy.sh
4. Check service logs:
   journalctl -u audit-log-to-ntfy.service -n 50 --no-pager
POST_INSTALL
fi
