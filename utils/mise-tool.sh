#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Minimal mise helpers used by the linters:
#   - emit_status: shared status-marker emitter consumed by verify.sh.
#   - fail_if_mise_install_incomplete: fail the current linter with an
#     actionable message when mise reports pinned-but-not-installed tools.
#
# Design intent: mise itself is the source of truth for which tool version
# is in effect. When `mise activate` is loaded, its shims are first on
# PATH, so bare `command -v <tool>` in linters picks up the pinned version
# automatically. The one failure mode we need to catch is mise install
# being incomplete — e.g. pipx:reuse silently skipped because pipx isn't
# on the host. `mise ls --missing --json` is the authoritative check for
# that; no per-tool mapping needed.

# Shared status marker emitter. Writes the pipe-delimited markers that
# verify.sh parses. No-op unless DEVBASE_CHECK_MARKERS=1 is set.
emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

# Returns 0 iff mise reports any pinned-but-not-installed tools in the
# effective config (merged across parent .mise.toml files).
mise_has_missing_pins() {
  command -v mise >/dev/null 2>&1 || return 1
  local json
  json=$(mise ls --missing --json 2>/dev/null) || return 1
  [[ -n "$json" && "$json" != "{}" && "$json" != "[]" ]]
}

# Prints the missing pin names one per line (or nothing). Used by the
# preflight in verify.sh to show the user what's actually broken.
mise_list_missing_pins() {
  command -v mise >/dev/null 2>&1 || return 0
  mise ls --missing 2>/dev/null | awk 'NF{print $1}'
}

# Guard to place at the top of each linter's main(). Returns non-zero and
# emits a fail marker when a tool this linter depends on is pinned in mise
# but not installed. Caller should `return 1` on non-zero to short-circuit.
#
# Usage:
#   fail_if_mise_install_incomplete <tool> [<tool>...]
#     Fire only when one of the named tools matches a missing pin. Match is
#     a substring of the pin key (e.g. "reuse" matches "pipx:reuse",
#     "mvdan/sh" matches "aqua:mvdan/sh"). Use this from any linter whose
#     primary tool is pinned in .mise.toml.
#   fail_if_mise_install_incomplete  (no args)
#     Fire on any missing pin — coarse fallback, preserved for callers that
#     don't know their tool's pin key.
#
# Opt-outs (all silence this guard):
#   DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1 — locked-down envs; fall through to
#     whatever tool is on PATH.
#   DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1 — run anyway; each linter's own
#     tool-specific check will emit skip for the tools it needs.
#   DEVBASE_CHECK_PREFLIGHT_DONE=1 — verify.sh already reported the state
#     once; don't cascade the same message through every linter.
fail_if_mise_install_incomplete() {
  # ALLOW_SYSTEM_TOOLS: never gate; let the linter try whatever's on PATH.
  [[ "${DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS:-0}" == "1" ]] && return 0

  mise_has_missing_pins || return 0

  local all_missing=() relevant=() line
  while IFS= read -r line; do
    [[ -n "$line" ]] && all_missing+=("$line")
  done < <(mise_list_missing_pins)

  if (($# > 0)); then
    local pin want
    for pin in "${all_missing[@]}"; do
      for want in "$@"; do
        if [[ "$pin" == *"$want"* ]]; then
          relevant+=("$pin")
          break
        fi
      done
    done
    # Something is missing, but not this linter's tool — let it run.
    ((${#relevant[@]})) || return 0
  else
    relevant=("${all_missing[@]}")
  fi

  # This linter's tool is affected. Behaviour depends on context.
  if [[ "${DEVBASE_CHECK_IGNORE_MISSING_LINTERS:-0}" == "1" || "${DEVBASE_CHECK_PREFLIGHT_DONE:-0}" == "1" ]]; then
    # User opted to proceed with a partial install (or preflight already
    # reported the state). Skip this linter with a marker so verify.sh
    # shows it as skipped in the summary, not passed or failed.
    emit_status "skip" "mise pin missing"
    return 1
  fi

  # Running directly — print the full error.
  print_error "mise install is incomplete — run: mise install"
  printf '  - %s\n' "${relevant[@]}"
  printf '  (to skip: --ignore-missing-linters or DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1)\n'
  emit_status "fail" "mise install incomplete"
  return 1
}

# Returns the mise-resolved path for a tool, or empty. Used only by
# scripts/check-tools.sh to label provenance. Not needed by linters.
mise_tool_path() {
  command -v mise >/dev/null 2>&1 || return 1
  mise which "$1" 2>/dev/null
}
