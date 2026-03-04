#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

main() {
	print_header "VERSION CONTROL"

	if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		print_error "Not a Git repository - cannot verify version control state"
		return 1
	fi

	if [[ -z "$(git status --porcelain)" ]]; then
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
