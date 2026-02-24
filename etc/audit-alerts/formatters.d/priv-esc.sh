formatter_render() {
  local decoded_cmd
  local uid_label
  local exe_label

  decoded_cmd="$(extract_proctitle_text)"

  # Show the privilege change as an arrow when uid != euid
  if [[ "${EVENT_UID:-?}" != "${EVENT_EUID:-?}" ]]; then
    uid_label="uid=${EVENT_UID:-?} → euid=${EVENT_EUID:-?}"
  else
    uid_label="uid=${EVENT_UID:-?} euid=${EVENT_EUID:-?}"
  fi

  # Label common setuid executables in plain language
  case "${EVENT_EXE:-}" in
    */unix_chkpwd)  exe_label="PAM password check (${EVENT_COMM:-?})" ;;
    */su)           exe_label="switch user (su)" ;;
    */newgrp)       exe_label="new group (newgrp)" ;;
    */pkexec)       exe_label="polkit exec (pkexec)" ;;
    */passwd)       exe_label="password change (passwd)" ;;
    */chfn|*/chsh)  exe_label="change user info (${EVENT_COMM:-?})" ;;
    */mount|*/umount) exe_label="mount operation (${EVENT_COMM:-?})" ;;
    *)              exe_label="${EVENT_EXE:-?} (${EVENT_COMM:-?})" ;;
  esac

  FORMAT_TITLE="🔐 Audit: priv-esc on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "User: %s (AUID=%s)\n" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "Action: %s\n" "${RULE_PRIV_ESC_SUMMARY:-$exe_label}"
    printf "Escalation: %s\n" "$uid_label"
    printf "TTY: %s\n" "${EVENT_TTY:-?}"
    if [[ -n "$decoded_cmd" ]]; then
      printf "Command: %s\n" "$decoded_cmd"
    fi
    printf "\n"
    inspect_hint
  )"
}
