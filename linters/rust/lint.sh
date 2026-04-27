#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"

emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

main() {
  print_header "RUST LINTING (ALL)"

  local failed=0

  "${SCRIPT_DIR}/cargo_clippy.sh" || failed=1
  "${SCRIPT_DIR}/cargo_fmt.sh" || failed=1

  if [[ $failed -eq 0 ]]; then
    print_success "All Rust linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Some Rust linting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
