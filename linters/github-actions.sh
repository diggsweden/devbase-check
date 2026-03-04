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
  print_header "GITHUB ACTIONS LINTING (ACTIONLINT)"

  if [[ ! -d .github/workflows ]]; then
    print_info "No GitHub Actions workflows found to check"
    emit_status "na" "n/a"
    return 0
  fi

  if ! command -v actionlint >/dev/null 2>&1; then
    print_warning "actionlint not found in PATH - skipping GitHub Actions linting"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  if actionlint; then
    print_success "GitHub Actions linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "GitHub Actions linting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
