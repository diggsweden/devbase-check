#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/git-utils.sh"

emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

main() {
  print_header "COMMIT HEALTH (GOMMITLINT)"

  local current_branch default_branch
  current_branch=$(git branch --show-current)
  default_branch=$(get_default_branch)

  # Skip if on the base branch itself (gommitlint can't handle base..HEAD when they're the same)
  if [[ "$current_branch" == "$default_branch" ]]; then
    print_info "On ${default_branch} - no commits to check against base branch"
    emit_status "na" "n/a"
    return 0
  fi

  if ! has_commits_since "$default_branch"; then
    print_info "No commits to check on ${current_branch} (compared to ${default_branch})"
    emit_status "na" "n/a"
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
    emit_status "skip" "not in PATH"
    return 0
  fi

  if $gommitlint_cmd validate --base-branch="${default_branch}" 2>/dev/null; then
    print_success "Commit health check passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Commit health check failed - check your commit messages"
    emit_status "fail" "failed"
    return 1
  fi
}

main
