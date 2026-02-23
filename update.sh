#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_DIR="${AUDIT_TO_NTFY_REPO:-}"
ALLOW_DIRTY="${AUDIT_TO_NTFY_ALLOW_DIRTY:-0}"

detect_repo_dir() {
  if [[ -n "$REPO_DIR" ]]; then
    return
  fi

  if [[ -d "$SCRIPT_DIR/.git" ]]; then
    REPO_DIR="$SCRIPT_DIR"
    return
  fi

  if [[ -d "/opt/audit-to-ntfy/.git" ]]; then
    REPO_DIR="/opt/audit-to-ntfy"
    return
  fi

  echo "Could not detect git checkout." >&2
  echo "Set AUDIT_TO_NTFY_REPO=/path/to/audit-to-ntfy and run again." >&2
  exit 1
}

for cmd in git bash; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

detect_repo_dir

if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $REPO_DIR" >&2
  exit 1
fi

if [[ "$ALLOW_DIRTY" != "1" ]]; then
  if ! git -C "$REPO_DIR" diff --quiet || ! git -C "$REPO_DIR" diff --cached --quiet; then
    echo "Working tree is dirty in $REPO_DIR. Commit/stash first, or set AUDIT_TO_NTFY_ALLOW_DIRTY=1." >&2
    exit 1
  fi
fi

echo "Updating repository at $REPO_DIR ..."
git -C "$REPO_DIR" pull --ff-only

echo "Re-installing updated files ..."
if (( EUID == 0 )); then
  bash "$REPO_DIR/install.sh"
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required to run install.sh as root." >&2
    exit 1
  fi
  sudo bash "$REPO_DIR/install.sh"
fi

echo "Update complete."
