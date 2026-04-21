#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

readonly MODE="${1:-check}"

find_shell_scripts() {
  find . -type f \( -name "*.sh" -o -name "*.bash" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./vendor/*" \
    -not -path "./tests/libs/*" \
    2>/dev/null
}

check_format() {
  local scripts="$1"
  if echo "$scripts" | xargs -r shfmt -i 2 -d; then
    print_success "Shell script formatting check passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Shell script formatting failed - run 'just lint-shell-fmt-fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

fix_format() {
  local scripts="$1"
  if echo "$scripts" | xargs -r shfmt -i 2 -w; then
    print_success "Shell scripts formatted"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Shell script formatting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main() {
  print_header "SHELL SCRIPT FORMATTING (SHFMT)"
  fail_if_mise_install_incomplete mvdan/sh || return 1

  local scripts
  scripts=$(find_shell_scripts)

  if [[ -z "$scripts" ]]; then
    print_info "No shell scripts found to format"
    emit_status "na" "n/a"
    return 0
  fi

  if ! command -v shfmt >/dev/null 2>&1; then
    print_warning "shfmt not found in PATH - skipping shell formatting"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  case "$MODE" in
  check) check_format "$scripts" ;;
  fix) fix_format "$scripts" ;;
  *)
    print_error "Unknown mode: $MODE"
    printf "Usage: %s [check|fix]\n" "$0"
    emit_status "fail" "failed"
    return 1
    ;;
  esac
}

main
