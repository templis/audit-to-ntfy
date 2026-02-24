_systemd_action_label() {
  local num="$1"
  case "$num" in
    82|264|316) echo "$L_SYSTEMD_ACT_RENAMED" ;;
    83)         echo "$L_SYSTEMD_ACT_MKDIR" ;;
    87|263)     echo "$L_SYSTEMD_ACT_REMOVED" ;;
    88)         echo "$L_SYSTEMD_ACT_SYMLINKED" ;;
    *)          echo "" ;;
  esac
}

_systemd_exit_label() {
  local code="$1"
  case "$code" in
    0)   echo "$L_RESULT_OK" ;;
    -2)  echo "$L_RESULT_NOT_FOUND" ;;
    -13) echo "$L_RESULT_PERM_DENIED" ;;
    -17) echo "$L_RESULT_ALREADY_EXISTS" ;;
    -28) echo "$L_RESULT_NO_SPACE" ;;
    *)   echo "exit=$code" ;;
  esac
}

formatter_render() {
  local path
  local scope
  local default_summary
  local summary
  local syscall_num
  local action_label
  local success
  local exit_code
  local result_line

  path="$(extract_target_path)"
  if [[ -z "$path" ]]; then
    path="unknown path"
  fi

  scope="$L_SYSTEMD_SCOPE_SYSTEM"
  if [[ "${EVENT_KEY:-}" == "user-systemd" ]]; then
    scope="$L_SYSTEMD_SCOPE_USER"
  fi

  syscall_num="$(extract_numeric_field "syscall" "$SYSCALL_LINE")"
  action_label="$(_systemd_action_label "$syscall_num")"

  success="$(sed -n 's/.* success=\([a-z]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"
  exit_code="$(sed -n 's/.* exit=\(-\?[0-9]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"

  if [[ "$success" == "yes" ]]; then
    result_line="$L_RESULT_OK"
  elif [[ -n "$exit_code" ]]; then
    result_line="${L_RESULT_FAILED} $(_systemd_exit_label "$exit_code")"
  fi

  # shellcheck disable=SC2059
  default_summary="$(printf "$L_SYSTEMD_CHANGE" "$scope" "$path")"
  summary="${RULE_SYSTEMD_SUMMARY:-$default_summary}"

  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-systemd} on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    if [[ -n "$action_label" ]]; then
      printf "%s %s\n" "$L_ACTION" "$action_label"
    fi
    if [[ -n "${result_line:-}" ]]; then
      printf "%s %s\n" "$L_RESULT" "$result_line"
    fi
    printf "%s %s (%s)\n" "$L_VIA" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
    printf "%s %s\n" "$L_TTY" "${EVENT_TTY:-?}"
    printf "\n"
    inspect_hint
  )"
}
