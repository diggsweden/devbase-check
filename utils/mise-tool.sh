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
# emits a fail marker when `mise install` is incomplete for this project.
# Caller should `return 1` on non-zero to short-circuit the linter.
#
# Opt-outs (all silence this guard):
#   DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1 — locked-down envs; fall through to
#     whatever tool is on PATH.
#   DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1 — run anyway; each linter's own
#     tool-specific check will emit skip for the tools it needs.
#   DEVBASE_CHECK_PREFLIGHT_DONE=1 — verify.sh already reported the state
#     once; don't cascade the same message through every linter.
fail_if_mise_install_incomplete() {
  [[ "${DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS:-0}" == "1" ]] && return 0
  [[ "${DEVBASE_CHECK_IGNORE_MISSING_LINTERS:-0}" == "1" ]] && return 0
  [[ "${DEVBASE_CHECK_PREFLIGHT_DONE:-0}" == "1" ]] && return 0
  mise_has_missing_pins || return 0
  print_error "mise install is incomplete — run: mise install"
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  - %s\n' "$line"
  done < <(mise_list_missing_pins)
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
