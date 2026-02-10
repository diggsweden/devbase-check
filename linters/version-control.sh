#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

main() {
  print_header "VERSION CONTROL"

  if test -z "$(git status --porcelain | awk '{$1=$1};1')"; then
    print_success "All changes are under version control"
    return 0
  else
    print_error "Some changes are not under version control!

  This can happen if

    1. You forgot to version control your changes
    2. A linter automatically fixed a problem or reformatted the code.

  Please accept or discard any outstanding changes and try again."
    return 1
  fi
}

main
