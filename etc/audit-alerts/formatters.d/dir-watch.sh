_dir_watch_action_label() {
  local num="$1"
  case "$num" in
    # write / create / truncate
    1|2|76|77|85|257)  echo "$L_DIRWATCH_ACT_WRITE" ;;
    # rename
    82|264|316)         echo "$L_DIRWATCH_ACT_RENAMED" ;;
    # mkdir
    83|258)             echo "$L_DIRWATCH_ACT_MKDIR" ;;
    # rmdir
    84)                 echo "$L_DIRWATCH_ACT_RMDIR" ;;
    # unlink / unlinkat
    87|263)             echo "$L_DIRWATCH_ACT_DELETED" ;;
    # symlink
    88|266)             echo "$L_DIRWATCH_ACT_SYMLINKED" ;;
    # link
    86|265)             echo "$L_DIRWATCH_ACT_LINKED" ;;
    # chmod / fchmod / fchmodat / setxattr
    90|91|188|189|190|268) echo "$L_DIRWATCH_ACT_CHMOD" ;;
    # chown / lchown / fchown / fchownat
    92|93|94|260)       echo "$L_DIRWATCH_ACT_CHOWN" ;;
    # execve / execveat
    59|322)             echo "$L_DIRWATCH_ACT_EXEC" ;;
    *)                  echo "" ;;
  esac
}

formatter_render() {
  local path
  local syscall_num
  local action_label
  local success
  local exit_code
  local result_line
  local default_summary
  local summary

  path="$(extract_target_path)"
  [[ -z "$path" ]] && path="unknown path"

  syscall_num="$(extract_numeric_field "syscall" "$SYSCALL_LINE")"
  action_label="$(_dir_watch_action_label "$syscall_num")"

  success="$(sed -n 's/.* success=\([a-z]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"
  exit_code="$(sed -n 's/.* exit=\(-\?[0-9]*\).*/\1/p' <<<"$SYSCALL_LINE" | head -n 1)"

  if [[ "$success" == "yes" ]]; then
    result_line="$L_RESULT_OK"
  elif [[ -n "$exit_code" && "$exit_code" != "0" ]]; then
    result_line="${L_RESULT_FAILED} exit=${exit_code}"
  fi

  # shellcheck disable=SC2059
  default_summary="$(printf "$L_DIRWATCH_SUMMARY" "${action_label:-?}" "$path")"
  summary="${RULE_DIRWATCH_SUMMARY:-$default_summary}"

  FORMAT_TITLE="🔐 Audit: dir-watch on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    printf "%s\n" "$summary"
    if [[ -n "${result_line:-}" ]]; then
      printf "%s %s\n" "$L_RESULT" "$result_line"
    fi
    printf "%s %s (%s)\n" "$L_VIA" "${EVENT_EXE:-?}" "${EVENT_COMM:-?}"
    printf "%s %s\n" "$L_TTY" "${EVENT_TTY:-?}"
    printf "\n"
    inspect_hint
  )"
}
