# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`audit-to-ntfy` is a Bash-only tool that tails `auditd` logs and delivers formatted security alerts to an `ntfy` server. No build step, no package manager — pure Bash and standard Linux tools. Requires root at runtime.

## Common Commands

**Install:**
```bash
sudo ./install.sh
```

**Manual run (after install):**
```bash
sudo /usr/local/bin/audit-log-to-ntfy.sh
```

**Check service logs:**
```bash
journalctl -u audit-log-to-ntfy.service -n 50 --no-pager
```

**Update (from repo checkout):**
```bash
sudo ./update.sh
# or after install:
sudo /usr/local/bin/audit-to-ntfy-update.sh
```

**Safe ntfy delivery test (avoids credentials in shell history):**
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

**Inspect a specific audit event:**
```bash
sudo ausearch --event <SERIAL> -i
```

## Architecture

The pipeline runs as a systemd oneshot service every 15 seconds.

### Core Pipeline (`bin/audit-log-to-ntfy.sh`)

1. Reads `/var/log/audit/audit.log` from a byte offset stored in `/var/lib/audit-log-to-ntfy.offset`
2. Filters lines matching `ALERT_KEYS_REGEX` from `/etc/audit-alerts/audit-alerts.conf`
3. Deduplicates by `msg=audit(timestamp:serial)` — last processed serial in `/var/lib/audit-log-to-ntfy.lastmsg`
4. For each new event, calls `format.sh` to produce title + body, then POSTs to ntfy via curl

### Formatter Dispatcher (`etc/audit-alerts/format.sh`)

Sources a formatter plugin based on the audit key:
- `etc/audit-alerts/formatters.d/<key>.sh` — key-specific formatter (e.g. `sudo-use.sh`, `sshkeys.sh`)
- Falls back to `default.sh` if no key-specific file exists

Each formatter plugin defines a `formatter_render()` function that sets two variables: `FORMAT_TITLE` and `FORMAT_BODY`. The dispatcher also sources ruleset overrides before/after rendering.

### Ruleset Overrides (`etc/audit-alerts/rules.d/`)

After the formatter runs, these sourced files can override or augment output:
- `common.rules.sh` — always sourced
- `<key>.rules.sh` — sourced per audit key (e.g. `sshkeys.rules.sh`)

Override variables: `RULE_TITLE_OVERRIDE`, `RULE_TITLE_PREFIX`, `RULE_BODY_PREPEND`, `RULE_BODY_APPEND`, and module-specific summary variables (`RULE_SSHKEYS_SUMMARY`, `RULE_SUDO_SUMMARY`, etc.).

Ruleset files are installed by `install.sh` only if missing (preserving user edits on update). The file header marks the safe edit zone below `###`.

### State Files (runtime, not in repo)

- `/var/lib/audit-log-to-ntfy.offset` — byte offset into audit.log
- `/var/lib/audit-log-to-ntfy.lastmsg` — last processed msg serial for deduplication
- `/tmp/audit-log-to-ntfy.last` — last curl HTTP response (temporary)

### Coding Conventions

- All scripts use `set -euo pipefail`
- `curl --config /dev/null` is mandatory — prevents `.curlrc` injection and avoids ntfy rejecting the request as an "attachment"
- Configuration lives under `/etc/audit-alerts/`; credentials in `ntfy.env` must be mode `600`, root-owned
- `install.sh` is idempotent; ruleset files are only created if absent (not overwritten)
