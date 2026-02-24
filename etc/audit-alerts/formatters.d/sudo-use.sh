formatter_render() {
  local decoded_cmd
  local default_summary
  local summary

  decoded_cmd="$(extract_proctitle_text)"

  # shellcheck disable=SC2059
  default_summary="$(printf "$L_SUDO_SUMMARY" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}")"
  summary="${RULE_SUDO_SUMMARY:-$default_summary}"

  FORMAT_TITLE="🔐 Audit: sudo-use on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    printf "%s %s\n" "$L_UID" "${EVENT_UID:-?}"
    printf "%s %s\n" "$L_TTY" "${EVENT_TTY:-?}"
    if [[ -n "$decoded_cmd" ]]; then
      printf "%s %s\n" "$L_COMMAND" "$decoded_cmd"
    fi
    printf "\n"
    inspect_hint
  )"
}
