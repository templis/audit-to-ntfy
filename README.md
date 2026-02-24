# audit-to-ntfy

`audit-to-ntfy` reads new records from Linux `auditd` logs and sends concise interpreted alerts to an `ntfy` server using bearer token auth.

The project is designed for Arch Linux KDE and stays portable across distros by using Bash and standard Linux tools.

## Features

- Offset-based log reading from `/var/log/audit/audit.log`
- Deduplication by audit `msgid` / serial (`/var/lib/audit-log-to-ntfy.lastmsg`)
- Configurable key filter (default: `sshkeys`, `sudo-use`, `priv-esc`, `systemd`, `user-systemd`, `dir-watch`)
- Modular formatter plugins (`formatters.d/<key>.sh`, fallback to `default.sh`)
- Optional custom rulesets per module via sourced files in `rules.d`
- NTFY delivery with `curl --config /dev/null` and bearer token
- Message size cap (`MAX_BODY`) to avoid oversized payload rejection
- systemd oneshot service + periodic timer
- Self-update workflow via `update.sh`

## Repository Layout

- `bin/audit-log-to-ntfy.sh` core runner
- `etc/audit-alerts/ntfy.env.example` ntfy credentials template
- `etc/audit-alerts/audit-alerts.conf.example` behavior config template
- `etc/audit-alerts/format.sh` formatter dispatcher/helpers
- `etc/audit-alerts/formatters.d/*.sh` key-specific formatter plugins
- `etc/audit-alerts/rules.d/*.rules.sh` editable custom ruleset files
- `etc/systemd/audit-log-to-ntfy.service` systemd service
- `etc/systemd/audit-log-to-ntfy.timer` systemd timer
- `install.sh` idempotent installer
- `update.sh` self-update script (`git pull` + reinstall)

## Prerequisites

- Linux with `auditd` enabled and writing `/var/log/audit/audit.log`
- `audit` userspace tools installed (for `ausearch` during investigations)
- `curl`
- systemd
- Root privileges for install/runtime

## Quick Install (install.sh)

```bash
cd /path/to/audit-to-ntfy
sudo ./install.sh
```

Then edit credentials:

```bash
sudo vi /etc/audit-alerts/ntfy.env
```

Manual test:

```bash
sudo /usr/local/bin/audit-log-to-ntfy.sh
```

Check logs:

```bash
journalctl -u audit-log-to-ntfy.service -n 50 --no-pager
```

Update later:

```bash
sudo /usr/local/bin/audit-to-ntfy-update.sh
```

## Update

From the repository checkout:

```bash
sudo ./update.sh
```

If your checkout is elsewhere, set the path explicitly:

```bash
sudo AUDIT_TO_NTFY_REPO=/path/to/audit-to-ntfy /usr/local/bin/audit-to-ntfy-update.sh
```

## Manual Installation (mirrors install.sh exactly)

Run these commands from the project root:

```bash
sudo install -d -m 755 /etc/audit-alerts
sudo install -d -m 755 /etc/audit-alerts/formatters.d
sudo install -d -m 755 /etc/audit-alerts/rules.d
sudo install -d -m 755 /etc/systemd/system

sudo install -m 755 bin/audit-log-to-ntfy.sh /usr/local/bin/audit-log-to-ntfy.sh
sudo install -m 755 update.sh /usr/local/bin/audit-to-ntfy-update.sh
sudo install -m 755 etc/audit-alerts/format.sh /etc/audit-alerts/format.sh

for formatter_file in default.sh dir-watch.sh sshkeys.sh sudo-use.sh systemd.sh; do
  sudo install -m 644 "etc/audit-alerts/formatters.d/${formatter_file}" "/etc/audit-alerts/formatters.d/${formatter_file}"
done

for ruleset_file in common.rules.sh default.rules.sh dir-watch.rules.sh sshkeys.rules.sh sudo-use.rules.sh systemd.rules.sh user-systemd.rules.sh priv-esc.rules.sh; do
  if [ ! -f "/etc/audit-alerts/rules.d/${ruleset_file}" ]; then
    sudo install -m 644 "etc/audit-alerts/rules.d/${ruleset_file}" "/etc/audit-alerts/rules.d/${ruleset_file}"
  fi
done

sudo install -m 644 etc/audit-alerts/ntfy.env.example /etc/audit-alerts/ntfy.env.example
sudo install -m 644 etc/audit-alerts/audit-alerts.conf.example /etc/audit-alerts/audit-alerts.conf.example
```

Create live config files from examples only if missing:

```bash
if [ ! -f /etc/audit-alerts/ntfy.env ]; then
  sudo install -m 600 etc/audit-alerts/ntfy.env.example /etc/audit-alerts/ntfy.env
else
  sudo chmod 600 /etc/audit-alerts/ntfy.env
fi

if [ ! -f /etc/audit-alerts/audit-alerts.conf ]; then
  sudo install -m 644 etc/audit-alerts/audit-alerts.conf.example /etc/audit-alerts/audit-alerts.conf
else
  sudo chmod 644 /etc/audit-alerts/audit-alerts.conf
fi
```

Set ownership:

