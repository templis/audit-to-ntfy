_systemd_action_label() {
  # Maps raw syscall number to a human-readable action label.
  # x86_64 syscall numbers for the operations systemd commonly triggers.
  local num="$1"
  case "$num" in
    82|264|316) echo "renamed" ;;
    83)         echo "mkdir" ;;
    87|263)     echo "removed" ;;
    88)         echo "symlinked (enable)" ;;
    *)          echo "" ;;
  esac
}

_systemd_exit_label() {
  local code="$1"
  case "$code" in
    0)   echo "ok" ;;
    -2)  echo "not found" ;;
    -13) echo "permission denied" ;;
    -17) echo "already exists" ;;
    -28) echo "no space" ;;
    *)   echo "exit=$code" ;;
  esac
}

formatter_render() {
  local path
  local scope
  local summary
  local syscall_num
  local action_label
  local success
  local exit_code
  local exit_label
  local result_line

  path="$(extract_target_path)"
  if [[ -z "$path" ]]; then
    path="unknown path"
  fi

  scope="system"
  if [[ "${EVENT_KEY:-}" == "user-systemd" ]]; then
    scope="user"
  fi

  syscall_num="$(extract_numeric_field "syscall" "$SYSCALL_LINE")"
  action_label="$(_systemd_action_label "$syscall_num")"

  success="$(sed -n 's/.* success=\([a-z]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"
  exit_code="$(sed -n 's/.* exit=\(-\?[0-9]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"

  if [[ "$success" == "yes" ]]; then
    result_line="success"
  elif [[ -n "$exit_code" ]]; then
    exit_label="$(_systemd_exit_label "$exit_code")"
    result_line="failed: ${exit_label}"
  fi

  summary="${RULE_SYSTEMD_SUMMARY:-${scope} systemd change on: ${path}}"

  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-systemd} on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "User: %s (AUID=%s)\n" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    if [[ -n "$action_label" ]]; then
      printf "Action: %s\n" "$action_label"
    fi
    if [[ -n "$result_line" ]]; then
      printf "Result: %s\n" "$result_line"
    fi
    printf "Via: %s (%s)\n" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
    printf "TTY: %s\n" "${EVENT_TTY:-?}"
    printf "\n"
    inspect_hint
  )"
}
