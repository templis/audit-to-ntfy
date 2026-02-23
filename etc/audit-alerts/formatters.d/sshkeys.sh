formatter_render() {
  local path
  local summary

  path="$(extract_target_path)"
  if [[ -z "$path" ]]; then
    path="unknown path"
  fi

  summary="write on: ${path} with: ${EVENT_EXE:-?} (${EVENT_COMM:-?})"

  FORMAT_TITLE="🔐 Audit: sshkeys on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "User: %s (AUID=%s)\n" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    printf "TTY: %s\n" "${EVENT_TTY:-?}"
    printf "\n"
    inspect_hint
  )"
}
