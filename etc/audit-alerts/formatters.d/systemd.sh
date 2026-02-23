formatter_render() {
  local path
  local scope

  path="$(extract_target_path)"
  if [[ -z "$path" ]]; then
    path="unknown path"
  fi

  scope="system"
  if [[ "${EVENT_KEY:-}" == "user-systemd" ]]; then
    scope="user"
  fi

  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-systemd} on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "User: %s (AUID=%s)\n" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s systemd change on: %s\n" "$scope" "$path"
    printf "Via: %s (%s)\n" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
    printf "TTY: %s\n" "${EVENT_TTY:-?}"
    printf "\n"
    inspect_hint
  )"
}
