formatter_render() {
  local decoded_cmd
  local default_summary
  local summary
  local path

  path="$(extract_target_path)"
  if [[ -z "$path" ]]; then
    path="unknown path"
  fi

  decoded_cmd="$(extract_proctitle_text)"

  # shellcheck disable=SC2059
  default_summary="$(printf "$L_SSHKEYS_SUMMARY" "$path" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}")"
  summary="${RULE_SSHKEYS_SUMMARY:-$default_summary}"

  FORMAT_TITLE="🔐 Audit: sshkeys on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    printf "%s %s\n" "$L_TTY" "${EVENT_TTY:-?}"
    if [[ -n "$decoded_cmd" ]]; then
      printf "%s %s\n" "$L_COMMAND" "$decoded_cmd"
    fi
    printf "\n"
    inspect_hint
  )"
}
