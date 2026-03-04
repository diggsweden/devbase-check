#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/git-utils.sh"

main() {
	print_header "COMMIT HEALTH (GOMMITLINT)"

	local current_branch default_branch
	current_branch=$(git branch --show-current)
	default_branch=$(get_default_branch)

	# Skip if on the base branch itself (gommitlint can't handle base..HEAD when they're the same)
	if [[ "$current_branch" == "$default_branch" ]]; then
		print_info "On ${default_branch} - no commits to check against base branch"
		return 0
	fi

	if ! has_commits_since "$default_branch"; then
		print_info "No commits to check on ${current_branch} (compared to ${default_branch})"
		return 0
	fi

	# Detect SHA-256 repo and select correct binary
	# See: https://github.com/go-git/go-git/issues/706
	local gommitlint_cmd="gommitlint"
	if git rev-parse --show-object-format 2>/dev/null | grep -q sha256; then
		gommitlint_cmd="gommitlint-sha256"
	fi

	if ! command -v "$gommitlint_cmd" >/dev/null 2>&1; then
		print_warning "${gommitlint_cmd} not found in PATH - skipping commit linting"
		echo "  Install: mise install"
		return 0
	fi

	if $gommitlint_cmd validate --base-branch="${default_branch}" 2>/dev/null; then
		print_success "Commit health check passed"
		return 0
	else
		print_error "Commit health check failed - check your commit messages"
		return 1
	fi
}

main
