formatter_render() {
  local path
  local default_summary
  local priv_esc_summary
  path="$(extract_target_path)"

  default_summary="${RULE_DEFAULT_SUMMARY:-}"
  priv_esc_summary=""
  if [[ "${EVENT_KEY:-}" == "priv-esc" ]]; then
    priv_esc_summary="${RULE_PRIV_ESC_SUMMARY:-priv-esc summary: uid=${EVENT_UID:-?} euid=${EVENT_EUID:-?} exe=${EVENT_EXE:-?}}"
  fi

  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY:-event} on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s %s\n" "$L_UID" "${EVENT_UID:-?}"
    if [[ -n "$default_summary" ]]; then
      printf "%s\n" "$default_summary"
    fi
    if [[ -n "$priv_esc_summary" ]]; then
      printf "%s\n" "$priv_esc_summary"
    fi
    printf "%s %s (%s)\n" "$L_EXE" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
    printf "%s %s\n" "$L_TTY" "${EVENT_TTY:-?}"
    if [[ -n "$path" ]]; then
      printf "%s %s\n" "$L_PATH" "$path"
    fi
    printf "\n"
    inspect_hint
  )"
}
