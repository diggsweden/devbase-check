#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

main() {
  print_header "LICENSE COMPLIANCE (REUSE)"

  if ! command -v reuse >/dev/null 2>&1; then
    print_warning "reuse not found in PATH - skipping license compliance check"
    echo "  Install: mise install"
    return 0
  fi

  if reuse lint; then
    print_success "License compliance check passed"
    return 0
  else
    print_error "License compliance check failed"
    return 1
  fi
}

main
