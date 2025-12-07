#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

main() {
  print_header "GITHUB ACTIONS LINTING (ACTIONLINT)"

  if [[ ! -d .github/workflows ]]; then
    print_info "No GitHub Actions workflows found to check"
    return 0
  fi

  if ! command -v actionlint >/dev/null 2>&1; then
    print_warning "actionlint not found in PATH - skipping GitHub Actions linting"
    echo "  Install: mise install"
    return 0
  fi

  if actionlint; then
    print_success "GitHub Actions linting passed"
    return 0
  else
    print_error "GitHub Actions linting failed"
    return 1
  fi
}

main
