#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

find_containerfiles() {
  find . -type f \( -name "Containerfile" -o -name "Containerfile.*" -o -name "Dockerfile" -o -name "Dockerfile.*" \) -not -path "./.git/*" 2>/dev/null
}

main() {
  print_header "CONTAINER LINTING (HADOLINT)"
  fail_if_mise_install_incomplete || return 1

  local files
  files=$(find_containerfiles)

  if [[ -z "$files" ]]; then
    print_info "No Containerfile/Dockerfile found to check"
    emit_status "na" "n/a"
    return 0
  fi

  if ! command -v hadolint >/dev/null 2>&1; then
    print_warning "hadolint not found in PATH - skipping container linting"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  local failed=0
  while IFS= read -r file; do
    print_info "Checking $file..."
    if ! hadolint "$file"; then
      failed=1
    fi
  done <<<"$files"

  if [[ $failed -eq 0 ]]; then
    print_success "Container linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Container linting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
