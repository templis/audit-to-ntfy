formatter_render() {
  local decoded_cmd
  local uid_label
  local exe_label

  decoded_cmd="$(extract_proctitle_text)"

  if [[ "${EVENT_UID:-?}" != "${EVENT_EUID:-?}" ]]; then
    uid_label="uid=${EVENT_UID:-?} → euid=${EVENT_EUID:-?}"
  else
    uid_label="uid=${EVENT_UID:-?} euid=${EVENT_EUID:-?}"
  fi

  # shellcheck disable=SC2059
  case "${EVENT_EXE:-}" in
    */unix_chkpwd)    exe_label="$(printf "$L_PRIV_PAM"    "${EVENT_COMM:-?}")" ;;
    */su)             exe_label="$L_PRIV_SU" ;;
    */newgrp)         exe_label="$L_PRIV_NEWGRP" ;;
    */pkexec)         exe_label="$L_PRIV_PKEXEC" ;;
    */passwd)         exe_label="$L_PRIV_PASSWD" ;;
    */chfn|*/chsh)    exe_label="$(printf "$L_PRIV_CHUSER" "${EVENT_COMM:-?}")" ;;
    */mount|*/umount) exe_label="$(printf "$L_PRIV_MOUNT"  "${EVENT_COMM:-?}")" ;;
    *)                exe_label="${EVENT_EXE:-?} (${EVENT_COMM:-?})" ;;
  esac

  FORMAT_TITLE="🔐 Audit: priv-esc on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s %s\n" "$L_ACTION" "${RULE_PRIV_ESC_SUMMARY:-$exe_label}"
    printf "%s %s\n" "$L_ESCALATION" "$uid_label"
    printf "%s %s\n" "$L_TTY" "${EVENT_TTY:-?}"
    if [[ -n "$decoded_cmd" ]]; then
      printf "%s %s\n" "$L_COMMAND" "$decoded_cmd"
    fi
    printf "\n"
    inspect_hint
  )"
}
