formatter_render() {
  local decoded_cmd
  local summary

  decoded_cmd="$(extract_proctitle_text)"
  summary="${RULE_SUDO_SUMMARY:-sudo via: ${EVENT_EXE:-?} (${EVENT_COMM:-?})}"

  FORMAT_TITLE="🔐 Audit: sudo-use on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "User: %s (AUID=%s)\n" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    printf "UID: %s\n" "${EVENT_UID:-?}"
    printf "TTY: %s\n" "${EVENT_TTY:-?}"
    if [[ -n "$decoded_cmd" ]]; then
      printf "Command: %s\n" "$decoded_cmd"
    fi
    printf "\n"
    inspect_hint
  )"
}
