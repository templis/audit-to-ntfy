formatter_render() {
  local path
  local decoded_cmd
  local summary

  path="$(extract_target_path)"
  if [[ -z "$path" ]]; then
    path="unknown path"
  fi

  decoded_cmd="$(extract_proctitle_text)"

  summary="${RULE_SSHKEYS_SUMMARY:-write on: ${path} with: ${EVENT_EXE:-?} (${EVENT_COMM:-?})}"

  FORMAT_TITLE="🔐 Audit: sshkeys on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "User: %s (AUID=%s)\n" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    printf "TTY: %s\n" "${EVENT_TTY:-?}"
    if [[ -n "$decoded_cmd" ]]; then
      printf "Command: %s\n" "$decoded_cmd"
    fi
    printf "\n"
    inspect_hint
  )"
}
