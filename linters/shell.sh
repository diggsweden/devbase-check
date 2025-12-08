#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

find_shell_scripts() {
  find . -type f \( -name "*.sh" -o -name "*.bash" \) \
    -not -path "./.git/*" \
    -not -path "./tests/libs/*" \
    2>/dev/null
}

find_bats_files() {
  find . -type f -name "*.bats" \
    -not -path "./.git/*" \
    -not -path "./tests/libs/*" \
    2>/dev/null
}

main() {
  print_header "SHELL SCRIPT LINTING (SHELLCHECK)"

  local scripts
  scripts=$(find_shell_scripts)

  if [[ -z "$scripts" ]]; then
    print_info "No shell scripts found to check"
    return 0
  fi

  if ! command -v shellcheck >/dev/null 2>&1; then
    print_warning "shellcheck not found in PATH - skipping shell linting"
    echo "  Install: mise install"
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
    if ! echo "$bats_files" | xargs -r shellcheck --shell=bats --severity=info --exclude=SC1091,SC2034,SC2155,SC2164; then
      failed=1
    fi
  fi

  if [[ $failed -eq 0 ]]; then
    print_success "Shell script linting passed"
    return 0
  else
    print_error "Shell script linting failed"
    return 1
  fi
}

main