```bash
sudo chown root:root \
  /usr/local/bin/audit-log-to-ntfy.sh \
  /usr/local/bin/audit-to-ntfy-update.sh \
  /etc/audit-alerts/format.sh \
  /etc/audit-alerts/ntfy.env.example \
  /etc/audit-alerts/audit-alerts.conf.example \
  /etc/audit-alerts/ntfy.env \
  /etc/audit-alerts/audit-alerts.conf

for formatter_file in default.sh dir-watch.sh sshkeys.sh sudo-use.sh systemd.sh; do
  sudo chown root:root "/etc/audit-alerts/formatters.d/${formatter_file}"
done

for ruleset_file in common.rules.sh default.rules.sh dir-watch.rules.sh sshkeys.rules.sh sudo-use.rules.sh systemd.rules.sh user-systemd.rules.sh priv-esc.rules.sh; do
  sudo chown root:root "/etc/audit-alerts/rules.d/${ruleset_file}"
done
```

Install systemd units:

```bash
sudo install -m 644 etc/systemd/audit-log-to-ntfy.service /etc/systemd/system/audit-log-to-ntfy.service
sudo install -m 644 etc/systemd/audit-log-to-ntfy.timer /etc/systemd/system/audit-log-to-ntfy.timer
sudo chown root:root /etc/systemd/system/audit-log-to-ntfy.service /etc/systemd/system/audit-log-to-ntfy.timer
```

Enable/start timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now audit-log-to-ntfy.timer
```

## Configuration

### `/etc/audit-alerts/ntfy.env` (mode `600`, root owned)

```bash
NTFY_URL="https://ntfy.example.com"
NTFY_TOPIC="audit_alerts"
NTFY_TOKEN="REPLACE_WITH_REAL_TOKEN"
```

### `/etc/audit-alerts/audit-alerts.conf`

```bash
ALERT_KEYS_REGEX=' key="(sshkeys|sudo-use|priv-esc|systemd|user-systemd)"'
MAX_BODY=1200
HOME_USER=""
HOME_DIR=""
FORMATTERS_DIR="/etc/audit-alerts/formatters.d"
RULESETS_DIR="/etc/audit-alerts/rules.d"
```

- `ALERT_KEYS_REGEX`: Controls which audit keys trigger notifications.
- `MAX_BODY`: Max message body length before truncation.
- `HOME_USER` / `HOME_DIR`: Used to shorten matching paths to `~`.
- `FORMATTERS_DIR`: Formatter plugin directory.
- `RULESETS_DIR`: Directory for optional sourced custom rulesets.

## Custom Rulesets

Rulesets are sourced from:

- `/etc/audit-alerts/rules.d/common.rules.sh`
- `/etc/audit-alerts/rules.d/<key>.rules.sh` (for example `sshkeys.rules.sh`, `sudo-use.rules.sh`)

Each ruleset file is created by `install.sh` (and therefore also by `update.sh` via reinstall).
The file header explicitly says to edit only below `###`.

Supported override variables:

- global: `RULE_TITLE_OVERRIDE`, `RULE_TITLE_PREFIX`, `RULE_BODY_PREPEND`, `RULE_BODY_APPEND`
- `sshkeys`: `RULE_SSHKEYS_SUMMARY`
- `sudo-use`: `RULE_SUDO_SUMMARY`
- `systemd` and `user-systemd`: `RULE_SYSTEMD_SUMMARY`
- `priv-esc`: `RULE_PRIV_ESC_SUMMARY`
- `dir-watch`: `RULE_DIRWATCH_SUMMARY`
- fallback/default: `RULE_DEFAULT_SUMMARY`

If you create useful rulesets, please send them as examples so other users can benefit too.

## Formatter Behavior

- `sshkeys`: highlights write target path and editor/process
- `sudo-use`: shows invoking user and decoded proctitle command when available
- `priv-esc`: summarizes uid/euid context and executable
- `systemd` / `user-systemd`: highlights changed path and scope
- `dir-watch`: shows operation type (modified/renamed/deleted/…) and affected path
- fallback: `default.sh`

Each message includes:

- Title: `🔐 Audit: <key> on <hostname>`
- User and process context
- Investigation hint:
  - `sudo ausearch --event <SERIAL> -i`

## Testing

### Safe manual ntfy test (avoid credentials in shell history)

Use a temporary shell that sources the env file:

```bash
sudo bash -c '
  set -a
  source /etc/audit-alerts/ntfy.env
  printf "audit-to-ntfy manual test\n" | \
    curl --config /dev/null -sS \
      -H "Authorization: Bearer ${NTFY_TOKEN}" \
      -H "Title: audit-to-ntfy test" \
      --data-binary @- \
      "${NTFY_URL%/}/${NTFY_TOPIC}"
'
```

### Trigger representative audit events

- `sshkeys` style event: edit `~/.ssh/config`
- `sudo-use` style event: run `sudo true`
- `systemd` / `user-systemd`: edit corresponding unit files and reload daemon

Then force a run:

```bash
sudo /usr/local/bin/audit-log-to-ntfy.sh
```

Inspect exact event from alert serial:

```bash
sudo ausearch --event <SERIAL> -i
```

## Troubleshooting

- `attachments not allowed`:
  - Ensure the script uses `curl --config /dev/null`
  - Keep `MAX_BODY` modest
- Alert spam:
  - Narrow `ALERT_KEYS_REGEX`
  - Do not include `rootcmd` in default filters
- No notifications:
  - Confirm subscriber topic matches `NTFY_TOPIC`
  - Confirm timer is active:
    - `systemctl status audit-log-to-ntfy.timer`
  - Check service logs:
    - `journalctl -u audit-log-to-ntfy.service -n 50 --no-pager`

## License

GPL-3.0-or-later, see `LICENSE`.
