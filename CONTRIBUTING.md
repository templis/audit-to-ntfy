# Contributing to audit-to-ntfy

Contributions are welcome. The project grows through shared formatters,
language files, and ruleset examples — if you built something useful,
others will benefit from it too.

All contributions must be submitted under the GPL-3.0-or-later license.

## Ways to contribute

### 1. New formatter

Formatters live in `etc/audit-alerts/formatters.d/` and handle a specific
audit key. A formatter is a Bash file that defines a single function:

```bash
formatter_render() {
  # Build FORMAT_TITLE and FORMAT_BODY using L_* variables for all
  # user-visible strings. Helper functions from format.sh are available:
  #   extract_target_path, extract_proctitle_text, inspect_hint, ...
  FORMAT_TITLE="🔐 Audit: ${EVENT_KEY} on ${AUDIT_HOST}"
  FORMAT_BODY="$(
    printf "%s %s (AUID=%s)\n" "$L_USER" "${EVENT_USER:-unknown}" "${EVENT_AUID:-?}"
    # ...
    printf "\n"
    inspect_hint
  )"
}
```

Checklist before submitting:
- [ ] File named after the audit key: `<key>.sh`
- [ ] All user-visible strings use `L_*` variables (no hardcoded English)
- [ ] Passes `bash -n` syntax check
- [ ] Respects `RULE_<KEY>_SUMMARY` for ruleset overrides where applicable
- [ ] Entry added to `FORMATTER_FILES` in `install.sh`
- [ ] Corresponding `<key>.rules.sh` stub added to `etc/audit-alerts/rules.d/`
  and `RULESET_FILES` in `install.sh`
- [ ] New `L_*` variables added to `format.sh` defaults and both
  `lang/en_US.sh` and `lang/de_DE.sh`

### 2. New language file

Language files live in `etc/audit-alerts/lang/`. Copy `en_US.sh` as your
starting point — it lists every translatable string.

```bash
cp etc/audit-alerts/lang/en_US.sh etc/audit-alerts/lang/<locale>.sh
# translate all values, keep variable names unchanged
```

Checklist before submitting:
- [ ] File named `<locale>.sh` (e.g. `fr_FR.sh`, `es_ES.sh`)
- [ ] All variables from `en_US.sh` present (no missing keys)
- [ ] Passes `bash -n` syntax check
- [ ] Entry added to `LANG_FILES` in `install.sh`

### 3. Ruleset example

Rulesets are sourced Bash files that override notification content via
`RULE_*` variables. They live in `etc/audit-alerts/rules.d/`.

If you have a useful ruleset — for example a custom `sudo-use.rules.sh`
that highlights package manager calls differently — share it as an example
in `docs/ruleset-examples/` with a short comment explaining what it does.

No `install.sh` changes needed for example files.

## Submitting

Open a pull request against the `main` branch on the primary repository.
Please include a short description of what the contribution does and, if
it is a formatter or language file, a sample notification showing the output.
