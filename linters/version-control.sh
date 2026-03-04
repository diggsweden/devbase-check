#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

main() {
  print_header "WORKING TREE"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not a Git repository - cannot verify version control state"
    emit_status "fail" "failed"
    return 1
  fi

  if [[ -z "$(git status --porcelain)" ]]; then
    print_success "All changes are under version control"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Some changes are not under version control!

  This can happen if

    1. You forgot to version control your changes
    2. A linter automatically fixed a problem or reformatted the code.

  Please accept or discard any outstanding changes and try again."
    emit_status "fail" "failed"
    return 1
  fi
}

main
