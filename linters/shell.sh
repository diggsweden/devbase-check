#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

find_shell_scripts() {
  find . -type f \( -name "*.sh" -o -name "*.bash" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./tests/libs/*" \
    2>/dev/null
}

find_bats_files() {
  find . -type f -name "*.bats" \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./tests/libs/*" \
    2>/dev/null
}

main() {
  print_header "SHELL SCRIPT LINTING (SHELLCHECK)"
  fail_if_mise_install_incomplete shellcheck || return 1

  local scripts
  scripts=$(find_shell_scripts)

  if [[ -z "$scripts" ]]; then
    print_info "No shell scripts found to check"
    emit_status "na" "n/a"
    return 0
  fi

  if ! command -v shellcheck >/dev/null 2>&1; then
    print_warning "shellcheck not found in PATH - skipping shell linting"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  local failed=0
  if ! echo "$scripts" | xargs -r shellcheck --severity=info --exclude=SC1091,SC2034,SC2155; then
    failed=1
  fi

  local bats_files
  bats_files=$(find_bats_files)

  if [[ -n "$bats_files" ]]; then
    print_info "Checking bats test files..."
    if ! echo "$bats_files" | xargs -r shellcheck --shell=bats --severity=info --exclude=SC1090,SC1091,SC2016,SC2030,SC2031,SC2034,SC2123,SC2155,SC2164,SC2218; then
      failed=1
    fi
  fi

  if [[ $failed -eq 0 ]]; then
    print_success "Shell script linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Shell script linting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
