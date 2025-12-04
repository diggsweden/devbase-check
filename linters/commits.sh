#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

get_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@" || echo "main"
}

has_commits_to_check() {
  local default_branch="$1"
  local count
  count=$(git rev-list --count "${default_branch}..HEAD" 2>/dev/null || echo 0)
  [[ "$count" -gt 0 ]]
}

main() {
  print_header "COMMIT HEALTH (CONFORM)"

  if ! command -v conform >/dev/null 2>&1; then
    print_error "conform not found. Install with: mise install"
    return 1
  fi

  local current_branch default_branch
  current_branch=$(git branch --show-current)
  default_branch=$(get_default_branch)

  # Skip if on the base branch itself (conform can't handle base..HEAD when they're the same)
  if [[ "$current_branch" == "$default_branch" ]]; then
    print_info "On ${default_branch} - checking HEAD commit only"
    if conform enforce 2>/dev/null; then
      print_success "Commit health check passed"
      return 0
    else
      print_error "Commit health check failed - check your commit messages"
      return 1
    fi
  fi

  if ! has_commits_to_check "$default_branch"; then
    print_info "No commits to check on ${current_branch} (compared to ${default_branch})"
    return 0
  fi

  if conform enforce --base-branch="${default_branch}" 2>/dev/null; then
    print_success "Commit health check passed"
    return 0
  else
    print_error "Commit health check failed - check your commit messages"
    return 1
  fi
}

main
